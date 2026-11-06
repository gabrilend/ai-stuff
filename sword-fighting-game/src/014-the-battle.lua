-- 014-the-battle.lua
--
-- One battle: the field, the two contingents, and the tick that runs every
-- rule in one fixed order. Nothing in the tick iterates a hash table, and
-- strikes are resolved in soldier-id order, so a seed and a script decide the
-- whole battle on every run and on every machine.
--
-- The battle is laid out in its own frame: the player's contingent always
-- deploys along the southern edge and pushes north. Which compass direction
-- that is on the campaign map is the campaign's business (016).
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

local util = require("002-util")
local field_m = require("005-battlefield")
local soldier_m = require("006-soldier")
local stamina = require("007-stamina")
local movement = require("008-movement")
local the_u = require("009-the-u")
local swings = require("010-swings")
local hits = require("011-hit-resolution")
local mind = require("012-soldier-mind")
local ranged = require("013-ranged")
local perks = require("015-perks")

local M = {}

-- The counters the receipt reads. Every one starts at zero; a name not here
-- cannot be counted, so a typo in a counter is caught by the first test.
M.COUNTERS = {
	"swings", "hits", "criticals", "crit_momentum", "crit_flank", "crit_trait",
	"crit_chance", "parries", "parry_attempts", "misses", "trips", "falls",
	"volleys", "darts", "dart_hits", "dart_blocks", "dart_misses", "yields",
	"ally_passes", "blocked_steps", "dodges", "dodges_refused",
}

-- How the enemy deploys, by how its push meets ours: head on, or toward a wing.
local WING = { straight = 0, left = -1, right = 1 }

-- {{{ local function new_counters()
local function new_counters()
	local c = {}
	for _, name in ipairs(M.COUNTERS) do c[name] = 0 end
	return c
end
-- }}}

-- Lays one contingent's battalions side by side, facing the enemy.
-- {{{ local function deploy()
local function deploy(battle, team, facing, front_y, shift)
	local c = battle.config.field
	local span = c.battalions * c.battalion_wide + (c.battalions - 1) * c.battalion_gap
	local left = math.floor((c.width - span) / 2) + shift
	battle.battalions[team] = {}
	for b = 1, c.battalions do
		-- the origin is the middle of the battalion's front rank
		local x0 = left + (b - 1) * (c.battalion_wide + c.battalion_gap)
		local origin_x = x0 + c.battalion_wide / 2
		battle.battalions[team][b] = { team = team, index = b, x = origin_x,
			y = front_y + 0.5, facing = facing, halted = false,
			standing = c.battalion_wide * c.battalion_deep }
	end
	for b = 1, c.battalions do
		for sy = 0, c.battalion_deep - 1 do
			for sx = 0, c.battalion_wide - 1 do
				local id = #battle.soldiers + 1
				local s = soldier_m.new(battle.catalogue, battle.config, "swordsman", {
					id = id, team = team, battalion = b, slot_x = sx, slot_y = sy,
					x = 0, y = 0, facing = facing })
				s.x, s.y = mind.slot_position(battle, s)
				local cx, cy = field_m.cell_of(s.x, s.y)
				s.x, s.y = cx + 0.5, cy + 0.5
				field_m.claim(battle.field, cx, cy, s)
				battle.soldiers[id] = s
			end
		end
	end
end
-- }}}

-- The player stands in the front rank of the middle battalion, left of centre.
-- {{{ local function pick_player()
local function pick_player(battle)
	local c = battle.config.field
	local middle = math.ceil(c.battalions / 2)
	local slot = math.floor((c.battalion_wide - 1) / 2)
	for _, s in ipairs(battle.soldiers) do
		if s.team == 1 and s.battalion == middle and s.slot_y == 0 and s.slot_x == slot then
			s.is_player = true
			return s
		end
	end
	error("no soldier stands in the player's place")
end
-- }}}

-- opts: config, catalogue, streams, region (name), enemy_wing ("straight",
-- "left", "right"), perks = { [1] = list, [2] = list } of { name,
-- be_affected }, person (true when a person drives the player's soldier).
-- {{{ function M.new()
function M.new(opts)
	local config = opts.config
	local c = config.field
	local battle = {
		config = config, catalogue = opts.catalogue, streams = opts.streams,
		region_name = opts.region, region = opts.catalogue.regions[opts.region],
		field = field_m.new(c.width, c.height),
		soldiers = {}, battalions = {}, darts = {}, events = {}, ripostes = {}, strikers = {},
		struck = {},
		time = 0, ticks = 0, counters = new_counters(), outcome = false,
		shields = { false, false }, shield_decided = { false, false },
		volley_ready = { 0, 0 },
		volley_range = { config.ranged.default_range, config.ranged.default_range },
		trained_arc = { false, false },
		commanders = { "mind", "mind" },
		person = opts.person or false,
		ranged = ranged,
		started = { 0, 0 },
	}
	if not battle.region then error("no region kind named " .. tostring(opts.region)) end
	local wing = WING[opts.enemy_wing or "straight"]
	if not wing then error("no enemy wing named " .. tostring(opts.enemy_wing)) end
	local back = c.deploy_margin + c.battalion_deep - 1
	deploy(battle, 1, -math.pi / 2, c.height - 1 - back, 0)
	deploy(battle, 2, math.pi / 2, back, wing * c.wing_offset)
	battle.player = pick_player(battle)
	local taken = opts.perks or {}
	perks.apply(battle, 1, taken[1] or {})
	perks.apply(battle, 2, taken[2] or {})
	for _, s in ipairs(battle.soldiers) do
		battle.started[s.team] = battle.started[s.team] + 1
	end
	return battle
end
-- }}}

-- A battalion with nobody standing no longer draws anyone toward it.
-- {{{ local function nearest_battalion()
local function nearest_battalion(battle, b)
	local best, best_d = false, math.huge
	for _, o in ipairs(battle.battalions[3 - b.team]) do
		local d = (o.x - b.x) ^ 2 + (o.y - b.y) ^ 2
		if o.standing > 0 and d < best_d then best, best_d = o, d end
	end
	return best, math.sqrt(best_d)
end
-- }}}

-- The origin wheels toward the nearest enemy battalion and walks on until it
-- meets it; then it holds, and its soldiers fight. With no enemy battalion
-- left standing it holds where it is.
-- {{{ local function advance_one()
local function advance_one(battle, b, dt)
	local c = battle.config
	local o, d = nearest_battalion(battle, b)
	b.halted = (not o) or d < 2.0
	if not o then return end
	local want = math.atan2(o.y - b.y, o.x - b.x)
	b.facing = b.facing + util.wrap_angle(want - b.facing) * math.min(1, dt * 0.5)
	if b.halted then return end
	local share = battle.shields[b.team] and c.body.shield_walk or 1
	local speed = c.body.walk_speed * 0.55 * share * battle.region.walk
	b.x = b.x + math.cos(b.facing) * speed * dt
	b.y = b.y + math.sin(b.facing) * speed * dt
end
-- }}}

-- {{{ local function advance_formations()
local function advance_formations(battle, dt)
	for team = 1, 2 do
		for _, b in ipairs(battle.battalions[team]) do advance_one(battle, b, dt) end
	end
end
-- }}}

-- A contingent with a quarter or fewer standing breaks; past the time limit
-- the battle is a draw (outcome 0).
-- {{{ local function check_break()
local function check_break(battle)
	local standing = { 0, 0 }
	for team = 1, 2 do
		for _, b in ipairs(battle.battalions[team]) do b.standing = 0 end
	end
	for _, s in ipairs(battle.soldiers) do
		if s.alive then
			standing[s.team] = standing[s.team] + 1
			local b = battle.battalions[s.team][s.battalion]
			b.standing = b.standing + 1
		end
	end
	battle.standing = standing
	local share = battle.config.field.break_share
	for team = 1, 2 do
		if standing[team] <= battle.started[team] * share then
			battle.outcome = 3 - team
			return
		end
	end
	if battle.time >= battle.config.tick.battle_limit then battle.outcome = 0 end
end
-- }}}

-- With a lock, the body turns toward it; without, toward its battalion's
-- facing.
-- {{{ local function face()
local function face(battle, s, dt)
	if s.lock then
		the_u.turn(battle, s, dt, math.atan2(s.lock.y - s.y, s.lock.x - s.x))
	else
		the_u.turn(battle, s, dt, battle.battalions[s.team][s.battalion].facing)
	end
end
-- }}}

-- What the intent asks that is not movement: the guard, the U, a swing.
-- {{{ local function take_intent()
local function take_intent(battle, s)
	local i = s.intent
	the_u.move(s, i.u_delta)
	s.guard = i.guard and soldier_m.can_act(s) and not s.swing
	if i.swing then swings.start(battle, s, i.swing) end
end
-- }}}

-- {{{ local function count_down()
local function count_down(s, dt)
	if s.tripped > 0 then s.tripped = s.tripped - dt end
	if s.stagger > 0 then s.stagger = s.stagger - dt end
	if s.open > 0 then s.open = s.open - dt end
	if s.hurt_flash > 0 then s.hurt_flash = math.max(0, s.hurt_flash - dt * 2) end
end
-- }}}

-- One fixed step, always in this order. `player_intent` is the person's
-- intent for the player's soldier, or nil to let its mind drive it.
-- {{{ function M.tick()
function M.tick(battle, player_intent)
	local c = battle.config
	local dt = c.tick.seconds
	local soldiers = battle.soldiers
	for k = #battle.events, 1, -1 do battle.events[k] = nil end
	-- 1. intents
	for _, s in ipairs(soldiers) do
		if s.is_player and player_intent then
			local i, p = s.intent, player_intent
			i.forward, i.side, i.guard = p.forward, p.side, p.guard
			i.swing, i.u_delta, i.dodge = p.swing, p.u_delta, p.dodge
		else
			mind.think(battle, s, dt)
		end
	end
	-- 2. locks, facing, and what the intent asks of the sword
	for _, s in ipairs(soldiers) do
		if s.alive then
			the_u.update_lock(battle, s, dt)
			face(battle, s, dt)
			take_intent(battle, s)
		end
	end
	-- 3. movement and tripping
	for _, s in ipairs(soldiers) do movement.step(battle, s, dt) end
	-- 4. swings advance; then every strike of this tick resolves, in id
	-- order. The two passes make blows on one tick simultaneous: a soldier
	-- felled by a lower id this tick still lands the blow already falling,
	-- or the lower ids (team 1) would win every exchange of equal timing.
	local strikers, struck = battle.strikers, battle.struck
	for k = #strikers, 1, -1 do strikers[k], struck[k] = nil, nil end
	for _, s in ipairs(soldiers) do
		if s.alive and swings.advance(battle, s, dt) then
			strikers[#strikers + 1], struck[#strikers + 1] = s, s.swing
		end
	end
	for k, s in ipairs(strikers) do hits.resolve(battle, s, struck[k]) end
	for k = 1, #battle.ripostes do
		swings.start(battle, battle.ripostes[k], "riposte")
		battle.ripostes[k] = nil
	end
	-- 5. the commanders, and darts in flight
	for team = 1, 2 do
		if battle.commanders[team] == "mind" then ranged.commander(battle, team, dt) end
	end
	ranged.step(battle, dt)
	-- 6. rest and timers
	for _, s in ipairs(soldiers) do
		if s.alive then
			local moving = s.vx * s.vx + s.vy * s.vy > 0.01
			stamina.restore(s, c, dt, moving)
			count_down(s, dt)
		end
	end
	-- 7. formations, then the break check
	advance_formations(battle, dt)
	battle.time = battle.time + dt
	battle.ticks = battle.ticks + 1
	check_break(battle)
end
-- }}}

-- Whether any two enemies have come within engage range: the moment the
-- round drops into the front rank.
-- {{{ function M.lines_touched()
function M.lines_touched(battle)
	for _, s in ipairs(battle.soldiers) do
		if s.alive and s.lock and ranged.engaged(battle, s) then return true end
	end
	return false
end
-- }}}

return M

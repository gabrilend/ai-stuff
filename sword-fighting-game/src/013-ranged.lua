-- 013-ranged.lua
--
-- Volleys and the shield wall: the commander's two hands.
--
-- A volley is thrown by every soldier of a contingent not already fighting.
-- Every dart flies the same arc, because everyone trained the same way and
-- nobody can see how far the enemy is: it lands three battalion lengths ahead
-- of its thrower. Only the trained-arc perk lets a contingent pick range 1, 2
-- or 3. The commander chooses when to throw, not how far.
--
-- A dart that lands near an enemy joins the hit-resolution order at its parry
-- step, with the shield wall's large bonus against thrown weapons.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

local util = require("002-util")
local field_m = require("005-battlefield")
local soldier_m = require("006-soldier")
local hits = require("011-hit-resolution")

local M = {}

local scratch = {}

-- {{{ local function launch()
local function launch(battle, s, ex, ey)
	local r = battle.config.ranged
	battle.darts[#battle.darts + 1] = {
		sx = s.x, sy = s.y, ex = ex, ey = ey, t = 0,
		flight = r.flight_time, team = s.team, thrower = s,
	}
	battle.counters.darts = battle.counters.darts + 1
end
-- }}}

-- Fighting already: its lock is within engage range.
-- {{{ function M.engaged()
function M.engaged(battle, s)
	local t = s.lock
	return t and util.distance(s.x, s.y, t.x, t.y) <= battle.config.field.engage_range
end
-- }}}

-- {{{ function M.ready()
function M.ready(battle, team)
	return battle.time >= battle.volley_ready[team]
end
-- }}}

-- Only a contingent with the trained arc may change its range.
-- {{{ function M.set_range()
function M.set_range(battle, team, range)
	if battle.trained_arc[team] then battle.volley_range[team] = util.clamp(range, 1, 3) end
end
-- }}}

-- Throws, if the cooldown allows. Returns the number of darts thrown.
-- {{{ function M.volley()
function M.volley(battle, team)
	if not M.ready(battle, team) then return 0 end
	local r = battle.config.ranged
	local reach = battle.volley_range[team] * r.battalion_length
	local stream = battle.streams.ranged
	local thrown = 0
	for _, s in ipairs(battle.soldiers) do
		-- standing, on this side, and not already in the melee
		if s.team == team and s.alive and s.tripped <= 0 and not M.engaged(battle, s) then
			local fx, fy = soldier_m.forward(s)
			local ex = s.x + fx * reach + stream:range(-r.spread, r.spread)
			local ey = s.y + fy * reach + stream:range(-r.spread, r.spread)
			launch(battle, s, ex, ey)
			thrown = thrown + 1
		end
	end
	if thrown > 0 then
		battle.volley_ready[team] = battle.time + r.cooldown
		battle.counters.volleys = battle.counters.volleys + 1
		battle.events[#battle.events + 1] = { kind = "volley", team = team, darts = thrown }
	end
	return thrown
end
-- }}}

-- A skirmisher's throw from the front rank, straight at an enemy.
-- {{{ function M.throw_single()
function M.throw_single(battle, s, ex, ey)
	launch(battle, s, ex, ey)
end
-- }}}

-- The nearest standing enemy of the thrower within the hit radius takes it,
-- unless a shield turns it aside.
-- {{{ local function land()
local function land(battle, d)
	local c = battle.config
	for k = #scratch, 1, -1 do scratch[k] = nil end
	field_m.near(battle.field, d.ex, d.ey, c.ranged.hit_radius, scratch)
	local target, best = false, math.huge
	for _, o in ipairs(scratch) do
		local dist = util.distance(d.ex, d.ey, o.x, o.y)
		if o.alive and o.team ~= d.team and dist < best then target, best = o, dist end
	end
	if not target then
		battle.counters.dart_misses = battle.counters.dart_misses + 1
		return
	end
	local chance = 0
	if battle.shields[target.team] then chance = chance + c.hits.shield_volley end
	if target.traits.shield then chance = chance + c.hits.shield_parry end
	if target.guard then chance = chance + 0.15 end
	if battle.streams.ranged:chance(chance) then
		battle.counters.dart_blocks = battle.counters.dart_blocks + 1
		battle.events[#battle.events + 1] = { kind = "block", who = target }
		return
	end
	local damage = c.ranged.damage * hits.armor_share(battle, target)
	battle.counters.dart_hits = battle.counters.dart_hits + 1
	battle.events[#battle.events + 1] = { kind = "dart_hit", who = target, damage = damage }
	hits.apply_damage(battle, target, damage, d.thrower)
end
-- }}}

-- Darts fly; those whose flight is over land, and the list is compacted in
-- place so its order (and so the landing order) is the order thrown.
-- {{{ function M.step()
function M.step(battle, dt)
	local darts = battle.darts
	local keep = 0
	for k = 1, #darts do
		local d = darts[k]
		d.t = d.t + dt
		if d.t >= d.flight then
			land(battle, d)
		else
			keep = keep + 1
			darts[keep] = d
		end
	end
	for k = #darts, keep + 1, -1 do darts[k] = nil end
end
-- }}}

-- Where a dart is now, for drawing: along the line, lifted on the one arc.
-- {{{ function M.position()
function M.position(battle, d)
	local p = d.t / d.flight
	local x, y = util.lerp(d.sx, d.ex, p), util.lerp(d.sy, d.ey, p)
	return x, y, 4 * p * (1 - p) * battle.config.ranged.arc_height
end
-- }}}

-- The distance between this side's nearest battalion and the enemy's.
-- {{{ local function front_gap()
local function front_gap(battle, team)
	local best = math.huge
	for _, a in ipairs(battle.battalions[team]) do
		for _, b in ipairs(battle.battalions[3 - team]) do
			best = math.min(best, util.distance(a.x, a.y, b.x, b.y))
		end
	end
	return best
end
-- }}}

-- The commander's mind, for a side no person commands: throw when the enemy
-- is about where the arc lands; raise shields while the enemy's darts fly.
-- {{{ function M.commander()
function M.commander(battle, team, dt)
	local c = battle.config
	local incoming = false
	for _, d in ipairs(battle.darts) do
		if d.team ~= team then incoming = true break end
	end
	-- shields: decided once per volley seen, lowered when the sky is clear
	if not incoming then
		battle.shields[team], battle.shield_decided[team] = false, false
	elseif not battle.shield_decided[team] then
		battle.shield_decided[team] = true
		battle.shields[team] = battle.streams.ranged:chance(c.mind.shield_chance)
	end
	-- The arc is fixed, so the only choice is when. Both lines close while the
	-- darts fly, and each soldier throws from its own rank, so the commander
	-- throws when the gap at landing puts our middle rank's darts onto the
	-- enemy's middle rank: the gap is then the landing distance less both
	-- middles.
	local landing = battle.volley_range[team] * c.ranged.battalion_length
	local closing = 2 * c.body.walk_speed * 0.55 * battle.region.walk * c.ranged.flight_time
	local predicted = front_gap(battle, team) - closing
	local middle = (c.field.battalion_deep - 1) / 2
	if M.ready(battle, team) and math.abs(predicted - (landing - 2 * middle)) < 0.8
		and battle.streams.ranged:chance(c.mind.volley_chance * dt * 10) then
		M.volley(battle, team)
	end
end
-- }}}

return M

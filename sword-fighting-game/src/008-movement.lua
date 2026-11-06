-- 008-movement.lua
--
-- Turns a soldier's wish to move into a step, and enforces who may stand
-- where. The rules, from the vision:
--
--   enemy-held cells are walls: nobody can push anyone around;
--   ally-held cells may be entered at half speed, and the ally steps the other
--     way by itself, along its own dodge movement (not pushed by the mover);
--   a dodge never lands in an occupied cell;
--   the field's edge is a wall.
--
-- The trip rules (007-stamina.lua) are asked here, on the tick a backstep or a
-- guarded sidestep begins.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

local util = require("002-util")
local field_m = require("005-battlefield")
local soldier_m = require("006-soldier")
local stamina = require("007-stamina")

local M = {}

-- {{{ local function count()
local function count(battle, name)
	battle.counters[name] = battle.counters[name] + 1
end
-- }}}

-- Moves s to (nx, ny) if the cell there allows it. Returns "moved",
-- "blocked" or "ally" (the step leads into an ally's cell and has not
-- been taken, so the caller may retry it at half speed).
-- {{{ local function try_move()
local function try_move(battle, s, nx, ny, allow_ally)
	local field = battle.field
	local cx, cy = field_m.cell_of(nx, ny)
	local px, py = field_m.cell_of(s.x, s.y)
	-- the cell it holds, or the cell its body is already in (a yielding body
	-- walks out of the cell it gave away): no claim changes hands
	if (cx == s.cell_x and cy == s.cell_y) or (cx == px and cy == py) then
		s.x, s.y = nx, ny
		return "moved"
	end
	local h = field_m.holder(field, cx, cy)
	-- an empty cell: release the old, claim the new
	if h == false then
		field_m.release(field, s)
		field_m.claim(field, cx, cy, s)
		s.x, s.y = nx, ny
		return "moved"
	end
	-- the edge, or an enemy: a wall
	if h == "edge" or h.team ~= s.team then return "blocked" end
	-- an ally, and the caller has already slowed this step: trade places
	if allow_ally then
		field_m.swap(field, s, h)
		s.x, s.y = nx, ny
		M.give_yield(battle, h, s)
		count(battle, "yields")
		return "moved"
	end
	return "ally"
end
-- }}}

-- The ally has been given the mover's old cell; it steps to that cell's
-- centre by itself, at its own yield speed.
-- {{{ function M.give_yield()
function M.give_yield(battle, ally, mover)
	local tx, ty = ally.cell_x + 0.5, ally.cell_y + 0.5
	local dx, dy = util.normalize(tx - ally.x, ty - ally.y)
	ally.yield = { dx = dx, dy = dy, t = battle.config.body.yield_time,
		tx = tx, ty = ty }
end
-- }}}

-- Moves by (dx, dy), sliding along walls: the whole step, else each axis
-- alone. A step into an ally's cell is retried at the ally-pass share.
-- {{{ local function apply_motion()
local function apply_motion(battle, s, dx, dy, ally_share)
	if dx == 0 and dy == 0 then return 0, 0 end
	local ox, oy = s.x, s.y
	local tries = { { dx, dy }, { dx, 0 }, { 0, dy } }
	for _, t in ipairs(tries) do
		if t[1] ~= 0 or t[2] ~= 0 then
			local r = try_move(battle, s, s.x + t[1], s.y + t[2], false)
			if r == "moved" then break end
			-- into an ally: take the slower step, which may trade places;
			-- yields and dodges (share 0) never trade
			if r == "ally" and ally_share > 0 then
				local sx, sy = t[1] * ally_share, t[2] * ally_share
				if try_move(battle, s, s.x + sx, s.y + sy, true) == "moved" then
					count(battle, "ally_passes")
					break
				end
			end
		end
	end
	if s.x == ox and s.y == oy then count(battle, "blocked_steps") end
	return s.x - ox, s.y - oy
end
-- }}}

-- Every multiplier on walking speed, in one place.
-- {{{ local function speed_share()
local function speed_share(battle, s, forward)
	local c = battle.config.body
	local share = s.walk_mult * battle.region.walk
	-- guarding slows the step, except a beastwarrior walking forward
	if s.guard and not (s.traits.guard_while_advancing and forward > 0) then
		share = share * c.guard_walk
	end
	-- the shield wall slows the whole contingent
	if battle.shields[s.team] then share = share * c.shield_walk end
	return share
end
-- }}}

-- The trip rules fire when a step begins, not on every tick of it.
-- {{{ local function check_trips()
local function check_trips(battle, s, forward, side)
	local c = battle.config
	local backing = forward < -c.body.step_threshold
	local siding = math.abs(side) > c.body.step_threshold
	local tripped = false
	-- a backstep begun while fatigued: always a fall
	if backing and not s.was_backing and stamina.backstep_trips(s, c) then
		tripped = true
	end
	-- a sidestep begun while guarding: one in four
	if not tripped and siding and not s.was_siding
		and stamina.sidestep_trips(s, c, battle.streams.movement) then
		tripped = true
	end
	s.was_backing, s.was_siding = backing, siding
	if tripped then stamina.trip(s, c, battle) end
	return tripped
end
-- }}}

-- A quick step in the wished direction (backward when there is no wish). It
-- is refused before it starts if its landing cell is held by anyone.
-- {{{ local function start_dodge()
local function start_dodge(battle, s, forward, side)
	local c = battle.config
	if forward == 0 and side == 0 then forward = -1 end
	local fx, fy = soldier_m.forward(s)
	local rx, ry = soldier_m.right(s)
	local dx, dy = util.normalize(fx * forward + rx * side, fy * forward + ry * side)
	local lx, ly = s.x + dx * c.body.dodge_length, s.y + dy * c.body.dodge_length
	local cx, cy = field_m.cell_of(lx, ly)
	local same = cx == s.cell_x and cy == s.cell_y
	if not same and field_m.holder(battle.field, cx, cy) ~= false then
		count(battle, "dodges_refused")
		return
	end
	s.dodge = { dx = dx, dy = dy, t = c.body.dodge_time }
	stamina.spend(s, c.stamina.dodge_cost)
	count(battle, "dodges")
end
-- }}}

-- {{{ local function step_yield()
local function step_yield(battle, s, dt)
	local y = s.yield
	local c = battle.config.body
	local d = util.distance(s.x, s.y, y.tx, y.ty)
	local len = math.min(d, c.yield_speed * dt)
	apply_motion(battle, s, y.dx * len, y.dy * len, 0)
	y.t = y.t - dt
	if y.t <= 0 or d < 0.02 then s.yield = false end
end
-- }}}

-- {{{ local function step_dodge()
local function step_dodge(battle, s, dt)
	local d = s.dodge
	local c = battle.config.body
	local len = c.dodge_length / c.dodge_time * dt
	apply_motion(battle, s, d.dx * len, d.dy * len, 0)
	d.t = d.t - dt
	if d.t <= 0 then s.dodge = false end
end
-- }}}

-- {{{ local function step_walk()
local function step_walk(battle, s, dt)
	local c = battle.config.body
	local i = s.intent
	local forward, side = util.clamp(i.forward, -1, 1), util.clamp(i.side, -1, 1)
	if check_trips(battle, s, forward, side) then return end
	if i.dodge then
		start_dodge(battle, s, forward, side)
		if s.dodge then return end
	end
	local share = speed_share(battle, s, forward)
	local fspeed = forward > 0 and forward or forward * c.back_speed
	local sspeed = side * c.side_speed
	local fx, fy = soldier_m.forward(s)
	local rx, ry = soldier_m.right(s)
	local vx = (fx * fspeed + rx * sspeed) * c.walk_speed * share
	local vy = (fy * fspeed + ry * sspeed) * c.walk_speed * share
	-- loose soldiers slip through their own line at full speed
	local pass = s.traits.loose and 1 or c.ally_pass
	apply_motion(battle, s, vx * dt, vy * dt, pass)
end
-- }}}

-- One tick of movement. Lying down, nothing moves; yielding and dodging
-- carry on by themselves; otherwise the soldier walks by its intent.
-- {{{ function M.step()
function M.step(battle, s, dt)
	local ox, oy = s.x, s.y
	if not s.alive or s.tripped > 0 then
		s.vx, s.vy = 0, 0
		return
	end
	-- a yield is the ally's own movement and overrides its wishes
	if s.yield then
		step_yield(battle, s, dt)
	elseif s.dodge then
		step_dodge(battle, s, dt)
	else
		step_walk(battle, s, dt)
	end
	s.vx, s.vy = (s.x - ox) / dt, (s.y - oy) / dt
	s.distance_walked = s.distance_walked + util.length(s.x - ox, s.y - oy)
end
-- }}}

return M

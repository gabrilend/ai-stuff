-- 012-soldier-mind.lua
--
-- The small mind that fights for every soldier without a hand on it. It
-- writes the same intent record a person's keys and mouse write (forward,
-- side, guard, swing, u_delta, dodge), so the rules cannot tell a mind from a
-- person, and a headless battle is a whole battle.
--
-- The mind is a handful of states in a table. It is deliberately a little
-- slow (a reaction delay) so it can be beaten, and it never backsteps while
-- fatigued, so minds do not trip themselves on purpose.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

local util = require("002-util")
local soldier_m = require("006-soldier")
local field_m = require("005-battlefield")

local M = {}

-- U positions a mind aims for, by side.
local AIM = { left = -0.85, bend = 0, right = 0.85 }

local scratch = {}

-- Where the soldier's place in its battalion's formation is now: the
-- battalion's origin is the middle of its front rank, slots run across to the
-- right and back by rank.
-- {{{ function M.slot_position()
function M.slot_position(battle, s)
	local b = battle.battalions[s.team][s.battalion]
	local c = battle.config.field
	local fx, fy = math.cos(b.facing), math.sin(b.facing)
	local rx, ry = -fy, fx
	local across = s.slot_x - (c.battalion_wide - 1) / 2
	return b.x + rx * across - fx * s.slot_y, b.y + ry * across - fy * s.slot_y
end
-- }}}

-- A fatigued soldier never wishes a backstep big enough to count as one.
-- {{{ local function safe_forward()
local function safe_forward(battle, s, forward)
	local c = battle.config
	if soldier_m.fatigue(s) > c.stamina.trip_fatigue - 0.05 then
		return math.max(forward, -c.body.step_threshold * 0.8)
	end
	return forward
end
-- }}}

-- Sets the wish to walk to a point, relative to where the soldier faces.
-- {{{ local function walk_toward()
local function walk_toward(battle, s, i, tx, ty, arrive)
	local dx, dy = tx - s.x, ty - s.y
	local d = util.length(dx, dy)
	if d < arrive then return end
	dx, dy = dx / d, dy / d
	local fx, fy = soldier_m.forward(s)
	local rx, ry = soldier_m.right(s)
	local speed = math.min(1, d)
	i.forward = safe_forward(battle, s, (dx * fx + dy * fy) * speed)
	i.side = (dx * rx + dy * ry) * speed
end
-- }}}

-- The lock is winding up a swing aimed at this soldier.
-- {{{ local function threatened()
local function threatened(s)
	local t = s.lock
	return t and t.swing and not t.swing.struck and t.swing.target == s
end
-- }}}

-- Once per enemy swing seen, the mind decides whether to guard against it.
-- {{{ local function decide_guard()
local function decide_guard(battle, s, m)
	if not threatened(s) then return false end
	if m.seen ~= s.lock.swing then
		m.seen = s.lock.swing
		m.will_guard = battle.streams.minds:chance(battle.config.mind.guard_chance)
	end
	return m.will_guard
end
-- }}}

-- Most attacks are stabs. Otherwise a slash, from the side opposite the last
-- one when there was one, because that is where the momentum is.
-- {{{ local function choose_side()
local function choose_side(battle, s)
	local r = battle.streams.minds:float()
	if r < 0.5 then return "bend" end
	if s.last_side == "left" then return "right" end
	if s.last_side == "right" then return "left" end
	return r < 0.75 and "left" or "right"
end
-- }}}

-- {{{ local function nearest_within()
local function nearest_within(battle, s, radius)
	for k = #scratch, 1, -1 do scratch[k] = nil end
	field_m.near(battle.field, s.x, s.y, radius, scratch)
	local best, best_d = false, math.huge
	for _, o in ipairs(scratch) do
		local d = util.distance(s.x, s.y, o.x, o.y)
		if o.team ~= s.team and o.alive and d < best_d then best, best_d = o, d end
	end
	return best, best_d
end
-- }}}

local STATES = {}

-- Keep to the formation slot as the battalion advances; engage an enemy
-- that comes near; a skirmisher throws first when the enemy is a battalion
-- length or two away.
-- {{{ function STATES.march()
function STATES.march(battle, s, m, i)
	local c = battle.config
	if s.lock and util.distance(s.x, s.y, s.lock.x, s.lock.y) <= c.field.engage_range then
		m.state = "engage"
		return
	end
	if s.traits.throws_from_front and not m.thrown then
		local bl = c.ranged.battalion_length
		local e, d = nearest_within(battle, s, bl * 2)
		if e and d >= bl then
			battle.ranged.throw_single(battle, s, e.x, e.y)
			m.thrown, m.state, m.wait = true, "fall_back", 2.0
			return
		end
	end
	local tx, ty = M.slot_position(battle, s)
	walk_toward(battle, s, i, tx, ty, 0.15)
end
-- }}}

-- {{{ function STATES.engage()
function STATES.engage(battle, s, m, i)
	local c = battle.config
	local t = s.lock
	if not t or util.distance(s.x, s.y, t.x, t.y) > c.field.engage_range + 1 then
		m.state = "march"
		return
	end
	if s.stamina < c.mind.caution then
		m.state = "recover"
		return
	end
	local d = util.distance(s.x, s.y, t.x, t.y)
	local reach = s.weapon.reach + c.body.radius
	-- close in until within reach; give ground a little if crowded
	if d > reach * 0.85 then
		walk_toward(battle, s, i, t.x, t.y, 0)
	elseif d < reach * 0.45 then
		i.forward = safe_forward(battle, s, -0.4)
	end
	i.guard = decide_guard(battle, s, m) and not s.swing
	if i.guard or s.swing or m.wait > 0 or d > reach or not soldier_m.can_act(s) then
		return
	end
	m.aim = m.aim or AIM[choose_side(battle, s)]
	i.u_delta = util.clamp(m.aim - s.u, -0.15, 0.15)
	if math.abs(s.u - m.aim) < 0.05 then
		local heavy = s.stamina > 0.7 and battle.streams.minds:chance(0.12)
		i.swing = heavy and "overhead" or "swing"
		m.aim = false
		m.wait = c.mind.reaction + battle.streams.minds:range(0.1, 0.6)
		if s.traits.harry then m.harry, m.state = c.mind.harry_back, "harry" end
	end
end
-- }}}

-- Stand and breathe; guard only when a blow is coming, because the guard
-- itself costs stamina.
-- {{{ function STATES.recover()
function STATES.recover(battle, s, m, i)
	i.guard = decide_guard(battle, s, m)
	if s.stamina > battle.config.mind.comfort then m.state = "engage" end
end
-- }}}

-- The harry perk: strike, then the battalion steps back together.
-- {{{ function STATES.harry()
function STATES.harry(battle, s, m, i, dt)
	i.forward = safe_forward(battle, s, -0.6)
	i.guard = decide_guard(battle, s, m)
	m.harry = m.harry - dt
	if m.harry <= 0 then m.state = "engage" end
end
-- }}}

-- A skirmisher, having thrown, slips back through the loose formation.
-- {{{ function STATES.fall_back()
function STATES.fall_back(battle, s, m, i)
	i.forward = safe_forward(battle, s, -1)
	if m.wait <= 0 then m.state = "march" end
end
-- }}}

-- {{{ function M.think()
function M.think(battle, s, dt)
	local i = s.intent
	i.forward, i.side, i.guard, i.swing, i.u_delta, i.dodge = 0, 0, false, false, 0, false
	if not s.alive then return end
	local m = s.mind
	m.wait = m.wait - dt
	STATES[m.state](battle, s, m, i, dt)
end
-- }}}

return M

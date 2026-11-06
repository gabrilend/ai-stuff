-- 010-swings.lua
--
-- One attack from start to finish. A swing has a windup (committed: only a
-- hit can stop it), one strike moment (resolved by 011-hit-resolution.lua),
-- and a recovery. The kinds are rows in a table, so a weapon that wants a new
-- kind of swing adds a row rather than a branch.
--
-- Momentum is fixed at the strike: how fast the body was carrying itself at
-- the target, plus how the swing flows from the one before it.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

local util = require("002-util")
local the_u = require("009-the-u")
local stamina = require("007-stamina")
local soldier_m = require("006-soldier")

local M = {}

-- The side each kind comes from, when it does not depend on the U.
local KIND_SIDE = { overhead = "above" }

-- How a swing flows from the last one: the previous side, then this side,
-- names the momentum bonus earned. Opposite sides flow; the same side again
-- stalls (no row); a stab after a slash flows a little.
local FLOW = {
	left  = { right = "flow_bonus", bend = "bend_bonus" },
	right = { left = "flow_bonus", bend = "bend_bonus" },
	above = { left = "bend_bonus", right = "bend_bonus", bend = "bend_bonus" },
	bend  = {},
	none  = {},
}

-- {{{ local function allowed()
local function allowed(weapon, kind)
	for _, k in ipairs(weapon.swings) do
		if k == kind then return true end
	end
	return false
end
-- }}}

-- An overhead request is an overhead if the weapon makes them; anything else
-- swings from wherever the sword sits on the U. A weapon or a soldier that
-- only stabs turns every swing into a stab.
-- {{{ local function choose_kind()
local function choose_kind(battle, s, request)
	local side = the_u.side_of(s.u, battle.config)
	local kind = side == "bend" and "stab" or "slash"
	if request == "overhead" then kind = "overhead" end
	if s.traits.stabs_only or not allowed(s.weapon, kind) then
		kind, side = "stab", "bend"
	end
	return kind, KIND_SIDE[kind] or side
end
-- }}}

-- request: "swing", "overhead" or "riposte". Returns the swing, or false
-- when the soldier cannot swing now.
-- {{{ function M.start()
function M.start(battle, s, request)
	if s.swing or not soldier_m.can_act(s) then return false end
	local config = battle.config
	local kind, side = choose_kind(battle, s, request)
	if request == "riposte" then kind, side = "stab", "bend" end
	local row = config.swings[kind]
	local thick = s.thickness == 1 and 1.1 or 1
	local quick = request == "riposte" and 0.35 or 1
	s.swing = {
		kind = kind, side = side, t = 0,
		windup = row.windup * s.weapon.windup * thick * quick,
		recovery = row.recovery * s.weapon.recovery * thick,
		struck = false, momentum = 0,
		target = s.lock,
	}
	s.guard = false
	local cost = kind == "overhead" and config.stamina.overhead_cost or config.stamina.swing_cost
	stamina.spend(s, cost)
	battle.counters.swings = battle.counters.swings + 1
	battle.events[#battle.events + 1] = { kind = "swing", who = s, swing = kind }
	return s.swing
end
-- }}}

-- Body part: speed toward the target times the body-weight knob. Pattern
-- part: the flow bonus from the last swing's side to this one's, forgotten
-- if the last swing was too long ago. The overhead always carries its own.
-- {{{ function M.momentum()
function M.momentum(battle, s, swing)
	local c = battle.config
	local body = 0
	local t = swing.target
	if t then
		local dx, dy = util.normalize(t.x - s.x, t.y - s.y)
		body = math.max(0, s.vx * dx + s.vy * dy) * c.body.weight
	end
	local last = s.last_side
	if battle.time - s.last_swing_time > c.sword.flow_window then last = "none" end
	local bonus_name = FLOW[last][swing.side]
	local pattern = bonus_name and c.sword[bonus_name] or 0
	if swing.kind == "overhead" then pattern = pattern + c.sword.overhead_bonus end
	return body + pattern
end
-- }}}

-- Moves a swing on by one tick. Returns true on the tick it strikes. After
-- an overhead strikes, its swinger is open (unparryable) for the recovery.
-- {{{ function M.advance()
function M.advance(battle, s, dt)
	local w = s.swing
	if not w then return false end
	w.t = w.t + dt
	if not w.struck and w.t >= w.windup then
		w.struck = true
		w.momentum = M.momentum(battle, s, w)
		s.last_side, s.last_swing_time = w.side, battle.time
		if w.kind == "overhead" then s.open = w.recovery end
		return true
	end
	if w.t >= w.windup + w.recovery then s.swing = false end
	return false
end
-- }}}

-- For drawing: phase "windup" or "recovery" and how far through it, 0..1.
-- {{{ function M.progress()
function M.progress(swing)
	if swing.t < swing.windup then return "windup", swing.t / swing.windup end
	return "recovery", util.clamp((swing.t - swing.windup) / swing.recovery, 0, 1)
end
-- }}}

return M

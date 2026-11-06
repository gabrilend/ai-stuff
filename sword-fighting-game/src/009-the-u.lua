-- 009-the-u.lua
--
-- Where the sword rests, and who it is pointed at.
--
-- The U: picture a letter U drawn around the locked enemy. The weapon's place
-- on it is one number, u, from -1 (top of the left arm) through 0 (bottom of
-- the bend) to +1 (top of the right arm). The arms make slashes from their
-- side; the bend makes a stab, and the bend is wide because most attacks are
-- stabs: a battalion has no room for wide slashes.
--
-- The lock: the U is always drawn around the nearest enemy. When a different
-- enemy becomes nearest, the lock takes half a second to move to it, and it
-- moves before the next attack, so the enemy cannot tell which way you are
-- about to look.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

local util = require("002-util")
local field_m = require("005-battlefield")

local M = {}

local scratch = {}

-- Which part of the U the weapon is on: "left", "bend" or "right".
-- {{{ function M.side_of()
function M.side_of(u, config)
	local bend = config.sword.bend_width
	if u < -bend then return "left" end
	if u > bend then return "right" end
	return "bend"
end
-- }}}

-- The point on the U for drawing: lateral from -1 (left) to 1 (right), and
-- lift from 0 (bottom of the bend) to 1 (top of an arm). The arms rise
-- steeply, as a U's arms do.
-- {{{ function M.shape()
function M.shape(u)
	local lift = math.abs(u) ^ 2.2
	return u, lift
end
-- }}}

-- {{{ function M.move()
function M.move(s, delta)
	s.u = util.clamp(s.u + delta, -1, 1)
end
-- }}}

-- {{{ local function nearest_enemy()
local function nearest_enemy(battle, s)
	local range = battle.config.field.lock_range
	for i = #scratch, 1, -1 do scratch[i] = nil end
	field_m.near(battle.field, s.x, s.y, range, scratch)
	local best, best_d = false, math.huge
	for _, o in ipairs(scratch) do
		if o.team ~= s.team and o.alive then
			local d = util.distance(s.x, s.y, o.x, o.y)
			-- ties go to the lower id, so the choice never depends on order
			if d < best_d or (d == best_d and o.id < best.id) then
				best, best_d = o, d
			end
		end
	end
	return best, best_d
end
-- }}}

M.nearest_enemy = nearest_enemy

-- No enemy near: no lock. No lock yet: the first takes hold at once. A lock
-- held: a nearer enemy takes it only after the switch time, and a pending
-- switch that is overtaken by a third enemy starts its clock again.
-- {{{ function M.update_lock()
function M.update_lock(battle, s, dt)
	local nearest = nearest_enemy(battle, s)
	if not nearest then
		s.lock, s.lock_next, s.lock_timer = false, false, 0
		return
	end
	if s.lock == nearest then
		s.lock_next = false
		return
	end
	if not s.lock then
		s.lock = nearest
		return
	end
	if s.lock_next ~= nearest then
		s.lock_next = nearest
		s.lock_timer = battle.config.sword.lock_switch
	end
	s.lock_timer = s.lock_timer - dt
	if s.lock_timer <= 0 then
		s.lock, s.lock_next = nearest, false
	end
end
-- }}}

-- Turns the body toward an angle at the turn rate. Players and minds turn by
-- the same rule; free look moves only the player's eyes, not the body.
-- {{{ function M.turn()
function M.turn(battle, s, dt, toward)
	local diff = util.wrap_angle(toward - s.facing)
	local step = battle.config.body.turn_rate * dt
	s.facing = util.wrap_angle(s.facing + util.clamp(diff, -step, step))
end
-- }}}

return M

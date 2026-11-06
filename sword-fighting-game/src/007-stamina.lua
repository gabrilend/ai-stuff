-- 007-stamina.lua
--
-- How much the body has left. Stamina runs from 1 (fresh) to 0 (spent);
-- fatigue is 1 minus stamina. Actions spend it, rest restores it, and the
-- parry chance and the two trip rules are read from it here, as pure
-- functions of a soldier record and the configuration, so the documentation's
-- fatigue slider can show exactly what the game does.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}

-- A cost larger than what is left takes stamina to zero, never below.
-- {{{ function M.spend()
function M.spend(s, amount)
	s.stamina = math.max(0, s.stamina - amount)
end
-- }}}

-- Called once per tick after everything else. Swinging, guarding and
-- dodging spend rather than restore; standing still restores fastest.
-- {{{ function M.restore()
function M.restore(s, config, dt, moving)
	local c = config.stamina
	-- busy: the guard is the only busy state that costs by the second
	if s.guard then
		M.spend(s, c.guard_cost * dt)
		return
	end
	-- swinging or dodging: no rest, but no further cost either
	if s.swing or s.dodge then return end
	local rate = moving and c.restore or c.restore_still
	if moving then M.spend(s, c.walk_cost * dt) end
	s.stamina = math.min(1, s.stamina + rate * dt)
end
-- }}}

-- Nearly certain when fresh, falling with fatigue along a curve, and never
-- below the floor. Bushido flattens the curve, for armies without the armor
-- to rely on.
-- {{{ function M.parry_chance()
function M.parry_chance(stamina, config, bushido)
	local c = config.stamina
	local exponent = bushido and c.bushido_exponent or c.parry_exponent
	return math.max(c.parry_min, c.parry_max * stamina ^ exponent)
end
-- }}}

-- Backstepping while fatigued trips, always.
-- {{{ function M.backstep_trips()
function M.backstep_trips(s, config)
	return (1 - s.stamina) > config.stamina.trip_fatigue
end
-- }}}

-- Sidestepping while guarding trips one time in four; never otherwise. The
-- roll is only drawn while guarding, so unguarded sidesteps do not move the
-- movement stream at all.
-- {{{ function M.sidestep_trips()
function M.sidestep_trips(s, config, stream)
	if not s.guard then return false end
	return stream:chance(config.stamina.side_trip)
end
-- }}}

-- Down she goes: no movement, swing or guard until she gets up.
-- {{{ function M.trip()
function M.trip(s, config, battle)
	s.tripped = config.stamina.trip_time
	s.swing = false
	s.guard = false
	s.dodge = false
	s.vx, s.vy = 0, 0
	if battle then
		battle.counters.trips = battle.counters.trips + 1
		battle.events[#battle.events + 1] = { kind = "trip", who = s }
	end
end
-- }}}

return M

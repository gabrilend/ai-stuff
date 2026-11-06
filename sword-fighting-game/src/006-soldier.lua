-- 006-soldier.lua
--
-- One body on the field. Every soldier, the player's included, is the same
-- flat record; the player is a soldier with a hand on it. The fields are
-- listed in this file's .info.md page with their types.
--
-- The derived numbers (armor after thickness, walking share, awareness) are
-- worked out once here, when the soldier is made or refreshed after a perk,
-- and never per tick.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}

-- Thick armor adds this many rating points (the vision: "thicken for two
-- points, but you move slower"). Not a knob because it is the rule itself.
M.THICK_POINTS = 2

-- {{{ local function trait_set()
local function trait_set(list)
	local set = {}
	for _, name in ipairs(list) do set[name] = true end
	return set
end
-- }}}

-- `fields` gives id, team, battalion, slot_x, slot_y, x, y, facing.
-- {{{ function M.new()
function M.new(catalogue, config, unit_name, fields)
	local s = {
		id = fields.id, team = fields.team, battalion = fields.battalion,
		slot_x = fields.slot_x, slot_y = fields.slot_y,
		x = fields.x, y = fields.y, vx = 0, vy = 0,
		facing = fields.facing,
		cell_x = -1, cell_y = -1,
		stamina = 1, u = 0,
		lock = false, lock_next = false, lock_timer = 0,
		swing = false, last_side = "none", last_swing_time = -100,
		guard = false, open = 0, tripped = 0, stagger = 0,
		dodge = false, yield = false,
		was_backing = false, was_siding = false,
		alive = true, is_player = false,
		look_offset = 0, distance_walked = 0,
		hurt_flash = 0,
		extra_armor = 0, crit_chance = 0, thick_override = false,
		perk_traits = {},
		intent = { forward = 0, side = 0, guard = false, swing = false,
			u_delta = 0, dodge = false },
		mind = { state = "march", wait = 0, side = 0, harry = 0 },
	}
	M.become(s, catalogue, config, unit_name)
	s.health = s.health_max
	return s
end
-- }}}

-- Takes on a unit type: its weapon, health, armor and traits. Used when a
-- soldier is made and when a perk converts it.
-- {{{ function M.become()
function M.become(s, catalogue, config, unit_name)
	local unit = catalogue["unit-types"][unit_name]
	if not unit then error("no unit type named " .. tostring(unit_name)) end
	s.unit = unit_name
	s.unit_entry = unit
	s.weapon_name = s.weapon_override or unit.weapon
	s.weapon = catalogue.weapons[s.weapon_name]
	s.health_max = unit.health
	s.height = unit.height
	s.base_armor = unit.armor
	s.base_thickness = unit.thickness
	M.refresh(s, config)
end
-- }}}

-- Recomputes the derived numbers from the unit type and the perks laid on
-- the soldier (extra_armor, thick_override, perk_traits).
-- {{{ function M.refresh()
function M.refresh(s, config)
	s.traits = trait_set(s.unit_entry.traits)
	for name in pairs(s.perk_traits) do s.traits[name] = true end
	s.thickness = s.thick_override and 1 or s.base_thickness
	s.armor = s.base_armor + s.extra_armor + s.thickness * M.THICK_POINTS
	-- thick armor slows the walk; thin armor walks at the normal pace
	s.walk_mult = s.thickness == 1 and config.body.thick_walk or 1
	-- awareness narrows with armor, but never below what the eyes see
	local v = config.view
	s.awareness = math.max(v.fov, v.awareness - v.awareness_armor * s.armor)
end
-- }}}

-- {{{ function M.fatigue()
function M.fatigue(s)
	return 1 - s.stamina
end
-- }}}

-- Standing, alive, and not reeling: able to start a swing or a guard.
-- {{{ function M.can_act()
function M.can_act(s)
	return s.alive and s.tripped <= 0 and s.stagger <= 0
end
-- }}}

-- The unit vector the soldier faces, on the map.
-- {{{ function M.forward()
function M.forward(s)
	return math.cos(s.facing), math.sin(s.facing)
end
-- }}}

-- The unit vector to the soldier's right. Map y grows southward, so the
-- right of a soldier facing east (0) is south (0, 1).
-- {{{ function M.right()
function M.right(s)
	return -math.sin(s.facing), math.cos(s.facing)
end
-- }}}

return M

-- unit-types.lua - the unit types catalogue (201, 602)
--
-- Made by hand; read by src/004-catalogue.lua, which checks every field.
-- Each entry: the weapon it carries, health, armor rating points, thickness
-- (0 thin, 1 thick), drawn height (1 is normal), and traits the rules read.
--
-- Traits, and the rule that reads each:
--   always_critical        every hit is critical          (011-hit-resolution)
--   guard_while_advancing  guarding does not slow forward (008-movement)
--   stabs_only             every swing is a stab          (010-swings)
--   throws_from_front      throws when the enemy is near  (012-soldier-mind, 013-ranged)
--   shield                 a parry bonus against swords   (011-hit-resolution)
--   loose                  passes allies at full speed    (008-movement)

return {
	swordsman = {
		title     = "two-handed swordsman",
		weapon    = "zweihander",
		health    = 100,
		armor     = 1,
		thickness = 0,
		height    = 1.0,
		traits    = {},
	},
	mega_spearman = {
		title     = "mega spearman",
		weapon    = "spear",
		health    = 110,
		-- the maximum armor rating the perks reach (4), plus one for the shield
		armor     = 5,
		thickness = 0,
		height    = 1.05,
		traits    = { "stabs_only", "shield" },
	},
	beastwarrior = {
		title     = "beastwarrior",
		weapon    = "zweihander",
		health    = 150,
		armor     = 1,
		thickness = 0,
		height    = 1.5,
		traits    = { "always_critical", "guard_while_advancing" },
	},
	skirmisher = {
		title     = "skirmisher",
		weapon    = "zweihander",
		health    = 85,
		armor     = 0,
		thickness = 0,
		height    = 0.95,
		traits    = { "throws_from_front", "loose" },
	},
}

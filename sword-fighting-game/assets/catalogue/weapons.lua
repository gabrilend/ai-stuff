-- weapons.lua - the weapons catalogue (201)
--
-- Made by hand; read by src/004-catalogue.lua, which checks every field.
-- Each entry: reach (cells), swings (kinds it may make), damage per kind,
-- windup and recovery multipliers on the swing timings, the brick colour of
-- the blade, and its drawn length in metres.
--
-- The first release is two-handed swords. The spear is here because the mega
-- spearman perk carries one; the rest of the arsenal waits for 703.

return {
	zweihander = {
		title    = "two-handed sword",
		reach    = 1.6,
		swings   = { "stab", "slash", "overhead" },
		damage   = { stab = 24, slash = 30, overhead = 46 },
		windup   = 1.0,
		recovery = 1.0,
		brick_color = { 0.80, 0.82, 0.86 },
		length   = 1.45,
	},
	spear = {
		title    = "spear",
		reach    = 2.1,
		swings   = { "stab" },
		damage   = { stab = 26, slash = 0, overhead = 0 },
		windup   = 0.9,
		recovery = 0.9,
		brick_color = { 0.62, 0.46, 0.28 },
		length   = 2.1,
	},
	halberd = {
		title    = "halberd",
		reach    = 2.0,
		swings   = { "stab", "slash", "overhead" },
		damage   = { stab = 22, slash = 36, overhead = 50 },
		windup   = 1.15,
		recovery = 1.1,
		brick_color = { 0.70, 0.70, 0.74 },
		length   = 2.0,
	},
}

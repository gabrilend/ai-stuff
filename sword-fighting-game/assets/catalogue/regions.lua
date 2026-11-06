-- regions.lua - the kinds of ground a battle can be fought on (201, 504)
--
-- Made by hand; read by src/004-catalogue.lua. Each entry: the ground colour,
-- a walking multiplier, and how much the scenery builder scatters there.
--
-- The vision's world: most swamps were turned into little parks, though some
-- remain; the prairie is bisected by roads manned with fences.

return {
	meadow = {
		title        = "meadow",
		ground_color = { 0.42, 0.62, 0.30 },
		walk         = 1.0,
		stones       = 1.0,
		fences       = 0,
		puddles      = 0,
	},
	swamp_park = {
		title        = "swamp park",
		ground_color = { 0.34, 0.46, 0.30 },
		walk         = 0.8,
		stones       = 0.4,
		fences       = 0,
		puddles      = 14,
	},
	prairie = {
		title        = "prairie with fences",
		ground_color = { 0.72, 0.66, 0.38 },
		walk         = 1.05,
		stones       = 0.5,
		fences       = 6,
		puddles      = 0,
	},
	hills = {
		title        = "hills",
		ground_color = { 0.50, 0.56, 0.36 },
		walk         = 0.9,
		stones       = 1.8,
		fences       = 0,
		puddles      = 0,
	},
}

-- unit-types.lua - the example mod's unit type (604)
--
-- Made by hand to show the mod folder at work: a mod file adds entries by
-- new names and replaces entries that share a name. Enable it by adding
-- "example-clay-knights" to the mods list in config.lua.

return {
	clay_knight = {
		title     = "clay knight",
		weapon    = "zweihander",
		health    = 120,
		armor     = 3,
		thickness = 1,
		height    = 1.1,
		traits    = { "shield" },
	},
}

-- perks.lua - the example mod's perk (604)
--
-- Made by hand: a perk that converts three soldiers into the mod's clay
-- knights, offered in the command phase like any shipped perk.

return {
	clay_knights = {
		title   = "clay knights",
		text    = "three soldiers in thick brick armor with shields.",
		affects = 3,
		effect  = "convert_units",
		value   = "clay_knight",
		limit   = 2,
	},
}

-- perks.lua - the perks catalogue (201, 601)
--
-- Made by hand; read by src/004-catalogue.lua and applied by src/015-perks.lua.
-- Each entry: a title and a line of text for the command table, who it
-- affects ("all", or a count of soldiers), the effect (a row in the perk
-- effects table of 015-perks.lua), the effect's argument, and how many times
-- one side may take it.

return {
	mega_spearmen = {
		title   = "mega spearmen",
		text    = "four soldiers in maxed armor with spear and shield. They can only stab.",
		affects = 4,
		effect  = "convert_units",
		value   = "mega_spearman",
		limit   = 3,
	},
	beastwarriors = {
		title   = "beastwarriors",
		text    = "two massive soldiers. Every hit is critical; they guard while advancing.",
		affects = 2,
		effect  = "convert_units",
		value   = "beastwarrior",
		limit   = 3,
	},
	skirmishers = {
		title   = "skirmishers",
		text    = "four soldiers throw from the front rank, then slip back through the line.",
		affects = 4,
		effect  = "convert_units",
		value   = "skirmisher",
		limit   = 3,
	},
	halberds = {
		title   = "halberds",
		text    = "the contingent trades its swords for halberds: longer reach, heavier slashes.",
		affects = "all",
		effect  = "swap_weapon",
		value   = "halberd",
		limit   = 1,
	},
	riposte = {
		title   = "riposte",
		text    = "a parry is followed at once by a counter-stab.",
		affects = "all",
		effect  = "add_trait",
		value   = "riposte",
		limit   = 1,
	},
	harry = {
		title   = "harry",
		text    = "battalions strike, then step back together: in and out.",
		affects = "all",
		effect  = "add_trait",
		value   = "harry",
		limit   = 1,
	},
	bushido = {
		title   = "bushido",
		text    = "your armor is not so good, so you train: parrying tires you less.",
		affects = "all",
		effect  = "add_trait",
		value   = "bushido",
		limit   = 1,
	},
	trained_arc = {
		title   = "trained arc",
		text    = "together, as a battalion, you learn every arc: throw at range 1, 2 or 3.",
		affects = "all",
		effect  = "unlock_ranges",
		value   = 1,
		limit   = 1,
	},
	better_armor = {
		title   = "better armor",
		text    = "one more armor point for everyone.",
		affects = "all",
		effect  = "add_armor",
		value   = 1,
		limit   = 3,
	},
	thick_armor = {
		title   = "thick armor",
		text    = "two more armor points, but everyone walks slower.",
		affects = "all",
		effect  = "thicken",
		value   = 1,
		limit   = 1,
	},
	keen_edges = {
		title   = "keen edges",
		text    = "a further one-in-ten chance that any hit is critical.",
		affects = "all",
		effect  = "crit_chance",
		value   = 0.1,
		limit   = 3,
	},
}

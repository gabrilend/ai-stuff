-- 001-config.def.lua
--
-- The default of every knob in the game, laid out the way dwm's config.def.h
-- is: one knob per line, aligned, with a short comment saying what the number
-- means and in what unit. To change a knob, write config.lua at the project
-- root returning a table of the same shape holding only the knobs to change;
-- 002-util.lua lays it over these and stops on any name these do not have.
--
-- Every change to a default is written down in docs/balance-updates.md with
-- the reason, so the record of how the numbers moved is never lost.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

return {
	tick = {
		seconds         = 1 / 60,  -- one simulation step
		max_per_frame   = 8,       -- ticks a slow frame may catch up before time is dropped
		battle_limit    = 240,     -- simulated seconds before a battle is called a draw
	},

	field = {
		width           = 48,      -- cells east to west
		height          = 40,      -- cells north to south
		cell_metres     = 1.2,     -- one soldier wide
		battalion_wide  = 4,       -- soldiers across one battalion's front
		battalion_deep  = 3,       -- ranks in one battalion
		battalions      = 3,       -- battalions per contingent
		battalion_gap   = 2,       -- empty cells between battalions side by side
		deploy_margin   = 3,       -- cells between a contingent's back rank and its edge
		engage_range    = 4.0,     -- cells: a mind starts fighting within this
		lock_range      = 6.0,     -- cells: the U finds its target within this
		break_share     = 0.25,    -- a contingent with this share or fewer standing breaks
		wing_offset     = 6,       -- cells the enemy deploys sideways when it pushes off-axis
	},

	body = {
		walk_speed      = 1.6,     -- cells per second, forward
		back_speed      = 0.7,     -- share of walk speed when backstepping
		side_speed      = 0.8,     -- share of walk speed when sidestepping
		ally_pass       = 0.5,     -- share of speed when walking into an ally's cell
		yield_speed     = 1.4,     -- cells per second an ally yields at
		yield_time      = 0.35,    -- seconds a yield lasts
		dodge_length    = 1.0,     -- cells a dodge covers
		dodge_time      = 0.25,    -- seconds a dodge takes
		turn_rate       = 4.0,     -- radians per second a soldier turns toward its lock
		thick_walk      = 0.75,    -- share of walk speed in thick armor
		guard_walk      = 0.6,     -- share of walk speed while guarding (beastwarriors excepted)
		shield_walk     = 0.6,     -- share of walk speed behind a raised shield wall
		step_threshold  = 0.3,     -- a wish past this counts as a step begun
		radius          = 0.38,    -- cells: how wide a body is, for reach
		weight          = 0.35,    -- momentum per cell per second of approach
	},

	stamina = {
		swing_cost      = 0.07,    -- spent starting a stab or slash
		overhead_cost   = 0.14,    -- spent starting an overhead
		parry_cost      = 0.05,    -- spent by the parrier on a parry
		parried_cost    = 0.06,    -- spent by the attacker when parried
		dodge_cost      = 0.08,    -- spent per dodge
		guard_cost      = 0.03,    -- per second, holding the guard
		walk_cost       = 0.004,   -- per second, walking
		restore         = 0.07,    -- per second, when not swinging, guarding or dodging
		restore_still   = 0.12,    -- per second, when also standing still
		parry_max       = 0.95,    -- parry chance at full stamina
		parry_min       = 0.10,    -- parry chance never falls below this
		parry_exponent  = 1.6,     -- how steeply parry chance falls with fatigue
		bushido_exponent = 0.9,    -- the exponent for soldiers with the bushido trait
		trip_fatigue    = 0.6,     -- backstepping above this fatigue trips
		side_trip       = 0.25,    -- chance a guarded sidestep trips
		trip_time       = 1.6,     -- seconds lying down
	},

	sword = {
		u_sensitivity   = 0.004,   -- U travel per pixel of mouse motion
		bend_width      = 0.55,    -- |u| below this is the bend: a stab
		lock_switch     = 0.5,     -- seconds the lock takes to move to a nearer enemy
		strike_arc      = 1.1,     -- radians either side of facing a swing can reach
		flow_bonus      = 0.6,     -- momentum for a swing from the side opposite the last
		bend_bonus      = 0.25,    -- momentum for a stab after a slash
		overhead_bonus  = 0.5,     -- momentum an overhead always carries
		flow_window     = 1.6,     -- seconds after which the last swing's side is forgotten
	},

	swings = {
		-- windup and recovery in seconds, reach in cells added to the weapon's,
		-- damage as a multiplier of the weapon's damage for that kind
		stab            = { windup = 0.30, recovery = 0.35, reach = 0.3, damage = 1.0 },
		slash           = { windup = 0.40, recovery = 0.45, reach = 0.0, damage = 1.0 },
		overhead        = { windup = 0.75, recovery = 0.80, reach = 0.0, damage = 1.0 },
	},

	hits = {
		critical_momentum = 0.75,  -- momentum at or above this makes a hit critical
		critical_mult   = 1.75,    -- damage multiplier on a critical hit
		flank_angle     = 1.5708,  -- radians off facing beyond which a hit is a flank (90 degrees)
		behind_angle    = 2.3562,  -- radians off facing beyond which no parry is possible (135)
		armor_per_point = 0.12,    -- share of damage each armor point takes off
		armor_cap       = 0.75,    -- armor never takes off more than this share
		stagger_hit     = 0.45,    -- seconds reeling after being hit
		stagger_parried = 0.35,    -- seconds reeling after being parried
		shield_parry    = 0.10,    -- parry bonus with a shield, against swords
		shield_volley   = 0.55,    -- parry bonus behind a raised shield, against volleys
	},

	ranged = {
		battalion_length = 5,      -- cells: one battalion's depth plus the gap behind it
		default_range   = 3,       -- battalion lengths every volley flies without the trained arc
		flight_time     = 1.4,     -- seconds a dart is in the air
		spread          = 1.2,     -- cells of scatter around the landing point
		hit_radius      = 0.6,     -- cells: a dart landing this close hits
		damage          = 22,      -- damage per dart
		cooldown        = 6.0,     -- seconds between volleys
		arc_height      = 6.0,     -- cells: the top of the arc, for drawing
	},

	mind = {
		reaction        = 0.25,    -- seconds a mind takes to answer what it sees
		caution         = 0.25,    -- below this stamina a mind recovers instead of swinging
		comfort         = 0.6,     -- above this stamina a recovering mind fights again
		guard_chance    = 0.75,    -- chance a mind guards when its lock winds up
		harry_back      = 0.8,     -- seconds a harrying battalion steps back
		volley_chance   = 0.35,    -- per second, chance the enemy commander throws when ready
		shield_chance   = 0.5,     -- chance the enemy commander raises shields under a volley
	},

	round = {
		result_pause    = 3.0,     -- seconds the result is shown before the next command phase
		perk_cards      = 3,       -- perks offered each command phase
	},

	campaign = {
		width           = 5,       -- regions across
		height          = 5,       -- regions down
		straight_weight = 3,       -- how much more the enemy prefers to head straight for home
	},

	view = {
		fov             = 90,      -- degrees, horizontal, first person
		awareness       = 160,     -- degrees a soldier knows about without turning
		awareness_armor = 6,       -- degrees of awareness lost per armor point
		eye_height      = 1.62,    -- metres
		eye_back        = 0.32,    -- metres the eye sits behind the shoulders
		third_pitch     = 0.9,     -- radians the commander's camera looks down
		third_distance  = 30,      -- metres from the camera to the contingent's centre
		third_fov       = 60,      -- degrees, horizontal, third person
		camera_slide    = 12,      -- metres per second the commander's camera slides
		edge_glow       = 0.35,    -- strength of the awareness glow at the screen edges
		fatigue_bob     = 0.04,    -- metres of view bob at full fatigue
		cat_faces       = 9,       -- cat faces hidden in the scenery
		stones          = 140,     -- loose stones in the scenery
		clouds          = 7,       -- clouds overhead
		team_colors     = {
			{ 0.78, 0.18, 0.14 },  -- team 1: brick red
			{ 0.16, 0.36, 0.78 },  -- team 2: brick blue
		},
		clay_color      = { 0.86, 0.66, 0.50 },  -- the clay the bodies are pressed from
		sky_top         = { 0.42, 0.62, 0.86 },
		sky_bottom      = { 0.86, 0.90, 0.92 },
	},

	-- Mods enabled, in the order they are laid over the catalogue (604).
	mods = {},

	-- Key bindings, as dwm's keys[]: { key, action, argument }.
	-- Actions are rows in the front desk's action table (029-the-front-desk.lua).
	keys = {
		{ "w",       "move",        "forward"  },
		{ "s",       "move",        "back"     },
		{ "a",       "move",        "left"     },
		{ "d",       "move",        "right"    },
		{ "lshift",  "dodge",       true       },
		{ "space",   "overhead",    true       },
		{ "lalt",    "free_look",   true       },
		{ "tab",     "switch_view", true       },
		{ "1",       "range",       1          },
		{ "2",       "range",       2          },
		{ "3",       "range",       3          },
		{ "y",       "be_affected", true       },
		{ "n",       "be_affected", false      },
		{ "up",      "push_key",    "N"        },
		{ "down",    "push_key",    "S"        },
		{ "left",    "push_key",    "W"        },
		{ "right",   "push_key",    "E"        },
		{ "kp8",     "push_key",    "N"        },
		{ "kp9",     "push_key",    "NE"       },
		{ "kp6",     "push_key",    "E"        },
		{ "kp3",     "push_key",    "SE"       },
		{ "kp2",     "push_key",    "S"        },
		{ "kp1",     "push_key",    "SW"       },
		{ "kp4",     "push_key",    "W"        },
		{ "kp7",     "push_key",    "NW"       },
		{ "return",  "begin_round", true       },
		{ "f12",     "screenshot",  "f12"      },
		{ "escape",  "quit",        true       },
	},

	-- Mouse buttons, the same way: { button, mode, action }.
	buttons = {
		{ 1, "first_person", "swing"   },
		{ 2, "first_person", "guard"   },
		{ 1, "third_person", "volley"  },
		{ 2, "third_person", "shields" },
		{ 1, "command",      "pick"    },
	},
}

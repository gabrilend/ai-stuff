# Issue 702f: WC3-Mode Profession Configuration

**Phase:** 7 - Gameplay: Core Mechanics
**Type:** Feature
**Priority:** Medium
**Dependencies:** 702a (Core), 702b (Gathering), 702c (Crafting), 702d (Recipes)

---

## Current Behavior

The profession engine is generic. No WC3-specific configuration exists for
simplified ability-based gathering/production that matches RTS gameplay.

---

## Intended Behavior

A WC3-style profession configuration that maps to:
- Unit abilities (Gather, Repair, Build)
- Building production (Train, Research, Upgrade)
- Simple skill levels (0-5 or binary)
- Race-specific variations

---

## Design Philosophy

```
┌─────────────────────────────────────────────────────────────────┐
│                    WC3 PROFESSION MAPPING                        │
│                                                                  │
│  ┌─────────────┐        ┌─────────────┐        ┌─────────────┐ │
│  │   ABILITY   │   ──▶  │ PROFESSION  │   ──▶  │   ACTION    │ │
│  │             │        │             │        │             │ │
│  │ Gather Gold │        │ Mining      │        │ Mine node   │ │
│  │ Gather Lumb │        │ Lumber      │        │ Chop tree   │ │
│  │ Repair      │        │ Repair      │        │ Fix bldg    │ │
│  │ Build       │        │ Construction│        │ Create bldg │ │
│  └─────────────┘        └─────────────┘        └─────────────┘ │
│                                                                  │
│  Abilities ARE professions in WC3 mode.                         │
│  If unit has ability, it has the profession.                    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## WC3 Profession Types

```lua
-- {{{ WC3 profession definitions
WC3_PROFESSIONS = {
    -- {{{ Gold Gathering
    gold_harvest = {
        id = "gold_harvest",
        type = "gathering",
        display_name = "Harvest Gold",

        -- Ability mapping
        ability_id = "Ahrl",  -- WC3 Harvest (Lumber/Gold)
        order_id = "harvest",

        -- No skill levels - binary (has or doesn't have)
        skill_max = 1,
        skill_required = 0,

        -- Resource parameters
        resource_type = "gold",
        base_yield = 10,
        trip_capacity = 10,

        -- Upgrades affect yield
        upgrades = {},  -- Gold harvesting rarely has upgrades
    },
    -- }}}

    -- {{{ Lumber Gathering
    lumber_harvest = {
        id = "lumber_harvest",
        type = "gathering",
        display_name = "Harvest Lumber",

        ability_id = "Ahrl",
        order_id = "harvest",

        skill_max = 1,
        skill_required = 0,

        resource_type = "lumber",
        base_yield = 10,
        trip_capacity = 10,

        -- Race-specific variations
        race_variations = {
            night_elf = {
                -- Wisps don't return, they entangle
                return_required = false,
                yield_rate = 5,  -- Lumber per second
            },
            undead = {
                -- Ghouls carry less but attack
                trip_capacity = 10,
                can_attack_trees = false,
            },
        },

        -- Upgrades
        upgrades = {
            {id = "improved_lumber_harvesting", bonus_yield = 10},
            {id = "advanced_lumber_harvesting", bonus_yield = 10},
        },
    },
    -- }}}

    -- {{{ Repair
    repair = {
        id = "repair",
        type = "service",
        display_name = "Repair",

        ability_id = "Arep",
        order_id = "repair",

        skill_max = 1,
        skill_required = 0,

        -- Repair parameters
        repair_rate = 35,  -- HP per second base
        cost_factor = 0.35,  -- 35% of build cost to fully repair

        -- Race variations
        race_variations = {
            undead = {
                -- Acolytes can't repair, buildings regenerate
                enabled = false,
            },
            night_elf = {
                -- Wisps repair but cost mana
                mana_cost = true,
            },
        },
    },
    -- }}}

    -- {{{ Construction
    construction = {
        id = "construction",
        type = "service",
        display_name = "Build",

        ability_id = "Abui",  -- Build
        order_id = "build",

        skill_max = 1,

        -- Race construction styles
        race_variations = {
            human = {
                style = "standard",  -- Worker builds, stays to finish
                multiple_workers = true,  -- Multiple can speed up
            },
            orc = {
                style = "standard",
                multiple_workers = true,
            },
            undead = {
                style = "summon",  -- Acolyte summons, can leave
                haunt_required = true,  -- Must be on blight
            },
            night_elf = {
                style = "uproot",  -- Wisp sacrifices to create
                consume_worker = true,
            },
        },
    },
    -- }}}

    -- {{{ Sacrifice (Undead)
    sacrifice = {
        id = "sacrifice",
        type = "service",
        display_name = "Sacrifice",

        ability_id = "Asac",
        order_id = "sacrifice",

        skill_max = 1,

        -- Sacrifice produces resources or effects
        yield = {
            gold = 0,
            building_speed = 1.0,  -- Speeds up construction
        },
    },
    -- }}}
}
-- }}}
```

---

## Building Professions

Buildings in WC3 act as profession "stations" that produce:

```lua
-- {{{ WC3 building professions
WC3_BUILDING_PROFESSIONS = {
    -- {{{ Barracks (Training)
    barracks = {
        id = "barracks",
        type = "training",
        display_name = "Train",

        profession = "military_training",

        -- Units that can be trained
        trains = {
            {unit = "footman", cost = {gold = 135}, time = 20},
            {unit = "rifleman", cost = {gold = 205, lumber = 30}, time = 26},
            {unit = "knight", cost = {gold = 245, lumber = 60}, time = 45},
        },

        -- Rally point for produced units
        has_rally = true,
    },
    -- }}}

    -- {{{ Armory (Upgrades)
    armory = {
        id = "armory",
        type = "research",
        display_name = "Research",

        profession = "blacksmithing",

        -- Upgrades that can be researched
        researches = {
            {
                id = "iron_forged_swords",
                cost = {gold = 100, lumber = 50},
                time = 60,
                effect = "melee_attack +1",
                levels = 3,
            },
            {
                id = "steel_armor",
                cost = {gold = 125, lumber = 75},
                time = 75,
                effect = "armor +2",
                levels = 3,
            },
        },
    },
    -- }}}

    -- {{{ Shop (Purchasing)
    shop = {
        id = "shop",
        type = "shop",
        display_name = "Purchase",

        profession = "merchant",

        -- Items for sale
        stock = {
            {item = "potion_of_healing", cost = {gold = 150}, stock = 2, restock = 30},
            {item = "potion_of_mana", cost = {gold = 100}, stock = 2, restock = 30},
            {item = "scroll_of_protection", cost = {gold = 150}, stock = 1, restock = 60},
        },

        -- Hero only items
        hero_only = true,
    },
    -- }}}

    -- {{{ Workshop (Engineering)
    workshop = {
        id = "workshop",
        type = "training",
        display_name = "Build",

        profession = "engineering",

        trains = {
            {unit = "flying_machine", cost = {gold = 90, lumber = 30}, time = 13},
            {unit = "mortar_team", cost = {gold = 180, lumber = 70}, time = 32},
            {unit = "siege_engine", cost = {gold = 195, lumber = 60}, time = 45},
        },

        researches = {
            {id = "flak_cannons", cost = {gold = 100, lumber = 150}, time = 40},
            {id = "flying_machine_bombs", cost = {gold = 150, lumber = 100}, time = 35},
        },
    },
    -- }}}
}
-- }}}
```

---

## Simplified Skill System

```lua
-- {{{ WC3 skill levels (if used)
-- Most WC3 "skills" are binary (have ability or not).
-- Some maps use simple 1-5 levels for custom systems.
WC3_SKILL_SYSTEM = {
    -- Binary mode (default)
    binary = {
        max_level = 1,
        display = "Enabled/Disabled",
    },

    -- Simple progression (custom maps)
    leveled = {
        max_level = 5,
        level_names = {"Novice", "Apprentice", "Journeyman", "Expert", "Master"},
        unlock_method = "experience",  -- or "research", "gold"
    },
}
-- }}}
```

---

## Upgrade System

WC3 upgrades are the primary "profession advancement":

```lua
-- {{{ Upgrade-based profession progression
WC3_UPGRADE_PROFESSIONS = {
    -- Lumber harvesting upgrades
    lumber_progression = {
        profession = "lumber_harvest",
        upgrades = {
            {
                id = "improved_lumber",
                building = "lumber_mill",
                cost = {gold = 100, lumber = 50},
                time = 60,
                effect = {yield_bonus = 10},
            },
            {
                id = "advanced_lumber",
                building = "lumber_mill",
                requires = {"improved_lumber"},
                cost = {gold = 175, lumber = 100},
                time = 75,
                effect = {yield_bonus = 10},
            },
        },
    },

    -- Weapon upgrades
    weapon_progression = {
        profession = "blacksmithing",
        upgrades = {
            {
                id = "iron_swords",
                building = "armory",
                cost = {gold = 100, lumber = 50},
                time = 60,
                effect = {melee_damage = 1},
            },
            {
                id = "steel_swords",
                building = "armory",
                requires = {"iron_swords"},
                cost = {gold = 175, lumber = 100},
                time = 75,
                effect = {melee_damage = 1},
            },
            {
                id = "mithril_swords",
                building = "armory",
                requires = {"steel_swords"},
                cost = {gold = 250, lumber = 150},
                time = 90,
                effect = {melee_damage = 1},
            },
        },
    },
}
-- }}}
```

---

## Race-Specific Configurations

```lua
-- {{{ Race profession sets
WC3_RACE_PROFESSIONS = {
    human = {
        worker = "peasant",
        gather = {"gold_harvest", "lumber_harvest"},
        service = {"repair", "construction"},
        buildings = {
            armory = "blacksmithing",
            workshop = "engineering",
            arcane_sanctum = "enchanting",
        },
    },

    orc = {
        worker = "peon",
        gather = {"gold_harvest", "lumber_harvest"},
        service = {"repair", "construction"},
        buildings = {
            war_mill = "blacksmithing",
            beastiary = "beast_training",
            spirit_lodge = "shamanism",
        },
    },

    undead = {
        worker = "acolyte",
        gather = {"gold_harvest"},  -- No lumber (ghouls do that)
        service = {"construction", "sacrifice"},  -- No repair
        special = {
            ghoul = {"lumber_harvest", "cannibalize"},
        },
        buildings = {
            graveyard = "necromancy",
            slaughterhouse = "beast_training",
        },
    },

    night_elf = {
        worker = "wisp",
        gather = {"lumber_harvest"},  -- Special lumber
        service = {"repair", "construction"},  -- Wisp sacrifice
        special = {
            -- Ancient buildings self-harvest
            ancients = {"self_harvest"},
        },
        buildings = {
            hunters_hall = "beast_training",
            ancient_of_lore = "druidism",
        },
    },
}
-- }}}
```

---

## WC3 Mode Configuration

```lua
-- {{{ Main WC3 mode config
WC3_PROFESSION_CONFIG = {
    -- Mode identifier
    mode = "wc3",

    -- Skill system
    skill_system = "binary",       -- or "leveled" for custom maps
    skill_max = 1,                 -- Ignored if binary

    -- Profession assignment
    profession_source = "ability",  -- Abilities define professions
    ability_mapping = true,

    -- No trainer system
    trainers_required = false,
    tier_training = false,

    -- Upgrades are the progression
    upgrade_progression = true,
    upgrade_buildings = true,

    -- Race-specific rules
    race_variations = true,

    -- UI presentation
    ui_style = "wc3",
    show_ability_icons = true,
    show_upgrade_buttons = true,

    -- Resource system
    resources = {"gold", "lumber", "food"},
    upkeep_system = true,
}
-- }}}
```

---

## API Extensions

```lua
-- WC3-specific profession functions
local wc3_prof = require("runtime.configs.wc3_profession")

-- Ability-based profession check
wc3_prof.has_profession_ability(unit, profession)
wc3_prof.get_professions_from_abilities(unit)

-- Gathering
wc3_prof.get_gather_rate(unit, resource_type)
wc3_prof.get_carry_capacity(unit, resource_type)
wc3_prof.apply_gather_upgrades(unit, resource_type)

-- Buildings
wc3_prof.get_trainable_units(building)
wc3_prof.get_researchable_upgrades(building)
wc3_prof.can_research(building, upgrade_id)
wc3_prof.start_research(building, upgrade_id)

-- Race variations
wc3_prof.get_race_config(race)
wc3_prof.apply_race_modifiers(unit, profession)
```

---

## Events

```lua
events.register("EVENT_WC3_HARVEST_COMPLETE")   -- Resource returned
events.register("EVENT_WC3_REPAIR_TICK")        -- Building repaired
events.register("EVENT_WC3_TRAIN_START")        -- Unit training begun
events.register("EVENT_WC3_TRAIN_COMPLETE")     -- Unit produced
events.register("EVENT_WC3_RESEARCH_START")     -- Upgrade begun
events.register("EVENT_WC3_RESEARCH_COMPLETE")  -- Upgrade finished
```

---

## Acceptance Criteria

- [ ] Worker abilities map to professions
- [ ] Gold and lumber harvesting work per-race
- [ ] Repair ability functions
- [ ] Building construction works (all 4 styles)
- [ ] Upgrades affect profession output
- [ ] Building production (train/research) works
- [ ] Shop purchasing works
- [ ] Race-specific variations applied
- [ ] WC3-style UI integration points exist
- [ ] Events fire for all actions
- [ ] Unit tests for WC3 profession logic

---

## Notes

The WC3 configuration flattens the profession system:
- Abilities = Professions (no learning)
- Upgrades = Progression (no skill-ups)
- Buildings = Stations (no trainers)

This mapping allows the same engine to power:
1. Authentic WC3 gameplay
2. Custom maps with WC3-style workers
3. Hybrid modes (WC3 base + WoW elements)

The key insight: WC3's "research" is WoW's "recipe learning" at the race level.
An Armory upgrade is teaching all Footmen a new "recipe" simultaneously.

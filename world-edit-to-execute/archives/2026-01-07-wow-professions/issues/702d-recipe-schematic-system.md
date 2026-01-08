# Issue 702d: Recipe and Schematic System

**Phase:** 7 - Gameplay: Core Mechanics
**Type:** Feature
**Priority:** High
**Dependencies:** 702a (Core), 406 (Resources)

---

## Current Behavior

No recipe or schematic system. Crafting professions (702c) need a way to define
what can be made, what materials are required, and how recipes are learned.

---

## Intended Behavior

A data-driven recipe system that defines all craftable items:

```
┌─────────────────────────────────────────────────────────────────┐
│                      RECIPE SYSTEM                               │
│                                                                  │
│  ┌────────────────┐    ┌────────────────┐    ┌──────────────┐  │
│  │ Recipe Registry│───▶│ Recipe Instance│───▶│ Crafted Item │  │
│  │                │    │                │    │              │  │
│  │ - ID           │    │ - Known by     │    │ - Quality    │  │
│  │ - Profession   │    │ - Cooldowns    │    │ - Properties │  │
│  │ - Materials    │    │ - Craft count  │    │ - Bound to   │  │
│  │ - Output       │    │                │    │              │  │
│  └────────────────┘    └────────────────┘    └──────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Recipe Definition Structure

```lua
-- {{{ Recipe schema
local recipe_schema = {
    -- Identity
    id = "iron_sword",
    name = "Iron Sword",
    description = "A sturdy sword forged from iron bars.",

    -- Requirements
    profession = "blacksmithing",
    skill_required = 100,
    skill_difficulty = {
        orange = 100,   -- Always skill-up
        yellow = 115,   -- Usually skill-up
        green = 130,    -- Sometimes skill-up
        gray = 145,     -- Never skill-up
    },

    -- Station requirements
    station = "forge",           -- nil = no station needed
    tool = "blacksmith_hammer",  -- nil = bare hands

    -- Materials (consumed on craft)
    reagents = {
        { item = "iron_bar", count = 4 },
        { item = "coal", count = 2 },
        { item = "leather_strip", count = 1 },
    },

    -- Optional reagents (modify output)
    optional_reagents = {
        { item = "sharpening_stone", effect = "+5 damage" },
        { item = "gem_socket", effect = "add gem slot" },
    },

    -- Output
    output = {
        item = "iron_sword",
        count = 1,
        chance = 1.0,           -- 100% success
    },

    -- Secondary outputs (byproducts)
    byproducts = {
        { item = "metal_scrap", count = 1, chance = 0.2 },
    },

    -- Crafting time
    cast_time = 3.0,            -- Seconds to craft
    cooldown = 0,               -- Seconds between crafts (0 = none)
    shared_cooldown = nil,      -- Cooldown category

    -- Learning
    source = "trainer",         -- trainer, drop, quest, discovery, vendor
    trainer_cost = { gold = 500 },
    discovery_base = nil,       -- Recipe that can discover this

    -- Flags
    flags = {
        bind_on_pickup = false,
        bind_on_equip = true,
        unique = false,         -- Only one output can exist
        questitem = false,
        seasonal = false,       -- Only available during events
    },

    -- WC3 compatibility
    wc3_mapping = {
        ability = nil,          -- WC3 ability ID if applicable
        upgrade = nil,          -- WC3 upgrade ID if applicable
    },
}
-- }}}
```

---

## Recipe Categories

```lua
RECIPE_CATEGORY = {
    -- Crafting categories
    WEAPON = "weapon",
    ARMOR = "armor",
    CONSUMABLE = "consumable",
    ENHANCEMENT = "enhancement",
    CONTAINER = "container",
    TRADE_GOODS = "trade_goods",
    DEVICE = "device",
    MOUNT = "mount",
    PET = "pet",

    -- Processing categories
    SMELT = "smelt",            -- Ore -> Bars
    REFINE = "refine",          -- Raw -> Processed
    TRANSMUTE = "transmute",    -- Material conversion
    DISENCHANT = "disenchant",  -- Item -> Materials
}
```

---

## Schematic Learning System

Schematics are the learnable form of recipes:

```lua
-- {{{ Schematic component
ecs.register_component("known_recipes", {
    -- Maps profession -> list of known recipe IDs
    recipes = {},

    -- Discovery progress (for discovery-type recipes)
    discovery_progress = {},

    -- Recipe statistics
    craft_counts = {},          -- recipe_id -> times crafted
    first_craft_times = {},     -- recipe_id -> timestamp
})
-- }}}

-- {{{ Learning functions
function recipes.learn(entity, recipe_id)
    -- Validate recipe exists
    -- Validate profession requirement met
    -- Add to known_recipes
    -- Fire EVENT_RECIPE_LEARNED
end

function recipes.unlearn(entity, recipe_id)
    -- Remove from known_recipes
    -- Fire EVENT_RECIPE_UNLEARNED
end

function recipes.knows(entity, recipe_id)
    -- Check if entity knows recipe
    return boolean
end
-- }}}
```

---

## Recipe Sources

```lua
RECIPE_SOURCE = {
    -- {{{ Trainer
    -- Purchased from profession trainer NPC
    TRAINER = {
        type = "trainer",
        requires_standing = false,  -- May require reputation
        cost = { gold = 0 },
        auto_learn = false,        -- Some are auto-learned at skill level
    },
    -- }}}

    -- {{{ Drop
    -- Dropped from mobs, found in containers
    DROP = {
        type = "drop",
        drop_table = "world_drop_recipes",
        bind_on_pickup = true,     -- Schematic item binds
    },
    -- }}}

    -- {{{ Quest
    -- Reward from completing quests
    QUEST = {
        type = "quest",
        quest_id = nil,
        auto_learn = true,         -- Learned immediately on quest complete
    },
    -- }}}

    -- {{{ Discovery
    -- Randomly discovered while crafting related recipe
    DISCOVERY = {
        type = "discovery",
        base_recipe = nil,         -- Must be crafting this to discover
        chance = 0.05,             -- 5% per craft
        skill_floor = 0,           -- Min skill to have chance
    },
    -- }}}

    -- {{{ Vendor
    -- Purchased from vendor (limited stock)
    VENDOR = {
        type = "vendor",
        vendor_id = nil,
        stock = 1,                 -- Limited quantity
        restock_time = 86400,      -- Seconds (0 = never)
    },
    -- }}}

    -- {{{ World
    -- Found in specific world location
    WORLD = {
        type = "world",
        location = nil,
        respawn_time = 3600,
    },
    -- }}}
}
```

---

## Skill Difficulty Colors

The classic WoW skill-up color system:

```lua
-- {{{ Difficulty calculation
function recipes.get_difficulty_color(skill_level, recipe)
    local diff = recipe.skill_difficulty

    if skill_level < diff.orange then
        return "red"     -- Cannot craft
    elseif skill_level < diff.yellow then
        return "orange"  -- Always skill-up
    elseif skill_level < diff.green then
        return "yellow"  -- High skill-up chance
    elseif skill_level < diff.gray then
        return "green"   -- Low skill-up chance
    else
        return "gray"    -- No skill-up
    end
end

function recipes.get_skillup_chance(skill_level, recipe)
    local color = recipes.get_difficulty_color(skill_level, recipe)
    local chances = {
        red = 0,
        orange = 1.0,
        yellow = 0.75,
        green = 0.25,
        gray = 0,
    }
    return chances[color] or 0
end
-- }}}
```

---

## Recipe Registry API

```lua
local recipes = require("runtime.systems.recipes")

-- {{{ Registration
recipes.register(recipe_definition)
recipes.register_bulk(recipe_table)
recipes.unregister(recipe_id)
-- }}}

-- {{{ Queries
recipes.get(recipe_id)
recipes.get_all_for_profession(profession_id)
recipes.get_learnable_at_skill(profession_id, skill_level)
recipes.get_by_output(item_id)
recipes.search(filter_fn)
-- }}}

-- {{{ Entity operations
recipes.learn(entity, recipe_id)
recipes.unlearn(entity, recipe_id)
recipes.knows(entity, recipe_id)
recipes.get_known(entity, profession_id)
recipes.get_craftable(entity, profession_id)  -- Known + have materials
-- }}}

-- {{{ Crafting integration
recipes.can_craft(entity, recipe_id)
recipes.get_missing_reagents(entity, recipe_id)
recipes.calculate_output(entity, recipe_id, optional_reagents)
-- }}}
```

---

## Events

```lua
events.register("EVENT_RECIPE_LEARNED")    -- Recipe added to known
events.register("EVENT_RECIPE_UNLEARNED")  -- Recipe removed
events.register("EVENT_RECIPE_DISCOVERED") -- Random discovery
events.register("EVENT_RECIPE_UNLOCKED")   -- Skill reached for trainer recipe
```

---

## Recipe Data Files

Recipes should be loadable from data files:

```lua
-- data/recipes/blacksmithing.lua
return {
    -- Apprentice (1-75)
    {
        id = "rough_sharpening_stone",
        profession = "blacksmithing",
        skill_required = 1,
        reagents = {{ item = "rough_stone", count = 1 }},
        output = { item = "rough_sharpening_stone", count = 1 },
    },
    {
        id = "copper_bar",
        category = "smelt",
        profession = "blacksmithing",
        skill_required = 1,
        reagents = {{ item = "copper_ore", count = 2 }},
        output = { item = "copper_bar", count = 1 },
    },
    -- ... hundreds more
}
```

---

## WC3 Mode Recipes

In WC3 mode, recipes map to upgrades and shop items:

```lua
WC3_RECIPE_MAPPING = {
    -- Armory upgrades as "recipes"
    {
        id = "wc3_iron_forged_swords",
        profession = "armory",
        skill_required = 0,
        station = "armory",
        reagents = {
            { resource = "gold", count = 100 },
            { resource = "lumber", count = 50 },
        },
        output = { upgrade = "iron_forged_swords" },
        cast_time = 60,  -- Research time
    },

    -- Shop purchases as instant "crafts"
    {
        id = "wc3_buy_healing_salve",
        profession = "shop",
        skill_required = 0,
        station = "shop",
        reagents = {
            { resource = "gold", count = 100 },
        },
        output = { item = "healing_salve", count = 1 },
        cast_time = 0,  -- Instant
    },
}
```

---

## Acceptance Criteria

- [x] Recipe definitions follow consistent schema
- [x] Recipes can be registered and queried
- [x] Entities can learn/unlearn recipes
- [x] Skill difficulty colors calculate correctly
- [x] Recipe sources (trainer, drop, etc.) work (constants defined)
- [x] Discovery system randomly teaches recipes
- [ ] Recipes loadable from data files (deferred to data loading phase)
- [ ] WC3 upgrade/shop mapping works (schema supports it, needs 702f)
- [x] Events fire for learning and discovery
- [x] Unit tests for recipe calculations

---

## Implementation Notes

Implementation completed 2026-01-07.

### Files Created

- `src/runtime/systems/recipes.lua` - Recipe and schematic system
- `src/tests/test_recipes.lua` - Unit tests (35 tests, all passing)

### Features Implemented

1. **Recipe Registry**
   - `register(definition)` - Register with validation and defaults
   - `register_bulk(list)` - Batch registration
   - `unregister(id)` - Remove recipe
   - `get(id)`, `get_all()` - Basic retrieval

2. **Query System**
   - `get_all_for_profession(id)` - Filter by profession
   - `get_learnable_at_skill(profession, skill)` - Skill-gated recipes
   - `get_by_output(item_id)` - Find by crafted item
   - `get_by_category(category)` - Filter by category
   - `search(filter_fn)` - Custom filtering

3. **Difficulty System**
   - `get_difficulty_color(skill, recipe)` - Red/orange/yellow/green/gray
   - `get_skillup_chance(skill, recipe)` - 0%/100%/75%/25%/0%
   - Auto-generated difficulty thresholds from skill_required

4. **Entity Recipe Tracking**
   - `learn(entity, recipe_id)` - Teach recipe
   - `unlearn(entity, recipe_id)` - Forget recipe
   - `knows(entity, recipe_id)` - Check if known
   - `get_known(entity, profession)` - List known recipes
   - `can_craft(entity, recipe_id)` - Validates skill + knowledge

5. **Statistics & Discovery**
   - `record_craft(entity, recipe_id)` - Track craft counts
   - `get_craft_count(entity, recipe_id)` - Query stats
   - `try_discovery(entity, base_recipe)` - Random recipe discovery

6. **Events**
   - `RECIPE_LEARNED`, `RECIPE_UNLEARNED`, `RECIPE_DISCOVERED`, `RECIPE_UNLOCKED`

### Test Summary

| Category | Tests |
|----------|-------|
| Recipe Registration | 7 |
| Recipe Queries | 8 |
| Skill Difficulty | 7 |
| Entity Recipe Learning | 7 |
| Crafting Preparation | 4 |
| Craft Statistics | 2 |
| **Total** | **35** |

### Deferred Items

- **Data file loading**: Recipes can be registered programmatically; file loading is a data pipeline concern
- **WC3 mapping**: Schema supports `wc3_mapping` field; implementation in 702f

---

## Notes

The recipe system is the "database" that drives crafting. Good recipe design:
- Clear material costs (predictable input)
- Meaningful skill progression (orange -> gray)
- Multiple learning paths (trainer vs drop vs discovery)
- WC3 compatibility through upgrade mapping

Recipe data will likely be the largest data set in the game, with hundreds
of entries per profession. The loading system should handle this efficiently.

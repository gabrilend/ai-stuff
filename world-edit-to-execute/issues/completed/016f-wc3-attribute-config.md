# Issue 016f: WC3 Attribute Config

## Current Behavior

WC3 attributes are hardcoded in hero.lua without proper schema definitions. No formal relationship exists between primary stats and derived values.

## Intended Behavior

A complete WC3 attribute configuration that:
- Defines all primary attributes (Strength, Agility, Intelligence)
- Defines derived attributes (Attack Damage, Armor, Mana)
- Follows WC3 formulas for stat-to-combat conversion
- Supports hero class stat gains per level
- Integrates with the attribute registry system

## Suggested Implementation Steps

### 1. WC3 Primary Attributes

```lua
-- src/libs/attributes/configs/wc3.lua

local registry = require("src.libs.attributes.registry")
local ATTR_TYPE = require("src.libs.attributes.schema").ATTR_TYPE
local ATTR_FLAGS = require("src.libs.attributes.schema").ATTR_FLAGS

-- {{{ WC3 Attribute Definitions

local PERSISTED_MODIFIABLE = ATTR_FLAGS.PERSISTED + ATTR_FLAGS.MODIFIABLE

-- {{{ Core Unit Attributes
local WC3_CORE = {
    -- Unit identity
    level = {
        type = ATTR_TYPE.INTEGER,
        min = 1, max = 25,  -- Heroes cap at 25 in WC3
        default = 1,
        flags = ATTR_FLAGS.PERSISTED,
    },
    experience = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 0,
        flags = ATTR_FLAGS.PERSISTED,
    },

    -- Primary stats
    strength = {
        type = ATTR_TYPE.INTEGER,
        min = 0, max = 999,
        default = 10,
        flags = PERSISTED_MODIFIABLE,
    },
    agility = {
        type = ATTR_TYPE.INTEGER,
        min = 0, max = 999,
        default = 10,
        flags = PERSISTED_MODIFIABLE,
    },
    intelligence = {
        type = ATTR_TYPE.INTEGER,
        min = 0, max = 999,
        default = 10,
        flags = PERSISTED_MODIFIABLE,
    },

    -- Primary stat type determines which stat gives attack damage
    primary_stat = {
        type = ATTR_TYPE.ENUM,
        enum_values = { "strength", "agility", "intelligence" },
        default = "strength",
        flags = ATTR_FLAGS.PERSISTED,
    },
}
-- }}}

-- {{{ Health and Mana
local WC3_RESOURCES = {
    -- Base values (before stat bonuses)
    base_health = {
        type = ATTR_TYPE.INTEGER,
        min = 1,
        default = 100,
        flags = PERSISTED_MODIFIABLE,
    },
    base_mana = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 0,  -- Non-casters have 0 base mana
        flags = PERSISTED_MODIFIABLE,
    },

    -- Current values
    health = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 100,
        flags = ATTR_FLAGS.PERSISTED,
    },
    mana = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 0,
        flags = ATTR_FLAGS.PERSISTED,
    },

    -- Regeneration rates (per second)
    base_health_regen = {
        type = ATTR_TYPE.FLOAT,
        min = 0,
        default = 0.25,
        flags = PERSISTED_MODIFIABLE,
    },
    base_mana_regen = {
        type = ATTR_TYPE.FLOAT,
        min = 0,
        default = 0.01,  -- Percent of max mana per second
        flags = PERSISTED_MODIFIABLE,
    },
}
-- }}}

-- {{{ Combat Stats
local WC3_COMBAT = {
    -- Base attack damage (before primary stat bonus)
    base_damage_min = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 10,
        flags = PERSISTED_MODIFIABLE,
    },
    base_damage_max = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 12,
        flags = PERSISTED_MODIFIABLE,
    },

    -- Attack speed (seconds between attacks)
    base_attack_cooldown = {
        type = ATTR_TYPE.FLOAT,
        min = 0.1,
        default = 1.5,
        flags = PERSISTED_MODIFIABLE,
    },

    -- Base armor (before agility bonus)
    base_armor = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 0,
        flags = PERSISTED_MODIFIABLE,
    },

    -- Movement
    movement_speed = {
        type = ATTR_TYPE.INTEGER,
        min = 0, max = 522,  -- WC3 speed cap
        default = 300,
        flags = PERSISTED_MODIFIABLE,
    },
}
-- }}}

-- {{{ Derived Attributes
local WC3_DERIVED = {
    -- Max health = base_health + (strength * 25)
    max_health = {
        type = ATTR_TYPE.INTEGER,
        min = 1,
        default = 100,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "base_health", "strength" },
        formula = function(get)
            return get("base_health") + (get("strength") * 25)
        end,
    },

    -- Max mana = base_mana + (intelligence * 15)
    max_mana = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "base_mana", "intelligence" },
        formula = function(get)
            return get("base_mana") + (get("intelligence") * 15)
        end,
    },

    -- Health regen = base_health_regen + (strength * 0.05)
    health_regen = {
        type = ATTR_TYPE.FLOAT,
        min = 0,
        default = 0.25,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "base_health_regen", "strength" },
        formula = function(get)
            return get("base_health_regen") + (get("strength") * 0.05)
        end,
    },

    -- Mana regen = base_mana_regen + (intelligence * 0.05)
    mana_regen = {
        type = ATTR_TYPE.FLOAT,
        min = 0,
        default = 0.01,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "base_mana_regen", "intelligence" },
        formula = function(get)
            return get("base_mana_regen") + (get("intelligence") * 0.05)
        end,
    },

    -- Armor = base_armor + (agility / 3)
    armor = {
        type = ATTR_TYPE.FLOAT,
        min = 0,
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "base_armor", "agility" },
        formula = function(get)
            return get("base_armor") + (get("agility") / 3)
        end,
    },

    -- Armor reduction percentage
    -- Formula: armor * 0.06 / (1 + 0.06 * armor)
    armor_reduction = {
        type = ATTR_TYPE.PERCENT,
        min = 0, max = 100,
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "armor" },
        formula = function(get)
            local armor = get("armor")
            if armor <= 0 then return 0 end
            return (armor * 0.06 / (1 + 0.06 * armor)) * 100
        end,
    },

    -- Attack damage bonus from primary stat
    attack_damage_bonus = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "primary_stat", "strength", "agility", "intelligence" },
        formula = function(get)
            local primary = get("primary_stat")
            if primary == "strength" then
                return get("strength")
            elseif primary == "agility" then
                return get("agility")
            elseif primary == "intelligence" then
                return get("intelligence")
            end
            return 0
        end,
    },

    -- Attack speed modifier from agility (1% per point)
    attack_speed_bonus = {
        type = ATTR_TYPE.PERCENT,
        min = 0,
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "agility" },
        formula = function(get)
            return get("agility")  -- 1% per agility
        end,
    },

    -- Effective attack cooldown
    attack_cooldown = {
        type = ATTR_TYPE.FLOAT,
        min = 0.1,
        default = 1.5,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "base_attack_cooldown", "attack_speed_bonus" },
        formula = function(get)
            local base = get("base_attack_cooldown")
            local bonus = get("attack_speed_bonus")
            return base / (1 + bonus / 100)
        end,
    },
}
-- }}}
-- }}}

-- {{{ Hero Class Definitions
-- Stat gains per level for different hero types
local HERO_CLASSES = {
    -- Strength heroes
    paladin = {
        primary_stat = "strength",
        base_strength = 24,
        base_agility = 13,
        base_intelligence = 17,
        strength_per_level = 2.7,
        agility_per_level = 1.5,
        intelligence_per_level = 1.8,
    },
    mountain_king = {
        primary_stat = "strength",
        base_strength = 24,
        base_agility = 11,
        base_intelligence = 15,
        strength_per_level = 3.0,
        agility_per_level = 1.5,
        intelligence_per_level = 1.5,
    },
    tauren_chieftain = {
        primary_stat = "strength",
        base_strength = 25,
        base_agility = 10,
        base_intelligence = 14,
        strength_per_level = 3.2,
        agility_per_level = 1.0,
        intelligence_per_level = 1.5,
    },

    -- Agility heroes
    demon_hunter = {
        primary_stat = "agility",
        base_strength = 21,
        base_agility = 22,
        base_intelligence = 16,
        strength_per_level = 2.4,
        agility_per_level = 1.5,
        intelligence_per_level = 2.1,
    },
    blademaster = {
        primary_stat = "agility",
        base_strength = 18,
        base_agility = 23,
        base_intelligence = 16,
        strength_per_level = 2.0,
        agility_per_level = 2.75,
        intelligence_per_level = 1.75,
    },
    warden = {
        primary_stat = "agility",
        base_strength = 18,
        base_agility = 23,
        base_intelligence = 16,
        strength_per_level = 2.0,
        agility_per_level = 2.8,
        intelligence_per_level = 1.5,
    },

    -- Intelligence heroes
    archmage = {
        primary_stat = "intelligence",
        base_strength = 14,
        base_agility = 17,
        base_intelligence = 24,
        strength_per_level = 1.8,
        agility_per_level = 1.0,
        intelligence_per_level = 3.2,
    },
    blood_mage = {
        primary_stat = "intelligence",
        base_strength = 18,
        base_agility = 14,
        base_intelligence = 22,
        strength_per_level = 2.0,
        agility_per_level = 1.0,
        intelligence_per_level = 3.0,
    },
    lich = {
        primary_stat = "intelligence",
        base_strength = 15,
        base_agility = 14,
        base_intelligence = 24,
        strength_per_level = 1.6,
        agility_per_level = 1.4,
        intelligence_per_level = 3.4,
    },
}
-- }}}

-- {{{ Registration
local M = {}

function M.register_all()
    registry.register_bulk(WC3_CORE)
    registry.register_bulk(WC3_RESOURCES)
    registry.register_bulk(WC3_COMBAT)
    registry.register_bulk(WC3_DERIVED)
end

function M.get_hero_class(class_name)
    return HERO_CLASSES[class_name]
end

function M.list_hero_classes()
    local result = {}
    for name, _ in pairs(HERO_CLASSES) do
        table.insert(result, name)
    end
    table.sort(result)
    return result
end

-- Apply hero class to a container
function M.apply_hero_class(container, class_name, level)
    local class = HERO_CLASSES[class_name]
    if not class then
        return false, "Unknown hero class: " .. tostring(class_name)
    end

    local setters = require("src.libs.attributes.setters")

    level = level or 1

    -- Calculate stats for level
    local levels_gained = level - 1
    local strength = math.floor(class.base_strength + (class.strength_per_level * levels_gained))
    local agility = math.floor(class.base_agility + (class.agility_per_level * levels_gained))
    local intelligence = math.floor(class.base_intelligence + (class.intelligence_per_level * levels_gained))

    setters.set_many(container, {
        level = level,
        primary_stat = class.primary_stat,
        strength = strength,
        agility = agility,
        intelligence = intelligence,
    }, { source = "hero_class:" .. class_name })

    return true
end

return M
-- }}}
```

### 2. Experience Table

```lua
-- {{{ WC3 Experience Table
-- XP required to reach each level
local XP_TABLE = {
    [1] = 0,
    [2] = 200,
    [3] = 500,
    [4] = 900,
    [5] = 1400,
    [6] = 2000,
    [7] = 2700,
    [8] = 3500,
    [9] = 4400,
    [10] = 5400,
    -- Extended beyond vanilla WC3
    [11] = 6500,
    [12] = 7700,
    [13] = 9000,
    [14] = 10400,
    [15] = 11900,
    [16] = 13500,
    [17] = 15200,
    [18] = 17000,
    [19] = 18900,
    [20] = 20900,
    [21] = 23000,
    [22] = 25200,
    [23] = 27500,
    [24] = 29900,
    [25] = 32400,
}

function M.get_xp_for_level(level)
    return XP_TABLE[level] or XP_TABLE[25]
end

function M.get_level_for_xp(xp)
    for lvl = 25, 1, -1 do
        if xp >= (XP_TABLE[lvl] or 0) then
            return lvl
        end
    end
    return 1
end
-- }}}
```

## Related Documents

- Issue 016a - Core attribute registry
- Issue 016e - Derived attribute engine
- Issue 016g - WoW attribute config (for comparison)
- Issue 016h - Cross-system mapping
- `src/guild/hero.lua` - Current WC3-style hero implementation

## Acceptance Criteria

- [x] All WC3 primary stats registered
- [x] All derived stats with formulas
- [x] Hero class definitions with stat gains
- [x] Experience table for levels 1-25
- [x] apply_hero_class() sets up container
- [x] Formulas match WC3 mechanics
- [x] Unit tests for stat calculations

---

**Status:** Complete
**Dependencies:** 016a, 016e

## Implementation Notes

Created `src/libs/attributes/configs/wc3.lua` (~580 lines) with complete WC3 attribute configuration.

### Attribute Categories
1. **WC3_CORE** - Primary stats (strength, agility, intelligence) and identity (level, experience, primary_stat)
2. **WC3_RESOURCES** - Health, mana, and regeneration (base values and current values)
3. **WC3_COMBAT** - Damage, armor, attack speed, movement speed, attack range
4. **WC3_DERIVED** - 12 computed attributes with WC3-accurate formulas

### Derived Attribute Formulas
- `max_health = base_health + (strength * 25)` (25 HP per strength)
- `max_mana = base_mana + (intelligence * 15)` (15 mana per intelligence)
- `health_regen = base_health_regen + (strength * 0.05)` (0.05 HP/sec per strength)
- `mana_regen = base_mana_regen + (intelligence * 0.05)` (0.05 mana/sec per intelligence)
- `armor = base_armor + (agility / 3)` (0.333 armor per agility)
- `armor_reduction = (armor * 0.06 / (1 + 0.06 * |armor|)) * 100` (WC3 damage reduction formula)
- `attack_damage_bonus` - Primary stat value (selected by primary_stat enum)
- `damage_min/max = base_damage_min/max + attack_damage_bonus`
- `attack_speed_bonus = agility` (1% IAS per agility)
- `attack_cooldown = base_attack_cooldown / (1 + attack_speed_bonus / 100)`
- `dps = avg_damage / attack_cooldown`

### Hero Classes (14 total)
- **Strength**: paladin, mountain_king, tauren_chieftain, death_knight, pit_lord
- **Agility**: demon_hunter, blademaster, warden, dark_ranger
- **Intelligence**: archmage, blood_mage, lich, keeper_of_the_grove, naga_sea_witch

Each hero class defines:
- Base stats (str/agi/int)
- Per-level stat gains (with fractional values)
- Primary stat type
- Base health/mana

### Experience Table
WC3-standard XP thresholds for levels 1-10, extended to level 25 with consistent progression.

### API Functions
- `register_all()` - Register all WC3 attributes
- `apply_hero_class(container, class_name, level)` - Apply hero class to container
- `calculate_stats_at_level(class_name, level)` - Preview stats without container
- `level_up(container, class_name)` - Apply stat gains for level-up
- `get_xp_for_level(level)` / `get_level_for_xp(xp)` - XP conversions
- `get_xp_to_next_level(xp)` / `get_xp_progress(xp)` - Progress queries
- `list_hero_classes()` / `get_hero_class(name)` / `get_hero_classes_by_primary()` - Class queries

### Test Coverage
42 tests covering:
- Registration (6 tests)
- Derived formulas (14 tests)
- Hero classes (10 tests)
- Experience table (5 tests)
- Level-up (3 tests)
- Integration (4 tests)

### Files Changed
- Created: `src/libs/attributes/configs/wc3.lua` (~580 lines)
- Created: `src/tests/test_wc3_config.lua` (42 tests)
- Modified: `src/libs/attributes/init.lua` (added load_config helper)


# Issue 016g: WoW Attribute Config

## Current Behavior

WoW-style attributes exist only as FIXME comments in hero.lua. No formal schema or calculation formulas are defined.

## Intended Behavior

A complete WoW attribute configuration that:
- Defines primary stats (Strength, Agility, Stamina, Intellect, Spirit)
- Defines secondary stats (Crit, Haste, Mastery, Versatility)
- Defines rating conversions (how item ratings become percentages)
- Supports class/spec variations
- Follows classic/TBC-era formulas (simpler than modern WoW)

## Suggested Implementation Steps

### 1. WoW Primary Attributes

```lua
-- src/libs/attributes/configs/wow.lua

local registry = require("src.libs.attributes.registry")
local ATTR_TYPE = require("src.libs.attributes.schema").ATTR_TYPE
local ATTR_FLAGS = require("src.libs.attributes.schema").ATTR_FLAGS

-- {{{ WoW Attribute Definitions

local PERSISTED_MODIFIABLE = ATTR_FLAGS.PERSISTED + ATTR_FLAGS.MODIFIABLE

-- {{{ Core Character Attributes
local WOW_CORE = {
    level = {
        type = ATTR_TYPE.INTEGER,
        min = 1, max = 70,  -- TBC cap
        default = 1,
        flags = ATTR_FLAGS.PERSISTED,
    },
    experience = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 0,
        flags = ATTR_FLAGS.PERSISTED,
    },

    -- Class determines stat scaling and abilities
    class = {
        type = ATTR_TYPE.ENUM,
        enum_values = {
            "warrior", "paladin", "hunter", "rogue",
            "priest", "shaman", "mage", "warlock", "druid"
        },
        default = "warrior",
        flags = ATTR_FLAGS.PERSISTED,
    },

    -- Spec affects stat weights
    spec = {
        type = ATTR_TYPE.ENUM,
        enum_values = {
            -- Will vary by class, simplified here
            "primary", "secondary", "tertiary"
        },
        default = "primary",
        flags = ATTR_FLAGS.PERSISTED,
    },
}
-- }}}

-- {{{ Primary Stats
local WOW_PRIMARY = {
    -- Strength: Melee AP (2 per point), Block value
    strength = {
        type = ATTR_TYPE.INTEGER,
        min = 0, max = 9999,
        default = 10,
        flags = PERSISTED_MODIFIABLE,
    },

    -- Agility: Crit (varies), Dodge, Ranged AP (rogues/hunters)
    agility = {
        type = ATTR_TYPE.INTEGER,
        min = 0, max = 9999,
        default = 10,
        flags = PERSISTED_MODIFIABLE,
    },

    -- Stamina: Health (10 per point after first 20)
    stamina = {
        type = ATTR_TYPE.INTEGER,
        min = 0, max = 9999,
        default = 10,
        flags = PERSISTED_MODIFIABLE,
    },

    -- Intellect: Mana (15 per point), Spell crit
    intellect = {
        type = ATTR_TYPE.INTEGER,
        min = 0, max = 9999,
        default = 10,
        flags = PERSISTED_MODIFIABLE,
    },

    -- Spirit: Out of combat regen (health and mana)
    spirit = {
        type = ATTR_TYPE.INTEGER,
        min = 0, max = 9999,
        default = 10,
        flags = PERSISTED_MODIFIABLE,
    },
}
-- }}}

-- {{{ Secondary Stats (Base Values)
local WOW_SECONDARY_BASE = {
    -- Attack power from gear
    base_attack_power = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 0,
        flags = PERSISTED_MODIFIABLE,
    },

    -- Spell power from gear
    base_spell_power = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 0,
        flags = PERSISTED_MODIFIABLE,
    },

    -- Crit rating from gear
    crit_rating = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 0,
        flags = PERSISTED_MODIFIABLE,
    },

    -- Hit rating from gear
    hit_rating = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 0,
        flags = PERSISTED_MODIFIABLE,
    },

    -- Haste rating from gear
    haste_rating = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 0,
        flags = PERSISTED_MODIFIABLE,
    },

    -- Defense rating from gear
    defense_rating = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 0,
        flags = PERSISTED_MODIFIABLE,
    },

    -- Resilience rating (PvP)
    resilience_rating = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 0,
        flags = PERSISTED_MODIFIABLE,
    },

    -- Armor from gear
    base_armor = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 0,
        flags = PERSISTED_MODIFIABLE,
    },

    -- Expertise rating
    expertise_rating = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 0,
        flags = PERSISTED_MODIFIABLE,
    },

    -- Armor penetration rating
    armor_pen_rating = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 0,
        flags = PERSISTED_MODIFIABLE,
    },
}
-- }}}

-- {{{ Resources
local WOW_RESOURCES = {
    base_health = {
        type = ATTR_TYPE.INTEGER,
        min = 1,
        default = 100,
        flags = PERSISTED_MODIFIABLE,
    },
    base_mana = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 0,
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
    rage = {
        type = ATTR_TYPE.INTEGER,
        min = 0, max = 100,
        default = 0,
        flags = ATTR_FLAGS.PERSISTED,
    },
    energy = {
        type = ATTR_TYPE.INTEGER,
        min = 0, max = 100,
        default = 100,
        flags = ATTR_FLAGS.PERSISTED,
    },

    -- Combo points (rogues/druids)
    combo_points = {
        type = ATTR_TYPE.INTEGER,
        min = 0, max = 5,
        default = 0,
        flags = 0,  -- Not persisted
    },
}
-- }}}

-- {{{ Rating Conversion Constants
-- These vary by level, simplified to level 70 values
local RATING_CONVERSIONS = {
    -- Rating needed for 1%
    CRIT_RATING_PER_PERCENT = 22.08,
    HIT_RATING_PER_PERCENT = 15.77,
    HASTE_RATING_PER_PERCENT = 15.77,
    EXPERTISE_RATING_PER_PERCENT = 3.94,  -- Per 1 expertise
    DEFENSE_RATING_PER_POINT = 2.37,      -- Per 1 defense skill
    RESILIENCE_PER_PERCENT = 39.42,
    ARMOR_PEN_RATING_PER_PERCENT = 5.92,

    -- Agility per 1% crit (varies by class)
    AGILITY_PER_CRIT = {
        warrior = 33,
        paladin = 25,
        hunter = 40,
        rogue = 40,
        priest = 0,  -- Doesn't benefit
        shaman = 25,
        mage = 0,
        warlock = 0,
        druid = 25,
    },

    -- Intellect per 1% spell crit
    INTELLECT_PER_SPELL_CRIT = 80,
}
-- }}}

-- {{{ Derived Attributes
local WOW_DERIVED = {
    -- Max health = base_health + (stamina - 20) * 10
    -- First 20 stamina gives 1 HP each
    max_health = {
        type = ATTR_TYPE.INTEGER,
        min = 1,
        default = 100,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "base_health", "stamina" },
        formula = function(get)
            local base = get("base_health")
            local sta = get("stamina")
            if sta <= 20 then
                return base + sta
            end
            return base + 20 + ((sta - 20) * 10)
        end,
    },

    -- Max mana = base_mana + (intellect - 20) * 15
    max_mana = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "base_mana", "intellect" },
        formula = function(get)
            local base = get("base_mana")
            local int = get("intellect")
            if int <= 20 then
                return base + int
            end
            return base + 20 + ((int - 20) * 15)
        end,
    },

    -- Attack power = base_attack_power + (strength * 2)
    -- For melee classes
    attack_power = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "base_attack_power", "strength", "agility", "class" },
        formula = function(get)
            local base = get("base_attack_power")
            local str = get("strength")
            local agi = get("agility")
            local class = get("class")

            -- Most classes: 2 AP per strength
            local ap = base + (str * 2)

            -- Rogues and Hunters get AP from agility too
            if class == "rogue" or class == "hunter" then
                ap = ap + agi
            end
            -- Druids in cat form would get AP from agility
            -- (simplified here)

            return ap
        end,
    },

    -- Spell power (from gear only, simplified)
    spell_power = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "base_spell_power" },
        formula = function(get)
            return get("base_spell_power")
        end,
    },

    -- Crit chance = crit_rating / 22.08 + agility / class_agi_per_crit
    crit_chance = {
        type = ATTR_TYPE.PERCENT,
        min = 0, max = 100,
        default = 5,  -- 5% base crit
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "crit_rating", "agility", "class" },
        formula = function(get)
            local rating = get("crit_rating")
            local agi = get("agility")
            local class = get("class")

            local base_crit = 5  -- All classes start with 5%
            local rating_crit = rating / RATING_CONVERSIONS.CRIT_RATING_PER_PERCENT
            local agi_per_crit = RATING_CONVERSIONS.AGILITY_PER_CRIT[class] or 0
            local agi_crit = 0
            if agi_per_crit > 0 then
                agi_crit = agi / agi_per_crit
            end

            return base_crit + rating_crit + agi_crit
        end,
    },

    -- Spell crit = base + intellect / 80
    spell_crit_chance = {
        type = ATTR_TYPE.PERCENT,
        min = 0, max = 100,
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "crit_rating", "intellect" },
        formula = function(get)
            local rating = get("crit_rating")
            local int = get("intellect")

            local rating_crit = rating / RATING_CONVERSIONS.CRIT_RATING_PER_PERCENT
            local int_crit = int / RATING_CONVERSIONS.INTELLECT_PER_SPELL_CRIT

            return rating_crit + int_crit
        end,
    },

    -- Hit chance from rating
    hit_chance = {
        type = ATTR_TYPE.PERCENT,
        min = 0, max = 100,
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "hit_rating" },
        formula = function(get)
            return get("hit_rating") / RATING_CONVERSIONS.HIT_RATING_PER_PERCENT
        end,
    },

    -- Haste percent from rating
    haste_percent = {
        type = ATTR_TYPE.PERCENT,
        min = 0,
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "haste_rating" },
        formula = function(get)
            return get("haste_rating") / RATING_CONVERSIONS.HASTE_RATING_PER_PERCENT
        end,
    },

    -- Total armor (includes agility bonus: 2 armor per agi)
    armor = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "base_armor", "agility" },
        formula = function(get)
            return get("base_armor") + (get("agility") * 2)
        end,
    },

    -- Armor damage reduction (level 70 formula)
    -- DR = Armor / (Armor + 10557.5)
    armor_reduction = {
        type = ATTR_TYPE.PERCENT,
        min = 0, max = 75,  -- 75% cap
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "armor", "level" },
        formula = function(get)
            local armor = get("armor")
            local level = get("level")
            if armor <= 0 then return 0 end

            -- Attacker level assumed equal to defender
            -- Constant = 400 + 85 * attacker_level
            local constant = 400 + (85 * level)
            local dr = (armor / (armor + constant)) * 100

            return math.min(75, dr)  -- 75% cap
        end,
    },

    -- Dodge from agility
    dodge_chance = {
        type = ATTR_TYPE.PERCENT,
        min = 0,
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "agility", "class" },
        formula = function(get)
            -- Simplified: varies heavily by class
            -- ~1% per 14-25 agility depending on class
            return get("agility") / 20
        end,
    },

    -- Block value from strength (for shield users)
    block_value = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "strength" },
        formula = function(get)
            -- 1 block value per 20 strength
            return math.floor(get("strength") / 20)
        end,
    },

    -- Mana regen from spirit (5-second rule)
    -- Mana per 5 seconds = 5 * sqrt(int) * spirit * 0.0093
    mana_regen_from_spirit = {
        type = ATTR_TYPE.FLOAT,
        min = 0,
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "intellect", "spirit" },
        formula = function(get)
            local int = get("intellect")
            local spirit = get("spirit")
            return 5 * math.sqrt(int) * spirit * 0.0093
        end,
    },
}
-- }}}
-- }}}

-- {{{ Registration
local M = {}

M.RATING_CONVERSIONS = RATING_CONVERSIONS

function M.register_all()
    registry.register_bulk(WOW_CORE)
    registry.register_bulk(WOW_PRIMARY)
    registry.register_bulk(WOW_SECONDARY_BASE)
    registry.register_bulk(WOW_RESOURCES)
    registry.register_bulk(WOW_DERIVED)
end

-- Get rating conversion for current level
function M.get_rating_conversion(stat_type, level)
    -- Ratings scale with level, simplified here
    -- Full implementation would use lookup tables
    local base = RATING_CONVERSIONS[stat_type .. "_RATING_PER_PERCENT"]
    if not base then return nil end

    -- Scale factor: ratings need more at higher levels
    local scale = 1 + (level - 60) * 0.02
    return base * math.max(1, scale)
end

return M
-- }}}
```

### 2. Class Stat Templates

```lua
-- {{{ Class Base Stats at Level 1
local CLASS_BASE_STATS = {
    warrior = {
        strength = 23, agility = 20, stamina = 22, intellect = 20, spirit = 21,
        base_health = 80, base_mana = 0,
        resource = "rage",
    },
    paladin = {
        strength = 22, agility = 20, stamina = 21, intellect = 20, spirit = 22,
        base_health = 68, base_mana = 80,
        resource = "mana",
    },
    hunter = {
        strength = 20, agility = 25, stamina = 21, intellect = 20, spirit = 21,
        base_health = 56, base_mana = 85,
        resource = "mana",
    },
    rogue = {
        strength = 21, agility = 24, stamina = 21, intellect = 20, spirit = 21,
        base_health = 55, base_mana = 0,
        resource = "energy",
    },
    priest = {
        strength = 20, agility = 20, stamina = 20, intellect = 22, spirit = 24,
        base_health = 52, base_mana = 120,
        resource = "mana",
    },
    shaman = {
        strength = 21, agility = 20, stamina = 21, intellect = 21, spirit = 22,
        base_health = 60, base_mana = 95,
        resource = "mana",
    },
    mage = {
        strength = 20, agility = 20, stamina = 20, intellect = 24, spirit = 22,
        base_health = 52, base_mana = 120,
        resource = "mana",
    },
    warlock = {
        strength = 20, agility = 20, stamina = 21, intellect = 23, spirit = 22,
        base_health = 53, base_mana = 109,
        resource = "mana",
    },
    druid = {
        strength = 21, agility = 20, stamina = 20, intellect = 22, spirit = 23,
        base_health = 54, base_mana = 100,
        resource = "mana",
    },
}
-- }}}
```

## Related Documents

- Issue 016a - Core attribute registry
- Issue 016e - Derived attribute engine
- Issue 016f - WC3 attribute config (for comparison)
- Issue 016h - Cross-system mapping
- Issue 015 - WoW style combat system (parent issue)

## Acceptance Criteria

- [ ] All WoW primary stats registered
- [ ] All secondary/rating stats registered
- [ ] Rating conversion constants defined
- [ ] Derived stats with proper formulas
- [ ] Class base stats defined
- [ ] Resource types (mana/rage/energy) supported
- [ ] Unit tests for stat calculations

---

**Status:** Pending
**Dependencies:** 016a, 016e


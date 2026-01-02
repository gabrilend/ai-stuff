-- WoW Attribute Configuration Module
-- Defines all World of Warcraft (TBC-era) attributes, rating systems, and class stats.
--
-- This module provides:
-- - Primary stats (Strength, Agility, Stamina, Intellect, Spirit)
-- - Secondary stats (Crit, Hit, Haste, Expertise, etc.)
-- - Rating conversion system (gear ratings to percentages)
-- - Class base stats with stat-per-level scaling
-- - Resource types (mana, rage, energy, combo points)
-- - Derived attributes with WoW-accurate formulas
--
-- Usage:
--   local wow = require("libs.attributes.configs.wow")
--   wow.register_all()
--   local container = registry.create_container()
--   wow.apply_class(container, "warrior", 70)

local registry = require("libs.attributes.registry")
local schema_module = require("libs.attributes.schema")
local ATTR_TYPE = schema_module.ATTR_TYPE
local ATTR_FLAGS = schema_module.ATTR_FLAGS

-- {{{ Module state
local wow = {}
local registered = false
-- }}}

-- {{{ Constants
local PERSISTED_MODIFIABLE = ATTR_FLAGS.PERSISTED + ATTR_FLAGS.MODIFIABLE
-- }}}

-- {{{ Rating Conversion Constants (Level 70 values)
-- Rating needed for 1% (or 1 point for some stats)
local RATING_CONVERSIONS = {
    CRIT_RATING_PER_PERCENT = 22.08,
    HIT_RATING_PER_PERCENT = 15.77,
    HASTE_RATING_PER_PERCENT = 15.77,
    EXPERTISE_RATING_PER_POINT = 3.94,  -- Per 1 expertise
    DEFENSE_RATING_PER_POINT = 2.37,    -- Per 1 defense skill
    RESILIENCE_PER_PERCENT = 39.42,
    ARMOR_PEN_RATING_PER_PERCENT = 5.92,
    PARRY_RATING_PER_PERCENT = 23.65,
    DODGE_RATING_PER_PERCENT = 18.92,
    BLOCK_RATING_PER_PERCENT = 7.88,

    -- Agility per 1% melee crit (varies by class)
    AGILITY_PER_CRIT = {
        warrior = 33,
        paladin = 25,
        hunter = 40,
        rogue = 40,
        priest = 0,   -- Doesn't benefit from agi crit
        shaman = 25,
        mage = 0,
        warlock = 0,
        druid = 25,
    },

    -- Intellect per 1% spell crit
    INTELLECT_PER_SPELL_CRIT = 80,

    -- Base miss chance against equal level target
    BASE_MISS_CHANCE = 5,
    DUAL_WIELD_MISS_PENALTY = 19,
    SPELL_HIT_CAP = 16,  -- Against boss (level +3)
}
-- }}}

-- {{{ WoW Attribute Definitions

-- {{{ WOW_CORE - Core Character Attributes
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

    -- Spec affects stat weights (simplified)
    spec = {
        type = ATTR_TYPE.ENUM,
        enum_values = { "primary", "secondary", "tertiary" },
        default = "primary",
        flags = ATTR_FLAGS.PERSISTED,
    },

    -- Resource type for this class
    resource_type = {
        type = ATTR_TYPE.ENUM,
        enum_values = { "mana", "rage", "energy" },
        default = "mana",
        flags = ATTR_FLAGS.PERSISTED,
    },
}
-- }}}

-- {{{ WOW_PRIMARY - Primary Stats
local WOW_PRIMARY = {
    -- Strength: Melee AP (2 per point), Block value
    strength = {
        type = ATTR_TYPE.INTEGER,
        min = 0, max = 9999,
        default = 10,
        flags = PERSISTED_MODIFIABLE,
    },

    -- Agility: Crit (varies), Dodge, Armor (2 per), Ranged AP
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

    -- Intellect: Mana (15 per point after first 20), Spell crit
    intellect = {
        type = ATTR_TYPE.INTEGER,
        min = 0, max = 9999,
        default = 10,
        flags = PERSISTED_MODIFIABLE,
    },

    -- Spirit: Out-of-combat regen (health and mana)
    spirit = {
        type = ATTR_TYPE.INTEGER,
        min = 0, max = 9999,
        default = 10,
        flags = PERSISTED_MODIFIABLE,
    },
}
-- }}}

-- {{{ WOW_SECONDARY_BASE - Secondary Stats (from gear)
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

    -- Healing power from gear (pre-TBC had separate)
    base_healing_power = {
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

    -- Parry rating
    parry_rating = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 0,
        flags = PERSISTED_MODIFIABLE,
    },

    -- Dodge rating
    dodge_rating = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 0,
        flags = PERSISTED_MODIFIABLE,
    },

    -- Block rating
    block_rating = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 0,
        flags = PERSISTED_MODIFIABLE,
    },

    -- Mp5 (mana per 5 seconds) from gear
    mp5 = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 0,
        flags = PERSISTED_MODIFIABLE,
    },

    -- Base attack speed (seconds per swing)
    base_attack_speed = {
        type = ATTR_TYPE.FLOAT,
        min = 0.1,
        default = 2.0,
        flags = PERSISTED_MODIFIABLE,
    },

    -- Base weapon damage
    base_damage_min = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 1,
        flags = PERSISTED_MODIFIABLE,
    },
    base_damage_max = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 2,
        flags = PERSISTED_MODIFIABLE,
    },
}
-- }}}

-- {{{ WOW_RESOURCES - Health, Mana, and Power Resources
local WOW_RESOURCES = {
    -- Base health (before stamina)
    base_health = {
        type = ATTR_TYPE.INTEGER,
        min = 1,
        default = 100,
        flags = PERSISTED_MODIFIABLE,
    },

    -- Base mana (before intellect)
    base_mana = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 0,
        flags = PERSISTED_MODIFIABLE,
    },

    -- Current values (mutable during combat)
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

    -- Combo points (rogues, cat druids)
    combo_points = {
        type = ATTR_TYPE.INTEGER,
        min = 0, max = 5,
        default = 0,
        flags = 0,  -- Not persisted
    },
}
-- }}}

-- {{{ WOW_DERIVED - Derived Attributes
local WOW_DERIVED = {
    -- Max health = base_health + stamina bonus
    -- First 20 stamina gives 1 HP each, then 10 HP per stamina
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

    -- Max mana = base_mana + intellect bonus
    -- First 20 intellect gives 1 mana each, then 15 mana per intellect
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

    -- Attack power = base + strength * 2 + agility (for rogues/hunters)
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

            -- Rogues, hunters, and cat druids get AP from agility
            if class == "rogue" or class == "hunter" then
                ap = ap + agi
            end

            return ap
        end,
    },

    -- Spell power (from gear, plus intellect for some classes)
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

    -- Healing power
    healing_power = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "base_healing_power", "base_spell_power" },
        formula = function(get)
            -- In TBC, spell power contributes to healing too
            return get("base_healing_power") + get("base_spell_power")
        end,
    },

    -- Melee crit chance = base + rating bonus + agility bonus
    crit_chance = {
        type = ATTR_TYPE.FLOAT,
        min = 0, max = 100,
        default = 5,  -- 5% base crit
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "crit_rating", "agility", "class" },
        formula = function(get)
            local rating = get("crit_rating")
            local agi = get("agility")
            local class = get("class")

            local base_crit = 5
            local rating_crit = rating / RATING_CONVERSIONS.CRIT_RATING_PER_PERCENT
            local agi_per_crit = RATING_CONVERSIONS.AGILITY_PER_CRIT[class] or 0
            local agi_crit = 0
            if agi_per_crit > 0 then
                agi_crit = agi / agi_per_crit
            end

            return base_crit + rating_crit + agi_crit
        end,
    },

    -- Spell crit chance = rating bonus + intellect bonus
    spell_crit_chance = {
        type = ATTR_TYPE.FLOAT,
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
        type = ATTR_TYPE.FLOAT,
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
        type = ATTR_TYPE.FLOAT,
        min = 0,
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "haste_rating" },
        formula = function(get)
            return get("haste_rating") / RATING_CONVERSIONS.HASTE_RATING_PER_PERCENT
        end,
    },

    -- Expertise from rating (reduces dodge/parry)
    expertise = {
        type = ATTR_TYPE.FLOAT,
        min = 0,
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "expertise_rating" },
        formula = function(get)
            return get("expertise_rating") / RATING_CONVERSIONS.EXPERTISE_RATING_PER_POINT
        end,
    },

    -- Defense skill from rating
    defense_skill = {
        type = ATTR_TYPE.FLOAT,
        min = 0,
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "defense_rating", "level" },
        formula = function(get)
            local base_defense = get("level") * 5  -- Base defense = level * 5
            local bonus = get("defense_rating") / RATING_CONVERSIONS.DEFENSE_RATING_PER_POINT
            return base_defense + bonus
        end,
    },

    -- Total armor (base + agility bonus)
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

    -- Armor damage reduction (against attacker of equal level)
    -- DR = Armor / (Armor + constant), where constant = 400 + 85 * level
    armor_reduction = {
        type = ATTR_TYPE.FLOAT,
        min = 0, max = 75,  -- 75% cap
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "armor", "level" },
        formula = function(get)
            local armor = get("armor")
            local level = get("level")
            if armor <= 0 then return 0 end

            local constant = 400 + (85 * level)
            local dr = (armor / (armor + constant)) * 100

            return math.min(75, dr)
        end,
    },

    -- Dodge chance = base + agility bonus + rating bonus
    dodge_chance = {
        type = ATTR_TYPE.FLOAT,
        min = 0,
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "agility", "dodge_rating", "class" },
        formula = function(get)
            local agi = get("agility")
            local rating = get("dodge_rating")

            -- Simplified: ~1% per 20 agility (varies by class)
            local agi_dodge = agi / 20
            local rating_dodge = rating / RATING_CONVERSIONS.DODGE_RATING_PER_PERCENT

            return agi_dodge + rating_dodge
        end,
    },

    -- Parry chance from rating
    parry_chance = {
        type = ATTR_TYPE.FLOAT,
        min = 0,
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "parry_rating" },
        formula = function(get)
            return get("parry_rating") / RATING_CONVERSIONS.PARRY_RATING_PER_PERCENT
        end,
    },

    -- Block chance from rating
    block_chance = {
        type = ATTR_TYPE.FLOAT,
        min = 0,
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "block_rating" },
        formula = function(get)
            return get("block_rating") / RATING_CONVERSIONS.BLOCK_RATING_PER_PERCENT
        end,
    },

    -- Block value from strength
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

    -- Mana regen from spirit (out of 5-second rule)
    -- MP5 = 5 * sqrt(int) * spirit * 0.009327
    mana_regen = {
        type = ATTR_TYPE.FLOAT,
        min = 0,
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "intellect", "spirit", "mp5" },
        formula = function(get)
            local int = get("intellect")
            local spirit = get("spirit")
            local mp5_gear = get("mp5")

            local spirit_regen = 5 * math.sqrt(int) * spirit * 0.009327
            return spirit_regen + mp5_gear
        end,
    },

    -- Resilience (damage reduction %)
    resilience_percent = {
        type = ATTR_TYPE.FLOAT,
        min = 0,
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "resilience_rating" },
        formula = function(get)
            return get("resilience_rating") / RATING_CONVERSIONS.RESILIENCE_PER_PERCENT
        end,
    },

    -- Armor penetration percent
    armor_pen_percent = {
        type = ATTR_TYPE.FLOAT,
        min = 0, max = 100,
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "armor_pen_rating" },
        formula = function(get)
            local pct = get("armor_pen_rating") / RATING_CONVERSIONS.ARMOR_PEN_RATING_PER_PERCENT
            return math.min(100, pct)
        end,
    },

    -- Effective attack speed (base / (1 + haste%))
    attack_speed = {
        type = ATTR_TYPE.FLOAT,
        min = 0.1,
        default = 2.0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "base_attack_speed", "haste_percent" },
        formula = function(get)
            local base = get("base_attack_speed")
            local haste = get("haste_percent")
            return base / (1 + haste / 100)
        end,
    },

    -- DPS approximation
    dps = {
        type = ATTR_TYPE.FLOAT,
        min = 0,
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "base_damage_min", "base_damage_max", "attack_power", "attack_speed" },
        formula = function(get)
            local dmg_min = get("base_damage_min")
            local dmg_max = get("base_damage_max")
            local ap = get("attack_power")
            local speed = get("attack_speed")

            if speed <= 0 then return 0 end

            -- AP adds damage: (AP / 14) * normalized_speed
            -- Using actual weapon speed for simplicity
            local ap_bonus = (ap / 14) * speed
            local avg_damage = (dmg_min + dmg_max) / 2 + ap_bonus

            return avg_damage / speed
        end,
    },
}
-- }}}

-- }}}

-- {{{ Class Base Stats
-- Stats at level 1 (before racial bonuses)
local CLASS_BASE_STATS = {
    warrior = {
        strength = 23, agility = 20, stamina = 22, intellect = 20, spirit = 21,
        base_health = 80, base_mana = 0,
        resource_type = "rage",
    },
    paladin = {
        strength = 22, agility = 20, stamina = 21, intellect = 20, spirit = 22,
        base_health = 68, base_mana = 80,
        resource_type = "mana",
    },
    hunter = {
        strength = 20, agility = 25, stamina = 21, intellect = 20, spirit = 21,
        base_health = 56, base_mana = 85,
        resource_type = "mana",
    },
    rogue = {
        strength = 21, agility = 24, stamina = 21, intellect = 20, spirit = 21,
        base_health = 55, base_mana = 0,
        resource_type = "energy",
    },
    priest = {
        strength = 20, agility = 20, stamina = 20, intellect = 22, spirit = 24,
        base_health = 52, base_mana = 120,
        resource_type = "mana",
    },
    shaman = {
        strength = 21, agility = 20, stamina = 21, intellect = 21, spirit = 22,
        base_health = 60, base_mana = 95,
        resource_type = "mana",
    },
    mage = {
        strength = 20, agility = 20, stamina = 20, intellect = 24, spirit = 22,
        base_health = 52, base_mana = 120,
        resource_type = "mana",
    },
    warlock = {
        strength = 20, agility = 20, stamina = 21, intellect = 23, spirit = 22,
        base_health = 53, base_mana = 109,
        resource_type = "mana",
    },
    druid = {
        strength = 21, agility = 20, stamina = 20, intellect = 22, spirit = 23,
        base_health = 54, base_mana = 100,
        resource_type = "mana",
    },
}

-- Stat gain per level (simplified - would vary by class)
local STAT_PER_LEVEL = {
    warrior = { strength = 2.2, agility = 1.0, stamina = 2.3, intellect = 0.5, spirit = 0.8 },
    paladin = { strength = 2.0, agility = 0.8, stamina = 2.0, intellect = 1.0, spirit = 1.2 },
    hunter = { strength = 0.8, agility = 2.4, stamina = 1.5, intellect = 1.0, spirit = 1.0 },
    rogue = { strength = 1.0, agility = 2.6, stamina = 1.5, intellect = 0.5, spirit = 0.8 },
    priest = { strength = 0.5, agility = 0.5, stamina = 1.0, intellect = 2.2, spirit = 2.4 },
    shaman = { strength = 1.5, agility = 0.8, stamina = 1.5, intellect = 1.8, spirit = 1.8 },
    mage = { strength = 0.5, agility = 0.5, stamina = 1.0, intellect = 2.8, spirit = 2.0 },
    warlock = { strength = 0.5, agility = 0.5, stamina = 1.2, intellect = 2.4, spirit = 2.2 },
    druid = { strength = 1.2, agility = 1.0, stamina = 1.5, intellect = 2.0, spirit = 2.2 },
}
-- }}}

-- {{{ Experience Table (TBC levels 1-70)
local XP_TABLE = {
    [1] = 0,
    [2] = 400,
    [3] = 900,
    [4] = 1400,
    [5] = 2100,
    [6] = 2800,
    [7] = 3600,
    [8] = 4500,
    [9] = 5400,
    [10] = 6500,
    [11] = 7600,
    [12] = 8700,
    [13] = 9800,
    [14] = 11000,
    [15] = 12300,
    [16] = 13600,
    [17] = 15000,
    [18] = 16400,
    [19] = 17800,
    [20] = 19300,
    [21] = 20800,
    [22] = 22400,
    [23] = 24000,
    [24] = 25500,
    [25] = 27200,
    [26] = 28900,
    [27] = 30500,
    [28] = 32200,
    [29] = 33900,
    [30] = 36300,
    [31] = 38800,
    [32] = 41600,
    [33] = 44600,
    [34] = 48000,
    [35] = 51400,
    [36] = 55000,
    [37] = 58700,
    [38] = 62400,
    [39] = 66200,
    [40] = 70200,
    [41] = 74300,
    [42] = 78500,
    [43] = 82800,
    [44] = 87100,
    [45] = 91600,
    [46] = 96300,
    [47] = 101000,
    [48] = 105800,
    [49] = 110700,
    [50] = 115700,
    [51] = 120900,
    [52] = 126100,
    [53] = 131500,
    [54] = 137000,
    [55] = 142500,
    [56] = 148200,
    [57] = 154000,
    [58] = 159900,
    [59] = 165800,
    [60] = 172000,
    -- TBC levels
    [61] = 290000,
    [62] = 317000,
    [63] = 349000,
    [64] = 386000,
    [65] = 428000,
    [66] = 475000,
    [67] = 527000,
    [68] = 585000,
    [69] = 648000,
    [70] = 717000,
}
-- }}}

-- {{{ Public API

-- {{{ wow.register_all
function wow.register_all()
    if registered then
        return false, "WoW attributes already registered"
    end

    registry.register_bulk(WOW_CORE)
    registry.register_bulk(WOW_PRIMARY)
    registry.register_bulk(WOW_SECONDARY_BASE)
    registry.register_bulk(WOW_RESOURCES)
    registry.register_bulk(WOW_DERIVED)

    registered = true
    return true
end
-- }}}

-- {{{ wow.is_registered
function wow.is_registered()
    return registered
end
-- }}}

-- {{{ wow.get_class
function wow.get_class(class_name)
    return CLASS_BASE_STATS[class_name]
end
-- }}}

-- {{{ wow.list_classes
function wow.list_classes()
    local result = {}
    for name, _ in pairs(CLASS_BASE_STATS) do
        result[#result + 1] = name
    end
    table.sort(result)
    return result
end
-- }}}

-- {{{ wow.apply_class
-- Apply class stats to a container at given level
function wow.apply_class(container, class_name, level)
    local class = CLASS_BASE_STATS[class_name]
    if not class then
        return false, "Unknown class: " .. tostring(class_name)
    end

    local gains = STAT_PER_LEVEL[class_name]
    if not gains then
        return false, "No stat gains for class: " .. tostring(class_name)
    end

    local setters = require("libs.attributes.setters")

    level = level or 1
    if level < 1 then level = 1 end
    if level > 70 then level = 70 end

    local levels_gained = level - 1

    setters.set_many(container, {
        level = level,
        experience = XP_TABLE[level] or 0,
        class = class_name,
        resource_type = class.resource_type,
        strength = math.floor(class.strength + (gains.strength * levels_gained)),
        agility = math.floor(class.agility + (gains.agility * levels_gained)),
        stamina = math.floor(class.stamina + (gains.stamina * levels_gained)),
        intellect = math.floor(class.intellect + (gains.intellect * levels_gained)),
        spirit = math.floor(class.spirit + (gains.spirit * levels_gained)),
        base_health = class.base_health,
        base_mana = class.base_mana,
    }, { source = "class:" .. class_name })

    return true
end
-- }}}

-- {{{ wow.calculate_stats_at_level
function wow.calculate_stats_at_level(class_name, level)
    local class = CLASS_BASE_STATS[class_name]
    if not class then
        return nil, "Unknown class: " .. tostring(class_name)
    end

    local gains = STAT_PER_LEVEL[class_name]
    if not gains then
        return nil, "No stat gains for class: " .. tostring(class_name)
    end

    level = level or 1
    if level < 1 then level = 1 end
    if level > 70 then level = 70 end

    local levels_gained = level - 1

    return {
        level = level,
        class = class_name,
        resource_type = class.resource_type,
        strength = math.floor(class.strength + (gains.strength * levels_gained)),
        agility = math.floor(class.agility + (gains.agility * levels_gained)),
        stamina = math.floor(class.stamina + (gains.stamina * levels_gained)),
        intellect = math.floor(class.intellect + (gains.intellect * levels_gained)),
        spirit = math.floor(class.spirit + (gains.spirit * levels_gained)),
    }
end
-- }}}

-- {{{ wow.level_up
function wow.level_up(container, class_name)
    local class = CLASS_BASE_STATS[class_name]
    if not class then
        return false, "Unknown class: " .. tostring(class_name)
    end

    local gains = STAT_PER_LEVEL[class_name]
    if not gains then
        return false, "No stat gains for class: " .. tostring(class_name)
    end

    local getters = require("libs.attributes.getters")
    local setters = require("libs.attributes.setters")

    local current_level = getters.get(container, "level")
    if current_level >= 70 then
        return false, "Already at max level"
    end

    local new_level = current_level + 1

    setters.set(container, "level", new_level, { source = "level_up" })
    setters.adjust(container, "strength", math.floor(gains.strength), { source = "level_up" })
    setters.adjust(container, "agility", math.floor(gains.agility), { source = "level_up" })
    setters.adjust(container, "stamina", math.floor(gains.stamina), { source = "level_up" })
    setters.adjust(container, "intellect", math.floor(gains.intellect), { source = "level_up" })
    setters.adjust(container, "spirit", math.floor(gains.spirit), { source = "level_up" })

    return true, {
        new_level = new_level,
        strength_gained = math.floor(gains.strength),
        agility_gained = math.floor(gains.agility),
        stamina_gained = math.floor(gains.stamina),
        intellect_gained = math.floor(gains.intellect),
        spirit_gained = math.floor(gains.spirit),
    }
end
-- }}}

-- {{{ wow.get_xp_for_level
function wow.get_xp_for_level(level)
    if level < 1 then return 0 end
    if level > 70 then return XP_TABLE[70] end
    return XP_TABLE[level] or XP_TABLE[70]
end
-- }}}

-- {{{ wow.get_level_for_xp
function wow.get_level_for_xp(xp)
    for lvl = 70, 1, -1 do
        if xp >= (XP_TABLE[lvl] or 0) then
            return lvl
        end
    end
    return 1
end
-- }}}

-- {{{ wow.get_xp_to_next_level
function wow.get_xp_to_next_level(current_xp)
    local current_level = wow.get_level_for_xp(current_xp)
    if current_level >= 70 then
        return 0
    end
    local next_level_xp = XP_TABLE[current_level + 1]
    return next_level_xp - current_xp
end
-- }}}

-- {{{ wow.get_xp_progress
function wow.get_xp_progress(current_xp)
    local current_level = wow.get_level_for_xp(current_xp)
    if current_level >= 70 then
        return 100
    end

    local level_start = XP_TABLE[current_level]
    local level_end = XP_TABLE[current_level + 1]
    local level_range = level_end - level_start

    if level_range <= 0 then
        return 100
    end

    local progress = current_xp - level_start
    return (progress / level_range) * 100
end
-- }}}

-- {{{ wow.get_rating_conversion
-- Get rating required for 1% (or 1 point) at given level
function wow.get_rating_conversion(stat_type, level)
    level = level or 70

    local base_key = stat_type:upper()
    local base = RATING_CONVERSIONS[base_key .. "_RATING_PER_PERCENT"]
        or RATING_CONVERSIONS[base_key .. "_RATING_PER_POINT"]
        or RATING_CONVERSIONS[base_key .. "_PER_PERCENT"]

    if not base then return nil end

    -- Rating requirements increase at higher levels
    -- At level 70, ratings are at base value
    -- At level 60, ratings are more efficient
    if level >= 70 then
        return base
    elseif level >= 60 then
        -- Linear interpolation between 60 and 70
        local factor = 0.7 + (0.3 * (level - 60) / 10)
        return base * factor
    else
        -- Below 60, ratings are very efficient
        return base * 0.5
    end
end
-- }}}

-- {{{ wow.reset
function wow.reset()
    registered = false
end
-- }}}

-- }}}

-- {{{ Exports for testing/introspection
wow.RATING_CONVERSIONS = RATING_CONVERSIONS
wow.CLASS_BASE_STATS = CLASS_BASE_STATS
wow.STAT_PER_LEVEL = STAT_PER_LEVEL
wow.XP_TABLE = XP_TABLE
wow.WOW_CORE = WOW_CORE
wow.WOW_PRIMARY = WOW_PRIMARY
wow.WOW_SECONDARY_BASE = WOW_SECONDARY_BASE
wow.WOW_RESOURCES = WOW_RESOURCES
wow.WOW_DERIVED = WOW_DERIVED
-- }}}

return wow

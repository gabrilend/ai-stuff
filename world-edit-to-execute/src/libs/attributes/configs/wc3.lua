-- WC3 Attribute Configuration Module
-- Defines all Warcraft 3 attributes, derived stats, hero classes, and XP tables.
--
-- This module provides:
-- - Primary stats (Strength, Agility, Intelligence)
-- - Resource stats (Health, Mana, regeneration)
-- - Combat stats (damage, armor, attack speed)
-- - Derived attributes with WC3-accurate formulas
-- - Hero class definitions with stat gains per level
-- - Experience table for levels 1-25
--
-- Usage:
--   local wc3 = require("libs.attributes.configs.wc3")
--   wc3.register_all()
--   local container = registry.create_container()
--   wc3.apply_hero_class(container, "paladin", 5)

local registry = require("libs.attributes.registry")
local schema_module = require("libs.attributes.schema")
local ATTR_TYPE = schema_module.ATTR_TYPE
local ATTR_FLAGS = schema_module.ATTR_FLAGS

-- {{{ Module state
local wc3 = {}
local registered = false
-- }}}

-- {{{ Constants
-- Combined flags for common patterns
local PERSISTED_MODIFIABLE = ATTR_FLAGS.PERSISTED + ATTR_FLAGS.MODIFIABLE
-- }}}

-- {{{ WC3 Attribute Definitions

-- {{{ WC3_CORE - Core Unit Attributes
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

-- {{{ WC3_RESOURCES - Health and Mana
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

    -- Current values (not derived - mutable during combat)
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

-- {{{ WC3_COMBAT - Combat Stats
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

    -- Attack range
    attack_range = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 100,  -- Melee range
        flags = PERSISTED_MODIFIABLE,
    },
}
-- }}}

-- {{{ WC3_DERIVED - Derived Attributes
-- These are computed from base attributes using WC3 formulas
local WC3_DERIVED = {
    -- Max health = base_health + (strength * 25)
    -- WC3 gives 25 HP per point of strength for heroes
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
    -- WC3 gives 15 mana per point of intelligence for heroes
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
    -- WC3 gives 0.05 HP/sec per strength (called "always" regen)
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
    -- WC3 gives 0.05 mana/sec per intelligence
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
    -- WC3 gives 1 armor per 3 agility (0.333... per point)
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
    -- WC3 formula: damage_multiplier = 1 - (armor * 0.06 / (1 + 0.06 * |armor|))
    -- For positive armor, this reduces damage taken
    armor_reduction = {
        type = ATTR_TYPE.FLOAT,
        min = -100, max = 100,
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "armor" },
        formula = function(get)
            local armor = get("armor")
            if armor == 0 then return 0 end
            return (armor * 0.06 / (1 + 0.06 * math.abs(armor))) * 100
        end,
    },

    -- Attack damage bonus from primary stat
    -- Primary stat type determines which stat adds to attack damage
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

    -- Total damage min = base_damage_min + attack_damage_bonus
    damage_min = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 10,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "base_damage_min", "attack_damage_bonus" },
        formula = function(get)
            return get("base_damage_min") + get("attack_damage_bonus")
        end,
    },

    -- Total damage max = base_damage_max + attack_damage_bonus
    damage_max = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 12,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "base_damage_max", "attack_damage_bonus" },
        formula = function(get)
            return get("base_damage_max") + get("attack_damage_bonus")
        end,
    },

    -- Attack speed modifier from agility (1% per point)
    -- This is the IAS (Increased Attack Speed) percentage
    attack_speed_bonus = {
        type = ATTR_TYPE.FLOAT,
        min = 0,
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "agility" },
        formula = function(get)
            return get("agility")  -- 1% per agility
        end,
    },

    -- Effective attack cooldown
    -- attack_cooldown = base_cooldown / (1 + IAS/100)
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

    -- DPS approximation (average damage / attack cooldown)
    dps = {
        type = ATTR_TYPE.FLOAT,
        min = 0,
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "damage_min", "damage_max", "attack_cooldown" },
        formula = function(get)
            local avg_damage = (get("damage_min") + get("damage_max")) / 2
            local cooldown = get("attack_cooldown")
            if cooldown <= 0 then return 0 end
            return avg_damage / cooldown
        end,
    },
}
-- }}}

-- }}}

-- {{{ Hero Class Definitions
-- Stat gains per level for different hero types, based on WC3 data
local HERO_CLASSES = {
    -- {{{ Strength Heroes (Human)
    paladin = {
        primary_stat = "strength",
        base_strength = 24,
        base_agility = 13,
        base_intelligence = 17,
        strength_per_level = 2.7,
        agility_per_level = 1.5,
        intelligence_per_level = 1.8,
        base_health = 100,
        base_mana = 255,
    },
    mountain_king = {
        primary_stat = "strength",
        base_strength = 24,
        base_agility = 11,
        base_intelligence = 15,
        strength_per_level = 3.0,
        agility_per_level = 1.5,
        intelligence_per_level = 1.5,
        base_health = 100,
        base_mana = 200,
    },
    -- }}}

    -- {{{ Strength Heroes (Orc)
    tauren_chieftain = {
        primary_stat = "strength",
        base_strength = 25,
        base_agility = 10,
        base_intelligence = 14,
        strength_per_level = 3.2,
        agility_per_level = 1.0,
        intelligence_per_level = 1.5,
        base_health = 100,
        base_mana = 225,
    },
    -- }}}

    -- {{{ Strength Heroes (Undead)
    death_knight = {
        primary_stat = "strength",
        base_strength = 23,
        base_agility = 12,
        base_intelligence = 17,
        strength_per_level = 2.7,
        agility_per_level = 1.5,
        intelligence_per_level = 1.8,
        base_health = 100,
        base_mana = 255,
    },
    -- }}}

    -- {{{ Agility Heroes
    demon_hunter = {
        primary_stat = "agility",
        base_strength = 21,
        base_agility = 22,
        base_intelligence = 16,
        strength_per_level = 2.4,
        agility_per_level = 1.5,
        intelligence_per_level = 2.1,
        base_health = 100,
        base_mana = 240,
    },
    blademaster = {
        primary_stat = "agility",
        base_strength = 18,
        base_agility = 23,
        base_intelligence = 16,
        strength_per_level = 2.0,
        agility_per_level = 2.75,
        intelligence_per_level = 1.75,
        base_health = 100,
        base_mana = 240,
    },
    warden = {
        primary_stat = "agility",
        base_strength = 18,
        base_agility = 23,
        base_intelligence = 16,
        strength_per_level = 2.0,
        agility_per_level = 2.8,
        intelligence_per_level = 1.5,
        base_health = 100,
        base_mana = 240,
    },
    -- }}}

    -- {{{ Intelligence Heroes
    archmage = {
        primary_stat = "intelligence",
        base_strength = 14,
        base_agility = 17,
        base_intelligence = 24,
        strength_per_level = 1.8,
        agility_per_level = 1.0,
        intelligence_per_level = 3.2,
        base_health = 100,
        base_mana = 285,
    },
    blood_mage = {
        primary_stat = "intelligence",
        base_strength = 18,
        base_agility = 14,
        base_intelligence = 22,
        strength_per_level = 2.0,
        agility_per_level = 1.0,
        intelligence_per_level = 3.0,
        base_health = 100,
        base_mana = 270,
    },
    lich = {
        primary_stat = "intelligence",
        base_strength = 15,
        base_agility = 14,
        base_intelligence = 24,
        strength_per_level = 1.6,
        agility_per_level = 1.4,
        intelligence_per_level = 3.4,
        base_health = 100,
        base_mana = 285,
    },
    keeper_of_the_grove = {
        primary_stat = "intelligence",
        base_strength = 16,
        base_agility = 15,
        base_intelligence = 22,
        strength_per_level = 1.8,
        agility_per_level = 1.5,
        intelligence_per_level = 2.9,
        base_health = 100,
        base_mana = 270,
    },
    -- }}}

    -- {{{ Neutral Heroes
    dark_ranger = {
        primary_stat = "agility",
        base_strength = 17,
        base_agility = 21,
        base_intelligence = 19,
        strength_per_level = 1.9,
        agility_per_level = 2.1,
        intelligence_per_level = 2.4,
        base_health = 100,
        base_mana = 255,
    },
    naga_sea_witch = {
        primary_stat = "intelligence",
        base_strength = 15,
        base_agility = 18,
        base_intelligence = 22,
        strength_per_level = 1.5,
        agility_per_level = 1.5,
        intelligence_per_level = 3.0,
        base_health = 100,
        base_mana = 270,
    },
    pit_lord = {
        primary_stat = "strength",
        base_strength = 26,
        base_agility = 13,
        base_intelligence = 17,
        strength_per_level = 3.0,
        agility_per_level = 1.3,
        intelligence_per_level = 1.7,
        base_health = 100,
        base_mana = 255,
    },
    -- }}}
}
-- }}}

-- {{{ Experience Table
-- XP required to reach each level (WC3 standard + extended)
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
    -- Extended beyond vanilla WC3 level 10
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
-- }}}

-- {{{ Public API

-- {{{ wc3.register_all
-- Register all WC3 attributes with the registry.
-- Should be called once during initialization.
function wc3.register_all()
    if registered then
        return false, "WC3 attributes already registered"
    end

    registry.register_bulk(WC3_CORE)
    registry.register_bulk(WC3_RESOURCES)
    registry.register_bulk(WC3_COMBAT)
    registry.register_bulk(WC3_DERIVED)

    registered = true
    return true
end
-- }}}

-- {{{ wc3.is_registered
-- Check if WC3 attributes have been registered.
function wc3.is_registered()
    return registered
end
-- }}}

-- {{{ wc3.get_hero_class
-- Get hero class definition by name.
-- @param class_name Hero class name (e.g., "paladin", "archmage")
-- @return Hero class table or nil if not found
function wc3.get_hero_class(class_name)
    return HERO_CLASSES[class_name]
end
-- }}}

-- {{{ wc3.list_hero_classes
-- Get list of all available hero class names.
-- @return Sorted array of hero class names
function wc3.list_hero_classes()
    local result = {}
    for name, _ in pairs(HERO_CLASSES) do
        result[#result + 1] = name
    end
    table.sort(result)
    return result
end
-- }}}

-- {{{ wc3.get_hero_classes_by_primary
-- Get hero classes grouped by primary stat.
-- @return Table with keys "strength", "agility", "intelligence"
function wc3.get_hero_classes_by_primary()
    local result = {
        strength = {},
        agility = {},
        intelligence = {},
    }
    for name, class in pairs(HERO_CLASSES) do
        table.insert(result[class.primary_stat], name)
    end
    for _, list in pairs(result) do
        table.sort(list)
    end
    return result
end
-- }}}

-- {{{ wc3.apply_hero_class
-- Apply hero class stats to a container.
-- Sets primary stat, base stats, and level-appropriate values.
-- @param container The attribute container
-- @param class_name Hero class name
-- @param level Target level (default 1)
-- @return true on success, or false and error message
function wc3.apply_hero_class(container, class_name, level)
    local class = HERO_CLASSES[class_name]
    if not class then
        return false, "Unknown hero class: " .. tostring(class_name)
    end

    local setters = require("libs.attributes.setters")

    level = level or 1
    if level < 1 then level = 1 end
    if level > 25 then level = 25 end

    -- Calculate stats for level
    -- Stats at level N = base + (per_level * (N - 1))
    local levels_gained = level - 1
    local strength = math.floor(class.base_strength + (class.strength_per_level * levels_gained))
    local agility = math.floor(class.base_agility + (class.agility_per_level * levels_gained))
    local intelligence = math.floor(class.base_intelligence + (class.intelligence_per_level * levels_gained))

    -- Apply all stats at once
    setters.set_many(container, {
        level = level,
        experience = XP_TABLE[level] or 0,
        primary_stat = class.primary_stat,
        strength = strength,
        agility = agility,
        intelligence = intelligence,
        base_health = class.base_health or 100,
        base_mana = class.base_mana or 0,
    }, { source = "hero_class:" .. class_name })

    return true
end
-- }}}

-- {{{ wc3.calculate_stats_at_level
-- Calculate hero stats at a given level without applying to container.
-- Useful for UI display or planning.
-- @param class_name Hero class name
-- @param level Target level
-- @return Stats table or nil and error message
function wc3.calculate_stats_at_level(class_name, level)
    local class = HERO_CLASSES[class_name]
    if not class then
        return nil, "Unknown hero class: " .. tostring(class_name)
    end

    level = level or 1
    if level < 1 then level = 1 end
    if level > 25 then level = 25 end

    local levels_gained = level - 1
    return {
        level = level,
        strength = math.floor(class.base_strength + (class.strength_per_level * levels_gained)),
        agility = math.floor(class.base_agility + (class.agility_per_level * levels_gained)),
        intelligence = math.floor(class.base_intelligence + (class.intelligence_per_level * levels_gained)),
        primary_stat = class.primary_stat,
    }
end
-- }}}

-- {{{ wc3.get_xp_for_level
-- Get XP required to reach a specific level.
-- @param level Target level (1-25)
-- @return XP required
function wc3.get_xp_for_level(level)
    if level < 1 then return 0 end
    if level > 25 then return XP_TABLE[25] end
    return XP_TABLE[level] or XP_TABLE[25]
end
-- }}}

-- {{{ wc3.get_level_for_xp
-- Get the level for a given amount of XP.
-- @param xp Current experience points
-- @return Current level (1-25)
function wc3.get_level_for_xp(xp)
    for lvl = 25, 1, -1 do
        if xp >= (XP_TABLE[lvl] or 0) then
            return lvl
        end
    end
    return 1
end
-- }}}

-- {{{ wc3.get_xp_to_next_level
-- Calculate XP needed to reach the next level.
-- @param current_xp Current experience points
-- @return XP needed, or 0 if at max level
function wc3.get_xp_to_next_level(current_xp)
    local current_level = wc3.get_level_for_xp(current_xp)
    if current_level >= 25 then
        return 0
    end
    local next_level_xp = XP_TABLE[current_level + 1]
    return next_level_xp - current_xp
end
-- }}}

-- {{{ wc3.get_xp_progress
-- Get progress toward next level as a percentage.
-- @param current_xp Current experience points
-- @return Progress percentage (0-100), or 100 if at max level
function wc3.get_xp_progress(current_xp)
    local current_level = wc3.get_level_for_xp(current_xp)
    if current_level >= 25 then
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

-- {{{ wc3.level_up
-- Apply stat gains from leveling up.
-- @param container The attribute container
-- @param class_name Hero class name (for per-level gains)
-- @return true on success, or false and error message
function wc3.level_up(container, class_name)
    local class = HERO_CLASSES[class_name]
    if not class then
        return false, "Unknown hero class: " .. tostring(class_name)
    end

    local getters = require("libs.attributes.getters")
    local setters = require("libs.attributes.setters")

    local current_level = getters.get(container, "level")
    if current_level >= 25 then
        return false, "Already at max level"
    end

    local new_level = current_level + 1

    -- Calculate stat gains (floored)
    local str_gain = math.floor(class.strength_per_level)
    local agi_gain = math.floor(class.agility_per_level)
    local int_gain = math.floor(class.intelligence_per_level)

    -- Apply level-up
    setters.set(container, "level", new_level, { source = "level_up" })
    setters.adjust(container, "strength", str_gain, { source = "level_up" })
    setters.adjust(container, "agility", agi_gain, { source = "level_up" })
    setters.adjust(container, "intelligence", int_gain, { source = "level_up" })

    return true, {
        new_level = new_level,
        strength_gained = str_gain,
        agility_gained = agi_gain,
        intelligence_gained = int_gain,
    }
end
-- }}}

-- {{{ wc3.reset
-- Reset the registered state (for testing).
function wc3.reset()
    registered = false
end
-- }}}

-- }}}

-- {{{ Exports for testing/introspection
wc3.HERO_CLASSES = HERO_CLASSES
wc3.XP_TABLE = XP_TABLE
wc3.WC3_CORE = WC3_CORE
wc3.WC3_RESOURCES = WC3_RESOURCES
wc3.WC3_COMBAT = WC3_COMBAT
wc3.WC3_DERIVED = WC3_DERIVED
-- }}}

return wc3

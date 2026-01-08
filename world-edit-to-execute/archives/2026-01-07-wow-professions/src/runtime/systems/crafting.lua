--[[
Crafting Professions System (Issue 702c)

Handles the crafting flow: consuming materials, creating items, and skill
progression. Integrates with professions (702a) and recipes (702d).

Core concepts:
- Crafting stations: Physical objects required for certain crafts
- Craft flow: Check requirements, consume reagents, create output
- Quality: Optional system for crafted item quality variation
- Events: Notifications for craft start/success/failure

Usage:
    local crafting = require("runtime.systems.crafting")
    local ecs = require("runtime.ecs")

    -- Start crafting a recipe
    local success, err = crafting.start_craft(entity, "iron_sword", 1)

    -- Check craftable recipes
    local craftable = crafting.get_craftable_recipes(entity, "blacksmithing")
]]

-- {{{ Configuration
local DIR = arg and arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path
-- }}}

local ecs = require("runtime.ecs")
local events = require("runtime.events")

local crafting = {}

-- ============================================================================
-- Constants
-- ============================================================================

-- {{{ CRAFT_STATE
-- State of an ongoing craft.
crafting.STATE = {
    IDLE = "idle",
    CRAFTING = "crafting",
    INTERRUPTED = "interrupted",
}
-- }}}

-- {{{ QUALITY
-- Quality levels for crafted items.
crafting.QUALITY = {
    POOR = 0,       -- Gray - failed craft
    COMMON = 1,     -- White - normal
    UNCOMMON = 2,   -- Green - bonus stats
    RARE = 3,       -- Blue - significant bonus
    EPIC = 4,       -- Purple - max stats
}
-- }}}

-- {{{ QUALITY_NAMES
-- Display names for quality levels.
crafting.QUALITY_NAMES = {
    [0] = "Poor",
    [1] = "Common",
    [2] = "Uncommon",
    [3] = "Rare",
    [4] = "Epic",
}
-- }}}

-- {{{ STATION_TYPE
-- Types of crafting stations.
crafting.STATION_TYPE = {
    FORGE = "forge",
    ANVIL = "anvil",
    ALCHEMY_LAB = "alchemy_lab",
    WORKSHOP = "workshop",
    ENCHANTING_TABLE = "enchanting_table",
    COOKING_FIRE = "cooking_fire",
    CAMPFIRE = "campfire",
    STOVE = "stove",
    LOOM = "loom",
    TANNING_RACK = "tanning_rack",
    INSCRIPTION_TABLE = "inscription_table",
    JEWELER_BENCH = "jeweler_bench",
    -- WC3 equivalents
    ARMORY = "armory",
    SHOP = "shop",
    ALTAR = "altar",
}
-- }}}

-- ============================================================================
-- Event Constants
-- ============================================================================

-- {{{ Crafting events
crafting.EVENT = {
    CRAFT_START = 300,
    CRAFT_SUCCESS = 301,
    CRAFT_FAILED = 302,
    CRAFT_INTERRUPTED = 303,
    STATION_USED = 304,
    STATION_LEFT = 305,
    QUALITY_BONUS = 306,
}
-- }}}

-- ============================================================================
-- Component Definitions
-- ============================================================================

-- {{{ CRAFTING_STATION_DEFAULTS
-- Crafting station component attached to world objects.
local CRAFTING_STATION_DEFAULTS = {
    station_type = nil,             -- One of STATION_TYPE
    professions_supported = {},     -- Array of profession IDs

    -- Bonus effects
    skill_bonus = 0,                -- +X to effective skill
    speed_bonus = 0,                -- % faster crafting (0 = normal)

    -- Fuel system (optional)
    requires_fuel = false,
    fuel_type = nil,                -- Item ID for fuel
    fuel_remaining = 0,             -- Units of fuel left
    fuel_consumption_rate = 1,      -- Fuel per craft

    -- Usage tracking
    in_use_by = nil,                -- Entity currently using station
    queue = {},                     -- Entities waiting to use
}
-- }}}

-- {{{ CRAFTING_STATE_DEFAULTS
-- Crafting state component attached to entities that can craft.
local CRAFTING_STATE_DEFAULTS = {
    state = "idle",                 -- idle, crafting, interrupted
    current_recipe = nil,           -- Recipe ID being crafted
    current_quantity = 0,           -- Number being crafted
    craft_start_time = 0,           -- When craft started
    craft_end_time = 0,             -- When craft will complete
    station_entity = nil,           -- Station being used (if any)
    progress = 0,                   -- 0.0 to 1.0
}
-- }}}

-- {{{ Register components
local function register_components()
    if not (ecs.component_exists and ecs.component_exists("crafting_station")) then
        ecs.register_component("crafting_station", CRAFTING_STATION_DEFAULTS)
    end
    if not (ecs.component_exists and ecs.component_exists("crafting_state")) then
        ecs.register_component("crafting_state", CRAFTING_STATE_DEFAULTS)
    end
end
-- }}}

-- ============================================================================
-- Lazy Loading
-- ============================================================================

-- {{{ get_professions
-- Lazy-load professions module to avoid circular dependency.
local _professions = nil
local function get_professions()
    if not _professions then
        _professions = require("runtime.systems.professions")
    end
    return _professions
end
-- }}}

-- {{{ get_recipes
-- Lazy-load recipes module to avoid circular dependency.
local _recipes = nil
local function get_recipes()
    if not _recipes then
        _recipes = require("runtime.systems.recipes")
    end
    return _recipes
end
-- }}}

-- ============================================================================
-- Helper Functions
-- ============================================================================

-- {{{ ensure_fresh_tables
-- Ensure the component has fresh tables (not inherited from defaults).
local function ensure_fresh_tables(comp, defaults)
    if rawget(comp, "_initialized") then
        return
    end

    for key, value in pairs(defaults) do
        if type(value) == "table" then
            rawset(comp, key, {})
        else
            rawset(comp, key, value)
        end
    end
    rawset(comp, "_initialized", true)
end
-- }}}

-- {{{ get_crafting_state
-- Get or create crafting state component for an entity.
-- @param entity_id Entity ID
-- @return Component or nil
local function get_crafting_state(entity_id)
    local comp = ecs.get_component(entity_id, "crafting_state")
    if comp then
        ensure_fresh_tables(comp, CRAFTING_STATE_DEFAULTS)
    end
    return comp
end
-- }}}

-- ============================================================================
-- Station Management
-- ============================================================================

-- {{{ crafting.is_station_available
-- Check if a station is available for use.
-- @param station_id Station entity ID
-- @return boolean, reason if not available
function crafting.is_station_available(station_id)
    local station = ecs.get_component(station_id, "crafting_station")
    if not station then
        return false, "Not a crafting station"
    end

    ensure_fresh_tables(station, CRAFTING_STATION_DEFAULTS)

    if station.in_use_by then
        return false, "Station in use"
    end

    if station.requires_fuel and station.fuel_remaining <= 0 then
        return false, "Station needs fuel"
    end

    return true
end
-- }}}

-- {{{ crafting.use_station
-- Begin using a crafting station.
-- @param entity_id Entity ID
-- @param station_id Station entity ID
-- @return true on success, false and error on failure
function crafting.use_station(entity_id, station_id)
    local available, err = crafting.is_station_available(station_id)
    if not available then
        return false, err
    end

    local station = ecs.get_component(station_id, "crafting_station")
    ensure_fresh_tables(station, CRAFTING_STATION_DEFAULTS)

    local state = get_crafting_state(entity_id)
    if not state then
        return false, "Entity cannot craft"
    end

    -- Already using a station?
    if state.station_entity then
        return false, "Already using a station"
    end

    station.in_use_by = entity_id
    state.station_entity = station_id

    events.fire(crafting.EVENT.STATION_USED, {
        entity = entity_id,
        station = station_id,
        station_type = station.station_type,
    })

    return true
end
-- }}}

-- {{{ crafting.leave_station
-- Stop using a crafting station.
-- @param entity_id Entity ID
-- @return true on success
function crafting.leave_station(entity_id)
    local state = get_crafting_state(entity_id)
    if not state then
        return false
    end

    local station_id = state.station_entity
    if not station_id then
        return false  -- Not using a station
    end

    local station = ecs.get_component(station_id, "crafting_station")
    if station then
        ensure_fresh_tables(station, CRAFTING_STATION_DEFAULTS)
        if station.in_use_by == entity_id then
            station.in_use_by = nil
        end
    end

    state.station_entity = nil

    events.fire(crafting.EVENT.STATION_LEFT, {
        entity = entity_id,
        station = station_id,
    })

    return true
end
-- }}}

-- {{{ crafting.get_station_info
-- Get information about a crafting station.
-- @param station_id Station entity ID
-- @return Station info table or nil
function crafting.get_station_info(station_id)
    local station = ecs.get_component(station_id, "crafting_station")
    if not station then
        return nil
    end

    ensure_fresh_tables(station, CRAFTING_STATION_DEFAULTS)

    return {
        station_type = station.station_type,
        professions = station.professions_supported,
        skill_bonus = station.skill_bonus,
        speed_bonus = station.speed_bonus,
        in_use = station.in_use_by ~= nil,
        needs_fuel = station.requires_fuel and station.fuel_remaining <= 0,
        fuel_remaining = station.fuel_remaining,
    }
end
-- }}}

-- {{{ crafting.supports_profession
-- Check if a station supports a specific profession.
-- @param station_id Station entity ID
-- @param profession_id Profession identifier
-- @return boolean
function crafting.supports_profession(station_id, profession_id)
    local station = ecs.get_component(station_id, "crafting_station")
    if not station then
        return false
    end

    ensure_fresh_tables(station, CRAFTING_STATION_DEFAULTS)

    for _, prof in ipairs(station.professions_supported) do
        if prof == profession_id then
            return true
        end
    end
    return false
end
-- }}}

-- {{{ crafting.add_fuel
-- Add fuel to a station.
-- @param station_id Station entity ID
-- @param amount Amount of fuel to add
-- @return New fuel amount or nil if not a station
function crafting.add_fuel(station_id, amount)
    local station = ecs.get_component(station_id, "crafting_station")
    if not station then
        return nil
    end

    ensure_fresh_tables(station, CRAFTING_STATION_DEFAULTS)
    station.fuel_remaining = station.fuel_remaining + amount
    return station.fuel_remaining
end
-- }}}

-- ============================================================================
-- Craft Requirements
-- ============================================================================

-- {{{ crafting.can_craft
-- Check if an entity can craft a recipe.
-- @param entity_id Entity ID
-- @param recipe_id Recipe identifier
-- @param station_id Optional station being used
-- @return boolean, error_message if false
function crafting.can_craft(entity_id, recipe_id, station_id)
    local recipes = get_recipes()
    local professions = get_professions()

    local recipe = recipes.get(recipe_id)
    if not recipe then
        return false, "Recipe not found"
    end

    -- Must know the recipe
    if not recipes.knows(entity_id, recipe_id) then
        return false, "Recipe not known"
    end

    -- Must have the profession
    if not professions.has_profession(entity_id, recipe.profession) then
        return false, "Profession not learned"
    end

    -- Check skill level
    local skill = professions.get_skill(entity_id, recipe.profession)
    if not skill or skill < recipe.skill_required then
        return false, "Skill too low"
    end

    -- Check station requirement
    if recipe.station then
        if not station_id then
            return false, "Requires crafting station: " .. recipe.station
        end
        local station = ecs.get_component(station_id, "crafting_station")
        if not station then
            return false, "Invalid station"
        end
        ensure_fresh_tables(station, CRAFTING_STATION_DEFAULTS)
        if station.station_type ~= recipe.station then
            return false, "Wrong station type"
        end
    end

    -- Check tool requirement (simplified - tool check would need inventory)
    -- TODO: Integrate with inventory system for tool check

    -- Note: Reagent check is handled separately (needs inventory system)

    return true
end
-- }}}

-- {{{ crafting.get_missing_reagents
-- Get list of missing reagents for a recipe.
-- @param entity_id Entity ID
-- @param recipe_id Recipe identifier
-- @return Array of { item, needed, have }
function crafting.get_missing_reagents(entity_id, recipe_id)
    local recipes = get_recipes()
    local recipe = recipes.get(recipe_id)
    if not recipe then
        return {}
    end

    -- Without inventory system, return all reagents as "missing"
    -- TODO: Integrate with inventory system
    local missing = {}
    for _, reagent in ipairs(recipe.reagents or {}) do
        missing[#missing + 1] = {
            item = reagent.item,
            needed = reagent.count,
            have = 0,
        }
    end
    return missing
end
-- }}}

-- ============================================================================
-- Craft Execution
-- ============================================================================

-- {{{ crafting.start_craft
-- Begin crafting a recipe.
-- @param entity_id Entity ID
-- @param recipe_id Recipe identifier
-- @param quantity Number to craft (default 1)
-- @return true on success, false and error on failure
function crafting.start_craft(entity_id, recipe_id, quantity)
    quantity = quantity or 1

    local state = get_crafting_state(entity_id)
    if not state then
        return false, "Entity cannot craft"
    end

    -- Already crafting?
    if state.state == crafting.STATE.CRAFTING then
        return false, "Already crafting"
    end

    -- Can craft this recipe?
    local can, err = crafting.can_craft(entity_id, recipe_id, state.station_entity)
    if not can then
        return false, err
    end

    local recipes = get_recipes()
    local recipe = recipes.get(recipe_id)

    -- Calculate craft time (apply station bonus if applicable)
    local cast_time = recipe.cast_time or 0
    if state.station_entity then
        local station = ecs.get_component(state.station_entity, "crafting_station")
        if station and station.speed_bonus > 0 then
            cast_time = cast_time * (1 - station.speed_bonus / 100)
        end
    end

    -- Update state
    local now = os.time()
    state.state = crafting.STATE.CRAFTING
    state.current_recipe = recipe_id
    state.current_quantity = quantity
    state.craft_start_time = now
    state.craft_end_time = now + cast_time
    state.progress = 0

    events.fire(crafting.EVENT.CRAFT_START, {
        entity = entity_id,
        recipe = recipe_id,
        quantity = quantity,
        duration = cast_time,
    })

    -- If instant (cast_time = 0), complete immediately
    if cast_time <= 0 then
        return crafting.complete_craft(entity_id)
    end

    return true
end
-- }}}

-- {{{ crafting.cancel_craft
-- Cancel an ongoing craft.
-- @param entity_id Entity ID
-- @return true if cancelled, false if not crafting
function crafting.cancel_craft(entity_id)
    local state = get_crafting_state(entity_id)
    if not state then
        return false
    end

    if state.state ~= crafting.STATE.CRAFTING then
        return false
    end

    local recipe_id = state.current_recipe

    -- Reset state
    state.state = crafting.STATE.IDLE
    state.current_recipe = nil
    state.current_quantity = 0
    state.craft_start_time = 0
    state.craft_end_time = 0
    state.progress = 0

    events.fire(crafting.EVENT.CRAFT_INTERRUPTED, {
        entity = entity_id,
        recipe = recipe_id,
    })

    return true
end
-- }}}

-- {{{ crafting.complete_craft
-- Complete an ongoing craft, creating the output.
-- @param entity_id Entity ID
-- @return true on success, result table with output info
function crafting.complete_craft(entity_id)
    local state = get_crafting_state(entity_id)
    if not state then
        return false, "Entity cannot craft"
    end

    local recipe_id = state.current_recipe
    if not recipe_id then
        return false, "Not crafting anything"
    end

    local recipes = get_recipes()
    local professions = get_professions()
    local recipe = recipes.get(recipe_id)
    if not recipe then
        return false, "Recipe no longer valid"
    end

    -- Get skill for quality calculation
    local skill = professions.get_skill(entity_id, recipe.profession) or 0
    local quantity = state.current_quantity or 1

    -- Calculate quality (if quality system enabled)
    local quality = crafting.calculate_quality(skill, recipe.skill_required)

    -- Record the craft for statistics
    recipes.record_craft(entity_id, recipe_id)

    -- Try skill up
    professions.try_skillup(entity_id, recipe.profession, recipe.skill_required)

    -- Try recipe discovery
    recipes.try_discovery(entity_id, recipe_id)

    -- Consume fuel if at a station
    if state.station_entity then
        local station = ecs.get_component(state.station_entity, "crafting_station")
        if station and station.requires_fuel then
            ensure_fresh_tables(station, CRAFTING_STATION_DEFAULTS)
            station.fuel_remaining = station.fuel_remaining - (station.fuel_consumption_rate or 1)
        end
    end

    -- Build result
    local result = {
        recipe = recipe_id,
        output = recipe.output,
        quantity = quantity,
        quality = quality,
        quality_name = crafting.QUALITY_NAMES[quality] or "Unknown",
        byproducts = {},
    }

    -- Roll for byproducts
    for _, bp in ipairs(recipe.byproducts or {}) do
        if math.random() <= (bp.chance or 1.0) then
            result.byproducts[#result.byproducts + 1] = {
                item = bp.item,
                count = bp.count or 1,
            }
        end
    end

    -- Reset state
    state.state = crafting.STATE.IDLE
    state.current_recipe = nil
    state.current_quantity = 0
    state.craft_start_time = 0
    state.craft_end_time = 0
    state.progress = 1.0

    events.fire(crafting.EVENT.CRAFT_SUCCESS, {
        entity = entity_id,
        recipe = recipe_id,
        output = result.output,
        quantity = quantity,
        quality = quality,
    })

    -- Note: Actual item creation depends on inventory system (406)
    -- This returns what WOULD be created

    return true, result
end
-- }}}

-- {{{ crafting.update_progress
-- Update craft progress (call each frame/tick).
-- @param entity_id Entity ID
-- @return Progress 0.0-1.0, or nil if not crafting
function crafting.update_progress(entity_id)
    local state = get_crafting_state(entity_id)
    if not state or state.state ~= crafting.STATE.CRAFTING then
        return nil
    end

    local now = os.time()
    local total = state.craft_end_time - state.craft_start_time
    local elapsed = now - state.craft_start_time

    if total <= 0 then
        state.progress = 1.0
    else
        state.progress = math.min(1.0, elapsed / total)
    end

    return state.progress
end
-- }}}

-- {{{ crafting.is_craft_ready
-- Check if craft has finished and can be completed.
-- @param entity_id Entity ID
-- @return boolean
function crafting.is_craft_ready(entity_id)
    local state = get_crafting_state(entity_id)
    if not state or state.state ~= crafting.STATE.CRAFTING then
        return false
    end

    return os.time() >= state.craft_end_time
end
-- }}}

-- {{{ crafting.get_craft_state
-- Get current crafting state for an entity.
-- @param entity_id Entity ID
-- @return State info table or nil
function crafting.get_craft_state(entity_id)
    local state = get_crafting_state(entity_id)
    if not state then
        return nil
    end

    local info = {
        state = state.state,
        recipe = state.current_recipe,
        quantity = state.current_quantity,
        station = state.station_entity,
        progress = state.progress,
    }

    if state.state == crafting.STATE.CRAFTING then
        local now = os.time()
        info.time_remaining = math.max(0, state.craft_end_time - now)
        info.time_total = state.craft_end_time - state.craft_start_time
    end

    return info
end
-- }}}

-- ============================================================================
-- Quality System
-- ============================================================================

-- {{{ Quality configuration
local quality_config = {
    enabled = false,            -- Quality system disabled by default
    excess_skill_factor = 25,   -- Skill above recipe req for quality bonuses
    epic_threshold = 0.95,      -- Roll threshold for epic
    rare_threshold = 0.80,      -- Roll threshold for rare
    uncommon_threshold = 0.50,  -- Roll threshold for uncommon
}
-- }}}

-- {{{ crafting.set_quality_enabled
-- Enable or disable the quality system.
-- @param enabled boolean
function crafting.set_quality_enabled(enabled)
    quality_config.enabled = enabled
end
-- }}}

-- {{{ crafting.is_quality_enabled
-- Check if quality system is enabled.
-- @return boolean
function crafting.is_quality_enabled()
    return quality_config.enabled
end
-- }}}

-- {{{ crafting.calculate_quality
-- Calculate the quality of a crafted item.
-- @param skill Current skill level
-- @param recipe_skill Recipe's skill requirement
-- @param luck Optional luck modifier (0.0-1.0)
-- @return Quality constant
function crafting.calculate_quality(skill, recipe_skill, luck)
    if not quality_config.enabled then
        return crafting.QUALITY.COMMON
    end

    luck = luck or 0
    local excess_skill = skill - recipe_skill
    local roll = math.random() + luck

    -- Epic: High roll AND significant excess skill
    if roll > quality_config.epic_threshold and excess_skill > (quality_config.excess_skill_factor * 2) then
        return crafting.QUALITY.EPIC
    end

    -- Rare: Good roll AND good excess skill
    if roll > quality_config.rare_threshold and excess_skill > quality_config.excess_skill_factor then
        return crafting.QUALITY.RARE
    end

    -- Uncommon: Decent roll
    if roll > quality_config.uncommon_threshold then
        return crafting.QUALITY.UNCOMMON
    end

    return crafting.QUALITY.COMMON
end
-- }}}

-- ============================================================================
-- Recipe Queries
-- ============================================================================

-- {{{ crafting.get_craftable_recipes
-- Get all recipes an entity can currently craft.
-- @param entity_id Entity ID
-- @param profession_id Optional profession filter
-- @return Array of recipe IDs
function crafting.get_craftable_recipes(entity_id, profession_id)
    local recipes = get_recipes()
    local professions = get_professions()

    local result = {}

    -- Get known recipes
    local known
    if profession_id then
        known = recipes.get_known(entity_id, profession_id)
    else
        local all_known = recipes.get_all_known(entity_id)
        known = {}
        for prof, prof_recipes in pairs(all_known) do
            for _, recipe_id in ipairs(prof_recipes) do
                known[#known + 1] = recipe_id
            end
        end
    end

    -- Filter to those we can actually craft
    for _, recipe_id in ipairs(known) do
        local can = crafting.can_craft(entity_id, recipe_id)
        if can then
            result[#result + 1] = recipe_id
        end
    end

    return result
end
-- }}}

-- {{{ crafting.find_nearest_station
-- Find the nearest station of a type within range.
-- @param entity_id Entity ID
-- @param station_type Station type to find
-- @param max_range Maximum distance
-- @return Station entity ID or nil
function crafting.find_nearest_station(entity_id, station_type, max_range)
    -- Note: This requires position/spatial system
    -- Placeholder implementation returns nil
    -- TODO: Integrate with spatial query system
    return nil
end
-- }}}

-- ============================================================================
-- Profession Definitions
-- ============================================================================

-- {{{ Crafting profession definitions
-- Metadata for each crafting profession. Used for UI and validation.
crafting.PROFESSION_DEFS = {
    blacksmithing = {
        id = "blacksmithing",
        name = "Blacksmithing",
        type = "crafting",
        stations = {"forge", "anvil"},
        tool = "blacksmith_hammer",
        material_types = {"bar", "stone", "gem"},
        output_types = {"weapon", "armor", "shield", "mail", "plate"},
        specializations = {
            {id = "armorsmith", skill = 200, focus = "armor"},
            {id = "weaponsmith", skill = 200, focus = "weapons"},
        },
    },
    alchemy = {
        id = "alchemy",
        name = "Alchemy",
        type = "crafting",
        stations = {"alchemy_lab"},
        tool = nil,
        material_types = {"herb", "reagent", "vial"},
        output_types = {"potion", "elixir", "flask", "transmute"},
        discovery_enabled = true,
        discovery_chance = 0.05,
        specializations = {
            {id = "elixir_master", skill = 300, bonus = "elixirs"},
            {id = "potion_master", skill = 300, bonus = "potions"},
            {id = "transmutation_master", skill = 300, bonus = "transmutes"},
        },
    },
    engineering = {
        id = "engineering",
        name = "Engineering",
        type = "crafting",
        stations = {"workshop"},
        tool = "arclight_spanner",
        material_types = {"bar", "part", "cloth", "gem"},
        output_types = {"device", "explosive", "pet", "mount", "gadget"},
        malfunction_base = 0.05,
        specializations = {
            {id = "gnomish", skill = 200, theme = "utility"},
            {id = "goblin", skill = 200, theme = "explosives"},
        },
    },
    enchanting = {
        id = "enchanting",
        name = "Enchanting",
        type = "crafting",
        stations = {},
        tool = "runed_rod",
        material_types = {"dust", "essence", "shard", "crystal"},
        output_types = {"enchant"},
        disenchant_enabled = true,
        rods = {
            {id = "runed_copper_rod", skill = 1},
            {id = "runed_silver_rod", skill = 100},
            {id = "runed_golden_rod", skill = 150},
            {id = "runed_truesilver_rod", skill = 200},
            {id = "runed_arcanite_rod", skill = 290},
        },
    },
    leatherworking = {
        id = "leatherworking",
        name = "Leatherworking",
        type = "crafting",
        stations = {"tanning_rack"},
        tool = nil,
        material_types = {"leather", "hide", "scale"},
        output_types = {"leather_armor", "bag", "patch"},
        specializations = {
            {id = "dragonscale", skill = 225, focus = "mail"},
            {id = "elemental", skill = 225, focus = "nature_resist"},
            {id = "tribal", skill = 225, focus = "leather"},
        },
    },
    tailoring = {
        id = "tailoring",
        name = "Tailoring",
        type = "crafting",
        stations = {"loom"},
        tool = nil,
        material_types = {"cloth", "thread", "dye"},
        output_types = {"cloth_armor", "bag", "shirt"},
        specializations = {
            {id = "mooncloth", skill = 300, focus = "healing"},
            {id = "shadoweave", skill = 300, focus = "shadow"},
            {id = "spellfire", skill = 300, focus = "fire"},
        },
    },
    jewelcrafting = {
        id = "jewelcrafting",
        name = "Jewelcrafting",
        type = "crafting",
        stations = {"jeweler_bench"},
        tool = nil,
        material_types = {"gem", "bar", "stone"},
        output_types = {"gem", "jewelry", "trinket"},
    },
    inscription = {
        id = "inscription",
        name = "Inscription",
        type = "crafting",
        stations = {"inscription_table"},
        tool = nil,
        material_types = {"herb", "ink", "parchment"},
        output_types = {"glyph", "scroll", "card"},
    },
    cooking = {
        id = "cooking",
        name = "Cooking",
        type = "secondary",
        stations = {"cooking_fire", "campfire", "stove"},
        tool = nil,
        material_types = {"meat", "fish", "spice", "produce"},
        output_types = {"food"},
        buff_system = true,
    },
    first_aid = {
        id = "first_aid",
        name = "First Aid",
        type = "secondary",
        stations = {},
        tool = nil,
        material_types = {"cloth"},
        output_types = {"bandage"},
    },
}
-- }}}

-- {{{ crafting.get_profession_def
-- Get the definition for a crafting profession.
-- @param profession_id Profession identifier
-- @return Definition table or nil
function crafting.get_profession_def(profession_id)
    return crafting.PROFESSION_DEFS[profession_id]
end
-- }}}

-- ============================================================================
-- Initialization
-- ============================================================================

-- {{{ crafting.init
-- Initialize the crafting system.
function crafting.init()
    register_components()
end
-- }}}

-- {{{ crafting.reset
-- Reset crafting system state (for testing).
function crafting.reset()
    quality_config.enabled = false
end
-- }}}

return crafting

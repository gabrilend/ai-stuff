--[[
Profession System (Issue 702a)

Provides profession and skill tracking for entities, supporting both
WoW-style (limited primary slots, skill levels 1-300) and WC3-style
(unlimited professions, simple 1-5 levels) configurations.

Core concepts:
- Primary professions: Limited slots (WoW: 2), must choose
- Secondary professions: Unlimited, always available
- Skill levels: Progress through crafting/gathering
- Skill caps: Training unlocks higher caps (75→150→225→300)
- Recipes: Per-profession list of known recipes

Usage:
    local professions = require("runtime.systems.professions")
    local ecs = require("runtime.ecs")

    -- Add profession component to entity
    ecs.add_component(entity, "professions")

    -- Learn a profession
    professions.learn_profession(entity, "mining")

    -- Try to skill up after gathering
    local skilled_up = professions.try_skillup(entity, "mining", 50)

    -- Check skill level
    local level = professions.get_skill(entity, "mining")
]]

-- {{{ Configuration
local DIR = arg and arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path
-- }}}

local ecs = require("runtime.ecs")
local events = require("runtime.events")

local professions = {}

-- ============================================================================
-- Configuration Modes
-- ============================================================================

-- {{{ PROFESSION_MODE
-- Available profession system modes
professions.MODE = {
    WOW = "wow",      -- WoW-style: 2 primaries, 1-300 skill, training caps
    WC3 = "wc3",      -- WC3-style: unlimited, 1-5 levels, XP-based
    CUSTOM = "custom", -- User-defined configuration
}
-- }}}

-- {{{ PROFESSION_TYPE
-- Profession categories
professions.TYPE = {
    PRIMARY = "primary",     -- Limited slots (mining, blacksmithing, etc.)
    SECONDARY = "secondary", -- Unlimited (cooking, fishing, first aid)
}
-- }}}

-- {{{ DIFFICULTY
-- Recipe/action difficulty colors
professions.DIFFICULTY = {
    ORANGE = "orange",  -- 100% skillup
    YELLOW = "yellow",  -- 75% skillup
    GREEN = "green",    -- 25% skillup
    GRAY = "gray",      -- 0% skillup
}
-- }}}

-- {{{ Default configurations
local CONFIG = {
    wow = {
        max_primary_slots = 2,
        skill_min = 1,
        skill_max = 300,
        skill_caps = {75, 150, 225, 300},  -- Apprentice, Journeyman, Expert, Artisan
        use_experience = false,             -- Direct skill levels
        skillup_formula = "wow",
        -- Difficulty thresholds (skill - recipe_level)
        orange_threshold = 0,
        yellow_threshold = 10,
        green_threshold = 25,
        gray_threshold = 50,
    },
    wc3 = {
        max_primary_slots = 0,  -- No limit
        skill_min = 1,
        skill_max = 5,
        skill_caps = {1, 2, 3, 4, 5},
        use_experience = true,
        skillup_formula = "always",
        xp_per_level = 100,
    },
    custom = {
        -- Will be set by user via set_config()
    },
}

-- Active configuration (default to WoW mode)
local active_mode = "wow"
local active_config = CONFIG.wow
-- }}}

-- ============================================================================
-- Event Constants
-- ============================================================================

-- {{{ Profession events
-- Add profession-specific events to the events system
-- These can be listened to by triggers for quest updates, achievements, etc.
professions.EVENT = {
    PROFESSION_LEARNED = 100,
    PROFESSION_FORGOTTEN = 101,
    SKILL_UP = 102,
    SKILL_CAP_RAISED = 103,
    RECIPE_LEARNED = 104,
    SPECIALIZATION_CHOSEN = 105,
}
-- }}}

-- ============================================================================
-- Component Definition
-- ============================================================================

-- {{{ PROFESSIONS_DEFAULTS
-- Default values for the professions component
local PROFESSIONS_DEFAULTS = {
    -- Primary professions: {[profession_id] = skill_data}
    primary = {},

    -- Secondary professions: {[profession_id] = skill_data}
    secondary = {},

    -- Number of primary profession slots used
    primary_slots_used = 0,

    -- Currently active profession (for gathering actions)
    active_profession = nil,
}
-- }}}

-- {{{ create_skill_data
-- Create a new skill data structure for a profession.
-- @param initial_skill Starting skill level (default: config's skill_min)
-- @param initial_cap Starting skill cap (default: first cap tier, or skill_max in XP modes)
-- @return skill_data table
local function create_skill_data(initial_skill, initial_cap)
    initial_skill = initial_skill or active_config.skill_min
    -- In XP-based modes (WC3), start at max cap since levels are gained via XP.
    -- In training-based modes (WoW), start at first training tier cap.
    if initial_cap == nil then
        if active_config.use_experience then
            initial_cap = active_config.skill_max
        else
            initial_cap = active_config.skill_caps[1]
        end
    end

    return {
        skill_level = initial_skill,
        skill_max = initial_cap,
        experience = 0,
        specialization = nil,
        recipes_known = {},
        last_skillup = 0,
    }
end
-- }}}

-- {{{ Register component
-- Register the professions component with the ECS
local function register_component()
    -- Check if already registered
    if ecs.component_exists and ecs.component_exists("professions") then
        return
    end

    ecs.register_component("professions", PROFESSIONS_DEFAULTS)
end
-- }}}

-- ============================================================================
-- Configuration API
-- ============================================================================

-- {{{ professions.set_mode
-- Set the profession system mode.
-- @param mode One of professions.MODE values
function professions.set_mode(mode)
    if mode == professions.MODE.WOW then
        active_mode = "wow"
        active_config = CONFIG.wow
    elseif mode == professions.MODE.WC3 then
        active_mode = "wc3"
        active_config = CONFIG.wc3
    elseif mode == professions.MODE.CUSTOM then
        active_mode = "custom"
        active_config = CONFIG.custom
    else
        error("set_mode: unknown mode '" .. tostring(mode) .. "'")
    end
end
-- }}}

-- {{{ professions.get_mode
-- Get the current profession system mode.
-- @return Current mode string
function professions.get_mode()
    return active_mode
end
-- }}}

-- {{{ professions.set_config
-- Set custom configuration values.
-- @param config Table of configuration options
function professions.set_config(config)
    CONFIG.custom = config
    if active_mode == "custom" then
        active_config = CONFIG.custom
    end
end
-- }}}

-- {{{ professions.get_config
-- Get the active configuration.
-- @return Active config table
function professions.get_config()
    return active_config
end
-- }}}

-- ============================================================================
-- Skill Calculation
-- ============================================================================

-- {{{ get_difficulty_color
-- Determine difficulty color based on skill level vs recipe requirement.
-- @param skill_level Current skill level
-- @param recipe_skill Recipe's skill requirement
-- @return Difficulty constant (ORANGE, YELLOW, GREEN, GRAY)
local function get_difficulty_color(skill_level, recipe_skill)
    local diff = skill_level - recipe_skill

    if diff < active_config.orange_threshold then
        return nil  -- Can't craft (too low skill)
    elseif diff < active_config.yellow_threshold then
        return professions.DIFFICULTY.ORANGE
    elseif diff < active_config.green_threshold then
        return professions.DIFFICULTY.YELLOW
    elseif diff < active_config.gray_threshold then
        return professions.DIFFICULTY.GREEN
    else
        return professions.DIFFICULTY.GRAY
    end
end
-- }}}

-- {{{ professions.get_skillup_chance
-- Calculate the chance of gaining a skill point.
-- @param entity_id Entity with profession component
-- @param profession_id Profession identifier
-- @param recipe_skill Recipe's skill requirement
-- @return Chance as 0.0-1.0, or nil if can't craft
function professions.get_skillup_chance(entity_id, profession_id, recipe_skill)
    local skill = professions.get_skill(entity_id, profession_id)
    if not skill then
        return nil
    end

    -- WC3 mode: always skill up
    if active_config.skillup_formula == "always" then
        return 1.0
    end

    -- WoW mode: based on difficulty color
    local difficulty = get_difficulty_color(skill, recipe_skill)

    if not difficulty then
        return nil  -- Can't craft
    elseif difficulty == professions.DIFFICULTY.ORANGE then
        return 1.0
    elseif difficulty == professions.DIFFICULTY.YELLOW then
        return 0.75
    elseif difficulty == professions.DIFFICULTY.GREEN then
        return 0.25
    else  -- GRAY
        return 0.0
    end
end
-- }}}

-- {{{ professions.get_difficulty
-- Get the difficulty color for a recipe.
-- @param entity_id Entity with profession component
-- @param profession_id Profession identifier
-- @param recipe_skill Recipe's skill requirement
-- @return Difficulty constant or nil if can't craft
function professions.get_difficulty(entity_id, profession_id, recipe_skill)
    local skill = professions.get_skill(entity_id, profession_id)
    if not skill then
        return nil
    end

    return get_difficulty_color(skill, recipe_skill)
end
-- }}}

-- ============================================================================
-- Query Functions
-- ============================================================================

-- {{{ ensure_fresh_tables
-- Ensure the component has fresh tables (not inherited from defaults).
-- ECS uses metatable inheritance, so table fields are shared by reference.
-- This function ensures the component has its own copies of mutable tables.
local function ensure_fresh_tables(comp)
    -- Check if already initialized (has own primary table)
    if rawget(comp, "_initialized") then
        return
    end

    -- Create fresh tables
    rawset(comp, "primary", {})
    rawset(comp, "secondary", {})
    rawset(comp, "primary_slots_used", 0)
    rawset(comp, "active_profession", nil)
    rawset(comp, "_initialized", true)
end
-- }}}

-- {{{ get_profession_data
-- Internal helper to get profession data from component.
-- @param entity_id Entity ID
-- @param profession_id Profession identifier
-- @return skill_data table, profession_type, or nil if not found
local function get_profession_data(entity_id, profession_id)
    local comp = ecs.get_component(entity_id, "professions")
    if not comp then
        return nil, nil
    end

    ensure_fresh_tables(comp)

    -- Check primary professions first
    if comp.primary[profession_id] then
        return comp.primary[profession_id], professions.TYPE.PRIMARY
    end

    -- Then secondary
    if comp.secondary[profession_id] then
        return comp.secondary[profession_id], professions.TYPE.SECONDARY
    end

    return nil, nil
end
-- }}}

-- {{{ professions.get_skill
-- Get current skill level for a profession.
-- @param entity_id Entity ID
-- @param profession_id Profession identifier
-- @return Skill level or nil if profession not known
function professions.get_skill(entity_id, profession_id)
    local data = get_profession_data(entity_id, profession_id)
    return data and data.skill_level or nil
end
-- }}}

-- {{{ professions.get_max_skill
-- Get current skill cap for a profession.
-- @param entity_id Entity ID
-- @param profession_id Profession identifier
-- @return Skill cap or nil if profession not known
function professions.get_max_skill(entity_id, profession_id)
    local data = get_profession_data(entity_id, profession_id)
    return data and data.skill_max or nil
end
-- }}}

-- {{{ professions.has_profession
-- Check if entity knows a profession.
-- @param entity_id Entity ID
-- @param profession_id Profession identifier
-- @return boolean
function professions.has_profession(entity_id, profession_id)
    local data = get_profession_data(entity_id, profession_id)
    return data ~= nil
end
-- }}}

-- {{{ professions.can_learn_profession
-- Check if entity can learn a new profession.
-- @param entity_id Entity ID
-- @param profession_id Profession identifier
-- @param profession_type TYPE.PRIMARY or TYPE.SECONDARY
-- @return boolean, error_message
function professions.can_learn_profession(entity_id, profession_id, profession_type)
    local comp = ecs.get_component(entity_id, "professions")
    if not comp then
        return false, "Entity has no professions component"
    end

    ensure_fresh_tables(comp)

    -- Already knows this profession?
    if professions.has_profession(entity_id, profession_id) then
        return false, "Already knows this profession"
    end

    -- Check primary slot limits (only if not unlimited mode)
    if profession_type == professions.TYPE.PRIMARY and active_config.max_primary_slots > 0 then
        if comp.primary_slots_used >= active_config.max_primary_slots then
            return false, "No available primary profession slots"
        end
    end

    return true
end
-- }}}

-- {{{ professions.get_known_recipes
-- Get list of known recipes for a profession.
-- @param entity_id Entity ID
-- @param profession_id Profession identifier
-- @return Array of recipe IDs or nil
function professions.get_known_recipes(entity_id, profession_id)
    local data = get_profession_data(entity_id, profession_id)
    if not data then
        return nil
    end

    -- Return copy to prevent modification
    local recipes = {}
    for recipe_id in pairs(data.recipes_known) do
        recipes[#recipes + 1] = recipe_id
    end
    return recipes
end
-- }}}

-- {{{ professions.knows_recipe
-- Check if entity knows a specific recipe.
-- @param entity_id Entity ID
-- @param profession_id Profession identifier
-- @param recipe_id Recipe identifier
-- @return boolean
function professions.knows_recipe(entity_id, profession_id, recipe_id)
    local data = get_profession_data(entity_id, profession_id)
    return data and data.recipes_known[recipe_id] == true
end
-- }}}

-- {{{ professions.get_specialization
-- Get the specialization for a profession.
-- @param entity_id Entity ID
-- @param profession_id Profession identifier
-- @return Specialization ID or nil
function professions.get_specialization(entity_id, profession_id)
    local data = get_profession_data(entity_id, profession_id)
    return data and data.specialization or nil
end
-- }}}

-- {{{ professions.get_experience
-- Get experience points for a profession (WC3 mode).
-- @param entity_id Entity ID
-- @param profession_id Profession identifier
-- @return Experience or nil
function professions.get_experience(entity_id, profession_id)
    local data = get_profession_data(entity_id, profession_id)
    return data and data.experience or nil
end
-- }}}

-- {{{ professions.get_all_professions
-- Get all professions known by an entity.
-- @param entity_id Entity ID
-- @return Table {primary = {id,...}, secondary = {id,...}}
function professions.get_all_professions(entity_id)
    local comp = ecs.get_component(entity_id, "professions")
    if not comp then
        return nil
    end

    ensure_fresh_tables(comp)

    local result = {primary = {}, secondary = {}}

    for profession_id in pairs(comp.primary) do
        result.primary[#result.primary + 1] = profession_id
    end

    for profession_id in pairs(comp.secondary) do
        result.secondary[#result.secondary + 1] = profession_id
    end

    return result
end
-- }}}

-- ============================================================================
-- Modification Functions
-- ============================================================================

-- {{{ professions.learn_profession
-- Learn a new profession.
-- @param entity_id Entity ID
-- @param profession_id Profession identifier
-- @param profession_type TYPE.PRIMARY or TYPE.SECONDARY (default: PRIMARY)
-- @param initial_skill Starting skill level (optional)
-- @return true on success, false and error on failure
function professions.learn_profession(entity_id, profession_id, profession_type, initial_skill)
    profession_type = profession_type or professions.TYPE.PRIMARY

    local can_learn, err = professions.can_learn_profession(entity_id, profession_id, profession_type)
    if not can_learn then
        return false, err
    end

    local comp = ecs.get_component(entity_id, "professions")
    ensure_fresh_tables(comp)
    local skill_data = create_skill_data(initial_skill)

    if profession_type == professions.TYPE.PRIMARY then
        comp.primary[profession_id] = skill_data
        comp.primary_slots_used = comp.primary_slots_used + 1
    else
        comp.secondary[profession_id] = skill_data
    end

    -- Fire event
    events.fire(professions.EVENT.PROFESSION_LEARNED, {
        entity = entity_id,
        profession = profession_id,
        profession_type = profession_type,
    })

    return true
end
-- }}}

-- {{{ professions.forget_profession
-- Unlearn a profession.
-- @param entity_id Entity ID
-- @param profession_id Profession identifier
-- @return true on success, false if not known
function professions.forget_profession(entity_id, profession_id)
    local comp = ecs.get_component(entity_id, "professions")
    if not comp then
        return false
    end

    ensure_fresh_tables(comp)

    local profession_type = nil

    if comp.primary[profession_id] then
        comp.primary[profession_id] = nil
        comp.primary_slots_used = comp.primary_slots_used - 1
        profession_type = professions.TYPE.PRIMARY
    elseif comp.secondary[profession_id] then
        comp.secondary[profession_id] = nil
        profession_type = professions.TYPE.SECONDARY
    else
        return false  -- Not known
    end

    -- Fire event
    events.fire(professions.EVENT.PROFESSION_FORGOTTEN, {
        entity = entity_id,
        profession = profession_id,
        profession_type = profession_type,
    })

    return true
end
-- }}}

-- {{{ professions.add_skill
-- Add skill points to a profession.
-- @param entity_id Entity ID
-- @param profession_id Profession identifier
-- @param amount Amount to add (can be negative)
-- @return New skill level or nil if profession not known
function professions.add_skill(entity_id, profession_id, amount)
    local data = get_profession_data(entity_id, profession_id)
    if not data then
        return nil
    end

    local old_level = data.skill_level
    data.skill_level = data.skill_level + amount

    -- Clamp to valid range
    if data.skill_level < active_config.skill_min then
        data.skill_level = active_config.skill_min
    end
    if data.skill_level > data.skill_max then
        data.skill_level = data.skill_max
    end

    -- Fire event if level changed
    if data.skill_level > old_level then
        data.last_skillup = os.time()
        events.fire(professions.EVENT.SKILL_UP, {
            entity = entity_id,
            profession = profession_id,
            old_level = old_level,
            new_level = data.skill_level,
        })
    end

    return data.skill_level
end
-- }}}

-- {{{ professions.set_skill_cap
-- Set the skill cap for a profession.
-- @param entity_id Entity ID
-- @param profession_id Profession identifier
-- @param new_cap New skill cap
-- @return true on success, false if profession not known
function professions.set_skill_cap(entity_id, profession_id, new_cap)
    local data = get_profession_data(entity_id, profession_id)
    if not data then
        return false
    end

    local old_cap = data.skill_max
    data.skill_max = new_cap

    -- Fire event if cap raised
    if new_cap > old_cap then
        events.fire(professions.EVENT.SKILL_CAP_RAISED, {
            entity = entity_id,
            profession = profession_id,
            old_cap = old_cap,
            new_cap = new_cap,
        })
    end

    return true
end
-- }}}

-- {{{ professions.learn_recipe
-- Learn a recipe for a profession.
-- @param entity_id Entity ID
-- @param profession_id Profession identifier
-- @param recipe_id Recipe identifier
-- @return true on success, false if profession not known
function professions.learn_recipe(entity_id, profession_id, recipe_id)
    local data = get_profession_data(entity_id, profession_id)
    if not data then
        return false
    end

    if not data.recipes_known[recipe_id] then
        data.recipes_known[recipe_id] = true

        events.fire(professions.EVENT.RECIPE_LEARNED, {
            entity = entity_id,
            profession = profession_id,
            recipe = recipe_id,
        })
    end

    return true
end
-- }}}

-- {{{ professions.set_specialization
-- Set the specialization for a profession.
-- @param entity_id Entity ID
-- @param profession_id Profession identifier
-- @param spec_id Specialization identifier
-- @return true on success, false if profession not known
function professions.set_specialization(entity_id, profession_id, spec_id)
    local data = get_profession_data(entity_id, profession_id)
    if not data then
        return false
    end

    local old_spec = data.specialization
    data.specialization = spec_id

    if spec_id ~= old_spec then
        events.fire(professions.EVENT.SPECIALIZATION_CHOSEN, {
            entity = entity_id,
            profession = profession_id,
            old_spec = old_spec,
            new_spec = spec_id,
        })
    end

    return true
end
-- }}}

-- {{{ professions.add_experience
-- Add experience points (WC3 mode).
-- @param entity_id Entity ID
-- @param profession_id Profession identifier
-- @param amount XP amount
-- @return New XP, levels_gained
function professions.add_experience(entity_id, profession_id, amount)
    local data = get_profession_data(entity_id, profession_id)
    if not data then
        return nil, 0
    end

    if not active_config.use_experience then
        return data.experience, 0
    end

    local xp_per_level = active_config.xp_per_level or 100
    local old_xp = data.experience
    local old_level = data.skill_level

    data.experience = data.experience + amount

    -- Check for level ups
    local levels_gained = 0
    while data.experience >= xp_per_level and data.skill_level < data.skill_max do
        data.experience = data.experience - xp_per_level
        data.skill_level = data.skill_level + 1
        levels_gained = levels_gained + 1

        events.fire(professions.EVENT.SKILL_UP, {
            entity = entity_id,
            profession = profession_id,
            old_level = data.skill_level - 1,
            new_level = data.skill_level,
        })
    end

    return data.experience, levels_gained
end
-- }}}

-- ============================================================================
-- Progression Functions
-- ============================================================================

-- {{{ professions.try_skillup
-- Attempt to gain a skill point based on recipe difficulty.
-- @param entity_id Entity ID
-- @param profession_id Profession identifier
-- @param recipe_skill Recipe's skill requirement
-- @return true if skilled up, false otherwise
function professions.try_skillup(entity_id, profession_id, recipe_skill)
    local chance = professions.get_skillup_chance(entity_id, profession_id, recipe_skill)
    if not chance or chance <= 0 then
        return false
    end

    -- Check skill cap
    local data = get_profession_data(entity_id, profession_id)
    if not data or data.skill_level >= data.skill_max then
        return false  -- Already at cap
    end

    -- Roll for skillup
    if math.random() <= chance then
        professions.add_skill(entity_id, profession_id, 1)
        return true
    end

    return false
end
-- }}}

-- {{{ professions.set_active
-- Set the active profession for an entity.
-- @param entity_id Entity ID
-- @param profession_id Profession identifier (or nil to clear)
-- @return true on success
function professions.set_active(entity_id, profession_id)
    local comp = ecs.get_component(entity_id, "professions")
    if not comp then
        return false
    end

    ensure_fresh_tables(comp)

    if profession_id and not professions.has_profession(entity_id, profession_id) then
        return false
    end

    comp.active_profession = profession_id
    return true
end
-- }}}

-- {{{ professions.get_active
-- Get the active profession for an entity.
-- @param entity_id Entity ID
-- @return Active profession ID or nil
function professions.get_active(entity_id)
    local comp = ecs.get_component(entity_id, "professions")
    if not comp then
        return nil
    end

    ensure_fresh_tables(comp)
    return comp.active_profession
end
-- }}}

-- ============================================================================
-- Initialization
-- ============================================================================

-- {{{ professions.init
-- Initialize the profession system.
function professions.init()
    register_component()
end
-- }}}

-- {{{ professions.reset
-- Reset profession system state (for testing).
function professions.reset()
    active_mode = "wow"
    active_config = CONFIG.wow
end
-- }}}

return professions

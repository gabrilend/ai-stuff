--[[
Recipe and Schematic System (Issue 702d)

Data-driven recipe system defining all craftable items, required materials,
skill requirements, and learning sources. Works with both WoW-style crafting
(profession recipes) and WC3-style (upgrades/shop items).

Core concepts:
- Recipe registry: Global definitions of all recipes
- Known recipes: Per-entity tracking of learned recipes
- Skill difficulty: Orange/yellow/green/gray progression
- Recipe sources: Trainer, drop, quest, discovery, vendor

Usage:
    local recipes = require("runtime.systems.recipes")
    local ecs = require("runtime.ecs")

    -- Register a recipe
    recipes.register({
        id = "iron_sword",
        profession = "blacksmithing",
        skill_required = 100,
        reagents = {{ item = "iron_bar", count = 4 }},
        output = { item = "iron_sword", count = 1 },
    })

    -- Entity learns recipe
    recipes.learn(entity, "iron_sword")

    -- Check if entity can craft
    if recipes.can_craft(entity, "iron_sword") then
        -- Crafting logic in 702c
    end
]]

-- {{{ Configuration
local DIR = arg and arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path
-- }}}

local ecs = require("runtime.ecs")
local events = require("runtime.events")

local recipes = {}

-- ============================================================================
-- Constants
-- ============================================================================

-- {{{ RECIPE_CATEGORY
-- Categories for organizing recipes in UI and queries.
recipes.CATEGORY = {
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
-- }}}

-- {{{ RECIPE_SOURCE
-- How recipes are obtained.
recipes.SOURCE = {
    TRAINER = "trainer",        -- Purchased from trainer NPC
    DROP = "drop",              -- Found as loot
    QUEST = "quest",            -- Quest reward
    DISCOVERY = "discovery",    -- Randomly discovered while crafting
    VENDOR = "vendor",          -- Purchased from vendor (limited stock)
    WORLD = "world",            -- Found in specific location
    DEFAULT = "default",        -- Automatically known
}
-- }}}

-- {{{ DIFFICULTY
-- Skill-up difficulty colors.
recipes.DIFFICULTY = {
    RED = "red",        -- Cannot craft (skill too low)
    ORANGE = "orange",  -- Always skill-up (100%)
    YELLOW = "yellow",  -- Usually skill-up (75%)
    GREEN = "green",    -- Sometimes skill-up (25%)
    GRAY = "gray",      -- Never skill-up (0%)
}
-- }}}

-- ============================================================================
-- Event Constants
-- ============================================================================

-- {{{ Recipe events
recipes.EVENT = {
    RECIPE_LEARNED = 200,
    RECIPE_UNLEARNED = 201,
    RECIPE_DISCOVERED = 202,
    RECIPE_UNLOCKED = 203,  -- Skill reached for trainer recipe
}
-- }}}

-- ============================================================================
-- Recipe Registry
-- ============================================================================

-- {{{ Registry state
local recipe_registry = {}
-- }}}

-- {{{ validate_recipe
-- Validate a recipe definition has required fields.
-- @param definition Recipe table
-- @return true if valid, false and error message if not
local function validate_recipe(definition)
    if not definition.id then
        return false, "Recipe requires 'id' field"
    end
    if not definition.profession then
        return false, "Recipe requires 'profession' field"
    end
    if not definition.output then
        return false, "Recipe requires 'output' field"
    end
    return true
end
-- }}}

-- {{{ apply_defaults
-- Apply default values to recipe definition.
-- @param definition Recipe table (modified in place)
local function apply_defaults(definition)
    definition.name = definition.name or definition.id
    definition.description = definition.description or ""
    definition.category = definition.category or recipes.CATEGORY.TRADE_GOODS
    definition.skill_required = definition.skill_required or 1
    definition.reagents = definition.reagents or {}
    definition.optional_reagents = definition.optional_reagents or {}
    definition.byproducts = definition.byproducts or {}
    definition.cast_time = definition.cast_time or 0
    definition.cooldown = definition.cooldown or 0
    definition.source = definition.source or recipes.SOURCE.TRAINER
    definition.flags = definition.flags or {}

    -- Skill difficulty thresholds (defaults based on skill_required)
    -- Standard WoW-style: orange at req, yellow +15, green +30, gray +45
    if not definition.skill_difficulty then
        local base = definition.skill_required
        definition.skill_difficulty = {
            orange = base,
            yellow = base + 15,
            green = base + 30,
            gray = base + 45,
        }
    end

    -- Output defaults
    if definition.output then
        definition.output.count = definition.output.count or 1
        definition.output.chance = definition.output.chance or 1.0
    end
end
-- }}}

-- {{{ recipes.register
-- Register a recipe definition.
-- @param definition Table with recipe data
-- @return true on success, false and error on failure
function recipes.register(definition)
    local valid, err = validate_recipe(definition)
    if not valid then
        return false, err
    end

    apply_defaults(definition)
    recipe_registry[definition.id] = definition
    return true
end
-- }}}

-- {{{ recipes.register_bulk
-- Register multiple recipes at once.
-- @param recipe_list Array of recipe definitions
-- @return Number of recipes registered, number of failures
function recipes.register_bulk(recipe_list)
    local registered = 0
    local failed = 0

    for _, def in ipairs(recipe_list) do
        local ok = recipes.register(def)
        if ok then
            registered = registered + 1
        else
            failed = failed + 1
        end
    end

    return registered, failed
end
-- }}}

-- {{{ recipes.unregister
-- Remove a recipe from the registry.
-- @param recipe_id Recipe identifier
-- @return true if removed, false if not found
function recipes.unregister(recipe_id)
    if recipe_registry[recipe_id] then
        recipe_registry[recipe_id] = nil
        return true
    end
    return false
end
-- }}}

-- {{{ recipes.get
-- Get a recipe definition by ID.
-- @param recipe_id Recipe identifier
-- @return Recipe definition or nil
function recipes.get(recipe_id)
    return recipe_registry[recipe_id]
end
-- }}}

-- {{{ recipes.get_all
-- Get all registered recipes.
-- @return Table of {recipe_id = definition}
function recipes.get_all()
    local result = {}
    for id, def in pairs(recipe_registry) do
        result[id] = def
    end
    return result
end
-- }}}

-- {{{ recipes.get_all_for_profession
-- Get all recipes for a specific profession.
-- @param profession_id Profession identifier
-- @return Array of recipe definitions
function recipes.get_all_for_profession(profession_id)
    local result = {}
    for _, def in pairs(recipe_registry) do
        if def.profession == profession_id then
            result[#result + 1] = def
        end
    end
    return result
end
-- }}}

-- {{{ recipes.get_learnable_at_skill
-- Get recipes that can be learned at a specific skill level.
-- @param profession_id Profession identifier
-- @param skill_level Current skill level
-- @return Array of recipe definitions
function recipes.get_learnable_at_skill(profession_id, skill_level)
    local result = {}
    for _, def in pairs(recipe_registry) do
        if def.profession == profession_id and def.skill_required <= skill_level then
            result[#result + 1] = def
        end
    end
    return result
end
-- }}}

-- {{{ recipes.get_by_output
-- Get recipes that produce a specific item.
-- @param item_id Output item identifier
-- @return Array of recipe definitions
function recipes.get_by_output(item_id)
    local result = {}
    for _, def in pairs(recipe_registry) do
        if def.output and def.output.item == item_id then
            result[#result + 1] = def
        end
    end
    return result
end
-- }}}

-- {{{ recipes.get_by_category
-- Get recipes in a specific category.
-- @param category Category constant
-- @return Array of recipe definitions
function recipes.get_by_category(category)
    local result = {}
    for _, def in pairs(recipe_registry) do
        if def.category == category then
            result[#result + 1] = def
        end
    end
    return result
end
-- }}}

-- {{{ recipes.search
-- Search recipes with a custom filter function.
-- @param filter_fn Function(recipe) -> boolean
-- @return Array of matching recipe definitions
function recipes.search(filter_fn)
    local result = {}
    for _, def in pairs(recipe_registry) do
        if filter_fn(def) then
            result[#result + 1] = def
        end
    end
    return result
end
-- }}}

-- {{{ recipes.clear_registry
-- Clear all registered recipes (for testing).
function recipes.clear_registry()
    recipe_registry = {}
end
-- }}}

-- ============================================================================
-- Skill Difficulty System
-- ============================================================================

-- {{{ recipes.get_difficulty_color
-- Determine difficulty color for a recipe at given skill level.
-- @param skill_level Current profession skill
-- @param recipe_id Recipe identifier (or recipe definition table)
-- @return Difficulty color constant, or nil if recipe not found
function recipes.get_difficulty_color(skill_level, recipe_id)
    local recipe = type(recipe_id) == "table" and recipe_id or recipe_registry[recipe_id]
    if not recipe then
        return nil
    end

    local diff = recipe.skill_difficulty
    if not diff then
        return recipes.DIFFICULTY.GRAY
    end

    if skill_level < recipe.skill_required then
        return recipes.DIFFICULTY.RED
    elseif skill_level < diff.yellow then
        return recipes.DIFFICULTY.ORANGE
    elseif skill_level < diff.green then
        return recipes.DIFFICULTY.YELLOW
    elseif skill_level < diff.gray then
        return recipes.DIFFICULTY.GREEN
    else
        return recipes.DIFFICULTY.GRAY
    end
end
-- }}}

-- {{{ recipes.get_skillup_chance
-- Get the chance of gaining a skill point from crafting.
-- @param skill_level Current profession skill
-- @param recipe_id Recipe identifier (or recipe definition table)
-- @return Chance as 0.0-1.0, or nil if recipe not found
function recipes.get_skillup_chance(skill_level, recipe_id)
    local color = recipes.get_difficulty_color(skill_level, recipe_id)
    if not color then
        return nil
    end

    local chances = {
        [recipes.DIFFICULTY.RED] = 0,
        [recipes.DIFFICULTY.ORANGE] = 1.0,
        [recipes.DIFFICULTY.YELLOW] = 0.75,
        [recipes.DIFFICULTY.GREEN] = 0.25,
        [recipes.DIFFICULTY.GRAY] = 0,
    }
    return chances[color] or 0
end
-- }}}

-- ============================================================================
-- Component Definition
-- ============================================================================

-- {{{ KNOWN_RECIPES_DEFAULTS
local KNOWN_RECIPES_DEFAULTS = {
    -- Map of profession_id -> { recipe_id = true, ... }
    recipes = {},

    -- Discovery progress: { recipe_id = progress_value }
    discovery_progress = {},

    -- Statistics: { recipe_id = count }
    craft_counts = {},

    -- First craft timestamps: { recipe_id = timestamp }
    first_craft_times = {},
}
-- }}}

-- {{{ Register component
local function register_component()
    if ecs.component_exists and ecs.component_exists("known_recipes") then
        return
    end
    ecs.register_component("known_recipes", KNOWN_RECIPES_DEFAULTS)
end
-- }}}

-- ============================================================================
-- Entity Recipe Operations
-- ============================================================================

-- {{{ ensure_fresh_tables
-- Ensure the component has fresh tables (not inherited from defaults).
local function ensure_fresh_tables(comp)
    if rawget(comp, "_initialized") then
        return
    end

    rawset(comp, "recipes", {})
    rawset(comp, "discovery_progress", {})
    rawset(comp, "craft_counts", {})
    rawset(comp, "first_craft_times", {})
    rawset(comp, "_initialized", true)
end
-- }}}

-- {{{ recipes.learn
-- Teach a recipe to an entity.
-- @param entity_id Entity ID
-- @param recipe_id Recipe identifier
-- @return true on success, false and error on failure
function recipes.learn(entity_id, recipe_id)
    local recipe = recipe_registry[recipe_id]
    if not recipe then
        return false, "Recipe not found: " .. tostring(recipe_id)
    end

    local comp = ecs.get_component(entity_id, "known_recipes")
    if not comp then
        return false, "Entity has no known_recipes component"
    end

    ensure_fresh_tables(comp)

    local profession = recipe.profession
    if not comp.recipes[profession] then
        comp.recipes[profession] = {}
    end

    -- Already known?
    if comp.recipes[profession][recipe_id] then
        return false, "Recipe already known"
    end

    comp.recipes[profession][recipe_id] = true

    -- Fire event
    events.fire(recipes.EVENT.RECIPE_LEARNED, {
        entity = entity_id,
        recipe = recipe_id,
        profession = profession,
    })

    return true
end
-- }}}

-- {{{ recipes.unlearn
-- Remove a recipe from an entity.
-- @param entity_id Entity ID
-- @param recipe_id Recipe identifier
-- @return true on success, false if not known
function recipes.unlearn(entity_id, recipe_id)
    local recipe = recipe_registry[recipe_id]
    if not recipe then
        return false
    end

    local comp = ecs.get_component(entity_id, "known_recipes")
    if not comp then
        return false
    end

    ensure_fresh_tables(comp)

    local profession = recipe.profession
    if not comp.recipes[profession] or not comp.recipes[profession][recipe_id] then
        return false
    end

    comp.recipes[profession][recipe_id] = nil

    -- Fire event
    events.fire(recipes.EVENT.RECIPE_UNLEARNED, {
        entity = entity_id,
        recipe = recipe_id,
        profession = profession,
    })

    return true
end
-- }}}

-- {{{ recipes.knows
-- Check if an entity knows a recipe.
-- @param entity_id Entity ID
-- @param recipe_id Recipe identifier
-- @return boolean
function recipes.knows(entity_id, recipe_id)
    local recipe = recipe_registry[recipe_id]
    if not recipe then
        return false
    end

    local comp = ecs.get_component(entity_id, "known_recipes")
    if not comp then
        return false
    end

    ensure_fresh_tables(comp)

    local profession = recipe.profession
    return comp.recipes[profession] and comp.recipes[profession][recipe_id] == true
end
-- }}}

-- {{{ recipes.get_known
-- Get all recipes known by an entity for a profession.
-- @param entity_id Entity ID
-- @param profession_id Profession identifier
-- @return Array of recipe IDs
function recipes.get_known(entity_id, profession_id)
    local comp = ecs.get_component(entity_id, "known_recipes")
    if not comp then
        return {}
    end

    ensure_fresh_tables(comp)

    local result = {}
    local prof_recipes = comp.recipes[profession_id]
    if prof_recipes then
        for recipe_id in pairs(prof_recipes) do
            result[#result + 1] = recipe_id
        end
    end
    return result
end
-- }}}

-- {{{ recipes.get_all_known
-- Get all recipes known by an entity across all professions.
-- @param entity_id Entity ID
-- @return Table of { profession_id = { recipe_id, ... }, ... }
function recipes.get_all_known(entity_id)
    local comp = ecs.get_component(entity_id, "known_recipes")
    if not comp then
        return {}
    end

    ensure_fresh_tables(comp)

    local result = {}
    for profession_id, prof_recipes in pairs(comp.recipes) do
        result[profession_id] = {}
        for recipe_id in pairs(prof_recipes) do
            result[profession_id][#result[profession_id] + 1] = recipe_id
        end
    end
    return result
end
-- }}}

-- ============================================================================
-- Crafting Preparation
-- ============================================================================

-- {{{ recipes.can_craft
-- Check if entity can craft a recipe (knows it, has skill, etc.).
-- Does NOT check materials - that's for the inventory/crafting system.
-- @param entity_id Entity ID
-- @param recipe_id Recipe identifier
-- @return boolean, error_message if false
function recipes.can_craft(entity_id, recipe_id)
    local recipe = recipe_registry[recipe_id]
    if not recipe then
        return false, "Recipe not found"
    end

    -- Must know the recipe
    if not recipes.knows(entity_id, recipe_id) then
        return false, "Recipe not known"
    end

    -- Check profession skill level
    local professions = require("runtime.systems.professions")
    local skill = professions.get_skill(entity_id, recipe.profession)
    if not skill then
        return false, "Profession not learned"
    end

    if skill < recipe.skill_required then
        return false, "Skill too low"
    end

    return true
end
-- }}}

-- {{{ recipes.get_missing_reagents
-- Get list of reagents the entity doesn't have enough of.
-- Note: This requires an inventory system - returns all reagents for now.
-- @param entity_id Entity ID
-- @param recipe_id Recipe identifier
-- @return Array of { item = id, needed = count, have = count }
function recipes.get_missing_reagents(entity_id, recipe_id)
    local recipe = recipe_registry[recipe_id]
    if not recipe then
        return {}
    end

    -- Without an inventory system, we can't check actual counts
    -- Return all reagents as "needed" with have=0
    local result = {}
    for _, reagent in ipairs(recipe.reagents) do
        result[#result + 1] = {
            item = reagent.item,
            needed = reagent.count,
            have = 0,  -- TODO: Query inventory
        }
    end
    return result
end
-- }}}

-- ============================================================================
-- Statistics
-- ============================================================================

-- {{{ recipes.record_craft
-- Record that entity crafted a recipe.
-- @param entity_id Entity ID
-- @param recipe_id Recipe identifier
function recipes.record_craft(entity_id, recipe_id)
    local comp = ecs.get_component(entity_id, "known_recipes")
    if not comp then
        return
    end

    ensure_fresh_tables(comp)

    -- Increment craft count
    comp.craft_counts[recipe_id] = (comp.craft_counts[recipe_id] or 0) + 1

    -- Record first craft time
    if not comp.first_craft_times[recipe_id] then
        comp.first_craft_times[recipe_id] = os.time()
    end
end
-- }}}

-- {{{ recipes.get_craft_count
-- Get how many times an entity has crafted a recipe.
-- @param entity_id Entity ID
-- @param recipe_id Recipe identifier
-- @return Count (0 if never crafted)
function recipes.get_craft_count(entity_id, recipe_id)
    local comp = ecs.get_component(entity_id, "known_recipes")
    if not comp then
        return 0
    end

    ensure_fresh_tables(comp)
    return comp.craft_counts[recipe_id] or 0
end
-- }}}

-- ============================================================================
-- Discovery System
-- ============================================================================

-- {{{ recipes.try_discovery
-- Attempt to discover a recipe while crafting another.
-- @param entity_id Entity ID
-- @param base_recipe_id Recipe being crafted
-- @return Discovered recipe ID or nil
function recipes.try_discovery(entity_id, base_recipe_id)
    -- Find recipes that can be discovered from this base
    local discoverable = recipes.search(function(r)
        return r.source == recipes.SOURCE.DISCOVERY
            and r.discovery_base == base_recipe_id
    end)

    if #discoverable == 0 then
        return nil
    end

    for _, recipe in ipairs(discoverable) do
        -- Already known?
        if recipes.knows(entity_id, recipe.id) then
            goto continue
        end

        -- Roll for discovery
        local chance = recipe.discovery_chance or 0.05
        if math.random() <= chance then
            -- Discovered!
            recipes.learn(entity_id, recipe.id)

            events.fire(recipes.EVENT.RECIPE_DISCOVERED, {
                entity = entity_id,
                recipe = recipe.id,
                base_recipe = base_recipe_id,
            })

            return recipe.id
        end

        ::continue::
    end

    return nil
end
-- }}}

-- ============================================================================
-- Initialization
-- ============================================================================

-- {{{ recipes.init
-- Initialize the recipe system.
function recipes.init()
    register_component()
end
-- }}}

-- {{{ recipes.reset
-- Reset recipe system state (for testing).
function recipes.reset()
    recipes.clear_registry()
end
-- }}}

return recipes

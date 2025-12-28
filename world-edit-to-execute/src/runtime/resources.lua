--[[
Resource Management System

Tracks player resources (gold, lumber, food) with per-player storage.
Provides getter/setter API with clamping to valid ranges.
Fires events when resources change.
Supports custom resource types for map-specific mechanics.

Standard WC3 resources:
- gold: Primary currency from gold mines (max 999999)
- lumber: Secondary currency from trees (max 999999)
- food_used: Population currently in use (max 300)
- food_cap: Maximum population capacity (max 300)
]]

local resources = {}

-- {{{ Resource type definitions
-- Standard WC3 resources with their constraints
-- Max of 300 for food to support custom maps (standard WC3 is 100)

-- Default resource types (used for reset)
local DEFAULT_RESOURCE_TYPES = {
    gold = {
        max = 999999,
        default = 0,
        description = "Primary currency from gold mines",
    },
    lumber = {
        max = 999999,
        default = 0,
        description = "Secondary currency from trees",
    },
    food_used = {
        max = 300,
        default = 0,
        description = "Population currently in use",
    },
    food_cap = {
        max = 300,
        default = 0,
        description = "Maximum population capacity",
    },
}

-- {{{ local function copy_resource_types
-- Deep copy resource type table.
local function copy_resource_types(source)
    local copy = {}
    for name, config in pairs(source) do
        copy[name] = {
            max = config.max,
            default = config.default,
            description = config.description,
        }
    end
    return copy
end
-- }}}

-- Active resource types (can be modified by register_type)
local RESOURCE_TYPES = copy_resource_types(DEFAULT_RESOURCE_TYPES)
-- }}}

-- {{{ Internal state
-- Per-player resource storage
-- Structure: player_resources[player_id][resource_name] = amount
local player_resources = {}

-- Event listeners for resource events
local event_listeners = {
    resource_changed = {},
    player_resources_initialized = {},
    resources_spent = {},
    resources_refunded = {},
    food_supply_changed = {},
    food_used_changed = {},
    upkeep_changed = {},
    harvest_deposited = {},
    gold_mine_depleted = {},
    gold_mine_low = {},
}
-- }}}

-- {{{ local function fire_event
-- Fire event to all registered listeners.
-- @param event_name Event name
-- @param ... Arguments to pass to listeners
local function fire_event(event_name, ...)
    local listeners = event_listeners[event_name]
    if listeners then
        for _, fn in ipairs(listeners) do
            fn(...)
        end
    end
end
-- }}}

-- ============================================================================
-- Resource Type Management
-- ============================================================================

-- {{{ function resources.register_type
-- Register a new resource type (for custom map resources).
-- Can also update an existing type's configuration.
-- @param name String identifier for the resource
-- @param config Table with max, default, and optional description
function resources.register_type(name, config)
    if RESOURCE_TYPES[name] then
        -- Allow updating existing type configs
        for k, v in pairs(config) do
            RESOURCE_TYPES[name][k] = v
        end
    else
        RESOURCE_TYPES[name] = {
            max = config.max or 999999,
            default = config.default or 0,
            description = config.description or "",
        }
    end
end
-- }}}

-- {{{ function resources.get_type_config
-- Get configuration for a resource type.
-- @param name Resource type name
-- @return Config table or nil if not found
function resources.get_type_config(name)
    return RESOURCE_TYPES[name]
end
-- }}}

-- {{{ function resources.get_all_types
-- Get list of all registered resource type names.
-- @return Array of resource type names
function resources.get_all_types()
    local types = {}
    for name in pairs(RESOURCE_TYPES) do
        types[#types + 1] = name
    end
    table.sort(types)  -- Consistent ordering
    return types
end
-- }}}

-- ============================================================================
-- Player Resource Storage
-- ============================================================================

-- {{{ function resources.init_player
-- Initialize resources for a new player.
-- Sets all resources to their default values.
-- @param player_id Player slot number (0-15)
function resources.init_player(player_id)
    player_resources[player_id] = {}

    for name, config in pairs(RESOURCE_TYPES) do
        player_resources[player_id][name] = config.default
    end

    fire_event("player_resources_initialized", player_id)
end
-- }}}

-- {{{ function resources.reset_player
-- Reset player resources to defaults.
-- Initializes player if not yet initialized.
-- @param player_id Player slot number
function resources.reset_player(player_id)
    if not player_resources[player_id] then
        resources.init_player(player_id)
        return
    end

    for name, config in pairs(RESOURCE_TYPES) do
        resources.set(player_id, name, config.default)
    end
end
-- }}}

-- {{{ function resources.remove_player
-- Clean up player resources.
-- @param player_id Player slot number
function resources.remove_player(player_id)
    player_resources[player_id] = nil
end
-- }}}

-- {{{ function resources.has_player
-- Check if player has been initialized.
-- @param player_id Player slot number
-- @return true if player has resources initialized
function resources.has_player(player_id)
    return player_resources[player_id] ~= nil
end
-- }}}

-- ============================================================================
-- Resource Getters
-- ============================================================================

-- {{{ function resources.get
-- Get current amount of a resource for a player.
-- Returns 0 if player or resource doesn't exist.
-- @param player_id Player slot number
-- @param resource_name Resource type name
-- @return Current resource amount
function resources.get(player_id, resource_name)
    local player = player_resources[player_id]
    if not player then
        return 0
    end
    return player[resource_name] or 0
end
-- }}}

-- {{{ function resources.get_all
-- Get all resources for a player as a table.
-- @param player_id Player slot number
-- @return Table of resource_name -> amount
function resources.get_all(player_id)
    local player = player_resources[player_id]
    if not player then
        return {}
    end

    local result = {}
    for name, amount in pairs(player) do
        result[name] = amount
    end
    return result
end
-- }}}

-- ============================================================================
-- Resource Setters
-- ============================================================================

-- {{{ function resources.set
-- Set a resource to a specific value.
-- Clamps to valid range [0, max].
-- Fires resource_changed event if value actually changed.
-- Auto-initializes player if not yet initialized.
-- @param player_id Player slot number
-- @param resource_name Resource type name
-- @param amount New value to set
-- @return The actual new value (after clamping)
function resources.set(player_id, resource_name, amount)
    -- Ensure player exists
    if not player_resources[player_id] then
        resources.init_player(player_id)
    end

    local config = RESOURCE_TYPES[resource_name]
    if not config then
        -- Unknown resource type - use defaults
        -- This allows setting custom resources before registering them
        config = { max = 999999, default = 0 }
    end

    local old_value = player_resources[player_id][resource_name] or 0

    -- Clamp to valid range [0, max]
    local new_value = math.max(0, math.min(amount, config.max))

    player_resources[player_id][resource_name] = new_value

    -- Fire event if changed
    if old_value ~= new_value then
        fire_event("resource_changed", player_id, resource_name, old_value, new_value)
    end

    return new_value
end
-- }}}

-- {{{ function resources.add
-- Add amount to a resource (can be negative).
-- @param player_id Player slot number
-- @param resource_name Resource type name
-- @param amount Amount to add (can be negative)
-- @return The new value
function resources.add(player_id, resource_name, amount)
    local current = resources.get(player_id, resource_name)
    return resources.set(player_id, resource_name, current + amount)
end
-- }}}

-- {{{ function resources.subtract
-- Subtract amount from a resource.
-- @param player_id Player slot number
-- @param resource_name Resource type name
-- @param amount Amount to subtract
-- @return The new value
function resources.subtract(player_id, resource_name, amount)
    return resources.add(player_id, resource_name, -amount)
end
-- }}}

-- ============================================================================
-- Spending and Validation (406b)
-- ============================================================================

-- {{{ function resources.can_afford
-- Check if player can afford a cost table.
-- Cost tables map resource names to amounts: { gold = 100, lumber = 50, food = 2 }
-- Food is special: checks if food_used + cost <= food_cap.
-- @param player_id Player slot number
-- @param cost Cost table
-- @return true if affordable, or false and missing resource name
function resources.can_afford(player_id, cost)
    if not cost then
        return true
    end

    for resource_name, amount in pairs(cost) do
        if resource_name == "food" then
            -- Food is special: check if food_used + amount <= food_cap
            local used = resources.get(player_id, "food_used")
            local cap = resources.get(player_id, "food_cap")

            if used + amount > cap then
                return false, "food"
            end
        else
            -- Standard resource: check if current >= amount
            local current = resources.get(player_id, resource_name)

            if current < amount then
                return false, resource_name
            end
        end
    end

    return true
end
-- }}}

-- {{{ function resources.spend
-- Spend resources according to a cost table.
-- This is ATOMIC: either all resources are spent, or none are.
-- Food spending increases food_used (not subtracts).
-- @param player_id Player slot number
-- @param cost Cost table { gold = N, lumber = N, food = N, ... }
-- @return true on success, or false and missing resource name
function resources.spend(player_id, cost)
    if not cost then
        return true
    end

    -- First, validate we can afford everything
    local can, missing = resources.can_afford(player_id, cost)
    if not can then
        return false, missing
    end

    -- Now spend each resource
    for resource_name, amount in pairs(cost) do
        if resource_name == "food" then
            -- Food spending increases food_used
            resources.add(player_id, "food_used", amount)
        else
            -- Standard resources are subtracted
            resources.subtract(player_id, resource_name, amount)
        end
    end

    -- Fire spending event
    fire_event("resources_spent", player_id, cost)

    return true
end
-- }}}

-- {{{ function resources.refund
-- Refund resources from a cancelled order.
-- Inverse of spend: adds back gold/lumber, decreases food_used.
-- @param player_id Player slot number
-- @param cost Cost table to refund
function resources.refund(player_id, cost)
    if not cost then
        return
    end

    for resource_name, amount in pairs(cost) do
        if resource_name == "food" then
            -- Food refund decreases food_used
            resources.subtract(player_id, "food_used", amount)
        else
            -- Standard resources are added back
            resources.add(player_id, resource_name, amount)
        end
    end

    -- Fire refund event
    fire_event("resources_refunded", player_id, cost)
end
-- }}}

-- {{{ function resources.validate_cost
-- Check if a cost table is well-formed.
-- @param cost Cost table to validate
-- @return true if valid, or false and error message
function resources.validate_cost(cost)
    if type(cost) ~= "table" then
        return false, "Cost must be a table"
    end

    for resource_name, amount in pairs(cost) do
        if type(resource_name) ~= "string" then
            return false, "Resource name must be a string"
        end
        if type(amount) ~= "number" or amount < 0 then
            return false, "Resource amount must be a non-negative number"
        end
    end

    return true
end
-- }}}

-- {{{ function resources.add_costs
-- Combine two cost tables.
-- @param cost1 First cost table
-- @param cost2 Second cost table
-- @return New cost table with summed amounts
function resources.add_costs(cost1, cost2)
    local result = {}

    for name, amount in pairs(cost1 or {}) do
        result[name] = (result[name] or 0) + amount
    end

    for name, amount in pairs(cost2 or {}) do
        result[name] = (result[name] or 0) + amount
    end

    return result
end
-- }}}

-- {{{ function resources.multiply_cost
-- Scale a cost table by a multiplier.
-- @param cost Cost table
-- @param multiplier Numeric multiplier
-- @return New cost table with scaled amounts (floored to integers)
function resources.multiply_cost(cost, multiplier)
    local result = {}

    for name, amount in pairs(cost or {}) do
        result[name] = math.floor(amount * multiplier)
    end

    return result
end
-- }}}

-- ============================================================================
-- Food Supply and Consumption (406c)
-- ============================================================================

-- {{{ function resources.add_food_supply
-- Called when food-providing buildings complete construction.
-- Examples: Farm (+6), Town Hall (+10), Ziggurat (+10 with upgrade).
-- @param player_id Player slot number
-- @param amount Food supply to add
function resources.add_food_supply(player_id, amount)
    local old_cap = resources.get(player_id, "food_cap")
    resources.add(player_id, "food_cap", amount)
    local new_cap = resources.get(player_id, "food_cap")

    fire_event("food_supply_changed", player_id, old_cap, new_cap)
end
-- }}}

-- {{{ function resources.remove_food_supply
-- Called when food-providing buildings are destroyed.
-- Note: food_used can exceed food_cap after this.
-- @param player_id Player slot number
-- @param amount Food supply to remove
function resources.remove_food_supply(player_id, amount)
    local old_cap = resources.get(player_id, "food_cap")
    resources.subtract(player_id, "food_cap", amount)
    local new_cap = resources.get(player_id, "food_cap")

    fire_event("food_supply_changed", player_id, old_cap, new_cap)
end
-- }}}

-- {{{ function resources.add_food_used
-- Called when units complete training or are summoned.
-- @param player_id Player slot number
-- @param amount Food consumption to add
function resources.add_food_used(player_id, amount)
    local old_used = resources.get(player_id, "food_used")
    resources.add(player_id, "food_used", amount)
    local new_used = resources.get(player_id, "food_used")

    fire_event("food_used_changed", player_id, old_used, new_used)

    -- Check for upkeep level changes
    resources._check_upkeep_change(player_id, old_used, new_used)
end
-- }}}

-- {{{ function resources.remove_food_used
-- Called when units die or are removed.
-- @param player_id Player slot number
-- @param amount Food consumption to remove
function resources.remove_food_used(player_id, amount)
    local old_used = resources.get(player_id, "food_used")
    resources.subtract(player_id, "food_used", amount)
    local new_used = resources.get(player_id, "food_used")

    fire_event("food_used_changed", player_id, old_used, new_used)

    -- Check for upkeep level changes
    resources._check_upkeep_change(player_id, old_used, new_used)
end
-- }}}

-- {{{ function resources.get_food_status
-- Get comprehensive food information for a player.
-- @param player_id Player slot number
-- @return Table with used, cap, available, is_capped, upkeep_level
function resources.get_food_status(player_id)
    local used = resources.get(player_id, "food_used")
    local cap = resources.get(player_id, "food_cap")

    return {
        used = used,
        cap = cap,
        available = cap - used,
        is_capped = used >= cap,
        upkeep_level = resources.get_upkeep_level(used),
    }
end
-- }}}

-- ============================================================================
-- Upkeep System (406c)
-- ============================================================================

-- {{{ Upkeep thresholds and rates
-- WC3 melee upkeep affects gold income rate
local UPKEEP_THRESHOLDS = {
    none = 50,    -- 0-50 food: 100% gold income
    low = 80,     -- 51-80 food: 70% gold income
    -- Above 80: 40% gold income (high upkeep)
}

local UPKEEP_RATES = {
    none = 1.0,
    low = 0.7,
    high = 0.4,
}
-- }}}

-- {{{ function resources.get_upkeep_level
-- Get upkeep level based on food used.
-- @param food_used Current food consumption
-- @return "none", "low", or "high"
function resources.get_upkeep_level(food_used)
    if food_used <= UPKEEP_THRESHOLDS.none then
        return "none"
    elseif food_used <= UPKEEP_THRESHOLDS.low then
        return "low"
    else
        return "high"
    end
end
-- }}}

-- {{{ function resources.get_upkeep_rate
-- Get upkeep rate for a player (multiplier for gold income).
-- @param player_id Player slot number
-- @return Rate (1.0, 0.7, or 0.4)
function resources.get_upkeep_rate(player_id)
    local used = resources.get(player_id, "food_used")
    local level = resources.get_upkeep_level(used)
    return UPKEEP_RATES[level]
end
-- }}}

-- {{{ function resources._check_upkeep_change
-- Internal: Check if upkeep level changed and fire event.
-- @param player_id Player slot number
-- @param old_used Previous food_used
-- @param new_used New food_used
function resources._check_upkeep_change(player_id, old_used, new_used)
    local old_level = resources.get_upkeep_level(old_used)
    local new_level = resources.get_upkeep_level(new_used)

    if old_level ~= new_level then
        fire_event("upkeep_changed", player_id, old_level, new_level)
    end
end
-- }}}

-- ============================================================================
-- Harvesting Integration (406c)
-- ============================================================================

-- {{{ function resources.deposit_harvest
-- Called when a worker deposits harvested resources.
-- Applies upkeep modifier to gold.
-- @param player_id Player slot number
-- @param resource_name Resource type (gold, lumber)
-- @param amount Base amount harvested
-- @param apply_upkeep Apply upkeep penalty to gold (default true)
-- @return Actual amount deposited
function resources.deposit_harvest(player_id, resource_name, amount, apply_upkeep)
    if apply_upkeep == nil then
        apply_upkeep = true
    end

    local final_amount = amount

    -- Apply upkeep penalty to gold
    if resource_name == "gold" and apply_upkeep then
        local rate = resources.get_upkeep_rate(player_id)
        final_amount = math.floor(amount * rate)
    end

    resources.add(player_id, resource_name, final_amount)

    fire_event("harvest_deposited", {
        player_id = player_id,
        resource = resource_name,
        amount = final_amount,
        original_amount = amount,
        upkeep_applied = apply_upkeep and resource_name == "gold",
    })

    return final_amount
end
-- }}}

-- {{{ function resources.deplete_gold_mine
-- Reduce gold remaining in a mine.
-- @param ecs ECS module reference
-- @param mine_entity Entity with gold_mine component
-- @param amount Gold extracted this harvest
-- @return Remaining gold, or nil and error message
function resources.deplete_gold_mine(ecs, mine_entity, amount)
    local mine = ecs.get_component(mine_entity, "gold_mine")
    if not mine then
        return nil, "Entity has no gold_mine component"
    end

    local old_remaining = mine.gold_remaining
    mine.gold_remaining = math.max(0, mine.gold_remaining - amount)

    if mine.gold_remaining <= 0 and old_remaining > 0 then
        fire_event("gold_mine_depleted", mine_entity)
    elseif mine.low_warning_threshold and mine.gold_remaining <= mine.low_warning_threshold then
        fire_event("gold_mine_low", mine_entity, mine.gold_remaining)
    end

    return mine.gold_remaining
end
-- }}}

-- {{{ function resources.get_mine_status
-- Get status of a gold mine.
-- @param ecs ECS module reference
-- @param mine_entity Entity with gold_mine component
-- @return Status table or nil
function resources.get_mine_status(ecs, mine_entity)
    local mine = ecs.get_component(mine_entity, "gold_mine")
    if not mine then
        return nil
    end

    local capacity = mine.gold_capacity or mine.gold_remaining
    return {
        remaining = mine.gold_remaining,
        capacity = capacity,
        percent = capacity > 0 and (mine.gold_remaining / capacity * 100) or 0,
        is_depleted = mine.gold_remaining <= 0,
    }
end
-- }}}

-- ============================================================================
-- Income System (406c) - For custom maps
-- ============================================================================

-- {{{ Income state
local player_income = {}  -- player_id -> { resource_name -> per_second }
local income_accumulator = {}  -- player_id_resource -> fractional accumulation
-- }}}

-- {{{ function resources.set_income_rate
-- Set periodic income rate for a player.
-- @param player_id Player slot number
-- @param resource_name Resource to grant
-- @param per_second Amount per second
function resources.set_income_rate(player_id, resource_name, per_second)
    if not player_income[player_id] then
        player_income[player_id] = {}
    end
    player_income[player_id][resource_name] = per_second
end
-- }}}

-- {{{ function resources.get_income_rate
-- Get periodic income rate for a player.
-- @param player_id Player slot number
-- @param resource_name Resource type
-- @return Per-second income rate
function resources.get_income_rate(player_id, resource_name)
    if not player_income[player_id] then
        return 0
    end
    return player_income[player_id][resource_name] or 0
end
-- }}}

-- {{{ function resources.process_income
-- Process periodic income for all players.
-- Called each game tick with delta time.
-- @param dt Delta time in seconds
function resources.process_income(dt)
    for player_id, incomes in pairs(player_income) do
        for resource_name, per_second in pairs(incomes) do
            if per_second > 0 then
                local amount = per_second * dt
                local key = player_id .. "_" .. resource_name
                local acc = (income_accumulator[key] or 0) + amount
                local whole = math.floor(acc)

                if whole > 0 then
                    resources.add(player_id, resource_name, whole)
                    income_accumulator[key] = acc - whole
                else
                    income_accumulator[key] = acc
                end
            end
        end
    end
end
-- }}}

-- {{{ function resources.clear_income
-- Clear all income rates (for reset).
function resources.clear_income()
    player_income = {}
    income_accumulator = {}
end
-- }}}

-- ============================================================================
-- Event System
-- ============================================================================

-- {{{ function resources.on
-- Register a listener for resource events.
-- Events: resource_changed, player_resources_initialized
-- @param event_name Event name
-- @param callback Function to call when event fires
function resources.on(event_name, callback)
    if not event_listeners[event_name] then
        event_listeners[event_name] = {}
    end
    table.insert(event_listeners[event_name], callback)
end
-- }}}

-- {{{ function resources.clear_events
-- Clear all event listeners (for testing).
function resources.clear_events()
    for event_name in pairs(event_listeners) do
        event_listeners[event_name] = {}
    end
end
-- }}}

-- ============================================================================
-- Reset / Testing
-- ============================================================================

-- {{{ function resources.reset
-- Clear all player resources, event listeners, and custom resource types (for testing).
function resources.reset()
    player_resources = {}
    resources.clear_events()
    resources.clear_income()
    -- Restore default resource types (removes custom types, resets modified configs)
    RESOURCE_TYPES = copy_resource_types(DEFAULT_RESOURCE_TYPES)
end
-- }}}

-- {{{ Exports
-- Export resource type names as constants
resources.TYPES = {
    GOLD = "gold",
    LUMBER = "lumber",
    FOOD_USED = "food_used",
    FOOD_CAP = "food_cap",
}
-- }}}

return resources

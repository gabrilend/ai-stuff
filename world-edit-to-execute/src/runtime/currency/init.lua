--[[
Currency System - Unified API for all currency types

Provides a single interface for accessing currencies regardless of their
storage mechanism (bag slots, ECS components, player resources).

Uses dispatch tables for O(1) getter/setter lookup (Issue 016 pattern).

Usage:
  local currency = require("runtime.currency")

  -- Get/set any currency
  local gold = currency.get(entity, "gold")
  currency.set(entity, "honor", 5000)

  -- Spending (atomic)
  if currency.can_afford(entity, { gold = 5, silver = 50 }) then
      currency.spend(entity, { gold = 5, silver = 50 })
  end

  -- WC3 resources (player-level)
  local lumber = currency.get(player_id, "wc3_lumber")
]]

local registry = require("runtime.currency.registry")

local currency = {}

-- Forward declarations
local GETTERS = {}
local SETTERS = {}
local ADDERS = {}

-- {{{ Module state
local _initialized = false
local _resources_module = nil  -- Lazy-loaded reference to resources.lua
-- }}}

-- {{{ local function get_resources
-- Lazy-load resources module to avoid circular dependency.
local function get_resources()
    if not _resources_module then
        _resources_module = require("runtime.resources")
    end
    return _resources_module
end
-- }}}

-- {{{ local function get_ecs
-- Lazy-load ECS module.
local function get_ecs()
    return require("runtime.ecs")
end
-- }}}

-- {{{ local function clamp
local function clamp(value, min_val, max_val)
    if value < min_val then return min_val end
    if max_val and value > max_val then return max_val end
    return value
end
-- }}}

-- {{{ Build dispatch tables
-- Called on module load to populate GETTERS and SETTERS.
local function build_dispatch_tables()
    local CAT = registry.CURRENCY_CATEGORY

    for name, schema in pairs(registry.CURRENCY_SCHEMA) do
        local cat = schema.category
        local idx = schema.index

        -- =====================================================================
        -- Physical currencies (coins in money_bag)
        -- =====================================================================
        if cat == CAT.PHYSICAL then
            GETTERS[name] = function(entity)
                local ecs = get_ecs()
                local bag = ecs.get_component(entity, "money_bag")
                if not bag then return 0 end
                return bag.slots[name] and bag.slots[name].quantity or 0
            end

            SETTERS[name] = function(entity, amount)
                local ecs = get_ecs()
                local bag = ecs.get_component(entity, "money_bag")
                if not bag then return false end
                bag.slots[name] = bag.slots[name] or { quantity = 0 }
                bag.slots[name].quantity = math.max(0, amount)
                bag.dirty = true
                return true
            end

        -- =====================================================================
        -- Abstract currencies (currency_container component)
        -- =====================================================================
        elseif cat == CAT.ABSTRACT then
            GETTERS[name] = function(entity)
                local ecs = get_ecs()
                local container = ecs.get_component(entity, "currency_container")
                if not container then return 0 end
                return container.values[idx] or 0
            end

            SETTERS[name] = function(entity, amount)
                local ecs = get_ecs()
                local container = ecs.get_component(entity, "currency_container")
                if not container then return false end
                container.values = container.values or {}
                local cap = schema.cap
                container.values[idx] = clamp(amount, 0, cap)
                return true
            end

        -- =====================================================================
        -- Token currencies (inventory items - count from inventory)
        -- =====================================================================
        elseif cat == CAT.TOKEN then
            GETTERS[name] = function(entity)
                -- Token counting requires inventory scan
                -- For now, return from currency_container tracking
                local ecs = get_ecs()
                local container = ecs.get_component(entity, "currency_container")
                if not container then return 0 end
                return container.tokens and container.tokens[name] or 0
            end

            SETTERS[name] = function(entity, amount)
                local ecs = get_ecs()
                local container = ecs.get_component(entity, "currency_container")
                if not container then return false end
                container.tokens = container.tokens or {}
                container.tokens[name] = math.max(0, amount)
                return true
            end

        -- =====================================================================
        -- WC3 resources (player-level via resources.lua)
        -- =====================================================================
        elseif cat == CAT.WC3_RESOURCE then
            -- Map wc3_gold -> gold, wc3_lumber -> lumber, etc.
            local res_name = name:gsub("^wc3_", "")

            GETTERS[name] = function(player_id)
                local resources = get_resources()
                return resources.get(player_id, res_name)
            end

            SETTERS[name] = function(player_id, amount)
                local resources = get_resources()
                resources.set(player_id, res_name, amount)
                return true
            end
        end

        -- Also index by numeric key
        GETTERS[idx] = GETTERS[name]
        SETTERS[idx] = SETTERS[name]
    end
end
-- }}}

-- {{{ currency.init
-- Initialize the currency system.
-- Registers ECS components if not already registered.
function currency.init()
    if _initialized then return end

    local ecs = get_ecs()

    -- Register money_bag component if needed
    -- Component registration happens in money_bag.lua
    -- Just verify ECS is available
    if not ecs then
        error("Currency system requires ECS module")
    end

    _initialized = true
end
-- }}}

-- {{{ currency.get
-- Get current value of a currency.
-- @param entity_or_player Entity ID (for character currencies) or player ID (for WC3)
-- @param currency_id Currency name (string) or index (number)
-- @return Current value, or 0 if not found
function currency.get(entity_or_player, currency_id)
    local getter = GETTERS[currency_id]
    if not getter then
        return 0
    end
    return getter(entity_or_player)
end
-- }}}

-- {{{ currency.set
-- Set currency to a specific value.
-- @param entity_or_player Entity or player ID
-- @param currency_id Currency name or index
-- @param amount New value
-- @return true on success, false if currency/entity not found
function currency.set(entity_or_player, currency_id, amount)
    local setter = SETTERS[currency_id]
    if not setter then
        return false
    end
    return setter(entity_or_player, amount)
end
-- }}}

-- {{{ currency.add
-- Add to a currency (can be negative).
-- @param entity_or_player Entity or player ID
-- @param currency_id Currency name or index
-- @param amount Amount to add
-- @return New value
function currency.add(entity_or_player, currency_id, amount)
    local current = currency.get(entity_or_player, currency_id)
    local new_value = current + amount
    currency.set(entity_or_player, currency_id, new_value)
    return currency.get(entity_or_player, currency_id)  -- Return clamped value
end
-- }}}

-- {{{ currency.subtract
-- Subtract from a currency.
-- @param entity_or_player Entity or player ID
-- @param currency_id Currency name or index
-- @param amount Amount to subtract
-- @return true if successful, false if insufficient
function currency.subtract(entity_or_player, currency_id, amount)
    local current = currency.get(entity_or_player, currency_id)
    if current < amount then
        return false, "Insufficient " .. tostring(currency_id)
    end
    currency.set(entity_or_player, currency_id, current - amount)
    return true
end
-- }}}

-- {{{ currency.can_afford
-- Check if entity/player can afford a cost table.
-- @param entity_or_player Entity or player ID
-- @param cost_table Table of currency_id -> amount
-- @return true if affordable, false and missing currency name otherwise
function currency.can_afford(entity_or_player, cost_table)
    if not cost_table then return true end

    for currency_id, amount in pairs(cost_table) do
        local current = currency.get(entity_or_player, currency_id)
        if current < amount then
            return false, currency_id
        end
    end
    return true
end
-- }}}

-- {{{ currency.spend
-- Spend currencies according to a cost table.
-- Atomic: either all currencies are spent, or none are.
-- @param entity_or_player Entity or player ID
-- @param cost_table Table of currency_id -> amount
-- @return true on success, false and missing currency on failure
function currency.spend(entity_or_player, cost_table)
    if not cost_table then return true end

    -- First validate
    local can, missing = currency.can_afford(entity_or_player, cost_table)
    if not can then
        return false, "Insufficient " .. tostring(missing)
    end

    -- Then spend
    for currency_id, amount in pairs(cost_table) do
        local current = currency.get(entity_or_player, currency_id)
        currency.set(entity_or_player, currency_id, current - amount)
    end

    return true
end
-- }}}

-- {{{ currency.refund
-- Refund currencies (inverse of spend).
-- @param entity_or_player Entity or player ID
-- @param cost_table Table of currency_id -> amount to refund
function currency.refund(entity_or_player, cost_table)
    if not cost_table then return end

    for currency_id, amount in pairs(cost_table) do
        currency.add(entity_or_player, currency_id, amount)
    end
end
-- }}}

-- {{{ currency.get_total_copper
-- Get total copper value from money_bag.
-- Useful for quick affordability checks on coin costs.
-- @param entity Entity with money_bag component
-- @return Total copper value
function currency.get_total_copper(entity)
    local ecs = get_ecs()
    local bag = ecs.get_component(entity, "money_bag")
    if not bag then return 0 end
    return bag.total_copper or 0
end
-- }}}

-- {{{ currency.format_money
-- Format copper amount as "Xg Ys Zc" string.
-- @param copper_amount Total copper value
-- @return Formatted string
function currency.format_money(copper_amount)
    if not copper_amount or copper_amount < 0 then
        return "0c"
    end

    local gold = math.floor(copper_amount / 10000)
    local silver = math.floor((copper_amount % 10000) / 100)
    local copper = copper_amount % 100

    local parts = {}
    if gold > 0 then parts[#parts + 1] = gold .. "g" end
    if silver > 0 then parts[#parts + 1] = silver .. "s" end
    if copper > 0 or #parts == 0 then parts[#parts + 1] = copper .. "c" end

    return table.concat(parts, " ")
end
-- }}}

-- {{{ currency.parse_money
-- Parse "Xg Ys Zc" string to copper amount.
-- @param money_string String like "1g 50s" or "500c"
-- @return Total copper value
function currency.parse_money(money_string)
    if not money_string or money_string == "" then
        return 0
    end

    local total = 0

    -- Match gold
    local gold = money_string:match("(%d+)g")
    if gold then total = total + tonumber(gold) * 10000 end

    -- Match silver
    local silver = money_string:match("(%d+)s")
    if silver then total = total + tonumber(silver) * 100 end

    -- Match copper
    local copper = money_string:match("(%d+)c")
    if copper then total = total + tonumber(copper) end

    return total
end
-- }}}

-- {{{ currency.get_schema
-- Get currency schema (passthrough to registry).
function currency.get_schema(id)
    return registry.get_schema(id)
end
-- }}}

-- {{{ currency.get_category
-- Get currency category.
function currency.get_category(id)
    return registry.get_category(id)
end
-- }}}

-- {{{ currency.is_physical
function currency.is_physical(id)
    return registry.is_physical(id)
end
-- }}}

-- {{{ currency.is_wc3
function currency.is_wc3(id)
    return registry.is_wc3(id)
end
-- }}}

-- {{{ currency.get_standing_name
-- Get reputation standing name.
function currency.get_standing_name(value)
    return registry.get_standing_name(value)
end
-- }}}

-- {{{ currency.get_honor_rank
-- Get honor rank info.
function currency.get_honor_rank(honor_value)
    return registry.get_honor_rank(honor_value)
end
-- }}}

-- {{{ Exports
currency.CURRENCY_CATEGORY = registry.CURRENCY_CATEGORY
currency.STANDING_THRESHOLDS = registry.STANDING_THRESHOLDS
currency.HONOR_RANKS = registry.HONOR_RANKS
currency.CURRENCY_SCHEMA = registry.CURRENCY_SCHEMA
currency.register_custom = registry.register_custom
currency.get_all_currencies = registry.get_all_currencies
currency.get_currencies_by_category = registry.get_currencies_by_category
-- }}}

-- Build dispatch tables on module load
build_dispatch_tables()

return currency

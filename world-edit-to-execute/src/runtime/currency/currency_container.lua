--[[
Currency Container - Abstract Currency Storage Component

Manages abstract currencies (honor, arena, justice, valor) and tokens
that are stored as counters rather than physical items. Supports caps,
weekly limits, decay, and modifiers.

Unlike money_bag (physical coins), currency_container stores point values
that don't occupy inventory space.

Usage:
  local container = require("runtime.currency.currency_container")

  -- Register component
  container.register_component()

  -- Add points
  container.add(entity_container, "honor", 500)

  -- Check weekly cap
  if container.can_earn_weekly(entity_container, "valor_points", 100) then
      container.add(entity_container, "valor_points", 100)
  end

  -- Apply weekly decay
  container.apply_decay(entity_container)
]]

local registry = require("runtime.currency.registry")

local container = {}

-- {{{ Constants
-- Component structure defaults
local COMPONENT_DEFAULTS = {
    -- Abstract currency values indexed by currency index
    values = {},

    -- Token counts indexed by currency name
    tokens = {},

    -- Weekly earned amounts (for weekly cap tracking)
    weekly_earned = {},

    -- Timestamp of last weekly reset
    last_weekly_reset = 0,

    -- Modifiers (from buffs, items, etc.)
    modifiers = {},
}

-- Weekly reset interval in seconds (7 days)
container.WEEKLY_RESET_INTERVAL = 7 * 24 * 60 * 60
-- }}}

-- {{{ local function get_ecs
local function get_ecs()
    return require("runtime.ecs")
end
-- }}}

-- {{{ local function get_time
-- Get current timestamp (can be overridden for testing).
local function get_time()
    return os.time()
end
-- }}}

-- {{{ local function get_schema_for_id
-- Resolve currency ID to schema, handling both string names and indices.
local function get_schema_for_id(currency_id)
    return registry.get_schema(currency_id)
end
-- }}}

-- {{{ local function get_index_for_id
-- Get the numeric index for a currency ID.
local function get_index_for_id(currency_id)
    local schema = get_schema_for_id(currency_id)
    if schema then
        return schema.index
    end
    return nil
end
-- }}}

-- {{{ container.register_component
-- Register the currency_container ECS component.
-- Call this during game initialization.
function container.register_component()
    local ecs = get_ecs()
    local component = ecs.component or require("runtime.ecs.component")

    -- Check if already registered
    if component.get_defaults and component.get_defaults("currency_container") then
        return
    end

    component.register("currency_container", {
        values = {},
        tokens = {},
        weekly_earned = {},
        last_weekly_reset = 0,
        modifiers = {},
    })
end
-- }}}

-- {{{ container.create
-- Create a fresh currency_container data structure.
-- @return New container table
function container.create()
    return {
        values = {},
        tokens = {},
        weekly_earned = {},
        last_weekly_reset = get_time(),
        modifiers = {},
    }
end
-- }}}

-- {{{ container.get
-- Get current value of an abstract currency.
-- @param cont Container table
-- @param currency_id Currency name or index
-- @return Current value, or 0 if not set
function container.get(cont, currency_id)
    if not cont or not cont.values then
        return 0
    end

    local idx = get_index_for_id(currency_id)
    if not idx then
        return 0
    end

    return cont.values[idx] or 0
end
-- }}}

-- {{{ container.set
-- Set value of an abstract currency.
-- @param cont Container table
-- @param currency_id Currency name or index
-- @param amount New value (clamped to 0 and cap)
-- @return New value after clamping
function container.set(cont, currency_id, amount)
    if not cont then
        return 0
    end
    cont.values = cont.values or {}

    local schema = get_schema_for_id(currency_id)
    if not schema then
        return 0
    end

    local idx = schema.index

    -- Clamp to valid range
    amount = math.max(0, math.floor(amount))
    if schema.cap then
        amount = math.min(amount, schema.cap)
    end

    cont.values[idx] = amount
    return amount
end
-- }}}

-- {{{ container.add
-- Add to an abstract currency.
-- @param cont Container table
-- @param currency_id Currency name or index
-- @param amount Amount to add (can be negative)
-- @return New value
function container.add(cont, currency_id, amount)
    local current = container.get(cont, currency_id)
    return container.set(cont, currency_id, current + amount)
end
-- }}}

-- {{{ container.subtract
-- Subtract from an abstract currency.
-- @param cont Container table
-- @param currency_id Currency name or index
-- @param amount Amount to subtract
-- @return true if successful, false if insufficient
function container.subtract(cont, currency_id, amount)
    local current = container.get(cont, currency_id)
    if current < amount then
        return false, "Insufficient " .. tostring(currency_id)
    end
    container.set(cont, currency_id, current - amount)
    return true
end
-- }}}

-- {{{ container.get_cap
-- Get the cap for a currency.
-- @param currency_id Currency name or index
-- @return Cap value, or nil if uncapped
function container.get_cap(currency_id)
    local schema = get_schema_for_id(currency_id)
    if schema then
        return schema.cap
    end
    return nil
end
-- }}}

-- {{{ container.get_weekly_cap
-- Get the weekly earning cap for a currency.
-- @param currency_id Currency name or index
-- @return Weekly cap value, or nil if no weekly cap
function container.get_weekly_cap(currency_id)
    local schema = get_schema_for_id(currency_id)
    if schema then
        return schema.weekly_cap
    end
    return nil
end
-- }}}

-- {{{ container.get_weekly_earned
-- Get amount earned this week for a currency.
-- @param cont Container table
-- @param currency_id Currency name or index
-- @return Amount earned this week
function container.get_weekly_earned(cont, currency_id)
    if not cont or not cont.weekly_earned then
        return 0
    end

    local idx = get_index_for_id(currency_id)
    if not idx then
        return 0
    end

    return cont.weekly_earned[idx] or 0
end
-- }}}

-- {{{ container.can_earn_weekly
-- Check if more of a currency can be earned this week.
-- @param cont Container table
-- @param currency_id Currency name or index
-- @param amount Amount to potentially earn
-- @return true if can earn, false if at weekly cap
function container.can_earn_weekly(cont, currency_id, amount)
    local weekly_cap = container.get_weekly_cap(currency_id)
    if not weekly_cap then
        return true  -- No weekly cap
    end

    local earned = container.get_weekly_earned(cont, currency_id)
    return (earned + amount) <= weekly_cap
end
-- }}}

-- {{{ container.add_with_weekly_tracking
-- Add currency while tracking weekly earnings.
-- @param cont Container table
-- @param currency_id Currency name or index
-- @param amount Amount to add
-- @return Amount actually added (may be less due to weekly cap)
function container.add_with_weekly_tracking(cont, currency_id, amount)
    if not cont then
        return 0
    end
    cont.weekly_earned = cont.weekly_earned or {}

    local idx = get_index_for_id(currency_id)
    if not idx then
        return 0
    end

    -- Check weekly cap
    local weekly_cap = container.get_weekly_cap(currency_id)
    if weekly_cap then
        local earned = cont.weekly_earned[idx] or 0
        local room = weekly_cap - earned
        amount = math.min(amount, room)

        if amount > 0 then
            cont.weekly_earned[idx] = earned + amount
        end
    end

    if amount > 0 then
        container.add(cont, currency_id, amount)
    end

    return amount
end
-- }}}

-- {{{ container.reset_weekly
-- Reset weekly earned amounts.
-- @param cont Container table
function container.reset_weekly(cont)
    if not cont then
        return
    end
    cont.weekly_earned = {}
    cont.last_weekly_reset = get_time()
end
-- }}}

-- {{{ container.check_weekly_reset
-- Check if weekly reset is due and perform it.
-- @param cont Container table
-- @return true if reset was performed
function container.check_weekly_reset(cont)
    if not cont then
        return false
    end

    local now = get_time()
    local last_reset = cont.last_weekly_reset or 0
    local elapsed = now - last_reset

    if elapsed >= container.WEEKLY_RESET_INTERVAL then
        container.reset_weekly(cont)
        return true
    end

    return false
end
-- }}}

-- {{{ container.apply_decay
-- Apply weekly decay to currencies that have decay_rate.
-- @param cont Container table
-- @return Table of {currency_id = amount_lost}
function container.apply_decay(cont)
    if not cont or not cont.values then
        return {}
    end

    local losses = {}

    for name, schema in pairs(registry.CURRENCY_SCHEMA) do
        if schema.decay_rate and schema.decay_rate > 0 then
            local idx = schema.index
            local current = cont.values[idx] or 0

            if current > 0 then
                local loss = math.floor(current * schema.decay_rate)
                local new_value = current - loss
                cont.values[idx] = math.max(0, new_value)
                losses[name] = loss
            end
        end
    end

    return losses
end
-- }}}

-- {{{ container.get_decay_rate
-- Get the decay rate for a currency.
-- @param currency_id Currency name or index
-- @return Decay rate (0.0-1.0), or 0 if no decay
function container.get_decay_rate(currency_id)
    local schema = get_schema_for_id(currency_id)
    if schema then
        return schema.decay_rate or 0
    end
    return 0
end
-- }}}

-- {{{ Token currency operations

-- {{{ container.get_token
-- Get count of a token currency.
-- @param cont Container table
-- @param token_name Token currency name
-- @return Count
function container.get_token(cont, token_name)
    if not cont or not cont.tokens then
        return 0
    end
    return cont.tokens[token_name] or 0
end
-- }}}

-- {{{ container.set_token
-- Set count of a token currency.
-- @param cont Container table
-- @param token_name Token currency name
-- @param amount New count
function container.set_token(cont, token_name, amount)
    if not cont then
        return
    end
    cont.tokens = cont.tokens or {}
    cont.tokens[token_name] = math.max(0, math.floor(amount))
end
-- }}}

-- {{{ container.add_token
-- Add to a token currency count.
-- @param cont Container table
-- @param token_name Token currency name
-- @param amount Amount to add
-- @return New count
function container.add_token(cont, token_name, amount)
    local current = container.get_token(cont, token_name)
    local new_value = current + amount
    container.set_token(cont, token_name, new_value)
    return container.get_token(cont, token_name)
end
-- }}}

-- {{{ container.remove_token
-- Remove from a token currency count.
-- @param cont Container table
-- @param token_name Token currency name
-- @param amount Amount to remove
-- @return true if successful, false if insufficient
function container.remove_token(cont, token_name, amount)
    local current = container.get_token(cont, token_name)
    if current < amount then
        return false, "Insufficient " .. token_name
    end
    container.set_token(cont, token_name, current - amount)
    return true
end
-- }}}

-- }}} End token operations

-- {{{ container.get_modifier
-- Get a modifier value.
-- @param cont Container table
-- @param modifier_name Modifier name
-- @return Modifier value, or 0
function container.get_modifier(cont, modifier_name)
    if not cont or not cont.modifiers then
        return 0
    end
    return cont.modifiers[modifier_name] or 0
end
-- }}}

-- {{{ container.set_modifier
-- Set a modifier value.
-- @param cont Container table
-- @param modifier_name Modifier name
-- @param value Modifier value
function container.set_modifier(cont, modifier_name, value)
    if not cont then
        return
    end
    cont.modifiers = cont.modifiers or {}
    cont.modifiers[modifier_name] = value
end
-- }}}

-- {{{ container.clear_modifiers
-- Clear all modifiers.
-- @param cont Container table
function container.clear_modifiers(cont)
    if not cont then
        return
    end
    cont.modifiers = {}
end
-- }}}

-- {{{ container.format
-- Format a currency value for display.
-- @param currency_id Currency name or index
-- @param amount Value to format
-- @return Formatted string
function container.format(currency_id, amount)
    local schema = get_schema_for_id(currency_id)
    if not schema then
        return tostring(amount)
    end

    local name = schema.display_name or currency_id
    return string.format("%d %s", amount, name)
end
-- }}}

-- {{{ container.get_all_values
-- Get all non-zero abstract currency values.
-- @param cont Container table
-- @return Table of {currency_name = value}
function container.get_all_values(cont)
    if not cont or not cont.values then
        return {}
    end

    local result = {}
    for name, schema in pairs(registry.CURRENCY_SCHEMA) do
        if schema.category == registry.CURRENCY_CATEGORY.ABSTRACT then
            local idx = schema.index
            local value = cont.values[idx] or 0
            if value > 0 then
                result[name] = value
            end
        end
    end

    return result
end
-- }}}

-- {{{ container.get_all_tokens
-- Get all non-zero token counts.
-- @param cont Container table
-- @return Table of {token_name = count}
function container.get_all_tokens(cont)
    if not cont or not cont.tokens then
        return {}
    end

    local result = {}
    for name, count in pairs(cont.tokens) do
        if count > 0 then
            result[name] = count
        end
    end

    return result
end
-- }}}

-- {{{ container.reset
-- Reset container to empty state.
-- @param cont Container table
function container.reset(cont)
    if not cont then
        return
    end
    cont.values = {}
    cont.tokens = {}
    cont.weekly_earned = {}
    cont.last_weekly_reset = get_time()
    cont.modifiers = {}
end
-- }}}

-- {{{ container.clone
-- Create a copy of a container.
-- @param cont Container table
-- @return New container with same values
function container.clone(cont)
    if not cont then
        return container.create()
    end

    local copy = container.create()

    -- Deep copy values
    for k, v in pairs(cont.values or {}) do
        copy.values[k] = v
    end

    -- Deep copy tokens
    for k, v in pairs(cont.tokens or {}) do
        copy.tokens[k] = v
    end

    -- Deep copy weekly_earned
    for k, v in pairs(cont.weekly_earned or {}) do
        copy.weekly_earned[k] = v
    end

    copy.last_weekly_reset = cont.last_weekly_reset or 0

    -- Deep copy modifiers
    for k, v in pairs(cont.modifiers or {}) do
        copy.modifiers[k] = v
    end

    return copy
end
-- }}}

return container

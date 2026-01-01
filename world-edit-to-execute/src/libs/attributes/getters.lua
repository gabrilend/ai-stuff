-- Attribute Getters Module
-- Dispatch table-based getters for O(1) attribute access.
--
-- This module provides computed getters that:
-- - Apply modifier stacks (flat, percent, multiplier)
-- - Compute derived attributes with dirty-flag caching
-- - Support raw vs computed access
-- - Enable batch reads for efficiency
--
-- Modifier application order: (base + flat) * (1 + percent/100) * multiplier
--
-- Usage:
--   local getters = require("libs.attributes.getters")
--   local value = getters.get(container, "strength")
--   local raw = getters.get_raw(container, "strength")
--   local breakdown = getters.get_modifier_breakdown(container, "strength")

local registry = require("libs.attributes.registry")

-- {{{ Module state
local getters = {}

-- Dispatch tables: populated from registry
-- GETTERS[id] and GETTERS[index] both work
local GETTERS = {}
local GETTERS_RAW = {}
-- }}}

-- {{{ Forward declarations
local apply_modifiers
local recalculate_derived
-- }}}

-- {{{ apply_modifiers
-- Apply modifier stack to a base value.
-- Modifier types:
--   - flat: added to base
--   - percent: percentage increase (additive with other percents)
--   - multiplier: multiplicative (stacks multiplicatively)
-- Order: (base + flat) * (1 + percent/100) * multiplier
-- @param container The attribute container
-- @param attr_id The attribute ID (for modifier lookup)
-- @param base_value The raw base value
-- @return Modified value
apply_modifiers = function(container, attr_id, base_value)
    local mods = container.modifiers[attr_id]
    if not mods or #mods == 0 then
        return base_value
    end

    local flat_sum = 0
    local percent_sum = 0
    local multiplier = 1

    for i = 1, #mods do
        local mod = mods[i]
        if mod.type == "flat" then
            flat_sum = flat_sum + mod.value
        elseif mod.type == "percent" then
            percent_sum = percent_sum + mod.value
        elseif mod.type == "multiplier" then
            multiplier = multiplier * mod.value
        end
    end

    -- Order: (base + flat) * (1 + percent/100) * multiplier
    return (base_value + flat_sum) * (1 + percent_sum / 100) * multiplier
end
-- }}}

-- {{{ recalculate_derived
-- Recalculate a derived attribute's value using its formula.
-- @param container The attribute container
-- @param schema The AttributeSchema for the derived attribute
recalculate_derived = function(container, schema)
    -- Create getter proxy for formula
    -- This allows the formula to access other attributes
    local get = function(attr_id)
        local getter = GETTERS[attr_id]
        if getter then
            return getter(container)
        end
        return 0
    end

    -- Execute formula
    local new_value = schema.formula(get)

    -- Store result and clear dirty flag
    container.values[schema.index] = new_value
    container.dirty[schema.index] = nil

    -- Also store in cached table for explicit cache access
    container.cached[schema.index] = new_value
end
-- }}}

-- {{{ build_getters
-- Build dispatch tables from the registry.
-- Called automatically on module load and can be called after
-- registry changes via rebuild().
local function build_getters()
    GETTERS = {}
    GETTERS_RAW = {}

    for id, schema in pairs(registry.schemas) do
        local index = schema.index

        -- Raw getter: base value only, no modifiers
        GETTERS_RAW[id] = function(container)
            return container.values[index]
        end
        -- Also index by numeric key for O(1) access
        GETTERS_RAW[index] = GETTERS_RAW[id]

        if schema:is_derived() then
            -- Derived attribute getter: compute on demand if dirty
            GETTERS[id] = function(container)
                -- Check dirty flag - recalculate if needed
                if container.dirty[index] then
                    recalculate_derived(container, schema)
                end
                return container.values[index]
            end
        else
            -- Standard attribute getter: apply modifiers
            GETTERS[id] = function(container)
                local base = container.values[index]
                return apply_modifiers(container, id, base)
            end
        end

        -- Also index by numeric key
        GETTERS[index] = GETTERS[id]
    end
end
-- }}}

-- {{{ Public API

-- {{{ getters.get
-- Get computed attribute value (with modifiers applied).
-- For derived attributes, recalculates if dirty.
-- @param container The attribute container
-- @param attr_id Attribute ID (string) or index (number)
-- @return value, or nil and error message if unknown
function getters.get(container, attr_id)
    local getter = GETTERS[attr_id]
    if not getter then
        return nil, "Unknown attribute: " .. tostring(attr_id)
    end
    return getter(container)
end
-- }}}

-- {{{ getters.get_raw
-- Get raw base value (no modifiers, no derived computation).
-- @param container The attribute container
-- @param attr_id Attribute ID or index
-- @return value, or nil and error message if unknown
function getters.get_raw(container, attr_id)
    local getter = GETTERS_RAW[attr_id]
    if not getter then
        return nil, "Unknown attribute: " .. tostring(attr_id)
    end
    return getter(container)
end
-- }}}

-- {{{ getters.get_base
-- Get base value with flat modifiers only (no percent/multiplier).
-- Useful for displaying "base + bonus" in UI.
-- @param container The attribute container
-- @param attr_id Attribute ID or index
-- @return value, or nil if unknown
function getters.get_base(container, attr_id)
    local base = getters.get_raw(container, attr_id)
    if base == nil then
        return nil
    end

    local schema = registry.get(attr_id)
    if not schema then
        return base
    end

    local mods = container.modifiers[attr_id] or container.modifiers[schema.id]
    if not mods then
        return base
    end

    local flat_sum = 0
    for i = 1, #mods do
        local mod = mods[i]
        if mod.type == "flat" then
            flat_sum = flat_sum + mod.value
        end
    end

    return base + flat_sum
end
-- }}}

-- {{{ getters.get_many
-- Batch read multiple attributes for efficiency.
-- @param container The attribute container
-- @param attr_ids Array of attribute IDs or indexes
-- @return Table mapping each id to its computed value
function getters.get_many(container, attr_ids)
    local results = {}
    for i = 1, #attr_ids do
        local id = attr_ids[i]
        results[id] = getters.get(container, id)
    end
    return results
end
-- }}}

-- {{{ getters.get_all
-- Get all non-hidden attributes.
-- @param container The attribute container
-- @return Table mapping id to computed value for all visible attributes
function getters.get_all(container)
    local results = {}
    for id, schema in pairs(registry.schemas) do
        if not schema:is_hidden() then
            results[id] = getters.get(container, id)
        end
    end
    return results
end
-- }}}

-- {{{ getters.get_all_raw
-- Get all attributes as raw values (no modifiers).
-- @param container The attribute container
-- @return Table mapping id to raw value
function getters.get_all_raw(container)
    local results = {}
    for id, schema in pairs(registry.schemas) do
        results[id] = container.values[schema.index]
    end
    return results
end
-- }}}

-- {{{ getters.get_modifier_breakdown
-- Get detailed breakdown of how a value is computed.
-- Useful for debugging and UI tooltips.
-- @param container The attribute container
-- @param attr_id Attribute ID or index
-- @return Breakdown table or nil if unknown
function getters.get_modifier_breakdown(container, attr_id)
    local schema = registry.get(attr_id)
    if not schema then
        return nil
    end

    local breakdown = {
        id = schema.id,
        index = schema.index,
        base = container.values[schema.index],
        flat = 0,
        percent = 0,
        multiplier = 1,
        sources = {},
        is_derived = schema:is_derived(),
    }

    -- Collect modifiers
    local mods = container.modifiers[schema.id] or {}
    for i = 1, #mods do
        local mod = mods[i]
        breakdown.sources[#breakdown.sources + 1] = {
            source = mod.source,
            type = mod.type,
            value = mod.value,
        }

        if mod.type == "flat" then
            breakdown.flat = breakdown.flat + mod.value
        elseif mod.type == "percent" then
            breakdown.percent = breakdown.percent + mod.value
        elseif mod.type == "multiplier" then
            breakdown.multiplier = breakdown.multiplier * mod.value
        end
    end

    -- Calculate final value
    breakdown.final = getters.get(container, attr_id)

    -- For derived attributes, also note dependencies
    if schema:is_derived() and schema.derived_from then
        breakdown.derived_from = {}
        for i = 1, #schema.derived_from do
            local dep_id = schema.derived_from[i]
            breakdown.derived_from[dep_id] = getters.get(container, dep_id)
        end
    end

    return breakdown
end
-- }}}

-- {{{ getters.get_getter
-- Get the getter function directly for hot-path optimization.
-- Pre-resolve once, then call directly in tight loops.
-- @param attr_id Attribute ID or index
-- @return Getter function or nil
function getters.get_getter(attr_id)
    return GETTERS[attr_id]
end
-- }}}

-- {{{ getters.get_raw_getter
-- Get the raw getter function directly.
-- @param attr_id Attribute ID or index
-- @return Raw getter function or nil
function getters.get_raw_getter(attr_id)
    return GETTERS_RAW[attr_id]
end
-- }}}

-- {{{ getters.has
-- Check if a getter exists for an attribute.
-- @param attr_id Attribute ID or index
-- @return boolean
function getters.has(attr_id)
    return GETTERS[attr_id] ~= nil
end
-- }}}

-- {{{ getters.rebuild
-- Rebuild dispatch tables after registry changes.
-- Call this after registering new attributes.
function getters.rebuild()
    build_getters()
end
-- }}}

-- {{{ getters.mark_dirty
-- Mark a derived attribute as needing recalculation.
-- Also marks any attributes that depend on this one.
-- @param container The attribute container
-- @param attr_id The attribute that changed
function getters.mark_dirty(container, attr_id)
    -- Get dependents from registry
    local dependents = registry.get_dependents(attr_id)
    for i = 1, #dependents do
        local dep_id = dependents[i]
        local schema = registry.get(dep_id)
        if schema then
            container.dirty[schema.index] = true
            -- Recursively mark dependents of dependents
            getters.mark_dirty(container, dep_id)
        end
    end
end
-- }}}

-- {{{ getters.invalidate_all_derived
-- Mark all derived attributes as dirty.
-- Useful after bulk changes or loading.
-- @param container The attribute container
function getters.invalidate_all_derived(container)
    for _, schema in pairs(registry.schemas) do
        if schema:is_derived() then
            container.dirty[schema.index] = true
        end
    end
end
-- }}}

-- }}}

-- Initialize on load
build_getters()

return getters

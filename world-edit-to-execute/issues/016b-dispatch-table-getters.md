# Issue 016b: Dispatch Table Getters

## Current Behavior

Attribute access uses direct table field access or string-keyed lookups with no caching, validation, or modifier application.

## Intended Behavior

Dispatch table-based getters that:
- Lookup handler by attribute ID in O(1)
- Apply modifier stacks automatically
- Cache derived values with invalidation
- Provide raw vs computed access
- Support batch reads for efficiency

## Suggested Implementation Steps

### 1. Getter Dispatch Table

```lua
-- src/libs/attributes/getters.lua

local registry = require("src.libs.attributes.registry")

-- {{{ Getter dispatch table
-- Built dynamically from registry
local GETTERS = {}
local GETTERS_RAW = {}

-- {{{ build_getters
local function build_getters()
    GETTERS = {}
    GETTERS_RAW = {}

    for id, schema in pairs(registry.schemas) do
        local index = schema.index

        -- Raw getter (base value only, no modifiers)
        GETTERS_RAW[id] = function(container)
            return container.values[index]
        end
        GETTERS_RAW[index] = GETTERS_RAW[id]

        if schema:is_derived() then
            -- Derived attribute getter
            GETTERS[id] = function(container)
                -- Check dirty flag
                if container.dirty[index] then
                    recalculate_derived(container, schema)
                end
                return container.values[index]
            end
        else
            -- Standard attribute getter (with modifiers)
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
-- }}}

-- {{{ apply_modifiers
local function apply_modifiers(container, attr_id, base_value)
    local mods = container.modifiers[attr_id]
    if not mods or #mods == 0 then
        return base_value
    end

    local flat_sum = 0
    local percent_sum = 0
    local multiplier = 1

    for _, mod in ipairs(mods) do
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
local function recalculate_derived(container, schema)
    -- Create getter proxy for formula
    local get = function(attr_id)
        local getter = GETTERS[attr_id]
        return getter and getter(container) or 0
    end

    -- Execute formula
    local new_value = schema.formula(get)

    -- Store and clear dirty
    container.values[schema.index] = new_value
    container.dirty[schema.index] = nil
end
-- }}}

-- {{{ Public API
local M = {}

-- {{{ get
-- Primary getter - applies modifiers, computes derived
function M.get(container, attr_id)
    local getter = GETTERS[attr_id]
    if not getter then
        return nil, "Unknown attribute: " .. tostring(attr_id)
    end
    return getter(container)
end
-- }}}

-- {{{ get_raw
-- Raw getter - base value only
function M.get_raw(container, attr_id)
    local getter = GETTERS_RAW[attr_id]
    if not getter then
        return nil, "Unknown attribute: " .. tostring(attr_id)
    end
    return getter(container)
end
-- }}}

-- {{{ get_base
-- Base + flat modifiers only (no percent/multiplier)
function M.get_base(container, attr_id)
    local base = M.get_raw(container, attr_id)
    if not base then return nil end

    local mods = container.modifiers[attr_id]
    if not mods then return base end

    local flat_sum = 0
    for _, mod in ipairs(mods) do
        if mod.type == "flat" then
            flat_sum = flat_sum + mod.value
        end
    end

    return base + flat_sum
end
-- }}}

-- {{{ get_many
-- Batch read for efficiency
function M.get_many(container, attr_ids)
    local results = {}
    for _, id in ipairs(attr_ids) do
        results[id] = M.get(container, id)
    end
    return results
end
-- }}}

-- {{{ get_all
-- Get all non-hidden attributes
function M.get_all(container)
    local results = {}
    for id, schema in pairs(registry.schemas) do
        if not schema:is_hidden() then
            results[id] = M.get(container, id)
        end
    end
    return results
end
-- }}}

-- {{{ get_modifier_breakdown
-- Debug: show how value is computed
function M.get_modifier_breakdown(container, attr_id)
    local schema = registry.get(attr_id)
    if not schema then return nil end

    local breakdown = {
        base = container.values[schema.index],
        flat = 0,
        percent = 0,
        multiplier = 1,
        sources = {},
    }

    local mods = container.modifiers[attr_id] or {}
    for _, mod in ipairs(mods) do
        table.insert(breakdown.sources, {
            source = mod.source,
            type = mod.type,
            value = mod.value,
        })

        if mod.type == "flat" then
            breakdown.flat = breakdown.flat + mod.value
        elseif mod.type == "percent" then
            breakdown.percent = breakdown.percent + mod.value
        elseif mod.type == "multiplier" then
            breakdown.multiplier = breakdown.multiplier * mod.value
        end
    end

    breakdown.final = M.get(container, attr_id)
    return breakdown
end
-- }}}

-- {{{ rebuild
-- Rebuild dispatch tables (call after registry changes)
function M.rebuild()
    build_getters()
end
-- }}}

-- Initialize on load
build_getters()

return M
-- }}}
```

### 2. Index Constants for Fast Access

```lua
-- src/libs/attributes/indexes.lua
-- Generated from registry, provides compile-time constants

local ATTR = {}

-- Populated by registry
-- ATTR.STRENGTH = 1
-- ATTR.AGILITY = 2
-- etc.

local function rebuild_indexes()
    local registry = require("src.libs.attributes.registry")
    for id, schema in pairs(registry.schemas) do
        ATTR[id:upper()] = schema.index
    end
end

return {
    ATTR = ATTR,
    rebuild = rebuild_indexes,
}
```

### 3. Cached Getter Pattern

```lua
-- For hot paths, pre-resolve the getter once
local get_strength = GETTERS["strength"]

-- Then use directly in tight loops
for _, entity in ipairs(entities) do
    local str = get_strength(entity.attributes)
    -- ...
end
```

## Related Documents

- Issue 016a - Core attribute registry
- Issue 016c - Dispatch table setters
- Issue 016d - Modifier stack system

## Acceptance Criteria

- [ ] GETTERS dispatch table populated from registry
- [ ] get() applies modifiers correctly
- [ ] get_raw() returns base value only
- [ ] Derived attributes computed on access
- [ ] Dirty flag system for cache invalidation
- [ ] get_many() for batch reads
- [ ] get_modifier_breakdown() for debugging
- [ ] Unit tests for modifier application

---

**Status:** Pending
**Dependencies:** 016a (Core Attribute Registry)

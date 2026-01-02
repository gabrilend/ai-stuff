# Issue 016c: Dispatch Table Setters

## Current Behavior

Attribute modification is done via direct assignment with no validation, event firing, or dependent attribute invalidation.

## Intended Behavior

Dispatch table-based setters that:
- Validate values against schema constraints
- Fire change events for reactive systems
- Invalidate dependent (derived) attributes
- Clamp or reject out-of-range values
- Support transactions for batch updates

## Suggested Implementation Steps

### 1. Setter Dispatch Table

```lua
-- src/libs/attributes/setters.lua

local registry = require("src.libs.attributes.registry")
local events = require("src.libs.attributes.events")

-- {{{ Setter dispatch table
local SETTERS = {}

-- {{{ build_setters
local function build_setters()
    SETTERS = {}

    for id, schema in pairs(registry.schemas) do
        local index = schema.index

        if schema:is_derived() then
            -- Derived attributes cannot be set directly
            SETTERS[id] = function(container, value)
                return false, "Cannot set derived attribute: " .. id
            end
        elseif schema:is_readonly() then
            -- Readonly attributes
            SETTERS[id] = function(container, value)
                return false, "Attribute is readonly: " .. id
            end
        else
            -- Standard setter
            SETTERS[id] = function(container, value, options)
                options = options or {}

                -- Validate
                local ok, err = schema:validate(value)
                if not ok then
                    if options.clamp and schema.min and schema.max then
                        value = math.max(schema.min, math.min(schema.max, value))
                    else
                        return false, err
                    end
                end

                -- Get old value
                local old_value = container.values[index]
                if old_value == value then
                    return true  -- No change
                end

                -- Set new value
                container.values[index] = value

                -- Mark dependents dirty
                invalidate_dependents(container, id)

                -- Fire event (unless suppressed)
                if not options.silent then
                    events.fire("attribute_changed", {
                        container = container,
                        attribute = id,
                        old_value = old_value,
                        new_value = value,
                        source = options.source,
                    })
                end

                return true
            end
        end

        -- Also index by numeric key
        SETTERS[index] = SETTERS[id]
    end
end
-- }}}
-- }}}

-- {{{ invalidate_dependents
local function invalidate_dependents(container, attr_id)
    local dependents = registry.get_dependents(attr_id)
    for _, dep_id in ipairs(dependents) do
        local dep_schema = registry.get(dep_id)
        if dep_schema then
            container.dirty[dep_schema.index] = true
            -- Recursively invalidate
            invalidate_dependents(container, dep_id)
        end
    end
end
-- }}}

-- {{{ Public API
local M = {}

-- {{{ set
-- Primary setter with validation and events
function M.set(container, attr_id, value, options)
    local setter = SETTERS[attr_id]
    if not setter then
        return false, "Unknown attribute: " .. tostring(attr_id)
    end
    return setter(container, value, options)
end
-- }}}

-- {{{ set_raw
-- Bypass validation (dangerous, for internal use)
function M.set_raw(container, attr_id, value)
    local schema = registry.get(attr_id)
    if not schema then
        return false, "Unknown attribute"
    end
    container.values[schema.index] = value
    invalidate_dependents(container, attr_id)
    return true
end
-- }}}

-- {{{ set_many
-- Batch update with single event
function M.set_many(container, updates, options)
    options = options or {}
    local results = {}
    local changes = {}

    -- Suppress individual events
    local batch_options = {
        silent = true,
        clamp = options.clamp,
        source = options.source,
    }

    for attr_id, value in pairs(updates) do
        local schema = registry.get(attr_id)
        if schema then
            local old_value = container.values[schema.index]
            local ok, err = M.set(container, attr_id, value, batch_options)
            results[attr_id] = { ok = ok, error = err }

            if ok and old_value ~= value then
                table.insert(changes, {
                    attribute = attr_id,
                    old_value = old_value,
                    new_value = value,
                })
            end
        end
    end

    -- Fire single batch event
    if not options.silent and #changes > 0 then
        events.fire("attributes_changed", {
            container = container,
            changes = changes,
            source = options.source,
        })
    end

    return results
end
-- }}}

-- {{{ adjust
-- Add/subtract from current value
function M.adjust(container, attr_id, delta, options)
    local getters = require("src.libs.attributes.getters")
    local current = getters.get_raw(container, attr_id)
    if not current then
        return false, "Unknown attribute"
    end
    return M.set(container, attr_id, current + delta, options)
end
-- }}}

-- {{{ reset
-- Reset to default value
function M.reset(container, attr_id, options)
    local schema = registry.get(attr_id)
    if not schema then
        return false, "Unknown attribute"
    end
    return M.set(container, attr_id, schema.default, options)
end
-- }}}

-- {{{ reset_all
-- Reset all attributes to defaults
function M.reset_all(container, options)
    options = options or {}
    local batch_options = { silent = true, source = options.source }

    for id, schema in pairs(registry.schemas) do
        if not schema:is_derived() then
            M.set(container, id, schema.default, batch_options)
        end
    end

    -- Clear all modifiers
    container.modifiers = {}

    -- Mark all derived dirty
    for id, schema in pairs(registry.schemas) do
        if schema:is_derived() then
            container.dirty[schema.index] = true
        end
    end

    if not options.silent then
        events.fire("attributes_reset", {
            container = container,
            source = options.source,
        })
    end

    return true
end
-- }}}

-- {{{ Transaction support
local Transaction = {}
Transaction.__index = Transaction

function M.begin_transaction(container)
    local txn = setmetatable({
        container = container,
        snapshot = {},
        pending = {},
    }, Transaction)

    -- Snapshot current values
    for index, value in pairs(container.values) do
        txn.snapshot[index] = value
    end

    return txn
end

function Transaction:set(attr_id, value)
    self.pending[attr_id] = value
end

function Transaction:commit(options)
    return M.set_many(self.container, self.pending, options)
end

function Transaction:rollback()
    for index, value in pairs(self.snapshot) do
        self.container.values[index] = value
    end
    -- Clear dirty flags and recompute would be needed
end
-- }}}

-- {{{ rebuild
function M.rebuild()
    build_setters()
end
-- }}}

-- Initialize on load
build_setters()

return M
-- }}}
```

### 2. Setter Options

```lua
-- Usage examples:

-- Basic set
set(entity.attrs, "strength", 25)

-- With options
set(entity.attrs, "strength", 999, {
    clamp = true,     -- Clamp to min/max instead of reject
    silent = true,    -- Don't fire events
    source = "item:sword_of_might",  -- Track what caused change
})

-- Batch update
set_many(entity.attrs, {
    strength = 20,
    agility = 15,
    stamina = 25,
}, { source = "level_up" })

-- Adjustment
adjust(entity.attrs, "health", -50, { source = "damage:fire" })
```

## Related Documents

- Issue 016a - Core attribute registry
- Issue 016b - Dispatch table getters
- Issue 016d - Modifier stack system

## Acceptance Criteria

- [x] SETTERS dispatch table populated from registry
- [x] set() validates against schema
- [x] Derived attributes reject direct set
- [x] Dependent attributes marked dirty on change
- [x] Events fired on value change
- [x] set_many() for batch updates
- [x] adjust() for delta operations
- [x] Transaction support for rollback
- [x] Unit tests for all paths

---

**Status:** Completed
**Dependencies:** 016a (Core Attribute Registry)

---

## Implementation Notes

**Completed 2026-01-01**

### Files Created

1. **src/libs/attributes/setters.lua** (~400 lines)
   - `SETTERS` dispatch table built from registry
   - `build_setters()` - creates setters for each attribute type
   - `invalidate_dependents()` - recursively marks derived attributes dirty
   - `fire_event()` - fires events to registered listeners
   - `set()` - primary setter with validation, clamping, events
   - `set_raw()` - bypass validation (for loading saved data)
   - `set_many()` - batch update with single event
   - `adjust()` - add/subtract from current value
   - `reset()` - reset single attribute to default
   - `reset_all()` - reset all attributes, clear modifiers
   - `on()` / `off()` / `clear_listeners()` - event listener management
   - `Transaction` class with `set()`, `commit()`, `rollback()`
   - `begin_transaction()` - create transaction for batch updates

2. **src/tests/test_setters.lua** (~650 lines)
   - 49 comprehensive unit tests covering all acceptance criteria
   - Tests: basic set, validation (min/max/clamp), type validation
   - Tests: derived/readonly protection, dependent invalidation
   - Tests: events (attribute_changed, attributes_changed, silent mode)
   - Tests: set_raw, set_many, adjust, reset, reset_all
   - Tests: transactions (queue, commit, rollback)
   - Tests: utility functions (has, get_setter, rebuild)

### Files Modified

- **src/libs/attributes/init.lua** - Added setters exports

### Key Design Decisions

1. **Built-in Event System**: Rather than depending on an external events module,
   setters.lua includes its own lightweight event system with `on()`, `off()`,
   and `clear_listeners()`. Events: `attribute_changed`, `attributes_changed`,
   `attributes_reset`.

2. **CLAMPED Flag Support**: Attributes with `ATTR_FLAGS.CLAMPED` auto-clamp to
   min/max instead of rejecting invalid values. Can also pass `{ clamp = true }`
   option to set() for explicit clamping.

3. **Lua Pattern Gotcha**: The hyphen `-` is a special character in Lua patterns
   (non-greedy modifier). Tests use `%%-` to escape or `string.find(s, pat, 1, true)`
   for plain text search.

### Test Results

```
=== Test Summary ===
Passed: 49
Failed: 0
Total: 49
All tests PASSED!
```

Combined with 016a and 016b: 148 tests total for attribute system.
- test_attributes.lua: 55 tests (registry, schema, container)
- test_getters.lua: 44 tests (computed values, modifiers, derived)
- test_setters.lua: 49 tests (validation, events, transactions)

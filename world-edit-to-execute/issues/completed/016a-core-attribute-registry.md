# Issue 016a: Core Attribute Registry

## Current Behavior

No centralized attribute definition system exists. Stats are defined inline in various modules without schema validation or type constraints.

## Intended Behavior

A registry system that:
- Defines attribute schemas via config blocks
- Assigns numeric indexes for array storage
- Validates types, ranges, and constraints
- Tracks dependencies between attributes
- Provides introspection for tooling

## Suggested Implementation Steps

### 1. Attribute Schema Structure

```lua
-- src/libs/attributes/schema.lua

local ATTR_TYPE = {
    INTEGER = "integer",
    FLOAT = "float",
    PERCENT = "percent",    -- 0.0 to 1.0 or 0 to 100
    BOOLEAN = "boolean",
    ENUM = "enum",
}

local ATTR_FLAGS = {
    PERSISTED = 0x01,       -- Saved to disk
    MODIFIABLE = 0x02,      -- Can have modifiers applied
    DERIVED = 0x04,         -- Computed from other attributes
    HIDDEN = 0x08,          -- Not shown in UI
    READONLY = 0x10,        -- Cannot be set directly
}

-- {{{ AttributeSchema
local AttributeSchema = {}
AttributeSchema.__index = AttributeSchema

function AttributeSchema.new(spec)
    local self = setmetatable({}, AttributeSchema)

    self.id = spec.id                     -- Unique string identifier
    self.index = spec.index               -- Numeric array index
    self.name = spec.name or spec.id      -- Display name
    self.type = spec.type or ATTR_TYPE.INTEGER
    self.min = spec.min                   -- Minimum value (optional)
    self.max = spec.max                   -- Maximum value (optional)
    self.default = spec.default or 0      -- Default value
    self.flags = spec.flags or 0          -- Bitfield of ATTR_FLAGS

    -- Derived attribute support
    self.derived_from = spec.derived_from or {}  -- Dependency list
    self.formula = spec.formula                   -- Calculation function

    -- Enum support
    self.enum_values = spec.enum_values or {}

    -- Validation
    self.validator = spec.validator       -- Custom validation function

    return self
end
-- }}}

-- {{{ validate
function AttributeSchema:validate(value)
    -- Type check
    if self.type == ATTR_TYPE.INTEGER then
        if type(value) ~= "number" or value ~= math.floor(value) then
            return false, "Expected integer"
        end
    elseif self.type == ATTR_TYPE.FLOAT or self.type == ATTR_TYPE.PERCENT then
        if type(value) ~= "number" then
            return false, "Expected number"
        end
    elseif self.type == ATTR_TYPE.BOOLEAN then
        if type(value) ~= "boolean" then
            return false, "Expected boolean"
        end
    elseif self.type == ATTR_TYPE.ENUM then
        local valid = false
        for _, v in ipairs(self.enum_values) do
            if v == value then valid = true; break end
        end
        if not valid then
            return false, "Invalid enum value"
        end
    end

    -- Range check
    if self.min and value < self.min then
        return false, "Below minimum: " .. self.min
    end
    if self.max and value > self.max then
        return false, "Above maximum: " .. self.max
    end

    -- Custom validation
    if self.validator then
        return self.validator(value)
    end

    return true
end
-- }}}

-- {{{ is_derived
function AttributeSchema:is_derived()
    return bit.band(self.flags, ATTR_FLAGS.DERIVED) ~= 0
end
-- }}}

-- {{{ is_modifiable
function AttributeSchema:is_modifiable()
    return bit.band(self.flags, ATTR_FLAGS.MODIFIABLE) ~= 0
end
-- }}}
```

### 2. Attribute Registry

```lua
-- {{{ AttributeRegistry
local AttributeRegistry = {
    schemas = {},           -- id -> AttributeSchema
    by_index = {},          -- index -> AttributeSchema
    next_index = 1,         -- Auto-assign indexes
    dependency_graph = {},  -- id -> { dependent_ids }
}

-- {{{ register
function AttributeRegistry.register(spec)
    -- Auto-assign index if not provided
    if not spec.index then
        spec.index = AttributeRegistry.next_index
        AttributeRegistry.next_index = AttributeRegistry.next_index + 1
    else
        AttributeRegistry.next_index = math.max(
            AttributeRegistry.next_index, spec.index + 1)
    end

    local schema = AttributeSchema.new(spec)

    -- Store in both lookups
    AttributeRegistry.schemas[schema.id] = schema
    AttributeRegistry.by_index[schema.index] = schema

    -- Build dependency graph
    for _, dep_id in ipairs(schema.derived_from) do
        AttributeRegistry.dependency_graph[dep_id] =
            AttributeRegistry.dependency_graph[dep_id] or {}
        table.insert(AttributeRegistry.dependency_graph[dep_id], schema.id)
    end

    return schema
end
-- }}}

-- {{{ get
function AttributeRegistry.get(id_or_index)
    if type(id_or_index) == "number" then
        return AttributeRegistry.by_index[id_or_index]
    else
        return AttributeRegistry.schemas[id_or_index]
    end
end
-- }}}

-- {{{ get_dependents
function AttributeRegistry.get_dependents(id)
    return AttributeRegistry.dependency_graph[id] or {}
end
-- }}}

-- {{{ list
function AttributeRegistry.list(filter)
    local results = {}
    for id, schema in pairs(AttributeRegistry.schemas) do
        local include = true
        if filter then
            if filter.type and schema.type ~= filter.type then
                include = false
            end
            if filter.derived ~= nil then
                if filter.derived ~= schema:is_derived() then
                    include = false
                end
            end
        end
        if include then
            table.insert(results, schema)
        end
    end
    return results
end
-- }}}

-- {{{ create_container
function AttributeRegistry.create_container()
    -- Create a new attribute container with default values
    local container = {
        values = {},
        modifiers = {},
        dirty = {},  -- Derived attributes needing recalculation
    }

    -- Initialize with defaults
    for _, schema in pairs(AttributeRegistry.schemas) do
        container.values[schema.index] = schema.default
    end

    return container
end
-- }}}
-- }}}
```

### 3. Bulk Registration

```lua
-- {{{ register_bulk
function AttributeRegistry.register_bulk(definitions)
    for id, spec in pairs(definitions) do
        spec.id = id
        AttributeRegistry.register(spec)
    end
end
-- }}}

-- Example usage:
AttributeRegistry.register_bulk({
    strength = {
        type = ATTR_TYPE.INTEGER,
        min = 0, max = 999,
        default = 10,
        flags = ATTR_FLAGS.PERSISTED + ATTR_FLAGS.MODIFIABLE,
    },
    agility = {
        type = ATTR_TYPE.INTEGER,
        min = 0, max = 999,
        default = 10,
        flags = ATTR_FLAGS.PERSISTED + ATTR_FLAGS.MODIFIABLE,
    },
    attack_power = {
        type = ATTR_TYPE.INTEGER,
        min = 0,
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "strength", "agility" },
        formula = function(get)
            return get("strength") * 2 + get("agility")
        end,
    },
})
```

## Related Documents

- Issue 016 - Parent issue (Attribute Getter/Setter System)
- Issue 016b - Dispatch table getters
- Issue 016c - Dispatch table setters

## Acceptance Criteria

- [x] AttributeSchema class with type/range validation
- [x] AttributeRegistry with dual lookup (id and index)
- [x] Automatic index assignment
- [x] Dependency graph tracking
- [x] Bulk registration from config blocks
- [x] Container creation with defaults
- [x] Unit tests for validation

---

**Status:** Completed
**Dependencies:** None (first in chain)

---

## Implementation Notes

**Completed 2025-12-31**

### Files Created

1. **src/libs/attributes/schema.lua** (~273 lines)
   - `ATTR_TYPE` constants: INTEGER, FLOAT, PERCENT, BOOLEAN, ENUM
   - `ATTR_FLAGS` bitfield: NONE, PERSISTED, MODIFIABLE, DERIVED, HIDDEN, READONLY, CLAMPED
   - `AttributeSchema` class with:
     - `new(spec)` - constructor from specification table
     - `validate(value)` - type and range validation
     - `clamp(value)` - clamp to min/max range
     - Flag accessors: `is_derived()`, `is_modifiable()`, `is_persisted()`, `is_hidden()`, `is_readonly()`, `is_clamped()`
     - `has_dependencies()` - check if derived from other attributes
     - `__tostring()` - debug representation

2. **src/libs/attributes/registry.lua** (~343 lines)
   - Dual lookup: `schemas` (id → schema), `by_index` (index → schema)
   - Automatic index assignment with collision detection
   - Dependency graph: `dependency_graph` (id → dependents), `reverse_deps` (id → dependencies)
   - Functions:
     - `register(spec)` - register single attribute
     - `register_bulk(definitions)` - register multiple from table
     - `get(id_or_index)` - lookup by id or index
     - `has(id_or_index)` - check if registered
     - `get_index(id)` / `get_id(index)` - conversion helpers
     - `get_dependents(id)` / `get_dependencies(id)` - dependency queries
     - `list(filter)` - filtered listing (by type, derived, modifiable, persisted)
     - `count()` - total registered count
     - `create_container()` - create attribute storage with defaults
     - `reset()` - clear all (for testing)
     - `validate_all_dependencies()` - check for missing dependencies
     - `get_topological_order()` - dependency-ordered list

3. **src/libs/attributes/init.lua** (~71 lines)
   - Module exports combining schema and registry
   - Re-exports: ATTR_TYPE, ATTR_FLAGS, AttributeSchema, all registry functions

4. **src/tests/test_attributes.lua** (~600 lines)
   - 55 comprehensive tests covering all acceptance criteria
   - Tests: schema creation, type validation, range validation, enum support
   - Tests: registry operations, dual lookup, dependency graph
   - Tests: filtering, container creation, topological order

### Compatibility Fix

Updated **src/compat.lua** with pure Lua 5.1/5.2 bitwise fallbacks:
- The system runs Lua 5.2 which lacks both native bitwise operators (5.3+) and the bit library (LuaJIT)
- Added arithmetic-based implementations of `band`, `bor`, `bnot`, `bxor`, `lshift`, `rshift`
- Works for 32-bit unsigned integers

### Test Results

```
=== Test Summary ===
Passed: 55
Failed: 0
Total: 55
All tests PASSED!
```

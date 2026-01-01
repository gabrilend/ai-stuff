#!/usr/bin/env lua
-- test_attributes.lua
-- Tests for the attribute registry system (Issue 016a).
--
-- Tests:
--   - AttributeSchema creation and validation
--   - Registry registration and lookup
--   - Automatic index assignment
--   - Dependency graph tracking
--   - Bulk registration
--   - Container creation

package.path = package.path .. ";src/?.lua;src/?/init.lua"

local attributes = require("libs.attributes")
local ATTR_TYPE = attributes.ATTR_TYPE
local ATTR_FLAGS = attributes.ATTR_FLAGS

-- {{{ Test utilities
local passed = 0
local failed = 0

-- {{{ test
local function test(name, fn)
    -- Reset registry before each test
    attributes.reset()

    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print(string.format("[PASS] %s", name))
    else
        failed = failed + 1
        print(string.format("[FAIL] %s: %s", name, err))
    end
end
-- }}}

-- {{{ assert_eq
local function assert_eq(actual, expected, msg)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s",
            msg or "assertion failed", tostring(expected), tostring(actual)))
    end
end
-- }}}

-- {{{ assert_true
local function assert_true(value, msg)
    if not value then
        error(msg or "expected true, got false")
    end
end
-- }}}

-- {{{ assert_false
local function assert_false(value, msg)
    if value then
        error(msg or "expected false, got true")
    end
end
-- }}}

-- {{{ assert_error
local function assert_error(fn, pattern)
    local ok, err = pcall(fn)
    if ok then
        error("expected error, but function succeeded")
    end
    if pattern and not string.find(tostring(err), pattern) then
        error("expected error matching '" .. pattern .. "', got: " .. tostring(err))
    end
end
-- }}}
-- }}}

-- {{{ AttributeSchema Tests

print("\n=== Testing AttributeSchema ===\n")

test("AttributeSchema: creates with required fields", function()
    local schema = attributes.AttributeSchema.new({
        id = "strength",
    })
    assert_eq(schema.id, "strength", "id")
    assert_eq(schema.type, ATTR_TYPE.INTEGER, "default type")
    assert_eq(schema.default, 0, "default value")
end)

test("AttributeSchema: uses provided values", function()
    local schema = attributes.AttributeSchema.new({
        id = "health",
        name = "Hit Points",
        type = ATTR_TYPE.FLOAT,
        min = 0,
        max = 1000,
        default = 100,
        flags = ATTR_FLAGS.PERSISTED + ATTR_FLAGS.MODIFIABLE,
    })
    assert_eq(schema.id, "health", "id")
    assert_eq(schema.name, "Hit Points", "name")
    assert_eq(schema.type, ATTR_TYPE.FLOAT, "type")
    assert_eq(schema.min, 0, "min")
    assert_eq(schema.max, 1000, "max")
    assert_eq(schema.default, 100, "default")
    assert_true(schema:is_persisted(), "is_persisted")
    assert_true(schema:is_modifiable(), "is_modifiable")
end)

test("AttributeSchema: requires id field", function()
    assert_error(function()
        attributes.AttributeSchema.new({})
    end, "requires 'id'")
end)

test("AttributeSchema: boolean default is false", function()
    local schema = attributes.AttributeSchema.new({
        id = "is_alive",
        type = ATTR_TYPE.BOOLEAN,
    })
    assert_eq(schema.default, false, "boolean default")
end)

test("AttributeSchema: enum default is first value", function()
    local schema = attributes.AttributeSchema.new({
        id = "race",
        type = ATTR_TYPE.ENUM,
        enum_values = { "human", "orc", "elf" },
    })
    assert_eq(schema.default, "human", "enum default")
end)
-- }}}

-- {{{ Validation Tests

print("\n=== Testing Validation ===\n")

test("validate: integer accepts valid integer", function()
    local schema = attributes.AttributeSchema.new({
        id = "strength",
        type = ATTR_TYPE.INTEGER,
    })
    local valid, err = schema:validate(50)
    assert_true(valid, err)
end)

test("validate: integer rejects float", function()
    local schema = attributes.AttributeSchema.new({
        id = "strength",
        type = ATTR_TYPE.INTEGER,
    })
    local valid, err = schema:validate(50.5)
    assert_false(valid, "should reject float")
    assert_true(string.find(err, "integer"), "error should mention integer")
end)

test("validate: integer rejects string", function()
    local schema = attributes.AttributeSchema.new({
        id = "strength",
        type = ATTR_TYPE.INTEGER,
    })
    local valid, err = schema:validate("50")
    assert_false(valid, "should reject string")
end)

test("validate: float accepts decimal", function()
    local schema = attributes.AttributeSchema.new({
        id = "speed",
        type = ATTR_TYPE.FLOAT,
    })
    local valid, err = schema:validate(1.5)
    assert_true(valid, err)
end)

test("validate: float accepts integer", function()
    local schema = attributes.AttributeSchema.new({
        id = "speed",
        type = ATTR_TYPE.FLOAT,
    })
    local valid, err = schema:validate(100)
    assert_true(valid, err)
end)

test("validate: boolean accepts true/false", function()
    local schema = attributes.AttributeSchema.new({
        id = "is_alive",
        type = ATTR_TYPE.BOOLEAN,
    })
    local valid1, err1 = schema:validate(true)
    local valid2, err2 = schema:validate(false)
    assert_true(valid1, err1)
    assert_true(valid2, err2)
end)

test("validate: boolean rejects number", function()
    local schema = attributes.AttributeSchema.new({
        id = "is_alive",
        type = ATTR_TYPE.BOOLEAN,
    })
    local valid, err = schema:validate(1)
    assert_false(valid, "should reject number")
end)

test("validate: enum accepts valid value", function()
    local schema = attributes.AttributeSchema.new({
        id = "race",
        type = ATTR_TYPE.ENUM,
        enum_values = { "human", "orc", "elf" },
    })
    local valid, err = schema:validate("orc")
    assert_true(valid, err)
end)

test("validate: enum rejects invalid value", function()
    local schema = attributes.AttributeSchema.new({
        id = "race",
        type = ATTR_TYPE.ENUM,
        enum_values = { "human", "orc", "elf" },
    })
    local valid, err = schema:validate("dwarf")
    assert_false(valid, "should reject invalid enum")
    assert_true(string.find(err, "Invalid enum"), "error should mention enum")
end)

test("validate: checks minimum", function()
    local schema = attributes.AttributeSchema.new({
        id = "health",
        type = ATTR_TYPE.INTEGER,
        min = 0,
    })
    local valid1, err1 = schema:validate(0)
    local valid2, err2 = schema:validate(-1)
    assert_true(valid1, err1)
    assert_false(valid2, "should reject below minimum")
end)

test("validate: checks maximum", function()
    local schema = attributes.AttributeSchema.new({
        id = "health",
        type = ATTR_TYPE.INTEGER,
        max = 100,
    })
    local valid1, err1 = schema:validate(100)
    local valid2, err2 = schema:validate(101)
    assert_true(valid1, err1)
    assert_false(valid2, "should reject above maximum")
end)

test("validate: custom validator", function()
    local schema = attributes.AttributeSchema.new({
        id = "even_number",
        type = ATTR_TYPE.INTEGER,
        validator = function(value)
            if value % 2 == 0 then
                return true
            else
                return false, "Must be even"
            end
        end,
    })
    local valid1, err1 = schema:validate(4)
    local valid2, err2 = schema:validate(5)
    assert_true(valid1, err1)
    assert_false(valid2, "should reject odd number")
    assert_true(string.find(err2, "even"), "error should mention even")
end)
-- }}}

-- {{{ Clamp Tests

print("\n=== Testing Clamp ===\n")

test("clamp: clamps to minimum", function()
    local schema = attributes.AttributeSchema.new({
        id = "health",
        type = ATTR_TYPE.INTEGER,
        min = 0,
        max = 100,
    })
    assert_eq(schema:clamp(-50), 0, "should clamp to min")
end)

test("clamp: clamps to maximum", function()
    local schema = attributes.AttributeSchema.new({
        id = "health",
        type = ATTR_TYPE.INTEGER,
        min = 0,
        max = 100,
    })
    assert_eq(schema:clamp(150), 100, "should clamp to max")
end)

test("clamp: leaves valid value unchanged", function()
    local schema = attributes.AttributeSchema.new({
        id = "health",
        type = ATTR_TYPE.INTEGER,
        min = 0,
        max = 100,
    })
    assert_eq(schema:clamp(50), 50, "should leave unchanged")
end)

test("clamp: ignores boolean", function()
    local schema = attributes.AttributeSchema.new({
        id = "flag",
        type = ATTR_TYPE.BOOLEAN,
    })
    assert_eq(schema:clamp(true), true, "should return boolean unchanged")
end)
-- }}}

-- {{{ Flag Accessor Tests

print("\n=== Testing Flag Accessors ===\n")

test("flags: is_derived", function()
    local schema = attributes.AttributeSchema.new({
        id = "attack_power",
        flags = ATTR_FLAGS.DERIVED,
    })
    assert_true(schema:is_derived(), "should be derived")
    assert_false(schema:is_modifiable(), "should not be modifiable")
end)

test("flags: is_modifiable", function()
    local schema = attributes.AttributeSchema.new({
        id = "strength",
        flags = ATTR_FLAGS.MODIFIABLE,
    })
    assert_true(schema:is_modifiable(), "should be modifiable")
    assert_false(schema:is_derived(), "should not be derived")
end)

test("flags: combined flags", function()
    local schema = attributes.AttributeSchema.new({
        id = "health",
        flags = ATTR_FLAGS.PERSISTED + ATTR_FLAGS.MODIFIABLE + ATTR_FLAGS.CLAMPED,
    })
    assert_true(schema:is_persisted(), "should be persisted")
    assert_true(schema:is_modifiable(), "should be modifiable")
    assert_true(schema:is_clamped(), "should be clamped")
    assert_false(schema:is_derived(), "should not be derived")
    assert_false(schema:is_hidden(), "should not be hidden")
end)
-- }}}

-- {{{ Registry Tests

print("\n=== Testing Registry ===\n")

test("register: basic registration", function()
    local schema = attributes.register({
        id = "strength",
        type = ATTR_TYPE.INTEGER,
    })
    assert_eq(schema.id, "strength", "id")
    assert_eq(schema.index, 1, "auto-assigned index")
end)

test("register: auto-increments index", function()
    attributes.register({ id = "strength" })
    attributes.register({ id = "agility" })
    attributes.register({ id = "intellect" })

    assert_eq(attributes.get_index("strength"), 1, "first index")
    assert_eq(attributes.get_index("agility"), 2, "second index")
    assert_eq(attributes.get_index("intellect"), 3, "third index")
end)

test("register: respects provided index", function()
    attributes.register({ id = "strength", index = 10 })
    attributes.register({ id = "agility" })  -- Should get 11

    assert_eq(attributes.get_index("strength"), 10, "provided index")
    assert_eq(attributes.get_index("agility"), 11, "next after provided")
end)

test("register: rejects duplicate id", function()
    attributes.register({ id = "strength" })
    assert_error(function()
        attributes.register({ id = "strength" })
    end, "already registered")
end)

test("register: rejects duplicate index", function()
    attributes.register({ id = "strength", index = 5 })
    assert_error(function()
        attributes.register({ id = "agility", index = 5 })
    end, "already used")
end)

test("get: by id", function()
    attributes.register({ id = "strength", default = 10 })
    local schema = attributes.get("strength")
    assert_eq(schema.id, "strength", "id")
    assert_eq(schema.default, 10, "default")
end)

test("get: by index", function()
    attributes.register({ id = "strength", default = 10 })
    local schema = attributes.get(1)
    assert_eq(schema.id, "strength", "id")
    assert_eq(schema.default, 10, "default")
end)

test("get: returns nil for unknown", function()
    local schema = attributes.get("unknown")
    assert_eq(schema, nil, "should be nil")
end)

test("has: returns true for registered", function()
    attributes.register({ id = "strength" })
    assert_true(attributes.has("strength"), "should have by id")
    assert_true(attributes.has(1), "should have by index")
end)

test("has: returns false for unregistered", function()
    assert_false(attributes.has("unknown"), "should not have unknown")
    assert_false(attributes.has(999), "should not have unknown index")
end)

test("get_index: returns index for id", function()
    attributes.register({ id = "strength", index = 5 })
    assert_eq(attributes.get_index("strength"), 5, "index")
end)

test("get_id: returns id for index", function()
    attributes.register({ id = "strength", index = 5 })
    assert_eq(attributes.get_id(5), "strength", "id")
end)

test("count: returns number of registered", function()
    assert_eq(attributes.count(), 0, "initially zero")
    attributes.register({ id = "strength" })
    attributes.register({ id = "agility" })
    assert_eq(attributes.count(), 2, "after registration")
end)
-- }}}

-- {{{ Bulk Registration Tests

print("\n=== Testing Bulk Registration ===\n")

test("register_bulk: registers multiple attributes", function()
    local count = attributes.register_bulk({
        strength = { type = ATTR_TYPE.INTEGER, default = 10 },
        agility = { type = ATTR_TYPE.INTEGER, default = 10 },
        intellect = { type = ATTR_TYPE.INTEGER, default = 10 },
    })
    assert_eq(count, 3, "should register 3")
    assert_eq(attributes.count(), 3, "total count")
    assert_true(attributes.has("strength"), "has strength")
    assert_true(attributes.has("agility"), "has agility")
    assert_true(attributes.has("intellect"), "has intellect")
end)

test("register_bulk: preserves spec values", function()
    attributes.register_bulk({
        health = { type = ATTR_TYPE.FLOAT, min = 0, max = 1000, default = 100 },
    })
    local schema = attributes.get("health")
    assert_eq(schema.type, ATTR_TYPE.FLOAT, "type")
    assert_eq(schema.min, 0, "min")
    assert_eq(schema.max, 1000, "max")
    assert_eq(schema.default, 100, "default")
end)
-- }}}

-- {{{ Dependency Graph Tests

print("\n=== Testing Dependency Graph ===\n")

test("dependencies: tracks derived_from", function()
    attributes.register_bulk({
        strength = { type = ATTR_TYPE.INTEGER },
        agility = { type = ATTR_TYPE.INTEGER },
        attack_power = {
            type = ATTR_TYPE.INTEGER,
            flags = ATTR_FLAGS.DERIVED,
            derived_from = { "strength", "agility" },
        },
    })

    local str_deps = attributes.get_dependents("strength")
    local agi_deps = attributes.get_dependents("agility")
    local ap_deps = attributes.get_dependencies("attack_power")

    assert_eq(#str_deps, 1, "strength has 1 dependent")
    assert_eq(str_deps[1], "attack_power", "dependent is attack_power")
    assert_eq(#agi_deps, 1, "agility has 1 dependent")
    assert_eq(#ap_deps, 2, "attack_power has 2 dependencies")
end)

test("dependencies: no dependencies for simple attributes", function()
    attributes.register({ id = "strength" })
    local deps = attributes.get_dependents("strength")
    assert_eq(#deps, 0, "no dependents")
end)

test("dependencies: validate_all_dependencies passes for valid", function()
    attributes.register_bulk({
        strength = {},
        attack_power = { derived_from = { "strength" } },
    })
    local valid, err = attributes.validate_all_dependencies()
    assert_true(valid, err)
end)

test("dependencies: validate_all_dependencies fails for missing", function()
    attributes.register({
        id = "attack_power",
        derived_from = { "strength" },  -- strength not registered
    })
    local valid, err = attributes.validate_all_dependencies()
    assert_false(valid, "should fail")
    assert_true(string.find(err, "unregistered"), "error mentions unregistered")
end)

test("dependencies: topological order", function()
    attributes.register_bulk({
        attack_power = { derived_from = { "strength", "agility" } },
        strength = {},
        agility = {},
        damage = { derived_from = { "attack_power" } },
    })

    local order = attributes.get_topological_order()
    assert_eq(#order, 4, "all 4 attributes")

    -- Find positions
    local pos = {}
    for i, id in ipairs(order) do
        pos[id] = i
    end

    -- Check ordering: dependencies come before dependents
    assert_true(pos["strength"] < pos["attack_power"], "strength before attack_power")
    assert_true(pos["agility"] < pos["attack_power"], "agility before attack_power")
    assert_true(pos["attack_power"] < pos["damage"], "attack_power before damage")
end)
-- }}}

-- {{{ Container Tests

print("\n=== Testing Container ===\n")

test("create_container: has default values", function()
    attributes.register_bulk({
        strength = { default = 10 },
        agility = { default = 15 },
        health = { default = 100 },
    })

    local container = attributes.create_container()
    local str_idx = attributes.get_index("strength")
    local agi_idx = attributes.get_index("agility")
    local hp_idx = attributes.get_index("health")

    assert_eq(container.values[str_idx], 10, "strength default")
    assert_eq(container.values[agi_idx], 15, "agility default")
    assert_eq(container.values[hp_idx], 100, "health default")
end)

test("create_container: marks derived as dirty", function()
    attributes.register_bulk({
        strength = {},
        attack_power = { flags = ATTR_FLAGS.DERIVED, derived_from = { "strength" } },
    })

    local container = attributes.create_container()
    local str_idx = attributes.get_index("strength")
    local ap_idx = attributes.get_index("attack_power")

    assert_false(container.dirty[str_idx], "strength not dirty")
    assert_true(container.dirty[ap_idx], "attack_power is dirty")
end)

test("create_container: has empty modifiers table", function()
    attributes.register({ id = "strength" })
    local container = attributes.create_container()
    assert_eq(type(container.modifiers), "table", "modifiers is table")
    assert_eq(next(container.modifiers), nil, "modifiers is empty")
end)

test("create_container: independent instances", function()
    attributes.register({ id = "strength", default = 10 })
    local c1 = attributes.create_container()
    local c2 = attributes.create_container()

    local idx = attributes.get_index("strength")
    c1.values[idx] = 50

    assert_eq(c1.values[idx], 50, "c1 modified")
    assert_eq(c2.values[idx], 10, "c2 unchanged")
end)
-- }}}

-- {{{ List/Filter Tests

print("\n=== Testing List/Filter ===\n")

test("list: returns all without filter", function()
    attributes.register_bulk({
        strength = {},
        agility = {},
        intellect = {},
    })

    local all = attributes.list()
    assert_eq(#all, 3, "returns all 3")
end)

test("list: filters by type", function()
    attributes.register_bulk({
        health = { type = ATTR_TYPE.INTEGER },
        speed = { type = ATTR_TYPE.FLOAT },
        is_alive = { type = ATTR_TYPE.BOOLEAN },
    })

    local integers = attributes.list({ type = ATTR_TYPE.INTEGER })
    local floats = attributes.list({ type = ATTR_TYPE.FLOAT })
    local booleans = attributes.list({ type = ATTR_TYPE.BOOLEAN })

    assert_eq(#integers, 1, "1 integer")
    assert_eq(#floats, 1, "1 float")
    assert_eq(#booleans, 1, "1 boolean")
end)

test("list: filters by derived", function()
    attributes.register_bulk({
        strength = {},
        agility = {},
        attack_power = { flags = ATTR_FLAGS.DERIVED, derived_from = { "strength" } },
    })

    local derived = attributes.list({ derived = true })
    local base = attributes.list({ derived = false })

    assert_eq(#derived, 1, "1 derived")
    assert_eq(derived[1].id, "attack_power", "derived is attack_power")
    assert_eq(#base, 2, "2 base")
end)

test("list: filters by modifiable", function()
    attributes.register_bulk({
        strength = { flags = ATTR_FLAGS.MODIFIABLE },
        agility = { flags = ATTR_FLAGS.MODIFIABLE },
        attack_power = { flags = ATTR_FLAGS.DERIVED },  -- Not modifiable
    })

    local modifiable = attributes.list({ modifiable = true })
    local not_modifiable = attributes.list({ modifiable = false })

    assert_eq(#modifiable, 2, "2 modifiable")
    assert_eq(#not_modifiable, 1, "1 not modifiable")
end)
-- }}}

-- {{{ Reset Tests

print("\n=== Testing Reset ===\n")

test("reset: clears all registrations", function()
    attributes.register_bulk({
        strength = {},
        agility = {},
    })
    assert_eq(attributes.count(), 2, "before reset")

    attributes.reset()
    assert_eq(attributes.count(), 0, "after reset")
    assert_false(attributes.has("strength"), "strength gone")
end)

test("reset: resets index counter", function()
    attributes.register({ id = "strength" })
    assert_eq(attributes.get_index("strength"), 1, "first registration")

    attributes.reset()
    attributes.register({ id = "agility" })
    assert_eq(attributes.get_index("agility"), 1, "reset to 1")
end)
-- }}}

-- {{{ __tostring Tests

print("\n=== Testing __tostring ===\n")

test("__tostring: includes key info", function()
    local schema = attributes.register({
        id = "strength",
        index = 5,
        type = ATTR_TYPE.INTEGER,
        flags = ATTR_FLAGS.MODIFIABLE + ATTR_FLAGS.PERSISTED,
    })
    local str = tostring(schema)
    assert_true(string.find(str, "strength"), "includes id")
    assert_true(string.find(str, "5"), "includes index")
    assert_true(string.find(str, "integer"), "includes type")
end)
-- }}}

-- {{{ Summary
print("\n=== Test Summary ===\n")
print(string.format("Passed: %d", passed))
print(string.format("Failed: %d", failed))
print(string.format("Total: %d", passed + failed))

if failed > 0 then
    print("\nSome tests FAILED!")
    os.exit(1)
else
    print("\nAll tests PASSED!")
    os.exit(0)
end
-- }}}

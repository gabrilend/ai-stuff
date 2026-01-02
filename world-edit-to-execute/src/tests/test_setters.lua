#!/usr/bin/env lua
-- Attribute Setters Unit Tests (Issue 016c)
-- Tests for dispatch table setters with validation, events, and transactions.
-- Run with: lua src/tests/test_setters.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local schema_module = require("libs.attributes.schema")
local registry = require("libs.attributes.registry")
local getters = require("libs.attributes.getters")
local setters = require("libs.attributes.setters")

local ATTR_TYPE = schema_module.ATTR_TYPE
local ATTR_FLAGS = schema_module.ATTR_FLAGS

-- {{{ Test utilities
local test_count = 0
local pass_count = 0

local function test(name, fn)
    test_count = test_count + 1
    local ok, err = pcall(fn)
    if ok then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name)
        print("         " .. tostring(err))
    end
end

local function assert_eq(actual, expected, msg)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s",
            msg or "Assertion failed",
            tostring(expected),
            tostring(actual)))
    end
end

local function assert_true(value, msg)
    if not value then
        error(msg or "Expected true")
    end
end

local function assert_false(value, msg)
    if value then
        error(msg or "Expected false")
    end
end

local function assert_nil(value, msg)
    if value ~= nil then
        error(string.format("%s: expected nil, got %s",
            msg or "Assertion failed", tostring(value)))
    end
end

local function assert_not_nil(value, msg)
    if value == nil then
        error(msg or "Expected non-nil")
    end
end

local function test_section(name)
    print("\n=== " .. name .. " ===")
end

local function reset_all()
    registry.reset()
    setters.clear_listeners()
    setters.rebuild()
    getters.rebuild()
end
-- }}}

-- {{{ Setup test attributes
local function setup_test_attributes()
    reset_all()

    -- Basic attributes
    registry.register({
        id = "strength",
        type = ATTR_TYPE.INTEGER,
        min = 1,
        max = 100,
        default = 10,
        flags = ATTR_FLAGS.MODIFIABLE,
    })

    registry.register({
        id = "agility",
        type = ATTR_TYPE.INTEGER,
        min = 1,
        max = 100,
        default = 10,
        flags = ATTR_FLAGS.MODIFIABLE,
    })

    registry.register({
        id = "health",
        type = ATTR_TYPE.INTEGER,
        min = 0,
        max = 999,
        default = 100,
        flags = ATTR_FLAGS.MODIFIABLE + ATTR_FLAGS.CLAMPED,
    })

    -- Derived attribute
    registry.register({
        id = "attack_power",
        type = ATTR_TYPE.INTEGER,
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "strength", "agility" },
        formula = function(get)
            return get("strength") * 2 + get("agility")
        end,
    })

    -- Readonly attribute
    registry.register({
        id = "level",
        type = ATTR_TYPE.INTEGER,
        min = 1,
        max = 60,
        default = 1,
        flags = ATTR_FLAGS.READONLY,
    })

    -- Float attribute
    registry.register({
        id = "crit_chance",
        type = ATTR_TYPE.FLOAT,
        min = 0.0,
        max = 1.0,
        default = 0.05,
        flags = ATTR_FLAGS.MODIFIABLE,
    })

    -- Boolean attribute
    registry.register({
        id = "is_elite",
        type = ATTR_TYPE.BOOLEAN,
        default = false,
        flags = ATTR_FLAGS.NONE,
    })

    -- Enum attribute
    registry.register({
        id = "class",
        type = ATTR_TYPE.ENUM,
        enum_values = { "warrior", "mage", "rogue" },
        default = "warrior",
        flags = ATTR_FLAGS.NONE,
    })

    -- Rebuild dispatch tables
    setters.rebuild()
    getters.rebuild()
end
-- }}}

-- {{{ Basic Set Tests
test_section("Basic Set Operations")

test("set() modifies attribute value", function()
    setup_test_attributes()
    local container = registry.create_container()

    local ok = setters.set(container, "strength", 25)
    assert_true(ok)
    assert_eq(getters.get_raw(container, "strength"), 25)
end)

test("set() returns true on no change", function()
    setup_test_attributes()
    local container = registry.create_container()

    setters.set(container, "strength", 25)
    local ok = setters.set(container, "strength", 25)
    assert_true(ok)
end)

test("set() by index works", function()
    setup_test_attributes()
    local container = registry.create_container()
    local index = registry.get_index("strength")

    local ok = setters.set(container, index, 30)
    assert_true(ok)
    assert_eq(getters.get_raw(container, "strength"), 30)
end)

test("set() returns error for unknown attribute", function()
    setup_test_attributes()
    local container = registry.create_container()

    local ok, err = setters.set(container, "unknown", 10)
    assert_false(ok)
    assert_true(err:find("Unknown attribute"), "Expected 'Unknown attribute' in error")
end)
-- }}}

-- {{{ Validation Tests
test_section("Validation")

test("set() rejects value below minimum", function()
    setup_test_attributes()
    local container = registry.create_container()

    local ok, err = setters.set(container, "strength", 0)
    assert_false(ok)
    assert_true(err:find("Below minimum"), "Expected 'Below minimum' in error")
    assert_eq(getters.get_raw(container, "strength"), 10)  -- Unchanged
end)

test("set() rejects value above maximum", function()
    setup_test_attributes()
    local container = registry.create_container()

    local ok, err = setters.set(container, "strength", 150)
    assert_false(ok)
    assert_true(err:find("Above maximum"), "Expected 'Above maximum' in error")
    assert_eq(getters.get_raw(container, "strength"), 10)  -- Unchanged
end)

test("set() with clamp option clamps value", function()
    setup_test_attributes()
    local container = registry.create_container()

    local ok = setters.set(container, "strength", 150, { clamp = true })
    assert_true(ok)
    assert_eq(getters.get_raw(container, "strength"), 100)  -- Clamped to max
end)

test("set() with clamp option clamps to minimum", function()
    setup_test_attributes()
    local container = registry.create_container()

    local ok = setters.set(container, "strength", -50, { clamp = true })
    assert_true(ok)
    assert_eq(getters.get_raw(container, "strength"), 1)  -- Clamped to min
end)

test("CLAMPED flag auto-clamps values", function()
    setup_test_attributes()
    local container = registry.create_container()

    -- health has CLAMPED flag
    local ok = setters.set(container, "health", 9999)
    assert_true(ok)
    assert_eq(getters.get_raw(container, "health"), 999)  -- Auto-clamped
end)

test("set() validates integer type", function()
    setup_test_attributes()
    local container = registry.create_container()

    local ok, err = setters.set(container, "strength", 25.5)
    assert_false(ok)
    assert_true(err:find("integer"), "Expected integer error")
end)

test("set() validates float type", function()
    setup_test_attributes()
    local container = registry.create_container()

    local ok = setters.set(container, "crit_chance", 0.25)
    assert_true(ok)
    assert_eq(getters.get_raw(container, "crit_chance"), 0.25)
end)

test("set() validates boolean type", function()
    setup_test_attributes()
    local container = registry.create_container()

    local ok = setters.set(container, "is_elite", true)
    assert_true(ok)
    assert_eq(getters.get_raw(container, "is_elite"), true)
end)

test("set() validates enum values", function()
    setup_test_attributes()
    local container = registry.create_container()

    local ok = setters.set(container, "class", "mage")
    assert_true(ok)
    assert_eq(getters.get_raw(container, "class"), "mage")
end)

test("set() rejects invalid enum values", function()
    setup_test_attributes()
    local container = registry.create_container()

    local ok, err = setters.set(container, "class", "paladin")
    assert_false(ok)
    assert_true(err:find("Invalid enum"), "Expected enum error")
end)
-- }}}

-- {{{ Protection Tests
test_section("Attribute Protection")

test("set() rejects derived attributes", function()
    setup_test_attributes()
    local container = registry.create_container()

    local ok, err = setters.set(container, "attack_power", 50)
    assert_false(ok)
    assert_true(err:find("derived"), "Expected 'derived' in error")
end)

test("set() rejects readonly attributes", function()
    setup_test_attributes()
    local container = registry.create_container()

    local ok, err = setters.set(container, "level", 10)
    assert_false(ok)
    assert_true(err:find("readonly"), "Expected 'readonly' in error")
end)
-- }}}

-- {{{ Dependent Invalidation Tests
test_section("Dependent Invalidation")

test("set() invalidates derived dependents", function()
    setup_test_attributes()
    local container = registry.create_container()

    -- Initially computed
    local initial = getters.get(container, "attack_power")
    assert_eq(initial, 10 * 2 + 10)  -- 30

    -- Change strength
    setters.set(container, "strength", 20)

    -- Derived should update
    local updated = getters.get(container, "attack_power")
    assert_eq(updated, 20 * 2 + 10)  -- 50
end)

test("set() invalidates multiple dependents", function()
    setup_test_attributes()
    local container = registry.create_container()

    setters.set(container, "strength", 25)
    setters.set(container, "agility", 15)

    local result = getters.get(container, "attack_power")
    assert_eq(result, 25 * 2 + 15)  -- 65
end)
-- }}}

-- {{{ Event Tests
test_section("Event System")

test("set() fires attribute_changed event", function()
    setup_test_attributes()
    local container = registry.create_container()

    local event_fired = false
    local event_data = nil
    setters.on("attribute_changed", function(data)
        event_fired = true
        event_data = data
    end)

    setters.set(container, "strength", 25)

    assert_true(event_fired, "Event should fire")
    assert_eq(event_data.attribute, "strength")
    assert_eq(event_data.old_value, 10)
    assert_eq(event_data.new_value, 25)
end)

test("set() with silent option suppresses event", function()
    setup_test_attributes()
    local container = registry.create_container()

    local event_fired = false
    setters.on("attribute_changed", function()
        event_fired = true
    end)

    setters.set(container, "strength", 25, { silent = true })

    assert_false(event_fired, "Event should not fire with silent option")
end)

test("event includes source when provided", function()
    setup_test_attributes()
    local container = registry.create_container()

    local event_source = nil
    setters.on("attribute_changed", function(data)
        event_source = data.source
    end)

    setters.set(container, "strength", 25, { source = "item:belt_of_strength" })

    assert_eq(event_source, "item:belt_of_strength")
end)

test("no event on no change", function()
    setup_test_attributes()
    local container = registry.create_container()

    setters.set(container, "strength", 25)

    local event_count = 0
    setters.on("attribute_changed", function()
        event_count = event_count + 1
    end)

    -- Set to same value
    setters.set(container, "strength", 25)

    assert_eq(event_count, 0, "No event when value unchanged")
end)

test("off() removes listener", function()
    setup_test_attributes()
    local container = registry.create_container()

    local count = 0
    local listener = function() count = count + 1 end
    setters.on("attribute_changed", listener)

    setters.set(container, "strength", 25)
    assert_eq(count, 1)

    setters.off("attribute_changed", listener)
    setters.set(container, "strength", 30)
    assert_eq(count, 1, "Listener should be removed")
end)

test("clear_listeners() removes all listeners", function()
    setup_test_attributes()
    local container = registry.create_container()

    local count = 0
    setters.on("attribute_changed", function() count = count + 1 end)
    setters.on("attribute_changed", function() count = count + 1 end)

    setters.clear_listeners()
    setters.set(container, "strength", 25)

    assert_eq(count, 0, "All listeners should be removed")
end)
-- }}}

-- {{{ set_raw Tests
test_section("set_raw")

test("set_raw() bypasses validation", function()
    setup_test_attributes()
    local container = registry.create_container()

    local ok = setters.set_raw(container, "strength", 9999)
    assert_true(ok)
    assert_eq(getters.get_raw(container, "strength"), 9999)
end)

test("set_raw() still invalidates dependents", function()
    setup_test_attributes()
    local container = registry.create_container()

    setters.set_raw(container, "strength", 50)
    local result = getters.get(container, "attack_power")
    assert_eq(result, 50 * 2 + 10)  -- 110
end)
-- }}}

-- {{{ set_many Tests
test_section("Batch Operations")

test("set_many() updates multiple attributes", function()
    setup_test_attributes()
    local container = registry.create_container()

    local results = setters.set_many(container, {
        strength = 25,
        agility = 20,
    })

    assert_true(results.strength.ok)
    assert_true(results.agility.ok)
    assert_eq(getters.get_raw(container, "strength"), 25)
    assert_eq(getters.get_raw(container, "agility"), 20)
end)

test("set_many() fires single batch event", function()
    setup_test_attributes()
    local container = registry.create_container()

    local single_events = 0
    local batch_events = 0
    setters.on("attribute_changed", function() single_events = single_events + 1 end)
    setters.on("attributes_changed", function() batch_events = batch_events + 1 end)

    setters.set_many(container, {
        strength = 25,
        agility = 20,
    })

    assert_eq(single_events, 0, "Individual events should be suppressed")
    assert_eq(batch_events, 1, "Single batch event should fire")
end)

test("set_many() batch event contains all changes", function()
    setup_test_attributes()
    local container = registry.create_container()

    local changes = nil
    setters.on("attributes_changed", function(data)
        changes = data.changes
    end)

    setters.set_many(container, {
        strength = 25,
        agility = 20,
    })

    assert_eq(#changes, 2)
end)

test("set_many() reports failures per attribute", function()
    setup_test_attributes()
    local container = registry.create_container()

    local results = setters.set_many(container, {
        strength = 150,  -- Out of range
        agility = 20,    -- Valid
    })

    assert_false(results.strength.ok)
    assert_true(results.agility.ok)
end)
-- }}}

-- {{{ adjust Tests
test_section("Adjust Operations")

test("adjust() adds to value", function()
    setup_test_attributes()
    local container = registry.create_container()

    setters.set(container, "health", 100)
    setters.adjust(container, "health", 50)

    assert_eq(getters.get_raw(container, "health"), 150)
end)

test("adjust() subtracts from value", function()
    setup_test_attributes()
    local container = registry.create_container()

    setters.set(container, "health", 100)
    setters.adjust(container, "health", -30)

    assert_eq(getters.get_raw(container, "health"), 70)
end)

test("adjust() respects validation", function()
    setup_test_attributes()
    local container = registry.create_container()

    -- health has CLAMPED flag, so it will auto-clamp
    setters.set(container, "health", 100)
    setters.adjust(container, "health", 1000)

    assert_eq(getters.get_raw(container, "health"), 999)  -- Clamped to max
end)

test("adjust() returns error for non-numeric", function()
    setup_test_attributes()
    local container = registry.create_container()

    local ok, err = setters.adjust(container, "is_elite", 1)
    assert_false(ok)
    assert_true(err:find("non%-numeric"), "Expected non-numeric error")
end)
-- }}}

-- {{{ reset Tests
test_section("Reset Operations")

test("reset() restores default value", function()
    setup_test_attributes()
    local container = registry.create_container()

    setters.set(container, "strength", 50)
    setters.reset(container, "strength")

    assert_eq(getters.get_raw(container, "strength"), 10)  -- Default
end)

test("reset_all() restores all defaults", function()
    setup_test_attributes()
    local container = registry.create_container()

    setters.set(container, "strength", 50)
    setters.set(container, "agility", 40)
    setters.reset_all(container)

    assert_eq(getters.get_raw(container, "strength"), 10)
    assert_eq(getters.get_raw(container, "agility"), 10)
end)

test("reset_all() clears modifiers", function()
    setup_test_attributes()
    local container = registry.create_container()

    container.modifiers["strength"] = {
        { type = "flat", value = 10, source = "test" }
    }

    setters.reset_all(container)

    assert_eq(#(container.modifiers["strength"] or {}), 0)
end)

test("reset_all() fires event", function()
    setup_test_attributes()
    local container = registry.create_container()

    local event_fired = false
    setters.on("attributes_reset", function()
        event_fired = true
    end)

    setters.reset_all(container)

    assert_true(event_fired)
end)
-- }}}

-- {{{ Transaction Tests
test_section("Transactions")

test("transaction queues changes", function()
    setup_test_attributes()
    local container = registry.create_container()

    local txn = setters.begin_transaction(container)
    txn:set("strength", 25)
    txn:set("agility", 20)

    -- Not yet applied
    assert_eq(getters.get_raw(container, "strength"), 10)
    assert_eq(getters.get_raw(container, "agility"), 10)
end)

test("transaction commit applies changes", function()
    setup_test_attributes()
    local container = registry.create_container()

    local txn = setters.begin_transaction(container)
    txn:set("strength", 25)
    txn:set("agility", 20)
    txn:commit()

    assert_eq(getters.get_raw(container, "strength"), 25)
    assert_eq(getters.get_raw(container, "agility"), 20)
end)

test("transaction rollback restores values", function()
    setup_test_attributes()
    local container = registry.create_container()

    setters.set(container, "strength", 15)

    local txn = setters.begin_transaction(container)
    txn:set("strength", 25)
    txn:commit()

    -- Values are now changed
    assert_eq(getters.get_raw(container, "strength"), 25)

    -- Start a new transaction and rollback before commit
    local txn2 = setters.begin_transaction(container)
    txn2:set("strength", 99)
    txn2:rollback()

    -- Rollback restores to snapshot (25, not 99)
    assert_eq(getters.get_raw(container, "strength"), 25)
end)

test("transaction get_pending returns queued value", function()
    setup_test_attributes()
    local container = registry.create_container()

    local txn = setters.begin_transaction(container)
    txn:set("strength", 25)

    assert_eq(txn:get_pending("strength"), 25)
    assert_nil(txn:get_pending("agility"))
end)

test("commit returns results", function()
    setup_test_attributes()
    local container = registry.create_container()

    local txn = setters.begin_transaction(container)
    txn:set("strength", 25)
    txn:set("level", 10)  -- Readonly, will fail

    local results = txn:commit()

    assert_true(results.strength.ok)
    assert_false(results.level.ok)
end)
-- }}}

-- {{{ has/get_setter Tests
test_section("Utility Functions")

test("has() returns true for valid attribute", function()
    setup_test_attributes()
    assert_true(setters.has("strength"))
end)

test("has() returns false for unknown attribute", function()
    setup_test_attributes()
    assert_false(setters.has("unknown"))
end)

test("get_setter() returns function", function()
    setup_test_attributes()
    local setter = setters.get_setter("strength")
    assert_eq(type(setter), "function")
end)

test("get_setter() returns nil for unknown", function()
    setup_test_attributes()
    local setter = setters.get_setter("unknown")
    assert_nil(setter)
end)

test("direct setter call works", function()
    setup_test_attributes()
    local container = registry.create_container()

    local setter = setters.get_setter("strength")
    local ok = setter(container, 25)

    assert_true(ok)
    assert_eq(getters.get_raw(container, "strength"), 25)
end)
-- }}}

-- {{{ rebuild Tests
test_section("Rebuild")

test("rebuild() picks up new attributes", function()
    setup_test_attributes()

    -- Register new attribute after initial build
    registry.register({
        id = "stamina",
        type = ATTR_TYPE.INTEGER,
        min = 1,
        max = 100,
        default = 10,
    })

    -- Before rebuild, setter doesn't exist
    assert_false(setters.has("stamina"))

    setters.rebuild()

    -- After rebuild, setter exists
    assert_true(setters.has("stamina"))

    local container = registry.create_container()
    local ok = setters.set(container, "stamina", 25)
    assert_true(ok)
end)
-- }}}

-- {{{ Test Summary
print("\n=== Test Summary ===")
print(string.format("Passed: %d", pass_count))
print(string.format("Failed: %d", test_count - pass_count))
print(string.format("Total: %d", test_count))

if pass_count == test_count then
    print("All tests PASSED!")
    os.exit(0)
else
    print("Some tests FAILED!")
    os.exit(1)
end
-- }}}

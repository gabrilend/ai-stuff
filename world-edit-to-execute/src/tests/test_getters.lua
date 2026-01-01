#!/usr/bin/env lua
-- Test suite for attribute getters module (Issue 016b)
-- Tests dispatch table getters, modifier application, derived attributes

package.path = package.path .. ";src/?.lua;src/?/init.lua"

local registry = require("libs.attributes.registry")
local getters = require("libs.attributes.getters")
local schema_module = require("libs.attributes.schema")
local ATTR_FLAGS = schema_module.ATTR_FLAGS

-- {{{ Test framework
local tests_run = 0
local tests_passed = 0

local function test(name, fn)
    tests_run = tests_run + 1
    local ok, err = pcall(fn)
    if ok then
        tests_passed = tests_passed + 1
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

local function assert_near(actual, expected, tolerance, msg)
    tolerance = tolerance or 0.0001
    if math.abs(actual - expected) > tolerance then
        error(string.format("%s: expected %s, got %s (tolerance %s)",
            msg or "Assertion failed",
            tostring(expected),
            tostring(actual),
            tostring(tolerance)))
    end
end

local function assert_true(value, msg)
    if not value then
        error(msg or "Expected true, got false")
    end
end

local function assert_nil(value, msg)
    if value ~= nil then
        error(string.format("%s: expected nil, got %s",
            msg or "Assertion failed",
            tostring(value)))
    end
end

local function assert_not_nil(value, msg)
    if value == nil then
        error(msg or "Expected non-nil value")
    end
end
-- }}}

-- {{{ Helper: setup test attributes
local function setup_test_attributes()
    registry.reset()

    -- Basic attributes
    registry.register({
        id = "strength",
        type = "integer",
        min = 0,
        max = 999,
        default = 10,
        flags = ATTR_FLAGS.MODIFIABLE,
    })

    registry.register({
        id = "agility",
        type = "integer",
        min = 0,
        max = 999,
        default = 10,
        flags = ATTR_FLAGS.MODIFIABLE,
    })

    registry.register({
        id = "intelligence",
        type = "integer",
        min = 0,
        max = 999,
        default = 10,
        flags = ATTR_FLAGS.MODIFIABLE,
    })

    -- Hidden attribute
    registry.register({
        id = "internal_counter",
        type = "integer",
        default = 0,
        flags = ATTR_FLAGS.HIDDEN,
    })

    -- Derived attribute
    registry.register({
        id = "attack_power",
        type = "integer",
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "strength", "agility" },
        formula = function(get)
            return get("strength") * 2 + get("agility")
        end,
    })

    -- Another derived attribute (depends on attack_power)
    registry.register({
        id = "damage_bonus",
        type = "float",
        default = 0,
        flags = ATTR_FLAGS.DERIVED,
        derived_from = { "attack_power" },
        formula = function(get)
            return get("attack_power") * 0.1
        end,
    })

    -- Float attribute
    registry.register({
        id = "crit_chance",
        type = "float",
        min = 0,
        max = 1,
        default = 0.05,
        flags = ATTR_FLAGS.MODIFIABLE,
    })

    -- Rebuild getters after registration
    getters.rebuild()
end
-- }}}

-- {{{ Test: Basic get and get_raw
print("\n=== Basic Getter Tests ===")

test("get returns base value when no modifiers", function()
    setup_test_attributes()
    local container = registry.create_container()

    local value = getters.get(container, "strength")
    assert_eq(value, 10, "strength should be 10")
end)

test("get_raw returns base value", function()
    setup_test_attributes()
    local container = registry.create_container()

    local value = getters.get_raw(container, "strength")
    assert_eq(value, 10, "raw strength should be 10")
end)

test("get works with numeric index", function()
    setup_test_attributes()
    local container = registry.create_container()

    local index = registry.get_index("strength")
    local value = getters.get(container, index)
    assert_eq(value, 10, "strength via index should be 10")
end)

test("get returns nil for unknown attribute", function()
    setup_test_attributes()
    local container = registry.create_container()

    local value, err = getters.get(container, "nonexistent")
    assert_nil(value, "should return nil for unknown")
    assert_not_nil(err, "should return error message")
end)

test("get reflects container value changes", function()
    setup_test_attributes()
    local container = registry.create_container()

    container.values[registry.get_index("strength")] = 50
    local value = getters.get(container, "strength")
    assert_eq(value, 50, "strength should be 50 after change")
end)
-- }}}

-- {{{ Test: Modifier Application
print("\n=== Modifier Application Tests ===")

test("flat modifier adds to base", function()
    setup_test_attributes()
    local container = registry.create_container()

    container.modifiers["strength"] = {
        { type = "flat", value = 5, source = "equipment" }
    }

    local value = getters.get(container, "strength")
    assert_eq(value, 15, "10 + 5 flat = 15")
end)

test("multiple flat modifiers stack additively", function()
    setup_test_attributes()
    local container = registry.create_container()

    container.modifiers["strength"] = {
        { type = "flat", value = 5, source = "equipment" },
        { type = "flat", value = 3, source = "buff" },
    }

    local value = getters.get(container, "strength")
    assert_eq(value, 18, "10 + 5 + 3 = 18")
end)

test("percent modifier applies after flat", function()
    setup_test_attributes()
    local container = registry.create_container()

    container.modifiers["strength"] = {
        { type = "flat", value = 10, source = "equipment" },
        { type = "percent", value = 50, source = "buff" },
    }

    -- (10 + 10) * (1 + 50/100) = 20 * 1.5 = 30
    local value = getters.get(container, "strength")
    assert_eq(value, 30, "(10 + 10) * 1.5 = 30")
end)

test("multiple percent modifiers stack additively", function()
    setup_test_attributes()
    local container = registry.create_container()

    container.modifiers["strength"] = {
        { type = "percent", value = 20, source = "buff1" },
        { type = "percent", value = 30, source = "buff2" },
    }

    -- 10 * (1 + (20+30)/100) = 10 * 1.5 = 15
    local value = getters.get(container, "strength")
    assert_eq(value, 15, "10 * 1.5 = 15")
end)

test("multiplier applies after percent", function()
    setup_test_attributes()
    local container = registry.create_container()

    container.modifiers["strength"] = {
        { type = "flat", value = 10, source = "equipment" },
        { type = "percent", value = 50, source = "buff" },
        { type = "multiplier", value = 2, source = "aura" },
    }

    -- (10 + 10) * 1.5 * 2 = 60
    local value = getters.get(container, "strength")
    assert_eq(value, 60, "(10 + 10) * 1.5 * 2 = 60")
end)

test("multiple multipliers stack multiplicatively", function()
    setup_test_attributes()
    local container = registry.create_container()

    container.modifiers["strength"] = {
        { type = "multiplier", value = 2, source = "buff1" },
        { type = "multiplier", value = 1.5, source = "buff2" },
    }

    -- 10 * 2 * 1.5 = 30
    local value = getters.get(container, "strength")
    assert_eq(value, 30, "10 * 2 * 1.5 = 30")
end)

test("get_raw ignores modifiers", function()
    setup_test_attributes()
    local container = registry.create_container()

    container.modifiers["strength"] = {
        { type = "flat", value = 100, source = "equipment" },
    }

    local value = getters.get_raw(container, "strength")
    assert_eq(value, 10, "raw should still be 10")
end)

test("complex modifier combination", function()
    setup_test_attributes()
    local container = registry.create_container()

    -- Base 10
    -- +15 flat -> 25
    -- +40% -> 25 * 1.4 = 35
    -- x1.2 multiplier -> 35 * 1.2 = 42
    container.modifiers["strength"] = {
        { type = "flat", value = 5, source = "equipment1" },
        { type = "flat", value = 10, source = "equipment2" },
        { type = "percent", value = 20, source = "buff1" },
        { type = "percent", value = 20, source = "buff2" },
        { type = "multiplier", value = 1.2, source = "aura" },
    }

    local value = getters.get(container, "strength")
    assert_eq(value, 42, "complex: (10+15)*1.4*1.2 = 42")
end)
-- }}}

-- {{{ Test: get_base
print("\n=== get_base Tests ===")

test("get_base returns base + flat only", function()
    setup_test_attributes()
    local container = registry.create_container()

    container.modifiers["strength"] = {
        { type = "flat", value = 10, source = "equipment" },
        { type = "percent", value = 50, source = "buff" },
        { type = "multiplier", value = 2, source = "aura" },
    }

    local base = getters.get_base(container, "strength")
    assert_eq(base, 20, "base + flat = 10 + 10 = 20")
end)

test("get_base returns raw when no modifiers", function()
    setup_test_attributes()
    local container = registry.create_container()

    local base = getters.get_base(container, "strength")
    assert_eq(base, 10, "base should be 10")
end)

test("get_base ignores percent and multiplier", function()
    setup_test_attributes()
    local container = registry.create_container()

    container.modifiers["strength"] = {
        { type = "percent", value = 100, source = "buff" },
        { type = "multiplier", value = 10, source = "aura" },
    }

    local base = getters.get_base(container, "strength")
    assert_eq(base, 10, "base should ignore percent/multiplier")
end)
-- }}}

-- {{{ Test: Derived Attributes
print("\n=== Derived Attribute Tests ===")

test("derived attribute computes from formula", function()
    setup_test_attributes()
    local container = registry.create_container()

    -- attack_power = strength * 2 + agility
    -- With defaults: 10 * 2 + 10 = 30
    local value = getters.get(container, "attack_power")
    assert_eq(value, 30, "attack_power = 10*2 + 10 = 30")
end)

test("derived attribute updates when dependencies change", function()
    setup_test_attributes()
    local container = registry.create_container()

    -- Change strength to 20
    container.values[registry.get_index("strength")] = 20
    getters.mark_dirty(container, "strength")

    -- attack_power = 20 * 2 + 10 = 50
    local value = getters.get(container, "attack_power")
    assert_eq(value, 50, "attack_power = 20*2 + 10 = 50")
end)

test("derived attribute clears dirty flag after compute", function()
    setup_test_attributes()
    local container = registry.create_container()

    local index = registry.get_index("attack_power")
    assert_true(container.dirty[index], "should be dirty initially")

    getters.get(container, "attack_power")
    assert_nil(container.dirty[index], "should not be dirty after get")
end)

test("chained derived attributes work", function()
    setup_test_attributes()
    local container = registry.create_container()

    -- damage_bonus = attack_power * 0.1
    -- attack_power = 10*2 + 10 = 30
    -- damage_bonus = 30 * 0.1 = 3
    local value = getters.get(container, "damage_bonus")
    assert_near(value, 3.0, 0.0001, "damage_bonus = 30 * 0.1 = 3")
end)

test("mark_dirty propagates to dependents", function()
    setup_test_attributes()
    local container = registry.create_container()

    -- Clear dirty flags by computing
    getters.get(container, "damage_bonus")

    local ap_index = registry.get_index("attack_power")
    local db_index = registry.get_index("damage_bonus")

    -- Change strength and mark dirty
    container.values[registry.get_index("strength")] = 50
    getters.mark_dirty(container, "strength")

    assert_true(container.dirty[ap_index], "attack_power should be dirty")
    assert_true(container.dirty[db_index], "damage_bonus should be dirty")
end)

test("derived attributes see modified dependency values", function()
    setup_test_attributes()
    local container = registry.create_container()

    -- Add modifier to strength
    container.modifiers["strength"] = {
        { type = "flat", value = 10, source = "equipment" },
    }
    getters.mark_dirty(container, "strength")

    -- attack_power should use modified strength (20)
    -- attack_power = 20 * 2 + 10 = 50
    local value = getters.get(container, "attack_power")
    assert_eq(value, 50, "attack_power should use modified strength")
end)
-- }}}

-- {{{ Test: Batch Operations
print("\n=== Batch Operation Tests ===")

test("get_many returns multiple values", function()
    setup_test_attributes()
    local container = registry.create_container()

    local results = getters.get_many(container, {"strength", "agility"})
    assert_eq(results["strength"], 10, "strength should be 10")
    assert_eq(results["agility"], 10, "agility should be 10")
end)

test("get_all returns all non-hidden values", function()
    setup_test_attributes()
    local container = registry.create_container()

    local results = getters.get_all(container)
    assert_not_nil(results["strength"], "should have strength")
    assert_not_nil(results["agility"], "should have agility")
    assert_nil(results["internal_counter"], "should not have hidden attr")
end)

test("get_all_raw returns all raw values", function()
    setup_test_attributes()
    local container = registry.create_container()

    container.modifiers["strength"] = {
        { type = "flat", value = 100, source = "equipment" },
    }

    local results = getters.get_all_raw(container)
    assert_eq(results["strength"], 10, "raw should be 10")
end)
-- }}}

-- {{{ Test: Modifier Breakdown
print("\n=== Modifier Breakdown Tests ===")

test("get_modifier_breakdown returns structure", function()
    setup_test_attributes()
    local container = registry.create_container()

    local breakdown = getters.get_modifier_breakdown(container, "strength")
    assert_not_nil(breakdown, "should return breakdown")
    assert_eq(breakdown.id, "strength", "id should match")
    assert_eq(breakdown.base, 10, "base should be 10")
    assert_eq(breakdown.final, 10, "final should be 10")
end)

test("breakdown includes modifier sources", function()
    setup_test_attributes()
    local container = registry.create_container()

    container.modifiers["strength"] = {
        { type = "flat", value = 5, source = "Sword of Might" },
        { type = "percent", value = 10, source = "Battle Shout" },
    }

    local breakdown = getters.get_modifier_breakdown(container, "strength")
    assert_eq(#breakdown.sources, 2, "should have 2 sources")
    assert_eq(breakdown.flat, 5, "flat sum should be 5")
    assert_eq(breakdown.percent, 10, "percent sum should be 10")
    assert_eq(breakdown.sources[1].source, "Sword of Might", "first source")
end)

test("breakdown shows derived dependencies", function()
    setup_test_attributes()
    local container = registry.create_container()

    local breakdown = getters.get_modifier_breakdown(container, "attack_power")
    assert_true(breakdown.is_derived, "should be marked as derived")
    assert_not_nil(breakdown.derived_from, "should have derived_from")
    assert_eq(breakdown.derived_from["strength"], 10, "should show str value")
    assert_eq(breakdown.derived_from["agility"], 10, "should show agi value")
end)

test("breakdown returns nil for unknown", function()
    setup_test_attributes()
    local container = registry.create_container()

    local breakdown = getters.get_modifier_breakdown(container, "nonexistent")
    assert_nil(breakdown, "should return nil for unknown")
end)
-- }}}

-- {{{ Test: Getter Functions
print("\n=== Getter Function Tests ===")

test("get_getter returns function", function()
    setup_test_attributes()
    local getter = getters.get_getter("strength")
    assert_not_nil(getter, "should return getter function")
    assert_eq(type(getter), "function", "should be a function")
end)

test("direct getter use for hot path", function()
    setup_test_attributes()
    local container = registry.create_container()

    local get_str = getters.get_getter("strength")
    local value = get_str(container)
    assert_eq(value, 10, "direct getter should return 10")
end)

test("get_raw_getter returns raw function", function()
    setup_test_attributes()
    local container = registry.create_container()

    container.modifiers["strength"] = {
        { type = "flat", value = 100, source = "equipment" },
    }

    local get_str_raw = getters.get_raw_getter("strength")
    local value = get_str_raw(container)
    assert_eq(value, 10, "raw getter should ignore modifiers")
end)

test("has returns true for existing getter", function()
    setup_test_attributes()
    assert_true(getters.has("strength"), "should have strength getter")
end)

test("has returns false for nonexistent getter", function()
    setup_test_attributes()
    assert_true(not getters.has("nonexistent"), "should not have nonexistent")
end)
-- }}}

-- {{{ Test: Dirty Flag Management
print("\n=== Dirty Flag Management Tests ===")

test("invalidate_all_derived marks all derived dirty", function()
    setup_test_attributes()
    local container = registry.create_container()

    -- Clear dirty flags
    getters.get(container, "attack_power")
    getters.get(container, "damage_bonus")

    local ap_index = registry.get_index("attack_power")
    local db_index = registry.get_index("damage_bonus")

    assert_nil(container.dirty[ap_index], "should be clean")
    assert_nil(container.dirty[db_index], "should be clean")

    getters.invalidate_all_derived(container)

    assert_true(container.dirty[ap_index], "should be dirty after invalidate")
    assert_true(container.dirty[db_index], "should be dirty after invalidate")
end)

test("rebuild creates new getters", function()
    setup_test_attributes()

    -- Register a new attribute after initial setup
    registry.register({
        id = "new_attr",
        type = "integer",
        default = 42,
    })

    -- Before rebuild, getter doesn't exist
    assert_true(not getters.has("new_attr"), "should not have getter yet")

    getters.rebuild()

    -- After rebuild, getter exists
    assert_true(getters.has("new_attr"), "should have getter after rebuild")

    local container = registry.create_container()
    local value = getters.get(container, "new_attr")
    assert_eq(value, 42, "new attribute should work")
end)
-- }}}

-- {{{ Test: Float Attributes
print("\n=== Float Attribute Tests ===")

test("float modifiers apply correctly", function()
    setup_test_attributes()
    local container = registry.create_container()

    container.modifiers["crit_chance"] = {
        { type = "flat", value = 0.05, source = "equipment" },
        { type = "percent", value = 20, source = "buff" },
    }

    -- (0.05 + 0.05) * 1.2 = 0.12
    local value = getters.get(container, "crit_chance")
    assert_near(value, 0.12, 0.0001, "crit should be 0.12")
end)

test("float raw value preserved", function()
    setup_test_attributes()
    local container = registry.create_container()

    local value = getters.get_raw(container, "crit_chance")
    assert_near(value, 0.05, 0.0001, "raw crit should be 0.05")
end)
-- }}}

-- {{{ Test: Edge Cases
print("\n=== Edge Case Tests ===")

test("empty modifier array behaves like no modifiers", function()
    setup_test_attributes()
    local container = registry.create_container()

    container.modifiers["strength"] = {}

    local value = getters.get(container, "strength")
    assert_eq(value, 10, "empty modifiers = base value")
end)

test("negative flat modifier reduces value", function()
    setup_test_attributes()
    local container = registry.create_container()

    container.modifiers["strength"] = {
        { type = "flat", value = -5, source = "debuff" },
    }

    local value = getters.get(container, "strength")
    assert_eq(value, 5, "10 - 5 = 5")
end)

test("negative percent modifier reduces value", function()
    setup_test_attributes()
    local container = registry.create_container()

    container.modifiers["strength"] = {
        { type = "percent", value = -50, source = "weakness" },
    }

    local value = getters.get(container, "strength")
    assert_eq(value, 5, "10 * 0.5 = 5")
end)

test("multiplier less than 1 reduces value", function()
    setup_test_attributes()
    local container = registry.create_container()

    container.modifiers["strength"] = {
        { type = "multiplier", value = 0.5, source = "curse" },
    }

    local value = getters.get(container, "strength")
    assert_eq(value, 5, "10 * 0.5 = 5")
end)

test("zero multiplier zeroes value", function()
    setup_test_attributes()
    local container = registry.create_container()

    container.modifiers["strength"] = {
        { type = "flat", value = 100, source = "equipment" },
        { type = "percent", value = 500, source = "buff" },
        { type = "multiplier", value = 0, source = "nullify" },
    }

    local value = getters.get(container, "strength")
    assert_eq(value, 0, "anything * 0 = 0")
end)

test("derived formula receiving zero returns correct value", function()
    setup_test_attributes()
    local container = registry.create_container()

    -- Zero out strength
    container.values[registry.get_index("strength")] = 0
    getters.mark_dirty(container, "strength")

    -- attack_power = 0 * 2 + 10 = 10
    local value = getters.get(container, "attack_power")
    assert_eq(value, 10, "attack_power = 0*2 + 10 = 10")
end)
-- }}}

-- {{{ Test Summary
print("\n=== Test Summary ===")
print(string.format("Passed: %d", tests_passed))
print(string.format("Failed: %d", tests_run - tests_passed))
print(string.format("Total: %d", tests_run))

if tests_passed == tests_run then
    print("All tests PASSED!")
    os.exit(0)
else
    print("Some tests FAILED!")
    os.exit(1)
end
-- }}}

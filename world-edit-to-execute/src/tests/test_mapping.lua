#!/usr/bin/env lua
-- Test suite for cross-system attribute mapping
-- Tests parallel conversions, semantic mappings, and conversion profiles.

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

-- {{{ Test Framework
local tests_run = 0
local tests_passed = 0
local current_suite = ""

local function suite(name)
    current_suite = name
    print("\n=== " .. name .. " ===")
end

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
    tolerance = tolerance or 0.01
    if math.abs(actual - expected) > tolerance then
        error(string.format("%s: expected ~%s, got %s (tolerance: %s)",
            msg or "Assertion failed",
            tostring(expected),
            tostring(actual),
            tostring(tolerance)))
    end
end

local function assert_true(condition, msg)
    if not condition then
        error(msg or "Expected true")
    end
end

local function assert_nil(value, msg)
    if value ~= nil then
        error(string.format("%s: expected nil, got %s", msg or "Expected nil", tostring(value)))
    end
end

local function assert_not_nil(value, msg)
    if value == nil then
        error(msg or "Expected non-nil value")
    end
end
-- }}}

-- {{{ Load modules
local mapping = require("libs.attributes.mapping")
local registry = require("libs.attributes.registry")
local getters = require("libs.attributes.getters")
local setters = require("libs.attributes.setters")
-- }}}

-- {{{ Test: Parallel Conversion
suite("Parallel Conversion")

test("convert_value wc3 to wow strength (1:1)", function()
    local result = mapping.convert_value("wc3", "wow", "strength", 50)
    assert_not_nil(result, "Should return result")
    assert_eq(result.source, "strength")
    assert_eq(result.target, "strength")
    assert_eq(result.value, 50)
    assert_eq(result.factor, 1.0)
end)

test("convert_value wow to wc3 strength (1:1)", function()
    local result = mapping.convert_value("wow", "wc3", "strength", 75)
    assert_not_nil(result, "Should return result")
    assert_eq(result.value, 75)
end)

test("convert_value intelligence -> intellect", function()
    local result = mapping.convert_value("wc3", "wow", "intelligence", 30)
    assert_not_nil(result, "Should return result")
    assert_eq(result.source, "intelligence")
    assert_eq(result.target, "intellect")
    assert_eq(result.value, 30)
end)

test("convert_value intellect -> intelligence", function()
    local result = mapping.convert_value("wow", "wc3", "intellect", 40)
    assert_not_nil(result, "Should return result")
    assert_eq(result.source, "intellect")
    assert_eq(result.target, "intelligence")
    assert_eq(result.value, 40)
end)

test("convert_value armor scaling (factor 10)", function()
    -- WC3 armor 10 -> WoW armor 100
    local result = mapping.convert_value("wc3", "wow", "base_armor", 10)
    assert_not_nil(result, "Should return result")
    assert_eq(result.value, 100)
    assert_eq(result.factor, 10.0)
end)

test("convert_value armor reverse (factor 0.1)", function()
    -- WoW armor 100 -> WC3 armor 10
    local result = mapping.convert_value("wow", "wc3", "base_armor", 100)
    assert_not_nil(result, "Should return result")
    assert_eq(result.value, 10)
    assert_near(result.factor, 0.1)
end)

test("convert_value same system returns identity", function()
    local result = mapping.convert_value("wc3", "wc3", "strength", 50)
    assert_not_nil(result, "Should return result")
    assert_eq(result.value, 50)
    assert_eq(result.factor, 1.0)
end)

test("convert_value unknown attribute returns error", function()
    local result, err = mapping.convert_value("wc3", "wow", "nonexistent_attr", 50)
    assert_nil(result, "Should return nil for unknown attr")
    assert_not_nil(err, "Should return error message")
    assert_true(err:find("No mapping"), "Error should mention no mapping")
end)

test("convert_value invalid system returns error", function()
    local result, err = mapping.convert_value("diablo", "wow", "strength", 50)
    assert_nil(result, "Should return nil for invalid system")
    assert_not_nil(err, "Should return error message")
    assert_true(err:find("Unknown system"), "Error should mention unknown system")
end)
-- }}}

-- {{{ Test: Bidirectional Consistency
suite("Bidirectional Consistency")

test("round-trip conversion preserves value", function()
    -- WC3 -> WoW -> WC3 should return original
    local original = 42
    local to_wow = mapping.convert_value("wc3", "wow", "strength", original)
    local back = mapping.convert_value("wow", "wc3", "strength", to_wow.value)
    assert_eq(back.value, original, "Round-trip should preserve value")
end)

test("round-trip armor conversion", function()
    local original = 15
    local to_wow = mapping.convert_value("wc3", "wow", "base_armor", original)
    assert_eq(to_wow.value, 150, "WC3 15 -> WoW 150")
    local back = mapping.convert_value("wow", "wc3", "base_armor", to_wow.value)
    assert_eq(back.value, original, "Round-trip should preserve armor")
end)

test("all parallels are bidirectional", function()
    local parallels = mapping.list_parallels()
    for _, p in ipairs(parallels) do
        if p.wc3 and p.wow and p.factor then
            -- Check forward
            local forward = mapping.get_parallel("wc3", p.wc3)
            assert_not_nil(forward, "Forward mapping should exist for " .. p.wc3)

            -- Check reverse
            local reverse = mapping.get_parallel("wow", p.wow)
            assert_not_nil(reverse, "Reverse mapping should exist for " .. p.wow)

            -- Check factors are inverse
            assert_near(forward.factor * reverse.factor, 1.0, 0.001,
                "Factors should be inverse for " .. p.wc3)
        end
    end
end)
-- }}}

-- {{{ Test: has_parallel and get_parallel
suite("Parallel Lookup")

test("has_parallel returns true for mapped attr", function()
    assert_true(mapping.has_parallel("wc3", "strength"))
    assert_true(mapping.has_parallel("wow", "strength"))
    assert_true(mapping.has_parallel("wc3", "intelligence"))
    assert_true(mapping.has_parallel("wow", "intellect"))
end)

test("has_parallel returns false for unmapped", function()
    assert_true(not mapping.has_parallel("wc3", "nonexistent"))
    assert_true(not mapping.has_parallel("wow", "spirit"))  -- WoW-only stat
end)

test("get_parallel returns mapping info", function()
    local info = mapping.get_parallel("wc3", "base_armor")
    assert_not_nil(info)
    assert_eq(info.target, "base_armor")
    assert_eq(info.factor, 10.0)
end)

test("list_parallels returns all definitions", function()
    local parallels = mapping.list_parallels()
    assert_true(#parallels > 5, "Should have multiple parallels defined")

    -- Check structure
    local found_armor = false
    for _, p in ipairs(parallels) do
        assert_not_nil(p.wc3 or p.wow, "Should have at least one system")
        if p.wc3 == "base_armor" then
            found_armor = true
            assert_eq(p.factor, 10.0)
        end
    end
    assert_true(found_armor, "Should include armor parallel")
end)
-- }}}

-- {{{ Test: Semantic Mappings
suite("Semantic Mappings")

test("list_semantic_mappings returns all mappings", function()
    local mappings = mapping.list_semantic_mappings()
    assert_not_nil(mappings.wc3_to_wow_stamina, "Should have stamina mapping")
    assert_not_nil(mappings.wow_to_wc3_damage_bonus, "Should have damage mapping")
end)

test("semantic mapping info has required fields", function()
    local mappings = mapping.list_semantic_mappings()
    for id, m in pairs(mappings) do
        assert_not_nil(m.description, id .. " should have description")
        assert_not_nil(m.source_system, id .. " should have source_system")
        assert_not_nil(m.target_system, id .. " should have target_system")
        assert_not_nil(m.source_attrs, id .. " should have source_attrs")
        assert_not_nil(m.target_attr, id .. " should have target_attr")
    end
end)

test("apply_semantic_mapping with valid container", function()
    -- Set up a WC3-style container
    registry.reset()
    registry.register({ id = "base_health", type = "integer", default = 100 })
    registry.register({ id = "strength", type = "integer", default = 20 })
    getters.rebuild()
    setters.rebuild()
    local container = registry.create_container()
    setters.set(container, "base_health", 200)
    setters.set(container, "strength", 30)

    local result = mapping.apply_semantic_mapping(container, "wc3_to_wow_stamina")
    assert_not_nil(result, "Should return result")
    assert_eq(result.target, "stamina")
    assert_true(result.value > 0, "Should compute positive stamina")
    -- WC3 max_health = 200 + (30 * 25) = 950
    -- WoW stamina = ((950 - 100) / 10) + 20 = 85 + 20 = 105
    assert_near(result.value, 105, 1, "Stamina calculation")
end)

test("apply_semantic_mapping unknown returns error", function()
    local container = registry.create_container()
    local result, err = mapping.apply_semantic_mapping(container, "nonexistent_mapping")
    assert_nil(result)
    assert_not_nil(err)
    assert_true(err:find("Unknown semantic mapping"))
end)
-- }}}

-- {{{ Test: Profiles
suite("Conversion Profiles")

test("list_profiles returns all profiles", function()
    local profiles = mapping.list_profiles()
    assert_not_nil(profiles.balanced, "Should have balanced profile")
    assert_not_nil(profiles.pve_optimized, "Should have pve_optimized profile")
    assert_not_nil(profiles.faithful_wc3, "Should have faithful_wc3 profile")
end)

test("profile info has required fields", function()
    local profiles = mapping.list_profiles()
    for name, p in pairs(profiles) do
        assert_not_nil(p.name, name .. " should have name")
        assert_not_nil(p.description, name .. " should have description")
        assert_not_nil(p.scale_factor, name .. " should have scale_factor")
    end
end)

test("apply_profile converts basic attributes", function()
    -- Set up source and target containers
    registry.reset()
    registry.register({ id = "strength", type = "integer", default = 10, min = 0, max = 999 })
    registry.register({ id = "agility", type = "integer", default = 10, min = 0, max = 999 })
    registry.register({ id = "stamina", type = "integer", default = 10, min = 0, max = 999 })
    registry.register({ id = "base_health", type = "integer", default = 100, min = 0, max = 9999 })
    getters.rebuild()
    setters.rebuild()

    local source = registry.create_container()
    local target = registry.create_container()

    setters.set(source, "strength", 50)
    setters.set(source, "agility", 30)
    setters.set(source, "base_health", 200)

    local results = mapping.apply_profile(source, target, "balanced", "wc3")

    assert_not_nil(results, "Should return results")
    assert_not_nil(results.converted, "Should have converted attributes")
    -- Strength should be converted 1:1 with scale_factor 1.0
    assert_eq(results.converted.strength, 50)
    assert_eq(results.converted.agility, 30)
end)

test("apply_profile applies scale factor", function()
    registry.reset()
    registry.register({ id = "strength", type = "integer", default = 10, min = 0, max = 999 })
    getters.rebuild()
    setters.rebuild()

    local source = registry.create_container()
    local target = registry.create_container()
    setters.set(source, "strength", 100)

    -- pve_optimized has scale_factor = 1.2
    local results = mapping.apply_profile(source, target, "pve_optimized", "wc3")

    -- 100 * 1.2 = 120
    assert_eq(results.converted.strength, 120)
end)

test("apply_profile applies bonuses", function()
    registry.reset()
    registry.register({ id = "strength", type = "integer", default = 10, min = 0, max = 999 })
    registry.register({ id = "hit_rating", type = "integer", default = 0, min = 0, max = 999 })
    getters.rebuild()
    setters.rebuild()

    local source = registry.create_container()
    local target = registry.create_container()
    setters.set(source, "strength", 50)

    -- pve_optimized has hit_rating bonus of 50
    local results = mapping.apply_profile(source, target, "pve_optimized", "wc3")

    assert_not_nil(results.bonuses, "Should have bonuses")
    assert_eq(results.bonuses.hit_rating, 50)
    assert_eq(getters.get(target, "hit_rating"), 50)
end)

test("apply_profile unknown returns error", function()
    local source = registry.create_container()
    local target = registry.create_container()
    local result, err = mapping.apply_profile(source, target, "nonexistent_profile")
    assert_nil(result)
    assert_not_nil(err)
    assert_true(err:find("Unknown profile"))
end)
-- }}}

-- {{{ Test: Container Conversion
suite("Container Conversion")

test("convert_container basic conversion", function()
    registry.reset()
    registry.register({ id = "strength", type = "integer", default = 10 })
    registry.register({ id = "agility", type = "integer", default = 10 })
    registry.register({ id = "base_armor", type = "integer", default = 5 })
    registry.register({ id = "custom_stat", type = "integer", default = 0 })
    getters.rebuild()
    setters.rebuild()

    local container = registry.create_container()
    setters.set(container, "strength", 50)
    setters.set(container, "agility", 30)
    setters.set(container, "base_armor", 10)
    setters.set(container, "custom_stat", 999)

    local result = mapping.convert_container(container, "wc3", "wow")

    assert_not_nil(result, "Should return result")
    assert_not_nil(result.values, "Should have values")
    assert_not_nil(result.unmapped, "Should have unmapped list")

    -- Check converted values
    assert_eq(result.values.strength, 50)
    assert_eq(result.values.agility, 30)
    assert_eq(result.values.base_armor, 100)  -- 10 * 10

    -- custom_stat has no mapping
    local found_custom = false
    for _, attr in ipairs(result.unmapped) do
        if attr == "custom_stat" then found_custom = true end
    end
    assert_true(found_custom, "custom_stat should be in unmapped list")
end)

test("convert_container invalid system", function()
    local container = registry.create_container()
    local result, err = mapping.convert_container(container, "diablo", "wow")
    assert_nil(result)
    assert_not_nil(err)
end)
-- }}}

-- {{{ Test: Print Functions
suite("Documentation Functions")

test("print_mapping_table runs without error", function()
    -- Capture output by redirecting to a string (simplified: just test no crash)
    local old_print = print
    local output = {}
    print = function(s) table.insert(output, s) end

    mapping.print_mapping_table()

    print = old_print

    assert_true(#output > 10, "Should produce significant output")

    -- Check for expected sections
    local found_parallels = false
    local found_semantic = false
    local found_profiles = false
    for _, line in ipairs(output) do
        if line:find("Parallels") then found_parallels = true end
        if line:find("Semantic") then found_semantic = true end
        if line:find("Profiles") then found_profiles = true end
    end
    assert_true(found_parallels, "Should have Parallels section")
    assert_true(found_semantic, "Should have Semantic section")
    assert_true(found_profiles, "Should have Profiles section")
end)
-- }}}

-- {{{ Summary
print("\n" .. string.rep("=", 50))
print(string.format("Tests: %d/%d passed", tests_passed, tests_run))
if tests_passed == tests_run then
    print("All tests passed!")
else
    print(string.format("FAILED: %d tests", tests_run - tests_passed))
    os.exit(1)
end
-- }}}

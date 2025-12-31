#!/usr/bin/env lua
--[[
Tests for Object Data Parser (objectdata.lua)

Tests the core binary format parser used by w3u, w3t, w3a, etc.
]]

-- Setup path
package.path = "src/?.lua;src/?/init.lua;" .. package.path

local objectdata = require("parsers.objectdata")

-- {{{ Test infrastructure
local tests_run = 0
local tests_passed = 0
local current_section = ""

local function section(name)
    current_section = name
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

local function assert_eq(expected, actual, msg)
    if expected ~= actual then
        error(string.format("%s: expected %s, got %s",
            msg or "Assertion failed",
            tostring(expected),
            tostring(actual)), 2)
    end
end

local function assert_near(expected, actual, tolerance, msg)
    tolerance = tolerance or 0.0001
    if math.abs(expected - actual) > tolerance then
        error(string.format("%s: expected %f, got %f (tolerance %f)",
            msg or "Assertion failed",
            expected, actual, tolerance), 2)
    end
end

local function assert_true(value, msg)
    if not value then
        error(msg or "Expected true", 2)
    end
end

local function assert_false(value, msg)
    if value then
        error(msg or "Expected false", 2)
    end
end

local function assert_nil(value, msg)
    if value ~= nil then
        error(msg or "Expected nil, got " .. tostring(value), 2)
    end
end
-- }}}

-- {{{ Helper to build binary data

local function int32_le(n)
    -- Convert to unsigned if negative
    if n < 0 then
        n = 0x100000000 + n
    end
    return string.char(
        n % 256,
        math.floor(n / 256) % 256,
        math.floor(n / 65536) % 256,
        math.floor(n / 16777216) % 256
    )
end

local function float32_le(f)
    -- IEEE 754 single precision
    -- Using a simple method for test data generation
    if f == 0 then
        return "\0\0\0\0"
    end

    local sign = 0
    if f < 0 then
        sign = 1
        f = -f
    end

    local mantissa, exponent = math.frexp(f)
    exponent = exponent + 126  -- IEEE bias is 127, frexp uses 1.xxx form

    if exponent <= 0 then
        -- Subnormal or zero
        return "\0\0\0\0"
    elseif exponent >= 255 then
        -- Infinity
        return string.char(0, 0, 128, sign * 128 + 127)
    end

    -- Normal number
    mantissa = (mantissa * 2 - 1) * 8388608  -- 2^23
    mantissa = math.floor(mantissa + 0.5)

    local b1 = mantissa % 256
    local b2 = math.floor(mantissa / 256) % 256
    local b3 = math.floor(mantissa / 65536) % 128 + (exponent % 2) * 128
    local b4 = sign * 128 + math.floor(exponent / 2)

    return string.char(b1, b2, b3, b4)
end

local function char4(s)
    if #s < 4 then
        s = s .. string.rep("\0", 4 - #s)
    end
    return s:sub(1, 4)
end

local function nullstr(s)
    return s .. "\0"
end

local function null_id()
    return "\0\0\0\0"
end

-- }}}

-- {{{ Build synthetic test data

-- Minimal valid file: version + empty tables
local function build_empty_file()
    return int32_le(2) ..  -- version
           int32_le(0) ..  -- original table: 0 objects
           int32_le(0)     -- custom table: 0 objects
end

-- File with one original object, one int modification
local function build_simple_original()
    return int32_le(2) ..      -- version
           int32_le(1) ..      -- original table: 1 object
           -- Object 1
           char4("hfoo") ..    -- original_id (footman)
           null_id() ..        -- new_id (null for original)
           int32_le(1) ..      -- 1 modification
           -- Modification 1
           char4("uhpm") ..    -- field_id (hit points max)
           int32_le(0) ..      -- var_type = int
           int32_le(800) ..    -- value
           null_id() ..        -- end_marker
           -- Custom table
           int32_le(0)         -- 0 custom objects
end

-- File with one custom object
local function build_simple_custom()
    return int32_le(2) ..      -- version
           int32_le(0) ..      -- original table: 0 objects
           int32_le(1) ..      -- custom table: 1 object
           -- Object 1
           char4("Hpal") ..    -- original_id (paladin - parent)
           char4("H001") ..    -- new_id (custom ID)
           int32_le(2) ..      -- 2 modifications
           -- Modification 1: name (string)
           char4("unam") ..    -- field_id
           int32_le(3) ..      -- var_type = string
           nullstr("Dark Knight") ..
           char4("H001") ..    -- end_marker
           -- Modification 2: HP (int)
           char4("uhpm") ..    -- field_id
           int32_le(0) ..      -- var_type = int
           int32_le(1500) ..   -- value
           char4("H001")       -- end_marker
end

-- File with real/unreal types
local function build_real_types()
    return int32_le(2) ..      -- version
           int32_le(1) ..      -- original table: 1 object
           -- Object 1
           char4("hfoo") ..    -- original_id
           null_id() ..        -- new_id
           int32_le(2) ..      -- 2 modifications
           -- Modification 1: real type (move speed)
           char4("umvs") ..    -- field_id
           int32_le(1) ..      -- var_type = real
           float32_le(350.5) ..
           null_id() ..
           -- Modification 2: unreal type (0.0-1.0)
           char4("uscl") ..    -- field_id (scale)
           int32_le(2) ..      -- var_type = unreal
           float32_le(0.75) ..
           null_id() ..
           -- Custom table
           int32_le(0)
end

-- File with level/column (ability format)
local function build_ability_format()
    return int32_le(2) ..      -- version
           int32_le(1) ..      -- original table: 1 object
           -- Object 1
           char4("AHhb") ..    -- original_id (Holy Bolt)
           null_id() ..        -- new_id
           int32_le(2) ..      -- 2 modifications
           -- Modification 1: damage at level 1
           char4("Hhb1") ..    -- field_id
           int32_le(0) ..      -- var_type = int
           int32_le(1) ..      -- level
           int32_le(0) ..      -- column
           int32_le(100) ..    -- value
           null_id() ..
           -- Modification 2: damage at level 2
           char4("Hhb1") ..    -- field_id
           int32_le(0) ..      -- var_type = int
           int32_le(2) ..      -- level
           int32_le(0) ..      -- column
           int32_le(200) ..    -- value
           null_id() ..
           -- Custom table
           int32_le(0)
end

-- File with multiple objects
local function build_multi_object()
    return int32_le(2) ..      -- version
           int32_le(2) ..      -- original table: 2 objects
           -- Object 1
           char4("hfoo") ..    -- footman
           null_id() ..
           int32_le(1) ..
           char4("uhpm") ..
           int32_le(0) ..
           int32_le(500) ..
           null_id() ..
           -- Object 2
           char4("hkni") ..    -- knight
           null_id() ..
           int32_le(1) ..
           char4("uhpm") ..
           int32_le(0) ..
           int32_le(1000) ..
           null_id() ..
           -- Custom table: 1 object
           int32_le(1) ..
           char4("hfoo") ..    -- parent
           char4("h000") ..    -- custom
           int32_le(1) ..
           char4("unam") ..
           int32_le(3) ..
           nullstr("Super Footman") ..
           char4("h000")
end

-- }}}

-- {{{ Tests

section("Basic Parsing")

test("parse empty file", function()
    local data = build_empty_file()
    local result, err = objectdata.parse(data)
    assert_true(result, "Parse failed: " .. tostring(err))
    assert_eq(2, result.version)
    local orig, cust = result:count()
    assert_eq(0, orig)
    assert_eq(0, cust)
end)

test("parse simple original object", function()
    local data = build_simple_original()
    local result, err = objectdata.parse(data)
    assert_true(result, "Parse failed: " .. tostring(err))

    local orig, cust = result:count()
    assert_eq(1, orig)
    assert_eq(0, cust)

    local obj = result:get("hfoo")
    assert_true(obj, "Object not found")
    assert_eq("hfoo", obj.id)
    assert_eq(1, #obj.modifications)
    assert_eq("uhpm", obj.modifications[1].field_id)
    assert_eq(0, obj.modifications[1].var_type)
    assert_eq(800, obj.modifications[1].value)
end)

test("parse simple custom object", function()
    local data = build_simple_custom()
    local result, err = objectdata.parse(data)
    assert_true(result, "Parse failed: " .. tostring(err))

    local orig, cust = result:count()
    assert_eq(0, orig)
    assert_eq(1, cust)

    local obj = result:get("H001")
    assert_true(obj, "Object not found")
    assert_eq("H001", obj.id)
    assert_eq("Hpal", obj.parent_id)
    assert_eq(2, #obj.modifications)
    assert_eq("Dark Knight", obj.modifications[1].value)
    assert_eq(1500, obj.modifications[2].value)
end)

section("Variable Types")

test("parse real type", function()
    local data = build_real_types()
    local result, err = objectdata.parse(data)
    assert_true(result, "Parse failed: " .. tostring(err))

    local obj = result:get("hfoo")
    assert_true(obj)
    -- First mod is real
    assert_eq(1, obj.modifications[1].var_type)
    assert_near(350.5, obj.modifications[1].value, 0.1)
end)

test("parse unreal type (clamped 0-1)", function()
    local data = build_real_types()
    local result, err = objectdata.parse(data)
    assert_true(result, "Parse failed: " .. tostring(err))

    local obj = result:get("hfoo")
    assert_true(obj)
    -- Second mod is unreal
    assert_eq(2, obj.modifications[2].var_type)
    assert_near(0.75, obj.modifications[2].value, 0.01)
end)

test("parse string type", function()
    local data = build_simple_custom()
    local result, err = objectdata.parse(data)
    assert_true(result, "Parse failed: " .. tostring(err))

    local obj = result:get("H001")
    assert_true(obj)
    assert_eq(3, obj.modifications[1].var_type)
    assert_eq("Dark Knight", obj.modifications[1].value)
end)

section("Level/Column (Ability Format)")

test("parse ability with level/column", function()
    local data = build_ability_format()
    local result, err = objectdata.parse(data, { has_level_column = true })
    assert_true(result, "Parse failed: " .. tostring(err))

    local obj = result:get("AHhb")
    assert_true(obj)
    assert_eq(2, #obj.modifications)

    -- Level 1
    assert_eq("Hhb1", obj.modifications[1].field_id)
    assert_eq(1, obj.modifications[1].level)
    assert_eq(0, obj.modifications[1].column)
    assert_eq(100, obj.modifications[1].value)

    -- Level 2
    assert_eq(2, obj.modifications[2].level)
    assert_eq(200, obj.modifications[2].value)
end)

section("ObjectDataTable Methods")

test("get returns object by ID", function()
    local data = build_simple_original()
    local result = objectdata.parse(data)
    local obj = result:get("hfoo")
    assert_true(obj)
    assert_eq("hfoo", obj.id)
end)

test("get returns nil for unknown ID", function()
    local data = build_simple_original()
    local result = objectdata.parse(data)
    local obj = result:get("xxxx")
    assert_nil(obj)
end)

test("has returns true for existing ID", function()
    local data = build_simple_original()
    local result = objectdata.parse(data)
    assert_true(result:has("hfoo"))
end)

test("has returns false for unknown ID", function()
    local data = build_simple_original()
    local result = objectdata.parse(data)
    assert_false(result:has("xxxx"))
end)

test("get_modification returns value", function()
    local data = build_simple_original()
    local result = objectdata.parse(data)
    local hp = result:get_modification("hfoo", "uhpm")
    assert_eq(800, hp)
end)

test("get_modification with level", function()
    local data = build_ability_format()
    local result = objectdata.parse(data, { has_level_column = true })

    local dmg1 = result:get_modification("AHhb", "Hhb1", 1)
    local dmg2 = result:get_modification("AHhb", "Hhb1", 2)
    assert_eq(100, dmg1)
    assert_eq(200, dmg2)
end)

test("get_parent returns parent object", function()
    local data = build_simple_custom()
    local result = objectdata.parse(data)
    local parent = result:get_parent("H001")
    assert_nil(parent)  -- Parent Hpal not in file
end)

test("is_custom returns true for custom objects", function()
    local data = build_simple_custom()
    local result = objectdata.parse(data)
    assert_true(result:is_custom("H001"))
end)

test("is_custom returns false for original objects", function()
    local data = build_simple_original()
    local result = objectdata.parse(data)
    assert_false(result:is_custom("hfoo"))
end)

test("all_ids returns sorted IDs", function()
    local data = build_multi_object()
    local result = objectdata.parse(data)
    local ids = result:all_ids()
    assert_eq(3, #ids)
    -- Sorted alphabetically
    assert_eq("h000", ids[1])
    assert_eq("hfoo", ids[2])
    assert_eq("hkni", ids[3])
end)

section("Multiple Objects")

test("parse multiple original objects", function()
    local data = build_multi_object()
    local result = objectdata.parse(data)

    local orig, cust = result:count()
    assert_eq(2, orig)
    assert_eq(1, cust)

    local foot = result:get("hfoo")
    local knight = result:get("hkni")
    assert_true(foot)
    assert_true(knight)
    assert_eq(500, foot.modifications[1].value)
    assert_eq(1000, knight.modifications[1].value)
end)

test("parse mixed original and custom", function()
    local data = build_multi_object()
    local result = objectdata.parse(data)

    local custom = result:get("h000")
    assert_true(custom)
    assert_eq("hfoo", custom.parent_id)
    assert_eq("Super Footman", custom.modifications[1].value)
end)

section("Error Handling")

test("rejects nil data", function()
    local result, err = objectdata.parse(nil)
    assert_nil(result)
    assert_true(err:find("too short"))
end)

test("rejects empty data", function()
    local result, err = objectdata.parse("")
    assert_nil(result)
    assert_true(err:find("too short"))
end)

test("rejects unsupported version", function()
    local data = int32_le(99)  -- Invalid version
    local result, err = objectdata.parse(data)
    assert_nil(result)
    assert_true(err:find("version"))
end)

section("Format Output")

test("format produces readable output", function()
    local data = build_multi_object()
    local result = objectdata.parse(data)
    local output = result:format()

    assert_true(output:find("version 2"))
    assert_true(output:find("Original"))
    assert_true(output:find("Custom"))
    assert_true(output:find("hfoo"))
    assert_true(output:find("h000"))
end)

-- }}}

-- {{{ Summary
print("\n" .. string.rep("=", 60))
print(string.format("Tests: %d passed / %d total", tests_passed, tests_run))
if tests_passed == tests_run then
    print("All tests passed!")
else
    print("SOME TESTS FAILED")
    os.exit(1)
end
-- }}}

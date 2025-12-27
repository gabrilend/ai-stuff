-- war3map.wct Parser Test (Issue 302)
-- Tests the wct parser with synthetic data since test maps are protected.
-- Run from project root: luajit src/tests/test_wct.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local wct = require("parsers.wct")

-- {{{ Test utilities
local tests_run = 0
local tests_passed = 0

local function print_separator(title)
    print("\n" .. string.rep("=", 60))
    print(title)
    print(string.rep("=", 60))
end

local function test(name, fn)
    io.write("Testing " .. name .. "... ")
    tests_run = tests_run + 1
    local ok, err = pcall(fn)
    if ok then
        tests_passed = tests_passed + 1
        print("PASS")
        return true
    else
        print("FAIL: " .. tostring(err))
        return false
    end
end

local function assert_eq(expected, actual, msg)
    if expected ~= actual then
        error(string.format("%s: expected %s, got %s",
            msg or "Assertion failed",
            tostring(expected),
            tostring(actual)))
    end
end

local function assert_not_nil(value, msg)
    if value == nil then
        error(msg or "Expected non-nil value")
    end
end

local function assert_nil(value, msg)
    if value ~= nil then
        error(msg or "Expected nil value, got " .. tostring(value))
    end
end
-- }}}

-- {{{ Binary writing utilities for synthetic data
local function write_int32(n)
    -- Little-endian int32
    local b1 = n % 256
    local b2 = math.floor(n / 256) % 256
    local b3 = math.floor(n / 65536) % 256
    local b4 = math.floor(n / 16777216) % 256
    return string.char(b1, b2, b3, b4)
end

local function write_sized_string(s)
    -- Length-prefixed string (no null terminator)
    return write_int32(#s) .. s
end
-- }}}

-- {{{ Build synthetic WCT data
-- {{{ build_wct_v0
-- Builds a Reign of Chaos (version 0) WCT file
local function build_wct_v0(trigger_texts)
    local parts = {}
    -- Version 0 (RoC) - no header comment
    parts[#parts + 1] = write_int32(0)
    -- Trigger count
    parts[#parts + 1] = write_int32(#trigger_texts)
    -- Trigger entries
    for _, text in ipairs(trigger_texts) do
        parts[#parts + 1] = write_sized_string(text or "")
    end
    return table.concat(parts)
end
-- }}}

-- {{{ build_wct_v1
-- Builds a Frozen Throne (version 1) WCT file
local function build_wct_v1(header_comment, trigger_texts)
    local parts = {}
    -- Version 1 (TFT)
    parts[#parts + 1] = write_int32(1)
    -- Header comment
    parts[#parts + 1] = write_sized_string(header_comment or "")
    -- Trigger count
    parts[#parts + 1] = write_int32(#trigger_texts)
    -- Trigger entries
    for _, text in ipairs(trigger_texts) do
        parts[#parts + 1] = write_sized_string(text or "")
    end
    return table.concat(parts)
end
-- }}}
-- }}}

print_separator("WCT Parser Tests (Issue 302)")

-- {{{ Test 1: Parse empty data
test("parse empty data returns error", function()
    local result, err = wct.parse("")
    assert_nil(result, "Expected nil result for empty data")
    assert_not_nil(err, "Expected error message")
end)

test("parse nil data returns error", function()
    local result, err = wct.parse(nil)
    assert_nil(result, "Expected nil result for nil data")
    assert_not_nil(err, "Expected error message")
end)
-- }}}

-- {{{ Test 2: Parse version 0 (RoC)
test("parse version 0 with no triggers", function()
    local data = build_wct_v0({})
    local result, err = wct.parse(data)
    assert_not_nil(result, err or "Failed to parse")
    assert_eq(0, result.version, "version")
    assert_eq("", result.header_comment, "header_comment should be empty")
    assert_eq(0, result.trigger_count, "trigger_count")
end)

test("parse version 0 with triggers", function()
    local data = build_wct_v0({
        "",  -- Not custom text
        "function Trig_Test_Actions takes nothing returns nothing\n    call DisplayTextToPlayer(GetLocalPlayer(), 0, 0, \"Hello\")\nendfunction",
        "",  -- Not custom text
    })
    local result, err = wct.parse(data)
    assert_not_nil(result, err or "Failed to parse")
    assert_eq(0, result.version, "version")
    assert_eq(3, result.trigger_count, "trigger_count")
    assert_nil(result.triggers[1], "trigger 1 should be nil (empty)")
    assert_not_nil(result.triggers[2], "trigger 2 should have content")
    assert_nil(result.triggers[3], "trigger 3 should be nil (empty)")
end)
-- }}}

-- {{{ Test 3: Parse version 1 (TFT)
test("parse version 1 with no triggers", function()
    local data = build_wct_v1("", {})
    local result, err = wct.parse(data)
    assert_not_nil(result, err or "Failed to parse")
    assert_eq(1, result.version, "version")
    assert_eq("", result.header_comment, "header_comment")
    assert_eq(0, result.trigger_count, "trigger_count")
end)

test("parse version 1 with header comment", function()
    local header = "// Custom JASS library\n// Author: Test\nfunction MyLibraryInit takes nothing returns nothing\nendfunction"
    local data = build_wct_v1(header, {})
    local result, err = wct.parse(data)
    assert_not_nil(result, err or "Failed to parse")
    assert_eq(1, result.version, "version")
    assert_eq(header, result.header_comment, "header_comment")
end)

test("parse version 1 with triggers and header", function()
    local header = "// Map Header"
    local triggers = {
        "",  -- GUI trigger
        "function Custom1 takes nothing returns nothing\nendfunction",
        "",  -- GUI trigger
        "function Custom2 takes nothing returns nothing\n    local integer i = 0\nendfunction",
    }
    local data = build_wct_v1(header, triggers)
    local result, err = wct.parse(data)
    assert_not_nil(result, err or "Failed to parse")
    assert_eq(1, result.version, "version")
    assert_eq(header, result.header_comment, "header_comment")
    assert_eq(4, result.trigger_count, "trigger_count")
    assert_nil(result.triggers[1], "trigger 1")
    assert_not_nil(result.triggers[2], "trigger 2")
    assert_nil(result.triggers[3], "trigger 3")
    assert_not_nil(result.triggers[4], "trigger 4")
end)
-- }}}

-- {{{ Test 4: get_custom_trigger_count
test("get_custom_trigger_count with mixed triggers", function()
    local data = build_wct_v1("", {
        "",
        "function A takes nothing returns nothing\nendfunction",
        "",
        "function B takes nothing returns nothing\nendfunction",
        "function C takes nothing returns nothing\nendfunction",
    })
    local result, err = wct.parse(data)
    assert_not_nil(result, err or "Failed to parse")
    local count = wct.get_custom_trigger_count(result)
    assert_eq(3, count, "custom trigger count")
end)

test("get_custom_trigger_count with no customs", function()
    local data = build_wct_v1("", { "", "", "" })
    local result, err = wct.parse(data)
    assert_not_nil(result, err or "Failed to parse")
    local count = wct.get_custom_trigger_count(result)
    assert_eq(0, count, "custom trigger count")
end)

test("get_custom_trigger_count with nil data", function()
    local count = wct.get_custom_trigger_count(nil)
    assert_eq(0, count, "count should be 0 for nil")
end)
-- }}}

-- {{{ Test 5: format function
test("format produces readable output", function()
    local header = "// Header\nfunction Init takes nothing returns nothing\nendfunction"
    local data = build_wct_v1(header, {
        "",
        "function Trig_Test_Actions takes nothing returns nothing\n    call DoNothing()\nendfunction",
    })
    local result, err = wct.parse(data)
    assert_not_nil(result, err or "Failed to parse")

    local output = wct.format(result)
    assert_not_nil(output, "format should return string")
    assert(output:find("Version: 1"), "should show version")
    assert(output:find("Header Comment"), "should show header section")
    assert(output:find("2 total"), "should show trigger count")
    assert(output:find("1 with custom"), "should show custom count")
end)
-- }}}

-- {{{ Test 6: merge_with_wtg
test("merge_with_wtg adds custom text to triggers", function()
    local wct_data = {
        version = 1,
        header_comment = "// My Header",
        trigger_count = 3,
        triggers = {
            [1] = nil,
            [2] = "function Trig_Test_Actions takes nothing returns nothing\nendfunction",
            [3] = nil,
        }
    }
    local wtg_data = {
        triggers = {
            { name = "Trigger1", is_custom_text = false },
            { name = "Trigger2", is_custom_text = true },
            { name = "Trigger3", is_custom_text = false },
        }
    }

    local ok, err = wct.merge_with_wtg(wct_data, wtg_data)
    assert(ok, err or "Merge failed")
    assert_nil(wtg_data.triggers[1].custom_jass, "trigger 1 should not have custom")
    assert_not_nil(wtg_data.triggers[2].custom_jass, "trigger 2 should have custom")
    assert_nil(wtg_data.triggers[3].custom_jass, "trigger 3 should not have custom")
    assert_eq("// My Header", wtg_data.header_comment, "header should be merged")
end)

test("merge_with_wtg handles nil inputs", function()
    local ok, err = wct.merge_with_wtg(nil, {})
    assert(not ok, "Should fail with nil wct_data")
    assert_not_nil(err, "Should have error message")

    ok, err = wct.merge_with_wtg({}, nil)
    assert(not ok, "Should fail with nil wtg_data")
end)

test("merge_with_wtg handles missing triggers array", function()
    local ok, err = wct.merge_with_wtg({ triggers = {} }, {})
    assert(not ok, "Should fail with missing triggers")
end)
-- }}}

-- {{{ Test 7: Edge cases
test("parse truncated data", function()
    -- Just version, no trigger count
    local data = write_int32(1) .. write_int32(0)  -- version + empty header
    local result, err = wct.parse(data)
    -- Should fail because trigger count is missing
    assert_nil(result, "Should fail on truncated data")
end)

test("parse with large trigger text", function()
    local big_text = string.rep("// Comment line\n", 1000)
    local data = build_wct_v1("", { big_text })
    local result, err = wct.parse(data)
    assert_not_nil(result, err or "Failed to parse")
    assert_eq(big_text, result.triggers[1], "Large text should be preserved")
end)

test("parse with unicode in comments", function()
    local header = "// Map: Тест карта\n// Author: 日本語"
    local data = build_wct_v1(header, {})
    local result, err = wct.parse(data)
    assert_not_nil(result, err or "Failed to parse")
    assert_eq(header, result.header_comment, "Unicode should be preserved")
end)
-- }}}

-- {{{ Summary
print_separator("Test Summary")
print(string.format("Passed: %d/%d", tests_passed, tests_run))
if tests_passed == tests_run then
    print("All tests passed!")
    os.exit(0)
else
    print("Some tests failed!")
    os.exit(1)
end
-- }}}

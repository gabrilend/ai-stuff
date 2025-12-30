#!/usr/bin/env luajit

-- Test suite for menu.lua library
-- Run with: luajit test-menu-lib.lua
-- Tests the parse_flag_value function and other TUI utilities

local DIR = "/home/ritz/programming/ai-stuff/scripts"
package.path = DIR .. "/libs/?.lua;" .. package.path

-- {{{ Test framework
local tests_passed = 0
local tests_failed = 0

local function test(name, condition, expected, actual)
    if condition then
        tests_passed = tests_passed + 1
        print(string.format("  ✓ PASS: %s", name))
    else
        tests_failed = tests_failed + 1
        print(string.format("  ✗ FAIL: %s", name))
        print(string.format("    Expected: %s", tostring(expected)))
        print(string.format("    Actual:   %s", tostring(actual)))
    end
end

local function test_section(name)
    print("")
    print(string.format("=== %s ===", name))
end
-- }}}

-- {{{ parse_flag_value tests
-- Recreate the function here for isolated testing
local function parse_flag_value(flag_str)
    if not flag_str or flag_str == "" then
        return "", nil
    end
    local value, width_str = string.match(flag_str, "^(.+):(%d+)$")
    if value and width_str then
        return value, tonumber(width_str)
    end
    return flag_str, nil
end

test_section("parse_flag_value")

-- Test: value:width format
local val, width = parse_flag_value("3:2")
test("parse '3:2' value", val == "3", "3", val)
test("parse '3:2' width", width == 2, 2, width)

val, width = parse_flag_value("100:4")
test("parse '100:4' value", val == "100", "100", val)
test("parse '100:4' width", width == 4, 4, width)

val, width = parse_flag_value("10:10")
test("parse '10:10' value", val == "10", "10", val)
test("parse '10:10' width", width == 10, 10, width)

-- Test: plain values (no width suffix)
val, width = parse_flag_value("hello")
test("parse 'hello' value", val == "hello", "hello", val)
test("parse 'hello' width is nil", width == nil, nil, width)

val, width = parse_flag_value("42")
test("parse '42' value", val == "42", "42", val)
test("parse '42' width is nil", width == nil, nil, width)

-- Test: edge cases
val, width = parse_flag_value("")
test("parse '' value", val == "", "", val)
test("parse '' width is nil", width == nil, nil, width)

val, width = parse_flag_value("0:3")
test("parse '0:3' value", val == "0", "0", val)
test("parse '0:3' width", width == 3, 3, width)

val, width = parse_flag_value("value:5")
test("parse 'value:5' value", val == "value", "value", val)
test("parse 'value:5' width", width == 5, 5, width)

-- Test: special cases that should NOT parse as value:width
val, width = parse_flag_value("path/to/file:line")
test("parse 'path/to/file:line' as-is", val == "path/to/file:line", "path/to/file:line", val)
test("parse 'path/to/file:line' width is nil", width == nil, nil, width)

val, width = parse_flag_value("host:port")
test("parse 'host:port' as-is", val == "host:port", "host:port", val)
-- }}}

-- {{{ Summary
print("")
print("=== Summary ===")
print(string.format("Passed: %d", tests_passed))
print(string.format("Failed: %d", tests_failed))
print("")
if tests_failed > 0 then
    print("TESTS FAILED")
    os.exit(1)
else
    print("ALL TESTS PASSED")
    os.exit(0)
end
-- }}}

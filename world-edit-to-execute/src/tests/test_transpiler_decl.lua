--[[
JASS Transpiler Declaration Tests

Tests for issue 306b - declaration transpilation:
- default_value() for all JASS types
- Global variable transpilation (with/without initializers, arrays, constants)
- Function transpilation (parameters, locals, body)
- Local variable transpilation
]]

package.path = package.path .. ";src/?.lua;src/?/init.lua"

local lexer = require("jass.lexer")
local parser = require("jass.parser")
local transpiler = require("jass.transpiler")

local tests_run = 0
local tests_passed = 0

-- {{{ assert_eq
local function assert_eq(actual, expected, msg)
    tests_run = tests_run + 1
    if actual == expected then
        tests_passed = tests_passed + 1
        return true
    else
        print(string.format("FAIL: %s", msg or "assertion failed"))
        print(string.format("  expected: %s", tostring(expected)))
        print(string.format("  actual: %s", tostring(actual)))
        return false
    end
end
-- }}}

-- {{{ assert_contains
local function assert_contains(str, substring, msg)
    tests_run = tests_run + 1
    if str and str:find(substring, 1, true) then
        tests_passed = tests_passed + 1
        return true
    else
        print(string.format("FAIL: %s", msg or "string should contain substring"))
        print(string.format("  looking for: %s", tostring(substring)))
        print(string.format("  in string: %s", tostring(str):sub(1, 200)))
        return false
    end
end
-- }}}

-- {{{ assert_not_contains
local function assert_not_contains(str, substring, msg)
    tests_run = tests_run + 1
    if not str or not str:find(substring, 1, true) then
        tests_passed = tests_passed + 1
        return true
    else
        print(string.format("FAIL: %s", msg or "string should not contain substring"))
        print(string.format("  should not find: %s", tostring(substring)))
        return false
    end
end
-- }}}

-- {{{ parse_and_transpile
local function parse_and_transpile(source)
    local tokens = lexer.tokenize(source)
    local ast, parse_errors = parser.parse(tokens)
    if #parse_errors > 0 then
        print("Parse errors:")
        for _, e in ipairs(parse_errors) do
            print("  " .. parser.format_error(e))
        end
    end
    local output, transpile_errors = transpiler.transpile(ast)
    return output, transpile_errors, ast
end
-- }}}

print("=== JASS Transpiler Declaration Tests ===\n")

-- ============================================================================
-- default_value Tests
-- ============================================================================

print("--- default_value Tests ---")

-- {{{ test: integer default
do
    local result = transpiler._default_value("integer")
    assert_eq(result, "0", "integer defaults to 0")
end
-- }}}

-- {{{ test: real default
do
    local result = transpiler._default_value("real")
    assert_eq(result, "0.0", "real defaults to 0.0")
end
-- }}}

-- {{{ test: boolean default
do
    local result = transpiler._default_value("boolean")
    assert_eq(result, "false", "boolean defaults to false")
end
-- }}}

-- {{{ test: string default
do
    local result = transpiler._default_value("string")
    assert_eq(result, '""', "string defaults to empty string")
end
-- }}}

-- {{{ test: code default
do
    local result = transpiler._default_value("code")
    assert_eq(result, "nil", "code defaults to nil")
end
-- }}}

-- {{{ test: nothing default
do
    local result = transpiler._default_value("nothing")
    assert_eq(result, "nil", "nothing defaults to nil")
end
-- }}}

-- {{{ test: handle type default
do
    local result = transpiler._default_value("unit")
    assert_eq(result, "nil", "unit (handle type) defaults to nil")
end
-- }}}

-- {{{ test: custom type default
do
    local result = transpiler._default_value("mytype")
    assert_eq(result, "nil", "custom type defaults to nil")
end
-- }}}

-- ============================================================================
-- Global Variable Tests
-- ============================================================================

print("--- Global Variable Tests ---")

-- {{{ test: global integer without initializer
do
    local output = parse_and_transpile([[
globals
    integer foo
endglobals
]])
    assert_contains(output, "local foo = 0", "integer global with default value")
end
-- }}}

-- {{{ test: global real without initializer
do
    local output = parse_and_transpile([[
globals
    real bar
endglobals
]])
    assert_contains(output, "local bar = 0.0", "real global with default value")
end
-- }}}

-- {{{ test: global boolean without initializer
do
    local output = parse_and_transpile([[
globals
    boolean flag
endglobals
]])
    assert_contains(output, "local flag = false", "boolean global with default value")
end
-- }}}

-- {{{ test: global string without initializer
do
    local output = parse_and_transpile([[
globals
    string msg
endglobals
]])
    assert_contains(output, 'local msg = ""', "string global with default value")
end
-- }}}

-- {{{ test: global handle type without initializer
do
    local output = parse_and_transpile([[
globals
    unit u
endglobals
]])
    assert_contains(output, "local u = nil", "handle type global defaults to nil")
end
-- }}}

-- {{{ test: global with initializer
do
    local output = parse_and_transpile([[
globals
    integer x = 42
endglobals
]])
    -- Note: initializer uses transpile_expr stub which returns placeholder
    assert_contains(output, "local x =", "global with initializer")
end
-- }}}

-- {{{ test: global array
do
    local output = parse_and_transpile([[
globals
    integer array nums
endglobals
]])
    assert_contains(output, "local nums = {}", "array global is empty table")
end
-- }}}

-- {{{ test: constant global
do
    local output = parse_and_transpile([[
globals
    constant integer MAX = 100
endglobals
]])
    assert_contains(output, "-- constant", "constant has annotation")
    assert_contains(output, "local MAX", "constant is still a local")
end
-- }}}

-- {{{ test: multiple globals
do
    local output = parse_and_transpile([[
globals
    integer a
    real b
    string c
endglobals
]])
    assert_contains(output, "local a = 0", "first global")
    assert_contains(output, "local b = 0.0", "second global")
    assert_contains(output, 'local c = ""', "third global")
end
-- }}}

-- ============================================================================
-- Function Transpilation Tests
-- ============================================================================

print("--- Function Transpilation Tests ---")

-- {{{ test: empty function
do
    local output = parse_and_transpile([[
function DoNothing takes nothing returns nothing
endfunction
]])
    assert_contains(output, "local function DoNothing()", "function signature")
    assert_contains(output, "end", "function end")
end
-- }}}

-- {{{ test: function with parameters
do
    local output = parse_and_transpile([[
function Add takes integer a, integer b returns integer
    return a
endfunction
]])
    assert_contains(output, "local function Add(a, b)", "function with params")
end
-- }}}

-- {{{ test: function with single parameter
do
    local output = parse_and_transpile([[
function Square takes integer x returns integer
    return x
endfunction
]])
    assert_contains(output, "local function Square(x)", "function with single param")
end
-- }}}

-- {{{ test: function with local variables
do
    local output = parse_and_transpile([[
function Test takes nothing returns nothing
    local integer i
    local real x
endfunction
]])
    assert_contains(output, "local i = 0", "local integer")
    assert_contains(output, "local x = 0.0", "local real")
end
-- }}}

-- {{{ test: function with local array
do
    local output = parse_and_transpile([[
function Test takes nothing returns nothing
    local integer array nums
endfunction
]])
    assert_contains(output, "local nums = {}", "local array")
end
-- }}}

-- {{{ test: function with local initializer
do
    local output = parse_and_transpile([[
function Test takes nothing returns nothing
    local integer i = 5
endfunction
]])
    -- Uses transpile_expr stub for now
    assert_contains(output, "local i =", "local with initializer")
end
-- }}}

-- {{{ test: function with body statements
do
    local output = parse_and_transpile([[
function Test takes nothing returns nothing
    set x = 1
    call DoSomething()
endfunction
]])
    -- Statements use stub - just check function structure
    assert_contains(output, "local function Test()", "function signature")
    assert_contains(output, "end", "function end")
end
-- }}}

-- {{{ test: function indentation
do
    local output = parse_and_transpile([[
function Test takes nothing returns nothing
    local integer i
endfunction
]])
    -- Local should be indented (4 spaces)
    assert_contains(output, "    local i", "local is indented")
end
-- }}}

-- {{{ test: multiple functions
do
    local output = parse_and_transpile([[
function Foo takes nothing returns nothing
endfunction

function Bar takes nothing returns nothing
endfunction
]])
    assert_contains(output, "local function Foo()", "first function")
    assert_contains(output, "local function Bar()", "second function")
end
-- }}}

-- {{{ test: function with many parameters
do
    local output = parse_and_transpile([[
function Multi takes integer a, real b, string c, boolean d returns nothing
endfunction
]])
    assert_contains(output, "local function Multi(a, b, c, d)", "multiple params")
end
-- }}}

-- ============================================================================
-- Integration Tests
-- ============================================================================

print("--- Integration Tests ---")

-- {{{ test: globals and functions together
do
    local output = parse_and_transpile([[
globals
    integer counter = 0
endglobals

function Increment takes nothing returns nothing
    set counter = counter + 1
endfunction
]])
    assert_contains(output, "local counter", "global defined")
    assert_contains(output, "local function Increment", "function defined")
end
-- }}}

-- {{{ test: complete program structure
do
    local output = parse_and_transpile([[
type mytype extends handle
native DoNative takes nothing returns nothing
globals
    integer x
endglobals
function Init takes nothing returns nothing
    local integer i
endfunction
]])
    assert_contains(output, "type mytype extends handle", "type as comment")
    assert_contains(output, "native DoNative", "native as comment")
    assert_contains(output, "local x = 0", "global")
    assert_contains(output, "local function Init", "function")
end
-- }}}

-- {{{ test: output starts with header
do
    local output = parse_and_transpile("")
    assert_contains(output, "Generated by JASS-to-Lua transpiler", "has header")
end
-- }}}

-- {{{ test: blank lines between declarations
do
    local output = parse_and_transpile([[
globals
    integer x
endglobals
function Foo takes nothing returns nothing
endfunction
]])
    -- Should have blank line between globals and function
    -- Just verify both exist without error
    assert_contains(output, "local x", "has global")
    assert_contains(output, "local function Foo", "has function")
end
-- }}}

-- ============================================================================
-- Summary
-- ============================================================================

print("")
print(string.format("=== Results: %d/%d tests passed ===", tests_passed, tests_run))

if tests_passed == tests_run then
    print("All tests passed!")
    os.exit(0)
else
    print(string.format("FAILED: %d tests failed", tests_run - tests_passed))
    os.exit(1)
end

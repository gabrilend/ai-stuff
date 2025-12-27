--[[
JASS Transpiler Infrastructure Tests

Tests for issue 306a - transpiler core infrastructure:
- Context creation and structure
- Output emission (emit, emit_blank, emit_comment)
- Indentation management
- Error reporting
- Declaration collection (first pass)
- Main transpile entry point
- Helper utilities (format_params, is_native, is_global)
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

-- {{{ assert_true
local function assert_true(value, msg)
    return assert_eq(value, true, msg)
end
-- }}}

-- {{{ assert_false
local function assert_false(value, msg)
    return assert_eq(value, false, msg)
end
-- }}}

-- {{{ assert_nil
local function assert_nil(value, msg)
    return assert_eq(value, nil, msg)
end
-- }}}

-- {{{ assert_not_nil
local function assert_not_nil(value, msg)
    tests_run = tests_run + 1
    if value ~= nil then
        tests_passed = tests_passed + 1
        return true
    else
        print(string.format("FAIL: %s (expected non-nil)", msg or "assertion failed"))
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
        print(string.format("  in string: %s", tostring(str)))
        return false
    end
end
-- }}}

-- {{{ parse_jass
-- Helper to parse JASS source and return AST
local function parse_jass(source)
    local tokens = lexer.tokenize(source)
    local ast, errors = parser.parse(tokens)
    return ast, errors
end
-- }}}

print("=== JASS Transpiler Infrastructure Tests ===\n")

-- ============================================================================
-- Context Creation Tests
-- ============================================================================

print("--- Context Creation ---")

-- {{{ test: create_context returns table
do
    local ctx = transpiler._create_context()
    assert_not_nil(ctx, "create_context returns table")
end
-- }}}

-- {{{ test: context has output array
do
    local ctx = transpiler._create_context()
    assert_not_nil(ctx.output, "context has output array")
    assert_eq(type(ctx.output), "table", "output is table")
    assert_eq(#ctx.output, 0, "output starts empty")
end
-- }}}

-- {{{ test: context has indent counter
do
    local ctx = transpiler._create_context()
    assert_eq(ctx.indent, 0, "indent starts at 0")
end
-- }}}

-- {{{ test: context has symbol tables
do
    local ctx = transpiler._create_context()
    assert_not_nil(ctx.globals, "context has globals table")
    assert_not_nil(ctx.functions, "context has functions table")
    assert_not_nil(ctx.natives, "context has natives table")
    assert_not_nil(ctx.types, "context has types table")
end
-- }}}

-- {{{ test: context has state tracking
do
    local ctx = transpiler._create_context()
    assert_nil(ctx.current_func, "current_func starts nil")
    assert_not_nil(ctx.current_locals, "current_locals exists")
    assert_false(ctx.in_loop, "in_loop starts false")
    assert_eq(ctx.loop_depth, 0, "loop_depth starts at 0")
end
-- }}}

-- {{{ test: context has errors array
do
    local ctx = transpiler._create_context()
    assert_not_nil(ctx.errors, "context has errors array")
    assert_eq(#ctx.errors, 0, "errors starts empty")
end
-- }}}

-- ============================================================================
-- Output Emission Tests
-- ============================================================================

print("--- Output Emission ---")

-- {{{ test: emit adds line to output
do
    local ctx = transpiler._create_context()
    transpiler._emit(ctx, "local x = 5")
    assert_eq(#ctx.output, 1, "one line in output")
    assert_eq(ctx.output[1], "local x = 5", "line content correct")
end
-- }}}

-- {{{ test: emit respects indentation
do
    local ctx = transpiler._create_context()
    ctx.indent = 2
    transpiler._emit(ctx, "return true")
    assert_eq(ctx.output[1], "        return true", "two levels of indentation (8 spaces)")
end
-- }}}

-- {{{ test: emit_blank adds empty line
do
    local ctx = transpiler._create_context()
    transpiler._emit(ctx, "line1")
    transpiler._emit_blank(ctx)
    transpiler._emit(ctx, "line2")
    assert_eq(#ctx.output, 3, "three lines")
    assert_eq(ctx.output[2], "", "middle line is empty")
end
-- }}}

-- {{{ test: emit_comment adds comment
do
    local ctx = transpiler._create_context()
    transpiler._emit_comment(ctx, "This is a comment")
    assert_eq(ctx.output[1], "-- This is a comment", "comment formatted correctly")
end
-- }}}

-- {{{ test: emit_comment respects indentation
do
    local ctx = transpiler._create_context()
    ctx.indent = 1
    transpiler._emit_comment(ctx, "Indented comment")
    assert_eq(ctx.output[1], "    -- Indented comment", "indented comment")
end
-- }}}

-- {{{ test: indent increases level
do
    local ctx = transpiler._create_context()
    assert_eq(ctx.indent, 0, "starts at 0")
    transpiler._indent(ctx)
    assert_eq(ctx.indent, 1, "now at 1")
    transpiler._indent(ctx)
    assert_eq(ctx.indent, 2, "now at 2")
end
-- }}}

-- {{{ test: dedent decreases level
do
    local ctx = transpiler._create_context()
    ctx.indent = 3
    transpiler._dedent(ctx)
    assert_eq(ctx.indent, 2, "decreased to 2")
    transpiler._dedent(ctx)
    assert_eq(ctx.indent, 1, "decreased to 1")
end
-- }}}

-- {{{ test: dedent doesn't go negative
do
    local ctx = transpiler._create_context()
    transpiler._dedent(ctx)
    assert_eq(ctx.indent, 0, "stays at 0")
    transpiler._dedent(ctx)
    assert_eq(ctx.indent, 0, "still at 0")
end
-- }}}

-- ============================================================================
-- Error Reporting Tests
-- ============================================================================

print("--- Error Reporting ---")

-- {{{ test: add_error records error
do
    local ctx = transpiler._create_context()
    transpiler._add_error(ctx, "Something went wrong")
    assert_eq(#ctx.errors, 1, "one error recorded")
    assert_eq(ctx.errors[1].message, "Something went wrong", "message correct")
end
-- }}}

-- {{{ test: add_error with node location
do
    local ctx = transpiler._create_context()
    local node = { type = "TEST", line = 42, col = 10 }
    transpiler._add_error(ctx, "Error with location", node)
    assert_eq(ctx.errors[1].line, 42, "line recorded")
    assert_eq(ctx.errors[1].col, 10, "column recorded")
end
-- }}}

-- {{{ test: add_error accumulates multiple errors
do
    local ctx = transpiler._create_context()
    transpiler._add_error(ctx, "First error")
    transpiler._add_error(ctx, "Second error")
    transpiler._add_error(ctx, "Third error")
    assert_eq(#ctx.errors, 3, "three errors accumulated")
end
-- }}}

-- {{{ test: format_error with location
do
    local err = { message = "Test error", line = 5, col = 12 }
    local formatted = transpiler._format_error(err)
    assert_contains(formatted, "Line 5", "contains line number")
    assert_contains(formatted, "Test error", "contains message")
end
-- }}}

-- {{{ test: format_error without location
do
    local err = { message = "Test error" }
    local formatted = transpiler._format_error(err)
    assert_eq(formatted, "Test error", "just message without location")
end
-- }}}

-- ============================================================================
-- Helper Utilities Tests
-- ============================================================================

print("--- Helper Utilities ---")

-- {{{ test: format_params empty
do
    local result = transpiler._format_params({})
    assert_eq(result, "nothing", "empty params returns 'nothing'")
end
-- }}}

-- {{{ test: format_params nil
do
    local result = transpiler._format_params(nil)
    assert_eq(result, "nothing", "nil params returns 'nothing'")
end
-- }}}

-- {{{ test: format_params single
do
    local params = {{ type = "integer", name = "x" }}
    local result = transpiler._format_params(params)
    assert_eq(result, "integer x", "single param formatted")
end
-- }}}

-- {{{ test: format_params multiple
do
    local params = {
        { type = "integer", name = "x" },
        { type = "real", name = "y" },
        { type = "string", name = "s" },
    }
    local result = transpiler._format_params(params)
    assert_eq(result, "integer x, real y, string s", "multiple params formatted")
end
-- }}}

-- {{{ test: is_native false when empty
do
    local ctx = transpiler._create_context()
    assert_false(transpiler._is_native(ctx, "GetUnitX"), "not native when empty")
end
-- }}}

-- {{{ test: is_native true when registered
do
    local ctx = transpiler._create_context()
    ctx.natives["GetUnitX"] = { params = {}, return_type = "real" }
    assert_true(transpiler._is_native(ctx, "GetUnitX"), "is native when registered")
end
-- }}}

-- {{{ test: is_global false when empty
do
    local ctx = transpiler._create_context()
    assert_false(transpiler._is_global(ctx, "udg_MyVar"), "not global when empty")
end
-- }}}

-- {{{ test: is_global true when registered
do
    local ctx = transpiler._create_context()
    ctx.globals["udg_MyVar"] = { var_type = "integer", is_array = false }
    assert_true(transpiler._is_global(ctx, "udg_MyVar"), "is global when registered")
end
-- }}}

-- {{{ test: is_local false when empty
do
    local ctx = transpiler._create_context()
    assert_false(transpiler._is_local(ctx, "x"), "not local when empty")
end
-- }}}

-- {{{ test: is_local true when registered
do
    local ctx = transpiler._create_context()
    ctx.current_locals["x"] = true
    assert_true(transpiler._is_local(ctx, "x"), "is local when registered")
end
-- }}}

-- ============================================================================
-- Declaration Collection Tests
-- ============================================================================

print("--- Declaration Collection ---")

-- {{{ test: collect types
do
    local ast, _ = parse_jass([[
type unit extends handle
type widget extends handle
]])
    local ctx = transpiler._create_context()
    transpiler._collect_declarations(ctx, ast)
    assert_not_nil(ctx.types["unit"], "unit type collected")
    assert_not_nil(ctx.types["widget"], "widget type collected")
end
-- }}}

-- {{{ test: collect globals
do
    local ast, _ = parse_jass([[
globals
    integer foo
    real bar = 1.0
    constant integer MAX = 100
endglobals
]])
    local ctx = transpiler._create_context()
    transpiler._collect_declarations(ctx, ast)
    assert_not_nil(ctx.globals["foo"], "foo global collected")
    assert_not_nil(ctx.globals["bar"], "bar global collected")
    assert_not_nil(ctx.globals["MAX"], "MAX global collected")
    assert_true(ctx.globals["MAX"].is_constant, "MAX is constant")
end
-- }}}

-- {{{ test: collect natives
do
    local ast, _ = parse_jass([[
native GetUnitX takes unit u returns real
native SetUnitX takes unit u, real x returns nothing
constant native ConvertPlayerColor takes integer i returns playercolor
]])
    local ctx = transpiler._create_context()
    transpiler._collect_declarations(ctx, ast)
    assert_not_nil(ctx.natives["GetUnitX"], "GetUnitX collected")
    assert_not_nil(ctx.natives["SetUnitX"], "SetUnitX collected")
    assert_not_nil(ctx.natives["ConvertPlayerColor"], "ConvertPlayerColor collected")
    assert_true(ctx.natives["ConvertPlayerColor"].is_constant, "ConvertPlayerColor is constant")
end
-- }}}

-- {{{ test: collect functions
do
    local ast, _ = parse_jass([[
function MyFunc takes integer x returns boolean
    return true
endfunction

function NoParams takes nothing returns nothing
endfunction
]])
    local ctx = transpiler._create_context()
    transpiler._collect_declarations(ctx, ast)
    assert_not_nil(ctx.functions["MyFunc"], "MyFunc collected")
    assert_not_nil(ctx.functions["NoParams"], "NoParams collected")
    assert_eq(ctx.functions["MyFunc"].return_type, "boolean", "return type collected")
end
-- }}}

-- ============================================================================
-- Main Transpile Entry Point Tests
-- ============================================================================

print("--- Main Transpile Entry Point ---")

-- {{{ test: transpile nil returns error
do
    local output, errors = transpiler.transpile(nil)
    assert_nil(output, "nil input returns nil output")
    assert_eq(#errors, 1, "one error for nil input")
end
-- }}}

-- {{{ test: transpile non-program returns error
do
    local fake_ast = { type = "NOT_PROGRAM" }
    local output, errors = transpiler.transpile(fake_ast)
    assert_nil(output, "non-program returns nil output")
    assert_eq(#errors, 1, "one error for wrong type")
    assert_contains(errors[1].message, "PROGRAM", "error mentions PROGRAM")
end
-- }}}

-- {{{ test: transpile empty program
do
    local ast, _ = parse_jass("")
    local output, errors = transpiler.transpile(ast)
    assert_not_nil(output, "output generated")
    assert_eq(#errors, 0, "no errors")
    assert_contains(output, "Generated by JASS-to-Lua transpiler", "has header comment")
end
-- }}}

-- {{{ test: transpile with type definition
do
    local ast, _ = parse_jass("type unit extends handle")
    local output, errors = transpiler.transpile(ast)
    assert_eq(#errors, 0, "no errors")
    assert_contains(output, "type unit extends handle", "type def in output as comment")
end
-- }}}

-- {{{ test: transpile with native
do
    local ast, _ = parse_jass("native GetUnitX takes unit u returns real")
    local output, errors = transpiler.transpile(ast)
    assert_eq(#errors, 0, "no errors")
    assert_contains(output, "native GetUnitX", "native in output as comment")
end
-- }}}

-- {{{ test: transpile with globals
do
    local ast, _ = parse_jass([[
globals
    integer myVar = 5
endglobals
]])
    local output, errors = transpiler.transpile(ast)
    assert_eq(#errors, 0, "no errors")
    assert_contains(output, "Globals", "globals mentioned in output")
end
-- }}}

-- {{{ test: transpile with function
do
    local ast, _ = parse_jass([[
function Test takes nothing returns nothing
endfunction
]])
    local output, errors = transpiler.transpile(ast)
    assert_eq(#errors, 0, "no errors")
    assert_contains(output, "function Test", "function mentioned in output")
end
-- }}}

-- {{{ test: transpile multiple declarations
do
    local ast, _ = parse_jass([[
type mytype extends handle
native Foo takes nothing returns nothing
globals
    integer x
endglobals
function Bar takes nothing returns nothing
endfunction
]])
    local output, errors = transpiler.transpile(ast)
    assert_eq(#errors, 0, "no errors for multiple declarations")
    assert_contains(output, "type mytype", "type in output")
    assert_contains(output, "native Foo", "native in output")
    assert_contains(output, "Globals", "globals in output")
    assert_contains(output, "function Bar", "function in output")
end
-- }}}

-- ============================================================================
-- Integration Tests
-- ============================================================================

print("--- Integration Tests ---")

-- {{{ test: full pipeline lexer -> parser -> transpiler
do
    local source = [[
type unit extends handle
native GetUnitX takes unit u returns real
globals
    unit myUnit
endglobals
function InitUnit takes nothing returns nothing
    set myUnit = null
endfunction
]]
    local tokens = lexer.tokenize(source)
    local ast, parse_errors = parser.parse(tokens)
    assert_eq(#parse_errors, 0, "no parse errors")

    local output, transpile_errors = transpiler.transpile(ast)
    assert_eq(#transpile_errors, 0, "no transpile errors")
    assert_not_nil(output, "output generated")
    assert_contains(output, "Generated by", "has header")
end
-- }}}

-- {{{ test: output is valid string
do
    local ast, _ = parse_jass([[
function Test takes nothing returns nothing
    return
endfunction
]])
    local output, _ = transpiler.transpile(ast)
    assert_eq(type(output), "string", "output is string")
    assert_true(#output > 0, "output is non-empty")
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

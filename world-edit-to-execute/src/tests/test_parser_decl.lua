-- JASS Parser Declarations Test (305b)
-- Tests declaration parsing: type, globals, native, function.
-- Run with: luajit src/tests/test_parser_decl.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local lexer = require("jass.lexer")
local parser = require("jass.parser")

-- {{{ Test utilities
local passed = 0
local failed = 0

local function print_separator(title)
    print("\n" .. string.rep("=", 60))
    print(title)
    print(string.rep("=", 60))
end

local function test(name, fn)
    io.write("Testing " .. name .. "... ")
    local ok, err = pcall(fn)
    if ok then
        print("PASS")
        passed = passed + 1
        return true
    else
        print("FAIL: " .. tostring(err))
        failed = failed + 1
        return false
    end
end

local function parse_source(source)
    local tokens = lexer.tokenize(source)
    return parser.parse(tokens)
end
-- }}}

-- {{{ Type definition tests
local function test_type_definitions()
    print_separator("Type Definition Tests")

    test("Parse simple type", function()
        local ast, errors = parse_source("type unit extends handle")
        assert(#errors == 0, "Expected no errors, got " .. #errors)
        assert(#ast.declarations == 1, "Expected 1 declaration")
        local decl = ast.declarations[1]
        assert(decl.type == parser.AST.TYPE_DEF, "Expected TYPE_DEF")
        assert(decl.name == "unit", "Expected name 'unit'")
        assert(decl.base_type == "handle", "Expected base_type 'handle'")
    end)

    test("Parse multiple types", function()
        local ast, errors = parse_source([[
type unit extends handle
type item extends widget
type player extends agent
]])
        assert(#errors == 0, "Expected no errors")
        assert(#ast.declarations == 3, "Expected 3 declarations")
        assert(ast.declarations[1].name == "unit")
        assert(ast.declarations[2].name == "item")
        assert(ast.declarations[3].name == "player")
    end)
end
-- }}}

-- {{{ Globals block tests
local function test_globals_blocks()
    print_separator("Globals Block Tests")

    test("Parse empty globals", function()
        local ast, errors = parse_source([[
globals
endglobals
]])
        assert(#errors == 0, "Expected no errors, got " .. #errors)
        assert(#ast.declarations == 1)
        local decl = ast.declarations[1]
        assert(decl.type == parser.AST.GLOBAL_BLOCK)
        assert(#decl.declarations == 0, "Expected no declarations in globals")
    end)

    test("Parse globals with variables", function()
        local ast, errors = parse_source([[
globals
    integer myInt
    real myReal
    string myString
endglobals
]])
        assert(#errors == 0, "Expected no errors")
        local block = ast.declarations[1]
        assert(#block.declarations == 3, "Expected 3 variables")
        assert(block.declarations[1].name == "myInt")
        assert(block.declarations[1].var_type == "integer")
        assert(block.declarations[2].name == "myReal")
        assert(block.declarations[3].name == "myString")
    end)

    test("Parse constant globals", function()
        local ast, errors = parse_source([[
globals
    constant integer MAX_PLAYERS = 12
    constant real PI = 3.14159
endglobals
]])
        assert(#errors == 0, "Expected no errors")
        local block = ast.declarations[1]
        assert(block.declarations[1].is_constant == true)
        assert(block.declarations[1].name == "MAX_PLAYERS")
        assert(block.declarations[2].is_constant == true)
    end)

    test("Parse array globals", function()
        local ast, errors = parse_source([[
globals
    integer array myIntArray
    unit array allUnits
endglobals
]])
        assert(#errors == 0, "Expected no errors")
        local block = ast.declarations[1]
        assert(block.declarations[1].is_array == true)
        assert(block.declarations[1].name == "myIntArray")
        assert(block.declarations[2].is_array == true)
    end)

    test("Parse globals with initializers", function()
        local ast, errors = parse_source([[
globals
    integer x = 5
    real y = 3.14
    string name = "test"
    boolean flag = true
endglobals
]])
        assert(#errors == 0, "Expected no errors")
        local block = ast.declarations[1]
        assert(block.declarations[1].initializer ~= nil, "Expected initializer")
        assert(block.declarations[2].initializer ~= nil)
        assert(block.declarations[3].initializer ~= nil)
        assert(block.declarations[4].initializer ~= nil)
    end)
end
-- }}}

-- {{{ Native declaration tests
local function test_native_declarations()
    print_separator("Native Declaration Tests")

    test("Parse native with no params", function()
        local ast, errors = parse_source("native DoNothing takes nothing returns nothing")
        assert(#errors == 0, "Expected no errors")
        local decl = ast.declarations[1]
        assert(decl.type == parser.AST.NATIVE_DECL)
        assert(decl.name == "DoNothing")
        assert(#decl.params == 0, "Expected no params")
        assert(decl.return_type == "nothing")
    end)

    test("Parse native with params", function()
        local ast, errors = parse_source("native CreateUnit takes player p, integer id, real x, real y, real f returns unit")
        assert(#errors == 0, "Expected no errors")
        local decl = ast.declarations[1]
        assert(decl.name == "CreateUnit")
        assert(#decl.params == 5, "Expected 5 params")
        assert(decl.params[1].type == "player")
        assert(decl.params[1].name == "p")
        assert(decl.params[2].type == "integer")
        assert(decl.return_type == "unit")
    end)

    test("Parse constant native", function()
        local ast, errors = parse_source("constant native GetUnitTypeId takes unit u returns integer")
        assert(#errors == 0, "Expected no errors")
        local decl = ast.declarations[1]
        assert(decl.is_constant == true)
        assert(decl.name == "GetUnitTypeId")
    end)
end
-- }}}

-- {{{ Function definition tests
local function test_function_definitions()
    print_separator("Function Definition Tests")

    test("Parse empty function", function()
        local ast, errors = parse_source([[
function DoNothing takes nothing returns nothing
endfunction
]])
        assert(#errors == 0, "Expected no errors, got " .. #errors)
        local decl = ast.declarations[1]
        assert(decl.type == parser.AST.FUNCTION_DEF)
        assert(decl.name == "DoNothing")
        assert(#decl.params == 0)
        assert(decl.return_type == "nothing")
        assert(#decl.locals == 0)
        assert(#decl.body == 0)
    end)

    test("Parse function with params", function()
        local ast, errors = parse_source([[
function Add takes integer a, integer b returns integer
endfunction
]])
        assert(#errors == 0, "Expected no errors")
        local decl = ast.declarations[1]
        assert(decl.name == "Add")
        assert(#decl.params == 2)
        assert(decl.params[1].name == "a")
        assert(decl.params[2].name == "b")
        assert(decl.return_type == "integer")
    end)

    test("Parse function with locals", function()
        local ast, errors = parse_source([[
function TestLocals takes nothing returns nothing
    local integer i
    local real x = 0.0
    local unit array units
endfunction
]])
        assert(#errors == 0, "Expected no errors")
        local decl = ast.declarations[1]
        assert(#decl.locals == 3, "Expected 3 locals")
        assert(decl.locals[1].name == "i")
        assert(decl.locals[2].name == "x")
        assert(decl.locals[2].initializer ~= nil)
        assert(decl.locals[3].is_array == true)
    end)

    test("Parse function with statements", function()
        local ast, errors = parse_source([[
function TestStatements takes nothing returns nothing
    call DisplayText("Hello")
    set x = 5
    return
endfunction
]])
        assert(#errors == 0, "Expected no errors")
        local decl = ast.declarations[1]
        assert(#decl.body >= 2, "Expected at least 2 statements")
    end)
end
-- }}}

-- {{{ Mixed declaration tests
local function test_mixed_declarations()
    print_separator("Mixed Declaration Tests")

    test("Parse full JASS file structure", function()
        local ast, errors = parse_source([[
type unit extends handle
type item extends widget

globals
    constant integer MAX_PLAYERS = 12
    unit array allUnits
endglobals

native CreateUnit takes player p, integer id, real x, real y, real f returns unit

function InitGame takes nothing returns nothing
    local integer i = 0
    call DisplayText("Hello")
endfunction

function main takes nothing returns nothing
    call InitGame()
endfunction
]])
        assert(#errors == 0, "Expected no errors, got " .. #errors)
        assert(#ast.declarations == 6, "Expected 6 declarations")
        assert(ast.declarations[1].type == parser.AST.TYPE_DEF)
        assert(ast.declarations[2].type == parser.AST.TYPE_DEF)
        assert(ast.declarations[3].type == parser.AST.GLOBAL_BLOCK)
        assert(ast.declarations[4].type == parser.AST.NATIVE_DECL)
        assert(ast.declarations[5].type == parser.AST.FUNCTION_DEF)
        assert(ast.declarations[6].type == parser.AST.FUNCTION_DEF)
    end)
end
-- }}}

-- {{{ Error handling tests
local function test_error_handling()
    print_separator("Error Handling Tests")

    test("Report error for missing type name", function()
        local ast, errors = parse_source("type extends handle")
        assert(#errors > 0, "Expected errors")
    end)

    test("Report error for missing endglobals", function()
        local ast, errors = parse_source([[
globals
    integer x
]])
        assert(#errors > 0, "Expected errors")
    end)

    test("Report error for missing endfunction", function()
        local ast, errors = parse_source([[
function Test takes nothing returns nothing
    call Foo()
]])
        assert(#errors > 0, "Expected errors")
    end)

    test("Error recovery continues parsing", function()
        local ast, errors = parse_source([[
type extends handle

function Valid takes nothing returns nothing
endfunction
]])
        -- Should have errors but also recover to parse the function
        assert(#errors > 0, "Expected errors")
        -- The function should still be parsed
        local found_func = false
        for _, decl in ipairs(ast.declarations) do
            if decl.type == parser.AST.FUNCTION_DEF and decl.name == "Valid" then
                found_func = true
            end
        end
        assert(found_func, "Should have recovered to parse Valid function")
    end)
end
-- }}}

-- {{{ Main
local function main()
    print_separator("JASS Parser Declaration Tests (305b)")

    test_type_definitions()
    test_globals_blocks()
    test_native_declarations()
    test_function_definitions()
    test_mixed_declarations()
    test_error_handling()

    print_separator("Results")
    print(string.format("Passed: %d / %d", passed, passed + failed))

    if failed > 0 then
        print("SOME TESTS FAILED")
        return false
    else
        print("ALL TESTS PASSED")
        return true
    end
end
-- }}}

local ok = main()
os.exit(ok and 0 or 1)

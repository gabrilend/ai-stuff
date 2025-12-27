--[[
Test: JASS Parser Comprehensive Test Suite (305e)

Unified test runner for the complete JASS parser.
Validates all parsing components:
- Type declarations (305b)
- Global declarations (305b)
- Native declarations (305b)
- Function definitions (305b)
- Expression parsing with precedence (305c)
- All statement types (305d)
- Error recovery (305a)
- Integration with realistic JASS code

Run from project root: lua src/tests/test_parser.lua
]]

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local lexer = require("jass.lexer")
local parser = require("jass.parser")
local AST = parser.AST

local tests_run = 0
local tests_passed = 0
local tests_failed = 0

-- {{{ test helper
local function test(name, fn)
    tests_run = tests_run + 1
    local ok, err = pcall(fn)
    if ok then
        tests_passed = tests_passed + 1
        print(string.format("  [PASS] %s", name))
    else
        tests_failed = tests_failed + 1
        print(string.format("  [FAIL] %s: %s", name, err))
    end
end
-- }}}

-- {{{ assert helpers
local function assert_eq(expected, actual, msg)
    if expected ~= actual then
        error(string.format("%s: expected %s, got %s", msg or "assertion failed",
            tostring(expected), tostring(actual)))
    end
end

local function parse(source)
    local tokens = lexer.tokenize(source)
    return parser.parse(tokens)
end

local function parse_expr(expr_str)
    local source = string.format([[
function test takes nothing returns integer
    return %s
endfunction
]], expr_str)
    local ast = parse(source)
    if ast and ast.declarations[1] and ast.declarations[1].body[1] then
        return ast.declarations[1].body[1].value
    end
    return nil
end
-- }}}

print("=== JASS Parser Comprehensive Test Suite (305e) ===\n")

-- {{{ Type declaration tests
local function test_type_declarations()
    print("-- Type Declarations --")

    test("parse type declaration", function()
        local ast = parse("type unitid extends handle")
        assert(ast, "parse failed")
        assert(ast.declarations[1], "no declarations")
        assert_eq(AST.TYPE_DEF, ast.declarations[1].type, "node type")
        assert_eq("unitid", ast.declarations[1].name, "type name")
        assert_eq("handle", ast.declarations[1].base_type, "base_type")
    end)

    test("parse multiple type declarations", function()
        local ast = parse([[
type player extends handle
type unit extends handle
type timer extends handle
]])
        assert_eq(3, #ast.declarations, "declaration count")
    end)
end
-- }}}

-- {{{ Globals block tests
local function test_globals_block()
    print("\n-- Globals Block --")

    test("parse globals block", function()
        local ast = parse([[
globals
    integer foo
    real bar = 3.14
    constant integer MAX = 100
    string array names
endglobals
]])
        assert(ast, "parse failed")
        local globals = ast.declarations[1]
        assert_eq(AST.GLOBAL_BLOCK, globals.type, "node type")
        assert_eq(4, #globals.declarations, "variable count")
    end)

    test("constant flag", function()
        local ast = parse([[
globals
    constant real PI = 3.14159
endglobals
]])
        local var = ast.declarations[1].declarations[1]
        assert(var.is_constant, "should be constant")
    end)

    test("array flag", function()
        local ast = parse([[
globals
    unit array selectedUnits
endglobals
]])
        local var = ast.declarations[1].declarations[1]
        assert(var.is_array, "should be array")
    end)

    test("initializer expression", function()
        local ast = parse([[
globals
    integer x = 5 + 3
endglobals
]])
        local var = ast.declarations[1].declarations[1]
        assert(var.initializer, "should have initializer")
        assert_eq(AST.BINARY_EXPR, var.initializer.type, "initializer type")
    end)
end
-- }}}

-- {{{ Native declaration tests
local function test_native_declarations()
    print("\n-- Native Declarations --")

    test("parse native declaration", function()
        local ast = parse("native CreateUnit takes player p, integer id, real x, real y, real f returns unit")
        assert(ast, "parse failed")
        local native = ast.declarations[1]
        assert_eq(AST.NATIVE_DECL, native.type, "node type")
        assert_eq("CreateUnit", native.name, "name")
        assert_eq(5, #native.params, "param count")
        assert_eq("unit", native.return_type, "return type")
    end)

    test("parse constant native", function()
        local ast = parse("constant native GetHandleId takes handle h returns integer")
        local native = ast.declarations[1]
        assert(native.is_constant, "should be constant")
    end)

    test("native takes nothing", function()
        local ast = parse("native GetRandomInt takes nothing returns integer")
        local native = ast.declarations[1]
        assert_eq(0, #native.params, "should have no params")
    end)

    test("native returns nothing", function()
        local ast = parse("native DestroyTimer takes timer t returns nothing")
        local native = ast.declarations[1]
        assert_eq("nothing", native.return_type, "should return nothing")
    end)
end
-- }}}

-- {{{ Function definition tests
local function test_function_definitions()
    print("\n-- Function Definitions --")

    test("parse empty function", function()
        local ast = parse([[
function DoNothing takes nothing returns nothing
endfunction
]])
        local fn = ast.declarations[1]
        assert_eq(AST.FUNCTION_DEF, fn.type, "node type")
        assert_eq("DoNothing", fn.name, "name")
        assert_eq(0, #fn.params, "param count")
        assert_eq("nothing", fn.return_type, "return type")
    end)

    test("function with parameters", function()
        local ast = parse([[
function Add takes integer a, integer b returns integer
    return a + b
endfunction
]])
        local fn = ast.declarations[1]
        assert_eq(2, #fn.params, "param count")
        assert_eq("a", fn.params[1].name, "first param name")
        assert_eq("integer", fn.params[1].type, "first param type")
    end)

    test("function with locals", function()
        local ast = parse([[
function WithLocals takes nothing returns nothing
    local integer i = 0
    local real r
    local unit array units
endfunction
]])
        local fn = ast.declarations[1]
        assert_eq(3, #fn.locals, "local count")
        assert(fn.locals[1].initializer, "first local has initializer")
        assert(not fn.locals[2].initializer, "second local no initializer")
        assert(fn.locals[3].is_array, "third local is array")
    end)
end
-- }}}

-- {{{ Expression precedence tests
local function test_expression_precedence()
    print("\n-- Expression Precedence --")

    test("multiplication before addition", function()
        -- 2 + 3 * 4 should parse as 2 + (3 * 4)
        local expr = parse_expr("2 + 3 * 4")
        assert_eq(AST.BINARY_EXPR, expr.type, "root type")
        assert_eq("+", expr.operator, "root operator")
        assert_eq(AST.BINARY_EXPR, expr.right.type, "right type")
        assert_eq("*", expr.right.operator, "right operator")
    end)

    test("multiplication groups left", function()
        -- 2 * 3 + 4 should parse as (2 * 3) + 4
        local expr = parse_expr("2 * 3 + 4")
        assert_eq("+", expr.operator, "root operator")
        assert_eq("*", expr.left.operator, "left operator")
    end)

    test("AND before OR", function()
        local expr = parse_expr("a and b or c")
        assert_eq("or", expr.operator, "root operator")
        assert_eq("and", expr.left.operator, "left operator")
    end)

    test("comparison before boolean", function()
        local expr = parse_expr("a > b and c < d")
        assert_eq("and", expr.operator, "root operator")
        assert_eq(">", expr.left.operator, "left comparison")
        assert_eq("<", expr.right.operator, "right comparison")
    end)

    test("unary before binary", function()
        local expr = parse_expr("-a * b")
        assert_eq("*", expr.operator, "root operator")
        assert_eq(AST.UNARY_EXPR, expr.left.type, "left is unary")
    end)

    test("parentheses override precedence", function()
        local expr = parse_expr("(2 + 3) * 4")
        assert_eq("*", expr.operator, "root operator")
        assert_eq("+", expr.left.operator, "grouped addition")
    end)

    test("NOT before AND", function()
        local expr = parse_expr("not a and b")
        assert_eq("and", expr.operator, "root operator")
        assert_eq(AST.UNARY_EXPR, expr.left.type, "left is unary not")
    end)
end
-- }}}

-- {{{ Primary expression tests
local function test_primary_expressions()
    print("\n-- Primary Expressions --")

    test("integer literal", function()
        local expr = parse_expr("42")
        assert_eq(AST.LITERAL, expr.type, "type")
    end)

    test("real literal", function()
        local expr = parse_expr("3.14")
        assert_eq(AST.LITERAL, expr.type, "type")
    end)

    test("boolean literals", function()
        local expr = parse_expr("true")
        assert_eq(AST.LITERAL, expr.type, "type")
        expr = parse_expr("false")
        assert_eq(AST.LITERAL, expr.type, "type")
    end)

    test("string literal", function()
        local expr = parse_expr('"hello"')
        assert_eq(AST.LITERAL, expr.type, "type")
    end)

    test("null literal", function()
        local expr = parse_expr("null")
        assert_eq(AST.LITERAL, expr.type, "type")
    end)

    test("rawcode literal", function()
        local expr = parse_expr("'hfoo'")
        assert_eq(AST.LITERAL, expr.type, "type")
    end)

    test("identifier", function()
        local expr = parse_expr("myVar")
        assert_eq(AST.IDENTIFIER, expr.type, "type")
        assert_eq("myVar", expr.name, "name")
    end)

    test("function call", function()
        local expr = parse_expr("GetRandomInt(1, 10)")
        assert_eq(AST.CALL_EXPR, expr.type, "type")
        assert_eq(AST.IDENTIFIER, expr.callee.type, "callee type")
        assert_eq("GetRandomInt", expr.callee.name, "callee name")
        assert_eq(2, #expr.arguments, "arg count")
    end)

    test("array access", function()
        local expr = parse_expr("arr[i]")
        assert_eq(AST.ARRAY_ACCESS, expr.type, "type")
        assert_eq(AST.IDENTIFIER, expr.array.type, "array type")
        assert_eq("arr", expr.array.name, "array name")
    end)

    test("function reference", function()
        local expr = parse_expr("function MyCallback")
        assert_eq(AST.FUNCTION_REF, expr.type, "type")
        assert_eq("MyCallback", expr.name, "function name")
    end)
end
-- }}}

-- {{{ Statement tests
local function test_statements()
    print("\n-- Statements --")

    test("set statement", function()
        local ast = parse([[
function test takes nothing returns nothing
    set x = 5
endfunction
]])
        local stmt = ast.declarations[1].body[1]
        assert_eq(AST.SET_STMT, stmt.type, "type")
        assert_eq("x", stmt.name, "name")
    end)

    test("set array element", function()
        local ast = parse([[
function test takes nothing returns nothing
    set arr[0] = 10
endfunction
]])
        local stmt = ast.declarations[1].body[1]
        assert(stmt.index, "should have index")
    end)

    test("call statement", function()
        local ast = parse([[
function test takes nothing returns nothing
    call DoNothing()
    call SetUnitX(u, 100.0)
endfunction
]])
        local body = ast.declarations[1].body
        assert_eq(AST.CALL_STMT, body[1].type, "type")
        assert_eq(0, #body[1].arguments, "no args")
        assert_eq(2, #body[2].arguments, "two args")
    end)

    test("if statement", function()
        local ast = parse([[
function test takes nothing returns nothing
    if a > 0 then
        set a = 0
    endif
endfunction
]])
        local stmt = ast.declarations[1].body[1]
        assert_eq(AST.IF_STMT, stmt.type, "type")
        assert(stmt.condition, "has condition")
        assert_eq(1, #stmt.then_branch, "then branch count")
    end)

    test("if-else statement", function()
        local ast = parse([[
function test takes nothing returns nothing
    if a > 0 then
        set a = 1
    else
        set a = 0
    endif
endfunction
]])
        local stmt = ast.declarations[1].body[1]
        assert(stmt.else_branch, "has else branch")
        assert_eq(1, #stmt.else_branch, "else branch count")
    end)

    test("if-elseif-else statement", function()
        local ast = parse([[
function test takes nothing returns nothing
    if a > 0 then
        set a = 1
    elseif a < 0 then
        set a = -1
    else
        set a = 0
    endif
endfunction
]])
        local stmt = ast.declarations[1].body[1]
        assert(stmt.elseif_branches, "has elseif branches")
        assert_eq(1, #stmt.elseif_branches, "elseif count")
    end)

    test("loop statement", function()
        local ast = parse([[
function test takes nothing returns nothing
    loop
        set i = i + 1
        exitwhen i >= 10
    endloop
endfunction
]])
        local stmt = ast.declarations[1].body[1]
        assert_eq(AST.LOOP_STMT, stmt.type, "type")
        assert_eq(2, #stmt.body, "body count")
    end)

    test("exitwhen statement", function()
        local ast = parse([[
function test takes nothing returns nothing
    loop
        exitwhen i >= 10
    endloop
endfunction
]])
        local stmt = ast.declarations[1].body[1].body[1]
        assert_eq(AST.EXITWHEN_STMT, stmt.type, "type")
        assert(stmt.condition, "has condition")
    end)

    test("return with value", function()
        local ast = parse([[
function test takes nothing returns integer
    return 42
endfunction
]])
        local stmt = ast.declarations[1].body[1]
        assert_eq(AST.RETURN_STMT, stmt.type, "type")
        assert(stmt.value, "has value")
    end)

    test("return without value", function()
        local ast = parse([[
function test takes nothing returns nothing
    return
endfunction
]])
        local stmt = ast.declarations[1].body[1]
        assert_eq(AST.RETURN_STMT, stmt.type, "type")
        assert(not stmt.value, "no value")
    end)

    test("debug statement", function()
        local ast = parse([[
function test takes nothing returns nothing
    debug set x = 5
endfunction
]])
        local stmt = ast.declarations[1].body[1]
        assert(stmt.is_debug, "should be marked debug")
    end)
end
-- }}}

-- {{{ Error recovery tests
local function test_error_recovery()
    print("\n-- Error Recovery --")

    test("continues after missing endfunction", function()
        local ast = parse([[
function broken takes nothing returns nothing
    set x = 5
function second takes nothing returns nothing
endfunction
]])
        -- Should still parse something
        assert(ast, "should return AST")
    end)

    test("reports missing then", function()
        local ast = parse([[
function test takes nothing returns nothing
    if a > 0
        set a = 0
    endif
endfunction
]])
        -- Parser should handle this gracefully
        assert(ast, "should return AST")
    end)

    test("reports misplaced local", function()
        local ast = parse([[
function test takes nothing returns nothing
    set x = 5
    local integer y
endfunction
]])
        -- Should still parse
        assert(ast, "should return AST")
    end)
end
-- }}}

-- {{{ Nested structure tests
local function test_nested_structures()
    print("\n-- Nested Structures --")

    test("nested if in loop", function()
        local ast = parse([[
function test takes nothing returns nothing
    loop
        if a > 0 then
            set a = a - 1
        endif
        exitwhen a <= 0
    endloop
endfunction
]])
        local loop_stmt = ast.declarations[1].body[1]
        assert_eq(AST.LOOP_STMT, loop_stmt.type, "outer loop")
        local if_stmt = loop_stmt.body[1]
        assert_eq(AST.IF_STMT, if_stmt.type, "inner if")
    end)

    test("deeply nested loops", function()
        local ast = parse([[
function test takes nothing returns nothing
    loop
        loop
            loop
                exitwhen true
            endloop
        endloop
    endloop
endfunction
]])
        local l1 = ast.declarations[1].body[1]
        local l2 = l1.body[1]
        local l3 = l2.body[1]
        assert_eq(AST.LOOP_STMT, l3.type, "innermost loop")
    end)

    test("complex control flow", function()
        local ast = parse([[
function test takes nothing returns nothing
    loop
        if a > 0 then
            loop
                exitwhen b >= 10
                set b = b + 1
            endloop
        elseif a < 0 then
            if c > 0 then
                set c = 0
            else
                exitwhen true
            endif
        else
            exitwhen true
        endif
    endloop
endfunction
]])
        assert(ast, "should parse complex structure")
        assert(ast.declarations[1].body[1], "has outer loop")
    end)
end
-- }}}

-- {{{ Edge case tests
local function test_edge_cases()
    print("\n-- Edge Cases --")

    test("empty if body", function()
        local ast = parse([[
function test takes nothing returns nothing
    if false then
    endif
endfunction
]])
        local if_stmt = ast.declarations[1].body[1]
        assert_eq(0, #if_stmt.then_branch, "empty then branch")
    end)

    test("empty loop body", function()
        local ast = parse([[
function test takes nothing returns nothing
    loop
        exitwhen true
    endloop
endfunction
]])
        assert(ast, "should parse")
    end)

    test("nested function calls", function()
        local ast = parse([[
function test takes nothing returns unit
    return GetOwningPlayer(GetTriggerUnit())
endfunction
]])
        local ret_expr = ast.declarations[1].body[1].value
        assert_eq(AST.CALL_EXPR, ret_expr.type, "outer call")
        assert_eq(AST.CALL_EXPR, ret_expr.arguments[1].type, "inner call")
    end)

    test("complex expression", function()
        local ast = parse([[
function test takes nothing returns boolean
    return (a + b) * c > d and not (e or f)
endfunction
]])
        assert(ast, "should parse complex expression")
    end)

    test("array in expression", function()
        local ast = parse([[
function test takes nothing returns integer
    return arr[i + 1] * 2
endfunction
]])
        assert(ast, "should parse array expression")
    end)
end
-- }}}

-- {{{ Integration tests
local function test_integration()
    print("\n-- Integration: Realistic JASS --")

    test("parse common.j style header", function()
        local ast = parse([[
type unitid extends handle
type abilityid extends handle
type itemid extends handle

globals
    constant real bj_PI = 3.14159
    constant real bj_E = 2.71828
    constant real bj_RADTODEG = 180.0 / bj_PI
    integer bj_forLoopAIndex = 0
    integer bj_forLoopBIndex = 0
    unit array bj_lastCreatedUnit
    group bj_lastCreatedGroup = null
endglobals

constant native GetHandleId takes handle h returns integer
native CreateUnit takes player p, integer id, real x, real y, real f returns unit
native GetLocalPlayer takes nothing returns player
native DisplayTextToPlayer takes player p, real x, real y, string msg returns nothing
]])
        assert(ast, "should parse")
        assert(#ast.declarations >= 7, "should have many declarations")
    end)

    test("parse blizzard.j style function", function()
        local ast = parse([[
function CreateNUnitsAtLoc takes integer count, integer unitId, player whichPlayer, location loc, real face returns group
    local group g = CreateGroup()
    local integer i = 0

    loop
        exitwhen i >= count
        call GroupAddUnit(g, CreateUnitAtLoc(whichPlayer, unitId, loc, face))
        set i = i + 1
    endloop

    return g
endfunction
]])
        assert(ast, "should parse")
        local fn = ast.declarations[1]
        assert_eq("CreateNUnitsAtLoc", fn.name, "function name")
        assert_eq(5, #fn.params, "param count")
        assert_eq(2, #fn.locals, "local count")
        assert_eq(2, #fn.body, "body statement count (loop + return)")
    end)

    test("parse trigger initialization pattern", function()
        local ast = parse([[
function InitTrig_MyTrigger takes nothing returns nothing
    local trigger t = CreateTrigger()
    call TriggerRegisterTimerEventPeriodic(t, 1.00)
    call TriggerAddCondition(t, Condition(function Trig_MyTrigger_Conditions))
    call TriggerAddAction(t, function Trig_MyTrigger_Actions)
endfunction
]])
        assert(ast, "should parse")
        local fn = ast.declarations[1]
        assert_eq(1, #fn.locals, "has local trigger")
        assert_eq(3, #fn.body, "has 3 calls")
    end)

    test("parse hero ability function", function()
        local ast = parse([[
function HeroHasAbility takes unit whichUnit, integer abilId returns boolean
    local integer i = 0
    local integer abilCount = GetUnitAbilityLevel(whichUnit, abilId)

    if abilCount > 0 then
        return true
    endif

    loop
        exitwhen i >= 6
        if GetUnitAbilityLevel(whichUnit, GetHeroSkill(whichUnit, i)) == abilId then
            return true
        endif
        set i = i + 1
    endloop

    return false
endfunction
]])
        assert(ast, "should parse")
        local fn = ast.declarations[1]
        assert_eq("boolean", fn.return_type, "returns boolean")
    end)

    test("parse map initialization", function()
        local ast = parse([[
globals
    constant integer MAX_PLAYERS = 12
    player array players
    boolean gameStarted = false
endglobals

function InitPlayers takes nothing returns nothing
    local integer i = 0
    loop
        exitwhen i >= MAX_PLAYERS
        set players[i] = Player(i)
        set i = i + 1
    endloop
endfunction

function main takes nothing returns nothing
    call InitPlayers()
    set gameStarted = true
endfunction

function config takes nothing returns nothing
    call SetMapName("Test Map")
    call SetPlayers(MAX_PLAYERS)
endfunction
]])
        assert(ast, "should parse")
        assert_eq(4, #ast.declarations, "has globals + 3 functions")
    end)
end
-- }}}

-- {{{ Main
local function main()
    test_type_declarations()
    test_globals_block()
    test_native_declarations()
    test_function_definitions()
    test_expression_precedence()
    test_primary_expressions()
    test_statements()
    test_error_recovery()
    test_nested_structures()
    test_edge_cases()
    test_integration()

    print("\n=== Summary ===")
    print(string.format("Tests passed: %d/%d", tests_passed, tests_run))

    if tests_failed > 0 then
        print(string.format("Tests failed: %d", tests_failed))
        print("SOME TESTS FAILED")
        os.exit(1)
    else
        print("All tests passed!")
        os.exit(0)
    end
end

main()
-- }}}

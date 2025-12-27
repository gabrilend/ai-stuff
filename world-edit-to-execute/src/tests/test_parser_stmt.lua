--[[
JASS Parser Statement Tests

Tests for issue 305d - statement parsing:
- SET statements (simple and array assignment)
- CALL statements (procedure calls)
- IF statements (if/elseif/else/endif)
- LOOP statements (loop/endloop)
- EXITWHEN statements
- RETURN statements (with and without value)
- LOCAL declarations
- DEBUG keyword handling
- Error cases (array initializers, locals after statements)
]]

package.path = package.path .. ";src/?.lua;src/?/init.lua"

local lexer = require("jass.lexer")
local parser = require("jass.parser")

local AST = parser.AST
local TOKEN = lexer.TOKEN

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

-- {{{ parse_function_body
-- Helper to parse a function with statements and return the parsed function node
local function parse_function_body(body_code)
    local source = string.format([[
function Test takes nothing returns nothing
%s
endfunction
]], body_code)
    local tokens = lexer.tokenize(source)
    local ast, errors = parser.parse(tokens)
    return ast, errors
end
-- }}}

-- {{{ get_first_function
local function get_first_function(ast)
    for _, decl in ipairs(ast.declarations) do
        if decl.type == AST.FUNCTION_DEF then
            return decl
        end
    end
    return nil
end
-- }}}

print("=== JASS Parser Statement Tests ===\n")

-- ============================================================================
-- SET Statement Tests
-- ============================================================================

print("--- SET Statement Tests ---")

-- {{{ test: simple set statement
do
    local ast, errors = parse_function_body("set x = 5")
    assert_eq(#errors, 0, "no parse errors for simple set")
    local fn = get_first_function(ast)
    assert_eq(#fn.body, 1, "one statement in body")
    local stmt = fn.body[1]
    assert_eq(stmt.type, AST.SET_STMT, "statement is SET_STMT")
    assert_eq(stmt.name, "x", "target variable is x")
    assert_nil(stmt.index, "no array index")
    assert_not_nil(stmt.value, "has value expression")
end
-- }}}

-- {{{ test: set with expression
do
    local ast, errors = parse_function_body("set x = a + b * 2")
    assert_eq(#errors, 0, "no parse errors for set with expression")
    local fn = get_first_function(ast)
    local stmt = fn.body[1]
    assert_eq(stmt.type, AST.SET_STMT, "statement is SET_STMT")
    assert_eq(stmt.value.type, AST.BINARY_EXPR, "value is binary expression")
end
-- }}}

-- {{{ test: array set statement
do
    local ast, errors = parse_function_body("set arr[0] = 10")
    assert_eq(#errors, 0, "no parse errors for array set")
    local fn = get_first_function(ast)
    local stmt = fn.body[1]
    assert_eq(stmt.type, AST.SET_STMT, "statement is SET_STMT")
    assert_eq(stmt.name, "arr", "target array is arr")
    assert_not_nil(stmt.index, "has array index")
    assert_eq(stmt.index.type, AST.LITERAL, "index is literal")
end
-- }}}

-- {{{ test: array set with expression index
do
    local ast, errors = parse_function_body("set units[i + 1] = CreateUnit()")
    assert_eq(#errors, 0, "no parse errors for array set with expression index")
    local fn = get_first_function(ast)
    local stmt = fn.body[1]
    assert_eq(stmt.index.type, AST.BINARY_EXPR, "index is binary expression")
end
-- }}}

-- ============================================================================
-- CALL Statement Tests
-- ============================================================================

print("--- CALL Statement Tests ---")

-- {{{ test: call with no arguments
do
    local ast, errors = parse_function_body("call DoNothing()")
    assert_eq(#errors, 0, "no parse errors for call with no args")
    local fn = get_first_function(ast)
    local stmt = fn.body[1]
    assert_eq(stmt.type, AST.CALL_STMT, "statement is CALL_STMT")
    assert_eq(stmt.name, "DoNothing", "function name is DoNothing")
    assert_eq(#stmt.arguments, 0, "no arguments")
end
-- }}}

-- {{{ test: call with single argument
do
    local ast, errors = parse_function_body("call Print(\"hello\")")
    assert_eq(#errors, 0, "no parse errors for call with single arg")
    local fn = get_first_function(ast)
    local stmt = fn.body[1]
    assert_eq(#stmt.arguments, 1, "one argument")
    assert_eq(stmt.arguments[1].type, AST.LITERAL, "argument is literal")
end
-- }}}

-- {{{ test: call with multiple arguments
do
    local ast, errors = parse_function_body("call CreateUnit(player, 'hfoo', 0.0, 0.0, 270.0)")
    assert_eq(#errors, 0, "no parse errors for call with multiple args")
    local fn = get_first_function(ast)
    local stmt = fn.body[1]
    assert_eq(#stmt.arguments, 5, "five arguments")
end
-- }}}

-- {{{ test: call with expression arguments
do
    local ast, errors = parse_function_body("call Foo(a + b, GetX(u))")
    assert_eq(#errors, 0, "no parse errors for call with expression args")
    local fn = get_first_function(ast)
    local stmt = fn.body[1]
    assert_eq(#stmt.arguments, 2, "two arguments")
    assert_eq(stmt.arguments[1].type, AST.BINARY_EXPR, "first arg is expression")
    assert_eq(stmt.arguments[2].type, AST.CALL_EXPR, "second arg is call expression")
end
-- }}}

-- ============================================================================
-- IF Statement Tests
-- ============================================================================

print("--- IF Statement Tests ---")

-- {{{ test: simple if/then/endif
do
    local ast, errors = parse_function_body([[
if x > 0 then
    set y = 1
endif
]])
    assert_eq(#errors, 0, "no parse errors for simple if")
    local fn = get_first_function(ast)
    local stmt = fn.body[1]
    assert_eq(stmt.type, AST.IF_STMT, "statement is IF_STMT")
    assert_not_nil(stmt.condition, "has condition")
    assert_eq(#stmt.then_branch, 1, "one statement in then branch")
    assert_eq(#stmt.elseif_branches, 0, "no elseif branches")
    assert_nil(stmt.else_branch, "no else branch")
end
-- }}}

-- {{{ test: if/then/else/endif
do
    local ast, errors = parse_function_body([[
if x > 0 then
    set y = 1
else
    set y = 0
endif
]])
    assert_eq(#errors, 0, "no parse errors for if/else")
    local fn = get_first_function(ast)
    local stmt = fn.body[1]
    assert_eq(#stmt.then_branch, 1, "one statement in then branch")
    assert_not_nil(stmt.else_branch, "has else branch")
    assert_eq(#stmt.else_branch, 1, "one statement in else branch")
end
-- }}}

-- {{{ test: if/then/elseif/then/endif
do
    local ast, errors = parse_function_body([[
if x > 0 then
    set y = 1
elseif x < 0 then
    set y = -1
endif
]])
    assert_eq(#errors, 0, "no parse errors for if/elseif")
    local fn = get_first_function(ast)
    local stmt = fn.body[1]
    assert_eq(#stmt.elseif_branches, 1, "one elseif branch")
    assert_not_nil(stmt.elseif_branches[1].condition, "elseif has condition")
    assert_eq(#stmt.elseif_branches[1].body, 1, "one statement in elseif body")
end
-- }}}

-- {{{ test: multiple elseif branches
do
    local ast, errors = parse_function_body([[
if x == 1 then
    call One()
elseif x == 2 then
    call Two()
elseif x == 3 then
    call Three()
else
    call Other()
endif
]])
    assert_eq(#errors, 0, "no parse errors for multiple elseif")
    local fn = get_first_function(ast)
    local stmt = fn.body[1]
    assert_eq(#stmt.elseif_branches, 2, "two elseif branches")
    assert_not_nil(stmt.else_branch, "has else branch")
end
-- }}}

-- {{{ test: empty if body
do
    local ast, errors = parse_function_body([[
if false then
endif
]])
    assert_eq(#errors, 0, "no parse errors for empty if body")
    local fn = get_first_function(ast)
    local stmt = fn.body[1]
    assert_eq(#stmt.then_branch, 0, "empty then branch")
end
-- }}}

-- {{{ test: nested if statements
do
    local ast, errors = parse_function_body([[
if a then
    if b then
        call Inner()
    endif
endif
]])
    assert_eq(#errors, 0, "no parse errors for nested if")
    local fn = get_first_function(ast)
    local outer = fn.body[1]
    assert_eq(outer.type, AST.IF_STMT, "outer is IF_STMT")
    local inner = outer.then_branch[1]
    assert_eq(inner.type, AST.IF_STMT, "inner is IF_STMT")
end
-- }}}

-- ============================================================================
-- LOOP Statement Tests
-- ============================================================================

print("--- LOOP Statement Tests ---")

-- {{{ test: simple loop
do
    local ast, errors = parse_function_body([[
loop
    set i = i + 1
    exitwhen i >= 10
endloop
]])
    assert_eq(#errors, 0, "no parse errors for simple loop")
    local fn = get_first_function(ast)
    local stmt = fn.body[1]
    assert_eq(stmt.type, AST.LOOP_STMT, "statement is LOOP_STMT")
    assert_eq(#stmt.body, 2, "two statements in loop body")
end
-- }}}

-- {{{ test: empty loop
do
    local ast, errors = parse_function_body([[
loop
endloop
]])
    assert_eq(#errors, 0, "no parse errors for empty loop")
    local fn = get_first_function(ast)
    local stmt = fn.body[1]
    assert_eq(#stmt.body, 0, "empty loop body")
end
-- }}}

-- {{{ test: nested loops
do
    local ast, errors = parse_function_body([[
loop
    loop
        exitwhen true
    endloop
    exitwhen true
endloop
]])
    assert_eq(#errors, 0, "no parse errors for nested loops")
    local fn = get_first_function(ast)
    local outer = fn.body[1]
    assert_eq(outer.type, AST.LOOP_STMT, "outer is LOOP_STMT")
    local inner = outer.body[1]
    assert_eq(inner.type, AST.LOOP_STMT, "inner is LOOP_STMT")
end
-- }}}

-- ============================================================================
-- EXITWHEN Statement Tests
-- ============================================================================

print("--- EXITWHEN Statement Tests ---")

-- {{{ test: exitwhen with simple condition
do
    local ast, errors = parse_function_body([[
loop
    exitwhen i > 10
endloop
]])
    assert_eq(#errors, 0, "no parse errors for exitwhen")
    local fn = get_first_function(ast)
    local loop_stmt = fn.body[1]
    local exitwhen = loop_stmt.body[1]
    assert_eq(exitwhen.type, AST.EXITWHEN_STMT, "statement is EXITWHEN_STMT")
    assert_not_nil(exitwhen.condition, "has condition")
end
-- }}}

-- {{{ test: exitwhen with complex condition
do
    local ast, errors = parse_function_body([[
loop
    exitwhen i > 10 and done == true
endloop
]])
    assert_eq(#errors, 0, "no parse errors for exitwhen with complex condition")
    local fn = get_first_function(ast)
    local loop_stmt = fn.body[1]
    local exitwhen = loop_stmt.body[1]
    assert_eq(exitwhen.condition.type, AST.BINARY_EXPR, "condition is binary expression")
    assert_eq(exitwhen.condition.operator, "and", "condition uses and operator")
end
-- }}}

-- ============================================================================
-- RETURN Statement Tests
-- ============================================================================

print("--- RETURN Statement Tests ---")

-- {{{ test: return without value
do
    local ast, errors = parse_function_body("return")
    assert_eq(#errors, 0, "no parse errors for return without value")
    local fn = get_first_function(ast)
    local stmt = fn.body[1]
    assert_eq(stmt.type, AST.RETURN_STMT, "statement is RETURN_STMT")
    assert_nil(stmt.value, "no return value")
end
-- }}}

-- {{{ test: return with literal
do
    local ast, errors = parse_function_body("return 42")
    assert_eq(#errors, 0, "no parse errors for return with literal")
    local fn = get_first_function(ast)
    local stmt = fn.body[1]
    assert_eq(stmt.type, AST.RETURN_STMT, "statement is RETURN_STMT")
    assert_not_nil(stmt.value, "has return value")
    assert_eq(stmt.value.type, AST.LITERAL, "return value is literal")
end
-- }}}

-- {{{ test: return with expression
do
    local ast, errors = parse_function_body("return a + b")
    assert_eq(#errors, 0, "no parse errors for return with expression")
    local fn = get_first_function(ast)
    local stmt = fn.body[1]
    assert_eq(stmt.value.type, AST.BINARY_EXPR, "return value is expression")
end
-- }}}

-- {{{ test: return with function call
do
    local ast, errors = parse_function_body("return GetValue()")
    assert_eq(#errors, 0, "no parse errors for return with call")
    local fn = get_first_function(ast)
    local stmt = fn.body[1]
    assert_eq(stmt.value.type, AST.CALL_EXPR, "return value is call expression")
end
-- }}}

-- ============================================================================
-- LOCAL Declaration Tests
-- ============================================================================

print("--- LOCAL Declaration Tests ---")

-- {{{ test: local without initializer
do
    local ast, errors = parse_function_body("local integer i")
    assert_eq(#errors, 0, "no parse errors for local without initializer")
    local fn = get_first_function(ast)
    assert_eq(#fn.locals, 1, "one local declaration")
    local local_decl = fn.locals[1]
    assert_eq(local_decl.type, AST.LOCAL_DECL, "declaration is LOCAL_DECL")
    assert_eq(local_decl.var_type, "integer", "type is integer")
    assert_eq(local_decl.name, "i", "name is i")
    assert_nil(local_decl.initializer, "no initializer")
    assert_false(local_decl.is_array, "not an array")
end
-- }}}

-- {{{ test: local with initializer
do
    local ast, errors = parse_function_body("local real x = 1.5")
    assert_eq(#errors, 0, "no parse errors for local with initializer")
    local fn = get_first_function(ast)
    local local_decl = fn.locals[1]
    assert_eq(local_decl.var_type, "real", "type is real")
    assert_not_nil(local_decl.initializer, "has initializer")
    assert_eq(local_decl.initializer.type, AST.LITERAL, "initializer is literal")
end
-- }}}

-- {{{ test: local array
do
    local ast, errors = parse_function_body("local unit array units")
    assert_eq(#errors, 0, "no parse errors for local array")
    local fn = get_first_function(ast)
    local local_decl = fn.locals[1]
    assert_eq(local_decl.var_type, "unit", "type is unit")
    assert_eq(local_decl.name, "units", "name is units")
    assert_true(local_decl.is_array, "is array")
    assert_nil(local_decl.initializer, "no initializer for array")
end
-- }}}

-- {{{ test: multiple locals
do
    local ast, errors = parse_function_body([[
local integer i = 0
local real x
local unit u = null
]])
    assert_eq(#errors, 0, "no parse errors for multiple locals")
    local fn = get_first_function(ast)
    assert_eq(#fn.locals, 3, "three local declarations")
end
-- }}}

-- {{{ test: array initializer error
do
    local ast, errors = parse_function_body("local integer array arr = 5")
    assert_eq(#errors, 1, "one parse error for array initializer")
    assert_true(errors[1].message:find("Array variables cannot have initializers") ~= nil,
        "error message mentions array initializers")
end
-- }}}

-- ============================================================================
-- DEBUG Keyword Tests
-- ============================================================================

print("--- DEBUG Keyword Tests ---")

-- {{{ test: debug set statement
do
    local ast, errors = parse_function_body("debug set x = 5")
    assert_eq(#errors, 0, "no parse errors for debug set")
    local fn = get_first_function(ast)
    local stmt = fn.body[1]
    assert_eq(stmt.type, AST.SET_STMT, "statement is SET_STMT")
    assert_true(stmt.is_debug, "statement is marked as debug")
end
-- }}}

-- {{{ test: debug call statement
do
    local ast, errors = parse_function_body("debug call Print(\"debug\")")
    assert_eq(#errors, 0, "no parse errors for debug call")
    local fn = get_first_function(ast)
    local stmt = fn.body[1]
    assert_eq(stmt.type, AST.CALL_STMT, "statement is CALL_STMT")
    assert_true(stmt.is_debug, "statement is marked as debug")
end
-- }}}

-- ============================================================================
-- Locals After Statements Error Test
-- ============================================================================

print("--- Locals After Statements Error ---")

-- {{{ test: local after statement
do
    local ast, errors = parse_function_body([[
set x = 1
local integer y
]])
    assert_eq(#errors, 1, "one parse error for local after statement")
    assert_true(errors[1].message:find("must appear at the beginning") ~= nil,
        "error message mentions local placement")
    local fn = get_first_function(ast)
    -- Local should still be parsed and added
    assert_eq(#fn.locals, 1, "local still parsed despite error")
end
-- }}}

-- ============================================================================
-- Complex/Integration Tests
-- ============================================================================

print("--- Complex Integration Tests ---")

-- {{{ test: function with mixed statements
do
    local ast, errors = parse_function_body([[
local integer i = 0
local unit u

set i = 10
call CreateUnit(Player(0), 'hfoo', 0, 0, 0)

loop
    set i = i - 1
    if i == 5 then
        call Print("halfway")
    endif
    exitwhen i <= 0
endloop

return
]])
    assert_eq(#errors, 0, "no parse errors for complex function")
    local fn = get_first_function(ast)
    assert_eq(#fn.locals, 2, "two local declarations")
    assert_eq(#fn.body, 4, "four statements in body")
end
-- }}}

-- {{{ test: deeply nested control structures
do
    local ast, errors = parse_function_body([[
loop
    if a then
        loop
            if b then
                exitwhen true
            endif
        endloop
    else
        set x = 0
    endif
    exitwhen done
endloop
]])
    assert_eq(#errors, 0, "no parse errors for deeply nested structures")
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

--[[
Test suite for JASS-to-Lua transpiler statement transpilation (Issue 306c)

Tests all statement types: SET, CALL, IF, LOOP, EXITWHEN, RETURN
Verifies correct Lua code generation from JASS AST.
]]

-- {{{ Setup paths
local script_dir = debug.getinfo(1, "S").source:match("@(.*/)")
local project_root = script_dir:match("(.*/)[^/]+/[^/]+/$") or script_dir .. "../../"
package.path = project_root .. "src/?.lua;" .. package.path
-- }}}

-- {{{ Require modules
local lexer = require("jass.lexer")
local parser = require("jass.parser")
local transpiler = require("jass.transpiler")
-- }}}

-- {{{ Test helpers
local tests_run = 0
local tests_passed = 0

local function test(name, fn)
    tests_run = tests_run + 1
    local ok, err = pcall(fn)
    if ok then
        tests_passed = tests_passed + 1
        print(string.format("  [PASS] %s", name))
    else
        print(string.format("  [FAIL] %s", name))
        print(string.format("         %s", err))
    end
end

local function assert_eq(expected, actual, msg)
    if expected ~= actual then
        error(string.format("%s: expected %q, got %q", msg or "Mismatch", tostring(expected), tostring(actual)))
    end
end

local function assert_contains(str, pattern, msg)
    if not str:find(pattern, 1, true) then
        error(string.format("%s: expected to contain %q\n  in: %s", msg or "Not found", pattern, str))
    end
end

local function assert_not_contains(str, pattern, msg)
    if str:find(pattern, 1, true) then
        error(string.format("%s: should NOT contain %q\n  in: %s", msg or "Unexpected", pattern, str))
    end
end

-- Parse and transpile JASS code
local function transpile(jass_code)
    local tokens, lex_err = lexer.tokenize(jass_code)
    if lex_err then error("Lexer error: " .. lex_err) end

    local ast, parse_errors = parser.parse(tokens)
    if #parse_errors > 0 then
        error("Parser error: " .. parse_errors[1].message)
    end

    local lua_code, trans_errors = transpiler.transpile(ast)
    return lua_code, trans_errors, ast
end
-- }}}

-- {{{ SET Statement Tests
print("-- SET Statement Tests --")

test("simple variable assignment", function()
    local lua = transpile([[
function Test takes nothing returns nothing
    set x = 5
endfunction
]])
    assert_contains(lua, "x = 5", "simple set")
    assert_not_contains(lua, "set", "no set keyword")
end)

test("set with expression", function()
    local lua = transpile([[
function Test takes nothing returns nothing
    set result = a + b * c
endfunction
]])
    assert_contains(lua, "result =", "assignment target")
    -- Expression should be transpiled (with parens for precedence)
end)

test("array element assignment", function()
    local lua = transpile([[
function Test takes nothing returns nothing
    set arr[i] = value
endfunction
]])
    assert_contains(lua, "arr[i] = value", "array assignment")
end)

test("array with expression index", function()
    local lua = transpile([[
function Test takes nothing returns nothing
    set data[x + 1] = 42
endfunction
]])
    assert_contains(lua, "data[", "array access")
    assert_contains(lua, "] = 42", "array value")
end)
-- }}}

-- {{{ CALL Statement Tests
print("\n-- CALL Statement Tests --")

test("simple function call", function()
    local lua = transpile([[
function Test takes nothing returns nothing
    call DoSomething()
endfunction
]])
    assert_contains(lua, "DoSomething()", "function call")
    assert_not_contains(lua, "call", "no call keyword")
end)

test("function call with arguments", function()
    local lua = transpile([[
function Test takes nothing returns nothing
    call MyFunc(a, b, 42)
endfunction
]])
    assert_contains(lua, "MyFunc(a, b, 42)", "call with args")
end)

test("native function call prefixed", function()
    -- First declare a native, then call it
    local lua = transpile([[
native CreateUnit takes integer p, integer t, real x, real y, real f returns nothing
function Test takes nothing returns nothing
    call CreateUnit(0, 1, 0.0, 0.0, 0.0)
endfunction
]])
    assert_contains(lua, "runtime.CreateUnit(", "native prefixed")
end)

test("user function not prefixed", function()
    local lua = transpile([[
function MyHelper takes nothing returns nothing
endfunction
function Test takes nothing returns nothing
    call MyHelper()
endfunction
]])
    assert_contains(lua, "MyHelper()", "user func no prefix")
    assert_not_contains(lua, "runtime.MyHelper", "no runtime prefix for user func")
end)
-- }}}

-- {{{ IF Statement Tests
print("\n-- IF Statement Tests --")

test("simple if-then-endif", function()
    local lua = transpile([[
function Test takes nothing returns nothing
    if a > 0 then
        set x = 1
    endif
endfunction
]])
    assert_contains(lua, "if (a > 0) then", "if condition")
    assert_contains(lua, "x = 1", "then body")
    assert_contains(lua, "end", "end keyword")
    assert_not_contains(lua, "endif", "no endif")
end)

test("if-else", function()
    local lua = transpile([[
function Test takes nothing returns nothing
    if flag then
        set x = 1
    else
        set x = 0
    endif
endfunction
]])
    assert_contains(lua, "if flag then", "if")
    assert_contains(lua, "else", "else")
    assert_contains(lua, "x = 1", "then body")
    assert_contains(lua, "x = 0", "else body")
end)

test("if-elseif-else", function()
    local lua = transpile([[
function Test takes nothing returns nothing
    if a > 0 then
        set x = 1
    elseif a < 0 then
        set x = 2
    else
        set x = 3
    endif
endfunction
]])
    assert_contains(lua, "if (a > 0) then", "if")
    assert_contains(lua, "elseif (a < 0) then", "elseif")
    assert_contains(lua, "else", "else")
end)

test("multiple elseif", function()
    local lua = transpile([[
function Test takes nothing returns nothing
    if x == 1 then
        call A()
    elseif x == 2 then
        call B()
    elseif x == 3 then
        call C()
    endif
endfunction
]])
    local elseif_count = 0
    for _ in lua:gmatch("elseif") do
        elseif_count = elseif_count + 1
    end
    assert_eq(2, elseif_count, "elseif count")
end)

test("nested if", function()
    local lua = transpile([[
function Test takes nothing returns nothing
    if a then
        if b then
            set x = 1
        endif
    endif
endfunction
]])
    -- Should have two "if" and two "end"
    local if_count = 0
    for _ in lua:gmatch("if [^t]") do
        if_count = if_count + 1
    end
    assert_eq(2, if_count, "nested if count")
end)
-- }}}

-- {{{ LOOP Statement Tests
print("\n-- LOOP Statement Tests --")

test("simple loop", function()
    local lua = transpile([[
function Test takes nothing returns nothing
    loop
        set i = i + 1
    endloop
endfunction
]])
    assert_contains(lua, "while true do", "infinite loop pattern")
    assert_contains(lua, "i = (i + 1)", "loop body")
    assert_not_contains(lua, "endloop", "no endloop")
end)

test("loop with exitwhen", function()
    local lua = transpile([[
function Test takes nothing returns nothing
    loop
        set i = i + 1
        exitwhen i >= 10
    endloop
endfunction
]])
    assert_contains(lua, "while true do", "loop")
    assert_contains(lua, "if (i >= 10) then break end", "exitwhen")
end)

test("multiple exitwhen", function()
    local lua = transpile([[
function Test takes nothing returns nothing
    loop
        exitwhen a
        exitwhen b
    endloop
endfunction
]])
    local break_count = 0
    for _ in lua:gmatch("then break end") do
        break_count = break_count + 1
    end
    assert_eq(2, break_count, "multiple exitwhen")
end)

test("nested loops", function()
    local lua = transpile([[
function Test takes nothing returns nothing
    loop
        loop
            exitwhen inner_done
        endloop
        exitwhen outer_done
    endloop
endfunction
]])
    local while_count = 0
    for _ in lua:gmatch("while true do") do
        while_count = while_count + 1
    end
    assert_eq(2, while_count, "nested loops")
end)
-- }}}

-- {{{ RETURN Statement Tests
print("\n-- RETURN Statement Tests --")

test("return with value", function()
    local lua = transpile([[
function GetSum takes integer a, integer b returns integer
    return a + b
endfunction
]])
    assert_contains(lua, "return (a + b)", "return with expr")
end)

test("return without value", function()
    local lua = transpile([[
function DoStuff takes nothing returns nothing
    return
endfunction
]])
    -- Should have "return" without anything after (or just whitespace/newline)
    assert_contains(lua, "return", "return keyword")
end)

test("return literal", function()
    local lua = transpile([[
function Always42 takes nothing returns integer
    return 42
endfunction
]])
    assert_contains(lua, "return 42", "return literal")
end)

test("return string", function()
    local lua = transpile([[
function GetName takes nothing returns string
    return "Hello"
endfunction
]])
    assert_contains(lua, 'return "Hello"', "return string")
end)
-- }}}

-- {{{ Complex Statement Tests
print("\n-- Complex Statement Tests --")

test("function with locals and statements", function()
    local lua = transpile([[
function Complex takes integer n returns integer
    local integer i
    local integer sum
    set sum = 0
    set i = 0
    loop
        set sum = sum + i
        set i = i + 1
        exitwhen i > n
    endloop
    return sum
endfunction
]])
    assert_contains(lua, "local i = 0", "local declaration")
    assert_contains(lua, "local sum = 0", "local declaration")
    assert_contains(lua, "sum = 0", "assignment")
    assert_contains(lua, "while true do", "loop")
    assert_contains(lua, "break end", "exitwhen")
    assert_contains(lua, "return sum", "return")
end)

test("if inside loop", function()
    local lua = transpile([[
function Test takes nothing returns nothing
    loop
        if condition then
            call Action()
        endif
        exitwhen done
    endloop
endfunction
]])
    assert_contains(lua, "while true do", "loop")
    assert_contains(lua, "if condition then", "if inside loop")
    assert_contains(lua, "Action()", "call inside if")
    assert_contains(lua, "then break end", "exitwhen")
end)

test("not-equal operator", function()
    local lua = transpile([[
function Test takes nothing returns nothing
    if a != b then
        call Different()
    endif
endfunction
]])
    assert_contains(lua, "~=", "not-equal becomes ~=")
    assert_not_contains(lua, "!=", "no JASS not-equal")
end)

test("boolean literals", function()
    local lua = transpile([[
function Test takes nothing returns nothing
    if true then
        set x = false
    endif
endfunction
]])
    assert_contains(lua, "if true then", "true literal")
    assert_contains(lua, "= false", "false literal")
end)
-- }}}

-- {{{ Error Handling Tests
print("\n-- Error Handling Tests --")

test("empty function body valid", function()
    local lua, errors = transpile([[
function Empty takes nothing returns nothing
endfunction
]])
    assert_eq(0, #errors, "no errors for empty function")
end)

test("empty if branches valid", function()
    local lua, errors = transpile([[
function Test takes nothing returns nothing
    if false then
    endif
endfunction
]])
    assert_eq(0, #errors, "no errors for empty if")
end)
-- }}}

-- {{{ Summary
print(string.format("\n=== Results: %d/%d tests passed ===", tests_passed, tests_run))

if tests_passed == tests_run then
    print("All tests passed!")
    os.exit(0)
else
    print(string.format("FAILED: %d tests failed", tests_run - tests_passed))
    os.exit(1)
end
-- }}}

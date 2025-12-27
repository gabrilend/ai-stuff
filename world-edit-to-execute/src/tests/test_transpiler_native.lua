--[[
Test suite for JASS-to-Lua transpiler native function handling (Issue 306e)

Tests native detection, runtime prefixing, registry loading, and special constructs.
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
local function transpile(jass_code, options)
    local tokens, lex_err = lexer.tokenize(jass_code)
    if lex_err then error("Lexer error: " .. lex_err) end

    local ast, parse_errors = parser.parse(tokens)
    if #parse_errors > 0 then
        error("Parser error: " .. parse_errors[1].message)
    end

    local lua_code, trans_errors = transpiler.transpile(ast, options)
    return lua_code, trans_errors, ast
end
-- }}}

-- {{{ Built-in Natives Tests
print("-- Built-in Natives Tests --")

test("BUILTIN_NATIVES list is populated", function()
    local natives = transpiler._BUILTIN_NATIVES
    assert(#natives > 100, "Should have at least 100 builtin natives")
    -- Check some known natives exist
    local set = transpiler._builtin_natives_set
    assert(set["CreateUnit"], "CreateUnit should be builtin")
    assert(set["Player"], "Player should be builtin")
    assert(set["GetRandomInt"], "GetRandomInt should be builtin")
    assert(set["Condition"], "Condition should be builtin")
    assert(set["ForGroup"], "ForGroup should be builtin")
end)

test("init_builtin_natives creates registry", function()
    local registry = transpiler._init_builtin_natives()
    assert(registry["CreateUnit"], "CreateUnit should be in registry")
    assert(registry["Player"], "Player should be in registry")
    assert_eq(true, registry["CreateUnit"].is_builtin, "Should be marked as builtin")
end)

test("builtin native calls get runtime prefix", function()
    local lua = transpile([[
function Test takes nothing returns nothing
    call CreateUnit(Player(0), 'hfoo', 0, 0, 0)
endfunction
]])
    assert_contains(lua, "runtime.CreateUnit(", "CreateUnit prefixed")
    assert_contains(lua, "runtime.Player(", "Player prefixed")
end)

test("user functions do NOT get runtime prefix", function()
    local lua = transpile([[
function MyHelper takes nothing returns nothing
endfunction
function Test takes nothing returns nothing
    call MyHelper()
endfunction
]])
    assert_contains(lua, "MyHelper()", "user func no prefix")
    assert_not_contains(lua, "runtime.MyHelper", "no runtime on user func")
end)
-- }}}

-- {{{ Native Registry Loader Tests
print("\n-- Native Registry Loader Tests --")

test("load_natives_from_ast extracts natives", function()
    local tokens = lexer.tokenize([[
native CreateUnit takes player p, integer id, real x, real y, real f returns unit
native Player takes integer i returns player
function NotNative takes nothing returns nothing
endfunction
]])
    local ast = parser.parse(tokens)
    local registry = transpiler._load_natives_from_ast(ast)

    assert(registry["CreateUnit"], "CreateUnit extracted")
    assert(registry["Player"], "Player extracted")
    assert_eq(nil, registry["NotNative"], "Functions not in registry")
    assert_eq("unit", registry["CreateUnit"].return_type, "return type captured")
    assert_eq(5, #registry["CreateUnit"].params, "params captured")
end)

test("load_natives parses common.j source", function()
    local source = [[
native GetRandomInt takes integer lowBound, integer highBound returns integer
native GetRandomReal takes real lowBound, real highBound returns real
constant native Player takes integer i returns player
]]
    local registry, errors = transpiler.load_natives(source)

    assert(registry["GetRandomInt"], "GetRandomInt loaded")
    assert(registry["GetRandomReal"], "GetRandomReal loaded")
    assert(registry["Player"], "Player loaded")
    assert_eq("integer", registry["GetRandomInt"].return_type, "return type")
    assert_eq(true, registry["Player"].is_constant, "constant native")
end)

test("merge_native_registries combines registries", function()
    local reg1 = { A = { return_type = "integer" } }
    local reg2 = { B = { return_type = "real" } }
    local reg3 = { A = { return_type = "real" } }  -- Override A

    local merged = transpiler._merge_native_registries(reg1, reg2, reg3)

    assert(merged["A"], "A in merged")
    assert(merged["B"], "B in merged")
    assert_eq("real", merged["A"].return_type, "Later overrides earlier")
end)

test("custom native_registry via options", function()
    local custom_registry = {
        MyNative = { params = {}, return_type = "nothing", is_builtin = false }
    }

    local lua = transpile([[
function Test takes nothing returns nothing
    call MyNative()
    call NotANative()
endfunction
]], { native_registry = custom_registry })

    assert_contains(lua, "runtime.MyNative()", "custom native prefixed")
    assert_contains(lua, "NotANative()", "non-native not prefixed")
    assert_not_contains(lua, "runtime.NotANative", "non-native no prefix")
end)
-- }}}

-- {{{ Special Constructs Tests
print("\n-- Special Constructs Tests --")

test("Condition() is a native", function()
    local lua = transpile([[
function MyCheck takes nothing returns boolean
    return true
endfunction
function Test takes nothing returns nothing
    call TriggerAddCondition(t, Condition(function MyCheck))
endfunction
]])
    assert_contains(lua, "runtime.TriggerAddCondition(", "TriggerAddCondition prefixed")
    assert_contains(lua, "runtime.Condition(", "Condition prefixed")
end)

test("Filter() is a native", function()
    local lua = transpile([[
function MyFilter takes nothing returns boolean
    return true
endfunction
function Test takes nothing returns nothing
    local boolexpr b
    set b = Filter(function MyFilter)
endfunction
]])
    assert_contains(lua, "runtime.Filter(", "Filter prefixed")
end)

test("ForGroup callback transpiles correctly", function()
    local lua = transpile([[
function DoForUnit takes nothing returns nothing
endfunction
function Test takes nothing returns nothing
    call ForGroup(g, function DoForUnit)
endfunction
]])
    assert_contains(lua, "runtime.ForGroup(", "ForGroup prefixed")
    -- The function reference should just be the name
    assert_contains(lua, "DoForUnit)", "function reference passed")
end)

test("ExecuteFunc goes through runtime", function()
    local lua = transpile([[
function Test takes nothing returns nothing
    call ExecuteFunc("MyFunction")
endfunction
]])
    assert_contains(lua, 'runtime.ExecuteFunc("MyFunction")', "ExecuteFunc prefixed")
end)

test("function reference as code type", function()
    local lua = transpile([[
function Callback takes nothing returns nothing
endfunction
function Test takes nothing returns nothing
    call TimerStart(t, 1.0, false, function Callback)
endfunction
]])
    assert_contains(lua, "runtime.TimerStart(", "TimerStart prefixed")
    assert_contains(lua, "Callback)", "function ref as last arg")
end)
-- }}}

-- {{{ Native vs BJ Tests
print("\n-- Native vs BJ Tests --")

test("declared native gets runtime prefix", function()
    local lua = transpile([[
native CustomNative takes integer x returns nothing
function Test takes nothing returns nothing
    call CustomNative(5)
endfunction
]])
    assert_contains(lua, "runtime.CustomNative(5)", "declared native prefixed")
end)

test("BJ functions from same script not prefixed", function()
    -- BJ functions are regular JASS functions (not natives)
    local lua = transpile([[
function CreateNUnitsAtLoc takes integer n, integer t, location loc returns nothing
endfunction
function Test takes nothing returns nothing
    call CreateNUnitsAtLoc(5, 'hfoo', loc)
endfunction
]])
    -- BJ should NOT have runtime prefix (it's user-defined)
    assert_contains(lua, "CreateNUnitsAtLoc(5,", "BJ func no prefix")
    assert_not_contains(lua, "runtime.CreateNUnitsAtLoc", "BJ not runtime prefixed")
end)

test("math natives are prefixed", function()
    local lua = transpile([[
function Test takes nothing returns real
    return Cos(1.0) + Sin(2.0) + SquareRoot(4.0)
endfunction
]])
    assert_contains(lua, "runtime.Cos(", "Cos prefixed")
    assert_contains(lua, "runtime.Sin(", "Sin prefixed")
    assert_contains(lua, "runtime.SquareRoot(", "SquareRoot prefixed")
end)

test("string natives are prefixed", function()
    local lua = transpile([[
function Test takes integer n returns nothing
    call DisplayTextToPlayer(Player(0), 0, 0, I2S(n))
endfunction
]])
    assert_contains(lua, "runtime.DisplayTextToPlayer(", "Display prefixed")
    assert_contains(lua, "runtime.Player(", "Player prefixed")
    assert_contains(lua, "runtime.I2S(", "I2S prefixed")
end)
-- }}}

-- {{{ Expression Context Tests
print("\n-- Expression Context Tests --")

test("native in expression context prefixed", function()
    local lua = transpile([[
globals
    integer x = GetRandomInt(1, 10)
endglobals
]])
    assert_contains(lua, "runtime.GetRandomInt(", "native in global init")
end)

test("native in if condition prefixed", function()
    local lua = transpile([[
function Test takes nothing returns nothing
    if IsUnitType(u, UNIT_TYPE_HERO) then
        call DoSomething()
    endif
endfunction
]])
    assert_contains(lua, "runtime.IsUnitType(", "native in condition")
end)

test("native in return expression prefixed", function()
    local lua = transpile([[
function GetOwner takes unit u returns player
    return GetOwningPlayer(u)
endfunction
]])
    assert_contains(lua, "runtime.GetOwningPlayer(", "native in return")
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

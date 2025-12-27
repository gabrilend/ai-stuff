-- war3map.wtg ECA Parser Test (Issue 301d)
-- Tests ECA (Event/Condition/Action) parsing with synthetic data.
-- Run from project root: luajit src/tests/test_wtg_eca.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local wtg = require("parsers.wtg")

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

local function assert_eq(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s",
            message or "Assertion failed",
            tostring(expected),
            tostring(actual)))
    end
end

local function assert_not_nil(value, message)
    if value == nil then
        error(message or "Expected non-nil value")
    end
end

local function assert_true(value, message)
    if value ~= true then
        error(message or "Expected true")
    end
end

local function assert_false(value, message)
    if value ~= false then
        error(message or "Expected false")
    end
end
-- }}}

-- {{{ Synthetic WTG data generators
-- Pack a 32-bit unsigned integer as little-endian bytes
local function pack_uint32(n)
    local b1 = n % 256
    local b2 = math.floor(n / 256) % 256
    local b3 = math.floor(n / 65536) % 256
    local b4 = math.floor(n / 16777216) % 256
    return string.char(b1, b2, b3, b4)
end

-- Pack a 32-bit signed integer as little-endian bytes
local function pack_int32(n)
    if n < 0 then
        n = n + 4294967296  -- Convert to unsigned representation
    end
    return pack_uint32(n)
end

-- Create a simple parameter (no sub-parameters, no array)
local function make_simple_param(type_id, value)
    local parts = {}
    parts[#parts + 1] = pack_int32(type_id)       -- type
    parts[#parts + 1] = value .. "\0"             -- value
    parts[#parts + 1] = pack_uint32(0)            -- has_sub = false
    parts[#parts + 1] = pack_uint32(0)            -- is_array = false
    return table.concat(parts)
end

-- Create a simple ECA (no parameters, no children)
local function make_simple_eca(type_id, name, is_enabled)
    local parts = {}
    parts[#parts + 1] = pack_uint32(type_id)      -- type
    parts[#parts + 1] = name .. "\0"              -- function name
    parts[#parts + 1] = pack_uint32(is_enabled and 1 or 0)  -- is_enabled
    parts[#parts + 1] = pack_uint32(0)            -- param_count
    parts[#parts + 1] = pack_uint32(0)            -- child_count
    return table.concat(parts)
end

-- Create an ECA with parameters
local function make_eca_with_params(type_id, name, params)
    local parts = {}
    parts[#parts + 1] = pack_uint32(type_id)      -- type
    parts[#parts + 1] = name .. "\0"              -- function name
    parts[#parts + 1] = pack_uint32(1)            -- is_enabled = true
    parts[#parts + 1] = pack_uint32(#params)      -- param_count
    for _, p in ipairs(params) do
        parts[#parts + 1] = p
    end
    parts[#parts + 1] = pack_uint32(0)            -- child_count
    return table.concat(parts)
end

-- Create an ECA with nested children (for control flow)
local function make_eca_with_children(type_id, name, children)
    local parts = {}
    parts[#parts + 1] = pack_uint32(type_id)      -- type
    parts[#parts + 1] = name .. "\0"              -- function name
    parts[#parts + 1] = pack_uint32(1)            -- is_enabled = true
    parts[#parts + 1] = pack_uint32(0)            -- param_count
    parts[#parts + 1] = pack_uint32(#children)    -- child_count
    for _, c in ipairs(children) do
        parts[#parts + 1] = c
    end
    return table.concat(parts)
end

-- Create WTG header with no categories, no variables
local function make_wtg_header()
    local parts = {}
    parts[#parts + 1] = "WTG!"                    -- magic
    parts[#parts + 1] = pack_uint32(7)            -- version (TFT)
    parts[#parts + 1] = pack_uint32(0)            -- category count = 0
    parts[#parts + 1] = pack_uint32(0)            -- variable count = 0
    return table.concat(parts)
end

-- Create a trigger metadata block
local function make_trigger_metadata(name, desc, category, eca_count)
    local parts = {}
    parts[#parts + 1] = name .. "\0"              -- name
    parts[#parts + 1] = desc .. "\0"              -- description
    parts[#parts + 1] = pack_uint32(0)            -- is_comment = false
    parts[#parts + 1] = pack_uint32(1)            -- is_enabled = true
    parts[#parts + 1] = pack_uint32(0)            -- is_custom_text = false
    parts[#parts + 1] = pack_uint32(1)            -- is_initially_on = true
    parts[#parts + 1] = pack_uint32(0)            -- run_on_init = false
    parts[#parts + 1] = pack_uint32(category)     -- category_index
    parts[#parts + 1] = pack_uint32(eca_count)    -- eca_count
    return table.concat(parts)
end

-- Create a complete WTG with a single trigger containing specified ECAs
local function make_wtg_with_ecas(trigger_name, ecas)
    local parts = {}
    -- Header
    parts[#parts + 1] = make_wtg_header()
    -- Trigger count
    parts[#parts + 1] = pack_uint32(1)
    -- Trigger metadata
    parts[#parts + 1] = make_trigger_metadata(trigger_name, "", 0, #ecas)
    -- ECAs
    for _, eca in ipairs(ecas) do
        parts[#parts + 1] = eca
    end
    return table.concat(parts)
end
-- }}}

-- {{{ Main test suite
local function run_tests()
    print_separator("WTG ECA Parser Tests (301d)")

    -- Test 1: Parse simple event ECA
    test("Parse simple event ECA", function()
        local event = make_simple_eca(0, "TriggerRegisterTimerEventPeriodic", true)
        local data = make_wtg_with_ecas("TestTrigger", {event})

        local result, err = wtg.parse(data)
        assert_not_nil(result, "parse returned nil: " .. tostring(err))
        assert_eq(#result.triggers, 1, "trigger count")

        local trig = result.triggers[1]
        assert_eq(#trig.events, 1, "event count")
        assert_eq(#trig.conditions, 0, "condition count")
        assert_eq(#trig.actions, 0, "action count")

        local ev = trig.events[1]
        assert_eq(ev.type, "event", "ECA type")
        assert_eq(ev.name, "TriggerRegisterTimerEventPeriodic", "ECA name")
        assert_true(ev.is_enabled, "is_enabled")
        assert_eq(#ev.parameters, 0, "param count")
        assert_eq(#ev.children, 0, "child count")
    end)

    -- Test 2: Parse simple condition ECA
    test("Parse simple condition ECA", function()
        local cond = make_simple_eca(1, "IsUnitAlive", true)
        local data = make_wtg_with_ecas("TestTrigger", {cond})

        local result = wtg.parse(data)
        assert_not_nil(result, "parse returned nil")

        local trig = result.triggers[1]
        assert_eq(#trig.events, 0, "event count")
        assert_eq(#trig.conditions, 1, "condition count")
        assert_eq(#trig.actions, 0, "action count")

        local c = trig.conditions[1]
        assert_eq(c.type, "condition", "ECA type")
        assert_eq(c.name, "IsUnitAlive", "ECA name")
    end)

    -- Test 3: Parse simple action ECA
    test("Parse simple action ECA", function()
        local action = make_simple_eca(2, "CreateNUnitsAtLoc", true)
        local data = make_wtg_with_ecas("TestTrigger", {action})

        local result = wtg.parse(data)
        assert_not_nil(result, "parse returned nil")

        local trig = result.triggers[1]
        assert_eq(#trig.events, 0, "event count")
        assert_eq(#trig.conditions, 0, "condition count")
        assert_eq(#trig.actions, 1, "action count")

        local a = trig.actions[1]
        assert_eq(a.type, "action", "ECA type")
        assert_eq(a.name, "CreateNUnitsAtLoc", "ECA name")
    end)

    -- Test 4: Parse multiple ECAs of different types
    test("Parse multiple ECAs", function()
        local event = make_simple_eca(0, "TriggerRegisterEnterRectSimple", true)
        local cond = make_simple_eca(1, "CompareInteger", true)
        local action1 = make_simple_eca(2, "DisplayTextToForce", true)
        local action2 = make_simple_eca(2, "Wait", true)
        local data = make_wtg_with_ecas("TestTrigger", {event, cond, action1, action2})

        local result = wtg.parse(data)
        assert_not_nil(result, "parse returned nil")

        local trig = result.triggers[1]
        assert_eq(#trig.events, 1, "event count")
        assert_eq(#trig.conditions, 1, "condition count")
        assert_eq(#trig.actions, 2, "action count")

        assert_eq(trig.events[1].name, "TriggerRegisterEnterRectSimple", "event name")
        assert_eq(trig.conditions[1].name, "CompareInteger", "condition name")
        assert_eq(trig.actions[1].name, "DisplayTextToForce", "action1 name")
        assert_eq(trig.actions[2].name, "Wait", "action2 name")
    end)

    -- Test 5: Parse ECA with parameters
    test("Parse ECA with parameters", function()
        local param1 = make_simple_param(0, "5.00")   -- real value
        local param2 = make_simple_param(3, "Hello")  -- string value
        local action = make_eca_with_params(2, "DisplayTextToForce", {param1, param2})
        local data = make_wtg_with_ecas("TestTrigger", {action})

        local result = wtg.parse(data)
        assert_not_nil(result, "parse returned nil")

        local trig = result.triggers[1]
        assert_eq(#trig.actions, 1, "action count")

        local a = trig.actions[1]
        assert_eq(#a.parameters, 2, "param count")
        assert_eq(a.parameters[1].value, "5.00", "param1 value")
        assert_eq(a.parameters[2].value, "Hello", "param2 value")
    end)

    -- Test 6: Parse disabled ECA
    test("Parse disabled ECA", function()
        local action = make_simple_eca(2, "DisabledAction", false)
        local data = make_wtg_with_ecas("TestTrigger", {action})

        local result = wtg.parse(data)
        assert_not_nil(result, "parse returned nil")

        local trig = result.triggers[1]
        assert_eq(#trig.actions, 1, "action count")
        assert_false(trig.actions[1].is_enabled, "is_enabled should be false")
    end)

    -- Test 7: Parse nested ECAs (control flow)
    test("Parse nested ECAs", function()
        -- Create an IfThenElse with a condition and action child
        local condition_child = make_simple_eca(1, "IsUnitAlive", true)
        local action_child = make_simple_eca(2, "DoNothing", true)
        local if_then_else = make_eca_with_children(2, "IfThenElseMultiple",
            {condition_child, action_child})
        local data = make_wtg_with_ecas("TestTrigger", {if_then_else})

        local result = wtg.parse(data)
        assert_not_nil(result, "parse returned nil")

        local trig = result.triggers[1]
        assert_eq(#trig.actions, 1, "action count")

        local a = trig.actions[1]
        assert_eq(a.name, "IfThenElseMultiple", "action name")
        assert_eq(#a.children, 2, "child count")

        -- Children should be parsed with correct types
        assert_eq(a.children[1].type, "condition", "child1 type")
        assert_eq(a.children[1].name, "IsUnitAlive", "child1 name")
        assert_eq(a.children[2].type, "action", "child2 type")
        assert_eq(a.children[2].name, "DoNothing", "child2 name")
    end)

    -- Test 8: Parse deeply nested ECAs
    test("Parse deeply nested ECAs", function()
        -- Build nested structure: IfThenElse containing ForLoop containing Action
        local inner_action = make_simple_eca(2, "PlaySound", true)
        local for_loop = make_eca_with_children(2, "ForLoopAMultiple", {inner_action})
        local if_then_else = make_eca_with_children(2, "IfThenElseMultiple", {for_loop})
        local data = make_wtg_with_ecas("TestTrigger", {if_then_else})

        local result = wtg.parse(data)
        assert_not_nil(result, "parse returned nil")

        local trig = result.triggers[1]
        local a = trig.actions[1]

        assert_eq(a.name, "IfThenElseMultiple", "top level action")
        assert_eq(#a.children, 1, "top level children")
        assert_eq(a.children[1].name, "ForLoopAMultiple", "nested loop")
        assert_eq(#a.children[1].children, 1, "loop children")
        assert_eq(a.children[1].children[1].name, "PlaySound", "inner action")
    end)

    -- Test 9: parse_eca option false skips ECA parsing
    test("parse_eca=false skips ECA parsing", function()
        local action = make_simple_eca(2, "TestAction", true)
        local data = make_wtg_with_ecas("TestTrigger", {action})

        local result = wtg.parse(data, { parse_eca = false })
        assert_not_nil(result, "parse returned nil")

        local trig = result.triggers[1]
        -- ECAs should be empty when not parsed
        assert_eq(#trig.events, 0, "events should be empty")
        assert_eq(#trig.conditions, 0, "conditions should be empty")
        assert_eq(#trig.actions, 0, "actions should be empty")
        -- But eca_count should still be set
        assert_eq(trig.eca_count, 1, "eca_count should be 1")
        -- And offsets should be stored
        assert_not_nil(result._trigger_eca_offsets, "offsets should be stored")
    end)

    -- Test 10: Two-pass parsing with parse_eca_pass
    test("Two-pass parsing with parse_eca_pass", function()
        local action = make_simple_eca(2, "TwoPassAction", true)
        local data = make_wtg_with_ecas("TestTrigger", {action})

        -- First pass: metadata only
        local result = wtg.parse(data, { parse_eca = false })
        assert_not_nil(result, "first pass returned nil")
        assert_eq(#result.triggers[1].actions, 0, "actions should be empty after first pass")

        -- Second pass: parse ECAs
        result = wtg.parse_eca_pass(data, result)
        assert_not_nil(result, "second pass returned nil")
        assert_eq(#result.triggers[1].actions, 1, "action should be parsed")
        assert_eq(result.triggers[1].actions[1].name, "TwoPassAction", "action name")

        -- Offsets should be cleaned up
        assert_eq(result._trigger_eca_offsets, nil, "offsets should be nil after ECA pass")
    end)

    -- Test 11: Format function shows ECA details
    test("Format function shows ECA details", function()
        local event = make_simple_eca(0, "MapInit", true)
        local action = make_simple_eca(2, "DisplayMessage", true)
        local data = make_wtg_with_ecas("TestTrigger", {event, action})

        local result = wtg.parse(data)
        local formatted = wtg.format(result)

        assert(formatted:find("E=1 C=0 A=1"), "should show ECA counts")
        assert(formatted:find("Event: MapInit"), "should show event name")
        assert(formatted:find("Action: DisplayMessage"), "should show action name")

        print("")
        print("  --- Formatted Output ---")
        for line in formatted:gmatch("[^\n]+") do
            print("  " .. line)
        end
    end)

    -- Test 12: ECA type_id is preserved
    test("ECA type_id is preserved", function()
        local event = make_simple_eca(0, "Test", true)
        local cond = make_simple_eca(1, "Test", true)
        local action = make_simple_eca(2, "Test", true)
        local data = make_wtg_with_ecas("TestTrigger", {event, cond, action})

        local result = wtg.parse(data)
        assert_eq(result.triggers[1].events[1].type_id, 0, "event type_id")
        assert_eq(result.triggers[1].conditions[1].type_id, 1, "condition type_id")
        assert_eq(result.triggers[1].actions[1].type_id, 2, "action type_id")
    end)

    -- Test 13: Internal parse functions exposed
    test("Internal parse functions exposed", function()
        assert_not_nil(wtg._parse_single_eca, "_parse_single_eca should be exposed")
        assert_not_nil(wtg._parse_trigger_ecas, "_parse_trigger_ecas should be exposed")
        assert_not_nil(wtg._parse_parameter_placeholder, "_parse_parameter_placeholder should be exposed")
    end)

    -- Summary
    print_separator("Results")
    print(string.format("Passed: %d / %d", tests_passed, tests_run))
    if tests_passed < tests_run then
        print("SOME TESTS FAILED")
        return false
    else
        print("ALL TESTS PASSED")
        return true
    end
end
-- }}}

-- Run tests
local ok = run_tests()
os.exit(ok and 0 or 1)

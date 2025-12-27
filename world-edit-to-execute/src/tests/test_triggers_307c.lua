#!/usr/bin/env lua
--[[
Test Suite for Issue 307c: Condition and Action System

Tests the condition and action management functions:
- Condition, Filter wrappers
- TriggerAddCondition, TriggerRemoveCondition, TriggerClearConditions
- TriggerEvaluate
- TriggerAddAction, TriggerRemoveAction, TriggerClearActions
- TriggerExecute
- Trigger:fire()

Run from project root: lua src/tests/test_triggers_307c.lua
]]

-- {{{ Configuration
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path
-- }}}

-- {{{ Test framework
local passed = 0
local failed = 0
local current_test = ""

local function test(name, fn)
    current_test = name
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print(string.format("  [PASS] %s", name))
    else
        failed = failed + 1
        print(string.format("  [FAIL] %s", name))
        print(string.format("         %s", err))
    end
end

local function assert_eq(actual, expected, msg)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s",
            msg or "assertion", tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, msg)
    if not value then
        error(msg or "expected true, got false")
    end
end

local function assert_false(value, msg)
    if value then
        error(msg or "expected false, got true")
    end
end

local function assert_nil(value, msg)
    if value ~= nil then
        error(string.format("%s: expected nil, got %s", msg or "assertion", tostring(value)))
    end
end

local function assert_not_nil(value, msg)
    if value == nil then
        error(msg or "expected non-nil value")
    end
end
-- }}}

-- {{{ Load modules
local runtime = require("runtime")
local handles = runtime._handles
local triggers = runtime._triggers
-- }}}

-- ============================================================================
-- Condition/Filter Tests
-- ============================================================================

print("\n=== Condition/Filter ===")

test("Condition wraps function", function()
    runtime.reset()
    local func = function() return true end
    local cond = runtime.Condition(func)
    assert_eq(cond.type, "condition", "type is condition")
    assert_eq(cond.func, func, "func is stored")
end)

test("Condition handles non-function gracefully", function()
    runtime.reset()
    local cond = runtime.Condition("not a function")
    assert_eq(cond.type, "condition", "type is condition")
    assert_true(cond.func(), "default func returns true")
end)

test("Filter is alias for Condition", function()
    runtime.reset()
    local func = function() return false end
    local filter = runtime.Filter(func)
    assert_eq(filter.type, "condition", "type is condition")
    assert_eq(filter.func, func, "func is stored")
end)

-- ============================================================================
-- TriggerAddCondition Tests
-- ============================================================================

print("\n=== TriggerAddCondition ===")

test("TriggerAddCondition adds condition to trigger", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local cond = runtime.Condition(function() return true end)
    local tc = runtime.TriggerAddCondition(t, cond)
    assert_not_nil(tc, "returns triggercondition")
    assert_eq(#t.conditions, 1, "1 condition added")
end)

test("TriggerAddCondition registers with handle system", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local cond = runtime.Condition(function() return true end)
    local tc = runtime.TriggerAddCondition(t, cond)
    assert_true(handles.is_valid(tc), "registered with handles")
    assert_eq(tc._handle_type, "triggercondition", "correct handle type")
end)

test("TriggerAddCondition returns nil for invalid trigger", function()
    runtime.reset()
    local cond = runtime.Condition(function() return true end)
    assert_nil(runtime.TriggerAddCondition(nil, cond), "nil trigger")
    assert_nil(runtime.TriggerAddCondition({}, cond), "non-trigger")
end)

test("TriggerAddCondition returns nil for invalid condition", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    assert_nil(runtime.TriggerAddCondition(t, nil), "nil condition")
    assert_nil(runtime.TriggerAddCondition(t, {}), "non-condition")
    assert_nil(runtime.TriggerAddCondition(t, function() end), "bare function")
end)

-- ============================================================================
-- TriggerRemoveCondition Tests
-- ============================================================================

print("\n=== TriggerRemoveCondition ===")

test("TriggerRemoveCondition removes condition", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local cond = runtime.Condition(function() return true end)
    local tc = runtime.TriggerAddCondition(t, cond)
    assert_eq(#t.conditions, 1, "1 condition")
    runtime.TriggerRemoveCondition(t, tc)
    assert_eq(#t.conditions, 0, "0 conditions after remove")
end)

test("TriggerRemoveCondition destroys handle", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local cond = runtime.Condition(function() return true end)
    local tc = runtime.TriggerAddCondition(t, cond)
    runtime.TriggerRemoveCondition(t, tc)
    assert_false(handles.is_valid(tc), "handle destroyed")
end)

test("TriggerRemoveCondition handles nil gracefully", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    -- Should not error
    runtime.TriggerRemoveCondition(t, nil)
    runtime.TriggerRemoveCondition(nil, nil)
end)

-- ============================================================================
-- TriggerClearConditions Tests
-- ============================================================================

print("\n=== TriggerClearConditions ===")

test("TriggerClearConditions removes all conditions", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    runtime.TriggerAddCondition(t, runtime.Condition(function() return true end))
    runtime.TriggerAddCondition(t, runtime.Condition(function() return true end))
    runtime.TriggerAddCondition(t, runtime.Condition(function() return true end))
    assert_eq(#t.conditions, 3, "3 conditions")
    runtime.TriggerClearConditions(t)
    assert_eq(#t.conditions, 0, "0 conditions after clear")
end)

test("TriggerClearConditions destroys all handles", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local tc1 = runtime.TriggerAddCondition(t, runtime.Condition(function() return true end))
    local tc2 = runtime.TriggerAddCondition(t, runtime.Condition(function() return true end))
    runtime.TriggerClearConditions(t)
    assert_false(handles.is_valid(tc1), "tc1 destroyed")
    assert_false(handles.is_valid(tc2), "tc2 destroyed")
end)

test("TriggerClearConditions handles nil gracefully", function()
    runtime.reset()
    -- Should not error
    runtime.TriggerClearConditions(nil)
end)

-- ============================================================================
-- TriggerEvaluate Tests
-- ============================================================================

print("\n=== TriggerEvaluate ===")

test("TriggerEvaluate returns true for no conditions", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    assert_true(runtime.TriggerEvaluate(t), "no conditions = true")
end)

test("TriggerEvaluate returns true when all conditions pass", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    runtime.TriggerAddCondition(t, runtime.Condition(function() return true end))
    runtime.TriggerAddCondition(t, runtime.Condition(function() return true end))
    assert_true(runtime.TriggerEvaluate(t), "all true = true")
end)

test("TriggerEvaluate returns false when any condition fails", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    runtime.TriggerAddCondition(t, runtime.Condition(function() return true end))
    runtime.TriggerAddCondition(t, runtime.Condition(function() return false end))
    runtime.TriggerAddCondition(t, runtime.Condition(function() return true end))
    assert_false(runtime.TriggerEvaluate(t), "one false = false")
end)

test("TriggerEvaluate returns false for disabled trigger", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    runtime.DisableTrigger(t)
    assert_false(runtime.TriggerEvaluate(t), "disabled = false")
end)

test("TriggerEvaluate returns false when condition throws", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    runtime.TriggerAddCondition(t, runtime.Condition(function() error("oops") end))
    assert_false(runtime.TriggerEvaluate(t), "error = false")
end)

test("TriggerEvaluate returns false for nil trigger", function()
    runtime.reset()
    assert_false(runtime.TriggerEvaluate(nil), "nil = false")
end)

-- ============================================================================
-- TriggerAddAction Tests
-- ============================================================================

print("\n=== TriggerAddAction ===")

test("TriggerAddAction adds action to trigger", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local ta = runtime.TriggerAddAction(t, function() end)
    assert_not_nil(ta, "returns triggeraction")
    assert_eq(#t.actions, 1, "1 action added")
end)

test("TriggerAddAction registers with handle system", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local ta = runtime.TriggerAddAction(t, function() end)
    assert_true(handles.is_valid(ta), "registered with handles")
    assert_eq(ta._handle_type, "triggeraction", "correct handle type")
end)

test("TriggerAddAction returns nil for invalid trigger", function()
    runtime.reset()
    assert_nil(runtime.TriggerAddAction(nil, function() end), "nil trigger")
    assert_nil(runtime.TriggerAddAction({}, function() end), "non-trigger")
end)

test("TriggerAddAction returns nil for invalid function", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    assert_nil(runtime.TriggerAddAction(t, nil), "nil function")
    assert_nil(runtime.TriggerAddAction(t, "not a function"), "string")
end)

-- ============================================================================
-- TriggerRemoveAction Tests
-- ============================================================================

print("\n=== TriggerRemoveAction ===")

test("TriggerRemoveAction removes action", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local ta = runtime.TriggerAddAction(t, function() end)
    assert_eq(#t.actions, 1, "1 action")
    runtime.TriggerRemoveAction(t, ta)
    assert_eq(#t.actions, 0, "0 actions after remove")
end)

test("TriggerRemoveAction destroys handle", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local ta = runtime.TriggerAddAction(t, function() end)
    runtime.TriggerRemoveAction(t, ta)
    assert_false(handles.is_valid(ta), "handle destroyed")
end)

test("TriggerRemoveAction handles nil gracefully", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    -- Should not error
    runtime.TriggerRemoveAction(t, nil)
    runtime.TriggerRemoveAction(nil, nil)
end)

-- ============================================================================
-- TriggerClearActions Tests
-- ============================================================================

print("\n=== TriggerClearActions ===")

test("TriggerClearActions removes all actions", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    runtime.TriggerAddAction(t, function() end)
    runtime.TriggerAddAction(t, function() end)
    runtime.TriggerAddAction(t, function() end)
    assert_eq(#t.actions, 3, "3 actions")
    runtime.TriggerClearActions(t)
    assert_eq(#t.actions, 0, "0 actions after clear")
end)

test("TriggerClearActions destroys all handles", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local ta1 = runtime.TriggerAddAction(t, function() end)
    local ta2 = runtime.TriggerAddAction(t, function() end)
    runtime.TriggerClearActions(t)
    assert_false(handles.is_valid(ta1), "ta1 destroyed")
    assert_false(handles.is_valid(ta2), "ta2 destroyed")
end)

test("TriggerClearActions handles nil gracefully", function()
    runtime.reset()
    -- Should not error
    runtime.TriggerClearActions(nil)
end)

-- ============================================================================
-- TriggerExecute Tests
-- ============================================================================

print("\n=== TriggerExecute ===")

test("TriggerExecute runs all actions", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local count = 0
    runtime.TriggerAddAction(t, function() count = count + 1 end)
    runtime.TriggerAddAction(t, function() count = count + 10 end)
    runtime.TriggerExecute(t)
    assert_eq(count, 11, "both actions ran")
end)

test("TriggerExecute skips conditions", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    -- Add condition that returns false
    runtime.TriggerAddCondition(t, runtime.Condition(function() return false end))
    local ran = false
    runtime.TriggerAddAction(t, function() ran = true end)
    runtime.TriggerExecute(t)
    assert_true(ran, "action ran despite false condition")
end)

test("TriggerExecute does nothing for disabled trigger", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    runtime.DisableTrigger(t)
    local ran = false
    runtime.TriggerAddAction(t, function() ran = true end)
    runtime.TriggerExecute(t)
    assert_false(ran, "action did not run")
end)

test("TriggerExecute increments exec count", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    runtime.TriggerAddAction(t, function() end)
    assert_eq(runtime.TriggerGetExecCount(t), 0, "initial count")
    runtime.TriggerExecute(t)
    assert_eq(runtime.TriggerGetExecCount(t), 1, "count after execute")
end)

test("TriggerExecute continues after action error", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local ran = false
    runtime.TriggerAddAction(t, function() error("oops") end)
    runtime.TriggerAddAction(t, function() ran = true end)
    runtime.TriggerExecute(t)
    assert_true(ran, "second action ran after first error")
end)

test("TriggerExecute stops if trigger destroyed mid-execution", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local second_ran = false
    runtime.TriggerAddAction(t, function() runtime.DestroyTrigger(t) end)
    runtime.TriggerAddAction(t, function() second_ran = true end)
    runtime.TriggerExecute(t)
    assert_false(second_ran, "second action did not run after destroy")
end)

test("TriggerExecute handles nil gracefully", function()
    runtime.reset()
    -- Should not error
    runtime.TriggerExecute(nil)
end)

-- ============================================================================
-- Trigger:fire Tests
-- ============================================================================

print("\n=== Trigger:fire ===")

test("fire evaluates conditions then runs actions", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local condition_checked = false
    local action_ran = false
    runtime.TriggerAddCondition(t, runtime.Condition(function()
        condition_checked = true
        return true
    end))
    runtime.TriggerAddAction(t, function() action_ran = true end)
    local result = t:fire({})
    assert_true(condition_checked, "condition evaluated")
    assert_true(action_ran, "action ran")
    assert_true(result, "fire returned true")
end)

test("fire does not run actions if condition fails", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local action_ran = false
    runtime.TriggerAddCondition(t, runtime.Condition(function() return false end))
    runtime.TriggerAddAction(t, function() action_ran = true end)
    local result = t:fire({})
    assert_false(action_ran, "action did not run")
    assert_false(result, "fire returned false")
end)

test("fire returns false for disabled trigger", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    runtime.DisableTrigger(t)
    local action_ran = false
    runtime.TriggerAddAction(t, function() action_ran = true end)
    local result = t:fire({})
    assert_false(action_ran, "action did not run")
    assert_false(result, "fire returned false")
end)

test("fire returns false for destroyed trigger", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    runtime.DestroyTrigger(t)
    local result = t:fire({})
    assert_false(result, "fire returned false")
end)

test("fire stores event_data temporarily", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local captured_data = nil
    runtime.TriggerAddAction(t, function()
        captured_data = t._event_data
    end)
    t:fire({unit = "test_unit", player = "test_player"})
    -- After fire, event_data should be cleared
    assert_nil(t._event_data, "event_data cleared after fire")
end)

test("fire increments exec count on success", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    runtime.TriggerAddAction(t, function() end)
    t:fire({})
    assert_eq(runtime.TriggerGetExecCount(t), 1, "count incremented")
end)

test("fire does not increment exec count on condition failure", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    runtime.TriggerAddCondition(t, runtime.Condition(function() return false end))
    runtime.TriggerAddAction(t, function() end)
    t:fire({})
    assert_eq(runtime.TriggerGetExecCount(t), 0, "count not incremented")
end)

-- ============================================================================
-- Integration Tests
-- ============================================================================

print("\n=== Integration ===")

test("Full trigger flow: condition + action", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local threshold = 5
    local value = 10
    local result_msg = nil

    runtime.TriggerAddCondition(t, runtime.Condition(function()
        return value > threshold
    end))

    runtime.TriggerAddAction(t, function()
        result_msg = "Value " .. value .. " exceeded threshold " .. threshold
    end)

    local success = t:fire({})
    assert_true(success, "trigger fired successfully")
    assert_eq(result_msg, "Value 10 exceeded threshold 5", "action ran with correct message")
end)

test("Multiple conditions with AND logic", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local value = 10
    local results = {}

    runtime.TriggerAddCondition(t, runtime.Condition(function()
        results[#results + 1] = "cond1"
        return value > 5
    end))
    runtime.TriggerAddCondition(t, runtime.Condition(function()
        results[#results + 1] = "cond2"
        return value < 20
    end))
    runtime.TriggerAddCondition(t, runtime.Condition(function()
        results[#results + 1] = "cond3"
        return value == 10
    end))

    runtime.TriggerAddAction(t, function()
        results[#results + 1] = "action"
    end)

    t:fire({})
    assert_eq(#results, 4, "all conditions + action evaluated")
    assert_eq(results[1], "cond1")
    assert_eq(results[2], "cond2")
    assert_eq(results[3], "cond3")
    assert_eq(results[4], "action")
end)

test("Condition short-circuit on first failure", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local results = {}

    runtime.TriggerAddCondition(t, runtime.Condition(function()
        results[#results + 1] = "cond1"
        return true
    end))
    runtime.TriggerAddCondition(t, runtime.Condition(function()
        results[#results + 1] = "cond2"
        return false  -- Fails here
    end))
    runtime.TriggerAddCondition(t, runtime.Condition(function()
        results[#results + 1] = "cond3"
        return true
    end))

    runtime.TriggerAddAction(t, function()
        results[#results + 1] = "action"
    end)

    t:fire({})
    -- Should stop after cond2 fails
    assert_eq(#results, 2, "stopped after first failure")
    assert_eq(results[1], "cond1")
    assert_eq(results[2], "cond2")
end)

test("Multiple actions execute in order", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local order = {}

    runtime.TriggerAddAction(t, function() order[#order + 1] = "first" end)
    runtime.TriggerAddAction(t, function() order[#order + 1] = "second" end)
    runtime.TriggerAddAction(t, function() order[#order + 1] = "third" end)

    t:fire({})
    assert_eq(#order, 3, "3 actions ran")
    assert_eq(order[1], "first")
    assert_eq(order[2], "second")
    assert_eq(order[3], "third")
end)

-- ============================================================================
-- Results
-- ============================================================================

print("")
print(string.rep("=", 60))
print(string.format("=== Results: %d/%d tests passed ===", passed, passed + failed))
print(string.rep("=", 60))

if failed > 0 then
    os.exit(1)
else
    print("\nALL 307c TESTS PASSED!")
    os.exit(0)
end

#!/usr/bin/env lua
--[[
Test Suite for Issue 307b: Trigger Lifecycle API

Tests the trigger lifecycle functions:
- CreateTrigger, DestroyTrigger
- EnableTrigger, DisableTrigger, IsTriggerEnabled
- ResetTrigger, TriggerGetExecCount

Run from project root: lua src/tests/test_triggers_307b.lua
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
-- CreateTrigger Tests
-- ============================================================================

print("\n=== CreateTrigger ===")

test("CreateTrigger returns a trigger", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    assert_not_nil(t, "trigger created")
    assert_true(triggers.is_trigger(t), "is a trigger")
end)

test("CreateTrigger returns enabled trigger", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    assert_true(t.enabled, "trigger enabled")
end)

test("CreateTrigger assigns unique handle IDs", function()
    runtime.reset()
    local t1 = runtime.CreateTrigger()
    local t2 = runtime.CreateTrigger()
    assert_true(t1._handle_id ~= t2._handle_id, "different handle IDs")
end)

test("CreateTrigger registers with handle system", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    assert_true(handles.is_valid(t), "registered with handles")
end)

-- ============================================================================
-- DestroyTrigger Tests
-- ============================================================================

print("\n=== DestroyTrigger ===")

test("DestroyTrigger makes trigger invalid", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    assert_true(t:is_valid(), "valid before destroy")
    runtime.DestroyTrigger(t)
    assert_false(t:is_valid(), "invalid after destroy")
end)

test("DestroyTrigger disables trigger", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    runtime.DestroyTrigger(t)
    assert_false(t.enabled, "disabled after destroy")
end)

test("DestroyTrigger clears conditions", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    -- Add a fake condition entry
    t.conditions[1] = {func = function() return true end}
    runtime.DestroyTrigger(t)
    assert_eq(#t.conditions, 0, "conditions cleared")
end)

test("DestroyTrigger clears actions", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    -- Add a fake action entry
    t.actions[1] = {func = function() end}
    runtime.DestroyTrigger(t)
    assert_eq(#t.actions, 0, "actions cleared")
end)

test("DestroyTrigger clears events", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local unregistered = false
    t.events[1] = {
        type = "test",
        unregister = function() unregistered = true end
    }
    runtime.DestroyTrigger(t)
    assert_eq(#t.events, 0, "events cleared")
    assert_true(unregistered, "unregister called")
end)

test("DestroyTrigger handles nil gracefully", function()
    runtime.reset()
    -- Should not error
    runtime.DestroyTrigger(nil)
end)

test("DestroyTrigger handles non-trigger gracefully", function()
    runtime.reset()
    -- Should not error
    runtime.DestroyTrigger({})
    runtime.DestroyTrigger("not a trigger")
    runtime.DestroyTrigger(123)
end)

test("DestroyTrigger handles already-destroyed trigger", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    runtime.DestroyTrigger(t)
    -- Second destroy should not error
    runtime.DestroyTrigger(t)
end)

test("DestroyTrigger removes from handle system", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local id = t._handle_id
    runtime.DestroyTrigger(t)
    assert_nil(handles.get_by_id(id), "removed from registry")
end)

-- ============================================================================
-- EnableTrigger Tests
-- ============================================================================

print("\n=== EnableTrigger ===")

test("EnableTrigger sets enabled to true", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    t.enabled = false
    runtime.EnableTrigger(t)
    assert_true(t.enabled, "enabled after EnableTrigger")
end)

test("EnableTrigger handles nil gracefully", function()
    runtime.reset()
    -- Should not error
    runtime.EnableTrigger(nil)
end)

test("EnableTrigger handles non-trigger gracefully", function()
    runtime.reset()
    -- Should not error
    runtime.EnableTrigger({})
end)

test("EnableTrigger handles destroyed trigger", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    runtime.DestroyTrigger(t)
    -- Should not error or change state
    runtime.EnableTrigger(t)
    assert_false(t.enabled, "stays disabled when destroyed")
end)

-- ============================================================================
-- DisableTrigger Tests
-- ============================================================================

print("\n=== DisableTrigger ===")

test("DisableTrigger sets enabled to false", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    assert_true(t.enabled, "enabled initially")
    runtime.DisableTrigger(t)
    assert_false(t.enabled, "disabled after DisableTrigger")
end)

test("DisableTrigger handles nil gracefully", function()
    runtime.reset()
    -- Should not error
    runtime.DisableTrigger(nil)
end)

test("DisableTrigger handles non-trigger gracefully", function()
    runtime.reset()
    -- Should not error
    runtime.DisableTrigger({})
end)

test("DisableTrigger handles destroyed trigger", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    runtime.DestroyTrigger(t)
    -- Should not error
    runtime.DisableTrigger(t)
end)

-- ============================================================================
-- IsTriggerEnabled Tests
-- ============================================================================

print("\n=== IsTriggerEnabled ===")

test("IsTriggerEnabled returns true for enabled trigger", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    assert_true(runtime.IsTriggerEnabled(t), "enabled trigger returns true")
end)

test("IsTriggerEnabled returns false for disabled trigger", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    runtime.DisableTrigger(t)
    assert_false(runtime.IsTriggerEnabled(t), "disabled trigger returns false")
end)

test("IsTriggerEnabled returns false for nil", function()
    runtime.reset()
    assert_false(runtime.IsTriggerEnabled(nil), "nil returns false")
end)

test("IsTriggerEnabled returns false for non-trigger", function()
    runtime.reset()
    assert_false(runtime.IsTriggerEnabled({}), "non-trigger returns false")
end)

test("IsTriggerEnabled returns false for destroyed trigger", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    runtime.DestroyTrigger(t)
    assert_false(runtime.IsTriggerEnabled(t), "destroyed trigger returns false")
end)

-- ============================================================================
-- ResetTrigger Tests
-- ============================================================================

print("\n=== ResetTrigger ===")

test("ResetTrigger clears wait state", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    t._wait_state = {some = "data"}
    runtime.ResetTrigger(t)
    assert_nil(t._wait_state, "wait state cleared")
end)

test("ResetTrigger handles nil gracefully", function()
    runtime.reset()
    -- Should not error
    runtime.ResetTrigger(nil)
end)

test("ResetTrigger handles non-trigger gracefully", function()
    runtime.reset()
    -- Should not error
    runtime.ResetTrigger({})
end)

test("ResetTrigger handles destroyed trigger", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    runtime.DestroyTrigger(t)
    -- Should not error
    runtime.ResetTrigger(t)
end)

-- ============================================================================
-- TriggerGetExecCount Tests
-- ============================================================================

print("\n=== TriggerGetExecCount ===")

test("TriggerGetExecCount returns 0 for new trigger", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    assert_eq(runtime.TriggerGetExecCount(t), 0, "initial exec count")
end)

test("TriggerGetExecCount tracks execution count", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    triggers.increment_exec_count(t)
    assert_eq(runtime.TriggerGetExecCount(t), 1, "count after 1 exec")
    triggers.increment_exec_count(t)
    triggers.increment_exec_count(t)
    assert_eq(runtime.TriggerGetExecCount(t), 3, "count after 3 execs")
end)

test("TriggerGetExecCount returns 0 for nil", function()
    runtime.reset()
    assert_eq(runtime.TriggerGetExecCount(nil), 0, "nil returns 0")
end)

test("TriggerGetExecCount returns 0 for non-trigger", function()
    runtime.reset()
    assert_eq(runtime.TriggerGetExecCount({}), 0, "non-trigger returns 0")
end)

-- ============================================================================
-- Integration Tests
-- ============================================================================

print("\n=== Integration ===")

test("Full lifecycle: create, enable/disable, destroy", function()
    runtime.reset()
    local t = runtime.CreateTrigger()

    -- Initial state
    assert_true(runtime.IsTriggerEnabled(t), "enabled initially")

    -- Disable
    runtime.DisableTrigger(t)
    assert_false(runtime.IsTriggerEnabled(t), "disabled")

    -- Re-enable
    runtime.EnableTrigger(t)
    assert_true(runtime.IsTriggerEnabled(t), "re-enabled")

    -- Destroy
    runtime.DestroyTrigger(t)
    assert_false(runtime.IsTriggerEnabled(t), "not enabled after destroy")
    assert_false(t:is_valid(), "not valid after destroy")
end)

test("Multiple triggers independent", function()
    runtime.reset()
    local t1 = runtime.CreateTrigger()
    local t2 = runtime.CreateTrigger()

    -- Disable one
    runtime.DisableTrigger(t1)
    assert_false(runtime.IsTriggerEnabled(t1), "t1 disabled")
    assert_true(runtime.IsTriggerEnabled(t2), "t2 still enabled")

    -- Destroy one
    runtime.DestroyTrigger(t1)
    assert_true(t2:is_valid(), "t2 still valid")
end)

test("Trigger count tracks correctly", function()
    runtime.reset()
    assert_eq(triggers.get_count(), 0, "0 initially")

    local t1 = runtime.CreateTrigger()
    assert_eq(triggers.get_count(), 1, "1 after create")

    local t2 = runtime.CreateTrigger()
    assert_eq(triggers.get_count(), 2, "2 after second create")

    runtime.DestroyTrigger(t1)
    assert_eq(triggers.get_count(), 1, "1 after destroy")

    runtime.DestroyTrigger(t2)
    assert_eq(triggers.get_count(), 0, "0 after all destroyed")
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
    print("\nALL 307b TESTS PASSED!")
    os.exit(0)
end

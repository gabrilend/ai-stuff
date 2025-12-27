#!/usr/bin/env lua
--[[
Test Suite for Issue 307a: Trigger Data Structure

Tests the foundational trigger data structure:
- Handle management (handles.lua)
- Trigger class (triggers.lua)
- Runtime API entry point (init.lua)

Run from project root: lua src/tests/test_triggers_307a.lua
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
local handles = require("runtime.handles")
local triggers = require("runtime.triggers")
local runtime = require("runtime")
-- }}}

-- ============================================================================
-- Handle System Tests
-- ============================================================================

print("\n=== Handle System (handles.lua) ===")

test("register assigns unique IDs", function()
    handles.reset()
    local obj1 = {}
    local obj2 = {}
    local id1 = handles.register(obj1, "test")
    local id2 = handles.register(obj2, "test")
    assert_eq(id1, 1, "first handle ID")
    assert_eq(id2, 2, "second handle ID")
end)

test("register stores type on object", function()
    handles.reset()
    local obj = {}
    handles.register(obj, "mytrigger")
    assert_eq(obj._handle_type, "mytrigger", "handle type")
    assert_eq(obj._handle_id, 1, "handle id")
end)

test("get_id returns correct ID", function()
    handles.reset()
    local obj = {}
    local id = handles.register(obj, "test")
    assert_eq(handles.get_id(obj), id, "get_id matches register return")
end)

test("get_by_id returns correct object", function()
    handles.reset()
    local obj = {}
    local id = handles.register(obj, "test")
    assert_eq(handles.get_by_id(id), obj, "get_by_id returns object")
end)

test("is_valid returns true for registered object", function()
    handles.reset()
    local obj = {}
    handles.register(obj, "test")
    assert_true(handles.is_valid(obj), "registered object is valid")
end)

test("is_valid returns false for nil", function()
    assert_false(handles.is_valid(nil), "nil is not valid")
end)

test("is_valid returns false for unregistered object", function()
    handles.reset()
    local obj = {}
    assert_false(handles.is_valid(obj), "unregistered object is not valid")
end)

test("destroy makes object invalid", function()
    handles.reset()
    local obj = {}
    handles.register(obj, "test")
    assert_true(handles.is_valid(obj), "valid before destroy")
    handles.destroy(obj)
    assert_false(handles.is_valid(obj), "invalid after destroy")
end)

test("destroy removes from registry", function()
    handles.reset()
    local obj = {}
    local id = handles.register(obj, "test")
    handles.destroy(obj)
    assert_nil(handles.get_by_id(id), "get_by_id returns nil after destroy")
    assert_nil(handles.get_id(obj), "get_id returns nil after destroy")
end)

test("get_type returns type name", function()
    handles.reset()
    local obj = {}
    handles.register(obj, "trigger")
    assert_eq(handles.get_type(obj), "trigger", "get_type")
end)

test("get_type returns nil for nil", function()
    assert_nil(handles.get_type(nil), "get_type of nil")
end)

test("get_stats returns correct counts", function()
    handles.reset()
    local stats1 = handles.get_stats()
    assert_eq(stats1.count, 0, "initial count")
    assert_eq(stats1.next_id, 1, "initial next_id")

    local obj1 = {}
    local obj2 = {}
    handles.register(obj1, "a")
    handles.register(obj2, "b")

    local stats2 = handles.get_stats()
    assert_eq(stats2.count, 2, "count after 2 registers")
    assert_eq(stats2.next_id, 3, "next_id after 2 registers")

    handles.destroy(obj1)
    local stats3 = handles.get_stats()
    assert_eq(stats3.count, 1, "count after destroy")
end)

test("reset clears all state", function()
    handles.reset()
    local obj = {}
    handles.register(obj, "test")
    handles.reset()
    assert_false(handles.is_valid(obj), "object invalid after reset")
    local stats = handles.get_stats()
    assert_eq(stats.count, 0, "count after reset")
    assert_eq(stats.next_id, 1, "next_id after reset")
end)

-- ============================================================================
-- Trigger Class Tests
-- ============================================================================

print("\n=== Trigger Class (triggers.lua) ===")

test("Trigger.new creates trigger with correct structure", function()
    handles.reset()
    triggers.reset()
    local t = triggers.Trigger.new()
    assert_not_nil(t, "trigger created")
    assert_true(t.enabled, "enabled by default")
    assert_eq(#t.conditions, 0, "empty conditions")
    assert_eq(#t.actions, 0, "empty actions")
    assert_eq(#t.events, 0, "empty events")
end)

test("Trigger.new assigns handle ID", function()
    handles.reset()
    triggers.reset()
    local t = triggers.Trigger.new()
    assert_not_nil(t._handle_id, "has handle ID")
    assert_eq(t._handle_type, "trigger", "handle type is trigger")
end)

test("Trigger.new registers with handle system", function()
    handles.reset()
    triggers.reset()
    local t = triggers.Trigger.new()
    assert_true(handles.is_valid(t), "registered with handles")
    assert_eq(handles.get_by_id(t._handle_id), t, "get_by_id works")
end)

test("Trigger:is_valid returns true for new trigger", function()
    handles.reset()
    triggers.reset()
    local t = triggers.Trigger.new()
    assert_true(t:is_valid(), "new trigger is valid")
end)

test("Trigger:is_valid returns false after destroy", function()
    handles.reset()
    triggers.reset()
    local t = triggers.Trigger.new()
    handles.destroy(t)
    assert_false(t:is_valid(), "destroyed trigger is invalid")
end)

test("Trigger.__tostring shows useful info", function()
    handles.reset()
    triggers.reset()
    local t = triggers.Trigger.new()
    local str = tostring(t)
    assert_true(str:find("Trigger<"), "contains Trigger<")
    assert_true(str:find("enabled"), "shows enabled status")
    assert_true(str:find("0 cond"), "shows condition count")
    assert_true(str:find("0 act"), "shows action count")
end)

test("Trigger.__tostring shows disabled", function()
    handles.reset()
    triggers.reset()
    local t = triggers.Trigger.new()
    t.enabled = false
    local str = tostring(t)
    assert_true(str:find("disabled"), "shows disabled status")
end)

test("Trigger.__tostring shows destroyed", function()
    handles.reset()
    triggers.reset()
    local t = triggers.Trigger.new()
    handles.destroy(t)
    local str = tostring(t)
    assert_true(str:find("destroyed"), "shows destroyed status")
end)

test("triggers.is_trigger returns true for Trigger", function()
    handles.reset()
    triggers.reset()
    local t = triggers.Trigger.new()
    assert_true(triggers.is_trigger(t), "Trigger is recognized")
end)

test("triggers.is_trigger returns false for non-trigger", function()
    assert_false(triggers.is_trigger({}), "plain table not trigger")
    assert_false(triggers.is_trigger(nil), "nil not trigger")
    assert_false(triggers.is_trigger("string"), "string not trigger")
    assert_false(triggers.is_trigger(123), "number not trigger")
end)

test("triggers.get_all returns active triggers", function()
    handles.reset()
    triggers.reset()
    local t1 = triggers.Trigger.new()
    local t2 = triggers.Trigger.new()
    local all = triggers.get_all()
    assert_eq(#all, 2, "2 active triggers")
end)

test("triggers.get_all excludes destroyed triggers", function()
    handles.reset()
    triggers.reset()
    local t1 = triggers.Trigger.new()
    local t2 = triggers.Trigger.new()
    handles.destroy(t1)
    local all = triggers.get_all()
    assert_eq(#all, 1, "1 active trigger after destroy")
end)

test("triggers.get_count returns correct count", function()
    handles.reset()
    triggers.reset()
    assert_eq(triggers.get_count(), 0, "initially 0")
    local t1 = triggers.Trigger.new()
    assert_eq(triggers.get_count(), 1, "1 after create")
    local t2 = triggers.Trigger.new()
    assert_eq(triggers.get_count(), 2, "2 after second create")
    handles.destroy(t1)
    assert_eq(triggers.get_count(), 1, "1 after destroy")
end)

test("triggers.increment_exec_count increments counter", function()
    handles.reset()
    triggers.reset()
    local t = triggers.Trigger.new()
    assert_eq(t._exec_count, 0, "initial count 0")
    triggers.increment_exec_count(t)
    assert_eq(t._exec_count, 1, "count 1 after increment")
    triggers.increment_exec_count(t)
    triggers.increment_exec_count(t)
    assert_eq(t._exec_count, 3, "count 3 after 3 increments")
end)

test("triggers.reset destroys all triggers", function()
    handles.reset()
    triggers.reset()
    local t1 = triggers.Trigger.new()
    local t2 = triggers.Trigger.new()
    triggers.reset()
    assert_false(t1:is_valid(), "t1 destroyed")
    assert_false(t2:is_valid(), "t2 destroyed")
    assert_eq(triggers.get_count(), 0, "count 0 after reset")
end)

-- ============================================================================
-- Runtime API Tests
-- ============================================================================

print("\n=== Runtime API (init.lua) ===")

test("runtime exports handles", function()
    assert_not_nil(runtime._handles, "runtime._handles exists")
    assert_eq(runtime._handles, handles, "same handles module")
end)

test("runtime exports triggers", function()
    assert_not_nil(runtime._triggers, "runtime._triggers exists")
    assert_eq(runtime._triggers, triggers, "same triggers module")
end)

test("runtime exports Trigger class", function()
    assert_not_nil(runtime._Trigger, "runtime._Trigger exists")
    assert_eq(runtime._Trigger, triggers.Trigger, "same Trigger class")
end)

test("runtime._is_trigger works", function()
    handles.reset()
    triggers.reset()
    local t = triggers.Trigger.new()
    assert_true(runtime._is_trigger(t), "recognizes trigger")
    assert_false(runtime._is_trigger({}), "rejects plain table")
end)

test("runtime.reset clears state", function()
    handles.reset()
    triggers.reset()
    local t = triggers.Trigger.new()
    runtime.reset()
    assert_false(t:is_valid(), "trigger destroyed after reset")
end)

test("runtime.get_stats returns correct info", function()
    runtime.reset()
    local stats1 = runtime.get_stats()
    assert_eq(stats1.handle_count, 0, "no handles initially")
    assert_eq(stats1.trigger_count, 0, "no triggers initially")

    local t1 = triggers.Trigger.new()
    local t2 = triggers.Trigger.new()

    local stats2 = runtime.get_stats()
    assert_eq(stats2.handle_count, 2, "2 handles")
    assert_eq(stats2.trigger_count, 2, "2 triggers")
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
    print("\nALL 307a TESTS PASSED!")
    os.exit(0)
end

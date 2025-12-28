#!/usr/bin/env lua
--[[
Test Suite for Issue 308a: Event Registry Core

Tests the event system's foundational registry operations:
- EVENT type constants
- register/unregister/fire operations
- Filter functions
- Trigger integration

Run from project root: lua src/tests/test_events_308a.lua
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

local function assert_gte(actual, expected, msg)
    if actual < expected then
        error(string.format("%s: expected >= %s, got %s",
            msg or "assertion", tostring(expected), tostring(actual)))
    end
end
-- }}}

-- {{{ Load modules
local runtime = require("runtime")
local events = runtime._events
-- }}}

-- ============================================================================
-- EVENT Constants Tests
-- ============================================================================

print("\n=== EVENT Constants ===")

test("EVENT table exists", function()
    assert_not_nil(events.EVENT, "EVENT table exists")
end)

test("EVENT table exported at runtime level", function()
    assert_not_nil(runtime.EVENT, "runtime.EVENT exists")
    assert_eq(runtime.EVENT, events.EVENT, "same reference")
end)

test("Game events defined", function()
    assert_not_nil(events.EVENT.MAP_INIT, "MAP_INIT")
    assert_not_nil(events.EVENT.GAME_START, "GAME_START")
end)

test("Timer events defined", function()
    assert_not_nil(events.EVENT.TIMER_EXPIRE, "TIMER_EXPIRE")
    assert_not_nil(events.EVENT.TIMER_PERIODIC, "TIMER_PERIODIC")
end)

test("Unit events defined", function()
    assert_not_nil(events.EVENT.UNIT_DEATH, "UNIT_DEATH")
    assert_not_nil(events.EVENT.UNIT_SPAWN, "UNIT_SPAWN")
    assert_not_nil(events.EVENT.UNIT_DAMAGED, "UNIT_DAMAGED")
    assert_not_nil(events.EVENT.UNIT_ATTACKED, "UNIT_ATTACKED")
end)

test("Spell events defined", function()
    assert_not_nil(events.EVENT.UNIT_SPELL_CHANNEL, "UNIT_SPELL_CHANNEL")
    assert_not_nil(events.EVENT.UNIT_SPELL_CAST, "UNIT_SPELL_CAST")
    assert_not_nil(events.EVENT.UNIT_SPELL_EFFECT, "UNIT_SPELL_EFFECT")
    assert_not_nil(events.EVENT.UNIT_SPELL_FINISH, "UNIT_SPELL_FINISH")
    assert_not_nil(events.EVENT.UNIT_SPELL_ENDCAST, "UNIT_SPELL_ENDCAST")
end)

test("Region events defined", function()
    assert_not_nil(events.EVENT.UNIT_ENTER_REGION, "UNIT_ENTER_REGION")
    assert_not_nil(events.EVENT.UNIT_LEAVE_REGION, "UNIT_LEAVE_REGION")
end)

test("Player events defined", function()
    assert_not_nil(events.EVENT.PLAYER_CHAT, "PLAYER_CHAT")
    assert_not_nil(events.EVENT.PLAYER_LEAVE, "PLAYER_LEAVE")
    assert_not_nil(events.EVENT.PLAYER_ALLIANCE_CHANGE, "PLAYER_ALLIANCE_CHANGE")
end)

test("Dialog events defined", function()
    assert_not_nil(events.EVENT.DIALOG_BUTTON_CLICK, "DIALOG_BUTTON_CLICK")
end)

test("Trackable events defined", function()
    assert_not_nil(events.EVENT.TRACKABLE_HIT, "TRACKABLE_HIT")
    assert_not_nil(events.EVENT.TRACKABLE_TRACK, "TRACKABLE_TRACK")
end)

test("All EVENT values are unique", function()
    local seen = {}
    for name, value in pairs(events.EVENT) do
        if seen[value] then
            error(string.format("Duplicate EVENT value: %s and %s both = %d",
                seen[value], name, value))
        end
        seen[value] = name
    end
end)

-- ============================================================================
-- Register Tests
-- ============================================================================

print("\n=== Register ===")

test("register returns listener handle", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local listener = events.register(events.EVENT.UNIT_DEATH, t)
    assert_not_nil(listener, "listener returned")
    assert_not_nil(listener.id, "has id")
    assert_eq(listener.event_type, events.EVENT.UNIT_DEATH, "event_type stored")
    assert_eq(listener.trigger, t, "trigger stored")
end)

test("register with nil event_type returns nil", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local listener = events.register(nil, t)
    assert_nil(listener, "nil returned for nil event")
end)

test("register with nil trigger returns nil", function()
    runtime.reset()
    local listener = events.register(events.EVENT.UNIT_DEATH, nil)
    assert_nil(listener, "nil returned for nil trigger")
end)

test("register stores filter function", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local filter = function(ctx) return true end
    local listener = events.register(events.EVENT.UNIT_DEATH, t, filter)
    assert_eq(listener.filter, filter, "filter stored")
end)

test("register increases listener count", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    assert_eq(events.get_listener_count(events.EVENT.UNIT_DEATH), 0, "initially 0")
    events.register(events.EVENT.UNIT_DEATH, t)
    assert_eq(events.get_listener_count(events.EVENT.UNIT_DEATH), 1, "now 1")
    events.register(events.EVENT.UNIT_DEATH, t)
    assert_eq(events.get_listener_count(events.EVENT.UNIT_DEATH), 2, "now 2")
end)

test("register adds to trigger.events for cleanup", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    assert_eq(#t.events, 0, "initially empty")
    local listener = events.register(events.EVENT.UNIT_DEATH, t)
    assert_eq(#t.events, 1, "now has 1 event entry")
    assert_eq(t.events[1].type, events.EVENT.UNIT_DEATH, "correct type")
    assert_eq(t.events[1].listener, listener, "correct listener")
end)

test("listener IDs are unique", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local l1 = events.register(events.EVENT.UNIT_DEATH, t)
    local l2 = events.register(events.EVENT.UNIT_DEATH, t)
    local l3 = events.register(events.EVENT.TIMER_EXPIRE, t)
    assert_true(l1.id ~= l2.id, "l1 != l2")
    assert_true(l2.id ~= l3.id, "l2 != l3")
    assert_true(l1.id ~= l3.id, "l1 != l3")
end)

-- ============================================================================
-- Unregister Tests
-- ============================================================================

print("\n=== Unregister ===")

test("unregister removes listener from registry", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local listener = events.register(events.EVENT.UNIT_DEATH, t)
    assert_eq(events.get_listener_count(events.EVENT.UNIT_DEATH), 1, "registered")
    events.unregister(listener)
    assert_eq(events.get_listener_count(events.EVENT.UNIT_DEATH), 0, "unregistered")
end)

test("unregister with nil is safe", function()
    runtime.reset()
    events.unregister(nil)  -- Should not error
end)

test("unregister removes correct listener", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local l1 = events.register(events.EVENT.UNIT_DEATH, t)
    local l2 = events.register(events.EVENT.UNIT_DEATH, t)
    local l3 = events.register(events.EVENT.UNIT_DEATH, t)
    assert_eq(events.get_listener_count(events.EVENT.UNIT_DEATH), 3, "3 registered")

    events.unregister(l2)
    assert_eq(events.get_listener_count(events.EVENT.UNIT_DEATH), 2, "2 after removing l2")

    -- l1 and l3 should still work (tested in fire tests)
end)

test("unregister does not touch trigger.events", function()
    -- unregister only removes from events registry, not trigger.events
    -- trigger.events cleanup happens in DestroyTrigger
    -- This avoids modification-during-iteration bugs
    runtime.reset()
    local t = runtime.CreateTrigger()
    local listener = events.register(events.EVENT.UNIT_DEATH, t)
    assert_eq(#t.events, 1, "1 event entry")
    events.unregister(listener)
    -- Stale entry remains in trigger.events but listener is gone from registry
    assert_eq(#t.events, 1, "still 1 in trigger.events")
    assert_eq(events.get_listener_count(events.EVENT.UNIT_DEATH), 0, "0 in registry")
end)

test("unregister same listener twice is safe", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local listener = events.register(events.EVENT.UNIT_DEATH, t)
    events.unregister(listener)
    events.unregister(listener)  -- Should not error
    assert_eq(events.get_listener_count(events.EVENT.UNIT_DEATH), 0, "still 0")
end)

-- ============================================================================
-- Fire Tests
-- ============================================================================

print("\n=== Fire ===")

test("fire calls trigger:fire with context", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local received_context = nil
    runtime.TriggerAddAction(t, function()
        received_context = {
            unit = runtime.GetTriggerUnit(),
            event_id = runtime.GetTriggerEventId(),
        }
    end)

    events.register(events.EVENT.UNIT_DEATH, t)
    local test_unit = {name = "test_unit"}
    events.fire(events.EVENT.UNIT_DEATH, {unit = test_unit})

    assert_not_nil(received_context, "action was called")
    assert_eq(received_context.unit, test_unit, "received correct unit")
    assert_eq(received_context.event_id, events.EVENT.UNIT_DEATH, "event_id set")
end)

test("fire with nil event_type is safe", function()
    runtime.reset()
    events.fire(nil, {})  -- Should not error
end)

test("fire with no listeners is safe", function()
    runtime.reset()
    events.fire(events.EVENT.UNIT_DEATH, {unit = {}})  -- Should not error
end)

test("fire calls all registered triggers", function()
    runtime.reset()
    local t1 = runtime.CreateTrigger()
    local t2 = runtime.CreateTrigger()
    local t3 = runtime.CreateTrigger()
    local calls = {}

    runtime.TriggerAddAction(t1, function() calls[#calls + 1] = "t1" end)
    runtime.TriggerAddAction(t2, function() calls[#calls + 1] = "t2" end)
    runtime.TriggerAddAction(t3, function() calls[#calls + 1] = "t3" end)

    events.register(events.EVENT.UNIT_DEATH, t1)
    events.register(events.EVENT.UNIT_DEATH, t2)
    events.register(events.EVENT.UNIT_DEATH, t3)

    events.fire(events.EVENT.UNIT_DEATH, {})

    assert_eq(#calls, 3, "all 3 called")
end)

test("fire only calls triggers for matching event type", function()
    runtime.reset()
    local t1 = runtime.CreateTrigger()
    local t2 = runtime.CreateTrigger()
    local calls = {}

    runtime.TriggerAddAction(t1, function() calls[#calls + 1] = "death" end)
    runtime.TriggerAddAction(t2, function() calls[#calls + 1] = "spawn" end)

    events.register(events.EVENT.UNIT_DEATH, t1)
    events.register(events.EVENT.UNIT_SPAWN, t2)

    events.fire(events.EVENT.UNIT_DEATH, {})

    assert_eq(#calls, 1, "only 1 called")
    assert_eq(calls[1], "death", "correct trigger")
end)

test("fire applies filter function", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local call_count = 0

    runtime.TriggerAddAction(t, function() call_count = call_count + 1 end)

    -- Filter that only accepts units with is_hero = true
    events.register(events.EVENT.UNIT_DEATH, t, function(ctx)
        return ctx.unit and ctx.unit.is_hero
    end)

    -- Non-hero should not fire
    events.fire(events.EVENT.UNIT_DEATH, {unit = {is_hero = false}})
    assert_eq(call_count, 0, "filter blocked non-hero")

    -- Hero should fire
    events.fire(events.EVENT.UNIT_DEATH, {unit = {is_hero = true}})
    assert_eq(call_count, 1, "filter passed hero")
end)

test("fire skips trigger if filter returns false", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local called = false

    runtime.TriggerAddAction(t, function() called = true end)
    events.register(events.EVENT.UNIT_DEATH, t, function(ctx) return false end)

    events.fire(events.EVENT.UNIT_DEATH, {})
    assert_false(called, "trigger not called when filter returns false")
end)

test("fire handles filter that throws error", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local called = false

    runtime.TriggerAddAction(t, function() called = true end)
    events.register(events.EVENT.UNIT_DEATH, t, function(ctx)
        error("filter error")
    end)

    events.fire(events.EVENT.UNIT_DEATH, {})
    assert_false(called, "trigger not called when filter errors")
end)

test("fire continues after one trigger errors", function()
    runtime.reset()
    local t1 = runtime.CreateTrigger()
    local t2 = runtime.CreateTrigger()
    local t2_called = false

    runtime.TriggerAddAction(t1, function() error("action error") end)
    runtime.TriggerAddAction(t2, function() t2_called = true end)

    events.register(events.EVENT.UNIT_DEATH, t1)
    events.register(events.EVENT.UNIT_DEATH, t2)

    events.fire(events.EVENT.UNIT_DEATH, {})
    assert_true(t2_called, "t2 called despite t1 error")
end)

test("fire handles unregister during iteration", function()
    runtime.reset()
    local t1 = runtime.CreateTrigger()
    local t2 = runtime.CreateTrigger()
    local listener1 = nil
    local calls = {}

    runtime.TriggerAddAction(t1, function()
        calls[#calls + 1] = "t1"
        -- Unregister self during fire
        if listener1 then
            events.unregister(listener1)
        end
    end)
    runtime.TriggerAddAction(t2, function() calls[#calls + 1] = "t2" end)

    listener1 = events.register(events.EVENT.UNIT_DEATH, t1)
    events.register(events.EVENT.UNIT_DEATH, t2)

    events.fire(events.EVENT.UNIT_DEATH, {})

    -- Both should have been called (list was snapshotted)
    assert_eq(#calls, 2, "both called")

    -- But now only t2 remains
    assert_eq(events.get_listener_count(events.EVENT.UNIT_DEATH), 1, "only 1 left")
end)

-- ============================================================================
-- Trigger Integration Tests
-- ============================================================================

print("\n=== Trigger Integration ===")

test("DestroyTrigger unregisters all events", function()
    runtime.reset()
    local t = runtime.CreateTrigger()

    events.register(events.EVENT.UNIT_DEATH, t)
    events.register(events.EVENT.UNIT_SPAWN, t)
    events.register(events.EVENT.TIMER_EXPIRE, t)

    assert_eq(events.get_total_listener_count(), 3, "3 registered")

    runtime.DestroyTrigger(t)

    assert_eq(events.get_total_listener_count(), 0, "0 after destroy")
end)

test("disabled trigger not fired", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local called = false

    runtime.TriggerAddAction(t, function() called = true end)
    events.register(events.EVENT.UNIT_DEATH, t)

    runtime.DisableTrigger(t)
    events.fire(events.EVENT.UNIT_DEATH, {})

    assert_false(called, "disabled trigger not fired")
end)

test("trigger conditions evaluated during fire", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local action_called = false
    local condition_value = true

    runtime.TriggerAddCondition(t, runtime.Condition(function()
        return condition_value
    end))
    runtime.TriggerAddAction(t, function() action_called = true end)

    events.register(events.EVENT.UNIT_DEATH, t)

    -- Condition true - should fire
    condition_value = true
    events.fire(events.EVENT.UNIT_DEATH, {})
    assert_true(action_called, "action called when condition true")

    -- Condition false - should not fire action
    action_called = false
    condition_value = false
    events.fire(events.EVENT.UNIT_DEATH, {})
    assert_false(action_called, "action not called when condition false")
end)

test("context available in trigger action", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local captured = {}

    runtime.TriggerAddAction(t, function()
        captured.unit = runtime.GetTriggerUnit()
        captured.player = runtime.GetTriggerPlayer()
        captured.killer = runtime.GetKillingUnit()
    end)

    events.register(events.EVENT.UNIT_DEATH, t)

    local dying = {name = "dying_unit"}
    local killer = {name = "killer_unit"}
    local player = {name = "player_1"}

    events.fire(events.EVENT.UNIT_DEATH, {
        unit = dying,
        player = player,
        killing_unit = killer,
    })

    assert_eq(captured.unit, dying, "got unit")
    assert_eq(captured.player, player, "got player")
    assert_eq(captured.killer, killer, "got killer")
end)

-- ============================================================================
-- Stats/Reset Tests
-- ============================================================================

print("\n=== Stats/Reset ===")

test("get_stats returns listener counts", function()
    runtime.reset()
    local t = runtime.CreateTrigger()

    events.register(events.EVENT.UNIT_DEATH, t)
    events.register(events.EVENT.UNIT_DEATH, t)
    events.register(events.EVENT.UNIT_SPAWN, t)

    local stats = events.get_stats()
    assert_eq(stats.total_listeners, 3, "total 3")
    assert_eq(stats.by_type[events.EVENT.UNIT_DEATH], 2, "2 death")
    assert_eq(stats.by_type[events.EVENT.UNIT_SPAWN], 1, "1 spawn")
end)

test("reset clears all listeners", function()
    runtime.reset()
    local t = runtime.CreateTrigger()

    events.register(events.EVENT.UNIT_DEATH, t)
    events.register(events.EVENT.UNIT_SPAWN, t)

    assert_eq(events.get_total_listener_count(), 2, "2 before reset")

    events.reset()

    assert_eq(events.get_total_listener_count(), 0, "0 after reset")
end)

test("runtime.reset includes events reset", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    events.register(events.EVENT.UNIT_DEATH, t)
    assert_eq(events.get_total_listener_count(), 1, "1 before")

    runtime.reset()

    assert_eq(events.get_total_listener_count(), 0, "0 after runtime.reset")
end)

test("runtime.get_stats includes event listeners", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    events.register(events.EVENT.UNIT_DEATH, t)
    events.register(events.EVENT.UNIT_SPAWN, t)

    local stats = runtime.get_stats()
    assert_eq(stats.event_listeners, 2, "2 listeners in runtime stats")
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
    print("\nALL 308a TESTS PASSED!")
    os.exit(0)
end

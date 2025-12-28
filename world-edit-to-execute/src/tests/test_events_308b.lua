#!/usr/bin/env lua
--[[
Test Suite for Issue 308b: Timer Events

Tests the timer event subsystem:
- TriggerRegisterTimerEvent
- CreateTimer/TimerStart
- Pause/Resume/Destroy timer
- Timer accessors (elapsed, remaining, timeout)
- update_timers tick processing

Run from project root: lua src/tests/test_events_308b.lua
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

local function assert_near(actual, expected, epsilon, msg)
    local diff = math.abs(actual - expected)
    if diff > epsilon then
        error(string.format("%s: expected %s +/- %s, got %s",
            msg or "assertion", tostring(expected), tostring(epsilon), tostring(actual)))
    end
end
-- }}}

-- {{{ Load modules
local runtime = require("runtime")
local events = runtime._events
-- }}}

-- ============================================================================
-- Timer Storage Tests
-- ============================================================================

print("\n=== Timer Storage ===")

test("runtime._timers exists", function()
    runtime.reset()
    assert_not_nil(runtime._timers, "_timers exists")
    assert_eq(type(runtime._timers), "table", "_timers is table")
end)

test("runtime._next_timer_id starts at 1", function()
    runtime.reset()
    assert_eq(runtime._next_timer_id, 1, "starts at 1")
end)

test("runtime.reset clears timers", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    runtime.TriggerRegisterTimerEvent(t, 1.0, false)
    assert_true(next(runtime._timers) ~= nil, "timer exists before reset")
    runtime.reset()
    assert_nil(next(runtime._timers), "empty after reset")
    assert_eq(runtime._next_timer_id, 1, "next_id reset to 1")
end)

-- ============================================================================
-- TriggerRegisterTimerEvent Tests
-- ============================================================================

print("\n=== TriggerRegisterTimerEvent ===")

test("TriggerRegisterTimerEvent returns timer object", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local timer = runtime.TriggerRegisterTimerEvent(t, 1.0, false)
    assert_not_nil(timer, "timer returned")
    assert_not_nil(timer.id, "has id")
    assert_eq(timer.trigger, t, "linked to trigger")
    assert_eq(timer.timeout, 1.0, "timeout stored")
    assert_false(timer.periodic, "not periodic")
    assert_true(timer.enabled, "enabled by default")
end)

test("TriggerRegisterTimerEvent with periodic=true", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local timer = runtime.TriggerRegisterTimerEvent(t, 0.5, true)
    assert_true(timer.periodic, "periodic flag set")
end)

test("TriggerRegisterTimerEvent with invalid trigger returns nil", function()
    runtime.reset()
    local timer = runtime.TriggerRegisterTimerEvent(nil, 1.0, false)
    assert_nil(timer, "nil for nil trigger")
    timer = runtime.TriggerRegisterTimerEvent({}, 1.0, false)
    assert_nil(timer, "nil for non-trigger")
end)

test("TriggerRegisterTimerEvent with invalid timeout returns nil", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    assert_nil(runtime.TriggerRegisterTimerEvent(t, nil, false), "nil timeout")
    assert_nil(runtime.TriggerRegisterTimerEvent(t, 0, false), "zero timeout")
    assert_nil(runtime.TriggerRegisterTimerEvent(t, -1, false), "negative timeout")
    assert_nil(runtime.TriggerRegisterTimerEvent(t, "1", false), "string timeout")
end)

test("TriggerRegisterTimerEvent stores timer in registry", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local timer = runtime.TriggerRegisterTimerEvent(t, 1.0, false)
    assert_not_nil(runtime._timers[timer.id], "in registry")
    assert_eq(runtime._timers[timer.id], timer, "correct timer")
end)

test("TriggerRegisterTimerEvent registers with event system", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local timer = runtime.TriggerRegisterTimerEvent(t, 1.0, false)
    assert_not_nil(timer.listener, "has listener")
    assert_eq(events.get_listener_count(events.EVENT.TIMER_EXPIRE), 1, "registered for expire")
end)

test("periodic timer registers for TIMER_PERIODIC event", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local timer = runtime.TriggerRegisterTimerEvent(t, 1.0, true)
    assert_eq(events.get_listener_count(events.EVENT.TIMER_PERIODIC), 1, "registered for periodic")
    assert_eq(events.get_listener_count(events.EVENT.TIMER_EXPIRE), 0, "not registered for expire")
end)

-- ============================================================================
-- CreateTimer / TimerStart Tests
-- ============================================================================

print("\n=== CreateTimer / TimerStart ===")

test("CreateTimer creates timer object", function()
    runtime.reset()
    local timer = runtime.CreateTimer()
    assert_not_nil(timer, "timer created")
    assert_not_nil(timer.id, "has id")
    assert_false(timer.enabled, "disabled by default")
    assert_eq(timer.timeout, 0, "no timeout yet")
end)

test("TimerStart configures timer", function()
    runtime.reset()
    local timer = runtime.CreateTimer()
    local callback_called = false
    runtime.TimerStart(timer, 2.0, false, function()
        callback_called = true
    end)
    assert_eq(timer.timeout, 2.0, "timeout set")
    assert_false(timer.periodic, "not periodic")
    assert_true(timer.enabled, "enabled after start")
    assert_not_nil(timer.callback, "callback stored")
end)

test("TimerStart with periodic=true", function()
    runtime.reset()
    local timer = runtime.CreateTimer()
    runtime.TimerStart(timer, 1.0, true, function() end)
    assert_true(timer.periodic, "periodic flag set")
end)

test("TimerStart resets elapsed", function()
    runtime.reset()
    local timer = runtime.CreateTimer()
    timer.elapsed = 0.5
    runtime.TimerStart(timer, 1.0, false, function() end)
    assert_eq(timer.elapsed, 0, "elapsed reset to 0")
end)

-- ============================================================================
-- Pause / Resume / Destroy Tests
-- ============================================================================

print("\n=== Pause / Resume / Destroy ===")

test("PauseTimer disables timer", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local timer = runtime.TriggerRegisterTimerEvent(t, 1.0, false)
    assert_true(timer.enabled, "enabled before pause")
    runtime.PauseTimer(timer)
    assert_false(timer.enabled, "disabled after pause")
end)

test("ResumeTimer enables timer", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local timer = runtime.TriggerRegisterTimerEvent(t, 1.0, false)
    runtime.PauseTimer(timer)
    assert_false(timer.enabled, "disabled")
    runtime.ResumeTimer(timer)
    assert_true(timer.enabled, "enabled after resume")
end)

test("Pause/Resume with nil is safe", function()
    runtime.reset()
    runtime.PauseTimer(nil)  -- Should not error
    runtime.ResumeTimer(nil)  -- Should not error
end)

test("DestroyTimer removes from registry", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local timer = runtime.TriggerRegisterTimerEvent(t, 1.0, false)
    local id = timer.id
    assert_not_nil(runtime._timers[id], "in registry before destroy")
    runtime.DestroyTimer(timer)
    assert_nil(runtime._timers[id], "removed after destroy")
end)

test("DestroyTimer unregisters from event system", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local timer = runtime.TriggerRegisterTimerEvent(t, 1.0, false)
    assert_eq(events.get_listener_count(events.EVENT.TIMER_EXPIRE), 1, "registered")
    runtime.DestroyTimer(timer)
    assert_eq(events.get_listener_count(events.EVENT.TIMER_EXPIRE), 0, "unregistered")
end)

test("DestroyTimer with nil is safe", function()
    runtime.reset()
    runtime.DestroyTimer(nil)  -- Should not error
end)

-- ============================================================================
-- Timer Accessor Tests
-- ============================================================================

print("\n=== Timer Accessors ===")

test("TimerGetElapsed returns elapsed time", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local timer = runtime.TriggerRegisterTimerEvent(t, 5.0, false)
    assert_eq(runtime.TimerGetElapsed(timer), 0, "initially 0")
    timer.elapsed = 2.5
    assert_eq(runtime.TimerGetElapsed(timer), 2.5, "returns elapsed")
end)

test("TimerGetRemaining returns time until fire", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local timer = runtime.TriggerRegisterTimerEvent(t, 5.0, false)
    assert_eq(runtime.TimerGetRemaining(timer), 5.0, "initially full timeout")
    timer.elapsed = 2.0
    assert_eq(runtime.TimerGetRemaining(timer), 3.0, "remaining decreases")
    timer.elapsed = 6.0
    assert_eq(runtime.TimerGetRemaining(timer), 0, "clamped to 0")
end)

test("TimerGetTimeout returns timeout period", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local timer = runtime.TriggerRegisterTimerEvent(t, 3.5, false)
    assert_eq(runtime.TimerGetTimeout(timer), 3.5, "returns timeout")
end)

test("IsTimerPeriodic returns periodic flag", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local one_shot = runtime.TriggerRegisterTimerEvent(t, 1.0, false)
    local periodic = runtime.TriggerRegisterTimerEvent(t, 1.0, true)
    assert_false(runtime.IsTimerPeriodic(one_shot), "one-shot not periodic")
    assert_true(runtime.IsTimerPeriodic(periodic), "periodic is periodic")
end)

test("accessors return 0/false for nil/invalid timer", function()
    runtime.reset()
    assert_eq(runtime.TimerGetElapsed(nil), 0, "nil elapsed")
    assert_eq(runtime.TimerGetRemaining(nil), 0, "nil remaining")
    assert_eq(runtime.TimerGetTimeout(nil), 0, "nil timeout")
    assert_false(runtime.IsTimerPeriodic(nil), "nil periodic")
end)

-- ============================================================================
-- update_timers Tests
-- ============================================================================

print("\n=== update_timers ===")

test("update_timers accumulates elapsed time", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local timer = runtime.TriggerRegisterTimerEvent(t, 5.0, false)
    assert_eq(timer.elapsed, 0, "initially 0")
    events.update_timers(0.1, runtime)
    assert_near(timer.elapsed, 0.1, 0.001, "after 0.1s")
    events.update_timers(0.2, runtime)
    assert_near(timer.elapsed, 0.3, 0.001, "after 0.3s total")
end)

test("update_timers does not accumulate when paused", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local timer = runtime.TriggerRegisterTimerEvent(t, 5.0, false)
    events.update_timers(0.1, runtime)
    runtime.PauseTimer(timer)
    events.update_timers(0.5, runtime)
    assert_near(timer.elapsed, 0.1, 0.001, "no change while paused")
end)

test("one-shot timer fires once then disables", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local fire_count = 0
    runtime.TriggerAddAction(t, function()
        fire_count = fire_count + 1
    end)
    local timer = runtime.TriggerRegisterTimerEvent(t, 0.5, false)

    -- Not fired yet
    events.update_timers(0.3, runtime)
    assert_eq(fire_count, 0, "not fired at 0.3s")

    -- Should fire at 0.5s
    events.update_timers(0.3, runtime)  -- Total 0.6s
    assert_eq(fire_count, 1, "fired at 0.6s")
    assert_false(timer.enabled, "disabled after fire")

    -- Should not fire again
    timer.elapsed = 0  -- Reset manually
    events.update_timers(1.0, runtime)
    assert_eq(fire_count, 1, "still 1 (disabled)")
end)

test("periodic timer fires repeatedly", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local fire_count = 0
    runtime.TriggerAddAction(t, function()
        fire_count = fire_count + 1
    end)
    local timer = runtime.TriggerRegisterTimerEvent(t, 0.5, true)

    events.update_timers(0.6, runtime)  -- Fire once
    assert_eq(fire_count, 1, "first fire")
    assert_true(timer.enabled, "still enabled")

    events.update_timers(0.5, runtime)  -- Fire again
    assert_eq(fire_count, 2, "second fire")

    events.update_timers(0.5, runtime)  -- Fire again
    assert_eq(fire_count, 3, "third fire")
end)

test("periodic timer preserves overflow", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    runtime.TriggerAddAction(t, function() end)
    local timer = runtime.TriggerRegisterTimerEvent(t, 1.0, true)

    -- Pass 1.3 seconds - should fire with 0.3 overflow
    events.update_timers(1.3, runtime)
    assert_near(timer.elapsed, 0.3, 0.001, "overflow preserved")
end)

test("timer callback is called", function()
    runtime.reset()
    local callback_count = 0
    local timer = runtime.CreateTimer()
    runtime.TimerStart(timer, 0.5, false, function()
        callback_count = callback_count + 1
    end)

    events.update_timers(0.6, runtime)
    assert_eq(callback_count, 1, "callback called")
end)

test("GetExpiredTimer returns timer in context", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local captured_timer = nil
    runtime.TriggerAddAction(t, function()
        captured_timer = runtime.GetExpiredTimer()
    end)
    local timer = runtime.TriggerRegisterTimerEvent(t, 0.5, false)

    events.update_timers(0.6, runtime)
    assert_eq(captured_timer, timer, "captured correct timer")
end)

test("update_timers handles multiple timers", function()
    runtime.reset()
    local t1 = runtime.CreateTrigger()
    local t2 = runtime.CreateTrigger()
    local fire1, fire2 = 0, 0
    runtime.TriggerAddAction(t1, function() fire1 = fire1 + 1 end)
    runtime.TriggerAddAction(t2, function() fire2 = fire2 + 1 end)

    runtime.TriggerRegisterTimerEvent(t1, 0.3, false)
    runtime.TriggerRegisterTimerEvent(t2, 0.5, false)

    events.update_timers(0.4, runtime)
    assert_eq(fire1, 1, "timer1 fired")
    assert_eq(fire2, 0, "timer2 not yet")

    events.update_timers(0.2, runtime)
    assert_eq(fire1, 1, "timer1 still 1")
    assert_eq(fire2, 1, "timer2 fired")
end)

test("update_timers with nil/invalid runtime is safe", function()
    events.update_timers(0.1, nil)  -- Should not error
    events.update_timers(0.1, {})  -- Should not error
end)

test("callback error doesn't stop timer processing", function()
    runtime.reset()
    local timer1 = runtime.CreateTimer()
    local timer2 = runtime.CreateTimer()
    local t2_called = false

    runtime.TimerStart(timer1, 0.5, false, function()
        error("callback error")
    end)
    runtime.TimerStart(timer2, 0.5, false, function()
        t2_called = true
    end)

    events.update_timers(0.6, runtime)
    assert_true(t2_called, "timer2 callback still called despite timer1 error")
end)

-- ============================================================================
-- Integration Tests
-- ============================================================================

print("\n=== Integration ===")

test("timer fires trigger with full context", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local results = {}

    runtime.TriggerAddAction(t, function()
        results.timer = runtime.GetExpiredTimer()
        results.event_id = runtime.GetTriggerEventId()
    end)

    local timer = runtime.TriggerRegisterTimerEvent(t, 0.5, false)
    events.update_timers(0.6, runtime)

    assert_eq(results.timer, timer, "got timer")
    assert_eq(results.event_id, events.EVENT.TIMER_EXPIRE, "got event id")
end)

test("runtime.get_stats includes timer count", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    runtime.TriggerRegisterTimerEvent(t, 1.0, false)
    runtime.TriggerRegisterTimerEvent(t, 2.0, true)
    runtime.CreateTimer()

    local stats = runtime.get_stats()
    assert_eq(stats.timer_count, 3, "3 timers")
end)

test("DestroyTrigger does not destroy timer", function()
    -- Timers are separate objects; destroying trigger doesn't destroy timer
    -- (but the timer's trigger reference becomes invalid)
    runtime.reset()
    local t = runtime.CreateTrigger()
    local timer = runtime.TriggerRegisterTimerEvent(t, 1.0, false)
    local timer_id = timer.id

    runtime.DestroyTrigger(t)

    -- Timer still exists in registry
    assert_not_nil(runtime._timers[timer_id], "timer still in registry")
    -- But trigger is gone
    assert_false(t:is_valid(), "trigger invalid")
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
    print("\nALL 308b TESTS PASSED!")
    os.exit(0)
end

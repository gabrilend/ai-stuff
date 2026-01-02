-- Timer Subsystem Unit Tests (401b)
-- Tests for WC3-compatible timer implementation.
-- Run with: luajit src/tests/test_timers.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local gameloop = require("runtime.gameloop")
local timers = require("runtime.timers")

-- {{{ Test utilities
local test_count = 0
local pass_count = 0

local function test(name, condition, msg)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name .. (msg and ": " .. msg or ""))
    end
end

local function test_section(name)
    print("\n=== " .. name .. " ===")
end

local function approx_eq(a, b, epsilon)
    epsilon = epsilon or 0.02  -- 2 tick tolerance
    return math.abs(a - b) < epsilon
end

local function reset_systems()
    gameloop.reset()
    timers.reset()
    timers.init()
end
-- }}}

-- {{{ Timer Creation Tests
test_section("Timer Creation")
reset_systems()

local t = timers.create()
test("Create returns timer", t ~= nil)
test("Timer has handle type", t._handle_type == "timer")
test("Timer has handle ID", t._handle_id ~= nil)
test("Timer not running", not t.running)
test("Timer not paused", not t.paused)
test("Duration is 0", t.duration == 0)

local t2 = timers.create()
test("Second timer has different ID", t2._handle_id ~= t._handle_id)
-- }}}

-- {{{ Timer Start Tests
test_section("Timer Start")
reset_systems()

local t = timers.create()
local fired = false
timers.start(t, 0.5, false, function()
    fired = true
end)

test("Timer running after start", t.running)
test("Timer in queue", timers.get_active_count() == 1)
test("Duration set", t.duration == 0.5)
test("Not periodic", not t.periodic)
test("Callback set", t.callback ~= nil)

-- Test restart
timers.start(t, 0.3, true, function() end)
test("Duration updated on restart", t.duration == 0.3)
test("Periodic updated on restart", t.periodic)
test("Still one timer in queue", timers.get_active_count() == 1)
-- }}}

-- {{{ Timer Expiration (One-Shot) Tests
test_section("Timer Expiration (One-Shot)")
reset_systems()

local fired = false
local fire_time = nil
local t = timers.create()
timers.start(t, 0.1, false, function()
    fired = true
    fire_time = gameloop.get_time()
end)

test("Not fired initially", not fired)

-- Advance time past expiration (0.1s ~= 6 ticks)
for i = 1, 10 do
    gameloop.update(0.016)
end

test("Timer fired", fired)
test("Fired at approximately correct time", fire_time ~= nil and fire_time >= 0.09)
test("Timer stopped after fire", not t.running)
test("Queue empty after one-shot", timers.get_active_count() == 0)
-- }}}

-- {{{ Timer Expiration (Periodic) Tests
test_section("Timer Expiration (Periodic)")
reset_systems()

local fire_count = 0
local fire_times = {}
local t = timers.create()
timers.start(t, 0.05, true, function()
    fire_count = fire_count + 1
    fire_times[#fire_times + 1] = gameloop.get_time()
end)

-- Advance enough for ~3-4 firings (0.2s = 12-13 ticks)
for i = 1, 15 do
    gameloop.update(0.016)
end

test("Periodic fired multiple times", fire_count >= 3, "got " .. fire_count)
test("Periodic still running", t.running)
test("Still in queue", timers.get_active_count() == 1)

-- Check approximate intervals
if #fire_times >= 2 then
    local interval = fire_times[2] - fire_times[1]
    test("Interval approximately correct", approx_eq(interval, 0.05, 0.02))
end
-- }}}

-- {{{ Timer Pause/Resume Tests
test_section("Timer Pause/Resume")
reset_systems()

local fired = false
local t = timers.create()
timers.start(t, 0.2, false, function()
    fired = true
end)

-- Advance halfway (~6 ticks = ~0.1s)
for i = 1, 6 do
    gameloop.update(0.016)
end

test("Not fired yet (halfway)", not fired)

-- Pause
timers.pause(t)
test("Timer paused", t.paused)
test("Timer still running (paused)", t.running)

local elapsed_at_pause = timers.get_elapsed(t)
test("Elapsed tracked at pause", elapsed_at_pause > 0.05)

-- Advance more (should not fire while paused)
for i = 1, 20 do
    gameloop.update(0.016)
end

test("Still not fired while paused", not fired)
test("Elapsed unchanged while paused", approx_eq(timers.get_elapsed(t), elapsed_at_pause, 0.001))

-- Resume
timers.resume(t)
test("Timer resumed", not t.paused)

-- Advance remaining time (~6 more ticks)
for i = 1, 10 do
    gameloop.update(0.016)
end

test("Fired after resume", fired)
-- }}}

-- {{{ Timer Query Tests
test_section("Timer Queries")
reset_systems()

local t = timers.create()
timers.start(t, 1.0, false, function() end)

test("Timeout is 1.0", timers.get_timeout(t) == 1.0)
test("Remaining starts at ~1.0", approx_eq(timers.get_remaining(t), 1.0))
test("Elapsed starts at ~0", approx_eq(timers.get_elapsed(t), 0))

-- Advance half second (~31 ticks)
for i = 1, 31 do
    gameloop.update(0.016)
end

local elapsed = timers.get_elapsed(t)
local remaining = timers.get_remaining(t)

test("Elapsed ~0.5", approx_eq(elapsed, 0.5, 0.05), "got " .. elapsed)
test("Remaining ~0.5", approx_eq(remaining, 0.5, 0.05), "got " .. remaining)
test("Elapsed + Remaining = Duration", approx_eq(elapsed + remaining, 1.0, 0.02))
-- }}}

-- {{{ Timer Destruction Tests
test_section("Timer Destruction")
reset_systems()

local fired = false
local t = timers.create()
timers.start(t, 0.1, false, function()
    fired = true
end)

test("Timer in queue before destroy", timers.get_active_count() == 1)

timers.destroy(t)

test("Handle ID cleared", t._handle_id == nil)
test("Handle type cleared", t._handle_type == nil)
test("Removed from queue", timers.get_active_count() == 0)

-- Advance past expiration
for i = 1, 10 do
    gameloop.update(0.016)
end

test("Destroyed timer didn't fire", not fired)
-- }}}

-- {{{ Multiple Timers Tests
test_section("Multiple Timers")
reset_systems()

local order = {}
local t1 = timers.create()
local t2 = timers.create()
local t3 = timers.create()

-- Start in different order than expiration
timers.start(t2, 0.08, false, function() order[#order + 1] = 2 end)
timers.start(t1, 0.04, false, function() order[#order + 1] = 1 end)
timers.start(t3, 0.12, false, function() order[#order + 1] = 3 end)

test("Three timers queued", timers.get_active_count() == 3)

-- Advance past all expirations
for i = 1, 10 do
    gameloop.update(0.016)
end

test("All fired", #order == 3)
test("Fired in expiration order", order[1] == 1 and order[2] == 2 and order[3] == 3,
     "got " .. table.concat(order, ","))
-- }}}

-- {{{ Priority Queue Ordering Tests
test_section("Priority Queue Ordering")
reset_systems()

-- Add timers with delays in random order
local results = {}
local delays = {0.08, 0.02, 0.06, 0.10, 0.04}

for i = 1, 5 do
    local t = timers.create()
    local idx = i  -- Capture for closure
    timers.start(t, delays[i], false, function()
        results[#results + 1] = idx
    end)
end

test("Five timers queued", timers.get_active_count() == 5)

-- Advance past all
for i = 1, 10 do
    gameloop.update(0.016)
end

-- Expected order by delay: 2 (0.02), 5 (0.04), 3 (0.06), 1 (0.08), 4 (0.10)
test("All 5 fired", #results == 5)
test("Correct order by delay",
     results[1] == 2 and results[2] == 5 and results[3] == 3 and
     results[4] == 1 and results[5] == 4,
     "got " .. table.concat(results, ","))
-- }}}

-- {{{ Edge Cases Tests
test_section("Edge Cases")
reset_systems()

-- Zero duration timer (should fire on next tick)
local zero_fired = false
local t = timers.create()
timers.start(t, 0, false, function() zero_fired = true end)
gameloop.update(0.016)
test("Zero duration fires on next tick", zero_fired)

-- Very small duration
reset_systems()
local small_fired = false
local t2 = timers.create()
timers.start(t2, 0.001, false, function() small_fired = true end)
gameloop.update(0.016)
test("Very small duration fires", small_fired)

-- Timer callback that errors
reset_systems()
local error_timer = timers.create()
local after_error = false
local good_timer = timers.create()

timers.start(error_timer, 0.02, false, function()
    error("intentional test error")
end)
timers.start(good_timer, 0.04, false, function()
    after_error = true
end)

-- Suppress expected error output
local old_print = print
print = function() end
for i = 1, 5 do
    gameloop.update(0.016)
end
print = old_print

test("Error doesn't break other timers", after_error)

-- Pause already paused timer (no-op)
reset_systems()
local t3 = timers.create()
timers.start(t3, 1.0, false, function() end)
timers.pause(t3)
local elapsed1 = timers.get_elapsed(t3)
timers.pause(t3)  -- Should be no-op
test("Double pause is no-op", timers.get_elapsed(t3) == elapsed1)

-- Resume non-paused timer (no-op)
reset_systems()
local t4 = timers.create()
timers.start(t4, 1.0, false, function() end)
local queue_before = timers.get_active_count()
timers.resume(t4)  -- Should be no-op (not paused)
test("Resume non-paused is no-op", timers.get_active_count() == queue_before)

-- Operations on destroyed timer
reset_systems()
local t5 = timers.create()
timers.destroy(t5)
test("get_elapsed on destroyed returns 0", timers.get_elapsed(t5) == 0)
test("get_remaining on destroyed returns 0", timers.get_remaining(t5) == 0)
test("get_timeout on destroyed returns 0", timers.get_timeout(t5) == 0)
-- }}}

-- {{{ Runtime API Registration Tests
test_section("Runtime API Registration")
reset_systems()

local runtime = {}
timers.register_runtime_api(runtime)

test("CreateTimer registered", runtime.CreateTimer == timers.create)
test("DestroyTimer registered", runtime.DestroyTimer == timers.destroy)
test("TimerStart registered", runtime.TimerStart == timers.start)
test("PauseTimer registered", runtime.PauseTimer == timers.pause)
test("ResumeTimer registered", runtime.ResumeTimer == timers.resume)
test("TimerGetElapsed registered", runtime.TimerGetElapsed == timers.get_elapsed)
test("TimerGetRemaining registered", runtime.TimerGetRemaining == timers.get_remaining)
test("TimerGetTimeout registered", runtime.TimerGetTimeout == timers.get_timeout)

-- Test using runtime API
local rt = runtime.CreateTimer()
local rt_fired = false
runtime.TimerStart(rt, 0.05, false, function() rt_fired = true end)
for i = 1, 5 do
    gameloop.update(0.016)
end
test("Runtime API works end-to-end", rt_fired)
-- }}}

-- {{{ Error Handling Tests
test_section("Error Handling")
reset_systems()

-- Invalid timer handle
local ok, err = pcall(function() timers.start(nil, 1.0, false, function() end) end)
test("Error on nil timer", not ok)

local ok2, err2 = pcall(function() timers.start({}, 1.0, false, function() end) end)
test("Error on invalid timer type", not ok2)

-- Invalid duration
local t = timers.create()
local ok3, err3 = pcall(function() timers.start(t, -1, false, function() end) end)
test("Error on negative duration", not ok3)

local ok4, err4 = pcall(function() timers.start(t, "fast", false, function() end) end)
test("Error on non-number duration", not ok4)

-- Invalid callback
local ok5, err5 = pcall(function() timers.start(t, 1.0, false, "not a function") end)
test("Error on invalid callback", not ok5)
-- }}}

-- {{{ Reset Tests
test_section("Reset")
reset_systems()

-- Create several timers
for i = 1, 5 do
    local t = timers.create()
    timers.start(t, i * 0.1, false, function() end)
end

test("5 timers active before reset", timers.get_active_count() == 5)

timers.reset()

test("0 timers after reset", timers.get_active_count() == 0)
-- }}}

-- {{{ B02 Eternal Timer Regression Tests
-- Tests for timer ownership and orphan cleanup.
-- B02: Periodic timers should be cleanable when their owners become invalid.
test_section("B02: Timer Registry")
reset_systems()

local t1 = timers.create()
local t2 = timers.create()
test("Registry tracks created timers", timers.get_registry_count() == 2)

timers.destroy(t1)
test("Registry removes destroyed timer", timers.get_registry_count() == 1)

timers.destroy(t2)
test("Registry empty after all destroyed", timers.get_registry_count() == 0)

test_section("B02: Timer Ownership")
reset_systems()

local t = timers.create()
test("No owner initially", timers.get_owner(t) == nil)

timers.set_owner(t, 12345)
test("Owner set correctly", timers.get_owner(t) == 12345)

timers.set_owner(t, "entity_abc")
test("Owner can be updated", timers.get_owner(t) == "entity_abc")

-- Owner cleared on destroy
timers.destroy(t)
test("Owner nil after destroy", timers.get_owner(t) == nil)

test_section("B02: Orphan Cleanup with Validator")
reset_systems()

-- Simulate 3 entities with periodic timers
local valid_entities = { [1] = true, [2] = true, [3] = true }
local fire_counts = { 0, 0, 0 }

for i = 1, 3 do
    local t = timers.create()
    timers.set_owner(t, i)  -- Owner is entity ID
    local idx = i
    timers.start(t, 0.05, true, function()
        fire_counts[idx] = fire_counts[idx] + 1
    end)
end

test("3 timers in queue", timers.get_active_count() == 3)
test("3 timers in registry", timers.get_registry_count() == 3)

-- Run a few ticks - all should fire
for i = 1, 5 do
    gameloop.update(0.016)
end
test("All timers firing", fire_counts[1] > 0 and fire_counts[2] > 0 and fire_counts[3] > 0)

-- "Destroy" entity 2 (remove from valid set)
valid_entities[2] = nil
local old_count_2 = fire_counts[2]

-- Run cleanup with validator function
local destroyed = timers.cleanup_orphans(function(owner)
    return valid_entities[owner] == true
end)

test("One orphan destroyed", destroyed == 1)
test("2 timers remain in queue", timers.get_active_count() == 2)
test("2 timers remain in registry", timers.get_registry_count() == 2)

-- Run more ticks - entity 2's timer should not fire anymore
for i = 1, 5 do
    gameloop.update(0.016)
end
test("Orphaned timer stopped", fire_counts[2] == old_count_2)
test("Other timers still firing", fire_counts[1] > old_count_2 and fire_counts[3] > old_count_2)

test_section("B02: Orphan Cleanup without Validator")
reset_systems()

-- Create some timers with and without owners
local t_owned1 = timers.create()
local t_owned2 = timers.create()
local t_no_owner = timers.create()

timers.set_owner(t_owned1, "player1")
timers.set_owner(t_owned2, "player2")
-- t_no_owner has no owner

timers.start(t_owned1, 1.0, false, function() end)
timers.start(t_owned2, 1.0, false, function() end)
timers.start(t_no_owner, 1.0, false, function() end)

test("3 timers before cleanup", timers.get_active_count() == 3)

-- Cleanup without validator destroys all with owners
local destroyed = timers.cleanup_orphans(nil)

test("Two owned timers destroyed", destroyed == 2)
test("One unowned timer remains", timers.get_active_count() == 1)

test_section("B02: Leak Prevention Simulation")
reset_systems()

-- Simulate the leak scenario from the bounty description
-- Many periodic timers created, then "forgotten"
local initial_count = timers.get_registry_count()

-- Create 100 periodic timers with owners
local owners = {}
for i = 1, 100 do
    owners[i] = true  -- All owners valid initially
    local t = timers.create()
    timers.set_owner(t, i)
    timers.start(t, 0.1, true, function() end)
end

test("100 timers created", timers.get_registry_count() == 100)

-- Run for a bit
for i = 1, 10 do
    gameloop.update(0.016)
end

-- "Destroy" 50 owners (simulating unit deaths)
for i = 1, 50 do
    owners[i] = nil
end

-- Cleanup orphans
local destroyed = timers.cleanup_orphans(function(owner)
    return owners[owner] == true
end)

test("50 orphans cleaned up", destroyed == 50)
test("50 timers remain", timers.get_registry_count() == 50)
test("50 timers still active", timers.get_active_count() == 50)

-- "Destroy" remaining owners
for i = 51, 100 do
    owners[i] = nil
end

destroyed = timers.cleanup_orphans(function(owner)
    return owners[owner] == true
end)

test("Remaining 50 cleaned up", destroyed == 50)
test("No timers remain", timers.get_registry_count() == 0)

test_section("B02: Runtime API Registration")
reset_systems()

local runtime = {}
timers.register_runtime_api(runtime)

test("TimerSetOwner registered", runtime.TimerSetOwner == timers.set_owner)
test("TimerGetOwner registered", runtime.TimerGetOwner == timers.get_owner)
test("CleanupOrphanTimers registered", runtime.CleanupOrphanTimers == timers.cleanup_orphans)
-- }}}

-- {{{ Summary
print("\n" .. string.rep("=", 50))
print(string.format("Tests: %d passed, %d failed", pass_count, test_count - pass_count))

if pass_count == test_count then
    print("ALL TESTS PASSED")
    os.exit(0)
else
    print("SOME TESTS FAILED")
    os.exit(1)
end
-- }}}

-- Game Loop Unit Tests (401a)
-- Tests for fixed timestep game loop implementation.
-- Run with: luajit src/tests/test_gameloop.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local gameloop = require("runtime.gameloop")

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
    epsilon = epsilon or 0.0001
    return math.abs(a - b) < epsilon
end
-- }}}

-- {{{ Initial State Tests
test_section("Initial State")
gameloop.reset()
test("Time starts at 0", gameloop.get_time() == 0)
test("Tick starts at 0", gameloop.get_tick() == 0)
test("Speed is 1.0", gameloop.get_speed() == 1.0)
test("Not paused", not gameloop.is_paused())
test("Tick rate is 62.5", gameloop.get_tick_rate() == 62.5)
test("Tick duration ~0.016", approx_eq(gameloop.get_tick_duration(), 0.016))
test("Accumulator is 0", gameloop.get_accumulator() == 0)
-- }}}

-- {{{ Single Tick Tests
test_section("Single Tick")
gameloop.reset()
gameloop.tick()
test("Tick count is 1", gameloop.get_tick() == 1)
test("Time advanced", approx_eq(gameloop.get_time(), 1/62.5))

gameloop.tick()
test("Tick count is 2", gameloop.get_tick() == 2)
test("Time is 2 ticks", approx_eq(gameloop.get_time(), 2/62.5))
-- }}}

-- {{{ Update Accumulator Tests
test_section("Update Accumulator")
gameloop.reset()
local ticks = gameloop.update(0.016)
test("One tick processed", ticks == 1)
test("Tick count is 1", gameloop.get_tick() == 1)

gameloop.reset()
ticks = gameloop.update(0.032)
test("Two ticks for 32ms", ticks == 2)
test("Tick count is 2", gameloop.get_tick() == 2)

gameloop.reset()
ticks = gameloop.update(0.008)  -- Less than one tick
test("No ticks for 8ms", ticks == 0)
test("Tick count still 0", gameloop.get_tick() == 0)
test("Accumulator has value", gameloop.get_accumulator() > 0)

ticks = gameloop.update(0.008)  -- Another 8ms, should complete one tick
test("One tick after accumulation", ticks == 1)
test("Tick count is 1", gameloop.get_tick() == 1)
-- }}}

-- {{{ Pause/Resume Tests
test_section("Pause/Resume")
gameloop.reset()
gameloop.pause()
test("Is paused", gameloop.is_paused())
ticks = gameloop.update(0.1)
test("No ticks when paused", ticks == 0)
test("Tick unchanged when paused", gameloop.get_tick() == 0)

gameloop.resume()
test("Not paused after resume", not gameloop.is_paused())
ticks = gameloop.update(0.016)
test("Ticks after resume", ticks >= 1)

gameloop.reset()
local new_state = gameloop.toggle_pause()
test("Toggle returns new state", new_state == true)
test("Is paused after toggle", gameloop.is_paused())
new_state = gameloop.toggle_pause()
test("Toggle again returns false", new_state == false)
test("Not paused after second toggle", not gameloop.is_paused())
-- }}}

-- {{{ Speed Control Tests
test_section("Speed Control")
gameloop.reset()
gameloop.set_speed(2.0)
test("Speed set to 2.0", gameloop.get_speed() == 2.0)
ticks = gameloop.update(0.016)
test("Double speed = 2 ticks", ticks == 2)

gameloop.reset()
gameloop.set_speed(0.5)
test("Speed set to 0.5", gameloop.get_speed() == 0.5)
ticks = gameloop.update(0.016)
test("Half speed = 0 ticks (accumulating)", ticks == 0)
ticks = gameloop.update(0.016)
test("Half speed 2nd frame = 1 tick", ticks == 1)

-- Test intermediate speed
gameloop.reset()
gameloop.set_speed(1.5)
test("Speed set to 1.5", gameloop.get_speed() == 1.5)
-- }}}

-- {{{ Speed Clamping Tests
test_section("Speed Clamping")
gameloop.reset()
gameloop.set_speed(5.0)
test("Speed clamped to max (2.0)", gameloop.get_speed() == 2.0)
gameloop.set_speed(0.1)
test("Speed clamped to min (0.5)", gameloop.get_speed() == 0.5)
gameloop.set_speed(-1.0)
test("Negative speed clamped to min", gameloop.get_speed() == 0.5)

-- Test error on invalid type
local ok, err = pcall(function() gameloop.set_speed("fast") end)
test("Error on string speed", not ok)
-- }}}

-- {{{ Delta Time Capping Tests
test_section("Delta Time Capping")
gameloop.reset()
ticks = gameloop.update(1.0)  -- 1 second = huge lag spike
-- Should be capped to 0.25s worth (~15.6 ticks)
test("Lag spike capped", ticks <= 16, "got " .. ticks)

gameloop.reset()
ticks = gameloop.update(10.0)  -- 10 seconds of freeze
test("Large lag capped", ticks <= 16, "got " .. ticks)

-- Negative delta time should be treated as 0
gameloop.reset()
ticks = gameloop.update(-0.1)
test("Negative dt = 0 ticks", ticks == 0)
-- }}}

-- {{{ Tick Callback Tests
test_section("Tick Callbacks")
gameloop.reset()
local callback_count = 0
local last_tick = nil
local last_time = nil

local id = gameloop.add_tick_callback(function(tick, time)
    callback_count = callback_count + 1
    last_tick = tick
    last_time = time
end)

test("Callback registered", id == 1)
gameloop.update(0.032)  -- Two ticks
test("Callback called twice", callback_count == 2)
test("Callback received tick", last_tick == 2)
test("Callback received time", approx_eq(last_time, 2/62.5))

-- Add second callback
local second_count = 0
local id2 = gameloop.add_tick_callback(function()
    second_count = second_count + 1
end)
test("Second callback registered", id2 == 2)

gameloop.update(0.016)  -- One tick
test("First callback called again", callback_count == 3)
test("Second callback called", second_count == 1)

-- Remove first callback
gameloop.remove_tick_callback(id)
gameloop.update(0.016)  -- One tick
test("Removed callback not called", callback_count == 3)
test("Second callback still works", second_count == 2)

-- Test invalid callback error
local ok2, err2 = pcall(function() gameloop.add_tick_callback("not a function") end)
test("Error on invalid callback", not ok2)
-- }}}

-- {{{ Multiple Callbacks Tests
test_section("Multiple Callbacks")
gameloop.reset()
local order = {}

gameloop.add_tick_callback(function() order[#order + 1] = "A" end)
gameloop.add_tick_callback(function() order[#order + 1] = "B" end)
gameloop.add_tick_callback(function() order[#order + 1] = "C" end)

gameloop.update(0.016)  -- One tick
test("Three callbacks called", #order == 3)
test("Callbacks called in order", order[1] == "A" and order[2] == "B" and order[3] == "C")
-- }}}

-- {{{ Interpolation Alpha Tests
test_section("Interpolation Alpha")
gameloop.reset()
gameloop.update(0.008)  -- Half a tick
local alpha = gameloop.get_interpolation_alpha()
test("Alpha ~0.5 for half tick", approx_eq(alpha, 0.5, 0.1))

gameloop.reset()
gameloop.update(0.004)  -- Quarter tick
alpha = gameloop.get_interpolation_alpha()
test("Alpha ~0.25 for quarter tick", approx_eq(alpha, 0.25, 0.1))

gameloop.reset()
test("Alpha 0 at start", gameloop.get_interpolation_alpha() == 0)
-- }}}

-- {{{ Reset Tests
test_section("Reset")
gameloop.reset()
gameloop.update(0.1)
gameloop.set_speed(1.5)
gameloop.pause()
local cb_id = gameloop.add_tick_callback(function() end)

gameloop.reset()
test("Time reset to 0", gameloop.get_time() == 0)
test("Tick reset to 0", gameloop.get_tick() == 0)
test("Speed reset to 1.0", gameloop.get_speed() == 1.0)
test("Paused reset to false", not gameloop.is_paused())
test("Accumulator reset to 0", gameloop.get_accumulator() == 0)
test("Callbacks cleared", gameloop.get_callback_count() == 0)
-- }}}

-- {{{ Constants Export Tests
test_section("Constants Export")
test("TICK_RATE exported", gameloop.TICK_RATE == 62.5)
test("TICK_DURATION exported", approx_eq(gameloop.TICK_DURATION, 0.016))
test("MIN_SPEED exported", gameloop.MIN_SPEED == 0.5)
test("MAX_SPEED exported", gameloop.MAX_SPEED == 2.0)
-- }}}

-- {{{ Determinism Tests
test_section("Determinism")
-- Same updates should produce same results
gameloop.reset()
for i = 1, 100 do
    gameloop.update(0.016)
end
local time1 = gameloop.get_time()
local tick1 = gameloop.get_tick()

gameloop.reset()
for i = 1, 100 do
    gameloop.update(0.016)
end
local time2 = gameloop.get_time()
local tick2 = gameloop.get_tick()

test("Deterministic tick count", tick1 == tick2)
test("Deterministic time", time1 == time2)
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

# Issue 401a: Core Fixed Timestep Loop

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** Critical
**Dependencies:** Phase 2 complete (data model), Phase 3 complete (triggers/JASS)
**Parent Issue:** 401-implement-game-tick-update-loop

---

## Current Behavior

No game execution environment exists. Parsed map data sits idle with no mechanism
to advance game state over time. There is no concept of game time, ticks, or a
consistent update loop.

---

## Intended Behavior

A foundational game loop module that:
- Advances game state at a fixed tick rate of 62.5 ticks/second (matching WC3)
- Uses accumulator pattern for frame-rate independent fixed timestep
- Tracks game time in both seconds and tick counts
- Supports pause/resume for game state freezing
- Supports speed adjustment (0.5x to 2.0x)
- Maintains determinism for replay compatibility

```lua
-- Example usage:
local gameloop = require("runtime.gameloop")

-- Called each frame with delta time
gameloop.update(0.016)  -- 16ms frame

-- Query game state
print(gameloop.get_time())  -- 1.234 seconds
print(gameloop.get_tick())  -- 77 ticks

-- Control game flow
gameloop.pause()
gameloop.set_speed(1.5)
gameloop.resume()
```

---

## Suggested Implementation Steps

1. **Create gameloop module structure**
   ```lua
   -- {{{ src/runtime/gameloop.lua
   -- Core game loop with fixed timestep accumulator pattern
   -- Runs at 62.5 Hz to match WC3's tick rate for deterministic replay

   local gameloop = {}
   -- }}}
   ```

2. **Define tick rate constants**
   ```lua
   -- {{{ Constants
   -- WC3 runs at approximately 62.5 ticks per second
   -- This rate is critical for:
   --   - Deterministic replay playback
   --   - Multiplayer synchronization
   --   - Consistent trigger timing
   local TICK_RATE = 62.5
   local TICK_DURATION = 1.0 / TICK_RATE  -- ~0.016 seconds (16ms)

   -- Speed bounds (WC3 supports Slow/Normal/Fast)
   local MIN_SPEED = 0.5
   local MAX_SPEED = 2.0
   -- }}}
   ```

3. **Initialize game state variables**
   ```lua
   -- {{{ State variables
   local game_time = 0.0      -- Total elapsed game time in seconds
   local tick_count = 0       -- Total ticks processed
   local game_speed = 1.0     -- Speed multiplier (1.0 = normal)
   local paused = false       -- Pause state
   local accumulator = 0.0    -- Time accumulator for fixed timestep

   -- Tick callbacks (filled by other systems like timers)
   local tick_callbacks = {}
   -- }}}
   ```

4. **Implement reset function**
   ```lua
   -- {{{ gameloop.reset
   function gameloop.reset()
   -- }}}
   -- {{{ gameloop.reset
   function gameloop.reset()
       -- Reset all state to initial values
       -- Called when loading a new map or restarting
       game_time = 0.0
       tick_count = 0
       game_speed = 1.0
       paused = false
       accumulator = 0.0
       tick_callbacks = {}
   end
   -- }}}
   ```

5. **Implement single tick processing**
   ```lua
   -- {{{ gameloop.tick
   function gameloop.tick()
   -- }}}
   -- {{{ gameloop.tick
   function gameloop.tick()
       -- Advance game state by one tick
       -- This is the core simulation step
       --
       -- Processing order (deterministic):
       --   1. Timer expirations (401b)
       --   2. Periodic triggers
       --   3. Entity updates (movement, abilities)
       --   4. Combat resolution
       --   5. Death/cleanup
       --   6. Event dispatch

       tick_count = tick_count + 1
       game_time = tick_count * TICK_DURATION

       -- Execute registered tick callbacks
       -- Each callback receives current tick and game time
       for i = 1, #tick_callbacks do
           local cb = tick_callbacks[i]
           if cb then
               cb(tick_count, game_time)
           end
       end
   end
   -- }}}
   ```

6. **Implement fixed timestep update loop**
   ```lua
   -- {{{ gameloop.update
   function gameloop.update(dt)
   -- }}}
   -- {{{ gameloop.update
   function gameloop.update(dt)
       -- Main update function, called each frame with delta time
       -- Uses accumulator pattern for fixed timestep
       --
       -- dt: real elapsed time in seconds since last frame
       --
       -- The accumulator collects time and processes fixed ticks
       -- This ensures deterministic simulation regardless of frame rate

       if paused then
           return 0  -- Return ticks processed (none when paused)
       end

       -- Validate delta time to prevent spiral of death
       -- Cap at 0.25 seconds (prevents huge catch-up after lag)
       if dt > 0.25 then
           dt = 0.25
       end

       -- Accumulate time, scaled by game speed
       accumulator = accumulator + (dt * game_speed)

       local ticks_processed = 0

       -- Process as many fixed timesteps as accumulated
       while accumulator >= TICK_DURATION do
           gameloop.tick()
           accumulator = accumulator - TICK_DURATION
           ticks_processed = ticks_processed + 1
       end

       return ticks_processed
   end
   -- }}}
   ```

7. **Implement pause/resume controls**
   ```lua
   -- {{{ gameloop.pause
   function gameloop.pause()
   -- }}}
   -- {{{ gameloop.pause
   function gameloop.pause()
       -- Pause game simulation
       -- Ticks stop advancing, but time can still be queried
       paused = true
   end
   -- }}}

   -- {{{ gameloop.resume
   function gameloop.resume()
   -- }}}
   -- {{{ gameloop.resume
   function gameloop.resume()
       -- Resume game simulation from paused state
       paused = false
   end
   -- }}}

   -- {{{ gameloop.is_paused
   function gameloop.is_paused()
   -- }}}
   -- {{{ gameloop.is_paused
   function gameloop.is_paused()
       return paused
   end
   -- }}}

   -- {{{ gameloop.toggle_pause
   function gameloop.toggle_pause()
   -- }}}
   -- {{{ gameloop.toggle_pause
   function gameloop.toggle_pause()
       paused = not paused
       return paused
   end
   -- }}}
   ```

8. **Implement speed control**
   ```lua
   -- {{{ gameloop.set_speed
   function gameloop.set_speed(multiplier)
   -- }}}
   -- {{{ gameloop.set_speed
   function gameloop.set_speed(multiplier)
       -- Set game speed multiplier
       -- WC3 speeds: Slow=0.5, Normal=1.0, Fast=1.5-2.0
       --
       -- Speed affects accumulator rate, not tick duration
       -- This means ticks are still 16ms of game time each,
       -- but real time passes faster or slower

       if type(multiplier) ~= "number" then
           error("set_speed: multiplier must be a number")
       end

       -- Clamp to valid range
       if multiplier < MIN_SPEED then
           multiplier = MIN_SPEED
       elseif multiplier > MAX_SPEED then
           multiplier = MAX_SPEED
       end

       game_speed = multiplier
   end
   -- }}}

   -- {{{ gameloop.get_speed
   function gameloop.get_speed()
   -- }}}
   -- {{{ gameloop.get_speed
   function gameloop.get_speed()
       return game_speed
   end
   -- }}}
   ```

9. **Implement time/tick accessors**
   ```lua
   -- {{{ gameloop.get_time
   function gameloop.get_time()
   -- }}}
   -- {{{ gameloop.get_time
   function gameloop.get_time()
       -- Return elapsed game time in seconds
       -- This is the canonical game time for all systems
       return game_time
   end
   -- }}}

   -- {{{ gameloop.get_tick
   function gameloop.get_tick()
   -- }}}
   -- {{{ gameloop.get_tick
   function gameloop.get_tick()
       -- Return total tick count since game start
       return tick_count
   end
   -- }}}

   -- {{{ gameloop.get_tick_duration
   function gameloop.get_tick_duration()
   -- }}}
   -- {{{ gameloop.get_tick_duration
   function gameloop.get_tick_duration()
       -- Return duration of one tick in seconds
       -- Useful for systems that need to know tick rate
       return TICK_DURATION
   end
   -- }}}

   -- {{{ gameloop.get_tick_rate
   function gameloop.get_tick_rate()
   -- }}}
   -- {{{ gameloop.get_tick_rate
   function gameloop.get_tick_rate()
       -- Return ticks per second
       return TICK_RATE
   end
   -- }}}

   -- {{{ gameloop.get_accumulator
   function gameloop.get_accumulator()
   -- }}}
   -- {{{ gameloop.get_accumulator
   function gameloop.get_accumulator()
       -- Return current accumulator value
       -- Useful for interpolation in rendering
       -- Returns value between 0 and TICK_DURATION
       return accumulator
   end
   -- }}}

   -- {{{ gameloop.get_interpolation_alpha
   function gameloop.get_interpolation_alpha()
   -- }}}
   -- {{{ gameloop.get_interpolation_alpha
   function gameloop.get_interpolation_alpha()
       -- Return interpolation factor for rendering
       -- 0.0 = at previous tick state
       -- 1.0 = at current tick state
       return accumulator / TICK_DURATION
   end
   -- }}}
   ```

10. **Implement tick callback registration**
    ```lua
    -- {{{ gameloop.add_tick_callback
    function gameloop.add_tick_callback(callback)
    -- }}}
    -- {{{ gameloop.add_tick_callback
    function gameloop.add_tick_callback(callback)
        -- Register a function to be called each tick
        -- Callbacks receive (tick_count, game_time)
        --
        -- Returns callback ID for removal
        -- Used by timer system, periodic triggers, etc.

        if type(callback) ~= "function" then
            error("add_tick_callback: callback must be a function")
        end

        tick_callbacks[#tick_callbacks + 1] = callback
        return #tick_callbacks
    end
    -- }}}

    -- {{{ gameloop.remove_tick_callback
    function gameloop.remove_tick_callback(id)
    -- }}}
    -- {{{ gameloop.remove_tick_callback
    function gameloop.remove_tick_callback(id)
        -- Remove a tick callback by ID
        -- Sets to nil to preserve indices (avoids shifting)

        if id >= 1 and id <= #tick_callbacks then
            tick_callbacks[id] = nil
        end
    end
    -- }}}
    ```

11. **Export module**
    ```lua
    -- {{{ Module export
    return gameloop
    -- }}}
    ```

12. **Create unit tests**
    ```lua
    -- {{{ src/tests/test_gameloop.lua
    -- Tests for game loop fixed timestep implementation

    local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
    package.path = DIR .. "/src/?.lua;" .. package.path

    local gameloop = require("runtime.gameloop")

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

    -- Reset before each test section
    gameloop.reset()

    test_section("Initial State")
    test("Time starts at 0", gameloop.get_time() == 0)
    test("Tick starts at 0", gameloop.get_tick() == 0)
    test("Speed is 1.0", gameloop.get_speed() == 1.0)
    test("Not paused", not gameloop.is_paused())
    test("Tick rate is 62.5", gameloop.get_tick_rate() == 62.5)
    test("Tick duration ~0.016", approx_eq(gameloop.get_tick_duration(), 0.016))

    test_section("Single Tick")
    gameloop.reset()
    gameloop.tick()
    test("Tick count is 1", gameloop.get_tick() == 1)
    test("Time advanced", approx_eq(gameloop.get_time(), 1/62.5))

    test_section("Update Accumulator")
    gameloop.reset()
    local ticks = gameloop.update(0.016)
    test("One tick processed", ticks == 1)
    test("Tick count is 1", gameloop.get_tick() == 1)

    gameloop.reset()
    ticks = gameloop.update(0.032)
    test("Two ticks for 32ms", ticks == 2)
    test("Tick count is 2", gameloop.get_tick() == 2)

    test_section("Pause/Resume")
    gameloop.reset()
    gameloop.pause()
    test("Is paused", gameloop.is_paused())
    ticks = gameloop.update(0.1)
    test("No ticks when paused", ticks == 0)
    test("Tick unchanged", gameloop.get_tick() == 0)
    gameloop.resume()
    test("Not paused after resume", not gameloop.is_paused())
    ticks = gameloop.update(0.016)
    test("Ticks after resume", ticks >= 1)

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

    test_section("Speed Clamping")
    gameloop.reset()
    gameloop.set_speed(5.0)
    test("Speed clamped to max", gameloop.get_speed() == 2.0)
    gameloop.set_speed(0.1)
    test("Speed clamped to min", gameloop.get_speed() == 0.5)

    test_section("Delta Time Capping")
    gameloop.reset()
    ticks = gameloop.update(1.0)  -- 1 second = huge lag spike
    -- Should be capped to 0.25s worth
    test("Lag spike capped", ticks <= 16)  -- 0.25 * 62.5 = 15.625

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
    gameloop.update(0.032)
    test("Callback called twice", callback_count == 2)
    test("Callback received tick", last_tick == 2)
    test("Callback received time", approx_eq(last_time, 2/62.5))
    gameloop.remove_tick_callback(id)
    gameloop.update(0.016)
    test("Removed callback not called", callback_count == 2)

    test_section("Interpolation Alpha")
    gameloop.reset()
    gameloop.update(0.008)  -- Half a tick
    local alpha = gameloop.get_interpolation_alpha()
    test("Alpha ~0.5 for half tick", approx_eq(alpha, 0.5, 0.1))

    print("\n" .. string.rep("=", 40))
    print(string.format("Tests: %d passed, %d failed",
                        pass_count, test_count - pass_count))
    if pass_count == test_count then
        print("ALL TESTS PASSED")
    else
        os.exit(1)
    end
    -- }}}
    ```

---

## Technical Notes

### Fixed Timestep Pattern

The accumulator pattern ensures deterministic simulation:
```
accumulator += dt * speed
while accumulator >= TICK_DURATION:
    tick()
    accumulator -= TICK_DURATION
```

This separates simulation rate from render rate, allowing:
- Consistent game logic regardless of frame rate
- Interpolation for smooth rendering between ticks
- Replay compatibility (same inputs → same outputs)

### Delta Time Capping

Large delta times (from lag spikes or tab-away) are capped to 0.25 seconds
to prevent "spiral of death" where the game can never catch up.

### Determinism Considerations

For replay/multiplayer compatibility:
- Tick rate is fixed at 62.5 Hz
- Processing order within tick is deterministic
- No floating-point non-determinism (consider fixed-point for positions)
- No reliance on wall-clock time during simulation

### Interpolation for Rendering

The `get_interpolation_alpha()` function returns a value 0-1 indicating
progress toward the next tick. Renderers can use this to interpolate
entity positions for smoother visuals.

---

## Related Documents

- issues/401-implement-game-tick-update-loop.md (parent issue)
- issues/401b-timer-subsystem.md (timer system using tick callbacks)
- docs/roadmap.md (Phase 4 overview)
- issues/402-build-entity-component-system.md (entity updates per tick)

---

## Acceptance Criteria

- [ ] Module created at src/runtime/gameloop.lua
- [ ] TICK_RATE constant set to 62.5
- [ ] TICK_DURATION calculated as 1/62.5
- [ ] `reset()` function clears all state
- [ ] `tick()` function advances tick_count and game_time
- [ ] `update(dt)` uses accumulator pattern for fixed timestep
- [ ] Delta time capped at 0.25s to prevent spiral of death
- [ ] `pause()` and `resume()` control simulation
- [ ] `is_paused()` returns current pause state
- [ ] `set_speed(multiplier)` adjusts game speed
- [ ] Speed clamped to 0.5-2.0 range
- [ ] `get_time()` returns game time in seconds
- [ ] `get_tick()` returns total tick count
- [ ] `get_tick_duration()` returns tick length
- [ ] `get_tick_rate()` returns 62.5
- [ ] `get_interpolation_alpha()` returns 0-1 for rendering
- [ ] `add_tick_callback()` registers per-tick functions
- [ ] `remove_tick_callback()` unregisters callbacks
- [ ] Unit tests pass for all functionality
- [ ] All code uses vimfold markers

---

## Notes

This is the foundational module for the entire runtime. It must be
rock-solid before building timer systems, entity updates, or trigger
processing on top of it.

The tick callback system provides the hook point for the timer subsystem
(401b) and other per-tick processing like entity movement and combat.

Speed adjustment affects real-time accumulation, not tick duration.
This means at 2x speed, ticks still represent 16ms of game time each,
but real time passes faster.

---

## Implementation Notes

*Completed by Claude Code on 2025-12-27*

### Files Created

| File | Description |
|------|-------------|
| `src/runtime/gameloop.lua` | Core fixed timestep game loop (~250 lines) |
| `src/tests/test_gameloop.lua` | Unit tests (69 tests) |

### Implementation Details

1. **Module Structure:**
   - Constants: TICK_RATE (62.5), TICK_DURATION (~0.016s), speed bounds
   - State: game_time, tick_count, game_speed, paused, accumulator, callbacks
   - Functions: All specified in acceptance criteria

2. **Accumulator Pattern:**
   - `update(dt)` accumulates time scaled by speed
   - Processes fixed ticks while accumulator >= TICK_DURATION
   - Returns count of ticks processed

3. **Safety Features:**
   - Delta time capped at 0.25s (prevents spiral of death)
   - Negative delta time treated as 0
   - Speed clamped to 0.5-2.0 range
   - Type validation on callback registration

4. **Test Coverage (69 tests):**
   - Initial state verification
   - Single tick processing
   - Accumulator behavior
   - Pause/resume controls
   - Speed control and clamping
   - Delta time capping
   - Tick callbacks (registration, removal, ordering)
   - Interpolation alpha
   - Reset functionality
   - Constants export
   - Determinism verification

### Acceptance Criteria Status

- [x] Module created at src/runtime/gameloop.lua
- [x] TICK_RATE constant set to 62.5
- [x] TICK_DURATION calculated as 1/62.5
- [x] `reset()` function clears all state
- [x] `tick()` function advances tick_count and game_time
- [x] `update(dt)` uses accumulator pattern for fixed timestep
- [x] Delta time capped at 0.25s to prevent spiral of death
- [x] `pause()` and `resume()` control simulation
- [x] `is_paused()` returns current pause state
- [x] `set_speed(multiplier)` adjusts game speed
- [x] Speed clamped to 0.5-2.0 range
- [x] `get_time()` returns game time in seconds
- [x] `get_tick()` returns total tick count
- [x] `get_tick_duration()` returns tick length
- [x] `get_tick_rate()` returns 62.5
- [x] `get_interpolation_alpha()` returns 0-1 for rendering
- [x] `add_tick_callback()` registers per-tick functions
- [x] `remove_tick_callback()` unregisters callbacks
- [x] Unit tests pass for all functionality
- [x] All code uses vimfold markers

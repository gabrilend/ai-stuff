# Issue 401b: Timer Subsystem

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** Critical
**Dependencies:** 401a-core-fixed-timestep-loop
**Parent Issue:** 401-implement-game-tick-update-loop

---

## Current Behavior

The game loop (401a) provides fixed timestep tick processing, but there is no
timer system for scheduling callbacks at specific times. JASS code that uses
`CreateTimer()`, `TimerStart()`, and related functions has no implementation.

---

## Intended Behavior

A WC3-compatible timer system that:
- Creates timer handles with proper lifecycle management
- Starts timers with duration, periodic flag, and callback
- Uses priority queue for efficient expiration checking
- Integrates with game loop tick processing
- Provides ~0.01 second precision matching WC3
- Supports one-shot and periodic timers

```lua
-- Example usage (matching WC3 JASS API):
local timer = runtime.CreateTimer()
runtime.TimerStart(timer, 1.0, true, function()
    print("Timer fired at: " .. runtime.TimerGetElapsed(timer))
end)

-- Later:
runtime.PauseTimer(timer)
runtime.ResumeTimer(timer)
runtime.DestroyTimer(timer)
```

---

## Suggested Implementation Steps

1. **Create timers module structure**
   ```lua
   -- {{{ src/runtime/timers.lua
   -- WC3-compatible timer system with priority queue
   -- Integrates with gameloop for tick-based expiration

   local timers = {}

   local gameloop = require("runtime.gameloop")
   local handles = require("runtime.handles")
   -- }}}
   ```

2. **Define timer state**
   ```lua
   -- {{{ State
   -- Priority queue for active timers (sorted by expiration time)
   local timer_queue = {}
   local timer_count = 0

   -- Timer precision: WC3 timers have ~0.01 second precision
   -- With 62.5 Hz tick rate, actual precision is 0.016 seconds
   local TIMER_PRECISION = 0.01
   -- }}}
   ```

3. **Implement priority queue operations**
   ```lua
   -- {{{ Priority Queue - Binary Heap Implementation
   -- Min-heap where smallest expiration_time is at index 1

   local function heap_parent(i)
       return math.floor(i / 2)
   end

   local function heap_left(i)
       return 2 * i
   end

   local function heap_right(i)
       return 2 * i + 1
   end

   local function heap_swap(i, j)
       timer_queue[i], timer_queue[j] = timer_queue[j], timer_queue[i]
       -- Update queue indices
       timer_queue[i].queue_index = i
       timer_queue[j].queue_index = j
   end

   local function heap_bubble_up(i)
       while i > 1 do
           local parent = heap_parent(i)
           if timer_queue[parent].expiration_time <= timer_queue[i].expiration_time then
               break
           end
           heap_swap(i, parent)
           i = parent
       end
   end

   local function heap_bubble_down(i)
       local n = #timer_queue
       while true do
           local smallest = i
           local left = heap_left(i)
           local right = heap_right(i)

           if left <= n and timer_queue[left].expiration_time < timer_queue[smallest].expiration_time then
               smallest = left
           end
           if right <= n and timer_queue[right].expiration_time < timer_queue[smallest].expiration_time then
               smallest = right
           end

           if smallest == i then
               break
           end

           heap_swap(i, smallest)
           i = smallest
       end
   end

   local function heap_insert(timer)
       timer_queue[#timer_queue + 1] = timer
       timer.queue_index = #timer_queue
       heap_bubble_up(#timer_queue)
   end

   local function heap_remove(timer)
       local i = timer.queue_index
       if not i or i > #timer_queue then return end

       local n = #timer_queue
       if i == n then
           timer_queue[n] = nil
       else
           timer_queue[i] = timer_queue[n]
           timer_queue[i].queue_index = i
           timer_queue[n] = nil
           -- May need to bubble up or down
           if i > 1 and timer_queue[i].expiration_time < timer_queue[heap_parent(i)].expiration_time then
               heap_bubble_up(i)
           else
               heap_bubble_down(i)
           end
       end
       timer.queue_index = nil
   end

   local function heap_peek()
       return timer_queue[1]
   end

   local function heap_pop()
       local timer = timer_queue[1]
       if timer then
           heap_remove(timer)
       end
       return timer
   end
   -- }}}
   ```

4. **Implement timer creation**
   ```lua
   -- {{{ timers.create
   function timers.create()
   -- }}}
   -- {{{ timers.create
   function timers.create()
       -- Create a new timer handle
       -- Returns timer object with handle integration

       local timer = {
           _handle_type = "timer",
           _handle_id = nil,

           -- Timer state
           duration = 0,
           expiration_time = 0,
           elapsed = 0,
           periodic = false,
           callback = nil,
           running = false,
           paused = false,

           -- Queue tracking
           queue_index = nil,
       }

       -- Register with handle system
       if handles and handles.register then
           handles.register(timer, "timer")
       else
           -- Fallback: generate simple ID
           timer_count = timer_count + 1
           timer._handle_id = timer_count
       end

       return timer
   end
   -- }}}
   ```

5. **Implement timer start**
   ```lua
   -- {{{ timers.start
   function timers.start(timer, duration, periodic, callback)
   -- }}}
   -- {{{ timers.start
   function timers.start(timer, duration, periodic, callback)
       -- Start a timer with specified parameters
       --
       -- timer: timer handle from create()
       -- duration: time until expiration in seconds
       -- periodic: if true, timer repeats; if false, one-shot
       -- callback: function to call on expiration

       if not timer or timer._handle_type ~= "timer" then
           error("TimerStart: invalid timer handle")
       end

       if type(duration) ~= "number" or duration < 0 then
           error("TimerStart: duration must be non-negative number")
       end

       if type(callback) ~= "function" then
           error("TimerStart: callback must be a function")
       end

       -- Remove from queue if already running
       if timer.running and timer.queue_index then
           heap_remove(timer)
       end

       -- Set timer properties
       timer.duration = duration
       timer.periodic = periodic or false
       timer.callback = callback
       timer.elapsed = 0
       timer.running = true
       timer.paused = false

       -- Calculate expiration time
       local current_time = gameloop.get_time()
       timer.expiration_time = current_time + duration

       -- Insert into priority queue
       heap_insert(timer)
   end
   -- }}}
   ```

6. **Implement timer pause/resume**
   ```lua
   -- {{{ timers.pause
   function timers.pause(timer)
   -- }}}
   -- {{{ timers.pause
   function timers.pause(timer)
       -- Pause a running timer
       -- Elapsed time is preserved

       if not timer or timer._handle_type ~= "timer" then
           return
       end

       if not timer.running or timer.paused then
           return
       end

       -- Calculate how much time has elapsed
       local current_time = gameloop.get_time()
       timer.elapsed = timer.duration - (timer.expiration_time - current_time)

       -- Remove from queue
       if timer.queue_index then
           heap_remove(timer)
       end

       timer.paused = true
   end
   -- }}}

   -- {{{ timers.resume
   function timers.resume(timer)
   -- }}}
   -- {{{ timers.resume
   function timers.resume(timer)
       -- Resume a paused timer
       -- Continues from where it was paused

       if not timer or timer._handle_type ~= "timer" then
           return
       end

       if not timer.running or not timer.paused then
           return
       end

       -- Calculate remaining time
       local remaining = timer.duration - timer.elapsed
       local current_time = gameloop.get_time()
       timer.expiration_time = current_time + remaining

       -- Re-insert into queue
       heap_insert(timer)

       timer.paused = false
   end
   -- }}}
   ```

7. **Implement timer destruction**
   ```lua
   -- {{{ timers.destroy
   function timers.destroy(timer)
   -- }}}
   -- {{{ timers.destroy
   function timers.destroy(timer)
       -- Destroy a timer and clean up resources

       if not timer or timer._handle_type ~= "timer" then
           return
       end

       -- Remove from queue if present
       if timer.queue_index then
           heap_remove(timer)
       end

       -- Clear state
       timer.running = false
       timer.paused = false
       timer.callback = nil

       -- Unregister handle
       if handles and handles.destroy then
           handles.destroy(timer)
       end

       timer._handle_id = nil
       timer._handle_type = nil
   end
   -- }}}
   ```

8. **Implement timer queries**
   ```lua
   -- {{{ timers.get_elapsed
   function timers.get_elapsed(timer)
   -- }}}
   -- {{{ timers.get_elapsed
   function timers.get_elapsed(timer)
       -- Return time elapsed since timer started

       if not timer or timer._handle_type ~= "timer" then
           return 0
       end

       if timer.paused then
           return timer.elapsed
       end

       if not timer.running then
           return 0
       end

       local current_time = gameloop.get_time()
       return timer.duration - (timer.expiration_time - current_time)
   end
   -- }}}

   -- {{{ timers.get_remaining
   function timers.get_remaining(timer)
   -- }}}
   -- {{{ timers.get_remaining
   function timers.get_remaining(timer)
       -- Return time remaining until expiration

       if not timer or timer._handle_type ~= "timer" then
           return 0
       end

       if timer.paused then
           return timer.duration - timer.elapsed
       end

       if not timer.running then
           return 0
       end

       local current_time = gameloop.get_time()
       local remaining = timer.expiration_time - current_time
       return remaining > 0 and remaining or 0
   end
   -- }}}

   -- {{{ timers.get_timeout
   function timers.get_timeout(timer)
   -- }}}
   -- {{{ timers.get_timeout
   function timers.get_timeout(timer)
       -- Return the timer's duration (timeout value)

       if not timer or timer._handle_type ~= "timer" then
           return 0
       end

       return timer.duration
   end
   -- }}}
   ```

9. **Implement tick processing**
   ```lua
   -- {{{ timers.process_tick
   function timers.process_tick(tick_count, game_time)
   -- }}}
   -- {{{ timers.process_tick
   function timers.process_tick(tick_count, game_time)
       -- Process timer expirations for this tick
       -- Called by gameloop each tick via tick callback
       --
       -- Fires all timers whose expiration_time <= game_time

       while true do
           local timer = heap_peek()
           if not timer then
               break
           end

           if timer.expiration_time > game_time then
               break
           end

           -- Timer has expired
           heap_pop()

           -- Execute callback
           if timer.callback then
               -- Protected call to prevent one bad timer from breaking all
               local ok, err = pcall(timer.callback)
               if not ok then
                   -- Log error but continue processing
                   print("[TIMER ERROR] " .. tostring(err))
               end
           end

           -- Handle periodic timers
           if timer.periodic and timer.running then
               -- Reset for next period
               timer.elapsed = 0
               timer.expiration_time = game_time + timer.duration
               heap_insert(timer)
           else
               -- One-shot timer is done
               timer.running = false
           end
       end
   end
   -- }}}
   ```

10. **Implement initialization and reset**
    ```lua
    -- {{{ timers.init
    function timers.init()
    -- }}}
    -- {{{ timers.init
    function timers.init()
        -- Initialize timer system
        -- Registers tick callback with gameloop

        timers.reset()

        -- Register with gameloop for per-tick processing
        gameloop.add_tick_callback(timers.process_tick)
    end
    -- }}}

    -- {{{ timers.reset
    function timers.reset()
    -- }}}
    -- {{{ timers.reset
    function timers.reset()
        -- Reset timer system to initial state
        -- Destroys all active timers

        -- Clear queue
        for i = #timer_queue, 1, -1 do
            local timer = timer_queue[i]
            if timer then
                timer.queue_index = nil
                timer.running = false
            end
            timer_queue[i] = nil
        end
    end
    -- }}}

    -- {{{ timers.get_active_count
    function timers.get_active_count()
    -- }}}
    -- {{{ timers.get_active_count
    function timers.get_active_count()
        -- Return number of active timers in queue
        return #timer_queue
    end
    -- }}}
    ```

11. **Export WC3-style runtime API**
    ```lua
    -- {{{ Runtime API (WC3 function names)
    -- These functions are injected into the runtime for JASS compatibility

    function timers.register_runtime_api(runtime)
        -- CreateTimer() -> timer
        runtime.CreateTimer = timers.create

        -- DestroyTimer(timer)
        runtime.DestroyTimer = timers.destroy

        -- TimerStart(timer, timeout, periodic, callback)
        runtime.TimerStart = timers.start

        -- PauseTimer(timer)
        runtime.PauseTimer = timers.pause

        -- ResumeTimer(timer)
        runtime.ResumeTimer = timers.resume

        -- TimerGetElapsed(timer) -> real
        runtime.TimerGetElapsed = timers.get_elapsed

        -- TimerGetRemaining(timer) -> real
        runtime.TimerGetRemaining = timers.get_remaining

        -- TimerGetTimeout(timer) -> real
        runtime.TimerGetTimeout = timers.get_timeout
    end
    -- }}}
    ```

12. **Export module**
    ```lua
    -- {{{ Module export
    return timers
    -- }}}
    ```

13. **Create unit tests**
    ```lua
    -- {{{ src/tests/test_timers.lua
    -- Tests for WC3-compatible timer subsystem

    local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
    package.path = DIR .. "/src/?.lua;" .. package.path

    local gameloop = require("runtime.gameloop")
    local timers = require("runtime.timers")

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

    -- Initialize systems
    gameloop.reset()
    timers.init()

    test_section("Timer Creation")
    local t = timers.create()
    test("Create returns timer", t ~= nil)
    test("Timer has handle type", t._handle_type == "timer")
    test("Timer has handle ID", t._handle_id ~= nil)
    test("Timer not running", not t.running)

    test_section("Timer Start")
    gameloop.reset()
    timers.reset()
    timers.init()

    local t = timers.create()
    local fired = false
    timers.start(t, 0.5, false, function()
        fired = true
    end)
    test("Timer running after start", t.running)
    test("Timer in queue", timers.get_active_count() == 1)
    test("Duration set", t.duration == 0.5)
    test("Not periodic", not t.periodic)

    test_section("Timer Expiration (One-Shot)")
    gameloop.reset()
    timers.reset()
    timers.init()

    fired = false
    local t = timers.create()
    timers.start(t, 0.1, false, function()
        fired = true
    end)

    -- Advance time past expiration
    for i = 1, 10 do
        gameloop.update(0.016)
    end
    test("Timer fired", fired)
    test("Timer stopped after fire", not t.running)
    test("Queue empty", timers.get_active_count() == 0)

    test_section("Timer Expiration (Periodic)")
    gameloop.reset()
    timers.reset()
    timers.init()

    local fire_count = 0
    local t = timers.create()
    timers.start(t, 0.05, true, function()
        fire_count = fire_count + 1
    end)

    -- Advance enough for ~3 firings
    for i = 1, 12 do
        gameloop.update(0.016)
    end
    test("Periodic fired multiple times", fire_count >= 2)
    test("Periodic still running", t.running)
    test("Still in queue", timers.get_active_count() == 1)

    test_section("Timer Pause/Resume")
    gameloop.reset()
    timers.reset()
    timers.init()

    fired = false
    local t = timers.create()
    timers.start(t, 0.2, false, function()
        fired = true
    end)

    -- Advance halfway
    for i = 1, 6 do
        gameloop.update(0.016)
    end
    test("Not fired yet", not fired)

    -- Pause
    timers.pause(t)
    test("Timer paused", t.paused)
    local elapsed_at_pause = timers.get_elapsed(t)
    test("Elapsed tracked", elapsed_at_pause > 0)

    -- Advance more (should not fire while paused)
    for i = 1, 20 do
        gameloop.update(0.016)
    end
    test("Still not fired while paused", not fired)

    -- Resume
    timers.resume(t)
    test("Timer resumed", not t.paused)

    -- Advance remaining time
    for i = 1, 10 do
        gameloop.update(0.016)
    end
    test("Fired after resume", fired)

    test_section("Timer Queries")
    gameloop.reset()
    timers.reset()
    timers.init()

    local t = timers.create()
    timers.start(t, 1.0, false, function() end)

    test("Timeout is 1.0", timers.get_timeout(t) == 1.0)
    test("Remaining starts at ~1.0", approx_eq(timers.get_remaining(t), 1.0))
    test("Elapsed starts at ~0", approx_eq(timers.get_elapsed(t), 0))

    -- Advance half second
    for i = 1, 31 do
        gameloop.update(0.016)
    end
    test("Elapsed ~0.5", approx_eq(timers.get_elapsed(t), 0.5, 0.05))
    test("Remaining ~0.5", approx_eq(timers.get_remaining(t), 0.5, 0.05))

    test_section("Timer Destruction")
    gameloop.reset()
    timers.reset()
    timers.init()

    fired = false
    local t = timers.create()
    timers.start(t, 0.1, false, function()
        fired = true
    end)

    timers.destroy(t)
    test("Handle ID cleared", t._handle_id == nil)
    test("Removed from queue", timers.get_active_count() == 0)

    -- Advance past expiration
    for i = 1, 10 do
        gameloop.update(0.016)
    end
    test("Destroyed timer didn't fire", not fired)

    test_section("Multiple Timers")
    gameloop.reset()
    timers.reset()
    timers.init()

    local order = {}
    local t1 = timers.create()
    local t2 = timers.create()
    local t3 = timers.create()

    timers.start(t2, 0.08, false, function() order[#order+1] = 2 end)
    timers.start(t1, 0.04, false, function() order[#order+1] = 1 end)
    timers.start(t3, 0.12, false, function() order[#order+1] = 3 end)

    test("Three timers queued", timers.get_active_count() == 3)

    -- Advance past all
    for i = 1, 10 do
        gameloop.update(0.016)
    end

    test("All fired", #order == 3)
    test("Fired in order", order[1] == 1 and order[2] == 2 and order[3] == 3)

    test_section("Priority Queue Ordering")
    gameloop.reset()
    timers.reset()
    timers.init()

    -- Add timers in random order, verify they fire in time order
    local results = {}
    for i = 1, 5 do
        local delay = ({0.08, 0.02, 0.06, 0.10, 0.04})[i]
        local t = timers.create()
        timers.start(t, delay, false, function()
            results[#results+1] = i
        end)
    end

    -- Expected order: 2, 5, 3, 1, 4 (sorted by delay)
    for i = 1, 8 do
        gameloop.update(0.016)
    end

    test("All 5 fired", #results == 5)
    test("Correct order", results[1] == 2 and results[2] == 5 and
                          results[3] == 3 and results[4] == 1 and results[5] == 4)

    test_section("Edge Cases")
    gameloop.reset()
    timers.reset()
    timers.init()

    -- Zero duration timer
    fired = false
    local t = timers.create()
    timers.start(t, 0, false, function() fired = true end)
    gameloop.update(0.016)
    test("Zero duration fires immediately", fired)

    -- Timer callback that errors
    local error_timer = timers.create()
    local after_error = false
    local good_timer = timers.create()
    timers.start(error_timer, 0.02, false, function()
        error("intentional test error")
    end)
    timers.start(good_timer, 0.04, false, function()
        after_error = true
    end)

    for i = 1, 4 do
        gameloop.update(0.016)
    end
    test("Error doesn't break other timers", after_error)

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

### Priority Queue Implementation

Uses a min-heap where the timer with smallest expiration_time is at the root:
- Insert: O(log n)
- Remove: O(log n)
- Peek next expiration: O(1)

This is critical for efficient tick processing - we only check timers that
might have expired rather than iterating all active timers.

### WC3 Timer Precision

WC3 timers have approximately 0.01 second precision, but our tick rate (62.5 Hz)
provides ~0.016 second precision. Timers expire on the first tick where:
```
game_time >= timer.expiration_time
```

### Periodic Timer Behavior

Periodic timers reset their expiration time after each firing:
```
expiration_time = current_time + duration
```

This means drift can occur over long periods. WC3 has the same behavior -
a 0.5s periodic timer doesn't guarantee exactly 2 fires per second.

### Callback Error Handling

Timer callbacks are wrapped in pcall to prevent one buggy timer from breaking
the entire timer system. Errors are logged but processing continues.

### Integration with Game Loop

The timer system registers a tick callback during init():
```lua
gameloop.add_tick_callback(timers.process_tick)
```

This ensures timers are processed every tick in the correct phase.

---

## Related Documents

- issues/401-implement-game-tick-update-loop.md (parent issue)
- issues/401a-core-fixed-timestep-loop.md (game loop infrastructure)
- src/runtime/gameloop.lua (tick callback registration)
- src/runtime/handles.lua (handle system integration)
- docs/roadmap.md (Phase 4 overview)

---

## Acceptance Criteria

- [ ] Module created at src/runtime/timers.lua
- [ ] `create()` creates timer with handle integration
- [ ] `start(timer, duration, periodic, callback)` starts timer
- [ ] `pause(timer)` pauses running timer, preserving elapsed time
- [ ] `resume(timer)` resumes paused timer
- [ ] `destroy(timer)` removes timer and cleans up
- [ ] `get_elapsed(timer)` returns elapsed time
- [ ] `get_remaining(timer)` returns time until expiration
- [ ] `get_timeout(timer)` returns timer duration
- [ ] Priority queue uses min-heap for O(log n) operations
- [ ] `process_tick()` fires all expired timers
- [ ] Periodic timers repeat correctly
- [ ] One-shot timers stop after firing
- [ ] Timer callbacks are error-protected (pcall)
- [ ] `init()` registers with game loop
- [ ] `reset()` clears all timers
- [ ] `register_runtime_api()` exports WC3-style functions
- [ ] Unit tests pass for all functionality
- [ ] All code uses vimfold markers

---

## Notes

The timer system is one of the most-used systems in WC3 maps. Many game
mechanics rely on periodic timers for updates, cooldowns, and delayed effects.

The priority queue is essential for performance. A map might have hundreds
of active timers, and we need to efficiently find which ones have expired
each tick without checking all of them.

The WC3 runtime API functions (CreateTimer, TimerStart, etc.) match the
JASS native function signatures so transpiled JASS code works without
modification.

---

## Implementation Notes

*Completed by Claude Code on 2025-12-27*

### Files Created

| File | Description |
|------|-------------|
| `src/runtime/timers.lua` | Timer subsystem with priority queue (~350 lines) |
| `src/tests/test_timers.lua` | Unit tests (73 tests) |

### Implementation Details

1. **Priority Queue (Min-Heap):**
   - Binary heap with smallest expiration_time at root
   - O(log n) insert/remove via bubble_up/bubble_down
   - O(1) peek for next expiration
   - Timer objects track their queue_index for O(log n) removal

2. **Timer API:**
   - `create()` - Creates timer with unique handle ID
   - `start(timer, duration, periodic, callback)` - Starts/restarts timer
   - `pause(timer)` - Pauses timer, preserves elapsed time
   - `resume(timer)` - Resumes from paused state
   - `destroy(timer)` - Removes timer and clears handle
   - `get_elapsed/remaining/timeout(timer)` - Query timer state

3. **Tick Processing:**
   - `process_tick()` registered as gameloop callback
   - Fires all timers where expiration_time <= game_time
   - Periodic timers re-inserted with new expiration
   - One-shot timers marked as not running
   - Callbacks wrapped in pcall for error isolation

4. **WC3 Runtime API:**
   - `register_runtime_api(runtime)` adds JASS-compatible functions:
     - CreateTimer, DestroyTimer
     - TimerStart, PauseTimer, ResumeTimer
     - TimerGetElapsed, TimerGetRemaining, TimerGetTimeout

5. **Test Coverage (73 tests):**
   - Timer creation and state
   - Start/restart behavior
   - One-shot expiration
   - Periodic expiration with intervals
   - Pause/resume preserving elapsed time
   - Query functions (elapsed, remaining, timeout)
   - Destruction and cleanup
   - Multiple timer ordering
   - Priority queue correctness
   - Edge cases (zero duration, errors, double pause)
   - Runtime API registration
   - Error handling
   - Reset functionality

### Acceptance Criteria Status

- [x] Module created at src/runtime/timers.lua
- [x] `create()` creates timer with handle integration
- [x] `start(timer, duration, periodic, callback)` starts timer
- [x] `pause(timer)` pauses running timer, preserving elapsed time
- [x] `resume(timer)` resumes paused timer
- [x] `destroy(timer)` removes timer and cleans up
- [x] `get_elapsed(timer)` returns elapsed time
- [x] `get_remaining(timer)` returns time until expiration
- [x] `get_timeout(timer)` returns timer duration
- [x] Priority queue uses min-heap for O(log n) operations
- [x] `process_tick()` fires all expired timers
- [x] Periodic timers repeat correctly
- [x] One-shot timers stop after firing
- [x] Timer callbacks are error-protected (pcall)
- [x] `init()` registers with game loop
- [x] `reset()` clears all timers
- [x] `register_runtime_api()` exports WC3-style functions
- [x] Unit tests pass for all functionality
- [x] All code uses vimfold markers

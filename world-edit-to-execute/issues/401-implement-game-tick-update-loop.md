# Issue 401: Implement Game Tick/Update Loop

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** Critical
**Dependencies:** Phase 2 complete (data model), Phase 3 complete (triggers/JASS)

---

## Current Behavior

No game execution environment exists. Parsed map data sits idle with no mechanism
to advance game state over time.

---

## Intended Behavior

A deterministic game loop that:
- Advances game state at a fixed tick rate (matching WC3's ~62.5 ticks/second)
- Processes entity updates in consistent order
- Fires time-based triggers and events
- Supports pause/resume/speed adjustment
- Maintains determinism for replay compatibility

---

## Suggested Implementation Steps

1. **Create core game loop module**
   ```
   src/runtime/
   └── gameloop.lua
   ```

2. **Define tick rate and timing**
   ```lua
   -- WC3 runs at approximately 62.5 ticks per second
   local TICK_RATE = 62.5
   local TICK_DURATION = 1.0 / TICK_RATE  -- ~0.016 seconds

   -- Game time tracking
   local game_time = 0.0      -- Total elapsed game time (seconds)
   local tick_count = 0       -- Total ticks processed
   local game_speed = 1.0     -- Speed multiplier (1.0 = normal)
   local paused = false
   ```

3. **Implement fixed timestep loop**
   ```lua
   -- Accumulator pattern for fixed timestep
   local accumulator = 0.0

   function gameloop.update(dt)
       if paused then return end

       accumulator = accumulator + (dt * game_speed)

       while accumulator >= TICK_DURATION do
           gameloop.tick()
           accumulator = accumulator - TICK_DURATION
       end
   end
   ```

4. **Implement single tick processing**
   ```lua
   function gameloop.tick()
       tick_count = tick_count + 1
       game_time = tick_count * TICK_DURATION

       -- Process in deterministic order:
       -- 1. Timer expirations
       -- 2. Periodic triggers
       -- 3. Entity updates (movement, abilities, etc.)
       -- 4. Combat resolution
       -- 5. Death/cleanup
       -- 6. Event dispatch
   end
   ```

5. **Add game state controls**
   ```lua
   function gameloop.pause()
   function gameloop.resume()
   function gameloop.set_speed(multiplier)
   function gameloop.get_time()
   function gameloop.get_tick()
   ```

6. **Implement timer system**
   ```lua
   -- WC3-style timer support
   function gameloop.create_timer()
   function gameloop.start_timer(timer, duration, periodic, callback)
   function gameloop.destroy_timer(timer)
   ```

---

## Technical Notes

### WC3 Tick Rate

WC3 runs at approximately 62.5 ticks per second (16ms per tick). This rate is
critical for:
- Deterministic replay playback
- Multiplayer synchronization
- Consistent trigger timing

### Determinism Requirements

For replay/multiplayer compatibility, the game loop must be deterministic:
- Same inputs → same outputs, always
- No floating point non-determinism (use fixed-point where needed)
- Consistent entity processing order
- No reliance on wall-clock time during simulation

### Game Speed

WC3 supports speed settings:
- Slow: 0.5x
- Normal: 1.0x
- Fast: 1.5x (or 2.0x in some contexts)

Speed affects the accumulator rate, not the tick duration.

### Timer Precision

WC3 timers have ~0.01 second precision. Timers should expire on the first
tick where game_time >= expiration_time.

---

## Related Documents

- docs/roadmap.md (Phase 4 overview)
- issues/402-build-entity-component-system.md (entity updates per tick)
- issues/Phase 3 issues (trigger/event system integration)

---

## Acceptance Criteria

- [ ] Fixed timestep loop at 62.5 ticks/second
- [ ] Deterministic tick processing
- [ ] Game time tracking (seconds and tick count)
- [ ] Pause/resume functionality
- [ ] Speed adjustment (0.5x to 2.0x)
- [ ] Timer system (create, start, periodic, destroy)
- [ ] Timer expiration with correct precision
- [ ] Unit tests for timing accuracy

---

## Notes

The game loop is the heart of the runtime. It must be rock-solid before
other runtime systems can be built on top of it.

Consider using a priority queue for timer management to efficiently
find the next timer to expire.

The loop should be decoupled from rendering - it produces game state,
the renderer consumes it at its own rate (interpolating if needed).

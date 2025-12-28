# Issue 308b: Implement Timer Events

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** High
**Parent Issue:** 308-build-event-dispatch-system.md
**Dependencies:** 308a-implement-event-registry-core

---

## Current Behavior

The event registry from 308a provides the infrastructure to register triggers for
events and fire those events with context. However, there is no timer subsystem
to create timed events.

Currently:
- No timer storage exists in runtime
- No TriggerRegisterTimerEvent function
- No game loop hook to update timers
- Periodic and one-shot timer behaviors not implemented

---

## Intended Behavior

A timer event subsystem that provides:

1. **Timer Storage** - Runtime maintains timer registry:
   ```lua
   runtime._timers = {}      -- timer_id → timer object
   runtime._next_timer_id = 1
   ```

2. **Timer Object Structure**:
   ```lua
   {
       id = <unique integer>,
       trigger = <trigger object>,
       timeout = <seconds>,
       periodic = <boolean>,
       elapsed = <accumulated time>,
       enabled = <boolean>,
       listener = <event listener reference>,
   }
   ```

3. **TriggerRegisterTimerEvent API**:
   - Creates timer object with specified timeout
   - Registers trigger for TIMER_EXPIRE or TIMER_PERIODIC event
   - Filter ensures only this timer's events fire the trigger
   - Returns timer object for later control

4. **Timer Update Function** - Called each game tick:
   - Accumulates delta time for each enabled timer
   - Fires event when elapsed >= timeout
   - Periodic timers reset elapsed and continue
   - One-shot timers disable after firing

5. **Timer Control Functions**:
   - PauseTimer(timer) - Set enabled = false
   - ResumeTimer(timer) - Set enabled = true
   - DestroyTimer(timer) - Remove from registry, unregister listener

---

## Suggested Implementation Steps

1. **Initialize timer storage in runtime**
   - Add to `src/runtime/init.lua`:
     ```lua
     runtime._timers = {}
     runtime._next_timer_id = 1
     ```

2. **Implement TriggerRegisterTimerEvent function**
   ```lua
   -- {{{ TriggerRegisterTimerEvent
   function runtime.TriggerRegisterTimerEvent(trigger, timeout, periodic)
       local timer_id = runtime._next_timer_id
       runtime._next_timer_id = runtime._next_timer_id + 1

       local timer = {
           id = timer_id,
           trigger = trigger,
           timeout = timeout,
           periodic = periodic or false,
           elapsed = 0,
           enabled = true,
       }

       -- Determine event type based on periodic flag
       local event_type = periodic and
           events.EVENT.TIMER_PERIODIC or
           events.EVENT.TIMER_EXPIRE

       -- Register with filter for this specific timer
       local listener = events.register(
           event_type,
           trigger,
           function(ctx) return ctx.timer_id == timer_id end
       )

       timer.listener = listener
       runtime._timers[timer_id] = timer

       return timer
   end
   -- }}}
   ```

3. **Implement events.update_timers function**
   ```lua
   -- {{{ update_timers
   function events.update_timers(dt)
       for id, timer in pairs(runtime._timers) do
           if timer.enabled then
               timer.elapsed = timer.elapsed + dt

               if timer.elapsed >= timer.timeout then
                   local event_type = timer.periodic and
                       events.EVENT.TIMER_PERIODIC or
                       events.EVENT.TIMER_EXPIRE

                   events.fire(event_type, {
                       event_id = event_type,
                       timer_id = id,
                       timer = timer,
                       elapsed = timer.elapsed,
                   })

                   if timer.periodic then
                       -- Reset for next period, preserve overflow
                       timer.elapsed = timer.elapsed - timer.timeout
                   else
                       -- One-shot timer disables after firing
                       timer.enabled = false
                   end
               end
           end
       end
   end
   -- }}}
   ```

4. **Implement PauseTimer function**
   ```lua
   -- {{{ PauseTimer
   function runtime.PauseTimer(timer)
       if timer and runtime._timers[timer.id] then
           timer.enabled = false
       end
   end
   -- }}}
   ```

5. **Implement ResumeTimer function**
   ```lua
   -- {{{ ResumeTimer
   function runtime.ResumeTimer(timer)
       if timer and runtime._timers[timer.id] then
           timer.enabled = true
       end
   end
   -- }}}
   ```

6. **Implement DestroyTimer function**
   ```lua
   -- {{{ DestroyTimer
   function runtime.DestroyTimer(timer)
       if not timer then return end

       local stored = runtime._timers[timer.id]
       if not stored then return end

       -- Unregister from event system
       if stored.listener then
           local event_type = stored.periodic and
               events.EVENT.TIMER_PERIODIC or
               events.EVENT.TIMER_EXPIRE
           events.unregister(event_type, stored.listener)
       end

       -- Remove from timer registry
       runtime._timers[timer.id] = nil
   end
   -- }}}
   ```

7. **Implement TimerGetElapsed function**
   ```lua
   -- {{{ TimerGetElapsed
   function runtime.TimerGetElapsed(timer)
       if timer and runtime._timers[timer.id] then
           return timer.elapsed
       end
       return 0
   end
   -- }}}
   ```

8. **Implement TimerGetRemaining function**
   ```lua
   -- {{{ TimerGetRemaining
   function runtime.TimerGetRemaining(timer)
       if timer and runtime._timers[timer.id] then
           return math.max(0, timer.timeout - timer.elapsed)
       end
       return 0
   end
   -- }}}
   ```

9. **Implement TimerGetTimeout function**
   ```lua
   -- {{{ TimerGetTimeout
   function runtime.TimerGetTimeout(timer)
       if timer and runtime._timers[timer.id] then
           return timer.timeout
       end
       return 0
   end
   -- }}}
   ```

10. **Document game loop integration**
    - Add comment in events.lua explaining update_timers must be called
    - Game loop (from issue 401) will call: `events.update_timers(dt)`
    - dt is delta time in seconds since last tick

11. **Write unit tests**
    - Create `src/tests/test_timer_events.lua`
    - Test one-shot timer fires once then disables
    - Test periodic timer fires repeatedly
    - Test timer with exact timeout boundary
    - Test PauseTimer stops accumulation
    - Test ResumeTimer continues accumulation
    - Test DestroyTimer removes timer completely
    - Test TimerGetElapsed/Remaining/Timeout accessors
    - Test multiple timers with different timeouts
    - Test timer context contains correct data

---

## Related Documents

- issues/308-build-event-dispatch-system.md (parent issue)
- issues/308a-implement-event-registry-core.md (dependency - event registry)
- issues/401-implement-game-tick-update-loop.md (will call update_timers)
- src/runtime/events.lua (event registry)
- src/runtime/init.lua (runtime API)

---

## Acceptance Criteria

- [x] Timer storage initialized in runtime (_timers, _next_timer_id)
- [x] TriggerRegisterTimerEvent creates and registers timer
- [x] One-shot timers (periodic=false) fire once then disable
- [x] Periodic timers fire repeatedly at interval
- [x] Timer events fire at correct intervals (within tick precision)
- [x] Periodic timers reset elapsed time correctly (preserve overflow)
- [x] PauseTimer stops timer accumulation
- [x] ResumeTimer continues timer accumulation
- [x] DestroyTimer removes timer and unregisters listener
- [x] TimerGetElapsed returns accumulated time
- [x] TimerGetRemaining returns time until next fire
- [x] TimerGetTimeout returns original timeout value
- [x] Event context includes timer_id, timer, elapsed
- [x] update_timers(dt) processes all enabled timers
- [x] Unit tests pass for timer operations

---

## Notes

Timer precision is limited by game tick rate. If the game loop runs at 30 FPS,
timer precision is ~33ms. Timers may fire slightly late but never early.

The elapsed overflow preservation for periodic timers ensures that if a timer
with 1.0s timeout has accumulated 1.05s, the next period starts with 0.05s
already elapsed. This prevents drift over many periods.

One-shot timers remain in the registry after firing (just disabled). This allows
querying their elapsed time. Call DestroyTimer to fully remove them.

The TIMER_EXPIRE vs TIMER_PERIODIC distinction exists for filtering purposes.
A trigger registered for TIMER_PERIODIC won't accidentally catch one-shot
timer events, even if both share the same timer_id space.

WC3 compatibility note: In WC3, CreateTimer() creates a timer handle, then
TimerStart() begins it. Our simplified API combines these into
TriggerRegisterTimerEvent for the common case. A more complete implementation
might separate timer creation from trigger registration.

---

## Implementation Notes

**Completed:** 2025-12-27

### Files Modified

| File | Description |
|------|-------------|
| `src/runtime/init.lua` | Added timer storage, TriggerRegisterTimerEvent, CreateTimer, TimerStart, Pause/Resume/Destroy, accessors |
| `src/runtime/events.lua` | Added update_timers(dt, runtime) function |
| `src/tests/test_events_308b.lua` | Test suite with 38 tests |

### Timer Functions Implemented

| Function | Description |
|----------|-------------|
| `TriggerRegisterTimerEvent(trigger, timeout, periodic)` | Register trigger to fire on timer |
| `CreateTimer()` | Create standalone timer |
| `TimerStart(timer, timeout, periodic, callback)` | Start timer with callback |
| `PauseTimer(timer)` | Pause timer accumulation |
| `ResumeTimer(timer)` | Resume paused timer |
| `DestroyTimer(timer)` | Remove timer completely |
| `TimerGetElapsed(timer)` | Get accumulated time |
| `TimerGetRemaining(timer)` | Get time until next fire |
| `TimerGetTimeout(timer)` | Get timeout period |
| `IsTimerPeriodic(timer)` | Check if periodic |

### Timer Storage Design

- Timers stored in `runtime._timers[id]` keyed by unique ID
- Each timer: `{id, trigger, timeout, periodic, elapsed, enabled, listener, callback}`
- Two usage patterns:
  1. `TriggerRegisterTimerEvent`: Links timer to trigger, fires event on timeout
  2. `CreateTimer` + `TimerStart`: Standalone timer with callback function

### update_timers Behavior

- Called by game loop (401) with delta time
- Iterates all enabled timers, accumulates elapsed time
- When elapsed >= timeout:
  - Fires callback if present (standalone timer)
  - Fires event if trigger attached
  - Periodic: resets elapsed with overflow preservation
  - One-shot: disables timer (remains in registry)

### Test Coverage

38 tests covering:
- Timer storage: 3 tests
- TriggerRegisterTimerEvent: 7 tests
- CreateTimer/TimerStart: 4 tests
- Pause/Resume/Destroy: 6 tests
- Timer accessors: 5 tests
- update_timers: 10 tests
- Integration: 3 tests

# Issue 309f: Test Event Dispatch

**Phase:** 3 - Logic Layer
**Type:** Test
**Priority:** Medium
**Parent:** 309-phase-3-integration-test
**Dependencies:** 307-implement-trigger-framework, 308-build-event-dispatch-system

---

## Current Behavior

No tests exist for the event dispatch system. Timer events, region events, unit events,
and player events are untested, leaving the trigger-to-event binding unverified.

---

## Intended Behavior

Comprehensive tests for the event dispatch system covering:
- Timer event registration and firing
- One-shot vs periodic timer behavior
- Event registry operations (register, unregister, fire)
- Event filtering and context passing
- Multiple triggers on the same event
- Event queue processing order

---

## Suggested Implementation Steps

1. **Create test file**
   ```
   src/tests/
   └── test_event_dispatch.lua
   ```

2. **Test event registry basics**
   ```lua
   -- {{{ test_event_registry_basics
   local function test_event_registry_basics()
       local events = require("runtime.events")
       local triggers = require("runtime.triggers")

       -- Create a trigger
       local trigger = triggers.create()
       local fired_count = 0
       triggers.add_action(trigger, function()
           fired_count = fired_count + 1
       end)

       -- Register for an event
       local listener = events.registry:register(
           events.EVENT.TIMER_EXPIRE,
           trigger,
           function(ctx) return true end  -- No filter
       )

       assert(listener, "Registration should return listener handle")

       -- Fire the event
       events.registry:fire(events.EVENT.TIMER_EXPIRE, {})
       assert(fired_count == 1, "Trigger should have fired once")

       -- Fire again
       events.registry:fire(events.EVENT.TIMER_EXPIRE, {})
       assert(fired_count == 2, "Trigger should have fired twice")

       -- Unregister
       events.registry:unregister(events.EVENT.TIMER_EXPIRE, listener)
       events.registry:fire(events.EVENT.TIMER_EXPIRE, {})
       assert(fired_count == 2, "Trigger should not fire after unregister")

       triggers.destroy(trigger)
       print("  Registry basics: PASSED")
   end
   -- }}}
   ```

3. **Test event filtering**
   ```lua
   -- {{{ test_event_filtering
   local function test_event_filtering()
       local events = require("runtime.events")
       local triggers = require("runtime.triggers")

       local trigger = triggers.create()
       local received_id = nil
       triggers.add_action(trigger, function(ctx)
           received_id = ctx.timer_id
       end)

       -- Register with filter for specific timer_id
       events.registry:register(
           events.EVENT.TIMER_EXPIRE,
           trigger,
           function(ctx) return ctx.timer_id == 42 end
       )

       -- Fire with non-matching ID
       events.registry:fire(events.EVENT.TIMER_EXPIRE, { timer_id = 99 })
       assert(received_id == nil, "Filter should block non-matching event")

       -- Fire with matching ID
       events.registry:fire(events.EVENT.TIMER_EXPIRE, { timer_id = 42 })
       assert(received_id == 42, "Filter should pass matching event")

       triggers.destroy(trigger)
       print("  Event filtering: PASSED")
   end
   -- }}}
   ```

4. **Test one-shot timer events**
   ```lua
   -- {{{ test_oneshot_timer
   local function test_oneshot_timer()
       local runtime = require("runtime")
       local events = require("runtime.events")

       local fired_count = 0
       local trigger = runtime.CreateTrigger()
       runtime.TriggerAddAction(trigger, function()
           fired_count = fired_count + 1
       end)

       -- Register 100ms one-shot timer
       runtime.TriggerRegisterTimerEvent(trigger, 0.1, false)

       -- Simulate 50ms - should not fire
       events.update_timers(0.05)
       assert(fired_count == 0, "Timer should not fire before timeout")

       -- Simulate another 60ms (total 110ms) - should fire once
       events.update_timers(0.06)
       assert(fired_count == 1, "Timer should fire once at timeout")

       -- Simulate more time - should NOT fire again (one-shot)
       events.update_timers(0.2)
       assert(fired_count == 1, "One-shot timer should not repeat")

       runtime.DestroyTrigger(trigger)
       print("  One-shot timer: PASSED")
   end
   -- }}}
   ```

5. **Test periodic timer events**
   ```lua
   -- {{{ test_periodic_timer
   local function test_periodic_timer()
       local runtime = require("runtime")
       local events = require("runtime.events")

       local fired_count = 0
       local trigger = runtime.CreateTrigger()
       runtime.TriggerAddAction(trigger, function()
           fired_count = fired_count + 1
       end)

       -- Register 100ms periodic timer
       runtime.TriggerRegisterTimerEvent(trigger, 0.1, true)

       -- Simulate 250ms - should fire 2 times
       for i = 1, 5 do
           events.update_timers(0.05)
       end
       assert(fired_count == 2, "Periodic timer should fire twice in 250ms: got " .. fired_count)

       -- Simulate another 200ms - should fire 2 more times (4 total)
       for i = 1, 4 do
           events.update_timers(0.05)
       end
       assert(fired_count == 4, "Periodic timer should fire 4 times in 450ms: got " .. fired_count)

       runtime.DestroyTrigger(trigger)
       print("  Periodic timer: PASSED")
   end
   -- }}}
   ```

6. **Test multiple triggers on same event**
   ```lua
   -- {{{ test_multiple_triggers_same_event
   local function test_multiple_triggers_same_event()
       local events = require("runtime.events")
       local triggers = require("runtime.triggers")

       local order = {}

       local trigger1 = triggers.create()
       triggers.add_action(trigger1, function()
           order[#order + 1] = "first"
       end)

       local trigger2 = triggers.create()
       triggers.add_action(trigger2, function()
           order[#order + 1] = "second"
       end)

       -- Register in order
       events.registry:register(events.EVENT.GAME_START, trigger1)
       events.registry:register(events.EVENT.GAME_START, trigger2)

       -- Fire event
       events.registry:fire(events.EVENT.GAME_START, {})

       assert(#order == 2, "Both triggers should fire")
       assert(order[1] == "first", "First registered should fire first")
       assert(order[2] == "second", "Second registered should fire second")

       triggers.destroy(trigger1)
       triggers.destroy(trigger2)
       print("  Multiple triggers same event: PASSED")
   end
   -- }}}
   ```

7. **Test context passing**
   ```lua
   -- {{{ test_context_passing
   local function test_context_passing()
       local events = require("runtime.events")
       local triggers = require("runtime.triggers")

       local received_context = nil
       local trigger = triggers.create()
       triggers.add_action(trigger, function(ctx)
           received_context = ctx
       end)

       events.registry:register(events.EVENT.UNIT_DEATH, trigger)

       -- Fire with context data
       local test_context = {
           event_id = events.EVENT.UNIT_DEATH,
           unit = { id = 123, name = "TestUnit" },
           killer = { id = 456, name = "TestKiller" },
           damage = 100,
       }
       events.registry:fire(events.EVENT.UNIT_DEATH, test_context)

       assert(received_context, "Context should be passed to action")
       assert(received_context.unit.id == 123, "Unit ID should be preserved")
       assert(received_context.killer.id == 456, "Killer ID should be preserved")
       assert(received_context.damage == 100, "Damage should be preserved")

       triggers.destroy(trigger)
       print("  Context passing: PASSED")
   end
   -- }}}
   ```

8. **Test event type constants**
   ```lua
   -- {{{ test_event_type_constants
   local function test_event_type_constants()
       local events = require("runtime.events")

       -- Verify core event types exist
       assert(events.EVENT.MAP_INIT, "MAP_INIT event type should exist")
       assert(events.EVENT.GAME_START, "GAME_START event type should exist")
       assert(events.EVENT.TIMER_EXPIRE, "TIMER_EXPIRE event type should exist")
       assert(events.EVENT.TIMER_PERIODIC, "TIMER_PERIODIC event type should exist")
       assert(events.EVENT.UNIT_DEATH, "UNIT_DEATH event type should exist")
       assert(events.EVENT.UNIT_DAMAGED, "UNIT_DAMAGED event type should exist")
       assert(events.EVENT.UNIT_ENTER_REGION, "UNIT_ENTER_REGION event type should exist")
       assert(events.EVENT.PLAYER_CHAT, "PLAYER_CHAT event type should exist")

       print("  Event type constants: PASSED")
   end
   -- }}}
   ```

9. **Create test runner**
   ```lua
   -- {{{ run_tests
   local function run_tests()
       print("=== Event Dispatch Tests ===")
       print()

       local tests = {
           { "Event registry basics", test_event_registry_basics },
           { "Event filtering", test_event_filtering },
           { "One-shot timer", test_oneshot_timer },
           { "Periodic timer", test_periodic_timer },
           { "Multiple triggers same event", test_multiple_triggers_same_event },
           { "Context passing", test_context_passing },
           { "Event type constants", test_event_type_constants },
       }

       local passed = 0
       local failed = 0

       for _, test in ipairs(tests) do
           local name, fn = test[1], test[2]
           local ok, err = pcall(fn)
           if ok then
               passed = passed + 1
           else
               print("FAIL: " .. name)
               print("  " .. tostring(err))
               failed = failed + 1
           end
       end

       print()
       print(string.format("Event Dispatch: %d/%d tests passed", passed, passed + failed))
       return failed == 0
   end
   -- }}}

   if not run_tests() then os.exit(1) end
   ```

---

## Technical Notes

### Timer Precision

Timer tests use small intervals (100ms) to keep tests fast. The event system
accumulates delta time each tick, so precision depends on tick rate (62.5/sec = 16ms).
Tests should allow for ±1 tick tolerance.

### Event Ordering

WC3 fires triggers in registration order. Tests verify this behavior is preserved
in our implementation.

### Context Immutability

Event context should be treated as read-only by triggers. Tests verify context
is passed correctly but don't test mutation behavior (implementation detail).

---

## Related Documents

- issues/309-phase-3-integration-test.md (parent issue)
- issues/308-build-event-dispatch-system.md (system being tested)
- issues/307-implement-trigger-framework.md (trigger dependency)
- issues/309e-test-trigger-runtime.md (related trigger tests)

---

## Acceptance Criteria

- [ ] Event registry register/unregister/fire operations work
- [ ] Event filters correctly block non-matching events
- [ ] One-shot timers fire exactly once
- [ ] Periodic timers fire at correct intervals
- [ ] Multiple triggers on same event fire in registration order
- [ ] Event context is passed to trigger actions
- [ ] All EVENT type constants are defined
- [ ] All tests complete in under 1 second

---

## Notes

This test suite validates the event dispatch system (issue 308) which bridges
game state changes to trigger execution. Combined with 309e (trigger runtime tests),
these tests prove the complete trigger→event→action pipeline works correctly.

Timer tests simulate time passing rather than using real-time delays, making
tests fast and deterministic.

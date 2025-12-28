# Issue 308a: Implement Event Registry Core

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** High
**Dependencies:** 307-implement-trigger-framework
**Parent Issue:** 308-build-event-dispatch-system

---

## Current Behavior

No event system exists. Triggers can be created (307) but there's no way
to register them for events or fire events when game state changes.

---

## Intended Behavior

A foundational event registry that:
- Defines all event type constants (EVENT.UNIT_DEATH, etc.)
- Stores trigger-to-event bindings
- Fires events to all registered triggers with filtering
- Supports unregistration for cleanup

```lua
local events = require("runtime.events")

-- Register a trigger for an event
local listener = events.register(EVENT.UNIT_DEATH, trigger, filterFunc)

-- Fire an event (called by game systems)
events.fire(EVENT.UNIT_DEATH, {unit = dyingUnit, killer = killerUnit})

-- Unregister when done
events.unregister(listener)
```

---

## Suggested Implementation Steps

1. **Create events.lua module**
   ```lua
   src/runtime/events.lua
   ```

2. **Define EVENT type constants**
   - Game events: MAP_INIT, GAME_START
   - Timer events: TIMER_EXPIRE, TIMER_PERIODIC
   - Unit events: UNIT_DEATH, UNIT_SPAWN, UNIT_DAMAGED, UNIT_ATTACKED, etc.
   - Spell events: UNIT_SPELL_CHANNEL, UNIT_SPELL_CAST, UNIT_SPELL_EFFECT, etc.
   - Region events: UNIT_ENTER_REGION, UNIT_LEAVE_REGION
   - Player events: PLAYER_CHAT, PLAYER_LEAVE, PLAYER_ALLIANCE_CHANGE
   - Dialog events: DIALOG_BUTTON_CLICK
   - Trackable events: TRACKABLE_HIT, TRACKABLE_TRACK

3. **Implement listener storage**
   - Store by event type for efficient lookup
   - Each listener: {trigger, filter, id}

4. **Implement register(event_type, trigger, filter)**
   - Add to listeners[event_type]
   - Return listener handle for unregistration
   - Update trigger.events for cleanup on destroy

5. **Implement unregister(listener)**
   - Remove from event's listener list
   - Remove from trigger.events

6. **Implement fire(event_type, context)**
   - Iterate listeners for event_type
   - Check filter (if present)
   - Call trigger:fire(context)

7. **Add to runtime exports**

---

## Technical Notes

### Listener Structure

```lua
{
    id = <unique id>,
    event_type = EVENT.UNIT_DEATH,
    trigger = <Trigger object>,
    filter = function(ctx) return true end,  -- optional
}
```

### Filter Functions

Filters narrow which triggers receive events:
```lua
-- Only fire for specific unit
function(ctx) return ctx.unit == my_hero end

-- Only fire for player
function(ctx) return ctx.player == Player(0) end
```

### Integration with Triggers

When registering, add entry to trigger.events for cleanup:
```lua
trigger.events[#trigger.events + 1] = {
    type = event_type,
    listener = listener,
    unregister = function() events.unregister(listener) end
}
```

When DestroyTrigger is called, it iterates trigger.events and calls unregister.

---

## Acceptance Criteria

- [x] Created src/runtime/events.lua
- [x] All EVENT type constants defined
- [x] events.register() adds listener correctly
- [x] events.unregister() removes listener correctly
- [x] events.fire() calls trigger:fire() for matching listeners
- [x] Filter functions correctly gate event delivery
- [x] Listeners added to trigger.events for cleanup
- [x] DestroyTrigger cleans up event registrations
- [x] Unit tests for registry operations

---

## Notes

This is the foundation that 308b-e build upon. The core registry is
event-type agnostic - specific event behaviors (timer ticks, region
checks) are added in subsequent sub-issues.

Keep the registry simple and efficient. Events may fire frequently
during gameplay.

---

## Implementation Notes

**Completed:** 2025-12-27

### Files Created/Modified

| File | Description |
|------|-------------|
| `src/runtime/events.lua` | Event registry with register/unregister/fire |
| `src/runtime/init.lua` | Added events module, EVENT export, updated reset/stats |
| `src/tests/test_events_308a.lua` | Test suite with 41 tests |

### EVENT Constants Defined

| Category | Events |
|----------|--------|
| Game | MAP_INIT, GAME_START |
| Timer | TIMER_EXPIRE, TIMER_PERIODIC |
| Unit | UNIT_DEATH, UNIT_SPAWN, UNIT_DAMAGED, UNIT_ATTACKED, UNIT_ACQUIRED_TARGET, UNIT_ISSUED_ORDER, UNIT_ISSUED_POINT_ORDER, UNIT_ISSUED_TARGET_ORDER, UNIT_SELECTED, UNIT_DESELECTED |
| Spell | UNIT_SPELL_CHANNEL, UNIT_SPELL_CAST, UNIT_SPELL_EFFECT, UNIT_SPELL_FINISH, UNIT_SPELL_ENDCAST |
| Region | UNIT_ENTER_REGION, UNIT_LEAVE_REGION |
| Player | PLAYER_CHAT, PLAYER_LEAVE, PLAYER_ALLIANCE_CHANGE, PLAYER_DEFEAT, PLAYER_VICTORY |
| Dialog | DIALOG_BUTTON_CLICK, DIALOG_CLOSE |
| Trackable | TRACKABLE_HIT, TRACKABLE_TRACK |

### Registry API

| Function | Description |
|----------|-------------|
| `register(event_type, trigger, filter)` | Register trigger for event, returns listener handle |
| `unregister(listener)` | Remove listener from registry |
| `fire(event_type, context)` | Fire event to all matching listeners |
| `get_listener_count(event_type)` | Get listener count for specific event |
| `get_total_listener_count()` | Get total listeners across all events |
| `get_stats()` | Get listener statistics for debugging |
| `reset()` | Clear all registrations |

### Design Decisions

1. **Listener storage by event type**: Efficient O(n) lookup where n is listeners for that event type, not total listeners.

2. **List snapshotting during fire**: The listener list is copied before iteration to handle listeners unregistering themselves during fire.

3. **unregister does not touch trigger.events**: To avoid modification-during-iteration bugs when DestroyTrigger iterates trigger.events. DestroyTrigger clears trigger.events after the loop.

4. **Filter function error handling**: Filter errors are caught with pcall; the listener is skipped rather than crashing the event dispatch.

### Test Coverage

41 tests covering:
- EVENT constants: 11 tests
- Register operations: 7 tests
- Unregister operations: 5 tests
- Fire operations: 10 tests
- Trigger integration: 4 tests
- Stats/reset: 4 tests

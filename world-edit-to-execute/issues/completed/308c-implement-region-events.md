# Issue 308c: Implement Region Events

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** High
**Parent Issue:** 308-build-event-dispatch-system.md
**Dependencies:** 308a-implement-event-registry-core

---

## Current Behavior

The event registry from 308a provides infrastructure for event→trigger bindings.
However, there are no region-based events - no way to trigger actions when units
enter or leave defined areas on the map.

Currently:
- No TriggerRegisterEnterRegion function
- No TriggerRegisterLeaveRegion function
- No event firing hooks for region boundary crossings
- No region→trigger binding storage

---

## Intended Behavior

A region event subsystem that provides:

1. **Region Event Registration APIs**:
   - `TriggerRegisterEnterRegion(trigger, region, filter)` - Fire when unit enters
   - `TriggerRegisterLeaveRegion(trigger, region, filter)` - Fire when unit leaves
   - Optional unit filter narrows which units trigger the event

2. **Event Firing Hooks** - Called by future region/collision systems:
   - `events.unit_entered_region(unit, region)` - Fire UNIT_ENTER_REGION
   - `events.unit_left_region(unit, region)` - Fire UNIT_LEAVE_REGION

3. **Event Context Structure**:
   ```lua
   {
       event_id = EVENT.UNIT_ENTER_REGION,  -- or UNIT_LEAVE_REGION
       unit = <entering/leaving unit>,
       region = <region object>,
   }
   ```

4. **Compound Filtering** - Filter combines:
   - Region matching (ctx.region == registered_region)
   - Optional unit filter function from registration

5. **GetTriggeringUnit / GetEnteringUnit / GetLeavingUnit**:
   - Context accessors for trigger actions to use
   - Store current event context for these functions

---

## Suggested Implementation Steps

1. **Implement TriggerRegisterEnterRegion function**
   ```lua
   -- {{{ TriggerRegisterEnterRegion
   function runtime.TriggerRegisterEnterRegion(trigger, region, filter)
       return events.register(
           events.EVENT.UNIT_ENTER_REGION,
           trigger,
           function(ctx)
               -- Must match the registered region
               if ctx.region ~= region then return false end
               -- Apply optional unit filter
               if filter and not filter(ctx.unit) then return false end
               return true
           end
       )
   end
   -- }}}
   ```

2. **Implement TriggerRegisterLeaveRegion function**
   ```lua
   -- {{{ TriggerRegisterLeaveRegion
   function runtime.TriggerRegisterLeaveRegion(trigger, region, filter)
       return events.register(
           events.EVENT.UNIT_LEAVE_REGION,
           trigger,
           function(ctx)
               -- Must match the registered region
               if ctx.region ~= region then return false end
               -- Apply optional unit filter
               if filter and not filter(ctx.unit) then return false end
               return true
           end
       )
   end
   -- }}}
   ```

3. **Implement unit_entered_region fire hook**
   ```lua
   -- {{{ unit_entered_region
   -- Called by region/collision system when unit crosses into region
   function events.unit_entered_region(unit, region)
       events.fire(events.EVENT.UNIT_ENTER_REGION, {
           event_id = events.EVENT.UNIT_ENTER_REGION,
           unit = unit,
           region = region,
           entering_unit = unit,  -- Alias for GetEnteringUnit
       })
   end
   -- }}}
   ```

4. **Implement unit_left_region fire hook**
   ```lua
   -- {{{ unit_left_region
   -- Called by region/collision system when unit crosses out of region
   function events.unit_left_region(unit, region)
       events.fire(events.EVENT.UNIT_LEAVE_REGION, {
           event_id = events.EVENT.UNIT_LEAVE_REGION,
           unit = unit,
           region = region,
           leaving_unit = unit,  -- Alias for GetLeavingUnit
       })
   end
   -- }}}
   ```

5. **Add event context storage for GetTrigger* functions**
   ```lua
   -- In events.lua or runtime
   events._current_context = nil

   -- Modify fire() to store context
   function events.fire(event_type, context)
       local list = events.registry.listeners[event_type]
       if not list then return end

       local old_context = events._current_context
       events._current_context = context

       for _, listener in ipairs(list) do
           if listener.filter(context) then
               listener.trigger:fire(context)
           end
       end

       events._current_context = old_context
   end
   ```

6. **Implement GetEnteringUnit function**
   ```lua
   -- {{{ GetEnteringUnit
   function runtime.GetEnteringUnit()
       local ctx = events._current_context
       if ctx and ctx.entering_unit then
           return ctx.entering_unit
       end
       return nil
   end
   -- }}}
   ```

7. **Implement GetLeavingUnit function**
   ```lua
   -- {{{ GetLeavingUnit
   function runtime.GetLeavingUnit()
       local ctx = events._current_context
       if ctx and ctx.leaving_unit then
           return ctx.leaving_unit
       end
       return nil
   end
   -- }}}
   ```

8. **Implement GetTriggerRegion function**
   ```lua
   -- {{{ GetTriggerRegion
   function runtime.GetTriggerRegion()
       local ctx = events._current_context
       if ctx and ctx.region then
           return ctx.region
       end
       return nil
   end
   -- }}}
   ```

9. **Implement generic GetTriggeringUnit function**
   ```lua
   -- {{{ GetTriggeringUnit
   -- Returns the unit relevant to the current event context
   function runtime.GetTriggeringUnit()
       local ctx = events._current_context
       if not ctx then return nil end
       -- Check various unit fields based on event type
       return ctx.triggering_unit or ctx.unit or ctx.entering_unit or ctx.leaving_unit
   end
   -- }}}
   ```

10. **Write unit tests**
    - Create `src/tests/test_region_events.lua`
    - Test TriggerRegisterEnterRegion creates correct binding
    - Test TriggerRegisterLeaveRegion creates correct binding
    - Test unit_entered_region fires correct event
    - Test unit_left_region fires correct event
    - Test region filter (only matching region triggers)
    - Test unit filter (optional filter function works)
    - Test GetEnteringUnit returns correct unit
    - Test GetLeavingUnit returns correct unit
    - Test GetTriggerRegion returns correct region
    - Test multiple triggers on same region
    - Test same trigger on multiple regions

---

## Related Documents

- issues/308-build-event-dispatch-system.md (parent issue)
- issues/308a-implement-event-registry-core.md (dependency - event registry)
- issues/405-implement-basic-collision-detection.md (will call region hooks)
- src/runtime/events.lua (event registry)
- src/runtime/init.lua (runtime API)

---

## Acceptance Criteria

- [x] TriggerRegisterEnterRegion creates event binding with region filter
- [x] TriggerRegisterLeaveRegion creates event binding with region filter
- [x] Region enter/leave events fire when hooks are called
- [x] Only triggers registered for matching region fire
- [x] Optional unit filter narrows which units trigger event
- [x] events.unit_entered_region(unit, region) fires UNIT_ENTER_REGION
- [x] events.unit_left_region(unit, region) fires UNIT_LEAVE_REGION
- [x] GetEnteringUnit returns unit from enter event context
- [x] GetLeavingUnit returns unit from leave event context
- [x] GetTriggerRegion returns region from event context
- [x] GetTriggeringUnit returns relevant unit for any event
- [x] Event context properly stored/restored during fire
- [x] Unit tests pass for region event operations

---

## Notes

Region events depend on a region/collision system (Phase 4/5) to detect boundary
crossings. This issue implements the event binding and firing infrastructure.
The actual detection of "unit crossed region boundary" will call the hooks
implemented here.

The unit filter parameter allows registering for specific unit types:
```lua
-- Only fire for hero units entering
TriggerRegisterEnterRegion(trig, my_region, function(unit)
    return unit.is_hero
end)
```

Context storage with old_context preservation allows nested event firing.
If an action fires another event, the outer context is restored afterward.

WC3 has separate GetEnteringUnit and GetLeavingUnit for clarity in trigger
actions. We provide both, plus a generic GetTriggeringUnit that works for
any unit-related event.

The region object structure is not defined here - it will be created by
the region/collision system. The event system only stores and compares
region references for filtering purposes.

---

## Implementation Notes

**Completed:** 2025-12-27

### Files Modified

| File | Description |
|------|-------------|
| `src/runtime/init.lua` | Added TriggerRegisterEnterRegion, TriggerRegisterLeaveRegion, GetEnteringUnit, GetLeavingUnit, GetTriggerRegion |
| `src/runtime/events.lua` | Added unit_entered_region, unit_left_region fire hooks |
| `src/tests/test_events_308c.lua` | Test suite with 24 tests |

### Functions Implemented

| Function | Description |
|----------|-------------|
| `TriggerRegisterEnterRegion(trigger, region, filter)` | Register for unit entering region |
| `TriggerRegisterLeaveRegion(trigger, region, filter)` | Register for unit leaving region |
| `GetEnteringUnit()` | Get unit that entered region |
| `GetLeavingUnit()` | Get unit that left region |
| `GetTriggerRegion()` | Get region from event context |
| `events.unit_entered_region(unit, region)` | Fire hook for enter event |
| `events.unit_left_region(unit, region)` | Fire hook for leave event |

### Design Notes

- Region events use compound filtering: region match + optional unit filter
- Fire hooks called by future collision system (Phase 4/5)
- Context includes both `entering_unit`/`leaving_unit` and generic `unit` for accessor compatibility
- Multiple triggers can watch same region; same trigger can watch multiple regions

### Test Coverage

24 tests covering:
- TriggerRegisterEnterRegion: 6 tests
- TriggerRegisterLeaveRegion: 6 tests
- Fire hooks: 3 tests
- Context accessors: 6 tests
- Multiple triggers: 3 tests

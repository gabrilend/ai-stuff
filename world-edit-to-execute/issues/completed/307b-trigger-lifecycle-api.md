# Issue 307b: Trigger Lifecycle API

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** High
**Dependencies:** 307a-trigger-data-structure
**Parent Issue:** 307-implement-trigger-framework

---

## Current Behavior

The Trigger class exists (307a) but there are no runtime API functions
for JASS code to create, destroy, or control triggers. Transpiled code
calling `runtime.CreateTrigger()` will fail.

---

## Intended Behavior

Complete trigger lifecycle management through the runtime API:

```lua
local runtime = require("runtime")

-- Create a new trigger
local t = runtime.CreateTrigger()

-- Check/modify enabled state
print(runtime.IsTriggerEnabled(t))  -- true
runtime.DisableTrigger(t)
print(runtime.IsTriggerEnabled(t))  -- false
runtime.EnableTrigger(t)

-- Destroy when done
runtime.DestroyTrigger(t)
```

These functions match the JASS native signatures exactly for transpiler
compatibility.

---

## Suggested Implementation Steps

1. **Implement CreateTrigger**
   ```lua
   -- {{{ CreateTrigger
   -- native CreateTrigger takes nothing returns trigger
   function runtime.CreateTrigger()
       local trigger = triggers.Trigger.new()
       return trigger
   end
   -- }}}
   ```

2. **Implement DestroyTrigger**
   ```lua
   -- {{{ DestroyTrigger
   -- native DestroyTrigger takes trigger t returns nothing
   function runtime.DestroyTrigger(trigger)
       if not triggers.is_trigger(trigger) then
           return  -- Silent fail for nil/invalid
       end

       -- Unregister from all events (cleanup for 308)
       for _, event in ipairs(trigger.events) do
           if event.unregister then
               event:unregister(trigger)
           end
       end
       trigger.events = {}

       -- Clear conditions and actions
       trigger.conditions = {}
       trigger.actions = {}

       -- Mark as disabled
       trigger.enabled = false

       -- Remove from handle system
       handles.destroy(trigger)
   end
   -- }}}
   ```

3. **Implement EnableTrigger**
   ```lua
   -- {{{ EnableTrigger
   -- native EnableTrigger takes trigger t returns nothing
   function runtime.EnableTrigger(trigger)
       if not triggers.is_trigger(trigger) then
           return
       end
       if not trigger:is_valid() then
           return  -- Already destroyed
       end
       trigger.enabled = true
   end
   -- }}}
   ```

4. **Implement DisableTrigger**
   ```lua
   -- {{{ DisableTrigger
   -- native DisableTrigger takes trigger t returns nothing
   function runtime.DisableTrigger(trigger)
       if not triggers.is_trigger(trigger) then
           return
       end
       if not trigger:is_valid() then
           return
       end
       trigger.enabled = false
   end
   -- }}}
   ```

5. **Implement IsTriggerEnabled**
   ```lua
   -- {{{ IsTriggerEnabled
   -- native IsTriggerEnabled takes trigger t returns boolean
   function runtime.IsTriggerEnabled(trigger)
       if not triggers.is_trigger(trigger) then
           return false
       end
       if not trigger:is_valid() then
           return false
       end
       return trigger.enabled
   end
   -- }}}
   ```

6. **Implement ResetTrigger (optional utility)**
   ```lua
   -- {{{ ResetTrigger
   -- native ResetTrigger takes trigger t returns nothing
   -- Clears wait state (for triggers that use TriggerSleepAction)
   function runtime.ResetTrigger(trigger)
       if not triggers.is_trigger(trigger) then
           return
       end
       -- Reset any internal wait/sleep state
       trigger._wait_state = nil
   end
   -- }}}
   ```

7. **Add null/invalid trigger handling**
   ```lua
   -- {{{ Null trigger constant
   -- In JASS, uninitialized triggers are null
   -- We represent this as nil in Lua

   -- Helper: safe trigger access
   local function validate_trigger(t)
       if t == nil then
           return nil, "null trigger"
       end
       if not triggers.is_trigger(t) then
           return nil, "not a trigger"
       end
       if not t:is_valid() then
           return nil, "destroyed trigger"
       end
       return t, nil
   end
   -- }}}
   ```

8. **Update runtime/init.lua exports**
   ```lua
   -- {{{ Trigger lifecycle (307b)
   runtime.CreateTrigger = CreateTrigger
   runtime.DestroyTrigger = DestroyTrigger
   runtime.EnableTrigger = EnableTrigger
   runtime.DisableTrigger = DisableTrigger
   runtime.IsTriggerEnabled = IsTriggerEnabled
   runtime.ResetTrigger = ResetTrigger
   -- }}}
   ```

9. **Add trigger count utility for debugging**
   ```lua
   -- {{{ TriggerGetExecCount (BJ helper)
   -- This tracks how many times a trigger has executed
   -- Used for debugging and performance monitoring

   function runtime.TriggerGetExecCount(trigger)
       if not triggers.is_trigger(trigger) then
           return 0
       end
       return trigger._exec_count or 0
   end

   -- Internal: increment exec count (called by fire() in 307c)
   function triggers.increment_exec_count(trigger)
       trigger._exec_count = (trigger._exec_count or 0) + 1
   end
   -- }}}
   ```

---

## Technical Notes

### Null Handling

JASS allows null triggers (uninitialized variables). In Lua:
- Null trigger → `nil`
- All lifecycle functions check for nil/invalid and fail silently
- This matches JASS behavior (no runtime errors for null triggers)

### Destruction Semantics

When a trigger is destroyed:
1. All events are unregistered (prevents future firing)
2. Conditions and actions are cleared (releases function references)
3. Trigger is disabled (extra safety)
4. Handle is removed from registry

After destruction, `is_valid()` returns false and all operations are no-ops.

### Event Unregistration

The `trigger.events` array stores event registrations. Each entry should have:
```lua
{
    type = "event_type",  -- For debugging
    unregister = function(self, trigger) ... end
}
```

The event system (308) populates this when events are registered.

### Thread Safety Note

JASS/WC3 is single-threaded, so we don't need thread synchronization.
However, trigger destruction during execution is possible:

```jass
function DestroyingSelf takes nothing returns nothing
    call DestroyTrigger(GetTriggeringTrigger())  -- Destroys self!
endfunction
```

This is handled by checking `is_valid()` before operations and the
context stacking in 307d.

---

## Related Documents

- issues/307-implement-trigger-framework.md (parent issue)
- issues/307a-trigger-data-structure.md (Trigger class definition)
- issues/307c-condition-action-system.md (conditions/actions use this)
- issues/307d-trigger-context-system.md (GetTriggeringTrigger)
- issues/308-build-event-dispatch.md (event registration)
- src/runtime/handles.lua (handle lifecycle)

---

## Acceptance Criteria

- [x] CreateTrigger() returns new trigger with handle ID
- [x] DestroyTrigger() cleans up trigger completely
- [x] DestroyTrigger() unregisters from all events
- [x] EnableTrigger() sets enabled = true
- [x] DisableTrigger() sets enabled = false
- [x] IsTriggerEnabled() returns correct boolean
- [x] All functions handle nil/invalid triggers gracefully
- [x] Destroyed triggers return false from IsTriggerEnabled
- [x] ResetTrigger() clears wait state
- [x] Functions exported in runtime API
- [x] Unit tests for lifecycle operations

---

## Notes

These lifecycle functions form the foundation for trigger management.
They must be robust because user code may:
- Pass nil/destroyed triggers
- Destroy triggers during execution
- Call enable/disable repeatedly

The design prioritizes silent failure over exceptions, matching JASS
behavior where invalid operations are typically ignored.

The `ResetTrigger` function is technically for resetting wait states
from `TriggerSleepAction`, which is complex to implement (requires
coroutines). For now, it can be a stub.

---

## Implementation Notes

**Completed:** 2025-12-27

### Functions Added to runtime/init.lua

| Function | Description |
|----------|-------------|
| `CreateTrigger()` | Creates new trigger, returns Trigger object |
| `DestroyTrigger(t)` | Cleans up trigger: unregisters events, clears conditions/actions, removes handle |
| `EnableTrigger(t)` | Sets `trigger.enabled = true` |
| `DisableTrigger(t)` | Sets `trigger.enabled = false` |
| `IsTriggerEnabled(t)` | Returns boolean, false for nil/invalid/destroyed |
| `ResetTrigger(t)` | Clears `_wait_state` (stub for future coroutine support) |
| `TriggerGetExecCount(t)` | Returns execution count for debugging |

### Error Handling

All functions follow JASS semantics - silent failure for invalid inputs:
- `nil` triggers are ignored
- Non-trigger objects are ignored
- Destroyed triggers are ignored (except IsTriggerEnabled returns false)

### DestroyTrigger Cleanup

1. Calls `unregister()` on each event entry
2. Destroys condition handles via `handles.destroy()`
3. Destroys action handles via `handles.destroy()`
4. Clears all arrays (events, conditions, actions)
5. Sets `enabled = false`
6. Removes from handle system

### Test Coverage

37 tests covering:
- CreateTrigger: 4 tests
- DestroyTrigger: 9 tests
- EnableTrigger: 4 tests
- DisableTrigger: 4 tests
- IsTriggerEnabled: 5 tests
- ResetTrigger: 4 tests
- TriggerGetExecCount: 4 tests
- Integration: 3 tests


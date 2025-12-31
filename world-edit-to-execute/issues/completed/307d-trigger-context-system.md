# Issue 307d: Trigger Context System

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** High
**Dependencies:** 307c-condition-action-system
**Parent Issue:** 307-implement-trigger-framework

---

## Current Behavior

The trigger fire() method (307c) has placeholder calls to context.push()
and context.pop(). Context accessor functions like GetTriggerUnit() are
not implemented. Nested trigger execution is not supported.

---

## Intended Behavior

A complete context stack system that:
- Tracks the current trigger and event data during execution
- Provides accessor functions for event-specific data
- Supports nested triggers (trigger action fires another trigger)
- Maintains proper context when triggers are destroyed mid-execution

```lua
local runtime = require("runtime")

-- During trigger execution, these return event data
local unit = runtime.GetTriggerUnit()      -- Unit that caused event
local player = runtime.GetTriggerPlayer()  -- Player that caused event
local trigger = runtime.GetTriggeringTrigger()  -- The firing trigger

-- Nested triggers work correctly
function OuterAction()
    -- GetTriggeringTrigger() returns outerTrigger
    runtime.TriggerExecute(innerTrigger)
    -- GetTriggeringTrigger() still returns outerTrigger
end
```

---

## Suggested Implementation Steps

1. **Create context module**
   ```lua
   -- {{{ context.lua
   -- Event context stack for trigger execution
   -- Provides GetTriggerUnit, GetTriggerPlayer, etc.

   local context = {}

   -- Context stack for nested trigger execution
   local context_stack = {}

   -- Current context (top of stack)
   local current_context = nil

   return context
   -- }}}
   ```

2. **Implement context structure**
   ```lua
   -- {{{ Context data structure
   -- Each context entry contains:
   -- {
   --     trigger = <trigger object>,
   --     event_id = <event type identifier>,
   --     unit = <triggering unit>,
   --     player = <triggering player>,
   --     -- Event-specific fields:
   --     spell_ability_id = <ability ID>,
   --     ordered_unit = <unit receiving order>,
   --     constructed_structure = <building>,
   --     killing_unit = <unit that killed>,
   --     dying_unit = <unit that died>,
   --     -- ... more as needed by 308
   -- }
   -- }}}
   ```

3. **Implement push/pop operations**
   ```lua
   -- {{{ push
   function context.push(event_data, trigger)
       -- Save current context to stack
       if current_context then
           context_stack[#context_stack + 1] = current_context
       end

       -- Set new context
       current_context = {
           trigger = trigger,
           event_id = event_data and event_data.event_id,
           unit = event_data and event_data.unit,
           player = event_data and event_data.player,
       }

       -- Copy any additional event-specific fields
       if event_data then
           for k, v in pairs(event_data) do
               if current_context[k] == nil then
                   current_context[k] = v
               end
           end
       end
   end
   -- }}}

   -- {{{ pop
   function context.pop()
       -- Restore previous context from stack
       if #context_stack > 0 then
           current_context = context_stack[#context_stack]
           context_stack[#context_stack] = nil
       else
           current_context = nil
       end
   end
   -- }}}
   ```

4. **Implement context accessor**
   ```lua
   -- {{{ get
   function context.get(field)
       if current_context then
           return current_context[field]
       end
       return nil
   end
   -- }}}

   -- {{{ get_current
   function context.get_current()
       return current_context
   end
   -- }}}

   -- {{{ is_active
   function context.is_active()
       return current_context ~= nil
   end
   -- }}}
   ```

5. **Implement GetTriggeringTrigger**
   ```lua
   -- {{{ GetTriggeringTrigger
   -- native GetTriggeringTrigger takes nothing returns trigger
   function runtime.GetTriggeringTrigger()
       return context.get("trigger")
   end
   -- }}}
   ```

6. **Implement GetTriggerEventId**
   ```lua
   -- {{{ GetTriggerEventId
   -- native GetTriggerEventId takes nothing returns eventid
   function runtime.GetTriggerEventId()
       return context.get("event_id")
   end
   -- }}}
   ```

7. **Implement GetTriggerUnit**
   ```lua
   -- {{{ GetTriggerUnit
   -- native GetTriggerUnit takes nothing returns unit
   -- Returns the unit that caused the event to fire
   function runtime.GetTriggerUnit()
       return context.get("unit")
   end
   -- }}}
   ```

8. **Implement GetTriggerPlayer**
   ```lua
   -- {{{ GetTriggerPlayer
   -- native GetTriggerPlayer takes nothing returns player
   -- Returns the player that caused the event to fire
   function runtime.GetTriggerPlayer()
       return context.get("player")
   end
   -- }}}
   ```

9. **Implement event-specific accessors**
   ```lua
   -- {{{ Spell event accessors
   -- native GetSpellAbilityId takes nothing returns integer
   function runtime.GetSpellAbilityId()
       return context.get("spell_ability_id")
   end

   -- native GetSpellAbilityUnit takes nothing returns unit
   function runtime.GetSpellAbilityUnit()
       return context.get("unit")  -- Same as GetTriggerUnit for spell events
   end

   -- native GetSpellTargetUnit takes nothing returns unit
   function runtime.GetSpellTargetUnit()
       return context.get("spell_target_unit")
   end

   -- native GetSpellTargetX takes nothing returns real
   function runtime.GetSpellTargetX()
       return context.get("spell_target_x") or 0.0
   end

   -- native GetSpellTargetY takes nothing returns real
   function runtime.GetSpellTargetY()
       return context.get("spell_target_y") or 0.0
   end
   -- }}}

   -- {{{ Order event accessors
   -- native GetOrderedUnit takes nothing returns unit
   function runtime.GetOrderedUnit()
       return context.get("ordered_unit") or context.get("unit")
   end

   -- native GetIssuedOrderId takes nothing returns integer
   function runtime.GetIssuedOrderId()
       return context.get("order_id")
   end

   -- native GetOrderTargetUnit takes nothing returns unit
   function runtime.GetOrderTargetUnit()
       return context.get("order_target_unit")
   end

   -- native GetOrderPointX takes nothing returns real
   function runtime.GetOrderPointX()
       return context.get("order_point_x") or 0.0
   end

   -- native GetOrderPointY takes nothing returns real
   function runtime.GetOrderPointY()
       return context.get("order_point_y") or 0.0
   end
   -- }}}

   -- {{{ Death event accessors
   -- native GetDyingUnit takes nothing returns unit
   function runtime.GetDyingUnit()
       return context.get("dying_unit") or context.get("unit")
   end

   -- native GetKillingUnit takes nothing returns unit
   function runtime.GetKillingUnit()
       return context.get("killing_unit")
   end
   -- }}}

   -- {{{ Construction event accessors
   -- native GetConstructingStructure takes nothing returns unit
   function runtime.GetConstructingStructure()
       return context.get("constructed_structure")
   end

   -- native GetConstructedStructure takes nothing returns unit
   function runtime.GetConstructedStructure()
       return context.get("constructed_structure")
   end
   -- }}}

   -- {{{ Attack event accessors
   -- native GetAttacker takes nothing returns unit
   function runtime.GetAttacker()
       return context.get("attacker")
   end

   -- native GetAttackedUnitBJ takes nothing returns unit
   function runtime.GetAttackedUnitBJ()
       return context.get("attacked_unit") or context.get("unit")
   end
   -- }}}

   -- {{{ Damage event accessors
   -- native GetEventDamage takes nothing returns real
   function runtime.GetEventDamage()
       return context.get("event_damage") or 0.0
   end

   -- native GetEventDamageSource takes nothing returns unit
   function runtime.GetEventDamageSource()
       return context.get("damage_source")
   end
   -- }}}
   ```

10. **Implement context depth tracking (debugging)**
    ```lua
    -- {{{ get_depth
    function context.get_depth()
        return #context_stack + (current_context and 1 or 0)
    end
    -- }}}

    -- {{{ dump (debug helper)
    function context.dump()
        print("Context stack depth:", context.get_depth())
        if current_context then
            print("  Current trigger:", current_context.trigger)
            print("  Event ID:", current_context.event_id)
            print("  Unit:", current_context.unit)
            print("  Player:", current_context.player)
        end
    end
    -- }}}
    ```

11. **Update Trigger:fire() to use context properly**
    ```lua
    -- {{{ Trigger:fire (updated from 307c)
    function Trigger:fire(event_data)
        if not self:is_valid() then
            return false
        end
        if not self.enabled then
            return false
        end

        -- Push context for this trigger execution
        context.push(event_data, self)

        local should_run = true
        local success_overall = true

        -- Evaluate all conditions
        for _, cond in ipairs(self.conditions) do
            local success, result = pcall(cond.func)
            if not success or not result then
                should_run = false
                break
            end
        end

        -- Execute actions if conditions passed
        if should_run then
            triggers.increment_exec_count(self)

            for _, action in ipairs(self.actions) do
                -- Check trigger still valid (may be destroyed by previous action)
                if not self:is_valid() then
                    break
                end

                local success, err = pcall(action.func)
                if not success then
                    -- Could log: print("Trigger action error:", err)
                end
            end
        end

        -- Pop context (restore previous)
        context.pop()

        return should_run
    end
    -- }}}
    ```

12. **Update runtime exports**
    ```lua
    -- {{{ Context accessors (307d)
    runtime.GetTriggeringTrigger = GetTriggeringTrigger
    runtime.GetTriggerEventId = GetTriggerEventId
    runtime.GetTriggerUnit = GetTriggerUnit
    runtime.GetTriggerPlayer = GetTriggerPlayer
    runtime.GetSpellAbilityId = GetSpellAbilityId
    runtime.GetSpellAbilityUnit = GetSpellAbilityUnit
    runtime.GetSpellTargetUnit = GetSpellTargetUnit
    runtime.GetSpellTargetX = GetSpellTargetX
    runtime.GetSpellTargetY = GetSpellTargetY
    runtime.GetOrderedUnit = GetOrderedUnit
    runtime.GetIssuedOrderId = GetIssuedOrderId
    runtime.GetOrderTargetUnit = GetOrderTargetUnit
    runtime.GetOrderPointX = GetOrderPointX
    runtime.GetOrderPointY = GetOrderPointY
    runtime.GetDyingUnit = GetDyingUnit
    runtime.GetKillingUnit = GetKillingUnit
    runtime.GetConstructingStructure = GetConstructingStructure
    runtime.GetConstructedStructure = GetConstructedStructure
    runtime.GetAttacker = GetAttacker
    runtime.GetAttackedUnitBJ = GetAttackedUnitBJ
    runtime.GetEventDamage = GetEventDamage
    runtime.GetEventDamageSource = GetEventDamageSource
    -- }}}
    ```

---

## Technical Notes

### Context Stack

The context stack allows nested trigger execution:

```
Trigger A fires
  → push context A
  → Action of A fires Trigger B
    → push context B
    → GetTriggerUnit() returns B's unit
    → pop context B
  → GetTriggerUnit() returns A's unit
  → pop context A
```

### Event Data Structure

The event system (308) will create event_data objects like:

```lua
{
    event_id = EVENT_UNIT_DEATH,
    unit = dying_unit,
    player = owning_player,
    killing_unit = killer,
    dying_unit = dying_unit,
}
```

The context module copies all fields, making them accessible via `context.get()`.

### Fallback Values

Many accessors return fallback values (0.0, nil) when not in context or
when the specific field isn't set. This prevents crashes for:
- Accessing context outside trigger execution
- Using wrong accessor for event type

### Self-Destruction Safety

Triggers can destroy themselves during action execution:

```jass
function DestroySelf takes nothing returns nothing
    call DestroyTrigger(GetTriggeringTrigger())
endfunction
```

The updated `fire()` method checks `is_valid()` before each action.
The context remains valid until `pop()` is called.

### Performance Consideration

The context stack is a simple array. For deeply nested triggers (rare),
this may grow large. The maximum practical depth is limited by Lua's
call stack, so this shouldn't be an issue.

---

## Related Documents

- issues/307-implement-trigger-framework.md (parent issue)
- issues/307a-trigger-data-structure.md (Trigger class)
- issues/307b-trigger-lifecycle-api.md (GetTriggeringTrigger returns trigger)
- issues/307c-condition-action-system.md (fire() uses context)
- issues/308-build-event-dispatch.md (provides event_data)
- src/runtime/context.lua (new file for context management)

---

## Acceptance Criteria

- [x] Created src/runtime/context.lua
- [x] context.push() stores context and previous context on stack
- [x] context.pop() restores previous context
- [x] context.get() retrieves field from current context
- [x] GetTriggeringTrigger() returns current trigger
- [x] GetTriggerEventId() returns event identifier
- [x] GetTriggerUnit() returns triggering unit
- [x] GetTriggerPlayer() returns triggering player
- [x] Spell event accessors work (GetSpellAbilityId, etc.)
- [x] Order event accessors work (GetOrderedUnit, etc.)
- [x] Death event accessors work (GetDyingUnit, GetKillingUnit)
- [x] Nested trigger execution maintains correct context
- [x] Context accessors return nil/0 when not in context
- [x] Trigger:fire() updated to use context.push/pop
- [x] Self-destructing triggers don't crash
- [x] Unit tests for context stacking

---

## Notes

This completes the trigger framework (307). The remaining piece is the
event system (308) which creates the event_data objects and calls
`trigger:fire(event_data)`.

The context accessors defined here are placeholders that will work once
the event system provides the appropriate data. For now, they return
nil/0 if the context doesn't have the field.

Additional accessors can be added as needed. The pattern is simple:
```lua
function runtime.GetSomeValue()
    return context.get("some_value") or default_value
end
```

The context module is intentionally separate from triggers.lua to keep
concerns isolated and make testing easier.

---

## Implementation Notes

**Completed:** 2025-12-27

### Files Created/Modified

| File | Description |
|------|-------------|
| `src/runtime/context.lua` | Context stack module with push/pop/get |
| `src/runtime/init.lua` | Added context accessors (20+ functions) |
| `src/runtime/triggers.lua` | Updated Trigger:fire() to use context |
| `src/tests/test_triggers_307d.lua` | Test suite with 36 tests |

### Context Module Functions

| Function | Description |
|----------|-------------|
| `push(event_data, trigger)` | Push new context onto stack |
| `pop()` | Pop current context, restore previous |
| `get(field)` | Get field from current context |
| `get_current()` | Get entire current context table |
| `is_active()` | Check if in trigger execution |
| `get_depth()` | Get nesting depth (for debugging) |
| `reset()` | Clear all context state |

### Context Accessors Added

**Core:** GetTriggeringTrigger, GetTriggerEventId, GetTriggerUnit, GetTriggerPlayer

**Spell Events:** GetSpellAbilityId, GetSpellAbilityUnit, GetSpellTargetUnit, GetSpellTargetX, GetSpellTargetY

**Order Events:** GetOrderedUnit, GetIssuedOrderId, GetOrderTargetUnit, GetOrderPointX, GetOrderPointY

**Death Events:** GetDyingUnit, GetKillingUnit

**Construction:** GetConstructingStructure, GetConstructedStructure

**Attack/Damage:** GetAttacker, GetAttackedUnitBJ, GetEventDamage, GetEventDamageSource

**Timer:** GetExpiredTimer

### Stack Design

- Nested triggers push new context, preserving outer context
- Pop restores previous context automatically
- Supports arbitrary nesting depth
- Stack implemented as simple Lua array

### Test Coverage

36 tests covering:
- Context module: 11 tests
- Context accessors: 14 tests
- Trigger:fire context: 5 tests
- Nested triggers: 3 tests
- Self-destruction: 1 test
- Integration: 2 tests

### Total Test Count (Issue 307)

| Sub-Issue | Tests |
|-----------|-------|
| 307a | 34 |
| 307b | 37 |
| 307c | 47 |
| 307d | 36 |
| **Total** | **154** |


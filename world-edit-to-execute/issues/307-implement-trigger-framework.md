# Issue 307: Implement Trigger Condition/Action Framework

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** High
**Dependencies:** 306-create-jass-lua-transpiler

---

## Current Behavior

No runtime support for triggers. Transpiled JASS code cannot execute
because the native trigger API doesn't exist.

---

## Intended Behavior

A trigger runtime framework providing:
- Trigger handle creation and management
- Condition registration and evaluation
- Action registration and execution
- Trigger enable/disable control
- Trigger destruction and cleanup

---

## Suggested Implementation Steps

1. **Create runtime module**
   ```
   src/runtime/
   ├── init.lua         (runtime API)
   ├── handles.lua      (handle management)
   └── triggers.lua     (this issue)
   ```

2. **Define trigger structure**
   ```lua
   local Trigger = {}
   Trigger.__index = Trigger

   function Trigger.new()
       local self = setmetatable({}, Trigger)
       self.enabled = true
       self.conditions = {}
       self.actions = {}
       self.events = {}
       return self
   end
   ```

3. **Implement core trigger API**
   ```lua
   -- CreateTrigger() → trigger
   function runtime.CreateTrigger()
       local trigger = Trigger.new()
       handles.register(trigger, "trigger")
       return trigger
   end

   -- DestroyTrigger(trigger)
   function runtime.DestroyTrigger(trigger)
       -- Unregister from all events
       for _, event in ipairs(trigger.events) do
           event:unregister(trigger)
       end
       trigger.conditions = {}
       trigger.actions = {}
       handles.destroy(trigger)
   end

   -- EnableTrigger(trigger)
   function runtime.EnableTrigger(trigger)
       trigger.enabled = true
   end

   -- DisableTrigger(trigger)
   function runtime.DisableTrigger(trigger)
       trigger.enabled = false
   end

   -- IsTriggerEnabled(trigger) → boolean
   function runtime.IsTriggerEnabled(trigger)
       return trigger.enabled
   end
   ```

4. **Implement condition system**
   ```lua
   -- Condition(function) → conditionfunc
   function runtime.Condition(func)
       return { type = "condition", func = func }
   end

   -- TriggerAddCondition(trigger, condition) → triggercondition
   function runtime.TriggerAddCondition(trigger, condition)
       local cond = {
           func = condition.func,
           trigger = trigger,
       }
       trigger.conditions[#trigger.conditions + 1] = cond
       return cond
   end

   -- TriggerRemoveCondition(trigger, condition)
   function runtime.TriggerRemoveCondition(trigger, condition)
       for i, c in ipairs(trigger.conditions) do
           if c == condition then
               table.remove(trigger.conditions, i)
               return
           end
       end
   end

   -- TriggerEvaluate(trigger) → boolean
   function runtime.TriggerEvaluate(trigger)
       if not trigger.enabled then
           return false
       end
       for _, cond in ipairs(trigger.conditions) do
           if not cond.func() then
               return false
           end
       end
       return true
   end
   ```

5. **Implement action system**
   ```lua
   -- TriggerAddAction(trigger, function) → triggeraction
   function runtime.TriggerAddAction(trigger, func)
       local action = {
           func = func,
           trigger = trigger,
       }
       trigger.actions[#trigger.actions + 1] = action
       return action
   end

   -- TriggerRemoveAction(trigger, action)
   function runtime.TriggerRemoveAction(trigger, action)
       for i, a in ipairs(trigger.actions) do
           if a == action then
               table.remove(trigger.actions, i)
               return
           end
       end
   end

   -- TriggerExecute(trigger)
   function runtime.TriggerExecute(trigger)
       if not trigger.enabled then
           return
       end
       for _, action in ipairs(trigger.actions) do
           action.func()
       end
   end
   ```

6. **Implement trigger execution flow**
   ```lua
   -- Internal: Called by event system when trigger fires
   function Trigger:fire(event_data)
       if not self.enabled then
           return
       end

       -- Set event context (GetTriggerUnit, etc.)
       runtime._event_context = event_data

       -- Evaluate conditions
       local should_run = true
       for _, cond in ipairs(self.conditions) do
           if not cond.func() then
               should_run = false
               break
           end
       end

       -- Execute actions if conditions passed
       if should_run then
           for _, action in ipairs(self.actions) do
               action.func()
           end
       end

       -- Clear event context
       runtime._event_context = nil
   end
   ```

7. **Implement trigger context functions**
   ```lua
   -- GetTriggeringTrigger() → trigger
   function runtime.GetTriggeringTrigger()
       return runtime._current_trigger
   end

   -- GetTriggerEventId() → eventid
   function runtime.GetTriggerEventId()
       return runtime._event_context and runtime._event_context.event_id
   end

   -- GetTriggerUnit() → unit
   function runtime.GetTriggerUnit()
       return runtime._event_context and runtime._event_context.unit
   end

   -- GetTriggerPlayer() → player
   function runtime.GetTriggerPlayer()
       return runtime._event_context and runtime._event_context.player
   end
   ```

---

## Technical Notes

### Trigger Lifecycle

1. **Creation:** `CreateTrigger()` allocates handle
2. **Setup:** Add events, conditions, actions
3. **Registration:** Events register trigger with dispatch
4. **Firing:** Event occurs → conditions checked → actions run
5. **Destruction:** `DestroyTrigger()` cleans up

### Condition Evaluation

All conditions must return true for actions to execute:
```lua
-- AND logic (default JASS behavior)
for _, cond in ipairs(conditions) do
    if not cond.func() then return false end
end
return true
```

### Event Context

During trigger execution, context functions provide access to event data:
- `GetTriggerUnit()` - Unit that caused the event
- `GetTriggerPlayer()` - Player that caused the event
- `GetTriggeringTrigger()` - The trigger itself
- Event-specific: `GetSpellAbilityId()`, `GetOrderedUnit()`, etc.

### Thread Safety Considerations

JASS triggers can be nested (trigger action fires another trigger):
```lua
-- Stack-based context management
local context_stack = {}

function push_context(ctx)
    context_stack[#context_stack + 1] = runtime._event_context
    runtime._event_context = ctx
end

function pop_context()
    runtime._event_context = context_stack[#context_stack]
    context_stack[#context_stack] = nil
end
```

---

## Related Documents

- docs/runtime/triggers.md (to be created)
- issues/306-create-jass-lua-transpiler.md (code generation)
- issues/308-build-event-dispatch.md (event system)

---

## Acceptance Criteria

- [ ] CreateTrigger/DestroyTrigger work correctly
- [ ] Enable/Disable trigger functionality
- [ ] Condition registration and evaluation
- [ ] Action registration and execution
- [ ] Trigger context functions (GetTriggerUnit, etc.)
- [ ] Nested trigger support (context stacking)
- [ ] Handle management integration
- [ ] Unit tests for trigger lifecycle

---

## Notes

This framework provides the core trigger mechanics without the event
system. Events (issue 308) will call into this framework when firing.

The design follows WC3's trigger model:
- Triggers are first-class objects
- Multiple conditions evaluated with AND
- Multiple actions executed in order
- Context available during execution

This is the foundation for all gameplay scripting.

Reference: [JASS Trigger API](http://jass.sourceforge.net/doc/)
Reference: [WC3 Trigger Reference](https://www.hiveworkshop.com/)

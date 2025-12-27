# Issue 307c: Condition and Action System

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** High
**Dependencies:** 307a-trigger-data-structure, 307b-trigger-lifecycle-api
**Parent Issue:** 307-implement-trigger-framework

---

## Current Behavior

Triggers can be created and destroyed (307b) but have no way to attach
conditions or actions. The core trigger evaluation and execution logic
is missing.

---

## Intended Behavior

Complete condition and action system for triggers:

```lua
local runtime = require("runtime")

-- Create trigger
local t = runtime.CreateTrigger()

-- Add a condition (returns true/false)
local function myCondition()
    return someValue > 10
end
local cond = runtime.TriggerAddCondition(t, runtime.Condition(myCondition))

-- Add an action (runs if conditions pass)
local function myAction()
    print("Trigger fired!")
end
local act = runtime.TriggerAddAction(t, myAction)

-- Evaluate conditions only (returns boolean)
local passed = runtime.TriggerEvaluate(t)  -- true if all conditions pass

-- Execute actions (runs all actions if trigger enabled)
runtime.TriggerExecute(t)

-- Or fire the trigger (evaluate + execute)
t:fire({unit = someUnit})  -- Internal method for event system

-- Remove condition/action
runtime.TriggerRemoveCondition(t, cond)
runtime.TriggerRemoveAction(t, act)
```

---

## Suggested Implementation Steps

1. **Implement Condition wrapper**
   ```lua
   -- {{{ Condition
   -- native Condition takes code func returns conditionfunc
   -- Wraps a function for use as a trigger condition
   function runtime.Condition(func)
       if type(func) ~= "function" then
           -- Handle invalid input gracefully
           return { type = "condition", func = function() return true end }
       end
       return {
           type = "condition",
           func = func,
       }
   end
   -- }}}
   ```

2. **Implement Filter wrapper (alias)**
   ```lua
   -- {{{ Filter
   -- native Filter takes code func returns filterfunc
   -- Same as Condition, used for enumeration filtering
   function runtime.Filter(func)
       return runtime.Condition(func)
   end
   -- }}}
   ```

3. **Implement TriggerAddCondition**
   ```lua
   -- {{{ TriggerAddCondition
   -- native TriggerAddCondition takes trigger t, conditionfunc c returns triggercondition
   function runtime.TriggerAddCondition(trigger, condition)
       if not triggers.is_trigger(trigger) or not trigger:is_valid() then
           return nil
       end
       if type(condition) ~= "table" or condition.type ~= "condition" then
           return nil
       end

       local triggercondition = {
           func = condition.func,
           trigger = trigger,
           _handle_type = "triggercondition",
       }

       -- Register with handle system
       handles.register(triggercondition, "triggercondition")

       -- Add to trigger's condition list
       trigger.conditions[#trigger.conditions + 1] = triggercondition

       return triggercondition
   end
   -- }}}
   ```

4. **Implement TriggerRemoveCondition**
   ```lua
   -- {{{ TriggerRemoveCondition
   -- native TriggerRemoveCondition takes trigger t, triggercondition c returns nothing
   function runtime.TriggerRemoveCondition(trigger, condition)
       if not triggers.is_trigger(trigger) or not trigger:is_valid() then
           return
       end
       if condition == nil then
           return
       end

       for i, c in ipairs(trigger.conditions) do
           if c == condition then
               table.remove(trigger.conditions, i)
               handles.destroy(condition)
               return
           end
       end
   end
   -- }}}
   ```

5. **Implement TriggerClearConditions**
   ```lua
   -- {{{ TriggerClearConditions
   -- native TriggerClearConditions takes trigger t returns nothing
   function runtime.TriggerClearConditions(trigger)
       if not triggers.is_trigger(trigger) or not trigger:is_valid() then
           return
       end

       -- Destroy all condition handles
       for _, cond in ipairs(trigger.conditions) do
           handles.destroy(cond)
       end

       trigger.conditions = {}
   end
   -- }}}
   ```

6. **Implement TriggerEvaluate**
   ```lua
   -- {{{ TriggerEvaluate
   -- native TriggerEvaluate takes trigger t returns boolean
   -- Evaluates all conditions with AND logic
   function runtime.TriggerEvaluate(trigger)
       if not triggers.is_trigger(trigger) or not trigger:is_valid() then
           return false
       end
       if not trigger.enabled then
           return false
       end

       -- All conditions must return true (AND logic)
       for _, cond in ipairs(trigger.conditions) do
           local success, result = pcall(cond.func)
           if not success then
               -- Condition threw error - treat as false
               -- Optionally log: print("Condition error:", result)
               return false
           end
           if not result then
               return false
           end
       end

       return true
   end
   -- }}}
   ```

7. **Implement TriggerAddAction**
   ```lua
   -- {{{ TriggerAddAction
   -- native TriggerAddAction takes trigger t, code func returns triggeraction
   function runtime.TriggerAddAction(trigger, func)
       if not triggers.is_trigger(trigger) or not trigger:is_valid() then
           return nil
       end
       if type(func) ~= "function" then
           return nil
       end

       local triggeraction = {
           func = func,
           trigger = trigger,
           _handle_type = "triggeraction",
       }

       -- Register with handle system
       handles.register(triggeraction, "triggeraction")

       -- Add to trigger's action list
       trigger.actions[#trigger.actions + 1] = triggeraction

       return triggeraction
   end
   -- }}}
   ```

8. **Implement TriggerRemoveAction**
   ```lua
   -- {{{ TriggerRemoveAction
   -- native TriggerRemoveAction takes trigger t, triggeraction a returns nothing
   function runtime.TriggerRemoveAction(trigger, action)
       if not triggers.is_trigger(trigger) or not trigger:is_valid() then
           return
       end
       if action == nil then
           return
       end

       for i, a in ipairs(trigger.actions) do
           if a == action then
               table.remove(trigger.actions, i)
               handles.destroy(action)
               return
           end
       end
   end
   -- }}}
   ```

9. **Implement TriggerClearActions**
   ```lua
   -- {{{ TriggerClearActions
   -- native TriggerClearActions takes trigger t returns nothing
   function runtime.TriggerClearActions(trigger)
       if not triggers.is_trigger(trigger) or not trigger:is_valid() then
           return
       end

       -- Destroy all action handles
       for _, action in ipairs(trigger.actions) do
           handles.destroy(action)
       end

       trigger.actions = {}
   end
   -- }}}
   ```

10. **Implement TriggerExecute**
    ```lua
    -- {{{ TriggerExecute
    -- native TriggerExecute takes trigger t returns nothing
    -- Executes all actions (does NOT check conditions)
    function runtime.TriggerExecute(trigger)
        if not triggers.is_trigger(trigger) or not trigger:is_valid() then
            return
        end
        if not trigger.enabled then
            return
        end

        -- Track execution count
        triggers.increment_exec_count(trigger)

        -- Execute each action in order
        for _, action in ipairs(trigger.actions) do
            local success, err = pcall(action.func)
            if not success then
                -- Action threw error - log but continue
                -- print("Action error:", err)
            end
        end
    end
    -- }}}
    ```

11. **Implement Trigger:fire() internal method**
    ```lua
    -- {{{ Trigger:fire
    -- Internal: Called by event system when trigger should fire
    -- Evaluates conditions, then executes actions if passed
    function Trigger:fire(event_data)
        if not self:is_valid() then
            return false
        end
        if not self.enabled then
            return false
        end

        -- Push event context (implemented in 307d)
        local context = require("runtime.context")
        context.push(event_data, self)

        -- Evaluate all conditions
        local should_run = true
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
                local success, err = pcall(action.func)
                if not success then
                    -- Log error but continue with other actions
                end
            end
        end

        -- Pop event context
        context.pop()

        return should_run
    end
    -- }}}
    ```

12. **Update runtime exports**
    ```lua
    -- {{{ Condition/Action system (307c)
    runtime.Condition = Condition
    runtime.Filter = Filter
    runtime.TriggerAddCondition = TriggerAddCondition
    runtime.TriggerRemoveCondition = TriggerRemoveCondition
    runtime.TriggerClearConditions = TriggerClearConditions
    runtime.TriggerEvaluate = TriggerEvaluate
    runtime.TriggerAddAction = TriggerAddAction
    runtime.TriggerRemoveAction = TriggerRemoveAction
    runtime.TriggerClearActions = TriggerClearActions
    runtime.TriggerExecute = TriggerExecute
    -- }}}
    ```

---

## Technical Notes

### AND Logic for Conditions

All conditions must return true for actions to execute:
```lua
for _, cond in ipairs(conditions) do
    if not cond.func() then
        return false  -- Short-circuit on first failure
    end
end
return true
```

This matches JASS behavior. For OR logic, the map script must implement
it manually (e.g., one condition that checks multiple things).

### Error Handling

Conditions and actions are wrapped in `pcall()`:
- If a condition throws, it's treated as returning false
- If an action throws, execution continues with the next action
- This prevents one bad function from breaking all triggers

### Condition vs Action Distinction

- **Condition**: Returns boolean, determines IF actions run
- **Action**: Returns nothing, performs side effects

Both are wrapped in handles so they can be removed individually.

### TriggerExecute vs fire()

- `TriggerExecute()`: Public API, runs actions WITHOUT checking conditions
- `Trigger:fire()`: Internal method, checks conditions THEN runs actions

This matches JASS where `TriggerExecute` is a native that skips conditions.

### Order Preservation

Conditions and actions are stored in arrays and evaluated/executed in
the order they were added. This matches JASS behavior.

---

## Related Documents

- issues/307-implement-trigger-framework.md (parent issue)
- issues/307a-trigger-data-structure.md (trigger.conditions, trigger.actions)
- issues/307b-trigger-lifecycle-api.md (CreateTrigger, DestroyTrigger)
- issues/307d-trigger-context-system.md (context.push/pop in fire())
- issues/308-build-event-dispatch.md (calls fire())
- src/runtime/handles.lua (handle registration for conditions/actions)

---

## Acceptance Criteria

- [x] Condition() wraps function in condition object
- [x] Filter() works as Condition alias
- [x] TriggerAddCondition() adds condition to trigger
- [x] TriggerRemoveCondition() removes specific condition
- [x] TriggerClearConditions() removes all conditions
- [x] TriggerEvaluate() returns true only if ALL conditions pass
- [x] TriggerEvaluate() returns false for disabled triggers
- [x] TriggerAddAction() adds action to trigger
- [x] TriggerRemoveAction() removes specific action
- [x] TriggerClearActions() removes all actions
- [x] TriggerExecute() runs all actions (skips condition check)
- [x] Trigger:fire() checks conditions then runs actions
- [x] Error in condition doesn't crash, returns false
- [x] Error in action doesn't crash, continues to next action
- [x] Condition/action handles properly registered/destroyed
- [x] Unit tests for condition evaluation and action execution

---

## Notes

This is the core of the trigger system - where conditions are evaluated
and actions are executed. The implementation must be robust because:

1. User code may have bugs (pcall protection)
2. Conditions may be removed during evaluation (use index, not iterator)
3. Actions may destroy the trigger itself (check is_valid)

The `fire()` method is designed to be called by the event system (308).
The context parameter provides access to event-specific data like
`GetTriggerUnit()`.

For now, `Trigger:fire()` calls into a stub context module. The full
context system is implemented in 307d.

---

## Implementation Notes

**Completed:** 2025-12-27

### Functions Added to runtime/init.lua

| Function | Description |
|----------|-------------|
| `Condition(func)` | Wraps function as condition object |
| `Filter(func)` | Alias for Condition (used in enumerations) |
| `TriggerAddCondition(t, c)` | Adds condition to trigger, returns handle |
| `TriggerRemoveCondition(t, c)` | Removes specific condition |
| `TriggerClearConditions(t)` | Removes all conditions |
| `TriggerEvaluate(t)` | Evaluates all conditions (AND logic) |
| `TriggerAddAction(t, func)` | Adds action to trigger, returns handle |
| `TriggerRemoveAction(t, a)` | Removes specific action |
| `TriggerClearActions(t)` | Removes all actions |
| `TriggerExecute(t)` | Runs all actions (skips conditions) |

### Method Added to Trigger Class

| Method | Description |
|--------|-------------|
| `Trigger:fire(event_data)` | Evaluates conditions, runs actions if passed |

### Condition Evaluation

- AND logic: all conditions must return true
- pcall protection: errors treated as false
- Short-circuit: stops on first failure
- Returns true with no conditions

### Action Execution

- Runs in order of addition
- pcall protection: continues after error
- Checks `is_valid()` between actions (self-destruction safe)
- TriggerExecute skips conditions
- Trigger:fire checks conditions first

### Handle System Integration

- Conditions registered as "triggercondition" handles
- Actions registered as "triggeraction" handles
- Handles destroyed on remove/clear/trigger destroy

### Test Coverage

47 tests covering:
- Condition/Filter: 3 tests
- TriggerAddCondition: 4 tests
- TriggerRemoveCondition: 3 tests
- TriggerClearConditions: 3 tests
- TriggerEvaluate: 6 tests
- TriggerAddAction: 4 tests
- TriggerRemoveAction: 3 tests
- TriggerClearActions: 3 tests
- TriggerExecute: 7 tests
- Trigger:fire: 7 tests
- Integration: 4 tests


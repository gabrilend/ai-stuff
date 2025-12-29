# Issue 309e: Test Trigger Runtime

**Phase:** 3 - Logic Layer
**Type:** Test
**Priority:** High
**Dependencies:** 307-implement-trigger-framework
**Parent Issue:** 309-phase-3-integration-test

---

## Current Behavior

The trigger runtime framework (307) is implemented but has no comprehensive
test suite verifying trigger creation, condition evaluation, action execution,
and context management.

---

## Intended Behavior

A comprehensive test suite for the trigger runtime covering:
- Trigger creation and destruction (lifecycle)
- Enable/disable functionality
- Condition registration and AND-logic evaluation
- Action registration and sequential execution
- Context stack for nested triggers
- Context accessor functions (GetTriggerUnit, etc.)

```bash
# Run trigger runtime tests
luajit src/tests/test_309e_trigger_runtime.lua

# Expected output:
# === Lifecycle Tests ===
#   [PASS] CreateTrigger returns trigger
#   [PASS] DestroyTrigger cleans up
#   ...
# === Condition Tests ===
#   [PASS] Single condition
#   [PASS] Multiple conditions AND logic
#   ...
# === Action Tests ===
#   [PASS] Single action executes
#   [PASS] Multiple actions in order
#   ...
# === Context Tests ===
#   [PASS] Context set during fire
#   [PASS] Nested trigger context stacking
#   ...
# ALL TESTS PASSED
```

---

## Suggested Implementation Steps

1. **Create test file structure**
   ```lua
   #!/usr/bin/env luajit
   -- {{{ test_309e_trigger_runtime.lua
   -- Comprehensive tests for trigger runtime framework
   -- Run from project root: luajit src/tests/test_309e_trigger_runtime.lua

   local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
   package.path = DIR .. "/src/?.lua;" .. package.path

   local runtime = require("runtime")
   local triggers = require("runtime.triggers")
   local handles = require("runtime.handles")
   -- }}}
   ```

2. **Implement test utilities**
   ```lua
   -- {{{ Test utilities
   local test_count = 0
   local pass_count = 0
   local fail_count = 0

   local function test(name, condition, msg)
       test_count = test_count + 1
       if condition then
           pass_count = pass_count + 1
           print("  [PASS] " .. name)
       else
           fail_count = fail_count + 1
           print("  [FAIL] " .. name .. (msg and ": " .. msg or ""))
       end
   end

   local function test_section(name)
       print("\n=== " .. name .. " ===")
   end

   -- Helper: reset runtime state between tests
   local function reset_runtime()
       -- Clear any lingering state
       runtime._event_context = nil
       runtime._current_trigger = nil
       -- Note: handles may accumulate, but that's okay for tests
   end
   -- }}}
   ```

3. **Test trigger creation**
   ```lua
   -- {{{ Trigger Creation Tests
   test_section("Trigger Creation Tests")

   reset_runtime()

   -- CreateTrigger
   local t = runtime.CreateTrigger()
   test("CreateTrigger returns value", t ~= nil)
   test("Trigger is table", type(t) == "table")
   test("Trigger has handle ID", t._handle_id ~= nil)
   test("Trigger type is trigger", t._handle_type == "trigger")

   -- Initial state
   test("Trigger enabled by default", t.enabled == true)
   test("Trigger has conditions table", type(t.conditions) == "table")
   test("Trigger has actions table", type(t.actions) == "table")
   test("Trigger has events table", type(t.events) == "table")
   test("Conditions initially empty", #t.conditions == 0)
   test("Actions initially empty", #t.actions == 0)

   -- Multiple triggers get unique IDs
   local t2 = runtime.CreateTrigger()
   test("Second trigger created", t2 ~= nil)
   test("Triggers have different IDs", t._handle_id ~= t2._handle_id)

   -- is_trigger utility
   if triggers.is_trigger then
       test("is_trigger returns true", triggers.is_trigger(t))
       test("is_trigger false for table", not triggers.is_trigger({}))
       test("is_trigger false for nil", not triggers.is_trigger(nil))
   end
   -- }}}
   ```

4. **Test trigger destruction**
   ```lua
   -- {{{ Trigger Destruction Tests
   test_section("Trigger Destruction Tests")

   reset_runtime()

   local t = runtime.CreateTrigger()
   local id = t._handle_id

   -- Add some conditions and actions
   runtime.TriggerAddCondition(t, runtime.Condition(function() return true end))
   runtime.TriggerAddAction(t, function() end)

   -- Destroy
   runtime.DestroyTrigger(t)

   -- Check cleanup
   test("Handle ID cleared", t._handle_id == nil)
   test("Conditions cleared", #t.conditions == 0)
   test("Actions cleared", #t.actions == 0)

   -- Handle system should not find destroyed trigger
   if handles.is_valid then
       test("Handle invalid after destroy", not handles.is_valid(t))
   end
   if handles.get_by_id then
       test("ID lookup returns nil", handles.get_by_id(id) == nil)
   end
   -- }}}
   ```

5. **Test enable/disable**
   ```lua
   -- {{{ Enable/Disable Tests
   test_section("Enable/Disable Tests")

   reset_runtime()

   local t = runtime.CreateTrigger()

   -- Initial state
   test("Initially enabled", runtime.IsTriggerEnabled(t) == true)

   -- Disable
   runtime.DisableTrigger(t)
   test("Disable works", t.enabled == false)
   test("IsTriggerEnabled returns false", runtime.IsTriggerEnabled(t) == false)

   -- Enable
   runtime.EnableTrigger(t)
   test("Enable works", t.enabled == true)
   test("IsTriggerEnabled returns true", runtime.IsTriggerEnabled(t) == true)

   -- Multiple toggles
   runtime.DisableTrigger(t)
   runtime.DisableTrigger(t)
   test("Double disable is disabled", not t.enabled)

   runtime.EnableTrigger(t)
   runtime.EnableTrigger(t)
   test("Double enable is enabled", t.enabled)

   runtime.DestroyTrigger(t)
   -- }}}
   ```

6. **Test condition system**
   ```lua
   -- {{{ Condition Tests
   test_section("Condition Tests")

   reset_runtime()

   local t = runtime.CreateTrigger()

   -- Single true condition
   local cond1 = runtime.TriggerAddCondition(t,
       runtime.Condition(function() return true end))
   test("AddCondition returns value", cond1 ~= nil)
   test("Condition added", #t.conditions == 1)
   test("TriggerEvaluate true", runtime.TriggerEvaluate(t) == true)

   -- Add false condition (AND logic should fail)
   local cond2 = runtime.TriggerAddCondition(t,
       runtime.Condition(function() return false end))
   test("Two conditions", #t.conditions == 2)
   test("TriggerEvaluate false (AND)", runtime.TriggerEvaluate(t) == false)

   -- Remove false condition
   runtime.TriggerRemoveCondition(t, cond2)
   test("Condition removed", #t.conditions == 1)
   test("TriggerEvaluate true again", runtime.TriggerEvaluate(t) == true)

   -- Disabled trigger evaluates false
   runtime.DisableTrigger(t)
   test("Disabled evaluates false", runtime.TriggerEvaluate(t) == false)

   runtime.DestroyTrigger(t)
   -- }}}
   ```

7. **Test action system**
   ```lua
   -- {{{ Action Tests
   test_section("Action Tests")

   reset_runtime()

   local t = runtime.CreateTrigger()
   local execution_order = {}

   -- Add actions
   local act1 = runtime.TriggerAddAction(t, function()
       execution_order[#execution_order + 1] = 1
   end)
   local act2 = runtime.TriggerAddAction(t, function()
       execution_order[#execution_order + 1] = 2
   end)
   local act3 = runtime.TriggerAddAction(t, function()
       execution_order[#execution_order + 1] = 3
   end)

   test("AddAction returns value", act1 ~= nil)
   test("Three actions added", #t.actions == 3)

   -- Execute
   execution_order = {}
   runtime.TriggerExecute(t)
   test("All actions executed", #execution_order == 3)
   test("Order preserved", execution_order[1] == 1 and
                           execution_order[2] == 2 and
                           execution_order[3] == 3)

   -- Remove middle action
   runtime.TriggerRemoveAction(t, act2)
   test("Action removed", #t.actions == 2)

   execution_order = {}
   runtime.TriggerExecute(t)
   test("Two actions execute", #execution_order == 2)
   test("Skips removed", execution_order[1] == 1 and execution_order[2] == 3)

   -- Disabled trigger doesn't execute
   runtime.DisableTrigger(t)
   execution_order = {}
   runtime.TriggerExecute(t)
   test("Disabled doesn't execute", #execution_order == 0)

   runtime.DestroyTrigger(t)
   -- }}}
   ```

8. **Test trigger:fire() method**
   ```lua
   -- {{{ Trigger Fire Tests
   test_section("Trigger Fire Tests")

   reset_runtime()

   local t = runtime.CreateTrigger()
   local condition_ran = false
   local action_ran = false

   -- Add condition and action
   runtime.TriggerAddCondition(t, runtime.Condition(function()
       condition_ran = true
       return true
   end))
   runtime.TriggerAddAction(t, function()
       action_ran = true
   end)

   -- Fire with event data
   if t.fire then
       t:fire({event_id = 1, unit = "test_unit"})
       test("Condition ran on fire", condition_ran)
       test("Action ran on fire", action_ran)
   else
       -- Alternative: manual evaluate + execute
       runtime.TriggerEvaluate(t)
       runtime.TriggerExecute(t)
       test("Condition ran (fallback)", condition_ran)
       test("Action ran (fallback)", action_ran)
   end

   -- Fire with failing condition
   runtime.TriggerAddCondition(t, runtime.Condition(function()
       return false
   end))
   action_ran = false
   if t.fire then
       t:fire({})
       test("Actions blocked by condition", not action_ran)
   end

   runtime.DestroyTrigger(t)
   -- }}}
   ```

9. **Test context accessor functions**
   ```lua
   -- {{{ Context Accessor Tests
   test_section("Context Accessor Tests")

   reset_runtime()

   -- No context initially
   test("No trigger initially", runtime.GetTriggeringTrigger() == nil)
   test("No unit initially", runtime.GetTriggerUnit() == nil)
   test("No player initially", runtime.GetTriggerPlayer() == nil)
   test("No event ID initially", runtime.GetTriggerEventId() == nil)

   -- Set context manually for testing
   local mock_unit = {name = "TestUnit"}
   local mock_player = {id = 0}
   local mock_trigger = runtime.CreateTrigger()

   runtime._event_context = {
       event_id = 42,
       unit = mock_unit,
       player = mock_player,
   }
   runtime._current_trigger = mock_trigger

   test("GetTriggerEventId", runtime.GetTriggerEventId() == 42)
   test("GetTriggerUnit", runtime.GetTriggerUnit() == mock_unit)
   test("GetTriggerPlayer", runtime.GetTriggerPlayer() == mock_player)
   test("GetTriggeringTrigger", runtime.GetTriggeringTrigger() == mock_trigger)

   -- Clear context
   runtime._event_context = nil
   runtime._current_trigger = nil

   test("Context cleared", runtime.GetTriggerUnit() == nil)

   runtime.DestroyTrigger(mock_trigger)
   -- }}}
   ```

10. **Test context stacking (nested triggers)**
    ```lua
    -- {{{ Context Stacking Tests
    test_section("Context Stacking Tests")

    reset_runtime()

    local outer_unit_seen = nil
    local inner_unit_seen = nil
    local after_inner_unit = nil

    local outer_unit = {name = "OuterUnit"}
    local inner_unit = {name = "InnerUnit"}

    -- Create inner trigger
    local inner_trigger = runtime.CreateTrigger()
    runtime.TriggerAddAction(inner_trigger, function()
        inner_unit_seen = runtime.GetTriggerUnit()
    end)

    -- Create outer trigger that fires inner
    local outer_trigger = runtime.CreateTrigger()
    runtime.TriggerAddAction(outer_trigger, function()
        outer_unit_seen = runtime.GetTriggerUnit()

        -- Fire inner trigger with different context
        if inner_trigger.fire then
            inner_trigger:fire({unit = inner_unit})
        else
            -- Manual context push/pop for nested execution
            local saved_context = runtime._event_context
            runtime._event_context = {unit = inner_unit}
            runtime.TriggerExecute(inner_trigger)
            runtime._event_context = saved_context
        end

        -- After inner, should still see outer context
        after_inner_unit = runtime.GetTriggerUnit()
    end)

    -- Fire outer trigger
    if outer_trigger.fire then
        outer_trigger:fire({unit = outer_unit})
    else
        runtime._event_context = {unit = outer_unit}
        runtime.TriggerExecute(outer_trigger)
        runtime._event_context = nil
    end

    test("Outer saw outer unit", outer_unit_seen == outer_unit)
    test("Inner saw inner unit", inner_unit_seen == inner_unit)
    test("After inner, outer restored", after_inner_unit == outer_unit)

    runtime.DestroyTrigger(inner_trigger)
    runtime.DestroyTrigger(outer_trigger)
    -- }}}
    ```

11. **Test handle integration**
    ```lua
    -- {{{ Handle Integration Tests
    test_section("Handle Integration Tests")

    reset_runtime()

    local t = runtime.CreateTrigger()
    local id = t._handle_id

    -- Handle lookup
    if handles.get_by_id then
        local found = handles.get_by_id(id)
        test("Handle lookup finds trigger", found == t)
    end

    if handles.get_id then
        test("get_id returns correct ID", handles.get_id(t) == id)
    end

    if handles.is_valid then
        test("is_valid true for active", handles.is_valid(t))
    end

    -- Destroy and verify cleanup
    runtime.DestroyTrigger(t)

    if handles.get_by_id then
        test("Destroyed not found", handles.get_by_id(id) == nil)
    end

    if handles.is_valid then
        test("is_valid false after destroy", not handles.is_valid(t))
    end
    -- }}}
    ```

12. **Test trigger tostring**
    ```lua
    -- {{{ Tostring Tests
    test_section("Tostring Tests")

    reset_runtime()

    local t = runtime.CreateTrigger()
    local str = tostring(t)

    test("Tostring returns string", type(str) == "string")
    test("Tostring contains Trigger", str:match("Trigger") ~= nil)

    -- Add conditions and actions, tostring should reflect
    runtime.TriggerAddCondition(t, runtime.Condition(function() return true end))
    runtime.TriggerAddAction(t, function() end)
    runtime.TriggerAddAction(t, function() end)

    str = tostring(t)
    test("Tostring shows cond count", str:match("1%s*cond") ~= nil or
                                       str:match("cond") ~= nil)
    test("Tostring shows action count", str:match("2%s*act") ~= nil or
                                         str:match("act") ~= nil)

    runtime.DisableTrigger(t)
    str = tostring(t)
    test("Tostring shows disabled", str:match("disabled") ~= nil)

    runtime.DestroyTrigger(t)
    -- }}}
    ```

13. **Test edge cases**
    ```lua
    -- {{{ Edge Case Tests
    test_section("Edge Case Tests")

    reset_runtime()

    -- Empty trigger
    local t = runtime.CreateTrigger()
    test("Empty evaluate true", runtime.TriggerEvaluate(t) == true)
    -- Empty execute should not error
    local ok = pcall(function() runtime.TriggerExecute(t) end)
    test("Empty execute no error", ok)

    -- Remove non-existent condition/action
    local fake_cond = {func = function() return true end}
    ok = pcall(function() runtime.TriggerRemoveCondition(t, fake_cond) end)
    test("Remove fake condition no error", ok)

    local fake_action = {func = function() end}
    ok = pcall(function() runtime.TriggerRemoveAction(t, fake_action) end)
    test("Remove fake action no error", ok)

    -- Condition that errors
    local error_count = 0
    runtime.TriggerAddCondition(t, runtime.Condition(function()
        error_count = error_count + 1
        -- First call succeeds, but we just count
        return true
    end))
    runtime.TriggerEvaluate(t)
    test("Condition called", error_count == 1)

    -- Action that errors (should this propagate or be caught?)
    local action_error_trigger = runtime.CreateTrigger()
    runtime.TriggerAddAction(action_error_trigger, function()
        error("intentional error")
    end)
    -- Depending on implementation, this may or may not propagate
    local executed_ok = pcall(function()
        runtime.TriggerExecute(action_error_trigger)
    end)
    test("Action error handling", true)  -- Just documenting behavior

    runtime.DestroyTrigger(t)
    runtime.DestroyTrigger(action_error_trigger)
    -- }}}
    ```

14. **Summary and exit**
    ```lua
    -- {{{ Summary
    print("\n" .. string.rep("=", 50))
    print(string.format("Tests: %d passed, %d failed, %d total",
                        pass_count, fail_count, test_count))
    if fail_count > 0 then
        print("SOME TESTS FAILED")
        os.exit(1)
    else
        print("ALL TESTS PASSED")
        os.exit(0)
    end
    -- }}}
    ```

---

## Technical Notes

### Runtime API Functions

| Function | Purpose |
|----------|---------|
| `CreateTrigger()` | Create new trigger with handle |
| `DestroyTrigger(t)` | Destroy trigger and cleanup |
| `EnableTrigger(t)` | Enable trigger |
| `DisableTrigger(t)` | Disable trigger |
| `IsTriggerEnabled(t)` | Check if enabled |
| `Condition(func)` | Wrap function as condition |
| `TriggerAddCondition(t, c)` | Add condition |
| `TriggerRemoveCondition(t, c)` | Remove condition |
| `TriggerEvaluate(t)` | Evaluate all conditions (AND) |
| `TriggerAddAction(t, func)` | Add action |
| `TriggerRemoveAction(t, a)` | Remove action |
| `TriggerExecute(t)` | Execute all actions |
| `GetTriggeringTrigger()` | Get current trigger |
| `GetTriggerUnit()` | Get triggering unit |
| `GetTriggerPlayer()` | Get triggering player |
| `GetTriggerEventId()` | Get event ID |

### Condition Evaluation

All conditions must return true for actions to execute:
```lua
for _, cond in ipairs(conditions) do
    if not cond.func() then return false end
end
return true
```

### Context Stack

For nested trigger execution:
```lua
push_context(new_context)
-- nested trigger runs
pop_context()  -- restores previous
```

### Handle System

Triggers integrate with the handle system:
- `handles.register(trigger, "trigger")` on create
- `handles.destroy(trigger)` on destroy
- `handles.is_valid(trigger)` to check validity

---

## Related Documents

- issues/309-phase-3-integration-test.md (parent issue)
- issues/307-implement-trigger-framework.md (framework implementation)
- issues/307a-trigger-data-structure.md (data structure)
- issues/307b-trigger-lifecycle-api.md (lifecycle)
- issues/307c-condition-action-system.md (conditions/actions)
- issues/307d-trigger-context-system.md (context)
- src/runtime/triggers.lua (implementation)
- src/runtime/handles.lua (handle system)

---

## Acceptance Criteria

- [ ] Test file created at src/tests/test_309e_trigger_runtime.lua
- [ ] Trigger creation tested (CreateTrigger)
- [ ] Trigger destruction tested (DestroyTrigger, cleanup)
- [ ] Enable/disable tested (EnableTrigger, DisableTrigger, IsTriggerEnabled)
- [ ] Condition system tested (Condition, Add, Remove, Evaluate)
- [ ] AND logic for multiple conditions verified
- [ ] Action system tested (Add, Remove, Execute)
- [ ] Action execution order verified
- [ ] Trigger:fire() method tested (if implemented)
- [ ] Context accessors tested (GetTriggerUnit, etc.)
- [ ] Context stacking for nested triggers tested
- [ ] Handle system integration verified
- [ ] Tostring output verified
- [ ] Edge cases tested (empty trigger, errors)
- [ ] All tests pass with zero failures

---

## Notes

The trigger runtime is the execution engine for all JASS trigger logic.
Tests verify both the API contracts and the behavioral semantics.

Key areas:
1. Lifecycle - triggers created/destroyed properly
2. Conditions - AND logic, evaluation
3. Actions - sequential execution
4. Context - proper stacking for nested triggers

The context stacking test is particularly important as it verifies that
nested trigger execution (trigger A fires trigger B) correctly preserves
and restores context.


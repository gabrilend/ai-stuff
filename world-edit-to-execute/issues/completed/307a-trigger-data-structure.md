# Issue 307a: Trigger Data Structure

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** High
**Dependencies:** None (first sub-issue, but requires handles.lua from runtime)
**Parent Issue:** 307-implement-trigger-framework

---

## Current Behavior

No runtime module structure exists. No trigger data type is defined.
Transpiled JASS code that creates triggers has nothing to call.

---

## Intended Behavior

A core Trigger class that provides the foundation for all trigger mechanics:
- Trigger object with proper metatable setup
- Integration with handle management system
- Storage for conditions, actions, and events
- Enable/disable state tracking

```lua
local triggers = require("runtime.triggers")

-- Create a new trigger
local t = triggers.Trigger.new()
print(t.enabled)      -- true
print(#t.conditions)  -- 0
print(#t.actions)     -- 0
```

---

## Suggested Implementation Steps

1. **Create runtime directory structure**
   ```
   src/runtime/
   ├── init.lua         (main runtime API - exports all modules)
   ├── handles.lua      (handle management - stub or full implementation)
   └── triggers.lua     (this issue)
   ```

2. **Create handles.lua stub (if not existing)**
   ```lua
   -- {{{ handles.lua
   -- Handle management for runtime objects
   -- Provides unique IDs and lifecycle management

   local handles = {}

   -- Handle ID counter
   local next_id = 1

   -- Handle registry (id → object)
   local registry = {}

   -- Object → handle ID mapping
   local object_ids = setmetatable({}, {__mode = "k"})

   -- {{{ register
   function handles.register(obj, type_name)
       local id = next_id
       next_id = next_id + 1

       registry[id] = obj
       object_ids[obj] = id

       -- Store type info on object
       obj._handle_id = id
       obj._handle_type = type_name

       return id
   end
   -- }}}

   -- {{{ destroy
   function handles.destroy(obj)
       local id = object_ids[obj]
       if id then
           registry[id] = nil
           object_ids[obj] = nil
           obj._handle_id = nil
       end
   end
   -- }}}

   -- {{{ get_id
   function handles.get_id(obj)
       return object_ids[obj]
   end
   -- }}}

   -- {{{ get_by_id
   function handles.get_by_id(id)
       return registry[id]
   end
   -- }}}

   -- {{{ is_valid
   function handles.is_valid(obj)
       return object_ids[obj] ~= nil
   end
   -- }}}

   return handles
   -- }}}
   ```

3. **Create triggers.lua with Trigger class**
   ```lua
   -- {{{ triggers.lua
   -- Trigger framework for JASS trigger execution
   -- Provides trigger creation, condition/action management, and execution

   local handles = require("runtime.handles")

   local triggers = {}

   -- {{{ Trigger class
   local Trigger = {}
   Trigger.__index = Trigger

   triggers.Trigger = Trigger
   -- }}}

   -- {{{ Trigger.new
   function Trigger.new()
       local self = setmetatable({}, Trigger)

       -- State
       self.enabled = true

       -- Condition functions (evaluated with AND logic)
       self.conditions = {}

       -- Action functions (executed in order)
       self.actions = {}

       -- Registered events (for cleanup on destroy)
       self.events = {}

       -- Register with handle system
       handles.register(self, "trigger")

       return self
   end
   -- }}}

   return triggers
   -- }}}
   ```

4. **Add Trigger validation method**
   ```lua
   -- {{{ Trigger:is_valid
   function Trigger:is_valid()
       return handles.is_valid(self)
   end
   -- }}}
   ```

5. **Add Trigger type checking utility**
   ```lua
   -- {{{ is_trigger
   function triggers.is_trigger(obj)
       return type(obj) == "table" and getmetatable(obj) == Trigger
   end
   -- }}}
   ```

6. **Add __tostring for debugging**
   ```lua
   -- {{{ Trigger.__tostring
   function Trigger:__tostring()
       local id = self._handle_id or "?"
       local status = self.enabled and "enabled" or "disabled"
       return string.format("Trigger<%s>[%d cond, %d act, %s]",
           id, #self.conditions, #self.actions, status)
   end
   -- }}}
   ```

7. **Create runtime init.lua**
   ```lua
   -- {{{ init.lua
   -- Runtime API for transpiled JASS code
   -- This module exports all runtime functions that JASS natives call

   local runtime = {}

   -- Load submodules
   local handles = require("runtime.handles")
   local triggers = require("runtime.triggers")

   -- Export handle utilities
   runtime._handles = handles

   -- Export trigger class (for internal use)
   runtime._Trigger = triggers.Trigger

   -- Trigger natives will be added in 307b-307d

   return runtime
   -- }}}
   ```

8. **Add storage for active triggers (optional registry)**
   ```lua
   -- {{{ Active trigger tracking
   -- Track all active triggers for iteration/cleanup
   local active_triggers = setmetatable({}, {__mode = "v"})

   function triggers.get_all()
       local result = {}
       for _, t in pairs(active_triggers) do
           if t:is_valid() then
               result[#result + 1] = t
           end
       end
       return result
   end

   -- Update Trigger.new to register
   local original_new = Trigger.new
   function Trigger.new()
       local t = original_new()
       active_triggers[t._handle_id] = t
       return t
   end
   -- }}}
   ```

---

## Technical Notes

### Handle System Integration

Every trigger gets a unique handle ID when created. This allows:
- Referencing triggers across function calls
- Cleanup tracking
- JASS compatibility (handle IDs are integers)

### Metatable Pattern

Using metatables allows:
- Method dispatch (`trigger:fire()`)
- Type checking via `getmetatable()`
- Custom `__tostring` for debugging

### Weak Tables for Registry

The `active_triggers` table uses weak values (`__mode = "v"`) so triggers
can be garbage collected when no longer referenced. The explicit
`DestroyTrigger()` function (307b) handles intentional cleanup.

### Collections Structure

```lua
trigger = {
    enabled = true/false,
    conditions = {
        {func = <function>, trigger = <self>},
        ...
    },
    actions = {
        {func = <function>, trigger = <self>},
        ...
    },
    events = {
        {type = "unit_death", unregister = <function>},
        ...
    },
    _handle_id = <integer>,
    _handle_type = "trigger",
}
```

The `trigger` back-reference in conditions/actions allows them to know
which trigger they belong to if needed.

---

## Related Documents

- issues/307-implement-trigger-framework.md (parent issue)
- issues/307b-trigger-lifecycle-api.md (uses Trigger.new)
- issues/307c-condition-action-system.md (populates conditions/actions)
- issues/307d-trigger-context-system.md (context during execution)
- issues/306-create-jass-lua-transpiler.md (generates code calling runtime)

---

## Acceptance Criteria

- [x] Created src/runtime/triggers.lua
- [x] Created src/runtime/handles.lua (or verified existing)
- [x] Created src/runtime/init.lua (runtime API entry point)
- [x] Trigger.new() creates trigger with correct structure
- [x] Trigger integrates with handle system (gets unique ID)
- [x] Trigger has enabled, conditions, actions, events fields
- [x] triggers.is_trigger() correctly identifies triggers
- [x] Trigger:is_valid() checks handle validity
- [x] Trigger.__tostring produces useful debug output
- [x] Module exports Trigger class for internal use
- [x] Basic test creates and inspects trigger

---

## Notes

This sub-issue establishes the foundational data structure. The actual
trigger functionality (create/destroy, conditions, actions) is built on
top of this in subsequent sub-issues.

The handle system stub may be expanded later, but the interface should
remain stable: `register()`, `destroy()`, `get_id()`, `is_valid()`.

Keep the Trigger class simple and focused on data storage. Behavior
(evaluation, execution) belongs in 307c.

---

## Implementation Notes

**Completed:** 2025-12-27

### Files Created

| File | Description |
|------|-------------|
| `src/runtime/handles.lua` | Handle management with unique IDs and lifecycle tracking |
| `src/runtime/triggers.lua` | Trigger class with metatable setup and helper functions |
| `src/runtime/init.lua` | Runtime API entry point that exports all modules |
| `src/tests/test_triggers_307a.lua` | Test suite with 34 tests |

### Handle System Features

- Unique integer ID generation starting from 1
- Bidirectional lookup: object→ID and ID→object
- Weak key table for object_ids (allows GC when handles are only reference)
- Type tracking via `_handle_type` field
- Stats reporting for debugging memory leaks

### Trigger Class Features

- Metatable pattern for method dispatch and type checking
- Fields: `enabled`, `conditions`, `actions`, `events`, `_exec_count`
- `__tostring` shows ID, condition/action counts, and status
- Active trigger tracking with weak values
- `triggers.is_trigger()` for type checking
- `triggers.get_all()` and `triggers.get_count()` for enumeration

### Runtime API

- Exports internal modules via `_handles`, `_triggers`, `_Trigger`
- `runtime.reset()` clears all state
- `runtime.get_stats()` for debugging

### Test Results

All 34 tests pass:
- 13 handle system tests
- 15 trigger class tests
- 6 runtime API tests


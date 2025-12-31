# Issue 402b: Implement Component Registry

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** Critical
**Dependencies:** 402a-implement-entity-manager
**Parent Issue:** 402-build-entity-component-system

---

## Current Behavior

Entities exist as numeric IDs with no data attached. There is no mechanism
to define component types or attach data to entities.

---

## Intended Behavior

A component registry system that:
- Registers component types with default values
- Attaches component instances to entities
- Retrieves components by entity and type
- Removes components from entities
- Uses metatable inheritance for efficient defaults
- Cleans up components when entities are destroyed

```lua
-- Example usage:
local ecs = require("runtime.ecs")

-- Register component types
ecs.register_component("position", {x = 0, y = 0, z = 0, facing = 0})
ecs.register_component("stats", {hp = 100, hp_max = 100, mp = 0})

-- Create entity with components
local entity = ecs.create_entity()
ecs.add_component(entity, "position", {x = 100, y = 200})
ecs.add_component(entity, "stats", {hp = 50})

-- Access components
local pos = ecs.get_component(entity, "position")
print(pos.x, pos.y)  -- 100, 200
print(pos.z)         -- 0 (from defaults)

local stats = ecs.get_component(entity, "stats")
print(stats.hp)      -- 50
print(stats.hp_max)  -- 100 (from defaults)

-- Modify component
pos.x = 150

-- Check and remove
print(ecs.has_component(entity, "position"))  -- true
ecs.remove_component(entity, "position")
print(ecs.has_component(entity, "position"))  -- false
```

---

## Suggested Implementation Steps

1. **Create component module**
   ```lua
   -- {{{ src/runtime/ecs/component.lua
   -- Component registry and attachment system
   -- Components are pure data with metatable inheritance for defaults

   local component = {}

   local entity_mod = require("runtime.ecs.entity")
   -- }}}
   ```

2. **Define component state**
   ```lua
   -- {{{ State
   -- Component type registry: name -> default values table
   local component_types = {}

   -- Component storage: component_name -> { entity_id -> component_data }
   local component_storage = {}

   -- Track all component names for an entity: entity_id -> { name -> true }
   local entity_components = {}
   -- }}}
   ```

3. **Implement component type registration**
   ```lua
   -- {{{ component.register
   function component.register(name, defaults)
   -- }}}
   -- {{{ component.register
   function component.register(name, defaults)
       -- Register a component type with its default values
       -- Defaults are used via metatable inheritance
       --
       -- name: string identifier for the component type
       -- defaults: table of default field values

       if type(name) ~= "string" then
           error("register: component name must be a string")
       end

       if type(defaults) ~= "table" then
           error("register: defaults must be a table")
       end

       if component_types[name] then
           error("register: component '" .. name .. "' already registered")
       end

       -- Store defaults (frozen copy)
       component_types[name] = {}
       for k, v in pairs(defaults) do
           component_types[name][k] = v
       end

       -- Initialize storage for this component type
       component_storage[name] = {}
   end
   -- }}}
   ```

4. **Implement component addition**
   ```lua
   -- {{{ component.add
   function component.add(entity_id, name, data)
   -- }}}
   -- {{{ component.add
   function component.add(entity_id, name, data)
       -- Add a component to an entity
       --
       -- entity_id: numeric entity ID from entity.create()
       -- name: registered component type name
       -- data: optional table of initial values (merged with defaults)
       --
       -- Returns the component instance

       if not entity_mod.exists(entity_id) then
           error("add: entity " .. tostring(entity_id) .. " does not exist")
       end

       local defaults = component_types[name]
       if not defaults then
           error("add: component type '" .. name .. "' not registered")
       end

       -- Check if entity already has this component
       if component_storage[name][entity_id] then
           error("add: entity " .. entity_id .. " already has component '" .. name .. "'")
       end

       -- Create component instance with metatable for defaults
       local instance = data and {} or {}
       if data then
           for k, v in pairs(data) do
               instance[k] = v
           end
       end
       setmetatable(instance, {__index = defaults})

       -- Store the component
       component_storage[name][entity_id] = instance

       -- Track which components this entity has
       if not entity_components[entity_id] then
           entity_components[entity_id] = {}
       end
       entity_components[entity_id][name] = true

       return instance
   end
   -- }}}
   ```

5. **Implement component retrieval**
   ```lua
   -- {{{ component.get
   function component.get(entity_id, name)
   -- }}}
   -- {{{ component.get
   function component.get(entity_id, name)
       -- Get a component from an entity
       -- Returns nil if entity doesn't have this component

       local storage = component_storage[name]
       if not storage then
           return nil
       end

       return storage[entity_id]
   end
   -- }}}
   ```

6. **Implement component existence check**
   ```lua
   -- {{{ component.has
   function component.has(entity_id, name)
   -- }}}
   -- {{{ component.has
   function component.has(entity_id, name)
       -- Check if entity has a specific component
       -- Returns true/false

       local storage = component_storage[name]
       return storage ~= nil and storage[entity_id] ~= nil
   end
   -- }}}
   ```

7. **Implement component removal**
   ```lua
   -- {{{ component.remove
   function component.remove(entity_id, name)
   -- }}}
   -- {{{ component.remove
   function component.remove(entity_id, name)
       -- Remove a component from an entity
       -- Returns true if component was removed, false if didn't exist

       local storage = component_storage[name]
       if not storage or not storage[entity_id] then
           return false
       end

       -- Remove from storage
       storage[entity_id] = nil

       -- Update entity's component tracking
       if entity_components[entity_id] then
           entity_components[entity_id][name] = nil
       end

       return true
   end
   -- }}}
   ```

8. **Implement entity component listing**
   ```lua
   -- {{{ component.get_all_for_entity
   function component.get_all_for_entity(entity_id)
   -- }}}
   -- {{{ component.get_all_for_entity
   function component.get_all_for_entity(entity_id)
       -- Get all components attached to an entity
       -- Returns table: { component_name -> component_instance }

       local result = {}
       local tracked = entity_components[entity_id]

       if tracked then
           for name in pairs(tracked) do
               result[name] = component_storage[name][entity_id]
           end
       end

       return result
   end
   -- }}}

   -- {{{ component.get_component_names
   function component.get_component_names(entity_id)
   -- }}}
   -- {{{ component.get_component_names
   function component.get_component_names(entity_id)
       -- Get list of component names attached to an entity
       -- Returns array of strings

       local result = {}
       local tracked = entity_components[entity_id]

       if tracked then
           for name in pairs(tracked) do
               result[#result + 1] = name
           end
       end

       return result
   end
   -- }}}
   ```

9. **Implement entity cleanup hook**
   ```lua
   -- {{{ Entity destruction cleanup
   -- Register hook to clean up components when entities are destroyed
   entity_mod.on_destroy(function(entity_id)
       -- Remove all components for this entity
       local tracked = entity_components[entity_id]

       if tracked then
           for name in pairs(tracked) do
               if component_storage[name] then
                   component_storage[name][entity_id] = nil
               end
           end
       end

       entity_components[entity_id] = nil
   end)
   -- }}}
   ```

10. **Implement reset and debug functions**
    ```lua
    -- {{{ component.reset
    function component.reset()
    -- }}}
    -- {{{ component.reset
    function component.reset()
        -- Reset all component storage (but keep type registrations)
        -- Called when entity system resets

        for name in pairs(component_storage) do
            component_storage[name] = {}
        end

        entity_components = {}
    end
    -- }}}

    -- {{{ component.get_registered_types
    function component.get_registered_types()
    -- }}}
    -- {{{ component.get_registered_types
    function component.get_registered_types()
        -- Get list of all registered component type names

        local result = {}
        for name in pairs(component_types) do
            result[#result + 1] = name
        end
        return result
    end
    -- }}}

    -- {{{ component.get_defaults
    function component.get_defaults(name)
    -- }}}
    -- {{{ component.get_defaults
    function component.get_defaults(name)
        -- Get the default values for a component type
        -- Returns nil if not registered

        return component_types[name]
    end
    -- }}}

    -- {{{ component.get_storage
    function component.get_storage(name)
    -- }}}
    -- {{{ component.get_storage
    function component.get_storage(name)
        -- Get direct access to component storage table
        -- For use by query system - returns entity_id -> component map
        -- Returns nil if component not registered

        return component_storage[name]
    end
    -- }}}

    -- {{{ component.get_stats
    function component.get_stats()
    -- }}}
    -- {{{ component.get_stats
    function component.get_stats()
        -- Get debug statistics about component system

        local type_count = 0
        local instance_counts = {}

        for name, storage in pairs(component_storage) do
            type_count = type_count + 1
            local count = 0
            for _ in pairs(storage) do
                count = count + 1
            end
            instance_counts[name] = count
        end

        return {
            registered_types = type_count,
            instances_by_type = instance_counts,
        }
    end
    -- }}}
    ```

11. **Export module**
    ```lua
    -- {{{ Module export
    return component
    -- }}}
    ```

12. **Update ECS init.lua**
    ```lua
    -- Add to src/runtime/ecs/init.lua:
    local component = require("runtime.ecs.component")

    ecs.register_component = component.register
    ecs.add_component = component.add
    ecs.get_component = component.get
    ecs.has_component = component.has
    ecs.remove_component = component.remove
    ecs.get_all_components = component.get_all_for_entity
    ecs.get_component_names = component.get_component_names
    ```

13. **Create unit tests**
    ```lua
    -- {{{ src/tests/test_ecs_component.lua
    -- Tests for ECS component registry

    local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
    package.path = DIR .. "/src/?.lua;" .. package.path

    local entity = require("runtime.ecs.entity")
    local component = require("runtime.ecs.component")

    local test_count = 0
    local pass_count = 0

    local function test(name, condition, msg)
        test_count = test_count + 1
        if condition then
            pass_count = pass_count + 1
            print("  [PASS] " .. name)
        else
            print("  [FAIL] " .. name .. (msg and ": " .. msg or ""))
        end
    end

    local function test_section(name)
        print("\n=== " .. name .. " ===")
    end

    -- Reset before tests
    entity.reset()
    component.reset()

    test_section("Component Registration")
    component.register("position", {x = 0, y = 0, z = 0, facing = 0})
    component.register("stats", {hp = 100, hp_max = 100, mp = 0, mp_max = 0})

    local types = component.get_registered_types()
    test("Two types registered", #types == 2)

    local pos_defaults = component.get_defaults("position")
    test("Position defaults exist", pos_defaults ~= nil)
    test("Position default x", pos_defaults.x == 0)
    test("Position default facing", pos_defaults.facing == 0)

    -- Double registration should error
    local ok = pcall(function()
        component.register("position", {x = 1})
    end)
    test("Double registration errors", not ok)

    test_section("Component Addition")
    entity.reset()
    component.reset()
    component.register("position", {x = 0, y = 0, z = 0})
    component.register("stats", {hp = 100})

    local e1 = entity.create()
    local pos = component.add(e1, "position", {x = 100, y = 200})

    test("Add returns component", pos ~= nil)
    test("Component has x value", pos.x == 100)
    test("Component has y value", pos.y == 200)
    test("Component inherits z default", pos.z == 0)

    -- Add without initial data
    local stats = component.add(e1, "stats")
    test("Add without data works", stats ~= nil)
    test("Inherits all defaults", stats.hp == 100)

    -- Double add should error
    ok = pcall(function()
        component.add(e1, "position", {x = 50})
    end)
    test("Double add errors", not ok)

    test_section("Component Retrieval")
    local got_pos = component.get(e1, "position")
    test("Get returns same instance", got_pos == pos)
    test("Get returns correct data", got_pos.x == 100)

    local got_stats = component.get(e1, "stats")
    test("Get stats", got_stats == stats)

    local got_missing = component.get(e1, "nonexistent")
    test("Get missing returns nil", got_missing == nil)

    local e2 = entity.create()
    local got_wrong_entity = component.get(e2, "position")
    test("Get wrong entity returns nil", got_wrong_entity == nil)

    test_section("Component Has Check")
    test("Has position true", component.has(e1, "position"))
    test("Has stats true", component.has(e1, "stats"))
    test("Has nonexistent false", not component.has(e1, "nonexistent"))
    test("Has on wrong entity false", not component.has(e2, "position"))

    test_section("Component Modification")
    pos.x = 150
    pos.custom_field = "test"

    local updated = component.get(e1, "position")
    test("Modification persists", updated.x == 150)
    test("Custom fields work", updated.custom_field == "test")
    test("Defaults still work", updated.z == 0)

    test_section("Component Removal")
    local removed = component.remove(e1, "position")
    test("Remove returns true", removed == true)
    test("Has returns false after remove", not component.has(e1, "position"))
    test("Get returns nil after remove", component.get(e1, "position") == nil)

    -- Double remove
    removed = component.remove(e1, "position")
    test("Double remove returns false", removed == false)

    -- Remove nonexistent
    removed = component.remove(e1, "nonexistent")
    test("Remove nonexistent returns false", removed == false)

    -- Stats should still exist
    test("Other components unaffected", component.has(e1, "stats"))

    test_section("Get All Components")
    entity.reset()
    component.reset()
    component.register("a", {val = 1})
    component.register("b", {val = 2})
    component.register("c", {val = 3})

    local e = entity.create()
    component.add(e, "a")
    component.add(e, "b")

    local all = component.get_all_for_entity(e)
    test("Get all returns 2 components", all.a ~= nil and all.b ~= nil)
    test("Get all excludes c", all.c == nil)

    local names = component.get_component_names(e)
    test("Get names returns 2", #names == 2)

    test_section("Entity Destruction Cleanup")
    entity.reset()
    component.reset()
    component.register("data", {value = 0})

    local e1 = entity.create()
    local e2 = entity.create()
    component.add(e1, "data", {value = 1})
    component.add(e2, "data", {value = 2})

    test("Before destroy: e1 has data", component.has(e1, "data"))
    test("Before destroy: e2 has data", component.has(e2, "data"))

    entity.destroy(e1)

    test("After destroy: e1 data gone", not component.has(e1, "data"))
    test("After destroy: e2 data remains", component.has(e2, "data"))

    local e2_data = component.get(e2, "data")
    test("E2 data correct", e2_data.value == 2)

    test_section("Metatable Inheritance")
    entity.reset()
    component.reset()
    component.register("test", {a = 1, b = 2, c = 3})

    local e = entity.create()
    local comp = component.add(e, "test", {b = 20})

    test("Override value", comp.b == 20)
    test("Inherited a", comp.a == 1)
    test("Inherited c", comp.c == 3)

    -- rawget should not see inherited values
    test("rawget override", rawget(comp, "b") == 20)
    test("rawget inherited nil", rawget(comp, "a") == nil)

    test_section("Component Stats")
    entity.reset()
    component.reset()
    component.register("x", {})
    component.register("y", {})

    entity.create()
    entity.create()
    entity.create()
    component.add(1, "x")
    component.add(2, "x")
    component.add(3, "x")
    component.add(1, "y")

    local stats = component.get_stats()
    test("Registered types count", stats.registered_types == 2)
    test("X instances count", stats.instances_by_type.x == 3)
    test("Y instances count", stats.instances_by_type.y == 1)

    print("\n" .. string.rep("=", 40))
    print(string.format("Tests: %d passed, %d failed",
                        pass_count, test_count - pass_count))
    if pass_count == test_count then
        print("ALL TESTS PASSED")
    else
        os.exit(1)
    end
    -- }}}
    ```

---

## Technical Notes

### Metatable Inheritance

Components use Lua metatables to inherit default values:
```lua
setmetatable(instance, {__index = defaults})
```

This means:
- Instance only stores overridden values (memory efficient)
- `rawget(comp, "field")` returns nil for inherited values
- Defaults can be changed globally (but shouldn't be)

### Storage Structure

Two storage mechanisms work together:
1. `component_storage[name][entity_id]` - Fast lookup by (type, entity)
2. `entity_components[entity_id][name]` - Track components per entity

This dual indexing supports both:
- "Get position of entity 5" (common operation)
- "Get all components of entity 5" (for serialization, destruction)

### Entity Destruction Hook

The component module registers an `on_destroy` hook to automatically
clean up all components when an entity is destroyed. This prevents
orphaned component data.

### Error Handling

The component system is strict about errors:
- Adding to non-existent entity: error
- Adding unregistered component: error
- Double-adding same component: error

This catches bugs early rather than silently failing.

---

## Related Documents

- issues/402-build-entity-component-system.md (parent issue)
- issues/402a-implement-entity-manager.md (entity lifecycle)
- issues/402c-implement-component-queries.md (uses get_storage)
- issues/402e-define-core-wc3-components.md (WC3 component definitions)
- src/runtime/ecs/component.lua (implementation)

---

## Acceptance Criteria

- [x] Module created at src/runtime/ecs/component.lua
- [x] `register(name, defaults)` registers component types
- [x] Double registration raises error
- [x] `add(entity, name, data)` attaches component to entity
- [x] Add to non-existent entity raises error
- [x] Add unregistered component raises error
- [x] Double-add raises error
- [x] Components inherit defaults via metatable
- [x] `get(entity, name)` returns component or nil
- [x] `has(entity, name)` returns boolean
- [x] `remove(entity, name)` removes component, returns success
- [x] `get_all_for_entity(entity)` returns all components
- [x] `get_component_names(entity)` returns component name list
- [x] Entity destruction automatically cleans up components
- [x] `get_storage(name)` exposes storage for query system
- [x] `get_stats()` returns debug information
- [x] ECS init.lua re-exports component functions
- [x] All code uses vimfold markers
- [x] Unit tests pass for all functionality

---

## Notes

Components are pure data containers with no methods. All behavior lives
in systems (402d). This separation enables data-oriented design and
easy serialization.

The metatable inheritance pattern is a Lua idiom for efficient defaults.
Only overridden values consume memory in the instance table.

The `get_storage()` function exposes internal storage for the query
system (402c) to build efficient indices.

---

## Implementation Notes

**Implemented:** 2025-12-27

### Files Created/Modified

- `src/runtime/ecs/component.lua` (~240 lines) - Component registry
- `src/runtime/ecs/init.lua` (updated) - Added component exports
- `src/tests/test_ecs_component.lua` (~400 lines) - 99 unit tests

### Key Decisions

1. **Added `init(force)` function** - The destroy hook registration needed
   a way to re-register after `entity.clear_hooks()` is called during testing.
   The `force` parameter allows tests to force re-registration.

2. **Added `clear_all()` function** - Clears type registrations in addition
   to instances. This is needed for testing to start completely fresh.
   Normal `reset()` keeps type registrations (appropriate for map reloads).

3. **Dual indexing strategy** - Components are indexed both by type and by
   entity to support efficient queries in both directions:
   - `component_storage[name][entity_id]` - Fast "get component X of entity Y"
   - `entity_components[entity_id][name]` - Fast "get all components of entity Y"

4. **Module-load initialization** - `component.init()` is called at module
   load time to register the entity destroy hook automatically.

### Test Coverage

- Component type registration (valid/invalid inputs, double registration)
- Component addition (with/without data, error cases)
- Component retrieval (existing, missing, wrong entity)
- Component has check
- Component modification (values, custom fields, defaults)
- Component removal (single, double, nonexistent)
- Get all components for entity
- Entity destruction cleanup (automatic hook)
- Metatable inheritance (override, inherit, rawget behavior)
- Component storage access
- Component stats
- Reset and clear_all behavior
- ECS main module integration
- Stress test (1000 entities, multiple components, destruction)


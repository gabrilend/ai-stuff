# Issue 402a: Implement Entity Manager

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** Critical
**Dependencies:** 401-implement-game-tick-update-loop
**Parent Issue:** 402-build-entity-component-system

---

## Current Behavior

No entity management system exists. Game objects from parsed map data have no
runtime representation or lifecycle management.

---

## Intended Behavior

A foundational entity manager that:
- Creates entities as numeric IDs for fast lookup
- Destroys entities and cleans up their data
- Recycles entity IDs to prevent unbounded growth
- Tracks entity existence for validation
- Provides hooks for entity lifecycle events

```lua
-- Example usage:
local ecs = require("runtime.ecs")

local entity = ecs.create_entity()
print(entity)  -- 1 (numeric ID)

local entity2 = ecs.create_entity()
print(entity2)  -- 2

ecs.destroy_entity(entity)
-- ID 1 is now in the free pool

local entity3 = ecs.create_entity()
print(entity3)  -- 1 (recycled)

print(ecs.entity_exists(entity2))  -- true
print(ecs.entity_exists(entity))   -- false (destroyed, ID recycled)
```

---

## Suggested Implementation Steps

1. **Create ECS module structure**
   ```lua
   -- {{{ src/runtime/ecs/init.lua
   -- Entity Component System - Main API
   -- Provides entity management, component attachment, and system execution

   local ecs = {}

   -- Load sub-modules
   local entity = require("runtime.ecs.entity")

   -- Re-export entity functions
   ecs.create_entity = entity.create
   ecs.destroy_entity = entity.destroy
   ecs.entity_exists = entity.exists
   ecs.get_entity_count = entity.get_count
   ecs.reset = entity.reset

   return ecs
   -- }}}
   ```

2. **Create entity module with state**
   ```lua
   -- {{{ src/runtime/ecs/entity.lua
   -- Entity management - creation, destruction, ID recycling
   -- Entities are just numeric IDs; components attach data to them

   local entity = {}
   -- }}}

   -- {{{ State
   local next_id = 1           -- Next ID to assign if no recycled IDs
   local entities = {}         -- id -> true (existence marker)
   local entity_count = 0      -- Active entity count
   local free_ids = {}         -- Stack of recycled IDs
   local free_count = 0        -- Count of free IDs (for fast check)

   -- Lifecycle hooks
   local on_create_hooks = {}
   local on_destroy_hooks = {}
   -- }}}
   ```

3. **Implement entity creation**
   ```lua
   -- {{{ entity.create
   function entity.create()
   -- }}}
   -- {{{ entity.create
   function entity.create()
       -- Create a new entity, returning its numeric ID
       -- Recycles IDs from destroyed entities when available

       local id

       -- Try to recycle an ID first
       if free_count > 0 then
           id = free_ids[free_count]
           free_ids[free_count] = nil
           free_count = free_count - 1
       else
           -- Allocate new ID
           id = next_id
           next_id = next_id + 1
       end

       -- Mark as existing
       entities[id] = true
       entity_count = entity_count + 1

       -- Call creation hooks
       for i = 1, #on_create_hooks do
           on_create_hooks[i](id)
       end

       return id
   end
   -- }}}
   ```

4. **Implement entity destruction**
   ```lua
   -- {{{ entity.destroy
   function entity.destroy(id)
   -- }}}
   -- {{{ entity.destroy
   function entity.destroy(id)
       -- Destroy an entity by ID
       -- The ID is recycled for future use
       -- Returns true if entity existed, false otherwise

       if not entities[id] then
           return false
       end

       -- Call destruction hooks (before cleanup)
       -- This allows components to be read during destruction
       for i = 1, #on_destroy_hooks do
           on_destroy_hooks[i](id)
       end

       -- Mark as non-existing
       entities[id] = nil
       entity_count = entity_count - 1

       -- Recycle the ID
       free_count = free_count + 1
       free_ids[free_count] = id

       return true
   end
   -- }}}
   ```

5. **Implement existence check**
   ```lua
   -- {{{ entity.exists
   function entity.exists(id)
   -- }}}
   -- {{{ entity.exists
   function entity.exists(id)
       -- Check if an entity ID is currently valid
       -- Returns true if entity exists, false otherwise

       return entities[id] == true
   end
   -- }}}
   ```

6. **Implement entity count and iteration**
   ```lua
   -- {{{ entity.get_count
   function entity.get_count()
   -- }}}
   -- {{{ entity.get_count
   function entity.get_count()
       -- Return the number of active entities
       return entity_count
   end
   -- }}}

   -- {{{ entity.iterate
   function entity.iterate()
   -- }}}
   -- {{{ entity.iterate
   function entity.iterate()
       -- Return iterator over all active entity IDs
       -- Usage: for id in entity.iterate() do ... end

       local id = 0
       return function()
           repeat
               id = id + 1
               if id >= next_id then
                   return nil
               end
           until entities[id]
           return id
       end
   end
   -- }}}
   ```

7. **Implement lifecycle hooks**
   ```lua
   -- {{{ entity.on_create
   function entity.on_create(callback)
   -- }}}
   -- {{{ entity.on_create
   function entity.on_create(callback)
       -- Register a callback for entity creation
       -- Callback receives (entity_id)
       -- Used by component system to initialize storage

       if type(callback) ~= "function" then
           error("on_create: callback must be a function")
       end

       on_create_hooks[#on_create_hooks + 1] = callback
   end
   -- }}}

   -- {{{ entity.on_destroy
   function entity.on_destroy(callback)
   -- }}}
   -- {{{ entity.on_destroy
   function entity.on_destroy(callback)
       -- Register a callback for entity destruction
       -- Callback receives (entity_id)
       -- Called BEFORE entity is removed (components still accessible)
       -- Used by component system to cleanup storage

       if type(callback) ~= "function" then
           error("on_destroy: callback must be a function")
       end

       on_destroy_hooks[#on_destroy_hooks + 1] = callback
   end
   -- }}}
   ```

8. **Implement reset function**
   ```lua
   -- {{{ entity.reset
   function entity.reset()
   -- }}}
   -- {{{ entity.reset
   function entity.reset()
       -- Reset entity manager to initial state
       -- Used when loading a new map or restarting

       -- Call destroy hooks for all existing entities
       for id = 1, next_id - 1 do
           if entities[id] then
               for i = 1, #on_destroy_hooks do
                   on_destroy_hooks[i](id)
               end
           end
       end

       -- Reset state
       next_id = 1
       entities = {}
       entity_count = 0
       free_ids = {}
       free_count = 0

       -- Note: hooks are NOT cleared - they're module-level registrations
   end
   -- }}}
   ```

9. **Implement debug utilities**
   ```lua
   -- {{{ entity.get_stats
   function entity.get_stats()
   -- }}}
   -- {{{ entity.get_stats
   function entity.get_stats()
       -- Return debug statistics about entity manager state

       return {
           active_count = entity_count,
           next_id = next_id,
           free_pool_size = free_count,
           peak_id = next_id - 1,
       }
   end
   -- }}}

   -- {{{ entity.get_all_ids
   function entity.get_all_ids()
   -- }}}
   -- {{{ entity.get_all_ids
   function entity.get_all_ids()
       -- Return array of all active entity IDs
       -- Useful for debugging, not for hot paths

       local ids = {}
       for id = 1, next_id - 1 do
           if entities[id] then
               ids[#ids + 1] = id
           end
       end
       return ids
   end
   -- }}}
   ```

10. **Export module**
    ```lua
    -- {{{ Module export
    return entity
    -- }}}
    ```

11. **Create unit tests**
    ```lua
    -- {{{ src/tests/test_ecs_entity.lua
    -- Tests for ECS entity manager

    local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
    package.path = DIR .. "/src/?.lua;" .. package.path

    local entity = require("runtime.ecs.entity")

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

    test_section("Entity Creation")
    local e1 = entity.create()
    test("First entity is 1", e1 == 1)
    local e2 = entity.create()
    test("Second entity is 2", e2 == 2)
    local e3 = entity.create()
    test("Third entity is 3", e3 == 3)
    test("Count is 3", entity.get_count() == 3)

    test_section("Entity Existence")
    test("Entity 1 exists", entity.exists(e1))
    test("Entity 2 exists", entity.exists(e2))
    test("Entity 99 doesn't exist", not entity.exists(99))
    test("Entity 0 doesn't exist", not entity.exists(0))

    test_section("Entity Destruction")
    local destroyed = entity.destroy(e2)
    test("Destroy returns true", destroyed == true)
    test("Entity 2 no longer exists", not entity.exists(e2))
    test("Count is 2", entity.get_count() == 2)
    test("Entity 1 still exists", entity.exists(e1))
    test("Entity 3 still exists", entity.exists(e3))

    -- Destroy non-existent
    destroyed = entity.destroy(e2)
    test("Double destroy returns false", destroyed == false)
    destroyed = entity.destroy(99)
    test("Destroy non-existent returns false", destroyed == false)

    test_section("ID Recycling")
    local e4 = entity.create()
    test("New entity recycles ID 2", e4 == 2)
    test("Count is 3", entity.get_count() == 3)

    -- Destroy multiple and check recycling order (LIFO)
    entity.destroy(e1)
    entity.destroy(e3)
    local e5 = entity.create()
    test("Recycles most recent first (ID 3)", e5 == 3)
    local e6 = entity.create()
    test("Then older recycled ID (ID 1)", e6 == 1)
    local e7 = entity.create()
    test("Then allocates new ID (ID 4)", e7 == 4)

    test_section("Entity Iteration")
    entity.reset()
    entity.create()  -- 1
    entity.create()  -- 2
    entity.create()  -- 3
    entity.destroy(2)

    local iterated = {}
    for id in entity.iterate() do
        iterated[#iterated + 1] = id
    end
    test("Iteration returns 2 entities", #iterated == 2)
    test("Iteration includes 1", iterated[1] == 1 or iterated[2] == 1)
    test("Iteration includes 3", iterated[1] == 3 or iterated[2] == 3)
    test("Iteration excludes 2", iterated[1] ~= 2 and iterated[2] ~= 2)

    test_section("Lifecycle Hooks")
    entity.reset()
    local created_ids = {}
    local destroyed_ids = {}

    entity.on_create(function(id)
        created_ids[#created_ids + 1] = id
    end)
    entity.on_destroy(function(id)
        destroyed_ids[#destroyed_ids + 1] = id
    end)

    local h1 = entity.create()
    local h2 = entity.create()
    test("Create hook called twice", #created_ids == 2)
    test("Create hook received correct IDs", created_ids[1] == h1 and created_ids[2] == h2)

    entity.destroy(h1)
    test("Destroy hook called", #destroyed_ids == 1)
    test("Destroy hook received correct ID", destroyed_ids[1] == h1)

    test_section("Reset")
    entity.reset()
    test("Count is 0 after reset", entity.get_count() == 0)
    test("Entity 1 doesn't exist after reset", not entity.exists(1))
    local after_reset = entity.create()
    test("First entity after reset is 1", after_reset == 1)

    test_section("Debug Stats")
    entity.reset()
    entity.create()
    entity.create()
    entity.create()
    entity.destroy(2)

    local stats = entity.get_stats()
    test("Stats active_count", stats.active_count == 2)
    test("Stats next_id", stats.next_id == 4)
    test("Stats free_pool_size", stats.free_pool_size == 1)
    test("Stats peak_id", stats.peak_id == 3)

    local all_ids = entity.get_all_ids()
    test("get_all_ids count", #all_ids == 2)

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

### Entity ID Strategy

Entities are simple numeric IDs (integers starting at 1):
- Fast table lookup (`entities[id]`)
- Easy serialization for save/replay
- Deterministic ordering

### ID Recycling

Destroyed entity IDs are pushed onto a stack (`free_ids`). New entities
pop from this stack first, only allocating new IDs when the pool is empty.
This prevents unbounded ID growth in long-running games.

The stack (LIFO) approach means recently destroyed IDs are reused first.
This is slightly better for cache locality when entities are short-lived.

### Lifecycle Hooks

Hooks allow other systems (component storage, queries) to react to entity
lifecycle events without tight coupling:
- `on_create`: Initialize component storage slots
- `on_destroy`: Clean up component data, update indices

Hooks are called in registration order. Destroy hooks are called BEFORE
the entity is removed, so components are still accessible during cleanup.

### Thread Safety

This implementation is NOT thread-safe. Entity creation/destruction
should only happen from the main game loop thread.

---

## Related Documents

- issues/402-build-entity-component-system.md (parent issue)
- issues/402b-implement-component-registry.md (uses entity storage)
- issues/402c-implement-component-queries.md (uses lifecycle hooks)
- issues/402f-implement-entity-handles.md (wraps entity IDs)
- src/runtime/ecs/entity.lua (implementation)

---

## Acceptance Criteria

- [x] Module created at src/runtime/ecs/entity.lua
- [x] `create()` returns unique numeric IDs starting at 1
- [x] `destroy(id)` removes entity and recycles ID
- [x] `destroy()` returns true if entity existed, false otherwise
- [x] `exists(id)` returns current validity of entity
- [x] ID recycling works correctly (LIFO stack)
- [x] `get_count()` returns active entity count
- [x] `iterate()` returns iterator over active entities
- [x] `on_create(callback)` registers creation hooks
- [x] `on_destroy(callback)` registers destruction hooks
- [x] Destroy hooks called before entity removal
- [x] `reset()` clears all entities and calls destroy hooks
- [x] `get_stats()` returns debug information
- [x] `get_all_ids()` returns array of active IDs
- [x] Main ECS init.lua re-exports entity functions
- [x] All code uses vimfold markers
- [x] Unit tests pass for all functionality

---

## Notes

This is the foundation for the entire ECS. Keep it simple and fast.
The entity manager does only one thing - manage entity IDs and existence.
All data attachment happens in the component system (402b).

The lifecycle hooks are the key integration point. The component registry
will use `on_destroy` to clean up component data when entities are destroyed.

Consider adding a generation counter per entity slot in a future iteration
(402f) for safe handle references.

---

## Implementation Notes

**Implemented:** 2025-12-27

### Files Created

- `src/runtime/ecs/entity.lua` (~180 lines) - Core entity manager
- `src/runtime/ecs/init.lua` (~45 lines) - Main ECS API with re-exports
- `src/tests/test_ecs_entity.lua` (~270 lines) - 64 unit tests

### Key Decisions

1. **Added `clear_hooks()` function** - Not in original spec but needed for
   testing. Without it, hooks accumulate across test sections causing test
   pollution. The `reset()` function intentionally preserves hooks as they're
   module-level registrations, but tests need a way to clear them.

2. **LIFO recycling confirmed working** - Tests verify that destroyed IDs
   are recycled in LIFO order (most recently destroyed first). This provides
   better cache locality for short-lived entities.

3. **Destroy hooks run before removal** - Tests confirm that during a destroy
   hook callback, `entity.exists(id)` still returns true. This allows
   component cleanup to access entity data before removal.

### Test Coverage

- Entity creation (sequential ID allocation)
- Entity existence (positive and negative cases)
- Entity destruction (return values, state updates)
- ID recycling (LIFO order verification)
- Entity iteration (sparse array traversal)
- Lifecycle hooks (creation, destruction, multiple hooks)
- Hook error handling (invalid callback rejection)
- Reset behavior (destroy hooks, state clearing)
- Debug utilities (stats, get_all_ids)
- ECS main module (re-export verification)
- Stress test (1000 entities, 500 destroyed, recycling)


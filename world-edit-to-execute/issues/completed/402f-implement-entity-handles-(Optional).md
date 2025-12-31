# Issue 402f: Implement Entity Handles (Optional)

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** Low (Optional Enhancement)
**Parent:** 402-build-entity-component-system
**Dependencies:** 402a-implement-entity-manager

---

## Current Behavior

Entity IDs are raw integers. When an entity is destroyed and its ID recycled,
stale references to the old entity may inadvertently access the new entity
occupying that ID slot. This can cause subtle bugs where code operates on
the wrong entity.

---

## Intended Behavior

A generation-counter handle pattern that provides safe entity references:

- **Handles** wrap entity IDs with a generation counter
- When an entity is destroyed, its generation increments
- Stale handles (with old generation) return `nil`/`false` on access
- New entities at recycled IDs have different generations than old handles
- Minimal performance overhead for the safety guarantee

```lua
local handle = ecs.get_handle(entity_id)

-- Later, after entity might be destroyed:
if handle:valid() then
    local entity = handle:get()
    -- Safe to use entity
else
    -- Entity was destroyed, handle is stale
end
```

---

## Suggested Implementation Steps

1. **Add generation tracking to entity manager**
   ```lua
   -- Modify entity storage to track generations
   -- Each slot has: { components = {}, generation = N }

   local entity_slots = {}     -- id -> { components, generation }
   local generations = {}      -- id -> current generation (persists across recycles)
   local next_entity_id = 1
   local free_ids = {}

   -- {{{ create_entity
   function ecs.create_entity()
       local id
       if #free_ids > 0 then
           id = table.remove(free_ids)
       else
           id = next_entity_id
           next_entity_id = next_entity_id + 1
           generations[id] = 0  -- Initialize generation
       end

       entity_slots[id] = { components = {} }
       return id
   end
   -- }}}

   -- {{{ destroy_entity
   function ecs.destroy_entity(id)
       if entity_slots[id] then
           entity_slots[id] = nil
           generations[id] = generations[id] + 1  -- Increment generation
           table.insert(free_ids, id)
       end
   end
   -- }}}
   ```

2. **Define Handle class**
   ```lua
   -- {{{ Handle
   local Handle = {}
   Handle.__index = Handle

   -- Create a new handle for an entity
   -- @param id Entity ID
   -- @param generation Generation at time of handle creation
   function Handle.new(id, generation)
       local self = setmetatable({}, Handle)
       self._id = id
       self._generation = generation
       return self
   end

   -- Check if handle still points to a valid entity
   -- @return boolean True if entity exists and generation matches
   function Handle:valid()
       if not entity_slots[self._id] then
           return false
       end
       return generations[self._id] == self._generation
   end

   -- Get the entity ID if handle is valid
   -- @return number|nil Entity ID or nil if invalid
   function Handle:get()
       if self:valid() then
           return self._id
       end
       return nil
   end

   -- Get entity ID without validation (use with caution)
   -- @return number Raw entity ID
   function Handle:get_unchecked()
       return self._id
   end

   -- String representation for debugging
   function Handle:__tostring()
       local valid = self:valid() and "valid" or "stale"
       return string.format("Handle(%d, gen=%d, %s)", self._id, self._generation, valid)
   end
   -- }}}
   ```

3. **Add handle creation API**
   ```lua
   -- {{{ get_handle
   -- Create a handle for an existing entity
   -- @param id Entity ID
   -- @return Handle|nil Handle object or nil if entity doesn't exist
   function ecs.get_handle(id)
       if not entity_slots[id] then
           return nil
       end
       return Handle.new(id, generations[id])
   end
   -- }}}

   -- {{{ create_entity_with_handle
   -- Create entity and return both ID and Handle
   -- @return number, Handle Entity ID and handle
   function ecs.create_entity_with_handle()
       local id = ecs.create_entity()
       local handle = Handle.new(id, generations[id])
       return id, handle
   end
   -- }}}
   ```

4. **Add handle-based component access**
   ```lua
   -- {{{ get_component_by_handle
   -- Get component using a handle (safe access)
   -- @param handle Handle object
   -- @param component_name Component name
   -- @return table|nil Component data or nil if handle invalid
   function ecs.get_component_by_handle(handle, component_name)
       local id = handle:get()
       if not id then
           return nil
       end
       return ecs.get_component(id, component_name)
   end
   -- }}}

   -- {{{ has_entity
   -- Check if entity ID is currently valid
   -- @param id Entity ID
   -- @return boolean
   function ecs.has_entity(id)
       return entity_slots[id] ~= nil
   end
   -- }}}
   ```

5. **Create unit tests**
   ```lua
   -- {{{ test_handle_validity
   local function test_handle_validity()
       local ecs = require("runtime.ecs")
       ecs.init()

       -- Create entity and get handle
       local id = ecs.create_entity()
       local handle = ecs.get_handle(id)

       assert(handle:valid(), "Handle should be valid for existing entity")
       assert(handle:get() == id, "Handle should return entity ID")

       -- Destroy entity
       ecs.destroy_entity(id)

       assert(not handle:valid(), "Handle should be invalid after destruction")
       assert(handle:get() == nil, "Handle:get() should return nil for destroyed entity")

       ecs.shutdown()
       print("  Handle validity: PASSED")
   end
   -- }}}

   -- {{{ test_handle_generation
   local function test_handle_generation()
       local ecs = require("runtime.ecs")
       ecs.init()

       -- Create and destroy entity to get a recycled ID
       local id1 = ecs.create_entity()
       local handle1 = ecs.get_handle(id1)
       ecs.destroy_entity(id1)

       -- Create new entity (should recycle id1)
       local id2 = ecs.create_entity()
       local handle2 = ecs.get_handle(id2)

       -- IDs might be the same (recycled)
       if id1 == id2 then
           -- Old handle should be stale
           assert(not handle1:valid(), "Old handle should be stale after ID recycled")
           -- New handle should be valid
           assert(handle2:valid(), "New handle should be valid")
           -- They point to same ID but different generations
           assert(handle1:get_unchecked() == handle2:get_unchecked(), "Same raw ID")
       end

       ecs.shutdown()
       print("  Handle generation: PASSED")
   end
   -- }}}

   -- {{{ test_handle_component_access
   local function test_handle_component_access()
       local ecs = require("runtime.ecs")
       ecs.init()

       ecs.register_component("position", { x = 0, y = 0 })

       local id = ecs.create_entity()
       local handle = ecs.get_handle(id)
       ecs.add_component(id, "position", { x = 100, y = 200 })

       -- Access via handle while valid
       local pos = ecs.get_component_by_handle(handle, "position")
       assert(pos, "Should get component via valid handle")
       assert(pos.x == 100, "Position X should be 100")

       -- Destroy entity
       ecs.destroy_entity(id)

       -- Access via stale handle
       local pos2 = ecs.get_component_by_handle(handle, "position")
       assert(pos2 == nil, "Should get nil for stale handle")

       ecs.shutdown()
       print("  Handle component access: PASSED")
   end
   -- }}}

   -- {{{ test_handle_tostring
   local function test_handle_tostring()
       local ecs = require("runtime.ecs")
       ecs.init()

       local id = ecs.create_entity()
       local handle = ecs.get_handle(id)

       local str = tostring(handle)
       assert(str:match("Handle"), "String should contain 'Handle'")
       assert(str:match("valid"), "String should contain 'valid'")

       ecs.destroy_entity(id)

       local str2 = tostring(handle)
       assert(str2:match("stale"), "String should contain 'stale' after destruction")

       ecs.shutdown()
       print("  Handle tostring: PASSED")
   end
   -- }}}
   ```

6. **Create test file**
   ```
   src/tests/
   └── test_entity_handles.lua
   ```

---

## Technical Notes

### Generation Counter Strategy

Each entity slot maintains a generation counter:
- Starts at 0 when slot first used
- Increments each time an entity at that slot is destroyed
- Handles store the generation at creation time
- Comparison detects stale references

```
Slot 5:  gen=0 → create(A) → destroy(A) → gen=1 → create(B)
Handle to A: { id=5, gen=0 } → valid() returns false (gen mismatch)
Handle to B: { id=5, gen=1 } → valid() returns true
```

### Memory Overhead

Per-handle overhead:
- 1 number for entity ID
- 1 number for generation
- Metatable reference (shared)

Per-slot overhead:
- 1 number for generation counter (persists in `generations` table)

### Performance Considerations

- `Handle:valid()` is O(1) - two table lookups and one comparison
- `Handle:get()` is O(1) - calls valid() then returns ID
- Generation counters never reset, so 32-bit integers allow ~4 billion
  destroy/recreate cycles per slot before wraparound

### When to Use Handles

**Use handles when:**
- Storing entity references across frames
- Caching entity references in triggers/callbacks
- References may outlive the entity

**Use raw IDs when:**
- Operating on entity within same frame
- Iterating query results (entities guaranteed to exist)
- Performance-critical inner loops

### WC3 Comparison

WC3's handle system serves a similar purpose. Functions like `GetTriggerUnit()`
return handles that become invalid when the unit is removed. Our Handle class
provides the same safety guarantee.

---

## Related Documents

- issues/402-build-entity-component-system.md (parent issue)
- issues/402a-implement-entity-manager.md (entity lifecycle)
- docs/roadmap.md (Phase 4 context)

---

## Acceptance Criteria

- [ ] Generation counter added to entity manager
- [ ] Handle class implemented with valid()/get()/get_unchecked()
- [ ] ecs.get_handle(id) creates handles for existing entities
- [ ] ecs.create_entity_with_handle() returns ID and handle
- [ ] ecs.get_component_by_handle() provides safe component access
- [ ] Stale handles return false/nil appropriately
- [ ] Recycled IDs don't validate old handles
- [ ] Handle:__tostring() shows valid/stale status
- [ ] Unit tests cover all handle operations
- [ ] Performance overhead documented

---

## Notes

This issue is marked **optional** because the core ECS works without handles.
However, handles prevent a class of subtle bugs that are difficult to debug:

```lua
-- Without handles (dangerous):
local enemy_id = find_nearest_enemy()
-- ... later, enemy might be destroyed and ID recycled ...
damage_entity(enemy_id, 10)  -- Might damage wrong entity!

-- With handles (safe):
local enemy_handle = ecs.get_handle(find_nearest_enemy())
-- ... later ...
if enemy_handle:valid() then
    damage_entity(enemy_handle:get(), 10)  -- Only damages if same entity
end
```

For a game engine that runs triggers and callbacks asynchronously, handles
provide important safety guarantees. Recommend implementing this before
Phase 4 integration testing to catch reference bugs early.

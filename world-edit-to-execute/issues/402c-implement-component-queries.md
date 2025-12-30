# Issue 402c: Implement Component Queries

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** High
**Dependencies:** 402b-implement-component-registry
**Parent Issue:** 402-build-entity-component-system

---

## Current Behavior

Components can be added to entities and retrieved individually, but there is
no efficient way to find all entities that have a specific set of components.
Systems would have to iterate all entities and check each one.

---

## Intended Behavior

An efficient query system that:
- Maintains indices of entities by component type
- Returns entities with specific component(s)
- Supports single-component and multi-component queries
- Uses iterators for memory efficiency
- Updates indices automatically when components change

```lua
-- Example usage:
local ecs = require("runtime.ecs")

-- Query all entities with position component
for entity, pos in ecs.query("position") do
    pos.x = pos.x + 1
end

-- Query entities with BOTH position AND movement
for entity, pos, mov in ecs.query("position", "movement") do
    pos.x = pos.x + mov.speed * dt
end

-- Get count of entities with component
local unit_count = ecs.query_count("unit_type")

-- Get all matching entities as array (for non-iterator use)
local all_units = ecs.query_all("unit_type")
```

---

## Suggested Implementation Steps

1. **Create query module**
   ```lua
   -- {{{ src/runtime/ecs/query.lua
   -- Component query system for ECS
   -- Provides efficient iteration over entities by component type

   local query = {}

   local component = require("runtime.ecs.component")
   local entity = require("runtime.ecs.entity")
   -- }}}
   ```

2. **Implement single-component query iterator**
   ```lua
   -- {{{ query.single
   function query.single(component_name)
   -- }}}
   -- {{{ query.single
   function query.single(component_name)
       -- Query entities with a single component
       -- Returns iterator: entity_id, component_instance
       --
       -- Usage: for entity, comp in query.single("position") do ... end

       local storage = component.get_storage(component_name)
       if not storage then
           -- Return empty iterator for unregistered components
           return function() return nil end
       end

       -- Return iterator over storage
       local entity_id, comp_instance
       return function()
           entity_id, comp_instance = next(storage, entity_id)
           if entity_id then
               return entity_id, comp_instance
           end
           return nil
       end
   end
   -- }}}
   ```

3. **Implement multi-component query iterator**
   ```lua
   -- {{{ query.multi
   function query.multi(component_names)
   -- }}}
   -- {{{ query.multi
   function query.multi(component_names)
       -- Query entities with ALL specified components
       -- Returns iterator: entity_id, comp1, comp2, ...
       --
       -- Usage: for e, pos, mov in query.multi({"position", "movement"}) do ... end

       if #component_names == 0 then
           return function() return nil end
       end

       if #component_names == 1 then
           return query.single(component_names[1])
       end

       -- Get storage tables for all components
       local storages = {}
       for i, name in ipairs(component_names) do
           local storage = component.get_storage(name)
           if not storage then
               -- If any component not registered, no results
               return function() return nil end
           end
           storages[i] = storage
       end

       -- Iterate over smallest storage for efficiency
       -- Find storage with fewest entries
       local smallest_idx = 1
       local smallest_count = math.huge
       for i, storage in ipairs(storages) do
           local count = 0
           for _ in pairs(storage) do count = count + 1 end
           if count < smallest_count then
               smallest_count = count
               smallest_idx = i
           end
       end

       local base_storage = storages[smallest_idx]
       local entity_id = nil

       return function()
           while true do
               entity_id = next(base_storage, entity_id)
               if not entity_id then
                   return nil
               end

               -- Check if entity has ALL other components
               local has_all = true
               local components = {}

               for i, storage in ipairs(storages) do
                   local comp = storage[entity_id]
                   if not comp then
                       has_all = false
                       break
                   end
                   components[i] = comp
               end

               if has_all then
                   -- Return entity_id followed by all components
                   return entity_id, unpack(components)
               end
           end
       end
   end
   -- }}}
   ```

4. **Implement unified query function**
   ```lua
   -- {{{ query.query
   function query.query(...)
   -- }}}
   -- {{{ query.query
   function query.query(...)
       -- Unified query interface
       -- Accepts variadic component names
       -- Returns iterator: entity_id, comp1, comp2, ...
       --
       -- Usage: for e, pos in query.query("position") do ... end
       -- Usage: for e, pos, mov in query.query("position", "movement") do ... end

       local names = {...}

       if #names == 0 then
           return function() return nil end
       end

       if #names == 1 then
           return query.single(names[1])
       end

       return query.multi(names)
   end
   -- }}}
   ```

5. **Implement query count**
   ```lua
   -- {{{ query.count
   function query.count(...)
   -- }}}
   -- {{{ query.count
   function query.count(...)
       -- Count entities matching the query
       -- More efficient than iterating when you just need the count

       local names = {...}

       if #names == 0 then
           return 0
       end

       if #names == 1 then
           local storage = component.get_storage(names[1])
           if not storage then return 0 end

           local count = 0
           for _ in pairs(storage) do
               count = count + 1
           end
           return count
       end

       -- Multi-component: must iterate and check
       local count = 0
       for _ in query.multi(names) do
           count = count + 1
       end
       return count
   end
   -- }}}
   ```

6. **Implement query to array**
   ```lua
   -- {{{ query.all
   function query.all(...)
   -- }}}
   -- {{{ query.all
   function query.all(...)
       -- Get all matching entities as an array
       -- Returns array of entity IDs
       -- Use when you need to modify entities during iteration

       local results = {}
       for entity_id in query.query(...) do
           results[#results + 1] = entity_id
       end
       return results
   end
   -- }}}

   -- {{{ query.first
   function query.first(...)
   -- }}}
   -- {{{ query.first
   function query.first(...)
       -- Get first matching entity
       -- Returns entity_id, comp1, comp2, ... or nil

       local iter = query.query(...)
       return iter()
   end
   -- }}}
   ```

7. **Implement component-based filtering**
   ```lua
   -- {{{ query.with_value
   function query.with_value(component_name, field, value)
   -- }}}
   -- {{{ query.with_value
   function query.with_value(component_name, field, value)
       -- Query entities where component.field == value
       -- Returns iterator: entity_id, component
       --
       -- Usage: for e, owner in query.with_value("owner", "player_id", 0) do ... end

       local storage = component.get_storage(component_name)
       if not storage then
           return function() return nil end
       end

       local entity_id = nil

       return function()
           while true do
               entity_id = next(storage, entity_id)
               if not entity_id then
                   return nil
               end

               local comp = storage[entity_id]
               if comp[field] == value then
                   return entity_id, comp
               end
           end
       end
   end
   -- }}}

   -- {{{ query.with_predicate
   function query.with_predicate(component_name, predicate)
   -- }}}
   -- {{{ query.with_predicate
   function query.with_predicate(component_name, predicate)
       -- Query entities where predicate(component) returns true
       -- Returns iterator: entity_id, component
       --
       -- Usage: for e, stats in query.with_predicate("stats",
       --                          function(s) return s.hp < s.hp_max end) do ... end

       local storage = component.get_storage(component_name)
       if not storage then
           return function() return nil end
       end

       local entity_id = nil

       return function()
           while true do
               entity_id = next(storage, entity_id)
               if not entity_id then
                   return nil
               end

               local comp = storage[entity_id]
               if predicate(comp) then
                   return entity_id, comp
               end
           end
       end
   end
   -- }}}
   ```

8. **Implement exclusion query**
   ```lua
   -- {{{ query.without
   function query.without(required_components, excluded_components)
   -- }}}
   -- {{{ query.without
   function query.without(required_components, excluded_components)
       -- Query entities with required components but WITHOUT excluded ones
       -- Returns iterator: entity_id, required_comp1, required_comp2, ...
       --
       -- Usage: for e, pos in query.without({"position"}, {"frozen"}) do ... end

       if #required_components == 0 then
           return function() return nil end
       end

       -- Get required storages
       local req_storages = {}
       for i, name in ipairs(required_components) do
           local storage = component.get_storage(name)
           if not storage then
               return function() return nil end
           end
           req_storages[i] = storage
       end

       -- Get excluded storages
       local excl_storages = {}
       for i, name in ipairs(excluded_components) do
           local storage = component.get_storage(name)
           -- Nil storage means component doesn't exist, so no exclusions
           if storage then
               excl_storages[#excl_storages + 1] = storage
           end
       end

       local entity_id = nil
       local base_storage = req_storages[1]

       return function()
           while true do
               entity_id = next(base_storage, entity_id)
               if not entity_id then
                   return nil
               end

               -- Check exclusions first (usually faster)
               local excluded = false
               for _, storage in ipairs(excl_storages) do
                   if storage[entity_id] then
                       excluded = true
                       break
                   end
               end

               if not excluded then
                   -- Check all required components
                   local has_all = true
                   local components = {}

                   for i, storage in ipairs(req_storages) do
                       local comp = storage[entity_id]
                       if not comp then
                           has_all = false
                           break
                       end
                       components[i] = comp
                   end

                   if has_all then
                       return entity_id, unpack(components)
                   end
               end
           end
       end
   end
   -- }}}
   ```

9. **Export module**
   ```lua
   -- {{{ Module export
   return query
   -- }}}
   ```

10. **Update ECS init.lua**
    ```lua
    -- Add to src/runtime/ecs/init.lua:
    local query_mod = require("runtime.ecs.query")

    ecs.query = query_mod.query
    ecs.query_count = query_mod.count
    ecs.query_all = query_mod.all
    ecs.query_first = query_mod.first
    ecs.query_with_value = query_mod.with_value
    ecs.query_with_predicate = query_mod.with_predicate
    ecs.query_without = query_mod.without
    ```

11. **Create unit tests**
    ```lua
    -- {{{ src/tests/test_ecs_query.lua
    -- Tests for ECS query system

    local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
    package.path = DIR .. "/src/?.lua;" .. package.path

    local entity = require("runtime.ecs.entity")
    local component = require("runtime.ecs.component")
    local query = require("runtime.ecs.query")

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

    -- Setup
    entity.reset()
    component.reset()
    component.register("position", {x = 0, y = 0})
    component.register("movement", {speed = 100})
    component.register("stats", {hp = 100})
    component.register("owner", {player_id = 0})
    component.register("frozen", {})

    test_section("Single Component Query")
    entity.reset()
    component.reset()
    component.register("position", {x = 0, y = 0})

    local e1 = entity.create()
    local e2 = entity.create()
    local e3 = entity.create()
    component.add(e1, "position", {x = 10})
    component.add(e2, "position", {x = 20})
    -- e3 has no position

    local found = {}
    for eid, pos in query.single("position") do
        found[eid] = pos.x
    end

    test("Found 2 entities", found[e1] and found[e2] and not found[e3])
    test("Correct values", found[e1] == 10 and found[e2] == 20)

    test_section("Multi Component Query")
    entity.reset()
    component.reset()
    component.register("position", {x = 0})
    component.register("movement", {speed = 100})
    component.register("stats", {hp = 100})

    local e1 = entity.create()  -- pos + mov
    local e2 = entity.create()  -- pos only
    local e3 = entity.create()  -- pos + mov + stats
    local e4 = entity.create()  -- nothing

    component.add(e1, "position", {x = 1})
    component.add(e1, "movement", {speed = 200})

    component.add(e2, "position", {x = 2})

    component.add(e3, "position", {x = 3})
    component.add(e3, "movement", {speed = 300})
    component.add(e3, "stats", {hp = 50})

    local found = {}
    for eid, pos, mov in query.multi({"position", "movement"}) do
        found[eid] = {pos.x, mov.speed}
    end

    test("Found 2 entities with both", found[e1] ~= nil and found[e3] ~= nil)
    test("e2 not found (missing movement)", found[e2] == nil)
    test("e4 not found (no components)", found[e4] == nil)
    test("e1 values correct", found[e1] and found[e1][1] == 1 and found[e1][2] == 200)
    test("e3 values correct", found[e3] and found[e3][1] == 3 and found[e3][2] == 300)

    test_section("Unified Query Interface")
    -- Single component
    local count = 0
    for _ in query.query("position") do count = count + 1 end
    test("query() single works", count == 3)

    -- Multi component via variadic
    count = 0
    for _ in query.query("position", "movement") do count = count + 1 end
    test("query() multi works", count == 2)

    -- Three components
    count = 0
    for eid in query.query("position", "movement", "stats") do
        count = count + 1
        test("Three-component match is e3", eid == e3)
    end
    test("Three-component count", count == 1)

    test_section("Query Count")
    local c = query.count("position")
    test("Count position", c == 3)

    c = query.count("movement")
    test("Count movement", c == 2)

    c = query.count("position", "movement")
    test("Count multi", c == 2)

    c = query.count("position", "movement", "stats")
    test("Count triple", c == 1)

    c = query.count("nonexistent")
    test("Count unregistered", c == 0)

    test_section("Query All (Array)")
    local all = query.all("position")
    test("All returns array", type(all) == "table")
    test("All has 3 entities", #all == 3)

    all = query.all("position", "movement")
    test("All multi has 2", #all == 2)

    test_section("Query First")
    local first_eid, first_pos = query.first("position")
    test("First returns entity", first_eid ~= nil)
    test("First returns component", first_pos ~= nil)

    first_eid = query.first("nonexistent")
    test("First unregistered nil", first_eid == nil)

    first_eid = query.first("position", "movement", "stats")
    test("First multi", first_eid == e3)

    test_section("Query With Value")
    entity.reset()
    component.reset()
    component.register("owner", {player_id = 0})

    local e1 = entity.create()
    local e2 = entity.create()
    local e3 = entity.create()
    component.add(e1, "owner", {player_id = 0})
    component.add(e2, "owner", {player_id = 1})
    component.add(e3, "owner", {player_id = 0})

    local found = {}
    for eid in query.with_value("owner", "player_id", 0) do
        found[eid] = true
    end

    test("Found 2 with player_id=0", found[e1] and found[e3])
    test("Excluded player_id=1", not found[e2])

    test_section("Query With Predicate")
    entity.reset()
    component.reset()
    component.register("stats", {hp = 100, hp_max = 100})

    local e1 = entity.create()
    local e2 = entity.create()
    local e3 = entity.create()
    component.add(e1, "stats", {hp = 100})
    component.add(e2, "stats", {hp = 50})
    component.add(e3, "stats", {hp = 25})

    local damaged = {}
    for eid, stats in query.with_predicate("stats", function(s)
        return s.hp < s.hp_max
    end) do
        damaged[eid] = stats.hp
    end

    test("Found 2 damaged", damaged[e2] and damaged[e3])
    test("Excluded full health", not damaged[e1])
    test("Correct hp values", damaged[e2] == 50 and damaged[e3] == 25)

    test_section("Query Without (Exclusion)")
    entity.reset()
    component.reset()
    component.register("position", {x = 0})
    component.register("movement", {speed = 100})
    component.register("frozen", {})

    local e1 = entity.create()  -- pos + mov
    local e2 = entity.create()  -- pos + mov + frozen
    local e3 = entity.create()  -- pos only

    component.add(e1, "position")
    component.add(e1, "movement")

    component.add(e2, "position")
    component.add(e2, "movement")
    component.add(e2, "frozen")

    component.add(e3, "position")

    local found = {}
    for eid in query.without({"position", "movement"}, {"frozen"}) do
        found[eid] = true
    end

    test("Found 1 movable non-frozen", found[e1] and not found[e2])
    test("Excluded missing movement", not found[e3])

    test_section("Empty Query Edge Cases")
    local iter = query.query()
    test("Empty query returns nil", iter() == nil)

    iter = query.single("nonexistent_component")
    test("Unregistered component returns nil", iter() == nil)

    local c = query.count()
    test("Empty count is 0", c == 0)

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

### Query Performance

Single-component queries are O(n) where n is the number of entities with
that component. Multi-component queries use the smallest storage as the
base and check other components, which is efficient when one component
is rare.

### Iterator Pattern

Queries return iterators rather than arrays to avoid memory allocation
on every query. For hot paths (system updates), this is critical:
```lua
-- Good: no allocation
for e, pos in ecs.query("position") do ... end

-- Less efficient: creates array
local all = ecs.query_all("position")
for _, e in ipairs(all) do ... end
```

Use `query_all()` only when you need to modify entities during iteration
(adding/removing components would invalidate the iterator).

### Multi-Component Unpacking

The multi-component iterator uses `unpack()` to return all components:
```lua
return entity_id, unpack(components)
```

This allows clean syntax:
```lua
for e, pos, mov, stats in ecs.query("position", "movement", "stats") do
```

### Predicate Queries

`with_predicate` allows complex filtering without pre-indexing:
```lua
-- Find all units at low health
for e, stats in ecs.query_with_predicate("stats", function(s)
    return s.hp < s.hp_max * 0.25
end) do
    -- Heal or show warning
end
```

---

## Related Documents

- issues/402-build-entity-component-system.md (parent issue)
- issues/402b-implement-component-registry.md (provides get_storage)
- issues/402d-implement-system-registration.md (uses queries)
- src/runtime/ecs/query.lua (implementation)

---

## Acceptance Criteria

- [x] Module created at src/runtime/ecs/query.lua
- [x] `single(name)` returns iterator for single-component query
- [x] `multi(names)` returns iterator for multi-component query
- [x] `query(...)` unified interface accepts variadic names
- [x] Multi-component queries only return entities with ALL components
- [x] Iterators return entity_id followed by component instances
- [x] `count(...)` returns count without full iteration
- [x] `all(...)` returns array of entity IDs
- [x] `first(...)` returns first match or nil
- [x] `with_value(name, field, value)` filters by field value
- [x] `with_predicate(name, fn)` filters by predicate function
- [x] `without(required, excluded)` excludes components
- [x] Empty queries return empty iterators (not nil)
- [x] Unregistered component queries return empty iterators
- [x] ECS init.lua re-exports query functions
- [x] All code uses vimfold markers
- [x] Unit tests pass for all functionality

---

## Notes

The query system is what makes ECS practical. Systems need to efficiently
find relevant entities without checking every entity in the world.

For WC3 maps with hundreds of units, linear iteration is acceptable.
If performance becomes an issue, consider:
- Cached query results (invalidated on component add/remove)
- Bitset-based component masks
- Archetype storage (entities with same components stored together)

For now, simplicity wins. Optimize only if profiling shows queries are
a bottleneck.

---

## Implementation Notes

**Implemented:** 2025-12-27

### Files Created/Modified

- `src/runtime/ecs/query.lua` (~270 lines) - Query system
- `src/runtime/ecs/init.lua` (updated) - Added 9 query exports
- `src/tests/test_ecs_query.lua` (~400 lines) - 62 unit tests

### Key Features

1. **Iterator-based queries** - All query functions return closures that
   iterate over component storage. No intermediate arrays allocated on
   hot paths.

2. **Multi-component optimization** - Uses smallest storage as base for
   multi-component queries, reducing iteration count when one component
   is rarer than others.

3. **Flexible filtering**:
   - `with_value()` - Filter by exact field match
   - `with_predicate()` - Filter by arbitrary function
   - `without()` - Exclude entities with certain components

4. **Safety helpers**:
   - `query_all()` - Returns array for safe modification during iteration
   - `query_first()` - Get single entity without full iteration

### Test Coverage

- Single component queries
- Multi-component queries (2, 3+ components)
- Unified query interface
- Query count optimization
- Query all (array conversion)
- Query first
- Value-based filtering
- Predicate-based filtering
- Exclusion queries
- Edge cases (empty, unregistered)
- ECS main module integration
- Stress test (1000 entities)


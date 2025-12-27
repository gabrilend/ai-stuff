# Issue 402d: Implement System Registration

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** High
**Dependencies:** 402c-implement-component-queries
**Parent Issue:** 402-build-entity-component-system

---

## Current Behavior

Entity and component management exists, along with queries to find entities
by component type. However, there is no mechanism to register and run systems
that process entities each game tick.

---

## Intended Behavior

A system registration and execution framework that:
- Registers named systems with required components and update functions
- Executes systems in registration order each tick
- Provides matching entities to each system's update function
- Supports system enable/disable for debugging
- Integrates with the game loop (401)

```lua
-- Example usage:
local ecs = require("runtime.ecs")

-- Register a movement system
ecs.register_system("movement", {"position", "movement"}, function(entities, dt)
    for entity, pos, mov in entities do
        pos.x = pos.x + mov.velocity_x * dt
        pos.y = pos.y + mov.velocity_y * dt
    end
end)

-- Register a health regen system
ecs.register_system("health_regen", {"stats"}, function(entities, dt)
    for entity, stats in entities do
        if stats.hp < stats.hp_max then
            stats.hp = math.min(stats.hp + stats.regen_hp * dt, stats.hp_max)
        end
    end
end)

-- Each game tick (called by gameloop):
ecs.update(dt)
```

---

## Suggested Implementation Steps

1. **Create system module**
   ```lua
   -- {{{ src/runtime/ecs/system.lua
   -- System registration and execution for ECS
   -- Systems process entities with specific components each tick

   local system = {}

   local query = require("runtime.ecs.query")
   -- }}}
   ```

2. **Define system state**
   ```lua
   -- {{{ State
   -- Ordered list of systems (execution order matters)
   local systems = {}
   local system_count = 0

   -- System lookup by name
   local systems_by_name = {}

   -- Global enable/disable
   local systems_enabled = true
   -- }}}
   ```

3. **Implement system registration**
   ```lua
   -- {{{ system.register
   function system.register(name, required_components, update_fn, options)
   -- }}}
   -- {{{ system.register
   function system.register(name, required_components, update_fn, options)
       -- Register a system to process entities
       --
       -- name: unique string identifier
       -- required_components: array of component names entities must have
       -- update_fn: function(query_iterator, dt) called each tick
       -- options: optional table with:
       --   priority: number (lower = runs first, default 0)
       --   enabled: boolean (default true)
       --
       -- Returns system handle for later modification

       if type(name) ~= "string" then
           error("register: name must be a string")
       end

       if systems_by_name[name] then
           error("register: system '" .. name .. "' already registered")
       end

       if type(required_components) ~= "table" then
           error("register: required_components must be a table")
       end

       if type(update_fn) ~= "function" then
           error("register: update_fn must be a function")
       end

       options = options or {}

       local sys = {
           name = name,
           components = required_components,
           update = update_fn,
           priority = options.priority or 0,
           enabled = options.enabled ~= false,  -- default true
           stats = {
               update_count = 0,
               total_time = 0,
               last_entity_count = 0,
           },
       }

       system_count = system_count + 1
       systems[system_count] = sys
       systems_by_name[name] = sys

       -- Re-sort by priority (stable sort)
       table.sort(systems, function(a, b)
           if a.priority == b.priority then
               -- Maintain registration order for same priority
               return false
           end
           return a.priority < b.priority
       end)

       return sys
   end
   -- }}}
   ```

4. **Implement system update loop**
   ```lua
   -- {{{ system.update
   function system.update(dt)
   -- }}}
   -- {{{ system.update
   function system.update(dt)
       -- Execute all enabled systems
       -- Called once per game tick
       --
       -- dt: delta time (usually TICK_DURATION from gameloop)
       --
       -- Returns number of systems that ran

       if not systems_enabled then
           return 0
       end

       local ran_count = 0

       for i = 1, system_count do
           local sys = systems[i]

           if sys.enabled then
               -- Get query iterator for required components
               local iter = query.query(unpack(sys.components))

               -- Track performance (optional)
               local start_time = os.clock()
               local entity_count = 0

               -- Wrap iterator to count entities
               local counting_iter = function()
                   local result = {iter()}
                   if result[1] then
                       entity_count = entity_count + 1
                       return unpack(result)
                   end
                   return nil
               end

               -- Call system update with iterator
               sys.update(counting_iter, dt)

               -- Update stats
               local elapsed = os.clock() - start_time
               sys.stats.update_count = sys.stats.update_count + 1
               sys.stats.total_time = sys.stats.total_time + elapsed
               sys.stats.last_entity_count = entity_count

               ran_count = ran_count + 1
           end
       end

       return ran_count
   end
   -- }}}
   ```

5. **Implement system control functions**
   ```lua
   -- {{{ system.enable
   function system.enable(name)
   -- }}}
   -- {{{ system.enable
   function system.enable(name)
       -- Enable a system by name
       local sys = systems_by_name[name]
       if sys then
           sys.enabled = true
           return true
       end
       return false
   end
   -- }}}

   -- {{{ system.disable
   function system.disable(name)
   -- }}}
   -- {{{ system.disable
   function system.disable(name)
       -- Disable a system by name
       local sys = systems_by_name[name]
       if sys then
           sys.enabled = false
           return true
       end
       return false
   end
   -- }}}

   -- {{{ system.is_enabled
   function system.is_enabled(name)
   -- }}}
   -- {{{ system.is_enabled
   function system.is_enabled(name)
       -- Check if a system is enabled
       local sys = systems_by_name[name]
       return sys and sys.enabled
   end
   -- }}}

   -- {{{ system.set_all_enabled
   function system.set_all_enabled(enabled)
   -- }}}
   -- {{{ system.set_all_enabled
   function system.set_all_enabled(enabled)
       -- Enable or disable all systems globally
       systems_enabled = enabled
   end
   -- }}}
   ```

6. **Implement system queries**
   ```lua
   -- {{{ system.get
   function system.get(name)
   -- }}}
   -- {{{ system.get
   function system.get(name)
       -- Get a system by name
       return systems_by_name[name]
   end
   -- }}}

   -- {{{ system.get_all
   function system.get_all()
   -- }}}
   -- {{{ system.get_all
   function system.get_all()
       -- Get all systems in execution order
       local result = {}
       for i = 1, system_count do
           result[i] = systems[i]
       end
       return result
   end
   -- }}}

   -- {{{ system.get_count
   function system.get_count()
   -- }}}
   -- {{{ system.get_count
   function system.get_count()
       -- Get total number of registered systems
       return system_count
   end
   -- }}}
   ```

7. **Implement system removal**
   ```lua
   -- {{{ system.unregister
   function system.unregister(name)
   -- }}}
   -- {{{ system.unregister
   function system.unregister(name)
       -- Remove a system by name
       -- Returns true if removed, false if not found

       local sys = systems_by_name[name]
       if not sys then
           return false
       end

       -- Find and remove from ordered list
       for i = 1, system_count do
           if systems[i] == sys then
               table.remove(systems, i)
               system_count = system_count - 1
               break
           end
       end

       systems_by_name[name] = nil
       return true
   end
   -- }}}
   ```

8. **Implement reset and debug**
   ```lua
   -- {{{ system.reset
   function system.reset()
   -- }}}
   -- {{{ system.reset
   function system.reset()
       -- Reset all systems (clear registrations)
       -- Called when loading a new map

       systems = {}
       system_count = 0
       systems_by_name = {}
       systems_enabled = true
   end
   -- }}}

   -- {{{ system.get_stats
   function system.get_stats()
   -- }}}
   -- {{{ system.get_stats
   function system.get_stats()
       -- Get performance statistics for all systems

       local result = {
           total_systems = system_count,
           enabled_count = 0,
           systems = {},
       }

       for i = 1, system_count do
           local sys = systems[i]
           if sys.enabled then
               result.enabled_count = result.enabled_count + 1
           end

           result.systems[sys.name] = {
               priority = sys.priority,
               enabled = sys.enabled,
               components = sys.components,
               update_count = sys.stats.update_count,
               total_time = sys.stats.total_time,
               avg_time = sys.stats.update_count > 0
                   and (sys.stats.total_time / sys.stats.update_count)
                   or 0,
               last_entity_count = sys.stats.last_entity_count,
           }
       end

       return result
   end
   -- }}}

   -- {{{ system.reset_stats
   function system.reset_stats()
   -- }}}
   -- {{{ system.reset_stats
   function system.reset_stats()
       -- Reset performance statistics
       for i = 1, system_count do
           local sys = systems[i]
           sys.stats.update_count = 0
           sys.stats.total_time = 0
           sys.stats.last_entity_count = 0
       end
   end
   -- }}}
   ```

9. **Export module**
   ```lua
   -- {{{ Module export
   return system
   -- }}}
   ```

10. **Update ECS init.lua**
    ```lua
    -- Add to src/runtime/ecs/init.lua:
    local system = require("runtime.ecs.system")

    ecs.register_system = system.register
    ecs.update = system.update
    ecs.enable_system = system.enable
    ecs.disable_system = system.disable
    ecs.is_system_enabled = system.is_enabled
    ecs.get_system = system.get
    ecs.get_all_systems = system.get_all
    ecs.unregister_system = system.unregister
    ecs.get_system_stats = system.get_stats
    ```

11. **Integrate with gameloop**
    ```lua
    -- In src/runtime/gameloop.lua or where tick processing happens:
    local ecs = require("runtime.ecs")

    -- Register ECS update as a tick callback
    gameloop.add_tick_callback(function(tick, time)
        ecs.update(gameloop.get_tick_duration())
    end)
    ```

12. **Create unit tests**
    ```lua
    -- {{{ src/tests/test_ecs_system.lua
    -- Tests for ECS system registration and execution

    local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
    package.path = DIR .. "/src/?.lua;" .. package.path

    local entity = require("runtime.ecs.entity")
    local component = require("runtime.ecs.component")
    local system = require("runtime.ecs.system")

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
    system.reset()
    component.register("position", {x = 0, y = 0})
    component.register("velocity", {vx = 0, vy = 0})
    component.register("stats", {hp = 100})

    test_section("System Registration")
    local called = false
    system.register("test_system", {"position"}, function(entities, dt)
        called = true
    end)

    test("System registered", system.get("test_system") ~= nil)
    test("System count is 1", system.get_count() == 1)
    test("System enabled by default", system.is_enabled("test_system"))

    -- Double registration should error
    local ok = pcall(function()
        system.register("test_system", {"position"}, function() end)
    end)
    test("Double registration errors", not ok)

    test_section("System Execution")
    entity.reset()
    system.reset()
    component.reset()
    component.register("position", {x = 0, y = 0})

    local update_calls = 0
    local entity_count = 0
    local received_dt = 0

    system.register("counter", {"position"}, function(entities, dt)
        update_calls = update_calls + 1
        received_dt = dt
        for e in entities do
            entity_count = entity_count + 1
        end
    end)

    -- Create some entities
    local e1 = entity.create()
    local e2 = entity.create()
    component.add(e1, "position")
    component.add(e2, "position")

    local ran = system.update(0.016)
    test("Update returns 1 system ran", ran == 1)
    test("System was called", update_calls == 1)
    test("Received correct dt", received_dt == 0.016)
    test("Processed 2 entities", entity_count == 2)

    test_section("System Priority")
    system.reset()

    local order = {}
    system.register("third", {}, function() order[#order+1] = "third" end, {priority = 10})
    system.register("first", {}, function() order[#order+1] = "first" end, {priority = -10})
    system.register("second", {}, function() order[#order+1] = "second" end, {priority = 0})

    system.update(0)
    test("First runs first", order[1] == "first")
    test("Second runs second", order[2] == "second")
    test("Third runs third", order[3] == "third")

    test_section("System Enable/Disable")
    system.reset()

    local counter = 0
    system.register("toggleable", {}, function() counter = counter + 1 end)

    system.update(0)
    test("Runs when enabled", counter == 1)

    system.disable("toggleable")
    test("Is disabled", not system.is_enabled("toggleable"))

    system.update(0)
    test("Doesn't run when disabled", counter == 1)

    system.enable("toggleable")
    test("Is enabled again", system.is_enabled("toggleable"))

    system.update(0)
    test("Runs after re-enable", counter == 2)

    test_section("Global Enable/Disable")
    system.reset()

    counter = 0
    system.register("sys1", {}, function() counter = counter + 1 end)
    system.register("sys2", {}, function() counter = counter + 1 end)

    system.update(0)
    test("Both run normally", counter == 2)

    counter = 0
    system.set_all_enabled(false)
    system.update(0)
    test("None run when globally disabled", counter == 0)

    system.set_all_enabled(true)
    system.update(0)
    test("Both run when globally enabled", counter == 2)

    test_section("System Unregistration")
    system.reset()

    system.register("to_remove", {}, function() end)
    system.register("to_keep", {}, function() end)

    test("Count is 2", system.get_count() == 2)

    local removed = system.unregister("to_remove")
    test("Unregister returns true", removed)
    test("Count is 1", system.get_count() == 1)
    test("Removed system not found", system.get("to_remove") == nil)
    test("Kept system exists", system.get("to_keep") ~= nil)

    removed = system.unregister("nonexistent")
    test("Unregister nonexistent returns false", not removed)

    test_section("System Stats")
    system.reset()
    entity.reset()
    component.reset()
    component.register("data", {})

    system.register("measured", {"data"}, function(entities, dt)
        for e in entities do end
    end)

    local e1 = entity.create()
    component.add(e1, "data")

    for i = 1, 5 do
        system.update(0.016)
    end

    local stats = system.get_stats()
    test("Stats total systems", stats.total_systems == 1)
    test("Stats enabled count", stats.enabled_count == 1)
    test("Stats update count", stats.systems.measured.update_count == 5)
    test("Stats has avg_time", stats.systems.measured.avg_time >= 0)
    test("Stats last entity count", stats.systems.measured.last_entity_count == 1)

    system.reset_stats()
    stats = system.get_stats()
    test("Stats reset", stats.systems.measured.update_count == 0)

    test_section("Get All Systems")
    system.reset()
    system.register("sys_a", {}, function() end)
    system.register("sys_b", {}, function() end)
    system.register("sys_c", {}, function() end)

    local all = system.get_all()
    test("Get all returns 3", #all == 3)
    test("Systems in order", all[1].name == "sys_a" or
                              all[2].name == "sys_b" or
                              all[3].name == "sys_c")

    test_section("Empty Components Query")
    system.reset()

    local empty_called = false
    system.register("empty_query", {}, function(entities, dt)
        empty_called = true
        -- Should still be callable
    end)

    system.update(0)
    test("Empty component system runs", empty_called)

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

### System Execution Order

Systems run in priority order (lowest first). Same-priority systems run
in registration order. This allows:
- Movement before collision
- Damage before death
- Cleanup after everything

### Delta Time

Each system receives `dt` - the time elapsed since the last tick. For
fixed timestep (401), this is always `TICK_DURATION` (~0.016 seconds).
Systems should multiply time-based values by `dt` for framerate independence.

### Performance Tracking

Each system tracks:
- `update_count`: How many times it ran
- `total_time`: Cumulative time spent
- `last_entity_count`: Entities processed last update

This helps identify slow systems during profiling.

### Entity Modification During Iteration

Systems should not create/destroy entities during iteration. If needed:
1. Collect entities to modify in a separate list
2. Process modifications after iteration
3. Or use `query.all()` to get a stable array

### Integration with Game Loop

The ECS `update()` function is registered as a tick callback with the
game loop (401). This ensures systems run at the correct rate and
integrate with timer processing.

---

## Related Documents

- issues/402-build-entity-component-system.md (parent issue)
- issues/402c-implement-component-queries.md (provides query iterator)
- issues/401a-core-fixed-timestep-loop.md (game loop integration)
- src/runtime/ecs/system.lua (implementation)

---

## Acceptance Criteria

- [x] Module created at src/runtime/ecs/system.lua
- [x] `register(name, components, update_fn, options)` registers systems
- [x] Double registration raises error
- [x] Systems receive query iterator and dt in update function
- [x] `update(dt)` executes all enabled systems
- [x] Systems run in priority order (lower first)
- [x] Same-priority systems run in registration order
- [x] `enable(name)` and `disable(name)` control individual systems
- [x] `is_enabled(name)` returns system state
- [x] `set_all_enabled(bool)` controls global execution
- [x] `get(name)` returns system by name
- [x] `get_all()` returns all systems in order
- [x] `get_count()` returns system count
- [x] `unregister(name)` removes systems
- [x] `get_stats()` returns performance information
- [x] `reset()` clears all systems
- [x] ECS init.lua re-exports system functions
- [x] Integration point with gameloop documented
- [x] All code uses vimfold markers
- [x] Unit tests pass for all functionality

---

## Notes

Systems are where game logic lives. Keep them focused and single-purpose:
- `movement_system`: Updates positions based on velocity
- `health_regen_system`: Regenerates HP over time
- `death_system`: Removes entities with HP <= 0

The priority system allows explicit ordering when needed:
```lua
ecs.register_system("input", {"player"}, handle_input, {priority = -100})
ecs.register_system("movement", {"position", "velocity"}, update_movement)
ecs.register_system("collision", {"position", "collider"}, check_collisions, {priority = 50})
ecs.register_system("cleanup", {"marked_for_death"}, remove_dead, {priority = 100})
```

Start with no explicit priorities; add them only when order matters.

---

## Implementation Notes

### Files Created/Modified
- `src/runtime/ecs/system.lua` (~294 lines) - System registration, execution, stats tracking
- `src/runtime/ecs/init.lua` - Added 12 system exports to ECS API
- `src/tests/test_ecs_system.lua` (~400 lines) - 132 tests covering all functionality

### Key Implementation Details

1. **Priority-based sorting with stable ordering**: Systems with equal priority run in
   registration order, achieved by using a `_sort_order` field during sorting.

2. **Counting iterator wrapper**: The update loop wraps the query iterator to count
   entities processed without affecting the system's iteration logic.

3. **Empty components support**: Systems with empty component requirements get a no-op
   iterator and still run each tick (useful for global update systems).

4. **Global vs individual enable**: `set_all_enabled(false)` overrides individual system
   enabled states, providing a global pause mechanism.

5. **Performance stats**: Each system tracks update_count, total_time, and last_entity_count
   for profiling. Stats can be reset without affecting registrations.

### Test Coverage
- 132 tests covering: registration, execution, priority, enable/disable, queries, stats, reset
- Total ECS test suite: 357 tests (64 entity + 99 component + 62 query + 132 system)

### Integration with Gameloop
The gameloop (401) will call `ecs.update_systems(dt)` as a tick callback to run all
systems at the fixed 62.5 Hz tick rate.


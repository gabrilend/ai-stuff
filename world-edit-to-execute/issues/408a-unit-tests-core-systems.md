# Issue 408a: Unit Tests - Core Systems

**Phase:** 4 - Runtime
**Type:** Test
**Priority:** High
**Dependencies:** 401 (game loop), 402 (ECS), 403 (pathfinding)

---

## Current Behavior

No unit tests exist for the core runtime systems: game loop, entity component system, and pathfinding. These are foundational systems that other Phase 4 components depend on.

---

## Intended Behavior

Comprehensive unit tests for:
- **Game Loop (401):** Tick rate accuracy, timer integration, pause/resume
- **ECS (402):** Entity lifecycle, component operations, system queries
- **Pathfinding (403):** Grid construction, A* algorithm, obstacle avoidance

Tests should be isolated (not require other Phase 4 systems) and fast (< 2 seconds total).

---

## Suggested Implementation Steps

1. **Create test file structure**
   ```
   src/tests/
   └── test_phase4_core.lua
   ```

2. **Implement game loop timing test**
   ```lua
   function test_game_loop_timing()
       local gameloop = require("runtime.gameloop")
       gameloop.init()

       local start_tick = gameloop.get_tick()

       -- Simulate 1 second of game time at 62.5 ticks/sec
       for i = 1, 100 do
           gameloop.update(0.01)  -- 10ms per frame
       end

       local elapsed_ticks = gameloop.get_tick() - start_tick
       local expected_ticks = 62  -- ~62.5 ticks per second

       assert(math.abs(elapsed_ticks - expected_ticks) <= 2,
           "Tick rate incorrect: got " .. elapsed_ticks .. ", expected ~" .. expected_ticks)

       gameloop.shutdown()
   end
   ```

3. **Implement game loop pause/resume test**
   ```lua
   function test_game_loop_pause()
       local gameloop = require("runtime.gameloop")
       gameloop.init()

       gameloop.pause()
       local tick_before = gameloop.get_tick()
       gameloop.update(1.0)  -- 1 second while paused
       local tick_after = gameloop.get_tick()

       assert(tick_before == tick_after, "Ticks advanced while paused")

       gameloop.resume()
       gameloop.update(0.1)

       assert(gameloop.get_tick() > tick_after, "Ticks should advance after resume")

       gameloop.shutdown()
   end
   ```

4. **Implement ECS entity lifecycle test**
   ```lua
   function test_ecs_entity_lifecycle()
       local ecs = require("runtime.ecs")
       ecs.init()

       -- Create entity
       local entity = ecs.create_entity()
       assert(entity, "Entity creation failed")
       assert(ecs.entity_exists(entity), "Entity should exist after creation")

       -- Destroy entity
       ecs.destroy_entity(entity)
       assert(not ecs.entity_exists(entity), "Entity should not exist after destruction")

       ecs.shutdown()
   end
   ```

5. **Implement ECS component operations test**
   ```lua
   function test_ecs_components()
       local ecs = require("runtime.ecs")
       ecs.init()

       local entity = ecs.create_entity()

       -- Add component
       ecs.add_component(entity, "position", {x = 100, y = 200, z = 0})
       local pos = ecs.get_component(entity, "position")
       assert(pos, "Component should exist after adding")
       assert(pos.x == 100, "Position X incorrect")
       assert(pos.y == 200, "Position Y incorrect")

       -- Modify component
       pos.x = 150
       local pos2 = ecs.get_component(entity, "position")
       assert(pos2.x == 150, "Component modification not persisted")

       -- Remove component
       ecs.remove_component(entity, "position")
       assert(ecs.get_component(entity, "position") == nil, "Component should be nil after removal")

       -- Add multiple components
       ecs.add_component(entity, "movement", {speed = 270})
       ecs.add_component(entity, "health", {current = 100, max = 100})

       local has_movement = ecs.has_component(entity, "movement")
       local has_health = ecs.has_component(entity, "health")
       assert(has_movement, "Should have movement component")
       assert(has_health, "Should have health component")

       ecs.destroy_entity(entity)
       ecs.shutdown()
   end
   ```

6. **Implement ECS query test**
   ```lua
   function test_ecs_queries()
       local ecs = require("runtime.ecs")
       ecs.init()

       -- Create entities with different component combinations
       local e1 = ecs.create_entity()
       ecs.add_component(e1, "position", {x = 0, y = 0})
       ecs.add_component(e1, "movement", {speed = 270})

       local e2 = ecs.create_entity()
       ecs.add_component(e2, "position", {x = 100, y = 100})
       -- No movement component

       local e3 = ecs.create_entity()
       ecs.add_component(e3, "position", {x = 200, y = 200})
       ecs.add_component(e3, "movement", {speed = 350})

       -- Query entities with both position and movement
       local movers = ecs.query({"position", "movement"})
       assert(#movers == 2, "Should find 2 entities with position+movement")

       -- Query entities with just position
       local positioned = ecs.query({"position"})
       assert(#positioned == 3, "Should find 3 entities with position")

       ecs.shutdown()
   end
   ```

7. **Implement pathfinding grid construction test**
   ```lua
   function test_pathfinding_grid()
       local pathfinding = require("runtime.pathfinding")

       -- Create a simple terrain mockup
       local terrain = {
           width = 32,
           height = 32,
           cell_size = 128,
           is_walkable = function(self, gx, gy)
               -- Block center area
               if gx >= 14 and gx <= 17 and gy >= 14 and gy <= 17 then
                   return false
               end
               return true
           end
       }

       pathfinding.build_grid(terrain)

       -- Verify grid dimensions
       local grid = pathfinding.get_grid()
       assert(grid.width == 32, "Grid width incorrect")
       assert(grid.height == 32, "Grid height incorrect")

       -- Verify walkability
       assert(pathfinding.is_walkable(0, 0), "Corner should be walkable")
       assert(not pathfinding.is_walkable(15, 15), "Center should be blocked")
   end
   ```

8. **Implement A* pathfinding test**
   ```lua
   function test_pathfinding_astar()
       local pathfinding = require("runtime.pathfinding")

       -- Build grid with obstacle
       local terrain = {
           width = 20,
           height = 20,
           cell_size = 128,
           is_walkable = function(self, gx, gy)
               -- Vertical wall from y=5 to y=14 at x=10
               if gx == 10 and gy >= 5 and gy <= 14 then
                   return false
               end
               return true
           end
       }

       pathfinding.build_grid(terrain)

       -- Find path that must go around wall
       local path = pathfinding.find_path(
           {x = 5, y = 10},   -- Start (left of wall)
           {x = 15, y = 10},  -- End (right of wall)
           "foot"
       )

       assert(path, "Path should be found")
       assert(#path >= 3, "Path should have multiple waypoints to go around wall")

       -- Verify path doesn't go through obstacle
       for _, waypoint in ipairs(path) do
           local gx, gy = pathfinding.world_to_grid(waypoint.x, waypoint.y)
           assert(pathfinding.is_walkable(gx, gy),
               "Path waypoint at grid (" .. gx .. "," .. gy .. ") goes through obstacle")
       end
   end
   ```

9. **Implement pathfinding edge cases test**
   ```lua
   function test_pathfinding_edge_cases()
       local pathfinding = require("runtime.pathfinding")

       -- Simple open terrain
       local terrain = {
           width = 10,
           height = 10,
           cell_size = 128,
           is_walkable = function() return true end
       }

       pathfinding.build_grid(terrain)

       -- Same start and end
       local path1 = pathfinding.find_path({x = 5, y = 5}, {x = 5, y = 5}, "foot")
       assert(path1 and #path1 == 1, "Same start/end should return single-point path")

       -- Adjacent points
       local path2 = pathfinding.find_path({x = 0, y = 0}, {x = 1, y = 0}, "foot")
       assert(path2 and #path2 >= 1, "Adjacent points should have path")

       -- Completely blocked destination
       local blocked_terrain = {
           width = 10,
           height = 10,
           cell_size = 128,
           is_walkable = function(self, gx, gy)
               -- Block destination
               if gx == 9 and gy == 9 then return false end
               return true
           end
       }
       pathfinding.build_grid(blocked_terrain)

       local path3 = pathfinding.find_path({x = 0, y = 0}, {x = 9, y = 9}, "foot")
       assert(path3 == nil, "Path to blocked destination should return nil")
   end
   ```

10. **Create test runner**
    ```lua
    local function run_tests()
        local tests = {
            {"Game loop timing", test_game_loop_timing},
            {"Game loop pause/resume", test_game_loop_pause},
            {"ECS entity lifecycle", test_ecs_entity_lifecycle},
            {"ECS components", test_ecs_components},
            {"ECS queries", test_ecs_queries},
            {"Pathfinding grid", test_pathfinding_grid},
            {"Pathfinding A*", test_pathfinding_astar},
            {"Pathfinding edge cases", test_pathfinding_edge_cases},
        }

        local passed = 0
        local failed = 0

        for _, test in ipairs(tests) do
            local name, fn = test[1], test[2]
            local ok, err = pcall(fn)
            if ok then
                print("PASS: " .. name)
                passed = passed + 1
            else
                print("FAIL: " .. name)
                print("  " .. tostring(err))
                failed = failed + 1
            end
        end

        print(string.format("\n%d/%d tests passed", passed, passed + failed))
        return failed == 0
    end

    if not run_tests() then os.exit(1) end
    ```

---

## Related Documents

- issues/408-phase-4-integration-test.md (parent issue)
- issues/401-implement-game-tick-update-loop.md
- issues/402-build-entity-component-system.md
- issues/403-implement-basic-pathfinding.md
- issues/408b-unit-tests-entity-systems.md (sibling - depends on this)

---

## Acceptance Criteria

- [ ] Game loop timing test passes (62.5 ticks/sec within ±2)
- [ ] Game loop pause/resume test passes
- [ ] ECS entity lifecycle test passes (create/destroy)
- [ ] ECS component operations test passes (add/get/remove)
- [ ] ECS query test passes (multi-component queries)
- [ ] Pathfinding grid construction test passes
- [ ] A* pathfinding with obstacle avoidance test passes
- [ ] Pathfinding edge cases test passes (same point, blocked dest)
- [ ] All tests complete in under 2 seconds

---

## Notes

These tests form the foundation for Phase 4 integration testing. Issues 408b and 408c can only proceed once these core system tests pass.

The game loop timing test may need tolerance adjustments on slower systems. Consider using a relative tolerance rather than absolute.

For pathfinding, the coordinate system should match WC3 conventions:
- World coordinates in game units (typically -32768 to 32768)
- Grid coordinates are indices into the pathing grid

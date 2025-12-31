# Issue 408d: Integration Scenario

**Phase:** 4 - Runtime
**Type:** Test
**Priority:** High
**Dependencies:** 408a (core tests), 408b (entity tests), 408c (player tests)

---

## Current Behavior

Individual unit tests verify components in isolation. No test verifies that all Phase 4 systems work together as a cohesive runtime.

---

## Intended Behavior

End-to-end integration scenario simulating a real game:
1. Initialize all runtime systems
2. Spawn units for multiple players
3. Issue movement orders
4. Run game loop for several seconds
5. Verify units moved, collisions handled, resources tracked
6. Check victory conditions

This proves all Phase 4 components integrate correctly.

---

## Suggested Implementation Steps

1. **Create integration test file**
   ```
   src/tests/
   └── test_phase4_integration.lua
   ```

2. **Implement system initialization sequence**
   ```lua
   local function init_all_systems()
       local gameloop = require("runtime.gameloop")
       local ecs = require("runtime.ecs")
       local pathfinding = require("runtime.pathfinding")
       local movement = require("runtime.movement")
       local collision = require("runtime.collision")
       local resources = require("runtime.resources")
       local player = require("runtime.player")

       -- Initialize in correct order (dependencies first)
       gameloop.init()
       ecs.init()
       resources.init()
       player.init()

       -- Build terrain/pathfinding grid
       local terrain = create_test_terrain()
       pathfinding.build_grid(terrain)

       -- Initialize systems that depend on ECS/pathfinding
       collision.init(ecs)
       movement.init(ecs, pathfinding, collision)

       return {
           gameloop = gameloop,
           ecs = ecs,
           pathfinding = pathfinding,
           movement = movement,
           collision = collision,
           resources = resources,
           player = player,
           terrain = terrain,
       }
   end
   ```

3. **Create test terrain helper**
   ```lua
   local function create_test_terrain()
       -- 64x64 grid, 128 units per cell = 8192x8192 world units
       return {
           width = 64,
           height = 64,
           cell_size = 128,
           -- Walkable everywhere except some obstacles
           is_walkable = function(self, gx, gy)
               -- Block a few cells in center (simulate trees/rocks)
               if gx >= 30 and gx <= 33 and gy >= 30 and gy <= 33 then
                   return false
               end
               return true
           end,
           -- Get start location for player
           get_start_location = function(self, player_id)
               local locations = {
                   [0] = {x = 1000, y = 1000},
                   [1] = {x = 7000, y = 7000},
               }
               return locations[player_id] or {x = 4000, y = 4000}
           end,
       }
   end
   ```

4. **Create unit spawning helper**
   ```lua
   local function spawn_unit(systems, owner, x, y, unit_type)
       local ecs = systems.ecs

       local entity = ecs.create_entity()

       -- Position component
       ecs.add_component(entity, "position", {
           x = x,
           y = y,
           facing = 0,
       })

       -- Movement component (units can move)
       local speed = unit_type == "worker" and 190 or 270
       ecs.add_component(entity, "movement", {
           speed = speed,
           pathing_type = "foot",
           current_order = nil,
           path = nil,
           path_index = 1,
       })

       -- Collision component
       ecs.add_component(entity, "collision", {
           radius = 32,
           type = "unit",
       })

       -- Unit identity
       ecs.add_component(entity, "unit", {
           owner = owner,
           unit_type = unit_type,
           handle = entity,  -- For JASS-style handle queries
       })

       -- Health component
       local max_hp = unit_type == "worker" and 220 or 420
       ecs.add_component(entity, "health", {
           current = max_hp,
           max = max_hp,
       })

       return entity
   end
   ```

5. **Implement two-player melee scenario**
   ```lua
   function test_two_player_melee()
       local systems = init_all_systems()

       -- Configure players
       systems.player.set_slot(0, {
           type = "human",
           race = "human",
           team = 0,
           name = "Player 1",
       })
       systems.player.set_slot(1, {
           type = "computer",
           race = "orc",
           team = 1,
           name = "Computer",
       })

       -- Set starting resources
       systems.resources.set(0, "gold", 500)
       systems.resources.set(0, "lumber", 150)
       systems.resources.set(1, "gold", 500)
       systems.resources.set(1, "lumber", 150)

       -- Get start locations
       local p0_start = systems.terrain:get_start_location(0)
       local p1_start = systems.terrain:get_start_location(1)

       -- Spawn starting units for player 0
       local p0_workers = {}
       for i = 1, 5 do
           local offset_x = (i - 1) * 64
           local worker = spawn_unit(systems, 0,
               p0_start.x + offset_x, p0_start.y, "worker")
           p0_workers[i] = worker
       end

       -- Spawn starting units for player 1
       local p1_workers = {}
       for i = 1, 5 do
           local offset_x = (i - 1) * 64
           local worker = spawn_unit(systems, 1,
               p1_start.x + offset_x, p1_start.y, "worker")
           p1_workers[i] = worker
       end

       -- Verify initial state
       assert(#systems.ecs.query({"unit"}) == 10, "Should have 10 units total")

       -- Issue move orders to player 0 workers (move toward center)
       for _, worker in ipairs(p0_workers) do
           systems.movement.order_move(worker, 4000, 4000)
       end

       -- Run simulation for ~2 seconds (125 ticks)
       for tick = 1, 125 do
           systems.gameloop.tick()
           systems.movement.update()
           systems.collision.update()
       end

       -- Verify workers moved
       for i, worker in ipairs(p0_workers) do
           local pos = systems.ecs.get_component(worker, "position")
           local distance_from_start = math.sqrt(
               (pos.x - p0_start.x)^2 + (pos.y - p0_start.y)^2)
           assert(distance_from_start > 100,
               "Worker " .. i .. " should have moved from start")
       end

       -- Verify resources unchanged (no spending occurred)
       assert(systems.resources.get(0, "gold") == 500, "Gold unchanged")

       -- Shutdown all systems
       shutdown_all_systems(systems)
   end
   ```

6. **Implement collision avoidance scenario**
   ```lua
   function test_collision_avoidance()
       local systems = init_all_systems()

       systems.player.set_slot(0, {type = "human", team = 0})

       -- Spawn two units that will collide
       local unit1 = spawn_unit(systems, 0, 0, 0, "footman")
       local unit2 = spawn_unit(systems, 0, 200, 0, "footman")

       -- Order both to move to same location
       systems.movement.order_move(unit1, 100, 0)
       systems.movement.order_move(unit2, 100, 0)

       -- Run for 1 second
       for tick = 1, 62 do
           systems.gameloop.tick()
           systems.movement.update()
           systems.collision.update()
       end

       -- Get final positions
       local pos1 = systems.ecs.get_component(unit1, "position")
       local pos2 = systems.ecs.get_component(unit2, "position")

       -- Verify units don't overlap
       local distance = math.sqrt((pos1.x - pos2.x)^2 + (pos1.y - pos2.y)^2)
       local combined_radius = 32 + 32

       assert(distance >= combined_radius - 1,
           "Units should not overlap: distance=" .. distance)

       shutdown_all_systems(systems)
   end
   ```

7. **Implement pathfinding around obstacles scenario**
   ```lua
   function test_pathfinding_around_obstacles()
       local systems = init_all_systems()

       systems.player.set_slot(0, {type = "human", team = 0})

       -- Spawn unit on one side of obstacle (center is blocked at 30-33)
       local unit = spawn_unit(systems, 0, 2000, 4000, "footman")

       -- Order to move to other side of obstacle
       systems.movement.order_move(unit, 6000, 4000)

       -- Get initial path
       local mov = systems.ecs.get_component(unit, "movement")
       assert(mov.path, "Path should be calculated")
       assert(#mov.path > 2, "Path should go around obstacle")

       -- Run for 5 seconds (should reach destination)
       for tick = 1, 312 do
           systems.gameloop.tick()
           systems.movement.update()
           systems.collision.update()
       end

       local pos = systems.ecs.get_component(unit, "position")
       assert(pos.x > 5500, "Unit should have reached destination X")

       shutdown_all_systems(systems)
   end
   ```

8. **Implement resource transaction scenario**
   ```lua
   function test_resource_transactions()
       local systems = init_all_systems()

       systems.player.set_slot(0, {type = "human", team = 0})
       systems.resources.set(0, "gold", 500)
       systems.resources.set(0, "lumber", 150)
       systems.resources.set_supply(0, 10)
       systems.resources.set_food(0, 0)

       -- Simulate training a unit (costs resources and food)
       local footman_cost = {gold = 135, lumber = 0}
       local footman_food = 2

       -- Check affordability
       assert(systems.resources.can_afford(0, footman_cost), "Should afford footman")
       assert(systems.resources.can_use_food(0, footman_food), "Should have food")

       -- Spend resources and reserve food
       systems.resources.spend(0, footman_cost)
       systems.resources.use_food(0, footman_food)

       -- Verify
       assert(systems.resources.get(0, "gold") == 365, "Gold after training")
       assert(systems.resources.get_food(0) == 2, "Food after training")

       -- Train 3 more footmen
       for i = 1, 3 do
           systems.resources.spend(0, footman_cost)
           systems.resources.use_food(0, footman_food)
       end

       assert(systems.resources.get(0, "gold") == 365 - 405, "Gold after 4 footmen")
       assert(systems.resources.get_food(0) == 8, "Food after 4 footmen")

       -- Can't train 5th (not enough food)
       assert(not systems.resources.can_use_food(0, footman_food),
           "Should not have food for 5th footman")

       shutdown_all_systems(systems)
   end
   ```

9. **Implement victory condition scenario**
   ```lua
   function test_victory_condition_scenario()
       local systems = init_all_systems()

       -- Two players, different teams
       systems.player.set_slot(0, {type = "human", team = 0})
       systems.player.set_slot(1, {type = "computer", team = 1})

       -- No winner initially
       assert(systems.player.check_victory() == nil, "No winner yet")

       -- Simulate player 1 losing (all buildings destroyed)
       systems.player.set_state(1, "defeated")

       -- Check victory
       local winner = systems.player.check_victory()
       assert(winner == 0, "Player 0 should win")

       shutdown_all_systems(systems)
   end
   ```

10. **Create shutdown helper**
    ```lua
    local function shutdown_all_systems(systems)
        -- Shutdown in reverse order of initialization
        systems.movement.shutdown()
        systems.collision.shutdown()
        systems.pathfinding.shutdown()
        systems.player.shutdown()
        systems.resources.shutdown()
        systems.ecs.shutdown()
        systems.gameloop.shutdown()
    end
    ```

11. **Create integration test runner**
    ```lua
    local function run_integration_tests()
        local tests = {
            {"Two-player melee scenario", test_two_player_melee},
            {"Collision avoidance", test_collision_avoidance},
            {"Pathfinding around obstacles", test_pathfinding_around_obstacles},
            {"Resource transactions", test_resource_transactions},
            {"Victory condition scenario", test_victory_condition_scenario},
        }

        local passed = 0
        local failed = 0

        print("=== Phase 4 Integration Tests ===\n")

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

        print(string.format("\n%d/%d integration tests passed", passed, passed + failed))
        return failed == 0
    end

    if not run_integration_tests() then os.exit(1) end
    ```

---

## Related Documents

- issues/408-phase-4-integration-test.md (parent issue)
- issues/408a-unit-tests-core-systems.md (prerequisite)
- issues/408b-unit-tests-entity-systems.md (prerequisite)
- issues/408c-unit-tests-player-systems.md (prerequisite)
- issues/408e-visual-demo.md (visual demonstration of integration)

---

## Acceptance Criteria

- [x] All runtime systems initialize without errors
- [x] Unit spawning creates entities with correct components
- [x] Two-player melee scenario runs without crashes
- [x] Workers move toward destination over time
- [ ] Collision avoidance prevents unit overlap (needs 405d)
- [ ] Pathfinding routes around obstacles correctly (needs movement.order_move 404c)
- [x] Resource transactions deduct correct amounts
- [x] Victory condition detection works for team elimination
- [x] All systems shutdown cleanly without memory leaks
- [x] Integration tests complete in under 10 seconds

---

## Notes

Integration tests validate system interactions that unit tests cannot:
- Correct initialization order (dependencies)
- Component data flows between systems
- Timing synchronization across subsystems

The scenarios are simplified versions of real WC3 gameplay:
- No combat (that's Phase 5)
- No building construction
- No fog of war
- No trigger execution

These tests prove the Phase 4 foundation is solid before Phase 5 adds complexity.

---

## Implementation Notes

**Completed: 2025-12-29**

### Changes Made

1. **Updated `src/tests/test_phase4_integration.lua`:**
   - Fixed function name detection for actual module APIs
   - Fixed `player.check_victory_conditions` (was `check_victory`)
   - Fixed `collision.shapes_collide` (was `collision.check`)
   - Fixed `player.init_from_w3i`/`init_manual` (was `init_player`)
   - Fixed `init_manual` array format (uses ipairs, needs `{slot = n}`)
   - Updated movement simulation to use ECS-based movement (ecs.update_systems)
   - Added tests for movement.set_path() and path progression
   - All 51 tests now pass

2. **Created debug script `src/tests/debug_victory.lua`:**
   - Standalone script to debug victory condition behavior
   - Useful for investigating player initialization issues

### Test Results

```
=== Module Availability ===   7 passed
=== System Initialization === 5 passed
=== Component Registration === 3 passed (+ 1 info)
=== Entity Spawning ===       7 passed
=== Terrain and Pathfinding === 6 passed
=== Movement System ===       4 passed (+ 1 info)
=== Player System ===         1 passed
=== Resource System ===       4 passed
=== Game Loop Integration === 2 passed
=== Movement Simulation ===   4 passed
=== Resource Transactions === 3 passed
=== Victory Conditions ===    2 passed
=== Collision System ===      3 passed

Total: 51 passed, 0 failed, 0 skipped
```

### Remaining Gaps

The following features are correctly identified as gaps:
- `movement.order_move` (Issue 404c) - needed for pathfinding integration
- `collision.update` (Issue 405d) - needed for movement collision integration

These are intentionally left incomplete as they belong to later sub-issues.


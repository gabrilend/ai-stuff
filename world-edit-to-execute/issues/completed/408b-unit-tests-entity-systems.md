# Issue 408b: Unit Tests - Entity Systems

**Phase:** 4 - Runtime
**Type:** Test
**Priority:** High
**Dependencies:** 408a (core system tests), 404 (movement), 405 (collision)

---

## Current Behavior

No unit tests exist for entity-based runtime systems: movement and collision detection. These systems operate on entities created by ECS and use pathfinding results.

---

## Intended Behavior

Comprehensive unit tests for:
- **Movement (404):** Path following, speed calculations, order processing
- **Collision (405):** Circle/rect collision, spatial queries, collision response

Tests should verify correct integration with ECS and pathfinding.

---

## Suggested Implementation Steps

1. **Create test file**
   ```
   src/tests/
   └── test_phase4_entity.lua
   ```

2. **Implement unit movement initialization test**
   ```lua
   function test_movement_init()
       local ecs = require("runtime.ecs")
       local movement = require("runtime.movement")

       ecs.init()
       movement.init(ecs)

       -- Create a unit with required components
       local unit = ecs.create_entity()
       ecs.add_component(unit, "position", {x = 0, y = 0, facing = 0})
       ecs.add_component(unit, "movement", {
           speed = 270,
           pathing_type = "foot",
           current_order = nil,
           path = nil,
           path_index = 1
       })

       local pos = ecs.get_component(unit, "position")
       local mov = ecs.get_component(unit, "movement")

       assert(pos, "Position component should exist")
       assert(mov, "Movement component should exist")
       assert(mov.speed == 270, "Speed should be 270")

       ecs.shutdown()
   end
   ```

3. **Implement movement order test**
   ```lua
   function test_movement_order()
       local ecs = require("runtime.ecs")
       local movement = require("runtime.movement")
       local pathfinding = require("runtime.pathfinding")

       -- Setup simple terrain
       local terrain = {
           width = 20, height = 20, cell_size = 128,
           is_walkable = function() return true end
       }

       ecs.init()
       pathfinding.build_grid(terrain)
       movement.init(ecs, pathfinding)

       -- Create unit
       local unit = ecs.create_entity()
       ecs.add_component(unit, "position", {x = 0, y = 0, facing = 0})
       ecs.add_component(unit, "movement", {
           speed = 270,
           pathing_type = "foot"
       })

       -- Issue move order
       movement.order_move(unit, 500, 500)

       local mov = ecs.get_component(unit, "movement")
       assert(mov.current_order, "Move order should be set")
       assert(mov.current_order.type == "move", "Order type should be 'move'")
       assert(mov.path, "Path should be calculated")

       ecs.shutdown()
   end
   ```

4. **Implement movement execution test**
   ```lua
   function test_movement_execution()
       local ecs = require("runtime.ecs")
       local movement = require("runtime.movement")
       local pathfinding = require("runtime.pathfinding")
       local gameloop = require("runtime.gameloop")

       -- Setup
       local terrain = {
           width = 20, height = 20, cell_size = 128,
           is_walkable = function() return true end
       }

       ecs.init()
       gameloop.init()
       pathfinding.build_grid(terrain)
       movement.init(ecs, pathfinding)

       -- Create unit at origin
       local unit = ecs.create_entity()
       ecs.add_component(unit, "position", {x = 0, y = 0, facing = 0})
       ecs.add_component(unit, "movement", {speed = 270, pathing_type = "foot"})

       -- Order move to (100, 0) - straight line
       movement.order_move(unit, 100, 0)

       -- Simulate 1 second of game time (62 ticks at 16ms each)
       for i = 1, 62 do
           gameloop.tick()
           movement.update()
       end

       local pos = ecs.get_component(unit, "position")
       -- At 270 units/sec, should have moved ~270 units
       -- But destination is only 100 units away, so should be at destination
       assert(pos.x >= 95 and pos.x <= 105,
           "Unit should be near destination X: " .. pos.x)
       assert(pos.y >= -5 and pos.y <= 5,
           "Unit should be near destination Y: " .. pos.y)

       ecs.shutdown()
       gameloop.shutdown()
   end
   ```

5. **Implement facing calculation test**
   ```lua
   function test_movement_facing()
       local ecs = require("runtime.ecs")
       local movement = require("runtime.movement")

       ecs.init()
       movement.init(ecs)

       local unit = ecs.create_entity()
       ecs.add_component(unit, "position", {x = 0, y = 0, facing = 0})
       ecs.add_component(unit, "movement", {speed = 270, pathing_type = "foot"})

       -- Calculate facing toward different directions
       local facing_right = movement.calculate_facing(0, 0, 100, 0)
       assert(math.abs(facing_right - 0) < 0.1, "Facing right should be ~0 radians")

       local facing_up = movement.calculate_facing(0, 0, 0, 100)
       assert(math.abs(facing_up - math.pi/2) < 0.1, "Facing up should be ~π/2 radians")

       local facing_left = movement.calculate_facing(0, 0, -100, 0)
       assert(math.abs(facing_left - math.pi) < 0.1 or math.abs(facing_left + math.pi) < 0.1,
           "Facing left should be ~±π radians")

       ecs.shutdown()
   end
   ```

6. **Implement collision circle test**
   ```lua
   function test_collision_circles()
       local collision = require("runtime.collision")

       -- Overlapping circles
       local overlap = collision.circles_collide(0, 0, 32, 50, 0, 32)
       assert(overlap, "Circles with combined radius 64, distance 50 should collide")

       -- Non-overlapping circles
       local no_overlap = collision.circles_collide(0, 0, 32, 100, 0, 32)
       assert(not no_overlap, "Circles with combined radius 64, distance 100 should not collide")

       -- Touching circles (edge case)
       local touching = collision.circles_collide(0, 0, 32, 64, 0, 32)
       assert(touching, "Circles exactly touching should count as collision")

       -- Same center (fully overlapping)
       local same_center = collision.circles_collide(100, 100, 50, 100, 100, 50)
       assert(same_center, "Same center circles should collide")
   end
   ```

7. **Implement collision rect test**
   ```lua
   function test_collision_rects()
       local collision = require("runtime.collision")

       -- Overlapping rects
       local overlap = collision.rects_collide(
           0, 0, 100, 100,      -- Rect 1: 0,0 to 100,100
           50, 50, 150, 150     -- Rect 2: 50,50 to 150,150
       )
       assert(overlap, "Overlapping rectangles should collide")

       -- Non-overlapping rects
       local no_overlap = collision.rects_collide(
           0, 0, 100, 100,
           200, 0, 300, 100
       )
       assert(not no_overlap, "Non-overlapping rectangles should not collide")

       -- Adjacent rects (touching edge)
       local adjacent = collision.rects_collide(
           0, 0, 100, 100,
           100, 0, 200, 100
       )
       -- Adjacent should NOT collide (WC3 semantics)
       assert(not adjacent, "Adjacent rectangles should not collide")
   end
   ```

8. **Implement spatial query test**
   ```lua
   function test_collision_spatial_query()
       local ecs = require("runtime.ecs")
       local collision = require("runtime.collision")

       ecs.init()
       collision.init(ecs)

       -- Create several entities at known positions
       local e1 = ecs.create_entity()
       ecs.add_component(e1, "position", {x = 0, y = 0})
       ecs.add_component(e1, "collision", {radius = 32, type = "unit"})

       local e2 = ecs.create_entity()
       ecs.add_component(e2, "position", {x = 50, y = 0})
       ecs.add_component(e2, "collision", {radius = 32, type = "unit"})

       local e3 = ecs.create_entity()
       ecs.add_component(e3, "position", {x = 200, y = 0})
       ecs.add_component(e3, "collision", {radius = 32, type = "unit"})

       collision.rebuild_spatial_index()

       -- Query radius around origin
       local nearby = collision.query_radius(0, 0, 100, {"unit"})
       assert(#nearby == 2, "Should find 2 units within radius 100 of origin")

       -- Query larger radius
       local all = collision.query_radius(100, 0, 200, {"unit"})
       assert(#all == 3, "Should find all 3 units within radius 200 of center")

       -- Query rect
       local in_rect = collision.query_rect(-10, -10, 60, 10, {"unit"})
       assert(#in_rect == 2, "Should find 2 units in rect")

       ecs.shutdown()
   end
   ```

9. **Implement movement-collision integration test**
   ```lua
   function test_movement_collision_integration()
       local ecs = require("runtime.ecs")
       local movement = require("runtime.movement")
       local collision = require("runtime.collision")
       local pathfinding = require("runtime.pathfinding")

       -- Setup
       local terrain = {
           width = 20, height = 20, cell_size = 128,
           is_walkable = function() return true end
       }

       ecs.init()
       pathfinding.build_grid(terrain)
       collision.init(ecs)
       movement.init(ecs, pathfinding, collision)

       -- Create two units that will collide
       local u1 = ecs.create_entity()
       ecs.add_component(u1, "position", {x = 0, y = 0, facing = 0})
       ecs.add_component(u1, "movement", {speed = 270, pathing_type = "foot"})
       ecs.add_component(u1, "collision", {radius = 32, type = "unit"})

       local u2 = ecs.create_entity()
       ecs.add_component(u2, "position", {x = 100, y = 0, facing = 0})
       ecs.add_component(u2, "movement", {speed = 0, pathing_type = "foot"})  -- Stationary
       ecs.add_component(u2, "collision", {radius = 32, type = "unit"})

       -- Order u1 to move through u2's position
       movement.order_move(u1, 200, 0)

       -- Simulate movement
       for i = 1, 20 do
           movement.update()
           collision.update()
       end

       local pos1 = ecs.get_component(u1, "position")
       local pos2 = ecs.get_component(u2, "position")

       -- u1 should not have passed through u2
       -- (Either stopped or path around)
       local distance = math.sqrt((pos1.x - pos2.x)^2 + (pos1.y - pos2.y)^2)
       assert(distance >= 60,
           "Units should maintain separation: distance = " .. distance)

       ecs.shutdown()
   end
   ```

10. **Create test runner**
    ```lua
    local function run_tests()
        local tests = {
            {"Movement init", test_movement_init},
            {"Movement order", test_movement_order},
            {"Movement execution", test_movement_execution},
            {"Movement facing", test_movement_facing},
            {"Collision circles", test_collision_circles},
            {"Collision rects", test_collision_rects},
            {"Collision spatial query", test_collision_spatial_query},
            {"Movement-collision integration", test_movement_collision_integration},
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
- issues/408a-unit-tests-core-systems.md (prerequisite)
- issues/404-create-unit-movement-system.md
- issues/405-implement-basic-collision-detection.md
- issues/408c-unit-tests-player-systems.md (sibling - can run in parallel)

---

## Acceptance Criteria

- [x] Movement initialization test passes
- [x] Movement order test passes (order issued, path calculated)
- [x] Movement execution test passes (unit reaches destination)
- [x] Movement facing calculation test passes (correct angles)
- [x] Circle collision test passes (overlap/no-overlap/touching)
- [x] Rectangle collision test passes (overlap/no-overlap/adjacent)
- [x] Spatial query test passes (radius and rect queries)
- [x] Movement-collision integration test passes (units don't pass through)
- [x] All tests complete in under 2 seconds

---

## Notes

Movement tests require ECS and pathfinding to be working (from 408a). The integration with collision is optional at the unit test level but should be tested.

Collision detection uses the spatial hash grid from issue 405. Tests should verify the grid is rebuilt when entities move.

WC3-specific considerations:
- Unit collision radii vary by unit type (typically 16-48 game units)
- Flying units use separate collision layer
- Buildings have rectangular collision

---

## Implementation Notes

**Completed:** 2025-12-30

### Test File Created

Created `src/tests/test_phase4_entity.lua` with 26 tests validating all acceptance criteria:

| Section | Tests | Description |
|---------|-------|-------------|
| AC1: Movement Initialization | 5 | Position/movement component attachment |
| AC2: Movement Orders | 4 | Path setting, waypoints, is_moving state |
| AC3: Movement Execution | 3 | Unit reaches destination after ECS updates |
| AC4: Facing Calculation | 2 | Facing right=0, facing up=π/2 |
| AC5: Circle Collision | 4 | Overlap, separate, touching, same center |
| AC6: Rectangle Collision | 3 | Overlap, separate, adjacent |
| AC7: Spatial Queries | 2 | query_radius, query_rect find entities |
| AC8: Movement-Collision | 2 | can_move_to blocks/allows movement |
| AC9: Timing | 1 | Completes under 2 seconds |

### Existing Test Coverage

The detailed test suites already implemented in previous issues provide extensive coverage:

- `test_movement_core.lua`: 90 tests - speeds, component creation, interpolation
- `test_movement_path.lua`: 49 tests - path following, waypoint progression, facing
- `test_orders.lua`: Order types, queuing, callbacks
- `test_collision_shapes.lua`: 99 tests - circle, rect, circle-rect, point-in-shape
- `test_collision_queries.lua`: Spatial hash queries, layer filtering
- `test_movement_collision.lua`: can_move_to, resolve_overlap, trigger zones

### Usage

```bash
# Run acceptance criteria validation
lua src/tests/test_phase4_entity.lua

# Run comprehensive Phase 4 tests
./issues/completed/demos/run_phase4.sh -a
```

All 26 acceptance tests pass.

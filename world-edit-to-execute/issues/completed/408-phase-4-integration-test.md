# Issue 408: Phase 4 Integration Test

**Phase:** 4 - Runtime
**Type:** Test
**Priority:** Medium
**Dependencies:** 401-407 (all Phase 4 issues)

---

## Current Behavior

No integration test exists for Phase 4 runtime systems.

---

## Intended Behavior

A comprehensive integration test that:
- Verifies all Phase 4 systems work together
- Demonstrates basic game execution from a loaded map
- Tests entity spawning, movement, and collision
- Validates resource tracking and player states
- Produces measurable output for validation

---

## Suggested Implementation Steps

1. **Create integration test**
   ```
   src/tests/phase4_test.lua
   ```

2. **Test game loop initialization**
   ```lua
   -- Test: Game loop runs at correct tick rate
   function test_game_loop_timing()
       gameloop.init()

       local start_tick = gameloop.get_tick()
       local start_time = os.clock()

       -- Simulate 1 second of game time
       for i = 1, 100 do
           gameloop.update(0.01)  -- 10ms per frame
       end

       local elapsed_ticks = gameloop.get_tick() - start_tick
       local expected_ticks = 62  -- ~62.5 ticks per second

       assert(math.abs(elapsed_ticks - expected_ticks) <= 2,
           "Tick rate incorrect: " .. elapsed_ticks)
   end
   ```

3. **Test entity creation and components**
   ```lua
   function test_ecs_basic()
       local entity = ecs.create_entity()
       assert(entity, "Entity creation failed")

       ecs.add_component(entity, "position", {x = 100, y = 200})
       ecs.add_component(entity, "movement", {speed = 270})

       local pos = ecs.get_component(entity, "position")
       assert(pos.x == 100, "Position X incorrect")
       assert(pos.y == 200, "Position Y incorrect")

       ecs.destroy_entity(entity)
       assert(ecs.get_component(entity, "position") == nil, "Entity not destroyed")
   end
   ```

4. **Test pathfinding**
   ```lua
   function test_pathfinding()
       -- Create simple test grid
       local terrain = create_test_terrain(32, 32)

       -- Add obstacle
       terrain:set_unwalkable(15, 15)
       terrain:set_unwalkable(15, 16)
       terrain:set_unwalkable(16, 15)
       terrain:set_unwalkable(16, 16)

       pathfinding.build_grid(terrain)

       -- Find path around obstacle
       local path = pathfinding.find_path(
           {x = 10, y = 15},
           {x = 20, y = 15},
           "foot"
       )

       assert(path, "No path found")
       assert(#path > 2, "Path should go around obstacle")

       -- Verify path doesn't go through obstacle
       for _, waypoint in ipairs(path) do
           local gx = pathfinding.world_to_grid(waypoint.x, waypoint.y)
           assert(terrain:is_walkable(gx.x, gx.y), "Path goes through obstacle")
       end
   end
   ```

5. **Test unit movement**
   ```lua
   function test_unit_movement()
       local unit = ecs.create_entity()
       ecs.add_component(unit, "position", {x = 0, y = 0, facing = 0})
       ecs.add_component(unit, "movement", {speed = 270, pathing_type = "foot"})

       movement.order_move(unit, 100, 0)

       -- Simulate 1 second
       for i = 1, 62 do
           gameloop.tick()
       end

       local pos = ecs.get_component(unit, "position")
       -- Should have moved ~270 units
       assert(pos.x > 250, "Unit didn't move far enough: " .. pos.x)
       assert(pos.x < 280, "Unit moved too far: " .. pos.x)
   end
   ```

6. **Test collision detection**
   ```lua
   function test_collision()
       local unit1 = create_test_unit(0, 0, 32)
       local unit2 = create_test_unit(50, 0, 32)

       -- Units 50 apart with radius 32 each - should collide
       local collides = collision.circles_collide(0, 0, 32, 50, 0, 32)
       assert(collides, "Should detect collision")

       -- Units 100 apart - should not collide
       local no_collide = collision.circles_collide(0, 0, 32, 100, 0, 32)
       assert(not no_collide, "Should not detect collision")

       -- Query test
       local nearby = collision.query_radius(25, 0, 50, {"unit"})
       assert(#nearby == 2, "Should find 2 nearby units")
   end
   ```

7. **Test resources**
   ```lua
   function test_resources()
       resources.init_player(0)
       resources.set(0, "gold", 500)
       resources.set(0, "lumber", 150)
       resources.set(0, "food_cap", 12)

       assert(resources.get(0, "gold") == 500)

       -- Test spending
       local can_afford = resources.can_afford(0, {gold = 100, lumber = 50})
       assert(can_afford, "Should be able to afford")

       resources.spend(0, {gold = 100, lumber = 50})
       assert(resources.get(0, "gold") == 400)
       assert(resources.get(0, "lumber") == 100)

       -- Test food
       assert(resources.can_afford(0, {food = 5}), "Should afford food")
       resources.spend(0, {food = 5})
       assert(resources.get(0, "food_used") == 5)
   end
   ```

8. **Test player management**
   ```lua
   function test_players()
       player.init_from_w3i(test_w3i_data)

       local p0 = player.get(0)
       assert(p0, "Player 0 should exist")
       assert(p0.state == "active")

       -- Test alliances
       player.set_alliance(0, 1, "passive", true)
       player.set_alliance(1, 0, "passive", true)
       assert(player.is_ally(0, 1), "Players should be allies")

       player.set_alliance(0, 2, "passive", false)
       assert(player.is_enemy(0, 2), "Players should be enemies")

       -- Test defeat
       player.defeat(1)
       assert(player.get(1).state == "defeated")
   end
   ```

9. **Full integration scenario**
   ```lua
   function test_full_scenario()
       -- Load a test map
       local map = Map.load("assets/test_map.w3x")

       -- Initialize all systems
       gameloop.init()
       ecs.init()
       player.init_from_w3i(map.info)
       resources.init_all_players()
       pathfinding.build_grid(map.terrain)

       -- Spawn a unit
       local unit = spawn_unit("hfoo", 0, {x = 0, y = 0})

       -- Give move order
       movement.order_move(unit, 500, 500)

       -- Run game for 5 simulated seconds
       for i = 1, 5 * 62 do
           gameloop.tick()
       end

       -- Verify unit moved
       local pos = ecs.get_component(unit, "position")
       assert(pos.x > 400, "Unit should have moved toward target")

       print("Full integration test PASSED")
   end
   ```

10. **Create visual demo**
    ```
    issues/completed/demos/phase4_demo.lua
    ```
    - Print game state each second
    - Show unit positions
    - Show resource counts
    - Demonstrate pathfinding visually (ASCII grid)

---

## Acceptance Criteria

- [ ] Game loop timing test passes
- [ ] ECS create/destroy/component tests pass
- [ ] Pathfinding obstacle avoidance test passes
- [ ] Unit movement test passes
- [ ] Collision detection tests pass
- [ ] Resource management tests pass
- [ ] Player/alliance tests pass
- [ ] Full integration scenario completes
- [ ] Visual demo produces meaningful output
- [ ] All tests run in under 5 seconds

---

## Test Coverage Matrix

| System | Unit Tests | Integration |
|--------|-----------|-------------|
| Game Loop (401) | ✓ | ✓ |
| ECS (402) | ✓ | ✓ |
| Pathfinding (403) | ✓ | ✓ |
| Movement (404) | ✓ | ✓ |
| Collision (405) | ✓ | ✓ |
| Resources (406) | ✓ | ✓ |
| Players (407) | ✓ | ✓ |

---

## Notes

The Phase 4 integration test is crucial for validating that all runtime
systems work together. The full scenario test should simulate a minimal
but complete game state.

Consider creating a "test map" asset specifically for integration testing
with known, predictable structure.

The demo should be runnable via the phase demo runner:
```bash
./run-demo.sh 4
```

Timing is critical for the game loop - use high-resolution timers if
available, and allow some tolerance in timing assertions.

---

## Sub-Issue Analysis

*Generated by Claude Code on 2025-12-19 03:18*

I've read the issue. Let me analyze whether it should be split into sub-issues.

## Analysis

This issue is already quite comprehensive and well-structured, but it **would benefit from splitting** for several reasons:

1. **Size**: 10 distinct implementation steps covering 7 different systems
2. **Dependencies**: The full integration test depends on all unit tests passing first
3. **Logical groupings**: There's a clear separation between unit tests per system, integration tests, and the visual demo

## Suggested Sub-Issues

### 408a-unit-tests-core-systems
**Description:** Unit tests for game loop (401), ECS (402), and pathfinding (403) - the foundational systems that other tests depend on.

**Covers:**
- Step 2: Game loop timing test
- Step 3: ECS basic operations test  
- Step 4: Pathfinding obstacle avoidance test

**Dependencies:** None (first to implement)

---

### 408b-unit-tests-entity-systems
**Description:** Unit tests for movement (404), collision (405) - systems that operate on entities.

**Covers:**
- Step 5: Unit movement test
- Step 6: Collision detection tests

**Dependencies:** 408a (needs ECS and pathfinding working)

---

### 408c-unit-tests-player-systems
**Description:** Unit tests for resources (406) and player management (407).

**Covers:**
- Step 7: Resource management tests
- Step 8: Player/alliance tests

**Dependencies:** None (can run in parallel with 408b)

---

### 408d-integration-scenario
**Description:** Full integration scenario that loads a test map and validates all systems working together.

**Covers:**
- Step 9: Full integration scenario
- Creating/using test_map.w3x asset

**Dependencies:** 408a, 408b, 408c (all unit tests must pass first)

---

### 408e-visual-demo
**Description:** Create the visual demo for phase demo runner, with ASCII visualization of game state.

**Covers:**
- Step 10: Visual demo creation
- Integration with run-demo.sh
- ASCII grid pathfinding visualization

**Dependencies:** 408d (demo should showcase working integration)

---

## Dependency Graph

```
408a (core tests) ──┬──▶ 408b (entity tests) ──┐
                    │                           ├──▶ 408d (integration) ──▶ 408e (demo)
                    └──▶ 408c (player tests) ───┘
```

## Alternative: Keep As-Is

If you prefer not to split, the issue is still implementable as a single unit. The steps are sequential and the test file could be written incrementally. However, splitting allows:
- Parallel work on 408b and 408c
- Clearer progress tracking (5 checkpoints vs 1)
- Easier debugging if specific system tests fail

**Recommendation:** Split into sub-issues. The logical groupings are clean, and tracking progress across 7 system integrations benefits from granularity.

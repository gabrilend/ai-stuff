--[[
Phase 4 Core Systems Unit Tests

Tests the foundational runtime systems: game loop, ECS, and pathfinding.
These tests validate the interfaces and behavior before Phase 5 integration.

Run with: lua src/tests/test_phase4_core.lua
]]

-- {{{ Setup package path
-- When run from project root: lua src/tests/test_phase4_core.lua
-- When run from src/tests: lua test_phase4_core.lua
local script_path = debug.getinfo(1, "S").source:match("@(.*)")
local script_dir = script_path and script_path:match("(.*/)")

-- Detect project root based on script location
local project_root
if script_dir then
    -- Running from project root: script_dir = "src/tests/"
    project_root = script_dir:gsub("src/tests/$", "")
    if project_root == script_dir then
        -- Running from src/tests directory
        project_root = script_dir .. "../../"
    end
else
    -- Fallback: assume running from project root
    project_root = ""
end

-- Add src/ to package path for module resolution
package.path = project_root .. "src/?.lua;" ..
               project_root .. "src/?/init.lua;" ..
               package.path
-- }}}

-- {{{ Test infrastructure
local passed = 0
local failed = 0
local test_results = {}

-- {{{ assert_eq
local function assert_eq(actual, expected, msg)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s",
            msg or "Assertion failed",
            tostring(expected),
            tostring(actual)))
    end
end
-- }}}

-- {{{ assert_true
local function assert_true(value, msg)
    if not value then
        error(msg or "Expected true, got false/nil")
    end
end
-- }}}

-- {{{ assert_false
local function assert_false(value, msg)
    if value then
        error(msg or "Expected false/nil, got true")
    end
end
-- }}}

-- {{{ assert_nil
local function assert_nil(value, msg)
    if value ~= nil then
        error(string.format("%s: expected nil, got %s",
            msg or "Assertion failed",
            tostring(value)))
    end
end
-- }}}

-- {{{ assert_near
local function assert_near(actual, expected, tolerance, msg)
    tolerance = tolerance or 0.001
    if math.abs(actual - expected) > tolerance then
        error(string.format("%s: expected ~%s (±%s), got %s",
            msg or "Assertion failed",
            tostring(expected),
            tostring(tolerance),
            tostring(actual)))
    end
end
-- }}}

-- {{{ run_test
local function run_test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        print("  PASS: " .. name)
        passed = passed + 1
        test_results[#test_results + 1] = {name = name, passed = true}
    else
        print("  FAIL: " .. name)
        print("        " .. tostring(err))
        failed = failed + 1
        test_results[#test_results + 1] = {name = name, passed = false, error = err}
    end
end
-- }}}
-- }}}

-- ============================================================================
-- GAME LOOP TESTS
-- ============================================================================

print("\n=== Game Loop Tests ===")

-- {{{ test_gameloop_reset
run_test("gameloop.reset() initializes state", function()
    local gameloop = require("runtime.gameloop")
    gameloop.reset()

    assert_eq(gameloop.get_tick(), 0, "Tick should be 0 after reset")
    assert_eq(gameloop.get_time(), 0, "Time should be 0 after reset")
    assert_eq(gameloop.get_speed(), 1.0, "Speed should be 1.0 after reset")
    assert_false(gameloop.is_paused(), "Should not be paused after reset")
end)
-- }}}

-- {{{ test_gameloop_tick_rate
run_test("gameloop runs at 62.5 Hz tick rate", function()
    local gameloop = require("runtime.gameloop")
    gameloop.reset()

    -- Simulate 1 second of game time
    local dt_per_frame = 0.01  -- 10ms frames (100 FPS)
    local frames = 100         -- 100 frames = 1 second

    for i = 1, frames do
        gameloop.update(dt_per_frame)
    end

    local elapsed_ticks = gameloop.get_tick()
    local expected_ticks = 62  -- 62.5 ticks per second, floored

    -- Allow ±2 ticks tolerance for accumulator edge cases
    assert_true(math.abs(elapsed_ticks - expected_ticks) <= 2,
        string.format("Tick rate incorrect: got %d, expected ~%d", elapsed_ticks, expected_ticks))
end)
-- }}}

-- {{{ test_gameloop_pause_resume
run_test("gameloop.pause() stops tick advancement", function()
    local gameloop = require("runtime.gameloop")
    gameloop.reset()

    -- Advance a bit
    gameloop.update(0.1)
    local tick_before = gameloop.get_tick()

    -- Pause and try to advance
    gameloop.pause()
    assert_true(gameloop.is_paused(), "Should be paused after pause()")

    gameloop.update(1.0)  -- 1 second while paused
    local tick_after_pause = gameloop.get_tick()

    assert_eq(tick_before, tick_after_pause, "Ticks should not advance while paused")

    -- Resume and verify advancement
    gameloop.resume()
    assert_false(gameloop.is_paused(), "Should not be paused after resume()")

    gameloop.update(0.1)
    assert_true(gameloop.get_tick() > tick_after_pause, "Ticks should advance after resume")
end)
-- }}}

-- {{{ test_gameloop_speed
run_test("gameloop.set_speed() affects tick rate", function()
    local gameloop = require("runtime.gameloop")
    gameloop.reset()

    -- Run at double speed
    gameloop.set_speed(2.0)
    assert_eq(gameloop.get_speed(), 2.0, "Speed should be 2.0")

    -- Simulate 0.5 seconds real time = 1 second game time at 2x speed
    for i = 1, 50 do
        gameloop.update(0.01)  -- 50 frames * 10ms = 500ms real time
    end

    local ticks = gameloop.get_tick()
    -- At 2x speed, 0.5 real seconds = 1 game second = ~62 ticks
    assert_true(ticks >= 60 and ticks <= 65,
        string.format("Expected ~62 ticks at 2x speed, got %d", ticks))
end)
-- }}}

-- {{{ test_gameloop_speed_clamp
run_test("gameloop.set_speed() clamps to valid range", function()
    local gameloop = require("runtime.gameloop")
    gameloop.reset()

    -- Try to set below minimum
    gameloop.set_speed(0.1)
    assert_eq(gameloop.get_speed(), gameloop.MIN_SPEED, "Speed should clamp to MIN_SPEED")

    -- Try to set above maximum
    gameloop.set_speed(10.0)
    assert_eq(gameloop.get_speed(), gameloop.MAX_SPEED, "Speed should clamp to MAX_SPEED")
end)
-- }}}

-- {{{ test_gameloop_tick_callback
run_test("gameloop tick callbacks execute each tick", function()
    local gameloop = require("runtime.gameloop")
    gameloop.reset()

    local callback_count = 0
    local callback_id = gameloop.add_tick_callback(function(tick, time)
        callback_count = callback_count + 1
    end)

    -- Run a few ticks
    gameloop.update(0.05)  -- Should be ~3 ticks

    assert_true(callback_count >= 2 and callback_count <= 4,
        string.format("Expected 2-4 callbacks, got %d", callback_count))

    -- Remove callback and verify no more calls
    local count_before_remove = callback_count
    gameloop.remove_tick_callback(callback_id)
    gameloop.update(0.05)

    assert_eq(callback_count, count_before_remove, "Callback should not fire after removal")
end)
-- }}}

-- {{{ test_gameloop_max_delta_cap
run_test("gameloop caps delta time to prevent spiral of death", function()
    local gameloop = require("runtime.gameloop")
    gameloop.reset()

    -- Simulate a huge lag spike (5 seconds)
    local ticks = gameloop.update(5.0)

    -- MAX_DELTA_TIME is 0.25, so at most ~15 ticks should process
    assert_true(ticks <= 20,
        string.format("Should cap ticks after lag spike, got %d", ticks))
end)
-- }}}

-- ============================================================================
-- ECS TESTS
-- ============================================================================

print("\n=== ECS Tests ===")

-- {{{ test_ecs_entity_lifecycle
run_test("ecs.create_entity/destroy_entity lifecycle", function()
    local ecs = require("runtime.ecs")
    -- Use reset() to preserve cleanup hooks (don't use clear_hooks())
    ecs.reset()

    -- Create entity
    local entity = ecs.create_entity()
    assert_true(entity, "Entity creation should return ID")
    assert_true(ecs.entity_exists(entity), "Entity should exist after creation")

    -- Destroy entity
    local destroyed = ecs.destroy_entity(entity)
    assert_true(destroyed, "Destroy should return true for existing entity")
    assert_false(ecs.entity_exists(entity), "Entity should not exist after destruction")

    -- Destroy again should return false
    local destroyed_again = ecs.destroy_entity(entity)
    assert_false(destroyed_again, "Destroy should return false for non-existent entity")
end)
-- }}}

-- {{{ test_ecs_entity_count
run_test("ecs.get_entity_count tracks active entities", function()
    local ecs = require("runtime.ecs")
    ecs.reset()

    assert_eq(ecs.get_entity_count(), 0, "Count should be 0 initially")

    local e1 = ecs.create_entity()
    assert_eq(ecs.get_entity_count(), 1, "Count should be 1 after create")

    local e2 = ecs.create_entity()
    local e3 = ecs.create_entity()
    assert_eq(ecs.get_entity_count(), 3, "Count should be 3 after creating more")

    ecs.destroy_entity(e2)
    assert_eq(ecs.get_entity_count(), 2, "Count should be 2 after destroy")

    ecs.destroy_entity(e1)
    ecs.destroy_entity(e3)
    assert_eq(ecs.get_entity_count(), 0, "Count should be 0 after destroying all")
end)
-- }}}

-- {{{ test_ecs_component_registration
run_test("ecs.register_component registers types", function()
    local ecs = require("runtime.ecs")
    ecs.reset()

    -- Register a component type
    ecs.register_component("test_position", {x = 0, y = 0, z = 0})

    local defaults = ecs.get_component_defaults("test_position")
    assert_true(defaults, "Defaults should exist after registration")
    assert_eq(defaults.x, 0, "Default x should be 0")
end)
-- }}}

-- {{{ test_ecs_component_add_get
run_test("ecs.add_component/get_component works", function()
    local ecs = require("runtime.ecs")
    ecs.reset()

    ecs.register_component("position", {x = 0, y = 0})
    local entity = ecs.create_entity()

    -- Add component with data
    local comp = ecs.add_component(entity, "position", {x = 100, y = 200})
    assert_true(comp, "add_component should return instance")
    assert_eq(comp.x, 100, "Component x should be 100")
    assert_eq(comp.y, 200, "Component y should be 200")

    -- Get component
    local retrieved = ecs.get_component(entity, "position")
    assert_true(retrieved, "get_component should return instance")
    assert_eq(retrieved.x, 100, "Retrieved x should be 100")

    -- Modify and verify persistence
    retrieved.x = 150
    local retrieved2 = ecs.get_component(entity, "position")
    assert_eq(retrieved2.x, 150, "Modification should persist")
end)
-- }}}

-- {{{ test_ecs_component_has
run_test("ecs.has_component checks presence", function()
    local ecs = require("runtime.ecs")
    ecs.reset()

    ecs.register_component("health", {current = 100, max = 100})
    local entity = ecs.create_entity()

    assert_false(ecs.has_component(entity, "health"), "Should not have component before add")

    ecs.add_component(entity, "health", {current = 50})
    assert_true(ecs.has_component(entity, "health"), "Should have component after add")
end)
-- }}}

-- {{{ test_ecs_component_remove
run_test("ecs.remove_component removes components", function()
    local ecs = require("runtime.ecs")
    ecs.reset()

    ecs.register_component("movement", {speed = 270})
    local entity = ecs.create_entity()

    ecs.add_component(entity, "movement", {speed = 350})
    assert_true(ecs.has_component(entity, "movement"), "Should have component")

    local removed = ecs.remove_component(entity, "movement")
    assert_true(removed, "Remove should return true")
    assert_false(ecs.has_component(entity, "movement"), "Should not have component after remove")
    assert_nil(ecs.get_component(entity, "movement"), "Get should return nil after remove")
end)
-- }}}

-- {{{ test_ecs_component_defaults
run_test("ecs components inherit defaults via metatable", function()
    local ecs = require("runtime.ecs")
    ecs.reset()

    ecs.register_component("stats", {hp = 100, mp = 50, armor = 5})
    local entity = ecs.create_entity()

    -- Add with only partial data
    local comp = ecs.add_component(entity, "stats", {hp = 80})

    assert_eq(comp.hp, 80, "Overridden value should be 80")
    assert_eq(comp.mp, 50, "Default mp should be 50")
    assert_eq(comp.armor, 5, "Default armor should be 5")
end)
-- }}}

-- {{{ test_ecs_entity_destroy_cleans_components
run_test("ecs.destroy_entity cleans up components", function()
    local ecs = require("runtime.ecs")
    -- NOTE: We do NOT call clear_hooks() here because we need the component
    -- cleanup hook (registered on module load) to run when entities are destroyed.
    -- clear_all() resets data but preserves hooks.
    ecs.reset()

    ecs.register_component("cleanup_test", {value = 0})
    local entity = ecs.create_entity()
    ecs.add_component(entity, "cleanup_test", {value = 42})

    assert_true(ecs.has_component(entity, "cleanup_test"), "Should have component before destroy")

    -- Get component count before destruction
    local count_before = ecs.query_count("cleanup_test")
    assert_eq(count_before, 1, "Should have 1 entity with component before destroy")

    ecs.destroy_entity(entity)

    -- After destruction, the entity no longer exists
    assert_false(ecs.entity_exists(entity), "Entity should not exist after destruction")

    -- Component cleanup hook should have removed the component from storage
    -- so the query should find no entities
    local count_after = ecs.query_count("cleanup_test")
    assert_eq(count_after, 0, "No entities should have component after destroy")
end)
-- }}}

-- {{{ test_ecs_query_single
run_test("ecs.query single component iteration", function()
    local ecs = require("runtime.ecs")
    ecs.reset()

    ecs.register_component("queryable", {value = 0})

    local e1 = ecs.create_entity()
    local e2 = ecs.create_entity()
    local e3 = ecs.create_entity()

    ecs.add_component(e1, "queryable", {value = 1})
    ecs.add_component(e2, "queryable", {value = 2})
    -- e3 has no component

    local found = {}
    for entity_id, comp in ecs.query("queryable") do
        found[entity_id] = comp.value
    end

    assert_eq(found[e1], 1, "e1 should have value 1")
    assert_eq(found[e2], 2, "e2 should have value 2")
    assert_nil(found[e3], "e3 should not be in results")
end)
-- }}}

-- {{{ test_ecs_query_multi
run_test("ecs.query multi-component intersection", function()
    local ecs = require("runtime.ecs")
    ecs.reset()

    ecs.register_component("pos", {x = 0, y = 0})
    ecs.register_component("vel", {vx = 0, vy = 0})

    local e1 = ecs.create_entity()
    ecs.add_component(e1, "pos", {x = 10, y = 20})
    ecs.add_component(e1, "vel", {vx = 1, vy = 2})

    local e2 = ecs.create_entity()
    ecs.add_component(e2, "pos", {x = 30, y = 40})
    -- e2 has no velocity

    local e3 = ecs.create_entity()
    ecs.add_component(e3, "pos", {x = 50, y = 60})
    ecs.add_component(e3, "vel", {vx = 5, vy = 6})

    local movers = {}
    for entity_id, pos, vel in ecs.query("pos", "vel") do
        movers[entity_id] = {pos = pos, vel = vel}
    end

    assert_true(movers[e1], "e1 should be in results (has both)")
    assert_nil(movers[e2], "e2 should not be in results (missing vel)")
    assert_true(movers[e3], "e3 should be in results (has both)")

    assert_eq(movers[e1].pos.x, 10, "e1 pos.x should be 10")
    assert_eq(movers[e1].vel.vx, 1, "e1 vel.vx should be 1")
end)
-- }}}

-- {{{ test_ecs_query_count
run_test("ecs.query_count counts matching entities", function()
    local ecs = require("runtime.ecs")
    ecs.reset()

    ecs.register_component("countable", {n = 0})

    for i = 1, 5 do
        local e = ecs.create_entity()
        ecs.add_component(e, "countable", {n = i})
    end

    local count = ecs.query_count("countable")
    assert_eq(count, 5, "Should count 5 entities")
end)
-- }}}

-- ============================================================================
-- PATHFINDING TESTS
-- ============================================================================

print("\n=== Pathfinding Tests ===")

-- {{{ Mock terrain helper
-- Creates a mock terrain object for testing
-- Uses deep water to simulate blocked tiles (WC3 style)
local function make_mock_terrain(width, height, blocked_tiles)
    blocked_tiles = blocked_tiles or {}

    local blocked_set = {}
    for _, tile in ipairs(blocked_tiles) do
        local key = tile[1] .. "," .. tile[2]
        blocked_set[key] = true
    end

    return {
        width = width,
        height = height,
        offset_x = 0,
        offset_y = 0,
        get_tile = function(self, x, y)
            if x < 0 or x >= width or y < 0 or y >= height then
                return nil
            end

            local key = x .. "," .. y
            local is_blocked = blocked_set[key]

            -- WC3 blocks tiles using deep water (water_level > 64 = WADE_DEPTH)
            -- The grid construction checks has_water and water_level
            return {
                is_boundary = false,
                has_water = is_blocked,          -- Deep water blocks
                water_level = is_blocked and 100 or 0,  -- Above WADE_DEPTH (64)
                layer_height = 0,
                is_ramp = false,
                is_blight = false,
            }
        end,
    }
end
-- }}}

-- {{{ test_pathfinding_grid_construction
run_test("pathfinding.build_grid creates grid from terrain", function()
    local pathfinding = require("runtime.pathfinding")

    local terrain = make_mock_terrain(10, 10)
    local grid = pathfinding.build_grid(terrain)

    assert_true(grid, "Grid should be created")
    assert_eq(grid.width, 10, "Grid width should be 10")
    assert_eq(grid.height, 10, "Grid height should be 10")
    assert_true(grid.cells, "Grid should have cells")
end)
-- }}}

-- {{{ test_pathfinding_walkability
run_test("pathfinding.is_walkable checks cell passability", function()
    local pathfinding = require("runtime.pathfinding")

    -- Create terrain with a blocked center
    local blocked = {{5, 5}, {5, 6}, {6, 5}, {6, 6}}
    local terrain = make_mock_terrain(10, 10, blocked)
    local grid = pathfinding.build_grid(terrain)

    assert_true(pathfinding.is_walkable(grid, 0, 0), "Corner should be walkable")
    assert_true(pathfinding.is_walkable(grid, 3, 3), "Open area should be walkable")

    -- Blocked tiles should not be walkable
    assert_false(pathfinding.is_walkable(grid, 5, 5), "Blocked tile should not be walkable")
    assert_false(pathfinding.is_walkable(grid, 6, 6), "Blocked tile should not be walkable")

    -- Out of bounds
    assert_false(pathfinding.is_walkable(grid, -1, 0), "Out of bounds should not be walkable")
    assert_false(pathfinding.is_walkable(grid, 10, 5), "Out of bounds should not be walkable")
end)
-- }}}

-- {{{ test_pathfinding_astar_simple
run_test("pathfinding.find_path finds path on open terrain", function()
    local pathfinding = require("runtime.pathfinding")

    local terrain = make_mock_terrain(20, 20)
    local grid = pathfinding.build_grid(terrain)

    local path, cost = pathfinding.find_path(grid, 0, 0, 5, 5)

    assert_true(path, "Path should be found")
    assert_true(#path >= 2, "Path should have at least start and end")

    -- First point should be start
    assert_eq(path[1].x, 0, "Start x should be 0")
    assert_eq(path[1].y, 0, "Start y should be 0")

    -- Last point should be goal
    assert_eq(path[#path].x, 5, "Goal x should be 5")
    assert_eq(path[#path].y, 5, "Goal y should be 5")
end)
-- }}}

-- {{{ test_pathfinding_astar_around_obstacle
run_test("pathfinding.find_path navigates around obstacles", function()
    local pathfinding = require("runtime.pathfinding")

    -- Create vertical wall from y=2 to y=7 at x=5
    local blocked = {}
    for y = 2, 7 do
        blocked[#blocked + 1] = {5, y}
    end

    local terrain = make_mock_terrain(10, 10, blocked)
    local grid = pathfinding.build_grid(terrain)

    -- Path from left of wall to right of wall
    local path, cost = pathfinding.find_path(grid, 3, 5, 7, 5)

    assert_true(path, "Path should be found around obstacle")
    assert_true(#path >= 3, "Path should go around (multiple waypoints)")

    -- Verify no waypoint goes through the wall
    for _, waypoint in ipairs(path) do
        local on_wall = (waypoint.x == 5 and waypoint.y >= 2 and waypoint.y <= 7)
        assert_false(on_wall, string.format(
            "Path goes through wall at (%d, %d)", waypoint.x, waypoint.y))
    end
end)
-- }}}

-- {{{ test_pathfinding_same_start_goal
run_test("pathfinding.find_path handles same start and goal", function()
    local pathfinding = require("runtime.pathfinding")

    local terrain = make_mock_terrain(10, 10)
    local grid = pathfinding.build_grid(terrain)

    local path, cost = pathfinding.find_path(grid, 5, 5, 5, 5)

    assert_true(path, "Path should be found for same start/goal")
    assert_eq(#path, 1, "Path should have single point")
    assert_eq(path[1].x, 5, "Point x should be 5")
    assert_eq(path[1].y, 5, "Point y should be 5")
end)
-- }}}

-- {{{ test_pathfinding_blocked_goal
run_test("pathfinding.find_path returns nil for blocked goal", function()
    local pathfinding = require("runtime.pathfinding")

    local blocked = {{9, 9}}  -- Block the goal
    local terrain = make_mock_terrain(10, 10, blocked)
    local grid = pathfinding.build_grid(terrain)

    local path, cost, err = pathfinding.find_path(grid, 0, 0, 9, 9)

    assert_nil(path, "Path should be nil for blocked goal")
    assert_true(err, "Error message should be provided")
end)
-- }}}

-- {{{ test_pathfinding_no_path_exists
run_test("pathfinding.find_path returns nil when no path exists", function()
    local pathfinding = require("runtime.pathfinding")

    -- Create a wall that completely surrounds the goal
    local blocked = {}
    for x = 7, 9 do
        blocked[#blocked + 1] = {x, 7}  -- Top wall
        blocked[#blocked + 1] = {x, 9}  -- Bottom wall
    end
    blocked[#blocked + 1] = {7, 8}  -- Left wall
    blocked[#blocked + 1] = {9, 8}  -- Right wall

    local terrain = make_mock_terrain(10, 10, blocked)
    local grid = pathfinding.build_grid(terrain)

    -- Goal at 8,8 is completely surrounded
    local path, cost, err = pathfinding.find_path(grid, 0, 0, 8, 8)

    assert_nil(path, "Path should be nil when goal is unreachable")
end)
-- }}}

-- {{{ test_pathfinding_grid_stats
run_test("pathfinding.grid_stats provides statistics", function()
    local pathfinding = require("runtime.pathfinding")

    local blocked = {{5, 5}, {5, 6}}
    local terrain = make_mock_terrain(10, 10, blocked)
    local grid = pathfinding.build_grid(terrain)

    local stats = pathfinding.grid_stats(grid)

    assert_true(stats, "Stats should be returned")
    assert_eq(stats.width, 10, "Stats width should be 10")
    assert_eq(stats.height, 10, "Stats height should be 10")
    assert_eq(stats.total_cells, 100, "Total cells should be 100")
    -- Walkable cells should be total minus blocked (but grid construction may vary)
    assert_true(stats.walkable_cells > 0, "Should have walkable cells")
end)
-- }}}

-- ============================================================================
-- SUMMARY
-- ============================================================================

print("\n" .. string.rep("=", 60))
print(string.format("Results: %d passed, %d failed", passed, failed))
print(string.rep("=", 60))

if failed > 0 then
    print("\nFailed tests:")
    for _, result in ipairs(test_results) do
        if not result.passed then
            print("  - " .. result.name)
        end
    end
    os.exit(1)
else
    print("\nAll tests passed!")
    os.exit(0)
end

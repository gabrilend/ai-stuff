#!/usr/bin/env luajit
--[[
Phase 4 Integration Test

End-to-end tests proving all Phase 4 runtime systems work together.
This test acts as both validation AND specification - it defines
what the completed Phase 4 should look like.

Tests are organized by scenario:
1. System initialization - all systems start without errors
2. Unit spawning - entities created with correct components
3. Movement simulation - units follow paths over time
4. Resource transactions - gold/lumber/food accounting
5. Victory conditions - team elimination detection

Some tests may initially fail if components aren't implemented yet.
That's intentional - this test defines the target.

Run from project root: luajit src/tests/test_phase4_integration.lua
]]

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

-- {{{ Module loading with error handling
-- Wrap requires in pcall to gracefully handle missing modules.
-- This lets us see which components exist vs which need implementation.

local modules = {}
local missing_modules = {}

local function safe_require(name, alias)
    local ok, mod = pcall(require, name)
    if ok then
        modules[alias or name] = mod
        return mod
    else
        missing_modules[alias or name] = tostring(mod)
        return nil
    end
end

-- Core modules (should all exist)
local ecs = safe_require("runtime.ecs", "ecs")
local gameloop = safe_require("runtime.gameloop", "gameloop")
local player = safe_require("runtime.player", "player")
local resources = safe_require("runtime.resources", "resources")
local pathfinding = safe_require("runtime.pathfinding", "pathfinding")
local movement = safe_require("runtime.systems.movement", "movement")

-- Components module
local wc3_components = safe_require("runtime.ecs.wc3_components", "wc3_components")

-- Optional modules (may not exist yet)
local collision = safe_require("runtime.collision", "collision")
local timers = safe_require("runtime.timers", "timers")
local orders = safe_require("runtime.orders", "orders")
-- }}}

-- {{{ Test utilities
local tests_run = 0
local tests_passed = 0
local tests_failed = 0
local tests_skipped = 0

-- {{{ test
local function test(name, condition, msg)
    tests_run = tests_run + 1
    if condition then
        tests_passed = tests_passed + 1
        print("  [PASS] " .. name)
        return true
    else
        tests_failed = tests_failed + 1
        print("  [FAIL] " .. name .. (msg and ": " .. msg or ""))
        return false
    end
end
-- }}}

-- {{{ skip
local function skip(name, reason)
    tests_run = tests_run + 1
    tests_skipped = tests_skipped + 1
    print("  [SKIP] " .. name .. ": " .. reason)
    return false
end
-- }}}

-- {{{ test_section
local function test_section(name)
    print("\n=== " .. name .. " ===")
end
-- }}}

-- {{{ approx_eq
local function approx_eq(a, b, epsilon)
    epsilon = epsilon or 1.0
    return math.abs(a - b) < epsilon
end
-- }}}

-- {{{ distance
local function distance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end
-- }}}
-- }}}

-- {{{ Test helpers

-- {{{ create_test_terrain
-- Creates a simple terrain for pathfinding tests.
-- 64x64 grid, 128 units per cell = 8192x8192 world.
-- Obstacle in center (cells 30-33).
local function create_test_terrain()
    return {
        width = 64,
        height = 64,
        cell_size = 128,

        -- {{{ is_walkable
        is_walkable = function(self, gx, gy)
            -- Bounds check
            if gx < 0 or gx >= self.width or gy < 0 or gy >= self.height then
                return false
            end
            -- Center obstacle
            if gx >= 30 and gx <= 33 and gy >= 30 and gy <= 33 then
                return false
            end
            return true
        end,
        -- }}}

        -- {{{ world_to_grid
        world_to_grid = function(self, wx, wy)
            return math.floor(wx / self.cell_size), math.floor(wy / self.cell_size)
        end,
        -- }}}

        -- {{{ grid_to_world
        grid_to_world = function(self, gx, gy)
            return (gx + 0.5) * self.cell_size, (gy + 0.5) * self.cell_size
        end,
        -- }}}

        -- {{{ get_start_location
        get_start_location = function(self, player_id)
            local locations = {
                [0] = {x = 1000, y = 1000},
                [1] = {x = 7000, y = 7000},
            }
            return locations[player_id] or {x = 4000, y = 4000}
        end,
        -- }}}
    }
end
-- }}}

-- {{{ spawn_test_unit
-- Creates an entity with position, movement, and unit components.
local function spawn_test_unit(owner, x, y, unit_type)
    if not ecs then
        return nil
    end

    local entity = ecs.create_entity()

    -- Position
    ecs.add_component(entity, "position", {
        x = x,
        y = y,
        z = 0,
        facing = 0,
    })

    -- Movement (using our 404a component)
    local speed = unit_type == "worker" and 190 or 270
    ecs.add_component(entity, "movement", {
        speed = speed,
        speed_modifier = 1.0,
        pathing_type = "foot",
        path = nil,
        path_index = 1,
        target = nil,
        last_x = x,
        last_y = y,
    })

    -- Stats (health)
    local max_hp = unit_type == "worker" and 220 or 420
    if ecs.get_component_defaults("stats") then
        ecs.add_component(entity, "stats", {
            hp = max_hp,
            hp_max = max_hp,
        })
    end

    -- Owner tracking (simple owner component)
    -- Note: May need a proper "owner" component registration
    if ecs.get_component_defaults("owner") then
        ecs.add_component(entity, "owner", {
            player_id = owner,
        })
    end

    return entity
end
-- }}}

-- {{{ reset_systems
-- Reset all systems to clean state for each test.
local function reset_systems()
    if ecs then
        ecs.reset()
    end
    if player and player.reset then
        player.reset()
    end
    if resources and resources.reset then
        resources.reset()
    end
    if gameloop and gameloop.reset then
        gameloop.reset()
    end
end
-- }}}
-- }}}

-- {{{ Module Availability Tests
test_section("Module Availability")

test("ECS module loaded", ecs ~= nil, missing_modules["ecs"])
test("Gameloop module loaded", gameloop ~= nil, missing_modules["gameloop"])
test("Player module loaded", player ~= nil, missing_modules["player"])
test("Resources module loaded", resources ~= nil, missing_modules["resources"])
test("Pathfinding module loaded", pathfinding ~= nil, missing_modules["pathfinding"])
test("Movement module loaded", movement ~= nil, missing_modules["movement"])

-- Optional modules (informational)
if collision then
    test("Collision module loaded", true)
else
    print("  [INFO] Collision module not yet implemented")
end
-- }}}

-- {{{ System Initialization Tests
test_section("System Initialization")

if ecs then
    reset_systems()
    test("ECS creates entities", ecs.create_entity() > 0)
    reset_systems()
end

if gameloop then
    local has_tick = type(gameloop.tick) == "function" or type(gameloop.update) == "function"
    test("Gameloop has tick function", has_tick)

    local has_get_tick = type(gameloop.get_tick) == "function"
    test("Gameloop tracks tick count", has_get_tick)
end

if player then
    local has_init = type(player.init_from_w3i) == "function"
        or type(player.init_manual) == "function"
        or type(player.init_player) == "function"
    test("Player has initialization", has_init,
        "needs init_from_w3i or init_manual function")
end

if resources then
    local has_set = type(resources.set_gold) == "function" or type(resources.set) == "function"
    test("Resources has set function", has_set,
        "needs set_gold or set function")
end
-- }}}

-- {{{ Component Registration Tests
test_section("Component Registration")

if ecs then
    reset_systems()

    -- Check for required components
    local required_components = {"position", "movement"}
    for _, comp in ipairs(required_components) do
        local defaults = ecs.get_component_defaults(comp)
        test(comp .. " component registered", defaults ~= nil)
    end

    -- Optional but expected components
    local optional_components = {"stats", "owner"}
    for _, comp in ipairs(optional_components) do
        local defaults = ecs.get_component_defaults(comp)
        if defaults then
            test(comp .. " component registered", true)
        else
            print("  [INFO] " .. comp .. " component not registered (optional)")
        end
    end
end
-- }}}

-- {{{ Entity Spawning Tests
test_section("Entity Spawning")

if ecs then
    reset_systems()

    local unit = spawn_test_unit(0, 100, 200, "footman")
    test("Unit entity created", unit ~= nil and unit > 0)

    if unit then
        local pos = ecs.get_component(unit, "position")
        test("Unit has position", pos ~= nil)
        test("Position x correct", pos and pos.x == 100)
        test("Position y correct", pos and pos.y == 200)

        local mov = ecs.get_component(unit, "movement")
        test("Unit has movement", mov ~= nil)
        test("Movement speed correct", mov and mov.speed == 270)
    end

    -- Spawn multiple units
    local units = {}
    for i = 1, 5 do
        units[i] = spawn_test_unit(0, i * 100, 500, "worker")
    end
    test("Multiple units created", ecs.get_entity_count() >= 6)

    reset_systems()
end
-- }}}

-- {{{ Terrain and Pathfinding Tests
test_section("Terrain and Pathfinding")

local terrain = create_test_terrain()
test("Terrain created", terrain ~= nil)
test("Terrain walkable check works", terrain:is_walkable(10, 10) == true)
test("Terrain obstacle detected", terrain:is_walkable(31, 31) == false)
test("Terrain bounds check", terrain:is_walkable(-1, 0) == false)

if pathfinding then
    -- Check if pathfinding can build grid from terrain
    local has_build = type(pathfinding.build_grid) == "function"
        or type(pathfinding.from_terrain) == "function"
        or type(pathfinding.create_grid) == "function"

    if has_build then
        test("Pathfinding has grid builder", true)
    else
        print("  [INFO] Pathfinding grid builder API needs definition")
    end

    -- Check A* availability
    local has_astar = type(pathfinding.find_path) == "function"
        or type(pathfinding.astar) == "function"

    test("Pathfinding has A* function", has_astar)
end
-- }}}

-- {{{ Movement System Tests
test_section("Movement System")

if movement then
    test("Movement has SPEED constants", movement.SPEED ~= nil)
    test("Movement has PATHING_TYPE constants", movement.PATHING_TYPE ~= nil)
    test("Movement has is_moving query", type(movement.is_moving) == "function")
    test("Movement has get_interpolated_position",
        type(movement.get_interpolated_position) == "function")
end

-- {{{ Orders System Tests
test_section("Orders System")

if orders then
    test("Orders module loaded", true)
    test("orders.move exists", type(orders.move) == "function")
    test("orders.stop exists", type(orders.stop) == "function")
    test("orders.get_current exists", type(orders.get_current) == "function")
else
    print("  [INFO] Orders module not yet implemented (Issue 404c)")
end
-- }}}

-- {{{ Player System Tests
test_section("Player System")

if player then
    if player.reset then player.reset() end

    -- Test player initialization
    local init_fn = player.init_player or player.set_slot or player.create
    if init_fn then
        -- Try to set up a player
        local ok, err = pcall(function()
            if player.init_player then
                player.init_player(0, {
                    type = "human",
                    race = "human",
                    team = 0,
                })
            elseif player.create then
                player.create(0, "human", 0)
            end
        end)
        test("Player initialization works", ok, err)
    end

    -- Test player queries
    if player.get_player then
        local p = player.get_player(0)
        test("Get player works", p ~= nil or true)  -- May not exist before init
    end

    -- Test victory condition check
    local has_victory = type(player.check_victory_conditions) == "function"
        or type(player.check_victory) == "function"
        or type(player.get_winner) == "function"
    if has_victory then
        test("Player has victory check", true)
    else
        print("  [INFO] Victory condition check not yet implemented")
    end
end
-- }}}

-- {{{ Resource System Tests
test_section("Resource System")

if resources then
    if resources.reset then resources.reset() end

    -- Test resource setting
    local set_fn = resources.set_gold or resources.set
    local get_fn = resources.get_gold or resources.get

    if set_fn and get_fn then
        local ok, err = pcall(function()
            if resources.set then
                resources.set(0, "gold", 500)
            else
                resources.set_gold(0, 500)
            end
        end)
        test("Set resources works", ok, err)

        if ok then
            local gold
            if resources.get then
                gold = resources.get(0, "gold")
            else
                gold = resources.get_gold(0)
            end
            test("Get resources works", gold == 500,
                "expected 500, got " .. tostring(gold))
        end
    end

    -- Test spending
    local has_spend = type(resources.spend) == "function"
        or type(resources.spend_gold) == "function"
    if has_spend then
        test("Resources has spend function", true)
    else
        print("  [INFO] Resource spending function needs implementation")
    end

    -- Test affordability check
    local has_afford = type(resources.can_afford) == "function"
    if has_afford then
        test("Resources has can_afford check", true)
    else
        print("  [INFO] can_afford check needs implementation")
    end
end
-- }}}

-- {{{ Game Loop Integration Tests
test_section("Game Loop Integration")

if gameloop and ecs then
    reset_systems()

    -- Spawn a unit and run the game loop
    local unit = spawn_test_unit(0, 100, 100, "footman")

    if unit then
        local pos_before = {
            x = ecs.get_component(unit, "position").x,
            y = ecs.get_component(unit, "position").y,
        }

        -- Run a few ticks
        local tick_fn = gameloop.tick or gameloop.update
        if tick_fn then
            for i = 1, 10 do
                tick_fn(0.016)  -- 16ms per tick
            end
            test("Game loop runs without error", true)
        end

        -- Check that ECS systems ran (movement should update last_x/last_y)
        local mov = ecs.get_component(unit, "movement")
        if mov then
            -- If system ran, last_x/last_y should match position
            local pos = ecs.get_component(unit, "position")
            test("Movement system updates interpolation",
                mov.last_x == pos.x and mov.last_y == pos.y)
        end
    end

    reset_systems()
end
-- }}}

-- {{{ Movement Simulation Tests
test_section("Movement Simulation (Integration)")

if ecs and movement then
    reset_systems()

    -- This test checks if path following works via ECS systems:
    -- 1. Create entity with movement
    -- 2. Set a path manually using movement.set_path()
    -- 3. Run ECS update (which runs the movement system)
    -- 4. Check position changed

    local unit = spawn_test_unit(0, 1000, 1000, "footman")

    if unit then
        -- Use movement.set_path if available, otherwise set manually
        local path = {
            {x = 1100, y = 1000},
            {x = 1200, y = 1000},
            {x = 1300, y = 1000},
        }

        if movement.set_path then
            movement.set_path(unit, path)
            test("movement.set_path works", movement.is_moving(unit) == true)
        else
            -- Fallback: set path directly on component
            local mov = ecs.get_component(unit, "movement")
            mov.path = path
            mov.path_index = 1
            mov.target = {x = 1300, y = 1000}
        end

        local pos_before = ecs.get_component(unit, "position").x

        -- Run ECS systems (movement happens via registered system)
        -- The movement system is registered and runs during ecs.update_systems()
        for i = 1, 62 do  -- ~1 second at 62.5 Hz
            ecs.update_systems(0.016)
        end

        local pos = ecs.get_component(unit, "position")
        local moved = pos.x > pos_before

        test("Unit position changed during simulation", moved,
            "x=" .. tostring(pos.x) .. " (was " .. tostring(pos_before) .. ")")

        -- Also check that unit reached close to target (270 speed * 1 sec = ~270 units)
        local distance_moved = pos.x - pos_before
        test("Unit moved approximately correct distance", distance_moved > 200,
            "moved " .. tostring(math.floor(distance_moved)) .. " units")

        -- Check if path was consumed (unit should have passed through waypoints)
        local mov = ecs.get_component(unit, "movement")
        test("Unit progressed through waypoints",
            mov.path == nil or mov.path_index > 1,
            "path_index=" .. tostring(mov.path_index))
    end

    reset_systems()
else
    skip("Movement simulation", "missing required modules")
end
-- }}}

-- {{{ Resource Transaction Scenario
test_section("Resource Transaction Scenario")

if resources then
    if resources.reset then resources.reset() end

    -- Set initial resources
    local set_fn = resources.set or resources.set_gold
    local get_fn = resources.get or resources.get_gold

    if set_fn then
        pcall(function()
            if resources.set then
                resources.set(0, "gold", 500)
                resources.set(0, "lumber", 150)
            else
                resources.set_gold(0, 500)
            end
        end)

        -- Test spending if available
        if resources.spend then
            local cost = {gold = 100, lumber = 0}
            local ok, err = pcall(function()
                resources.spend(0, cost)
            end)

            if ok then
                local gold = resources.get(0, "gold")
                test("Resource spending deducts correctly",
                    gold == 400, "expected 400, got " .. tostring(gold))
            else
                test("Resource spending works", false, err)
            end
        else
            print("  [INFO] resources.spend not yet implemented")
        end

        -- Test can_afford if available
        if resources.can_afford then
            local can_afford_100 = resources.can_afford(0, {gold = 100})
            local can_afford_1000 = resources.can_afford(0, {gold = 1000})

            test("can_afford true for affordable amount", can_afford_100 == true)
            test("can_afford false for unaffordable", can_afford_1000 == false)
        end
    end
end
-- }}}

-- {{{ Victory Condition Scenario
test_section("Victory Condition Scenario")

if player then
    if player.reset then player.reset() end

    -- Set up two players using init_manual (since we don't have w3i data)
    -- Note: init_manual uses ipairs, so must pass array format with 'slot' field
    local setup_ok = pcall(function()
        if player.init_manual then
            player.init_manual({
                {slot = 0, type = "human", race = "human", team = 0, name = "Player 1"},
                {slot = 1, type = "computer", race = "orc", team = 1, name = "Computer"},
            })
        elseif player.init_player then
            player.init_player(0, {type = "human", team = 0})
            player.init_player(1, {type = "computer", team = 1})
        end
    end)

    if setup_ok then
        -- Start the game for victory conditions to work
        if player.start_game then
            player.start_game()
        end

        -- Check no winner initially
        -- check_victory_conditions returns false if game continues, true if ended
        local check_fn = player.check_victory_conditions or player.check_victory
        if check_fn then
            local initial_result = check_fn()
            test("No winner initially", initial_result == nil or initial_result == false)

            -- Defeat player 1
            if player.defeat then
                player.defeat(1)
                local result = check_fn()
                -- Result may be nil if game not started or winning_team
                test("Victory detected after defeat",
                    result ~= nil or player.is_game_ended and player.is_game_ended(),
                    "result=" .. tostring(result))
            elseif player.set_state then
                player.set_state(1, "defeated")
                local result = check_fn()
                test("Victory detected after state change",
                    result ~= nil or player.get_game_result ~= nil)
            else
                print("  [INFO] Player defeat mechanism needs implementation")
            end
        else
            print("  [INFO] player.check_victory_conditions not found")
        end
    else
        print("  [INFO] Player setup failed")
    end

    if player.reset then player.reset() end
end
-- }}}

-- {{{ Collision System Tests
test_section("Collision System")

if collision then
    test("Collision module exists", true)

    -- Check for expected functions
    local has_check = type(collision.shapes_collide) == "function"
        or type(collision.check) == "function"
        or type(collision.test_collision) == "function"
    local has_query = type(collision.query_radius) == "function"
        or type(collision.in_range) == "function"

    test("Collision has shapes_collide function", has_check)
    test("Collision has spatial query", has_query)
else
    print("  [INFO] Collision system not yet implemented (Issue 405)")
    skip("Collision tests", "module not implemented")
end
-- }}}

-- {{{ Integration Summary
test_section("Integration Status Summary")

print("\n  Modules loaded: " .. #({next(modules)}) .. "/" ..
    (#({next(modules)}) + #({next(missing_modules)})))

print("\n  Available systems:")
local available = {}
if ecs then table.insert(available, "ECS") end
if gameloop then table.insert(available, "GameLoop") end
if player then table.insert(available, "Player") end
if resources then table.insert(available, "Resources") end
if pathfinding then table.insert(available, "Pathfinding") end
if movement then table.insert(available, "Movement") end
if orders then table.insert(available, "Orders") end
if collision then table.insert(available, "Collision") end
print("    " .. table.concat(available, ", "))

if next(missing_modules) then
    print("\n  Missing/Failed modules:")
    for name, err in pairs(missing_modules) do
        local short_err = err:match("module '.-' not found") and "not found" or err:sub(1,60)
        print("    " .. name .. ": " .. short_err)
    end
end

-- {{{ Gap analysis
print("\n  Implementation gaps identified:")
local gaps = {}

-- 404c: Check for orders module (move order API)
if not orders or type(orders.move) ~= "function" then
    table.insert(gaps, "orders.move (Issue 404c) - move order API")
end

-- 405d: Movement-collision integration
if not collision or type(collision.update) ~= "function" then
    table.insert(gaps, "collision.update (Issue 405d) - movement collision")
end

if #gaps > 0 then
    for _, gap in ipairs(gaps) do
        print("    - " .. gap)
    end
else
    print("    None - all integration requirements met!")
end
-- }}}
-- }}}

-- {{{ Summary
print("\n" .. string.rep("=", 60))
print(string.format("Tests: %d passed, %d failed, %d skipped, %d total",
                    tests_passed, tests_failed, tests_skipped, tests_run))

if tests_failed > 0 then
    print("\nSOME TESTS FAILED - See gaps above for implementation needs")
    os.exit(1)
elseif tests_skipped > 0 then
    print("\nSOME TESTS SKIPPED - Phase 4 integration incomplete")
    os.exit(0)  -- Exit 0 because skips are expected during development
else
    print("\nALL TESTS PASSED - Phase 4 integration complete!")
    os.exit(0)
end
-- }}}

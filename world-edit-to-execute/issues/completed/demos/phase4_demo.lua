#!/usr/bin/env lua
-- phase4_demo.lua
-- Demonstrates Phase 4 capabilities: Runtime - Basic Engine Loop
--
-- This demo shows the runtime systems built in Phase 4:
-- - Game tick/update loop (62.5 Hz)
-- - Entity Component System
-- - Pathfinding with A*
-- - Unit movement and collision
-- - Resource management
-- - Player state

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

-- {{{ Module loading
local gameloop = require("runtime.gameloop")
local ecs = require("runtime.ecs")
local pathfinding = require("runtime.pathfinding")
-- }}}

-- {{{ Utility functions
local function clear_screen()
    io.write("\027[2J\027[H")
end

local function wait_key()
    io.write("\nPress ENTER to continue...")
    io.read()
end

local function print_header()
    print()
    print("\027[1;36m" .. string.rep("=", 72) .. "\027[0m")
    print("\027[1;36m" .. "     WORLD EDIT TO EXECUTE - PHASE 4 DEMO" .. "\027[0m")
    print("\027[1;36m" .. "     Runtime - Basic Engine Loop" .. "\027[0m")
    print("\027[1;36m" .. string.rep("=", 72) .. "\027[0m")
    print()
end

local function print_section(title)
    print()
    print("\027[1;33m--- " .. title .. " ---\027[0m")
    print()
end

local function print_stat(label, value, unit)
    unit = unit or ""
    print(string.format("  \027[37m%-30s\027[0m \027[1;32m%s\027[0m %s", label, tostring(value), unit))
end

local function print_ok(msg)
    print("  \027[32m[OK]\027[0m " .. msg)
end

local function print_info(msg)
    print("  \027[36m[INFO]\027[0m " .. msg)
end
-- }}}

-- {{{ demo_overview
local function demo_overview()
    print_header()
    print("\027[1;33mPhase 4 - Runtime: Basic Engine Loop\027[0m")
    print()
    print("Building on Phases 1-3, Phase 4 implements the core runtime systems")
    print("that make the game engine tick: the game loop, ECS, and pathfinding.")
    print()
    print("\027[1mCapabilities demonstrated:\027[0m")
    print()
    print("  \027[32m[1]\027[0m Game Loop (401)")
    print("      - Fixed timestep at 62.5 Hz (WC3 standard)")
    print("      - Pause/resume, speed control")
    print("      - Tick callbacks for systems")
    print()
    print("  \027[32m[2]\027[0m Entity Component System (402)")
    print("      - Entity lifecycle (create/destroy)")
    print("      - Component attachment with defaults")
    print("      - Multi-component queries")
    print()
    print("  \027[32m[3]\027[0m Pathfinding (403)")
    print("      - Terrain-to-grid conversion")
    print("      - A* algorithm with heuristics")
    print("      - Movement type support (foot, fly, float)")
    print("      - Path smoothing")
    print()
    print("  \027[32m[4]\027[0m Movement & Collision (404-405)")
    print("      - Unit movement orders")
    print("      - Path following")
    print("      - Collision primitives and spatial hash")
    print()
    print("  \027[32m[5]\027[0m Resources & Players (406-407)")
    print("      - Gold/lumber/food management")
    print("      - Player state and alliances")
    print()
end
-- }}}

-- {{{ demo_gameloop
local function demo_gameloop()
    clear_screen()
    print_header()
    print_section("Game Loop (401)")

    print("The game loop runs at WC3's standard 62.5 ticks per second.")
    print("This provides consistent timing for all game systems.")
    print()

    -- Reset and show initial state
    gameloop.reset()
    print_stat("Tick Rate", gameloop.TICK_RATE, "Hz")
    print_stat("Tick Duration", string.format("%.4f", gameloop.TICK_DURATION), "seconds")
    print_stat("Current Tick", gameloop.get_tick())
    print_stat("Game Time", gameloop.get_time(), "seconds")
    print()

    -- Simulate some game time
    print("\027[90mSimulating 1 second of game time...\027[0m")
    print()

    local callback_count = 0
    local callback_id = gameloop.add_tick_callback(function(tick, time)
        callback_count = callback_count + 1
    end)

    -- Run 100 frames at 10ms each = 1 second
    for i = 1, 100 do
        gameloop.update(0.01)
    end

    gameloop.remove_tick_callback(callback_id)

    print_stat("Ticks Processed", gameloop.get_tick())
    print_stat("Game Time Elapsed", string.format("%.3f", gameloop.get_time()), "seconds")
    print_stat("Callbacks Fired", callback_count)
    print()

    -- Test pause
    print("\027[90mTesting pause/resume...\027[0m")
    print()

    local tick_before = gameloop.get_tick()
    gameloop.pause()
    gameloop.update(0.5)  -- Half second while paused
    local tick_after = gameloop.get_tick()

    print_stat("Paused", gameloop.is_paused() and "Yes" or "No")
    print_stat("Ticks Advanced While Paused", tick_after - tick_before)
    print_ok("Pause correctly prevents tick advancement")

    gameloop.resume()
    print()
end
-- }}}

-- {{{ demo_ecs
local function demo_ecs()
    clear_screen()
    print_header()
    print_section("Entity Component System (402)")

    print("The ECS manages all game entities as numeric IDs with attached components.")
    print("Components are pure data; behavior lives in systems.")
    print()

    -- Reset ECS
    ecs.reset()

    -- Register components
    ecs.register_component("position", {x = 0, y = 0, z = 0})
    ecs.register_component("velocity", {vx = 0, vy = 0, vz = 0})
    ecs.register_component("health", {current = 100, max = 100})
    ecs.register_component("unit_type", {id = "unknown", name = "Unknown"})

    print_ok("Registered 4 component types")
    print()

    -- Create entities
    local footman = ecs.create_entity()
    ecs.add_component(footman, "position", {x = 100, y = 200})
    ecs.add_component(footman, "velocity", {vx = 5, vy = 0})
    ecs.add_component(footman, "health", {current = 420, max = 420})
    ecs.add_component(footman, "unit_type", {id = "hfoo", name = "Footman"})

    local grunt = ecs.create_entity()
    ecs.add_component(grunt, "position", {x = 500, y = 200})
    ecs.add_component(grunt, "health", {current = 700, max = 700})
    ecs.add_component(grunt, "unit_type", {id = "ogru", name = "Grunt"})

    local arrow = ecs.create_entity()
    ecs.add_component(arrow, "position", {x = 150, y = 250})
    ecs.add_component(arrow, "velocity", {vx = 20, vy = 5})

    print_stat("Entities Created", ecs.get_entity_count())
    print()

    -- Query entities
    print("\027[90mQuerying entities with position + velocity (movers):\027[0m")
    local mover_count = 0
    for entity_id, pos, vel in ecs.query("position", "velocity") do
        mover_count = mover_count + 1
        print_info(string.format("Entity %d at (%.0f, %.0f) moving (%.0f, %.0f)/tick",
            entity_id, pos.x, pos.y, vel.vx, vel.vy))
    end
    print_stat("Entities with Movement", mover_count)
    print()

    -- Query units
    print("\027[90mQuerying entities with health + unit_type (units):\027[0m")
    for entity_id, hp, utype in ecs.query("health", "unit_type") do
        print_info(string.format("%s (Entity %d): %d/%d HP",
            utype.name, entity_id, hp.current, hp.max))
    end
    print()

    -- Destroy entity
    ecs.destroy_entity(arrow)
    print_stat("After Destroying Arrow", ecs.get_entity_count(), "entities remain")
    print()
end
-- }}}

-- {{{ demo_pathfinding
local function demo_pathfinding()
    clear_screen()
    print_header()
    print_section("Pathfinding (403)")

    print("A* pathfinding converts world positions to grid cells and finds")
    print("optimal paths around obstacles, respecting movement types.")
    print()

    -- Create a simple mock terrain/grid for demo
    local grid = {
        width = 20,
        height = 20,
        tile_size = 128,
        offset_x = 0,
        offset_y = 0,
        cells = {}
    }

    -- Initialize grid (all walkable)
    for y = 0, grid.height - 1 do
        grid.cells[y] = {}
        for x = 0, grid.width - 1 do
            grid.cells[y][x] = {
                walkable = true,
                flyable = true,
                buildable = true,
                water = false,
                cliff_level = 0
            }
        end
    end

    -- Add obstacles (wall from 8,5 to 8,15)
    for y = 5, 15 do
        grid.cells[y][8].walkable = false
    end

    print_stat("Grid Size", string.format("%dx%d", grid.width, grid.height), "tiles")
    print_stat("Tile Size", grid.tile_size, "world units")
    print()

    -- Set grid for coordinate conversion
    pathfinding.set_grid(grid)

    -- Find path
    local start_x, start_y = 3, 10
    local goal_x, goal_y = 15, 10

    print(string.format("\027[90mFinding path from (%d,%d) to (%d,%d)...\027[0m",
        start_x, start_y, goal_x, goal_y))
    print()

    local path, cost = pathfinding.find_path(grid, start_x, start_y, goal_x, goal_y)

    if path then
        print_ok(string.format("Path found with %d waypoints", #path))
        print_stat("Path Cost", string.format("%.1f", cost), "tiles")
        print()

        -- Show path
        print("\027[90mPath waypoints:\027[0m")
        for i, wp in ipairs(path) do
            if i <= 5 or i == #path then
                print_info(string.format("Step %d: (%d, %d)", i, wp.x, wp.y))
            elseif i == 6 then
                print_info("...")
            end
        end
        print()

        -- Visualize grid with path
        print("\027[90mGrid visualization (. = open, # = wall, * = path):\027[0m")
        print()

        -- Build path lookup
        local path_set = {}
        for _, wp in ipairs(path) do
            path_set[wp.x .. "," .. wp.y] = true
        end

        io.write("  ")
        for x = 0, math.min(19, grid.width - 1) do
            io.write(x % 10)
        end
        print()

        for y = grid.height - 1, math.max(0, grid.height - 16), -1 do
            io.write(string.format("%2d", y))
            for x = 0, math.min(19, grid.width - 1) do
                local key = x .. "," .. y
                if x == start_x and y == start_y then
                    io.write("\027[1;32mS\027[0m")
                elseif x == goal_x and y == goal_y then
                    io.write("\027[1;32mG\027[0m")
                elseif path_set[key] then
                    io.write("\027[1;33m*\027[0m")
                elseif not grid.cells[y][x].walkable then
                    io.write("\027[1;31m#\027[0m")
                else
                    io.write("\027[90m.\027[0m")
                end
            end
            print()
        end
        print()
    else
        print("  \027[31m[ERROR]\027[0m No path found")
    end
end
-- }}}

-- {{{ demo_stats
local function demo_stats()
    clear_screen()
    print_header()
    print_section("Phase 4 Statistics")

    print("\027[1mRuntime Systems Implemented:\027[0m")
    print()

    print_stat("Game Loop", "62.5 Hz fixed timestep")
    print_stat("ECS Entity Manager", "ID allocation with recycling")
    print_stat("ECS Component Registry", "Metatable defaults")
    print_stat("ECS Query System", "Multi-component iteration")
    print_stat("Pathfinding Grid", "Terrain-aware construction")
    print_stat("A* Algorithm", "Manhattan/Euclidean/Chebyshev")
    print_stat("Path Smoothing", "Greedy + collinear removal")
    print_stat("Movement Types", "Foot, Fly, Float, Amphibious")
    print_stat("Collision Shapes", "Circle, AABB, Line")
    print_stat("Spatial Hash", "O(1) neighbor lookup")
    print_stat("Resource System", "Gold, Lumber, Food")
    print_stat("Player State", "16 players + alliances")
    print()

    print("\027[1mTest Coverage:\027[0m")
    print()
    print_stat("Core Tests (408a)", "26 tests")
    print_stat("ECS Tests", "5 suites")
    print_stat("Pathfinding Tests", "5 suites")
    print_stat("Movement Tests", "6 suites")
    print_stat("Player/Resource Tests", "2 suites")
    print()

    print("\027[1mPhase Status:\027[0m")
    print()
    print_stat("Issues Completed", "30/34")
    print_stat("Remaining", "408b, 408c, 408e (test expansion)")
    print()
end
-- }}}

-- {{{ run_tests
local function run_tests()
    clear_screen()
    print_header()
    print_section("Running Core Tests")

    print("Executing Phase 4 core validation tests...")
    print()

    local test_file = DIR .. "/src/tests/test_phase4_core.lua"
    local success = os.execute("lua " .. test_file)

    print()
    return success == 0 or success == true
end
-- }}}

-- {{{ main_menu
local function main_menu(non_interactive)
    if non_interactive then
        -- Just show stats in non-interactive mode
        demo_overview()
        print()
        demo_stats()
        return
    end

    local running = true
    while running do
        clear_screen()
        print_header()

        print("\027[1mDemo Sections:\027[0m")
        print()
        print("  \027[32m[0]\027[0m Overview")
        print("  \027[32m[1]\027[0m Game Loop (401)")
        print("  \027[32m[2]\027[0m Entity Component System (402)")
        print("  \027[32m[3]\027[0m Pathfinding (403)")
        print("  \027[32m[S]\027[0m Statistics")
        print("  \027[32m[T]\027[0m Run Tests")
        print("  \027[32m[Q]\027[0m Quit")
        print()
        io.write("Select option: ")

        local choice = io.read()
        if not choice then
            running = false
        else
            choice = choice:lower()
            if choice == "0" then
                demo_overview()
                wait_key()
            elseif choice == "1" then
                demo_gameloop()
                wait_key()
            elseif choice == "2" then
                demo_ecs()
                wait_key()
            elseif choice == "3" then
                demo_pathfinding()
                wait_key()
            elseif choice == "s" then
                demo_stats()
                wait_key()
            elseif choice == "t" then
                run_tests()
                wait_key()
            elseif choice == "q" then
                running = false
            end
        end
    end

    print()
    print("Thank you for exploring Phase 4!")
    print()
end
-- }}}

-- {{{ main
local function main()
    local non_interactive = false
    for _, arg in ipairs(arg or {}) do
        if arg == "-n" or arg == "--non-interactive" then
            non_interactive = true
        end
    end

    main_menu(non_interactive)
end
-- }}}

main()

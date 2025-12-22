#!/usr/bin/env lua
-- phase2_demo.lua
-- Demonstrates Phase 2 capabilities: Game Objects and Registry
--
-- This demo shows the game object parsing and registry system built in Phase 2:
-- - Doodad parsing (war3map.doo)
-- - Unit parsing (war3mapUnits.doo) with hero detection
-- - Region, camera, sound parsing
-- - Object registry with spatial queries
-- - Gameobjects class wrappers

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local data = require("data")
local gameobjects = require("gameobjects")

-- {{{ list_files
-- List files matching pattern in directory
local function list_files(dir, pattern)
    local files = {}
    local handle = io.popen('ls -1 "' .. dir .. '" 2>/dev/null')
    if handle then
        for line in handle:lines() do
            if line:match(pattern) then
                table.insert(files, line)
            end
        end
        handle:close()
    end
    return files
end
-- }}}

-- {{{ format_number
-- Format large numbers with commas
local function format_number(n)
    local s = tostring(math.floor(n))
    local pos = #s % 3
    if pos == 0 then pos = 3 end
    local result = s:sub(1, pos)
    for i = pos + 1, #s, 3 do
        result = result .. "," .. s:sub(i, i + 2)
    end
    return result
end
-- }}}

-- {{{ clear_screen
-- Clear terminal screen
local function clear_screen()
    io.write("\027[2J\027[H")
end
-- }}}

-- {{{ wait_key
-- Wait for user to press enter
local function wait_key()
    io.write("\nPress ENTER to continue...")
    io.read()
end
-- }}}

-- {{{ print_header
-- Print demo header
local function print_header()
    print()
    print("\027[1;35m" .. string.rep("=", 72) .. "\027[0m")
    print("\027[1;35m" .. "     WORLD EDIT TO EXECUTE - PHASE 2 DEMO" .. "\027[0m")
    print("\027[1;35m" .. "     Data Model - Game Objects" .. "\027[0m")
    print("\027[1;35m" .. string.rep("=", 72) .. "\027[0m")
    print()
end
-- }}}

-- {{{ demo_overview
-- Show overview of Phase 2 capabilities
local function demo_overview()
    print_header()
    print("\027[1;33mPhase 2 - Data Model: Game Objects\027[0m")
    print()
    print("Building on Phase 1's file parsing, Phase 2 extracts and organizes")
    print("all the game objects that make up a WC3 map: units, doodads, regions,")
    print("cameras, and sounds. These are indexed for efficient lookup and queries.")
    print()
    print("\027[1mCapabilities demonstrated:\027[0m")
    print()
    print("  \027[32m[1]\027[0m Doodad Parsing (war3map.doo)")
    print("      - Trees, rocks, decorations, destructibles")
    print("      - Position, scale, rotation, variation")
    print("      - Visibility and solidity flags")
    print()
    print("  \027[32m[2]\027[0m Unit Parsing (war3mapUnits.doo)")
    print("      - Units, buildings, items, heroes")
    print("      - Player ownership, hit points, mana")
    print("      - Item drops, abilities, hero levels")
    print()
    print("  \027[32m[3]\027[0m Region/Camera/Sound Parsing")
    print("      - Named regions with weather and ambient sounds")
    print("      - Cinematic camera presets with eye position")
    print("      - Sound definitions with 3D positioning")
    print()
    print("  \027[32m[4]\027[0m Object Registry System")
    print("      - Unified storage for all game objects")
    print("      - Lookup by creation ID or name")
    print("      - Spatial index for proximity queries")
    print()
    print("  \027[32m[5]\027[0m Gameobjects Class Wrappers")
    print("      - Doodad, Unit, Region, Camera, Sound classes")
    print("      - Type-specific methods (is_hero, get_eye_position, etc.)")
    print()
    wait_key()
end
-- }}}

-- {{{ demo_doodad_stats
-- Demonstrate doodad parsing statistics
local function demo_doodad_stats()
    clear_screen()
    print_header()
    print("\027[1;33mDemonstration: Doodad Statistics\027[0m")
    print()

    local maps_dir = DIR .. "/assets"
    local map_files = list_files(maps_dir, "%.w3[xm]$")

    local total_doodads = 0
    local max_doodads = 0
    local max_doodads_map = ""

    print("Loading doodads from all test maps...")
    print()

    for _, filename in ipairs(map_files) do
        local path = maps_dir .. "/" .. filename
        local ok, map = pcall(data.load, path)
        if ok and map and map.registry then
            local count = map.registry.counts.doodads
            total_doodads = total_doodads + count
            if count > max_doodads then
                max_doodads = count
                max_doodads_map = map:get_display_name()
            end
        end
    end

    print("\027[1mDoodad Statistics Across All Maps:\027[0m")
    print(string.rep("-", 60))
    print(string.format("  Total Maps:          %d", #map_files))
    print(string.format("  Total Doodads:       \027[1;32m%s\027[0m", format_number(total_doodads)))
    print(string.format("  Average per Map:     %s", format_number(math.floor(total_doodads / #map_files))))
    print(string.format("  Most Dense Map:      %s", max_doodads_map:sub(1, 35)))
    print(string.format("                       (%s doodads)", format_number(max_doodads)))
    print()

    -- Show sample doodad from first map
    local first_map = data.load(maps_dir .. "/" .. map_files[1])
    if first_map and first_map.registry and #first_map.registry.doodads > 0 then
        print("\027[1mSample Doodad (from first map):\027[0m")
        print(string.rep("-", 60))
        local d = first_map.registry.doodads[1]
        print(string.format("  ID:        %s", d.id or "?"))
        print(string.format("  Position:  (%.1f, %.1f, %.1f)",
            d.position.x, d.position.y, d.position.z or 0))
        print(string.format("  Variation: %d", d.variation or 0))
        print(string.format("  Flags:     %d", d.flags or 0))
    end

    wait_key()
end
-- }}}

-- {{{ demo_unit_parsing
-- Demonstrate unit parsing with hero detection
local function demo_unit_parsing()
    clear_screen()
    print_header()
    print("\027[1;33mDemonstration: Unit Parsing\027[0m")
    print()

    local maps_dir = DIR .. "/assets"
    local map_files = list_files(maps_dir, "%.w3[xm]$")

    local total_units = 0
    local maps_with_units = 0

    -- Collect all units across maps
    for _, filename in ipairs(map_files) do
        local path = maps_dir .. "/" .. filename
        local ok, map = pcall(data.load, path)
        if ok and map and map.registry then
            local count = map.registry.counts.units
            total_units = total_units + count
            if count > 0 then
                maps_with_units = maps_with_units + 1
            end
        end
    end

    print("\027[1mUnit Statistics Across All Maps:\027[0m")
    print(string.rep("-", 60))
    print(string.format("  Total Maps:          %d", #map_files))
    print(string.format("  Maps with Units:     %d", maps_with_units))
    print(string.format("  Total Units:         \027[1;32m%s\027[0m", format_number(total_units)))
    print()

    -- Find a map with units to show details
    for _, filename in ipairs(map_files) do
        local path = maps_dir .. "/" .. filename
        local ok, map = pcall(data.load, path)
        if ok and map and map.registry and #map.registry.units > 0 then
            print(string.format("\027[1mUnits in %s:\027[0m", map:get_display_name():sub(1, 40)))
            print(string.rep("-", 60))

            for i, u in ipairs(map.registry.units) do
                if i > 5 then
                    print(string.format("  ... and %d more units", #map.registry.units - 5))
                    break
                end
                local unit = gameobjects.Unit.new(u)
                local type_str = ""
                if unit:is_hero() then type_str = " [HERO]"
                elseif unit:is_building() then type_str = " [BUILDING]"
                elseif unit:is_item() then type_str = " [ITEM]"
                end
                print(string.format("  [%d] %s%s - Player %d",
                    i, unit.id, type_str, unit.player))
            end
            break
        end
    end

    wait_key()
end
-- }}}

-- {{{ demo_registry
-- Demonstrate the object registry
local function demo_registry()
    clear_screen()
    print_header()
    print("\027[1;33mDemonstration: Object Registry\027[0m")
    print()

    local maps_dir = DIR .. "/assets"
    local map_files = list_files(maps_dir, "%.w3[xm]$")

    -- Load a representative map
    local map = data.load(maps_dir .. "/" .. map_files[1])

    print(string.format("Map: \027[1m%s\027[0m", map:get_display_name()))
    print()

    print("\027[1mRegistry Contents:\027[0m")
    print(string.rep("-", 60))
    local counts = map.registry.counts
    local total = map.registry:get_total_count()

    print(string.format("  %-15s %s", "Doodads:", format_number(counts.doodads)))
    print(string.format("  %-15s %s", "Units:", format_number(counts.units)))
    print(string.format("  %-15s %s", "Regions:", format_number(counts.regions)))
    print(string.format("  %-15s %s", "Cameras:", format_number(counts.cameras)))
    print(string.format("  %-15s %s", "Sounds:", format_number(counts.sounds)))
    print(string.rep("-", 60))
    print(string.format("  %-15s \027[1;32m%s\027[0m", "TOTAL:", format_number(total)))
    print()

    print("\027[1mRegistry Features:\027[0m")
    print()
    print("  \027[32m•\027[0m Lookup by creation_id: registry:get_by_creation_id(123)")
    print("  \027[32m•\027[0m Lookup by name:        registry:get_by_name(\"Camera 001\")")
    print("  \027[32m•\027[0m Map convenience:       map:get_unit(id), map:get_camera(name)")
    print()

    -- Demonstrate lookup if doodads exist
    if #map.registry.doodads > 0 then
        local first = map.registry.doodads[1]
        local id = first.creation_id or first.creation_number
        if id then
            local found = map.registry:get_by_creation_id(id)
            print("\027[1mLookup Example:\027[0m")
            print(string.format("  registry:get_by_creation_id(%d) -> %s", id, found.id))
        end
    end

    wait_key()
end
-- }}}

-- {{{ demo_spatial
-- Demonstrate spatial queries
local function demo_spatial()
    clear_screen()
    print_header()
    print("\027[1;33mDemonstration: Spatial Queries\027[0m")
    print()

    local maps_dir = DIR .. "/assets"
    local map_files = list_files(maps_dir, "%.w3[xm]$")

    -- Load a map with many doodads
    local map = data.load(maps_dir .. "/" .. map_files[2]) -- DAoW-5.2 has many

    print(string.format("Map: \027[1m%s\027[0m", map:get_display_name()))
    print(string.format("Total Doodads: %s", format_number(map.registry.counts.doodads)))
    print()

    -- Enable spatial indexing
    print("Enabling spatial index...")
    local start_time = os.clock()
    map.registry:enable_spatial_index(512)  -- 512 unit cell size
    local index_time = os.clock() - start_time
    print(string.format("\027[32mIndexed in %.3f seconds\027[0m", index_time))
    print()

    -- Find center of map based on doodad positions
    local sum_x, sum_y = 0, 0
    for i = 1, math.min(100, #map.registry.doodads) do
        sum_x = sum_x + map.registry.doodads[i].position.x
        sum_y = sum_y + map.registry.doodads[i].position.y
    end
    local center_x = sum_x / math.min(100, #map.registry.doodads)
    local center_y = sum_y / math.min(100, #map.registry.doodads)

    print("\027[1mSpatial Query Examples:\027[0m")
    print(string.rep("-", 60))

    -- Query different radii
    local radii = {500, 1000, 2000, 5000}
    for _, radius in ipairs(radii) do
        local query_start = os.clock()
        local nearby = map.registry:get_objects_in_radius(center_x, center_y, radius)
        local query_time = os.clock() - query_start

        print(string.format("  Radius %5d: %5d objects found (%.4fs)",
            radius, #nearby, query_time))
    end

    print()
    print("\027[1mSpatial Index Info:\027[0m")
    local info = map.registry.spatial:debug_info()
    print(string.format("  Cell Size:       %d units", info.cell_size))
    print(string.format("  Non-empty Cells: %d", info.cell_count))
    print(string.format("  Avg per Cell:    %.1f objects", info.avg_per_cell))
    print(string.format("  Max per Cell:    %d objects", info.max_per_cell))

    wait_key()
end
-- }}}

-- {{{ demo_gameobjects
-- Demonstrate gameobjects class wrappers
local function demo_gameobjects()
    clear_screen()
    print_header()
    print("\027[1;33mDemonstration: Gameobjects Classes\027[0m")
    print()

    print("The gameobjects module provides class wrappers for parsed data,")
    print("adding type-specific methods and consistent interfaces.")
    print()

    print("\027[1mAvailable Classes:\027[0m")
    print(string.rep("-", 60))
    print()

    -- Doodad example
    print("  \027[1;36mDoodad\027[0m")
    local doodad = gameobjects.Doodad.new({
        id = "LTlt",
        position = {x = 100, y = 200, z = 0},
        flags = 2,
        life = 100,
    })
    print(string.format("    %s", tostring(doodad)))
    print(string.format("    is_visible() = %s, is_solid() = %s",
        tostring(doodad:is_visible()), tostring(doodad:is_solid())))
    print()

    -- Unit example
    print("  \027[1;36mUnit\027[0m")
    local unit = gameobjects.Unit.new({
        id = "Hamg",  -- Archmage (hero)
        position = {x = 500, y = 600, z = 0},
        player = 0,
        hero_level = 5,
    })
    print(string.format("    %s", tostring(unit)))
    print(string.format("    is_hero() = %s, get_hero_level() = %d",
        tostring(unit:is_hero()), unit:get_hero_level()))
    print()

    -- Region example
    print("  \027[1;36mRegion\027[0m")
    local region = gameobjects.Region.new({
        name = "spawn_zone",
        bounds = {left = -512, bottom = -256, right = 512, top = 256},
        weather_id = "RAhr",
    })
    print(string.format("    %s", tostring(region)))
    local center = region:get_center()
    print(string.format("    get_center() = (%.0f, %.0f)", center.x, center.y))
    print(string.format("    has_weather() = %s", tostring(region:has_weather())))
    print()

    -- Camera example
    print("  \027[1;36mCamera\027[0m")
    local camera = gameobjects.Camera.new({
        name = "intro_cam",
        target = {x = 0, y = 0},
        rotation = 90,
        aoa = 60,
        distance = 2000,
        fov = 70,
    })
    print(string.format("    %s", tostring(camera)))
    local eye = camera:get_eye_position()
    print(string.format("    get_eye_position() = (%.0f, %.0f, %.0f)", eye.x, eye.y, eye.z))
    print()

    -- Sound example
    print("  \027[1;36mSound\027[0m")
    local sound = gameobjects.Sound.new({
        name = "ambient_rain",
        file = "Sound\\Ambient\\RainLoop.wav",
        volume = 80,
        flags = 3,  -- looping + 3D
    })
    print(string.format("    %s", tostring(sound)))
    print(string.format("    is_looping() = %s, is_3d() = %s",
        tostring(sound:is_looping()), tostring(sound:is_3d())))

    wait_key()
end
-- }}}

-- {{{ demo_all_maps_summary
-- Show all maps registry summary
local function demo_all_maps_summary()
    clear_screen()
    print_header()
    print("\027[1;33mAll Test Maps - Game Objects Summary\027[0m")
    print()

    local maps_dir = DIR .. "/assets"
    local map_files = list_files(maps_dir, "%.w3[xm]$")

    local totals = {
        doodads = 0, units = 0, regions = 0, cameras = 0, sounds = 0
    }
    local successful = 0

    print(string.format("%-35s %8s %5s %4s %4s %4s",
        "Map Name", "Doodads", "Units", "Rgns", "Cams", "Snds"))
    print(string.rep("-", 72))

    for _, filename in ipairs(map_files) do
        local path = maps_dir .. "/" .. filename
        local ok, map = pcall(data.load, path)
        if ok and map and map.registry then
            successful = successful + 1
            local c = map.registry.counts
            totals.doodads = totals.doodads + c.doodads
            totals.units = totals.units + c.units
            totals.regions = totals.regions + c.regions
            totals.cameras = totals.cameras + c.cameras
            totals.sounds = totals.sounds + c.sounds

            local name = map:get_display_name():sub(1, 35)
            print(string.format("\027[32m%-35s\027[0m %8d %5d %4d %4d %4d",
                name, c.doodads, c.units, c.regions, c.cameras, c.sounds))
        else
            print(string.format("\027[31m%-35s\027[0m FAILED", filename:sub(1, 35)))
        end
    end

    print(string.rep("-", 72))
    print(string.format("\027[1m%-35s %8s %5d %4d %4d %4d\027[0m",
        string.format("TOTALS (%d maps)", successful),
        format_number(totals.doodads), totals.units, totals.regions,
        totals.cameras, totals.sounds))
    print()

    local grand_total = totals.doodads + totals.units + totals.regions +
                       totals.cameras + totals.sounds
    print(string.format("Grand Total Objects: \027[1;32m%s\027[0m", format_number(grand_total)))

    wait_key()
end
-- }}}

-- {{{ demo_summary
-- Show summary and next steps
local function demo_summary()
    clear_screen()
    print_header()
    print("\027[1;33mPhase 2 Complete - Summary\027[0m")
    print()
    print("Phase 2 has built the data model for WC3 game objects:")
    print()
    print("  \027[32m+\027[0m Doodad parsing with visibility/solidity flags")
    print("  \027[32m+\027[0m Unit parsing with hero detection and item drops")
    print("  \027[32m+\027[0m Region parsing with weather and ambient sounds")
    print("  \027[32m+\027[0m Camera parsing with eye position calculation")
    print("  \027[32m+\027[0m Sound parsing with 3D positioning data")
    print("  \027[32m+\027[0m Object registry with indexed lookups")
    print("  \027[32m+\027[0m Spatial index for proximity queries")
    print("  \027[32m+\027[0m Gameobjects class wrappers")
    print()
    print("\027[1mIntegration with Phase 1:\027[0m")
    print("  Map.load() now automatically populates the registry")
    print("  with all parsed game objects, ready for queries.")
    print()
    print("\027[1mNext Phase: Logic Layer - Triggers and JASS\027[0m")
    print("  - Parse trigger definitions (war3map.wtg)")
    print("  - Parse custom text triggers (war3map.wct)")
    print("  - Build JASS lexer and parser")
    print("  - Create JASS-to-Lua transpiler")
    print("  - Implement trigger framework")
    print()
    print(string.rep("=", 60))
    print()
    print("\027[1;35mThank you for viewing the Phase 2 Demo!\027[0m")
    print()
end
-- }}}

-- {{{ main
-- Main entry point
local function main()
    -- Check for non-interactive mode
    if arg[1] == "-n" or arg[1] == "--non-interactive" then
        print_header()
        print("Phase 2 Demo - Non-interactive mode")
        print()

        local maps_dir = DIR .. "/assets"
        local map_files = list_files(maps_dir, "%.w3[xm]$")
        local successful = 0
        local total_objects = 0

        for _, filename in ipairs(map_files) do
            local path = maps_dir .. "/" .. filename
            local ok, map = pcall(data.load, path)
            if ok and map and map.registry then
                successful = successful + 1
                total_objects = total_objects + map.registry:get_total_count()
                print(string.format("  [OK] %s - %d objects",
                    filename, map.registry:get_total_count()))
            else
                print(string.format("  [FAIL] %s", filename))
            end
        end

        print()
        print(string.format("Result: %d/%d maps loaded, %s total objects",
            successful, #map_files, format_number(total_objects)))
        os.exit(successful == #map_files and 0 or 1)
    end

    -- Interactive demo
    demo_overview()
    demo_doodad_stats()
    demo_unit_parsing()
    demo_registry()
    demo_spatial()
    demo_gameobjects()
    demo_all_maps_summary()
    demo_summary()
end
-- }}}

main()

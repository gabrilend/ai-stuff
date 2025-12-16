#!/usr/bin/env lua
-- phase1_demo.lua
-- Demonstrates Phase 1 capabilities: WC3 map file parsing
--
-- This demo shows the complete file format parsing capability built in Phase 1:
-- - MPQ archive reading
-- - W3I map info parsing
-- - WTS trigger string resolution
-- - W3E terrain data extraction
-- - Unified Map data structure

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local data = require("data")

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

-- {{{ format_size
-- Format byte size as human readable
local function format_size(bytes)
    if bytes < 1024 then
        return string.format("%d B", bytes)
    elseif bytes < 1024 * 1024 then
        return string.format("%.1f KB", bytes / 1024)
    else
        return string.format("%.1f MB", bytes / (1024 * 1024))
    end
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
    print("\027[1;36m" .. string.rep("=", 72) .. "\027[0m")
    print("\027[1;36m" .. "     WORLD EDIT TO EXECUTE - PHASE 1 DEMO" .. "\027[0m")
    print("\027[1;36m" .. "     File Format Parsing Complete" .. "\027[0m")
    print("\027[1;36m" .. string.rep("=", 72) .. "\027[0m")
    print()
end
-- }}}

-- {{{ demo_overview
-- Show overview of Phase 1 capabilities
local function demo_overview()
    print_header()
    print("\027[1;33mPhase 1 - Foundation: File Format Parsing\027[0m")
    print()
    print("This phase established the ability to read and understand Warcraft 3")
    print("map files (.w3x). Like an emulator reading ROM files, this engine can")
    print("now extract and interpret the data structures within WC3 maps.")
    print()
    print("\027[1mCapabilities demonstrated:\027[0m")
    print()
    print("  \027[32m[1]\027[0m MPQ Archive Parsing")
    print("      - HM3W wrapper detection and offset calculation")
    print("      - Hash table parsing with encrypted entries")
    print("      - Block table parsing for file locations")
    print("      - File extraction with zlib decompression")
    print()
    print("  \027[32m[2]\027[0m Map Info Parsing (war3map.w3i)")
    print("      - Map name, author, description")
    print("      - Player configurations and starting positions")
    print("      - Force definitions and alliance settings")
    print("      - Map dimensions and tileset")
    print()
    print("  \027[32m[3]\027[0m String Table Parsing (war3map.wts)")
    print("      - TRIGSTR_xxx reference resolution")
    print("      - Localized text extraction")
    print()
    print("  \027[32m[4]\027[0m Terrain Parsing (war3map.w3e)")
    print("      - Height map data")
    print("      - Water and cliff information")
    print("      - Texture layers and tilesets")
    print()
    print("  \027[32m[5]\027[0m Unified Map Data Structure")
    print("      - Single Map.load() API")
    print("      - Integrated string resolution")
    print("      - Coordinate conversion utilities")
    print()
    wait_key()
end
-- }}}

-- {{{ demo_map_loading
-- Demonstrate map loading
local function demo_map_loading()
    clear_screen()
    print_header()
    print("\027[1;33mDemonstration: Loading WC3 Map Files\027[0m")
    print()

    local maps_dir = DIR .. "/assets"
    local map_files = list_files(maps_dir, "%.w3[xm]$")

    print(string.format("Found \027[1m%d\027[0m map files in assets/", #map_files))
    print()

    -- Load first map as example
    local example_file = map_files[1]
    if not example_file then
        print("\027[31mNo map files found!\027[0m")
        return
    end

    local path = maps_dir .. "/" .. example_file
    print(string.format("Loading: \027[1m%s\027[0m", example_file))
    print()

    local start_time = os.clock()
    local map = data.load(path)
    local load_time = os.clock() - start_time

    print(string.format("\027[32mLoaded in %.2f seconds\027[0m", load_time))
    print()

    -- Show map info
    print(string.rep("-", 60))
    print("\027[1mMap Information:\027[0m")
    print(string.rep("-", 60))
    print(string.format("  Name:        %s", map:get_display_name()))
    print(string.format("  Author:      %s", map:get_display_author()))
    print(string.format("  Dimensions:  %dx%d tiles", map.width, map.height))
    print(string.format("  Tileset:     %s", map.tileset))

    wait_key()
end
-- }}}

-- {{{ demo_player_info
-- Demonstrate player/force extraction
local function demo_player_info()
    clear_screen()
    print_header()
    print("\027[1;33mDemonstration: Player and Force Configuration\027[0m")
    print()

    -- Load a map with interesting player setup
    local path = DIR .. "/assets/DAoW-5.2.w3x"
    local map = data.load(path)

    print(string.format("Map: \027[1m%s\027[0m", map:get_display_name()))
    print()

    -- Player colors
    local PLAYER_COLORS = {
        [0]  = "Red",      [1]  = "Blue",     [2]  = "Teal",     [3]  = "Purple",
        [4]  = "Yellow",   [5]  = "Orange",   [6]  = "Green",    [7]  = "Pink",
        [8]  = "Gray",     [9]  = "Lt Blue",  [10] = "Dk Green", [11] = "Brown"
    }

    print(string.format("Players: \027[1m%d\027[0m", #map.players))
    print(string.rep("-", 60))

    for _, player in ipairs(map.players) do
        local num = player.number or player.id or 0
        local color = PLAYER_COLORS[num] or "Unknown"
        local name = map:resolve_string(player.name) or player.name or "?"
        local race = player.race or "?"
        local start_x = player.start_x or 0
        local start_y = player.start_y or 0

        print(string.format("  [\027[1;33m%2d\027[0m] %-8s %-25s (%s)",
            num, color, name:sub(1,25), race))
        print(string.format("       Start: (%.0f, %.0f)", start_x, start_y))
    end

    print()
    print(string.format("Forces: \027[1m%d\027[0m", #map.forces))
    print(string.rep("-", 60))

    for _, force in ipairs(map.forces) do
        local name = map:resolve_string(force.name) or force.name or "?"
        local flags = force.flags or {}
        print(string.format("  Force %d: %s", force.index or 0, name))
        if flags.allied then
            print("           Allied: yes")
        end
    end

    wait_key()
end
-- }}}

-- {{{ demo_terrain
-- Demonstrate terrain data
local function demo_terrain()
    clear_screen()
    print_header()
    print("\027[1;33mDemonstration: Terrain Data Extraction\027[0m")
    print()

    local path = DIR .. "/assets/DAoW-5.3.w3x"
    local map = data.load(path)

    print(string.format("Map: \027[1m%s\027[0m", map:get_display_name()))
    print()

    if not map.terrain then
        print("\027[31mNo terrain data available\027[0m")
        return
    end

    local stats = map.terrain:stats()

    print("\027[1mTerrain Statistics:\027[0m")
    print(string.rep("-", 60))
    print(string.format("  Grid Size:      %d x %d", map.terrain.width, map.terrain.height))
    print(string.format("  Total Tiles:    %s", string.format("%d", stats.total_tilepoints)))
    print(string.format("  Water Tiles:    %d (%.1f%%)",
        stats.water_count,
        stats.water_count / stats.total_tilepoints * 100))
    print(string.format("  Blight Tiles:   %d (%.1f%%)",
        stats.blight_count,
        stats.blight_count / stats.total_tilepoints * 100))
    print(string.format("  Ramp Tiles:     %d", stats.ramp_count))
    print(string.format("  Height Range:   %.1f to %.1f",
        stats.min_height, stats.max_height))

    -- Show sample terrain at center
    print()
    print("\027[1mTerrain Sample (center of map):\027[0m")
    print(string.rep("-", 60))

    local cx = math.floor(map.terrain.width / 2)
    local cy = math.floor(map.terrain.height / 2)

    -- Show 5x5 grid around center
    print()
    print("  Height map (5x5 around center):")
    print()
    for dy = -2, 2 do
        local row = "    "
        for dx = -2, 2 do
            local tile = map.terrain:get_tile(cx + dx, cy + dy)
            if tile then
                local h = tile.height
                -- Color code by height
                local color
                if h < -100 then color = "\027[34m"  -- blue (low)
                elseif h < 0 then color = "\027[36m"  -- cyan
                elseif h < 100 then color = "\027[32m"  -- green
                elseif h < 200 then color = "\027[33m"  -- yellow
                else color = "\027[31m" end  -- red (high)
                row = row .. string.format("%s%4.0f\027[0m ", color, h)
            else
                row = row .. "   ? "
            end
        end
        print(row)
    end

    print()
    print("  Legend: \027[34mlow\027[0m < \027[36m0\027[0m < \027[32mmedium\027[0m < \027[33mhigh\027[0m < \027[31mvery high\027[0m")

    wait_key()
end
-- }}}

-- {{{ demo_string_resolution
-- Demonstrate TRIGSTR resolution
local function demo_string_resolution()
    clear_screen()
    print_header()
    print("\027[1;33mDemonstration: TRIGSTR Resolution\027[0m")
    print()

    local path = DIR .. "/assets/DAoW-2.1.w3x"
    local map = data.load(path)

    print("WC3 maps use TRIGSTR_xxx references for localized text.")
    print("The .wts file contains the actual text for each reference.")
    print()

    if not map.strings then
        print("\027[31mNo string table available\027[0m")
        return
    end

    print(string.format("String table entries: \027[1m%d\027[0m", map.strings:count()))
    print()

    print("\027[1mExamples:\027[0m")
    print(string.rep("-", 60))

    -- Show some raw vs resolved strings
    local examples = {
        {raw = "TRIGSTR_199", desc = "Map name"},
        {raw = "TRIGSTR_200", desc = "Suggested players"},
        {raw = "TRIGSTR_402", desc = "Player name"},
    }

    for _, ex in ipairs(examples) do
        local resolved = map:resolve_string(ex.raw)
        print(string.format("  %s (%s):", ex.raw, ex.desc))
        print(string.format("    -> \027[32m%s\027[0m", resolved:sub(1,60)))
        print()
    end

    wait_key()
end
-- }}}

-- {{{ demo_all_maps
-- Show all loaded maps
local function demo_all_maps()
    clear_screen()
    print_header()
    print("\027[1;33mAll Test Maps Summary\027[0m")
    print()

    local maps_dir = DIR .. "/assets"
    local map_files = list_files(maps_dir, "%.w3[xm]$")

    local total_tiles = 0
    local total_players = 0
    local successful = 0

    for i, filename in ipairs(map_files) do
        local path = maps_dir .. "/" .. filename

        local ok, map = pcall(data.load, path)
        if ok and map then
            successful = successful + 1
            total_players = total_players + #map.players

            local tiles = 0
            if map.terrain then
                tiles = map.terrain.width * map.terrain.height
                total_tiles = total_tiles + tiles
            end

            print(string.format("\027[32m[%2d]\027[0m %-35s %dx%d  %2d players",
                i, map:get_display_name():sub(1,35),
                map.width, map.height, #map.players))
        else
            print(string.format("\027[31m[%2d]\027[0m %-35s FAILED", i, filename:sub(1,35)))
        end
    end

    print()
    print(string.rep("-", 60))
    print(string.format("Successfully loaded: \027[1m%d/%d\027[0m maps",
        successful, #map_files))
    print(string.format("Total terrain tiles: \027[1m%.1fM\027[0m", total_tiles / 1000000))
    print(string.format("Total players:       \027[1m%d\027[0m", total_players))

    wait_key()
end
-- }}}

-- {{{ demo_summary
-- Show summary and next steps
local function demo_summary()
    clear_screen()
    print_header()
    print("\027[1;33mPhase 1 Complete - Summary\027[0m")
    print()
    print("Phase 1 has established the foundation for the WC3 map engine:")
    print()
    print("  \027[32m+\027[0m MPQ archive parsing with hash/block tables")
    print("  \027[32m+\027[0m Map metadata extraction (name, author, players)")
    print("  \027[32m+\027[0m Trigger string resolution (TRIGSTR_xxx)")
    print("  \027[32m+\027[0m Terrain data parsing (heights, water, cliffs)")
    print("  \027[32m+\027[0m Unified Map data structure API")
    print("  \027[32m+\027[0m CLI tool for map inspection (mapdump.lua)")
    print()
    print("\027[1mKnown Limitations:\027[0m")
    print("  \027[33m-\027[0m PKWARE DCL compression not yet implemented")
    print("  \027[33m-\027[0m Some older maps may not be fully supported")
    print()
    print("\027[1mNext Phase: Data Model - Game Objects\027[0m")
    print("  - Parse doodads and decorations")
    print("  - Parse unit and building placements")
    print("  - Parse regions, cameras, and sounds")
    print("  - Build object registry system")
    print()
    print(string.rep("=", 60))
    print()
    print("\027[1;36mThank you for viewing the Phase 1 Demo!\027[0m")
    print()
end
-- }}}

-- {{{ main
-- Main entry point
local function main()
    -- Check for non-interactive mode
    if arg[1] == "-n" or arg[1] == "--non-interactive" then
        print_header()
        print("Phase 1 Demo - Non-interactive mode")
        print()

        local maps_dir = DIR .. "/assets"
        local map_files = list_files(maps_dir, "%.w3[xm]$")
        local successful = 0

        for _, filename in ipairs(map_files) do
            local path = maps_dir .. "/" .. filename
            local ok, map = pcall(data.load, path)
            if ok and map then
                successful = successful + 1
                print(string.format("  [OK] %s - %s",
                    filename, map:get_display_name()))
            else
                print(string.format("  [FAIL] %s", filename))
            end
        end

        print()
        print(string.format("Result: %d/%d maps loaded successfully",
            successful, #map_files))
        os.exit(successful == #map_files and 0 or 1)
    end

    -- Interactive demo
    demo_overview()
    demo_map_loading()
    demo_player_info()
    demo_terrain()
    demo_string_resolution()
    demo_all_maps()
    demo_summary()
end
-- }}}

main()

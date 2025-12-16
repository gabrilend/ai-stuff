#!/usr/bin/env lua
-- Test suite for unified Map data structure
-- Tests Map.load() and all accessor methods.
-- Run from project root: lua5.4 src/tests/test_data.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local data = require("data")

-- {{{ Test configuration
local TEST_MAPS_DIR = DIR .. "/assets"
local VERBOSE = os.getenv("VERBOSE") == "1"
-- }}}

-- {{{ Utility functions
-- {{{ log
local function log(...)
    if VERBOSE then
        print(...)
    end
end
-- }}}

-- {{{ get_map_files
local function get_map_files()
    local files = {}
    local handle = io.popen('ls "' .. TEST_MAPS_DIR .. '"/*.w3x 2>/dev/null')
    if handle then
        for line in handle:lines() do
            files[#files + 1] = line
        end
        handle:close()
    end
    return files
end
-- }}}
-- }}}

-- {{{ Test cases
-- {{{ test_player_colors
local function test_player_colors()
    print("Testing player colors...")

    assert(data.PLAYER_COLORS[0].name == "Red", "Player 0 should be Red")
    assert(data.PLAYER_COLORS[1].name == "Blue", "Player 1 should be Blue")
    assert(data.PLAYER_COLORS[0].r == 255, "Red should have r=255")
    assert(#data.PLAYER_COLORS + 1 >= 12, "Should have at least 12 colors")

    print("  PASS: Player colors defined")
end
-- }}}

-- {{{ test_map_new
local function test_map_new()
    print("Testing Map.new()...")

    local map = data.Map.new()
    assert(map.name == "", "Default name should be empty")
    assert(map.players ~= nil, "Players should be initialized")
    assert(map.terrain == nil, "Terrain should be nil initially")
    assert(map.strings == nil, "Strings should be nil initially")

    print("  PASS: Map.new() creates empty map")
end
-- }}}

-- {{{ test_map_load
local function test_map_load()
    print("Testing Map.load()...")

    local map_files = get_map_files()
    if #map_files == 0 then
        print("  SKIP: No test maps found")
        return
    end

    local passed = 0
    local failed = 0

    for _, map_path in ipairs(map_files) do
        local map_name = map_path:match("([^/]+)$")
        log("  Loading:", map_name)

        local ok, map = pcall(data.load, map_path)
        if not ok then
            log("    FAIL: Cannot load -", map)
            failed = failed + 1
            goto continue
        end

        -- Validate basic properties
        assert(map.source_path == map_path, "source_path should be set")

        -- Test display name resolution
        local display_name = map:get_display_name()
        log(string.format("    Name: %s -> %s", map.name, display_name))

        -- Test player access
        local player_count = map:player_count()
        log(string.format("    Players: %d", player_count))

        -- Test terrain access (if loaded)
        if map.terrain then
            local height = map:get_height(0, 0)
            log(string.format("    Terrain: %dx%d, height[0,0]=%.1f",
                map.terrain.width, map.terrain.height, height or 0))
        else
            log("    Terrain: Not loaded")
        end

        -- Test coordinate conversion (round-trip)
        local world = map:tile_to_world(10, 10)
        assert(world.x ~= nil, "tile_to_world should return x")
        assert(world.y ~= nil, "tile_to_world should return y")

        -- Convert back - should get same tile (or close)
        local tile_back = map:world_to_tile(world.x, world.y)
        assert(tile_back.x == 10, "Round-trip should preserve x")
        assert(tile_back.y == 10, "Round-trip should preserve y")

        passed = passed + 1
        ::continue::
    end

    print(string.format("  Results: %d passed, %d failed", passed, failed))
    if failed == 0 then
        print("  PASS: All maps loaded successfully")
    else
        print("  PARTIAL: Some maps failed")
    end
end
-- }}}

-- {{{ test_info_method
local function test_info_method()
    print("Testing Map:info()...")

    local map_files = get_map_files()
    if #map_files == 0 then
        print("  SKIP: No test maps")
        return
    end

    local map = data.load(map_files[1])
    local info = map:info()

    assert(info.name ~= nil, "info should have name")
    assert(info.dimensions ~= nil, "info should have dimensions")
    assert(info.dimensions.width ~= nil, "dimensions should have width")
    assert(info.player_count ~= nil, "info should have player_count")
    assert(info.has_terrain ~= nil, "info should have has_terrain")

    print("  PASS: Map:info() works")
end
-- }}}

-- {{{ test_format_output
local function test_format_output()
    print("Testing format output...")

    local map_files = get_map_files()
    if #map_files == 0 then
        print("  SKIP: No test maps")
        return
    end

    local map = data.load(map_files[1])
    local formatted = data.format(map)

    assert(formatted:find("Map Info"), "Should have title")
    assert(formatted:find("Name:"), "Should have name")
    assert(formatted:find("Players"), "Should have players section")
    assert(formatted:find("Terrain"), "Should have terrain section")

    if VERBOSE then
        print(formatted)
    end

    print("  PASS: Format output works")
end
-- }}}

-- {{{ test_string_resolution
local function test_string_resolution()
    print("Testing string resolution...")

    local map_files = get_map_files()
    if #map_files == 0 then
        print("  SKIP: No test maps")
        return
    end

    -- Find a map with TRIGSTR in its name
    local found_trigstr = false
    for _, map_path in ipairs(map_files) do
        local map = data.load(map_path)
        if map.name:find("TRIGSTR") then
            local resolved = map:get_display_name()
            assert(not resolved:find("TRIGSTR"), "TRIGSTR should be resolved")
            log(string.format("  %s -> %s", map.name, resolved))
            found_trigstr = true
            break
        end
    end

    if found_trigstr then
        print("  PASS: TRIGSTR resolution works")
    else
        print("  SKIP: No maps with TRIGSTR in name")
    end
end
-- }}}

-- {{{ test_player_access
local function test_player_access()
    print("Testing player access...")

    local map_files = get_map_files()
    if #map_files == 0 then
        print("  SKIP: No test maps")
        return
    end

    local map = data.load(map_files[1])

    if map:player_count() > 0 then
        local player_num = map.players[1].number or map.players[1].id or 0
        local player = map:get_player(player_num)
        assert(player ~= nil, "Should get player by number")

        local color = map:get_player_color(player_num)
        assert(color ~= nil, "Should get player color")
        assert(color.name ~= nil, "Color should have name")

        log(string.format("  Player %d: %s (%s)", player_num, player.name or "", color.name))
        print("  PASS: Player access works")
    else
        print("  SKIP: No players in map")
    end
end
-- }}}

-- {{{ test_terrain_access
local function test_terrain_access()
    print("Testing terrain access...")

    local map_files = get_map_files()
    if #map_files == 0 then
        print("  SKIP: No test maps")
        return
    end

    local map = data.load(map_files[1])

    if map.terrain then
        -- Test height access
        local height = map:get_height(10, 10)
        assert(height ~= nil, "Should get height at valid coords")

        -- Test walkable check
        local walkable = map:is_walkable(10, 10)
        assert(walkable ~= nil, "is_walkable should return boolean")

        -- Test water check
        local water = map:is_water(10, 10)
        assert(water ~= nil, "is_water should return boolean")

        -- Test tile access
        local tile = map:get_tile(10, 10)
        assert(tile ~= nil, "Should get tile data")
        assert(tile.height ~= nil, "Tile should have height")

        -- Test out of bounds
        local nil_height = map:get_height(-1, -1)
        assert(nil_height == nil, "Out of bounds should return nil")

        log(string.format("  Height at (10,10): %.1f, walkable: %s, water: %s",
            height, tostring(walkable), tostring(water)))
        print("  PASS: Terrain access works")
    else
        print("  SKIP: No terrain in map")
    end
end
-- }}}
-- }}}

-- {{{ Main
local function main()
    print("=== Map Data Structure Tests ===\n")

    test_player_colors()
    test_map_new()
    test_map_load()
    test_info_method()
    test_format_output()
    test_string_resolution()
    test_player_access()
    test_terrain_access()

    print("\n=== All tests completed ===")
end

main()
-- }}}

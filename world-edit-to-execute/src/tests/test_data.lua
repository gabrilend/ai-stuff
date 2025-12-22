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

-- {{{ test_registry_creation
local function test_registry_creation()
    print("Testing registry creation...")

    -- Empty map should have nil registry
    local empty_map = data.Map.new()
    assert(empty_map.registry == nil, "Empty map should have nil registry")

    -- Loaded map should have registry
    local map_files = get_map_files()
    if #map_files == 0 then
        print("  SKIP: No test maps")
        return
    end

    local map = data.load(map_files[1])
    assert(map.registry ~= nil, "Loaded map should have registry")
    assert(map.registry.counts ~= nil, "Registry should have counts")

    print("  PASS: Registry creation works")
end
-- }}}

-- {{{ test_registry_population
local function test_registry_population()
    print("Testing registry population...")

    local map_files = get_map_files()
    if #map_files == 0 then
        print("  SKIP: No test maps")
        return
    end

    local map = data.load(map_files[1])
    local counts = map.registry.counts
    local total = map.registry:get_total_count()

    log(string.format("  Doodads: %d", counts.doodads))
    log(string.format("  Units: %d", counts.units))
    log(string.format("  Regions: %d", counts.regions))
    log(string.format("  Cameras: %d", counts.cameras))
    log(string.format("  Sounds: %d", counts.sounds))
    log(string.format("  Total: %d", total))

    -- Verify counts match arrays
    assert(counts.doodads == #map.registry.doodads, "Doodad count mismatch")
    assert(counts.units == #map.registry.units, "Unit count mismatch")
    assert(counts.regions == #map.registry.regions, "Region count mismatch")
    assert(counts.cameras == #map.registry.cameras, "Camera count mismatch")
    assert(counts.sounds == #map.registry.sounds, "Sound count mismatch")

    -- Verify total
    local expected_total = counts.doodads + counts.units + counts.regions + counts.cameras + counts.sounds
    assert(total == expected_total, "Total count mismatch")

    print("  PASS: Registry population works")
end
-- }}}

-- {{{ test_registry_convenience_methods
local function test_registry_convenience_methods()
    print("Testing registry convenience methods...")

    local map_files = get_map_files()
    if #map_files == 0 then
        print("  SKIP: No test maps")
        return
    end

    local map = data.load(map_files[1])
    local tests_run = 0

    -- Test get_unit with actual unit creation_number if any exist
    if #map.registry.units > 0 then
        local first_unit = map.registry.units[1]
        local creation_id = first_unit.creation_id or first_unit.creation_number
        if creation_id then
            local found = map:get_unit(creation_id)
            assert(found ~= nil, "Should find unit by creation_id")
            assert(found == first_unit, "Should return same object reference")
            tests_run = tests_run + 1
        end
    end

    -- Test get_region with actual region if any exist
    if #map.registry.regions > 0 then
        local first_region = map.registry.regions[1]
        local creation_id = first_region.creation_id or first_region.creation_number
        if creation_id then
            local found = map:get_region(creation_id)
            assert(found ~= nil, "Should find region by creation_id")
            tests_run = tests_run + 1
        end
        -- Also test by name if available
        if first_region.name and first_region.name ~= "" then
            local found_by_name = map:get_region(first_region.name)
            assert(found_by_name ~= nil, "Should find region by name")
            tests_run = tests_run + 1
        end
    end

    -- Test get_camera with actual camera if any exist
    if #map.registry.cameras > 0 then
        local first_camera = map.registry.cameras[1]
        if first_camera.name and first_camera.name ~= "" then
            local found = map:get_camera(first_camera.name)
            assert(found ~= nil, "Should find camera by name")
            assert(found == first_camera, "Should return same object reference")
            tests_run = tests_run + 1
        end
    end

    -- Test lookup for non-existent returns nil
    local missing = map:get_unit(-99999)
    assert(missing == nil, "Non-existent should return nil")

    if tests_run > 0 then
        print(string.format("  PASS: Registry convenience methods work (%d tests)", tests_run))
    else
        print("  SKIP: No objects with IDs/names to test")
    end
end
-- }}}

-- {{{ test_registry_info_output
local function test_registry_info_output()
    print("Testing registry info output...")

    local map_files = get_map_files()
    if #map_files == 0 then
        print("  SKIP: No test maps")
        return
    end

    local map = data.load(map_files[1])
    local info = map:info()

    -- Check has_registry flag
    assert(info.has_registry == true, "info should have has_registry=true")

    -- Check object_counts
    assert(info.object_counts ~= nil, "info should have object_counts")
    assert(info.object_counts.doodads ~= nil, "object_counts should have doodads")
    assert(info.object_counts.units ~= nil, "object_counts should have units")
    assert(info.object_counts.total ~= nil, "object_counts should have total")

    -- Verify counts match registry
    assert(info.object_counts.doodads == map.registry.counts.doodads, "info doodads should match")
    assert(info.object_counts.total == map.registry:get_total_count(), "info total should match")

    print("  PASS: Registry info output works")
end
-- }}}

-- {{{ test_registry_format_output
local function test_registry_format_output()
    print("Testing registry format output...")

    local map_files = get_map_files()
    if #map_files == 0 then
        print("  SKIP: No test maps")
        return
    end

    local map = data.load(map_files[1])
    local formatted = data.format(map)

    -- Check Game Objects section exists
    assert(formatted:find("Game Objects"), "Should have Game Objects section")
    assert(formatted:find("Doodads:"), "Should have Doodads count")
    assert(formatted:find("Units:"), "Should have Units count")
    assert(formatted:find("Regions:"), "Should have Regions count")
    assert(formatted:find("Cameras:"), "Should have Cameras count")
    assert(formatted:find("Sounds:"), "Should have Sounds count")

    if VERBOSE then
        print("--- Format output ---")
        print(formatted)
        print("---")
    end

    print("  PASS: Registry format output works")
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

    -- Registry integration tests (207e)
    test_registry_creation()
    test_registry_population()
    test_registry_convenience_methods()
    test_registry_info_output()
    test_registry_format_output()

    print("\n=== All tests completed ===")
end

main()
-- }}}

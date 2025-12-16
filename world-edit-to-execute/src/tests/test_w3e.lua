#!/usr/bin/env lua
-- Test suite for w3e (terrain) parser
-- Tests parsing terrain data from real map files.
-- Run from project root: lua5.4 src/tests/test_w3e.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local w3e = require("parsers.w3e")
local mpq = require("mpq")

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
-- {{{ test_decode_height
local function test_decode_height()
    print("Testing height decoding...")

    -- Test formula: (raw - 8192) / 4
    assert(w3e.decode_height(8192) == 0, "8192 should decode to 0")
    assert(w3e.decode_height(8192 + 4) == 1, "8196 should decode to 1")
    assert(w3e.decode_height(8192 - 4) == -1, "8188 should decode to -1")
    assert(w3e.decode_height(8192 + 400) == 100, "8592 should decode to 100")
    assert(w3e.decode_height(0) == -2048, "0 should decode to -2048")

    print("  PASS: Height decoding works")
end
-- }}}

-- {{{ test_decode_water
local function test_decode_water()
    print("Testing water decoding...")

    -- Test water level extraction (14 bits)
    local water = w3e.decode_water(8192)
    assert(water.level == 0, "8192 should decode to level 0")
    assert(water.boundary == false, "No boundary flags")

    -- Test boundary flags (bits 14-15)
    local water_boundary = w3e.decode_water(0x4000 + 8192)  -- Bit 14 set
    assert(water_boundary.boundary == true, "Boundary flag should be set")

    print("  PASS: Water decoding works")
end
-- }}}

-- {{{ test_real_maps
local function test_real_maps()
    print("Testing against real map files...")

    local map_files = get_map_files()
    if #map_files == 0 then
        print("  SKIP: No test maps found")
        return
    end

    local passed = 0
    local failed = 0

    for _, map_path in ipairs(map_files) do
        local map_name = map_path:match("([^/]+)$")
        log("  Testing:", map_name)

        local ok, archive = pcall(mpq.open, map_path)
        if not ok then
            log("    SKIP: Cannot open MPQ -", archive)
            failed = failed + 1
            goto continue
        end

        -- Check if w3e exists
        if not archive:has("war3map.w3e") then
            log("    SKIP: No war3map.w3e in archive")
            failed = failed + 1
            archive:close()
            goto continue
        end

        -- Extract w3e
        local w3e_ok, w3e_data = pcall(archive.extract, archive, "war3map.w3e")
        if not w3e_ok then
            log("    FAIL: Cannot extract w3e -", w3e_data)
            failed = failed + 1
            archive:close()
            goto continue
        end

        -- Parse w3e
        local parse_ok, terrain = pcall(w3e.parse, w3e_data)
        if not parse_ok then
            log("    FAIL: Cannot parse w3e -", terrain)
            failed = failed + 1
            archive:close()
            goto continue
        end

        log(string.format("    Parsed: %dx%d tilepoints, tileset=%s",
            terrain.width, terrain.height, terrain.tileset))

        -- Get stats
        local stats = terrain:stats()
        log(string.format("    Height range: %.1f to %.1f",
            stats.min_height, stats.max_height))
        log(string.format("    Water: %d, Blight: %d, Ramps: %d",
            stats.water_count, stats.blight_count, stats.ramp_count))

        -- Basic validation
        assert(terrain.width > 0, "Width should be positive")
        assert(terrain.height > 0, "Height should be positive")
        assert(terrain.version == 11, "Version should be 11")
        assert(#terrain.ground_tilesets > 0, "Should have ground tilesets")

        -- Test accessor methods
        local tile = terrain:get_tile(0, 0)
        assert(tile ~= nil, "Should get tile at (0,0)")
        assert(terrain:get_height(0, 0) ~= nil, "Should get height at (0,0)")
        assert(terrain:get_tile(-1, -1) == nil, "Out of bounds should return nil")

        passed = passed + 1
        archive:close()
        ::continue::
    end

    print(string.format("  Results: %d passed, %d failed", passed, failed))
    if failed == 0 then
        print("  PASS: All maps parsed successfully")
    else
        print("  PARTIAL: Some maps failed")
    end
end
-- }}}

-- {{{ test_coordinate_conversion
local function test_coordinate_conversion()
    print("Testing coordinate conversion...")

    -- Create a mock terrain for testing
    local terrain = w3e.Terrain.new()
    terrain.width = 65
    terrain.height = 65
    terrain.offset_x = -4096
    terrain.offset_y = -4096

    -- Test tile to world
    local world = terrain:tile_to_world(0, 0)
    assert(world.x == -4096, "World X at tile 0 should be offset_x")
    assert(world.y == -4096, "World Y at tile 0 should be offset_y")

    local world2 = terrain:tile_to_world(32, 32)
    assert(world2.x == 32 * 128 - 4096, "World X calculation")
    assert(world2.y == 32 * 128 - 4096, "World Y calculation")

    -- Test world to tile
    local tile = terrain:world_to_tile(-4096, -4096)
    assert(tile.x == 0, "Tile X should be 0")
    assert(tile.y == 0, "Tile Y should be 0")

    print("  PASS: Coordinate conversion works")
end
-- }}}

-- {{{ test_format_output
local function test_format_output()
    print("Testing format output...")

    -- Try to parse a real map and format it
    local map_files = get_map_files()
    if #map_files == 0 then
        print("  SKIP: No test maps for format test")
        return
    end

    local archive = mpq.open(map_files[1])
    if not archive:has("war3map.w3e") then
        archive:close()
        print("  SKIP: No w3e in first map")
        return
    end

    local w3e_data = archive:extract("war3map.w3e")
    local terrain = w3e.parse(w3e_data)
    local formatted = w3e.format(terrain)

    assert(formatted:find("Terrain Info"), "Should have title")
    assert(formatted:find("Dimensions:"), "Should have dimensions")
    assert(formatted:find("Ground tilesets"), "Should have ground tilesets")
    assert(formatted:find("Statistics:"), "Should have statistics")

    archive:close()
    print("  PASS: Format output works")
end
-- }}}

-- {{{ test_tileset_lookup
local function test_tileset_lookup()
    print("Testing tileset lookup...")

    assert(w3e.TILESETS['L'] == "lordaeron_summer", "L should be lordaeron_summer")
    assert(w3e.TILESETS['A'] == "ashenvale", "A should be ashenvale")
    assert(w3e.TILESETS['N'] == "northrend", "N should be northrend")
    assert(w3e.TILESETS['Z'] == "sunken_ruins", "Z should be sunken_ruins")

    print("  PASS: Tileset lookup works")
end
-- }}}
-- }}}

-- {{{ Main
local function main()
    print("=== W3E Terrain Parser Tests ===\n")

    test_decode_height()
    test_decode_water()
    test_tileset_lookup()
    test_coordinate_conversion()
    test_format_output()
    test_real_maps()

    print("\n=== All tests completed ===")
end

main()
-- }}}

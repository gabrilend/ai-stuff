-- war3map.w3i Parser Test
-- Tests the w3i parser against real map files.
-- Run from project root: lua5.4 src/tests/test_w3i.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local mpq = require("mpq")
local w3i = require("parsers.w3i")

-- {{{ Test configuration
local TEST_MAP = DIR .. "/assets/DAoW-2.1.w3x"
-- }}}

-- {{{ Utility functions
local function print_separator(title)
    print("\n" .. string.rep("=", 60))
    print(title)
    print(string.rep("=", 60))
end

local function test(name, fn)
    io.write("Testing " .. name .. "... ")
    local ok, err = pcall(fn)
    if ok then
        print("PASS")
        return true
    else
        print("FAIL: " .. tostring(err))
        return false
    end
end
-- }}}

-- {{{ Main test suite
local function run_tests()
    local passed = 0
    local failed = 0

    print_separator("w3i Parser Tests")
    print("Test map: " .. TEST_MAP)

    -- Open archive
    local archive, err = mpq.open(TEST_MAP)
    if not archive then
        print("ERROR: Cannot open test map: " .. err)
        return false
    end

    -- Extract w3i
    local w3i_data, extract_err = archive:extract("war3map.w3i")
    if not w3i_data then
        print("ERROR: Cannot extract war3map.w3i: " .. extract_err)
        archive:close()
        return false
    end

    print("Extracted " .. #w3i_data .. " bytes of w3i data")

    -- Test 1: Parse w3i
    local map
    if test("w3i.parse()", function()
        map = assert(w3i.parse(w3i_data))
    end) then passed = passed + 1 else failed = failed + 1 end

    if not map then
        print("\nCannot continue without parsed map. Aborting.")
        archive:close()
        return false
    end

    -- Test 2: Check basic fields
    if test("Basic fields present", function()
        assert(map.version, "missing version")
        assert(map.name, "missing name")
        assert(map.author, "missing author")
        assert(map.players, "missing players")
        assert(map.forces, "missing forces")
        print("")
        print("  Version: " .. map.version)
        print("  Name: " .. map.name)
        print("  Author: " .. map.author)
    end) then passed = passed + 1 else failed = failed + 1 end

    -- Test 3: Check dimensions
    if test("Map dimensions", function()
        assert(map.width and map.width > 0, "invalid width")
        assert(map.height and map.height > 0, "invalid height")
        assert(map.playable_width, "missing playable_width")
        assert(map.playable_height, "missing playable_height")
        print("")
        print("  Full: " .. map.width .. " x " .. map.height)
        print("  Playable: " .. map.playable_width .. " x " .. map.playable_height)
    end) then passed = passed + 1 else failed = failed + 1 end

    -- Test 4: Check tileset
    if test("Tileset", function()
        assert(map.tileset_code, "missing tileset_code")
        assert(map.tileset, "missing tileset name")
        print("")
        print("  Code: " .. map.tileset_code)
        print("  Name: " .. map.tileset)
    end) then passed = passed + 1 else failed = failed + 1 end

    -- Test 5: Check players
    if test("Player definitions", function()
        assert(#map.players > 0, "no players defined")
        print("")
        print("  Count: " .. #map.players)
        for i, p in ipairs(map.players) do
            print(string.format("    [%d] %s (%s/%s)",
                p.number, p.name, p.type, p.race))
        end
    end) then passed = passed + 1 else failed = failed + 1 end

    -- Test 6: Check forces
    if test("Force definitions", function()
        assert(#map.forces > 0, "no forces defined")
        print("")
        print("  Count: " .. #map.forces)
        for i, f in ipairs(map.forces) do
            print(string.format("    %s: players [%s]",
                f.name, table.concat(f.players, ",")))
        end
    end) then passed = passed + 1 else failed = failed + 1 end

    -- Test 7: Check TFT fields (if version 25)
    if map.version >= 25 then
        if test("TFT-specific fields (v25)", function()
            assert(map.fog, "missing fog settings")
            assert(map.weather, "missing weather")
            print("")
            print("  Fog style: " .. map.fog.style)
            print("  Weather: '" .. map.weather .. "'")
            if map.upgrades then
                print("  Upgrades: " .. #map.upgrades)
            end
            if map.tech then
                print("  Tech: " .. #map.tech)
            end
        end) then passed = passed + 1 else failed = failed + 1 end
    end

    -- Test 8: Format output
    if test("w3i.format()", function()
        local formatted = w3i.format(map)
        assert(formatted and #formatted > 0, "format returned empty")
        print("")
        print("--- Formatted Output Preview ---")
        -- Print first 20 lines
        local lines = 0
        for line in formatted:gmatch("[^\n]+") do
            print("  " .. line)
            lines = lines + 1
            if lines >= 15 then
                print("  ...")
                break
            end
        end
    end) then passed = passed + 1 else failed = failed + 1 end

    archive:close()

    -- Summary
    print_separator("Results")
    print(string.format("Passed: %d / %d", passed, passed + failed))
    if failed > 0 then
        print("SOME TESTS FAILED")
        return false
    else
        print("ALL TESTS PASSED")
        return true
    end
end
-- }}}

-- {{{ Test all maps
local function test_all_maps()
    print_separator("Testing All Available Maps")

    local maps_dir = DIR .. "/assets"
    local handle = io.popen("ls " .. maps_dir .. "/*.w3x 2>/dev/null")
    if not handle then
        print("Cannot list maps directory")
        return
    end

    local maps = {}
    for line in handle:lines() do
        maps[#maps + 1] = line
    end
    handle:close()

    print("Found " .. #maps .. " map files\n")

    local success_count = 0
    local fail_count = 0

    for _, map_path in ipairs(maps) do
        local map_name = map_path:match("([^/]+)$")
        io.write(string.format("%-50s ", map_name))

        local archive, err = mpq.open(map_path)
        if not archive then
            print("OPEN FAIL: " .. err)
            fail_count = fail_count + 1
        else
            local w3i_data, w3i_err = archive:extract("war3map.w3i")
            if not w3i_data then
                print("EXTRACT FAIL: " .. w3i_err)
                fail_count = fail_count + 1
            else
                local map, parse_err = w3i.parse(w3i_data)
                if map then
                    print(string.format("OK v%d \"%s\"", map.version, map.name:sub(1,30)))
                    success_count = success_count + 1
                else
                    print("PARSE FAIL: " .. tostring(parse_err))
                    fail_count = fail_count + 1
                end
            end
            archive:close()
        end
    end

    print("")
    print(string.format("Success: %d / %d", success_count, success_count + fail_count))
end
-- }}}

-- Run the tests
local ok = run_tests()
test_all_maps()
os.exit(ok and 0 or 1)

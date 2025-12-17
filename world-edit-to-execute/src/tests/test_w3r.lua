-- war3map.w3r Parser Test
-- Tests the w3r parser against real map files.
-- Run from project root: lua src/tests/test_w3r.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local mpq = require("mpq")
local w3r = require("parsers.w3r")

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

    print_separator("w3r Parser Tests")
    print("Test map: " .. TEST_MAP)

    -- Open archive
    local archive, err = mpq.open(TEST_MAP)
    if not archive then
        print("ERROR: Cannot open test map: " .. err)
        return false
    end

    -- Check if w3r exists
    if not archive:has("war3map.w3r") then
        print("NOTE: Test map has no war3map.w3r (no regions defined)")
        archive:close()
        -- This is not a failure - map may not have regions
        return true
    end

    -- Extract w3r
    local w3r_data, extract_err = archive:extract("war3map.w3r")
    if not w3r_data then
        print("ERROR: Cannot extract war3map.w3r: " .. extract_err)
        archive:close()
        return false
    end

    print("Extracted " .. #w3r_data .. " bytes of w3r data")

    -- Test 1: Parse w3r
    local result
    if test("w3r.parse()", function()
        result = assert(w3r.parse(w3r_data))
    end) then passed = passed + 1 else failed = failed + 1 end

    if not result then
        print("\nCannot continue without parsed data. Aborting.")
        archive:close()
        return false
    end

    -- Test 2: Check header fields
    if test("Header fields present", function()
        assert(result.version, "missing version")
        assert(result.regions, "missing regions array")
        assert(result.by_creation_number, "missing lookup index")
        print("")
        print("  Version: " .. result.version)
        print("  Region count: " .. #result.regions)
    end) then passed = passed + 1 else failed = failed + 1 end

    -- Test 3: Check region structure (if any regions exist)
    if #result.regions > 0 then
        if test("Region structure", function()
            local r = result.regions[1]
            assert(r.name, "missing name")
            assert(r.creation_number, "missing creation_number")
            assert(r.bounds, "missing bounds")
            assert(r.bounds.left, "missing bounds.left")
            assert(r.bounds.bottom, "missing bounds.bottom")
            assert(r.bounds.right, "missing bounds.right")
            assert(r.bounds.top, "missing bounds.top")
            assert(r.color, "missing color")
            assert(r.color.r ~= nil, "missing color.r")
            assert(r.color.g ~= nil, "missing color.g")
            assert(r.color.b ~= nil, "missing color.b")
            assert(r.color.a ~= nil, "missing color.a")
            print("")
            print("  First region: " .. r.name)
            print("  Bounds: (" .. r.bounds.left .. ", " .. r.bounds.bottom ..
                  ") to (" .. r.bounds.right .. ", " .. r.bounds.top .. ")")
        end) then passed = passed + 1 else failed = failed + 1 end

        -- Test 4: Verify bounds are valid (right > left, top > bottom)
        if test("Bounds validation", function()
            for i, r in ipairs(result.regions) do
                assert(r.bounds.right >= r.bounds.left,
                    string.format("Region %d (%s): right < left", i, r.name))
                assert(r.bounds.top >= r.bounds.bottom,
                    string.format("Region %d (%s): top < bottom", i, r.name))
            end
            print("")
            print("  All " .. #result.regions .. " regions have valid bounds")
        end) then passed = passed + 1 else failed = failed + 1 end

        -- Test 5: Lookup by creation number
        if test("Lookup by creation_number", function()
            local first = result.regions[1]
            local found = w3r.get_region(result, first.creation_number)
            assert(found, "lookup returned nil")
            assert(found.name == first.name, "lookup returned wrong region")
            print("")
            print("  Lookup test: id=" .. first.creation_number .. " -> " .. found.name)
        end) then passed = passed + 1 else failed = failed + 1 end
    else
        print("\n  NOTE: No regions in this map, skipping region-specific tests")
    end

    -- Test 6: Format output
    if test("w3r.format()", function()
        local formatted = w3r.format(result)
        assert(formatted and #formatted > 0, "format returned empty")
        print("")
        print("--- Formatted Output Preview ---")
        -- Print first 15 lines
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
    local no_regions_count = 0

    for _, map_path in ipairs(maps) do
        local map_name = map_path:match("([^/]+)$")
        io.write(string.format("%-50s ", map_name))

        local archive, err = mpq.open(map_path)
        if not archive then
            print("OPEN FAIL: " .. err)
            fail_count = fail_count + 1
        else
            if not archive:has("war3map.w3r") then
                print("NO REGIONS")
                no_regions_count = no_regions_count + 1
                success_count = success_count + 1  -- Not a failure
            else
                local w3r_data, w3r_err = archive:extract("war3map.w3r")
                if not w3r_data then
                    print("EXTRACT FAIL: " .. w3r_err)
                    fail_count = fail_count + 1
                else
                    local result, parse_err = w3r.parse(w3r_data)
                    if result then
                        -- Count regions with weather/sound
                        local weather_count = 0
                        local sound_count = 0
                        for _, r in ipairs(result.regions) do
                            if r.weather then weather_count = weather_count + 1 end
                            if r.ambient_sound then sound_count = sound_count + 1 end
                        end
                        print(string.format("OK v%d %d regions (w=%d s=%d)",
                            result.version, #result.regions, weather_count, sound_count))
                        success_count = success_count + 1
                    else
                        print("PARSE FAIL: " .. tostring(parse_err))
                        fail_count = fail_count + 1
                    end
                end
            end
            archive:close()
        end
    end

    print("")
    print(string.format("Success: %d / %d (%d maps without regions)",
        success_count, success_count + fail_count, no_regions_count))
end
-- }}}

-- Run the tests
local ok = run_tests()
test_all_maps()
os.exit(ok and 0 or 1)

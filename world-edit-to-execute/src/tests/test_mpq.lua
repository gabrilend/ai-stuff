-- MPQ Unified API Test
-- Tests the unified mpq.open() API that ties together all MPQ parser modules.
-- Run from project root: lua src/tests/test_mpq.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local mpq = require("mpq")

-- {{{ Test configuration
local TEST_MAP = DIR .. "/assets/DAoW-2.1.w3x"
local TEST_FILES = {
    "war3map.w3i",
    "war3map.wts",
    "war3map.w3e",
    "war3map.j",
    "(listfile)",
}
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

    print_separator("MPQ Unified API Tests")
    print("Test map: " .. TEST_MAP)
    print("MPQ library version: " .. mpq.VERSION)

    -- Test 1: Open archive
    local archive
    if test("mpq.open()", function()
        archive = assert(mpq.open(TEST_MAP))
    end) then passed = passed + 1 else failed = failed + 1 end

    if not archive then
        print("\nCannot continue without archive. Aborting.")
        return false
    end

    -- Test 2: Get archive info
    if test("archive:info()", function()
        local info = archive:info()
        assert(info.filepath == TEST_MAP, "filepath mismatch")
        assert(info.file_size > 0, "file_size should be > 0")
        assert(info.file_count > 0, "file_count should be > 0")
        print("")
        print("  Archive info:")
        print("    File size: " .. info.file_size .. " bytes")
        print("    Archive size: " .. info.archive_size .. " bytes")
        print("    File count: " .. info.file_count)
        if info.map_name then
            print("    Map name: " .. info.map_name)
        end
    end) then passed = passed + 1 else failed = failed + 1 end

    -- Test 3: Check file existence
    if test("archive:has()", function()
        assert(archive:has("war3map.w3i"), "war3map.w3i should exist")
        -- war3map.j may not exist in all maps (older maps or protected maps)
        print("")
        print("    war3map.w3i: " .. tostring(archive:has("war3map.w3i")))
        print("    war3map.j: " .. tostring(archive:has("war3map.j")))
        print("    war3map.wts: " .. tostring(archive:has("war3map.wts")))
        assert(not archive:has("nonexistent.xyz"), "nonexistent file should not exist")
    end) then passed = passed + 1 else failed = failed + 1 end

    -- Test 4: Extract war3map.w3i
    if test("archive:extract('war3map.w3i')", function()
        local data, err = archive:extract("war3map.w3i")
        assert(data, "extraction failed: " .. tostring(err))
        assert(#data > 0, "extracted data should not be empty")
        print("")
        print("    Extracted " .. #data .. " bytes")
    end) then passed = passed + 1 else failed = failed + 1 end

    -- Test 5: Extract war3map.j (JASS script) - optional, may not exist
    if test("archive:extract('war3map.j') (optional)", function()
        if not archive:has("war3map.j") then
            print("")
            print("    SKIP: war3map.j not present in this archive")
            return  -- Not an error, just not present
        end
        local data, err = archive:extract("war3map.j")
        assert(data, "extraction failed: " .. tostring(err))
        assert(#data > 0, "JASS script should not be empty")
        -- JASS scripts start with known patterns
        local starts_ok = data:find("^//") or data:find("^globals") or
                          data:find("^function") or data:find("^native")
        assert(starts_ok or #data > 100, "doesn't look like valid JASS")
        print("")
        print("    Extracted " .. #data .. " bytes of JASS script")
    end) then passed = passed + 1 else failed = failed + 1 end

    -- Test 6: List files via (listfile)
    if test("archive:list()", function()
        local files, err = archive:list()
        if files then
            assert(#files > 0, "file list should not be empty")
            print("")
            print("    Found " .. #files .. " files in (listfile)")
            print("    First 5:")
            for i = 1, math.min(5, #files) do
                print("      " .. files[i])
            end
        else
            -- (listfile) may not exist in all archives
            print("")
            print("    Warning: " .. err)
        end
    end) then passed = passed + 1 else failed = failed + 1 end

    -- Test 7: Get block info
    if test("archive:get_block_info()", function()
        local block, err = archive:get_block_info("war3map.w3i")
        assert(block, "get_block_info failed: " .. tostring(err))
        assert(block.uncompressed_size > 0, "block should have size")
        print("")
        print("    war3map.w3i block:")
        print("      Compressed: " .. block.compressed_size .. " bytes")
        print("      Uncompressed: " .. block.uncompressed_size .. " bytes")
        print("      Encrypted: " .. tostring(block.flags.encrypted))
    end) then passed = passed + 1 else failed = failed + 1 end

    -- Test 8: Close archive
    if test("archive:close()", function()
        archive:close()
        -- Verify operations fail after close
        local ok = pcall(function() archive:has("test") end)
        assert(not ok, "operations should fail after close")
    end) then passed = passed + 1 else failed = failed + 1 end

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

-- {{{ Run tests on all available maps
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
            -- Try to extract war3map.w3i
            local w3i, w3i_err = archive:extract("war3map.w3i")
            if w3i then
                print("OK (" .. #w3i .. " bytes w3i)")
                success_count = success_count + 1
            else
                print("EXTRACT FAIL: " .. w3i_err)
                fail_count = fail_count + 1
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

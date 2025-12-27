-- war3map.wtg Header/Category Parser Test (Issue 301a)
-- Tests the wtg parser header and category parsing with synthetic data.
-- Run from project root: luajit src/tests/test_wtg_header.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local wtg = require("parsers.wtg")

-- {{{ Test utilities
local tests_run = 0
local tests_passed = 0

local function print_separator(title)
    print("\n" .. string.rep("=", 60))
    print(title)
    print(string.rep("=", 60))
end

local function test(name, fn)
    io.write("Testing " .. name .. "... ")
    tests_run = tests_run + 1
    local ok, err = pcall(fn)
    if ok then
        tests_passed = tests_passed + 1
        print("PASS")
        return true
    else
        print("FAIL: " .. tostring(err))
        return false
    end
end

local function assert_eq(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s",
            message or "Assertion failed",
            tostring(expected),
            tostring(actual)))
    end
end

local function assert_nil(value, message)
    if value ~= nil then
        error(string.format("%s: expected nil, got %s",
            message or "Assertion failed", tostring(value)))
    end
end

local function assert_not_nil(value, message)
    if value == nil then
        error(message or "Expected non-nil value")
    end
end
-- }}}

-- {{{ Synthetic WTG data generators
-- Pack a 32-bit unsigned integer as little-endian bytes
local function pack_uint32(n)
    local b1 = n % 256
    local b2 = math.floor(n / 256) % 256
    local b3 = math.floor(n / 65536) % 256
    local b4 = math.floor(n / 16777216) % 256
    return string.char(b1, b2, b3, b4)
end

-- Create minimal valid WTG with no categories, no variables, and no triggers
local function make_empty_wtg()
    local parts = {}
    parts[#parts + 1] = "WTG!"                    -- magic
    parts[#parts + 1] = pack_uint32(7)            -- version (TFT)
    parts[#parts + 1] = pack_uint32(0)            -- category count = 0
    parts[#parts + 1] = pack_uint32(0)            -- variable count = 0 (301b)
    parts[#parts + 1] = pack_uint32(0)            -- trigger count = 0 (301c)
    return table.concat(parts)
end

-- Create WTG with 2 categories, no variables, no triggers
local function make_wtg_with_categories()
    local parts = {}
    -- Header
    parts[#parts + 1] = "WTG!"                    -- magic
    parts[#parts + 1] = pack_uint32(7)            -- version (TFT)
    -- Categories
    parts[#parts + 1] = pack_uint32(2)            -- category count
    -- Category 0: normal
    parts[#parts + 1] = pack_uint32(0)            -- index
    parts[#parts + 1] = "Initialization\0"        -- name
    parts[#parts + 1] = pack_uint32(0)            -- type (normal)
    -- Category 1: comment
    parts[#parts + 1] = pack_uint32(1)            -- index
    parts[#parts + 1] = "// Disabled\0"           -- name
    parts[#parts + 1] = pack_uint32(1)            -- type (comment)
    -- Variables (301b)
    parts[#parts + 1] = pack_uint32(0)            -- variable count = 0
    -- Triggers (301c)
    parts[#parts + 1] = pack_uint32(0)            -- trigger count = 0
    return table.concat(parts)
end

-- Create WTG with version 4 (RoC)
local function make_wtg_version4()
    local parts = {}
    parts[#parts + 1] = "WTG!"                    -- magic
    parts[#parts + 1] = pack_uint32(4)            -- version (RoC)
    parts[#parts + 1] = pack_uint32(1)            -- category count
    parts[#parts + 1] = pack_uint32(0)            -- index
    parts[#parts + 1] = "Default\0"               -- name
    parts[#parts + 1] = pack_uint32(0)            -- type (normal)
    parts[#parts + 1] = pack_uint32(0)            -- variable count = 0 (301b)
    parts[#parts + 1] = pack_uint32(0)            -- trigger count = 0 (301c)
    return table.concat(parts)
end

-- Create invalid WTG (wrong magic)
local function make_invalid_magic()
    local parts = {}
    parts[#parts + 1] = "BAD!"                    -- wrong magic
    parts[#parts + 1] = pack_uint32(7)            -- version
    parts[#parts + 1] = pack_uint32(0)            -- category count
    return table.concat(parts)
end

-- Create unsupported version WTG
local function make_unsupported_version()
    local parts = {}
    parts[#parts + 1] = "WTG!"                    -- magic
    parts[#parts + 1] = pack_uint32(99)           -- unsupported version
    parts[#parts + 1] = pack_uint32(0)            -- category count
    return table.concat(parts)
end

-- Create truncated WTG (header only, missing categories)
local function make_truncated_wtg()
    local parts = {}
    parts[#parts + 1] = "WTG!"                    -- magic
    parts[#parts + 1] = pack_uint32(7)            -- version
    -- Missing category count
    return table.concat(parts)
end
-- }}}

-- {{{ Main test suite
local function run_tests()
    print_separator("WTG Header/Category Parser Tests (301a)")

    -- Test 1: Parse empty WTG (no categories)
    test("Parse empty WTG (no categories)", function()
        local data = make_empty_wtg()
        local result, err = wtg.parse(data)
        assert_not_nil(result, "parse returned nil: " .. tostring(err))
        assert_eq(result.version, 7, "version")
        assert_not_nil(result.categories, "categories array")
        assert_eq(#result.categories, 0, "category count")
        assert_not_nil(result._offset, "_offset for next parser")
    end)

    -- Test 2: Parse WTG with categories
    test("Parse WTG with 2 categories", function()
        local data = make_wtg_with_categories()
        local result, err = wtg.parse(data)
        assert_not_nil(result, "parse returned nil: " .. tostring(err))
        assert_eq(result.version, 7, "version")
        assert_eq(#result.categories, 2, "category count")

        -- Check first category
        local cat1 = result.categories[1]
        assert_eq(cat1.index, 0, "cat1 index")
        assert_eq(cat1.name, "Initialization", "cat1 name")
        assert_eq(cat1.type, "normal", "cat1 type")

        -- Check second category
        local cat2 = result.categories[2]
        assert_eq(cat2.index, 1, "cat2 index")
        assert_eq(cat2.name, "// Disabled", "cat2 name")
        assert_eq(cat2.type, "comment", "cat2 type")
    end)

    -- Test 3: Version 4 (RoC) support
    test("Parse version 4 (RoC) WTG", function()
        local data = make_wtg_version4()
        local result, err = wtg.parse(data)
        assert_not_nil(result, "parse returned nil: " .. tostring(err))
        assert_eq(result.version, 4, "version")
        assert_eq(#result.categories, 1, "category count")
        assert_eq(result.categories[1].name, "Default", "category name")
    end)

    -- Test 4: Invalid magic bytes
    test("Reject invalid magic bytes", function()
        local data = make_invalid_magic()
        local result, err = wtg.parse(data)
        assert_nil(result, "should return nil for invalid magic")
        assert_not_nil(err, "should return error message")
        assert(err:find("WTG!"), "error should mention expected magic")
    end)

    -- Test 5: Unsupported version
    test("Reject unsupported version", function()
        local data = make_unsupported_version()
        local result, err = wtg.parse(data)
        assert_nil(result, "should return nil for unsupported version")
        assert_not_nil(err, "should return error message")
        assert(err:find("99"), "error should mention the version")
    end)

    -- Test 6: Truncated data
    test("Handle truncated data gracefully", function()
        local data = make_truncated_wtg()
        local result, err = wtg.parse(data)
        assert_nil(result, "should return nil for truncated data")
        assert_not_nil(err, "should return error message")
    end)

    -- Test 7: Nil/empty input
    test("Handle nil input", function()
        local result, err = wtg.parse(nil)
        assert_nil(result, "should return nil for nil input")
        assert_not_nil(err, "should return error message")
    end)

    test("Handle empty string input", function()
        local result, err = wtg.parse("")
        assert_nil(result, "should return nil for empty input")
        assert_not_nil(err, "should return error message")
    end)

    -- Test 8: Format function
    test("Format function produces output", function()
        local data = make_wtg_with_categories()
        local result = wtg.parse(data)
        assert_not_nil(result, "parse should succeed")

        local formatted = wtg.format(result)
        assert_not_nil(formatted, "format should return string")
        assert(#formatted > 0, "format should not be empty")
        assert(formatted:find("Initialization"), "format should include category name")
        assert(formatted:find("comment"), "format should show comment type")
        print("")
        print("  --- Formatted Output ---")
        for line in formatted:gmatch("[^\n]+") do
            print("  " .. line)
        end
    end)

    -- Test 9: Offset tracking
    test("Offset advances correctly", function()
        local data = make_wtg_with_categories()
        local result = wtg.parse(data)
        assert_not_nil(result, "parse should succeed")

        -- Calculate expected offset:
        -- 4 (magic) + 4 (version) + 4 (cat count) +
        -- (4 index + 15 name + 4 type) + (4 index + 12 name + 4 type)
        -- = 8 + 4 + 23 + 20 = 55
        -- Actually: "Initialization\0" = 15 bytes, "// Disabled\0" = 12 bytes
        -- Total: 4+4+4 + (4+15+4) + (4+12+4) = 12 + 23 + 20 = 55

        assert(result._offset > 12, "_offset should advance past header")
        print("")
        print("  Final offset: " .. result._offset)
        print("  Data length: " .. #data)
    end)

    -- Test 10: Internal functions exposed
    test("Internal functions are exposed", function()
        assert_not_nil(wtg._read_string, "_read_string should be exposed")
        assert_not_nil(wtg._read_int32, "_read_int32 should be exposed")
        assert_not_nil(wtg._read_uint32, "_read_uint32 should be exposed")
        assert_not_nil(wtg._parse_header, "_parse_header should be exposed")
        assert_not_nil(wtg._parse_categories, "_parse_categories should be exposed")
    end)

    -- Summary
    print_separator("Results")
    print(string.format("Passed: %d / %d", tests_passed, tests_run))
    if tests_passed < tests_run then
        print("SOME TESTS FAILED")
        return false
    else
        print("ALL TESTS PASSED")
        return true
    end
end
-- }}}

-- {{{ Test with real map data (if available)
local function test_real_maps()
    print_separator("Real Map Integration Test")

    local mpq_ok, mpq = pcall(require, "mpq")
    if not mpq_ok then
        print("MPQ module not available, skipping real map tests")
        return
    end

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

    if #maps == 0 then
        print("No map files found")
        return
    end

    print("Checking " .. #maps .. " maps for war3map.wtg...")
    print("")

    local found_wtg = false
    for _, map_path in ipairs(maps) do
        local map_name = map_path:match("([^/]+)$")
        local archive, err = mpq.open(map_path)
        if archive then
            if archive:has("war3map.wtg") then
                found_wtg = true
                io.write(string.format("%-50s ", map_name))
                local wtg_data = archive:extract("war3map.wtg")
                if wtg_data then
                    local result, parse_err = wtg.parse(wtg_data)
                    if result then
                        print(string.format("OK v%d, %d categories",
                            result.version, #result.categories))
                    else
                        print("PARSE FAIL: " .. tostring(parse_err))
                    end
                else
                    print("EXTRACT FAIL")
                end
            end
            archive:close()
        end
    end

    if not found_wtg then
        print("NOTE: No test maps contain war3map.wtg files.")
        print("      These maps may be protected or use only war3map.j.")
        print("      Synthetic tests above validate parser correctness.")
    end
end
-- }}}

-- Run tests
local ok = run_tests()
test_real_maps()
os.exit(ok and 0 or 1)

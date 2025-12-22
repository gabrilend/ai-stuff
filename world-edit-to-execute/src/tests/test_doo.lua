#!/usr/bin/env lua
-- Test suite for doo (doodad placement) parser
-- Tests parsing against both synthetic data and real map files.
-- Run from project root: luajit src/tests/test_doo.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local doo = require("parsers.doo")
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

-- {{{ pack_int32
-- Pack a signed 32-bit integer to little-endian bytes
local function pack_int32(val)
    if val < 0 then
        val = val + 0x100000000
    end
    return string.char(
        val % 256,
        math.floor(val / 256) % 256,
        math.floor(val / 65536) % 256,
        math.floor(val / 16777216) % 256
    )
end
-- }}}

-- {{{ pack_float32
-- Pack a 32-bit float to little-endian bytes (IEEE 754)
local function pack_float32(val)
    if val == 0 then
        return "\0\0\0\0"
    end

    local sign = 0
    if val < 0 then
        sign = 0x80
        val = -val
    end

    local mantissa, exp = math.frexp(val)
    exp = exp + 126

    if exp <= 0 then
        mantissa = math.floor(mantissa * 2^(24 + exp) + 0.5)
        exp = 0
    else
        mantissa = math.floor((mantissa * 2 - 1) * 2^23 + 0.5)
    end

    local b1 = mantissa % 256
    local b2 = math.floor(mantissa / 256) % 256
    local b3 = math.floor(mantissa / 65536) % 128 + (exp % 2) * 128
    local b4 = math.floor(exp / 2) + sign

    return string.char(b1, b2, b3, b4)
end
-- }}}

-- {{{ pack_id
-- Pack a 4-character ID string
local function pack_id(id)
    if #id < 4 then
        id = id .. string.rep("\0", 4 - #id)
    end
    return id:sub(1, 4)
end
-- }}}

-- {{{ build_doodad_entry
-- Build a single doodad entry (42 bytes)
local function build_doodad_entry(d)
    local parts = {}

    -- Type ID (4 chars)
    parts[#parts + 1] = pack_id(d.id or "LTlt")

    -- Variation
    parts[#parts + 1] = pack_int32(d.variation or 0)

    -- Position (X, Y, Z)
    parts[#parts + 1] = pack_float32(d.x or 0)
    parts[#parts + 1] = pack_float32(d.y or 0)
    parts[#parts + 1] = pack_float32(d.z or 0)

    -- Angle
    parts[#parts + 1] = pack_float32(d.angle or 0)

    -- Scale (X, Y, Z)
    parts[#parts + 1] = pack_float32(d.scale_x or 1.0)
    parts[#parts + 1] = pack_float32(d.scale_y or 1.0)
    parts[#parts + 1] = pack_float32(d.scale_z or 1.0)

    -- Flags (1 byte)
    parts[#parts + 1] = string.char(d.flags or 2)

    -- Life (1 byte)
    parts[#parts + 1] = string.char(d.life or 100)

    -- Creation number
    parts[#parts + 1] = pack_int32(d.creation_number or 1)

    return table.concat(parts)
end
-- }}}

-- {{{ build_doo_file
-- Build a complete doo file
local function build_doo_file(doodads, options)
    options = options or {}
    local parts = {}

    -- Header
    parts[#parts + 1] = "W3do"  -- File ID
    parts[#parts + 1] = pack_int32(options.version or 7)  -- Version
    parts[#parts + 1] = pack_int32(options.subversion or 9)  -- Subversion
    parts[#parts + 1] = pack_int32(#doodads)  -- Doodad count

    -- Doodad entries
    for _, d in ipairs(doodads) do
        parts[#parts + 1] = build_doodad_entry(d)
    end

    -- Special doodads section (empty by default)
    parts[#parts + 1] = pack_int32(0)  -- Special version
    parts[#parts + 1] = pack_int32(0)  -- Special count

    return table.concat(parts)
end
-- }}}

-- {{{ build_special_doodad
-- Build a special doodad entry with item drops
local function build_special_doodad(sd)
    local parts = {}

    parts[#parts + 1] = pack_id(sd.id)
    parts[#parts + 1] = pack_int32(#sd.item_sets)

    for _, set in ipairs(sd.item_sets) do
        parts[#parts + 1] = pack_int32(#set.items)
        for _, item in ipairs(set.items) do
            parts[#parts + 1] = pack_id(item.id)
            parts[#parts + 1] = pack_int32(item.chance)
        end
    end

    return table.concat(parts)
end
-- }}}

-- {{{ build_doo_with_special
-- Build a doo file with special doodads
local function build_doo_with_special(doodads, special_doodads, options)
    options = options or {}
    local parts = {}

    -- Header
    parts[#parts + 1] = "W3do"
    parts[#parts + 1] = pack_int32(options.version or 7)
    parts[#parts + 1] = pack_int32(options.subversion or 9)
    parts[#parts + 1] = pack_int32(#doodads)

    -- Doodad entries
    for _, d in ipairs(doodads) do
        parts[#parts + 1] = build_doodad_entry(d)
    end

    -- Special doodads section
    parts[#parts + 1] = pack_int32(0)  -- Special version
    parts[#parts + 1] = pack_int32(#special_doodads)

    for _, sd in ipairs(special_doodads) do
        parts[#parts + 1] = build_special_doodad(sd)
    end

    return table.concat(parts)
end
-- }}}
-- }}}

-- {{{ Test cases
-- {{{ test_parse_empty
local function test_parse_empty()
    print("Testing empty file...")

    local data = build_doo_file({})
    local result = doo.parse(data)

    assert(result, "Should parse empty doo")
    assert(result.version == 7, "Version should be 7")
    assert(result.subversion == 9, "Subversion should be 9")
    assert(#result.doodads == 0, "Should have 0 doodads")

    print("  PASS: Empty file parsing works")
end
-- }}}

-- {{{ test_parse_single_doodad
local function test_parse_single_doodad()
    print("Testing single doodad entry...")

    local data = build_doo_file({
        {
            id = "LTlt",
            variation = 0,
            x = 1024.5,
            y = 2048.25,
            z = 50.0,
            angle = 1.57,
            scale_x = 1.0,
            scale_y = 1.0,
            scale_z = 1.5,
            flags = 2,
            life = 100,
            creation_number = 42,
        }
    })

    local result = doo.parse(data)

    assert(result, "Should parse single doodad")
    assert(#result.doodads == 1, "Should have 1 doodad")

    local d = result.doodads[1]
    assert(d.id == "LTlt", "ID mismatch")
    assert(d.variation == 0, "Variation mismatch")
    assert(math.abs(d.position.x - 1024.5) < 0.01, "X position mismatch")
    assert(math.abs(d.position.y - 2048.25) < 0.01, "Y position mismatch")
    assert(math.abs(d.position.z - 50.0) < 0.01, "Z position mismatch")
    assert(math.abs(d.angle - 1.57) < 0.01, "Angle mismatch")
    assert(math.abs(d.scale.x - 1.0) < 0.01, "Scale X mismatch")
    assert(math.abs(d.scale.z - 1.5) < 0.01, "Scale Z mismatch")
    assert(d.flags == 2, "Flags mismatch")
    assert(d.flags_name == "normal", "Flags name mismatch")
    assert(d.life == 100, "Life mismatch")
    assert(d.creation_number == 42, "Creation number mismatch")

    print("  PASS: Single doodad parsing works")
end
-- }}}

-- {{{ test_parse_multiple_doodads
local function test_parse_multiple_doodads()
    print("Testing multiple doodad entries...")

    local data = build_doo_file({
        { id = "LTlt", x = 100, y = 200, creation_number = 1 },
        { id = "ATtr", x = 300, y = 400, creation_number = 2 },
        { id = "BTtw", x = 500, y = 600, creation_number = 3 },
    })

    local result = doo.parse(data)

    assert(result, "Should parse multiple doodads")
    assert(#result.doodads == 3, "Should have 3 doodads")

    assert(result.doodads[1].id == "LTlt", "Doodad 1 ID mismatch")
    assert(result.doodads[2].id == "ATtr", "Doodad 2 ID mismatch")
    assert(result.doodads[3].id == "BTtw", "Doodad 3 ID mismatch")

    assert(result.doodads[1].creation_number == 1, "Doodad 1 creation number mismatch")
    assert(result.doodads[2].creation_number == 2, "Doodad 2 creation number mismatch")
    assert(result.doodads[3].creation_number == 3, "Doodad 3 creation number mismatch")

    print("  PASS: Multiple doodad parsing works")
end
-- }}}

-- {{{ test_parse_flags
local function test_parse_flags()
    print("Testing flag values...")

    local test_cases = {
        { flags = 0, expected_name = "invisible_non_solid" },
        { flags = 1, expected_name = "visible_non_solid" },
        { flags = 2, expected_name = "normal" },
    }

    for i, tc in ipairs(test_cases) do
        local data = build_doo_file({
            { id = "LTlt", flags = tc.flags, creation_number = i }
        })

        local result = doo.parse(data)
        local d = result.doodads[1]

        assert(d.flags == tc.flags,
            string.format("Test %d: flags expected %d, got %d", i, tc.flags, d.flags))
        assert(d.flags_name == tc.expected_name,
            string.format("Test %d: flags_name expected '%s', got '%s'",
                i, tc.expected_name, d.flags_name))
    end

    print("  PASS: Flag parsing works")
end
-- }}}

-- {{{ test_parse_special_doodads
local function test_parse_special_doodads()
    print("Testing special doodads (item drops)...")

    local data = build_doo_with_special(
        {
            { id = "LTlt", creation_number = 1 },
        },
        {
            {
                id = "LTlt",
                item_sets = {
                    {
                        items = {
                            { id = "gold", chance = 50 },
                            { id = "maap", chance = 25 },
                        }
                    },
                    {
                        items = {
                            { id = "stwp", chance = 100 },
                        }
                    },
                }
            }
        }
    )

    local result = doo.parse(data)

    assert(result.special_doodads, "Should have special_doodads")
    assert(#result.special_doodads.doodads == 1, "Should have 1 special doodad")

    local sd = result.special_doodads.doodads[1]
    assert(sd.id == "LTlt", "Special doodad ID mismatch")
    assert(#sd.item_sets == 2, "Should have 2 item sets")
    assert(#sd.item_sets[1].items == 2, "Item set 1 should have 2 items")
    assert(#sd.item_sets[2].items == 1, "Item set 2 should have 1 item")

    assert(sd.item_sets[1].items[1].id == "gold", "Item 1 ID mismatch")
    assert(sd.item_sets[1].items[1].chance == 50, "Item 1 chance mismatch")
    assert(sd.item_sets[1].items[2].id == "maap", "Item 2 ID mismatch")

    print("  PASS: Special doodad parsing works")
end
-- }}}

-- {{{ test_doodad_table_class
local function test_doodad_table_class()
    print("Testing DoodadTable class...")

    local data = build_doo_file({
        { id = "LTlt", x = 100, y = 100, creation_number = 1 },
        { id = "LTlt", x = 200, y = 200, creation_number = 2 },
        { id = "ATtr", x = 300, y = 300, creation_number = 3 },
        { id = "BTtw", x = 400, y = 400, creation_number = 4 },
    })

    local dt = doo.new(data)

    -- Test count
    assert(dt:count() == 4, "Count should be 4")

    -- Test get by creation number
    local d1 = dt:get(1)
    assert(d1 ~= nil, "Should find doodad with creation_number 1")
    assert(d1.id == "LTlt", "Doodad 1 ID mismatch")

    local missing = dt:get(999)
    assert(missing == nil, "Should not find missing doodad")

    -- Test get_by_type
    local ltlt_doodads = dt:get_by_type("LTlt")
    assert(#ltlt_doodads == 2, "Should have 2 LTlt doodads")

    local missing_type = dt:get_by_type("XXXX")
    assert(#missing_type == 0, "Should have 0 doodads of missing type")

    -- Test count_by_type
    assert(dt:count_by_type("LTlt") == 2, "Should have 2 LTlt")
    assert(dt:count_by_type("ATtr") == 1, "Should have 1 ATtr")
    assert(dt:count_by_type("XXXX") == 0, "Should have 0 unknown")

    -- Test types()
    local types = dt:types()
    assert(#types == 3, "Should have 3 unique types")

    -- Test pairs()
    local count = 0
    for i, d in dt:pairs() do
        count = count + 1
        assert(type(i) == "number", "Index should be number")
        assert(d.id ~= nil, "Doodad should have id")
    end
    assert(count == 4, "pairs() should iterate 4 times")

    print("  PASS: DoodadTable class works")
end
-- }}}

-- {{{ test_in_bounds
local function test_in_bounds()
    print("Testing in_bounds query...")

    local data = build_doo_file({
        { id = "LTlt", x = 100, y = 100, creation_number = 1 },
        { id = "LTlt", x = 200, y = 200, creation_number = 2 },
        { id = "LTlt", x = 300, y = 300, creation_number = 3 },
        { id = "LTlt", x = 1000, y = 1000, creation_number = 4 },
    })

    local dt = doo.new(data)

    -- Query a region that contains first 3 doodads
    local in_region = dt:in_bounds(0, 0, 500, 500)
    assert(#in_region == 3, "Should find 3 doodads in region")

    -- Query a region that contains only the last doodad
    local far_region = dt:in_bounds(900, 900, 1100, 1100)
    assert(#far_region == 1, "Should find 1 doodad in far region")
    assert(far_region[1].creation_number == 4, "Should be doodad 4")

    -- Query empty region
    local empty_region = dt:in_bounds(5000, 5000, 6000, 6000)
    assert(#empty_region == 0, "Should find 0 doodads in empty region")

    print("  PASS: in_bounds query works")
end
-- }}}

-- {{{ test_format
local function test_format()
    print("Testing format output...")

    local data = build_doo_file({
        { id = "LTlt", x = 100, y = 200, z = 10, angle = 1.57, life = 100, creation_number = 1 },
        { id = "LTlt", x = 300, y = 400, z = 20, life = 75, creation_number = 2 },
        { id = "ATtr", x = 500, y = 600, z = 0, creation_number = 3 },
    })

    local result = doo.parse(data)
    local formatted = doo.format(result)

    assert(formatted:find("Doodads"), "Should have header")
    assert(formatted:find("Version: 7"), "Should show version")
    assert(formatted:find("Doodad count: 3"), "Should show count")
    assert(formatted:find("LTlt"), "Should show LTlt type")
    assert(formatted:find("ATtr"), "Should show ATtr type")

    print("  PASS: Format output works")
end
-- }}}

-- {{{ test_invalid_data
local function test_invalid_data()
    print("Testing invalid data handling...")

    -- Too short
    local result, err = doo.parse("")
    assert(result == nil, "Should fail on empty data")
    assert(err ~= nil, "Should return error message")

    -- Invalid magic
    result, err = doo.parse("XXXX" .. pack_int32(7) .. pack_int32(9) .. pack_int32(0))
    assert(result == nil, "Should fail on invalid magic")
    assert(err:find("Invalid file ID"), "Error should mention file ID")

    -- nil data
    result, err = doo.parse(nil)
    assert(result == nil, "Should fail on nil data")

    print("  PASS: Invalid data handling works")
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
    local no_doo = 0
    local total_doodads = 0

    for _, map_path in ipairs(map_files) do
        local map_name = map_path:match("([^/]+)$")
        log("  Testing:", map_name)

        local ok, archive = pcall(mpq.open, map_path)
        if not ok then
            log("    SKIP: Cannot open MPQ -", archive)
            failed = failed + 1
            goto continue
        end

        -- Check if doo exists
        if not archive:has("war3map.doo") then
            log("    SKIP: No war3map.doo in archive")
            no_doo = no_doo + 1
            archive:close()
            goto continue
        end

        -- Extract doo
        local doo_ok, doo_data = pcall(archive.extract, archive, "war3map.doo")
        if not doo_ok then
            log("    FAIL: Cannot extract doo -", doo_data)
            failed = failed + 1
            archive:close()
            goto continue
        end

        -- Parse doo
        local parse_ok, result = pcall(doo.parse, doo_data)
        if not parse_ok then
            print(string.format("    FAIL: Cannot parse doo in %s - %s", map_name, result))
            failed = failed + 1
            archive:close()
            goto continue
        end

        if type(result) ~= "table" then
            print(string.format("    FAIL: Parse returned %s in %s - %s",
                type(result), map_name, tostring(result)))
            failed = failed + 1
            archive:close()
            goto continue
        end

        local count = #result.doodads
        total_doodads = total_doodads + count
        log(string.format("    Parsed: %d doodads", count))

        -- Validate some properties
        for i, d in ipairs(result.doodads) do
            if i > 10 then break end  -- Just check first 10
            if type(d.id) ~= "string" or #d.id ~= 4 then
                print(string.format("    FAIL: Invalid doodad ID at index %d", i))
                failed = failed + 1
                goto close_and_continue
            end
            if type(d.position) ~= "table" then
                print(string.format("    FAIL: Invalid position at index %d", i))
                failed = failed + 1
                goto close_and_continue
            end
        end

        passed = passed + 1
        ::close_and_continue::
        archive:close()
        ::continue::
    end

    print(string.format("  Results: %d passed, %d failed, %d no doo", passed, failed, no_doo))
    print(string.format("  Total doodads parsed: %d", total_doodads))

    if failed == 0 and passed > 0 then
        print("  PASS: All maps with doo parsed successfully")
    elseif passed > 0 then
        print("  PARTIAL: Some maps failed")
    end
end
-- }}}
-- }}}

-- {{{ Main
local function main()
    print("=== DOO Parser Tests ===\n")

    test_parse_empty()
    test_parse_single_doodad()
    test_parse_multiple_doodads()
    test_parse_flags()
    test_parse_special_doodads()
    test_doodad_table_class()
    test_in_bounds()
    test_format()
    test_invalid_data()
    test_real_maps()

    print("\n=== All tests completed ===")
end

main()
-- }}}

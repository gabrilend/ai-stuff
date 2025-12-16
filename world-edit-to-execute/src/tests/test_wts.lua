#!/usr/bin/env lua
-- Test suite for wts (trigger strings) parser
-- Tests parsing and TRIGSTR resolution against real map files.
-- Run from project root: lua5.4 src/tests/test_wts.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local wts = require("parsers.wts")
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
-- {{{ test_parse_basic
local function test_parse_basic()
    print("Testing basic parsing...")

    local content = [[
STRING 0
{
Hello World
}

STRING 1
{
Multi-line
content here
}

STRING 100
{
|cffff0000Red text|r
}
]]

    local st = wts.new(content)
    assert(st:count() == 3, "Expected 3 strings, got " .. st:count())
    assert(st:get(0) == "Hello World", "String 0 mismatch")
    assert(st:get(1) == "Multi-line\ncontent here", "String 1 mismatch (multi-line)")
    assert(st:get(100) == "|cffff0000Red text|r", "String 100 mismatch (color codes)")

    print("  PASS: Basic parsing works")
end
-- }}}

-- {{{ test_parse_edge_cases
local function test_parse_edge_cases()
    print("Testing edge cases...")

    -- Empty string
    local content1 = [[
STRING 0
{
}
]]
    local st1 = wts.new(content1)
    assert(st1:get(0) == "", "Empty string should be empty")

    -- Nested braces
    local content2 = [[
STRING 0
{
Some {nested} braces
}
]]
    local st2 = wts.new(content2)
    assert(st2:get(0) == "Some {nested} braces", "Nested braces not handled")

    -- Large ID
    local content3 = [[
STRING 99999
{
Large ID
}
]]
    local st3 = wts.new(content3)
    assert(st3:get(99999) == "Large ID", "Large ID not handled")

    -- Non-sequential IDs
    local content4 = [[
STRING 5
{
Five
}
STRING 10
{
Ten
}
STRING 2
{
Two
}
]]
    local st4 = wts.new(content4)
    assert(st4:count() == 3, "Non-sequential IDs: wrong count")
    assert(st4:get(5) == "Five", "ID 5 mismatch")
    assert(st4:get(10) == "Ten", "ID 10 mismatch")
    assert(st4:get(2) == "Two", "ID 2 mismatch")

    -- Duplicate ID (first wins)
    local content5 = [[
STRING 0
{
First
}
STRING 0
{
Second
}
]]
    local st5 = wts.new(content5)
    assert(st5:get(0) == "First", "Duplicate ID: first should win")

    print("  PASS: Edge cases handled")
end
-- }}}

-- {{{ test_resolve_trigstr
local function test_resolve_trigstr()
    print("Testing TRIGSTR resolution...")

    local content = [[
STRING 0
{
Map Name
}
STRING 1
{
Author
}
STRING 100
{
Welcome!
}
]]

    local st = wts.new(content)

    -- Basic resolution
    assert(st:resolve("TRIGSTR_000") == "Map Name", "TRIGSTR_000 not resolved")
    assert(st:resolve("TRIGSTR_0") == "Map Name", "TRIGSTR_0 not resolved")
    assert(st:resolve("TRIGSTR_001") == "Author", "TRIGSTR_001 not resolved")
    assert(st:resolve("TRIGSTR_100") == "Welcome!", "TRIGSTR_100 not resolved")

    -- Multiple in one string
    local result = st:resolve("By TRIGSTR_001: TRIGSTR_000")
    assert(result == "By Author: Map Name", "Multiple TRIGSTR not resolved")

    -- Unresolved (missing ID)
    assert(st:resolve("TRIGSTR_999") == "TRIGSTR_999", "Missing ID should stay literal")

    -- Negative ID
    assert(st:resolve("TRIGSTR_-001") == "", "Negative ID should resolve to empty")

    -- Mixed content
    local mixed = st:resolve("Welcome to TRIGSTR_000 by TRIGSTR_001!")
    assert(mixed == "Welcome to Map Name by Author!", "Mixed content not resolved")

    -- nil input
    assert(st:resolve(nil) == nil, "nil should return nil")

    print("  PASS: TRIGSTR resolution works")
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
    local no_wts = 0

    for _, map_path in ipairs(map_files) do
        local map_name = map_path:match("([^/]+)$")
        log("  Testing:", map_name)

        local ok, archive = pcall(mpq.open, map_path)
        if not ok then
            log("    SKIP: Cannot open MPQ -", archive)
            failed = failed + 1
            goto continue
        end

        -- Check if wts exists
        if not archive:has("war3map.wts") then
            log("    SKIP: No war3map.wts in archive")
            no_wts = no_wts + 1
            archive:close()
            goto continue
        end

        -- Extract wts
        local wts_ok, wts_data = pcall(archive.extract, archive, "war3map.wts")
        if not wts_ok then
            log("    FAIL: Cannot extract wts -", wts_data)
            failed = failed + 1
            archive:close()
            goto continue
        end

        -- Parse wts
        local parse_ok, st = pcall(wts.new, wts_data)
        if not parse_ok then
            log("    FAIL: Cannot parse wts -", st)
            failed = failed + 1
            archive:close()
            goto continue
        end

        log(string.format("    Parsed: %d strings", st:count()))

        -- Try to extract and resolve w3i if present
        if archive:has("war3map.w3i") then
            local w3i_ok, w3i_data = pcall(archive.extract, archive, "war3map.w3i")
            if w3i_ok then
                local w3i = require("parsers.w3i")
                local info_ok, info = pcall(w3i.parse, w3i_data)
                if info_ok and info and info.name then
                    local resolved_name = st:resolve(info.name)
                    log(string.format("    Map name: %s -> %s", info.name, resolved_name))
                end
            end
        end

        passed = passed + 1
        archive:close()
        ::continue::
    end

    print(string.format("  Results: %d passed, %d failed, %d no wts", passed, failed, no_wts))
    if failed == 0 then
        print("  PASS: All maps with wts parsed successfully")
    else
        print("  PARTIAL: Some maps failed")
    end
end
-- }}}

-- {{{ test_format
local function test_format()
    print("Testing format output...")

    local content = [[
STRING 0
{
Map Name
}
STRING 1
{
Author Name
}
STRING 2
{
This is a very long description that should be truncated when displayed in the formatted output for readability purposes
}
]]

    local st = wts.new(content)
    local formatted = wts.format(st)

    assert(formatted:find("StringTable: 3 strings"), "Format should show count")
    assert(formatted:find("%[0%]"), "Format should show ID 0")
    assert(formatted:find("Map Name"), "Format should show content")
    assert(formatted:find("%.%.%."), "Long strings should be truncated")

    print("  PASS: Format output works")
end
-- }}}

-- {{{ test_ids_and_pairs
local function test_ids_and_pairs()
    print("Testing ids() and pairs()...")

    local content = [[
STRING 5
{
Five
}
STRING 2
{
Two
}
STRING 10
{
Ten
}
]]

    local st = wts.new(content)

    -- Test ids() returns sorted list
    local ids = st:ids()
    assert(#ids == 3, "Should have 3 IDs")
    assert(ids[1] == 2, "First ID should be 2")
    assert(ids[2] == 5, "Second ID should be 5")
    assert(ids[3] == 10, "Third ID should be 10")

    -- Test pairs() iteration
    local count = 0
    for id, content in st:pairs() do
        count = count + 1
        assert(type(id) == "number", "ID should be number")
        assert(type(content) == "string", "Content should be string")
    end
    assert(count == 3, "pairs() should iterate 3 times")

    print("  PASS: ids() and pairs() work")
end
-- }}}
-- }}}

-- {{{ Main
local function main()
    print("=== WTS Parser Tests ===\n")

    test_parse_basic()
    test_parse_edge_cases()
    test_resolve_trigstr()
    test_ids_and_pairs()
    test_format()
    test_real_maps()

    print("\n=== All tests completed ===")
end

main()
-- }}}

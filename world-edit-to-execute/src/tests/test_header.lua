#!/usr/bin/env lua
-- Test script for MPQ header parser
-- Run from project root: lua src/tests/test_header.lua

-- {{{ Setup
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"

-- Add src to package path
package.path = DIR .. "/src/?.lua;" .. package.path

local header = require("mpq.header")
-- }}}

-- {{{ Test utilities
local test_count = 0
local pass_count = 0
local fail_count = 0

local function test(name, condition, msg)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        fail_count = fail_count + 1
        print("  [FAIL] " .. name .. (msg and ": " .. msg or ""))
    end
end

local function test_section(name)
    print("\n=== " .. name .. " ===")
end
-- }}}

-- {{{ Test: Parse DAoW-2.1.w3x
test_section("Parse DAoW-2.1.w3x")

local test_file = DIR .. "/assets/DAoW-2.1.w3x"
local result, err = header.open_w3x(test_file)

test("File opens successfully", result ~= nil, err)

if result then
    -- HM3W tests
    test("HM3W header present", result.hm3w ~= nil)
    if result.hm3w then
        test("HM3W magic is correct", result.hm3w.magic == "HM3W")
        test("Map name extracted", result.hm3w.map_name ~= nil and #result.hm3w.map_name > 0,
             "name: " .. tostring(result.hm3w.map_name))
        test("Map name contains 'Dark Ages'",
             result.hm3w.map_name and result.hm3w.map_name:find("Dark Ages"),
             "name: " .. tostring(result.hm3w.map_name))
    end

    -- MPQ tests
    test("MPQ header present", result.mpq ~= nil)
    if result.mpq then
        test("MPQ magic is correct", result.mpq.magic == "MPQ\x1A")
        test("MPQ at offset 512", result.mpq_offset == 512)
        test("Archive size > 0", result.mpq.archive_size > 0)
        test("Archive size matches file minus header",
             result.mpq.archive_size == result.file_size - 512,
             "expected " .. (result.file_size - 512) .. ", got " .. result.mpq.archive_size)
        test("Hash entries > 0", result.mpq.hash_table_entries > 0)
        test("Hash entries is power of 2",
             result.mpq.hash_table_entries > 0 and
             (result.mpq.hash_table_entries & (result.mpq.hash_table_entries - 1)) == 0)
        test("Block entries > 0", result.mpq.block_table_entries > 0)
        test("Sector size calculated", result.mpq.sector_size > 0)
    end

    -- Validation
    if result.mpq then
        local valid, errors = header.validate(result.mpq)
        test("Header validates", valid,
             errors and table.concat(errors, "; ") or nil)
    end

    -- Print formatted header
    print("\n--- Formatted Output ---")
    print(header.format(result))
end
-- }}}

-- {{{ Test: Error handling
test_section("Error Handling")

-- Test non-existent file
local bad_result, bad_err = header.open_w3x(DIR .. "/assets/nonexistent.w3x")
test("Non-existent file returns error", bad_result == nil)
test("Error message mentions file", bad_err and bad_err:find("Cannot open"))

-- Test invalid file (use a text file)
local readme_path = DIR .. "/docs/roadmap.md"
local invalid_result, invalid_err = header.open_w3x(readme_path)
test("Invalid file returns error", invalid_result == nil)
test("Error message is descriptive", invalid_err ~= nil and #invalid_err > 0)
-- }}}

-- {{{ Test: All map files
test_section("All Map Files")

local maps_tested = 0
local maps_passed = 0

-- List all .w3x files
local assets_dir = DIR .. "/assets"
local handle = io.popen("ls -1 " .. assets_dir .. "/*.w3x 2>/dev/null")
if handle then
    for filepath in handle:lines() do
        maps_tested = maps_tested + 1
        local map_result, map_err = header.open_w3x(filepath)
        local basename = filepath:match("([^/]+)$")
        if map_result and map_result.mpq then
            maps_passed = maps_passed + 1
            print("  [OK] " .. basename)
        else
            print("  [FAIL] " .. basename .. ": " .. tostring(map_err))
        end
    end
    handle:close()
end

test("All maps parse successfully", maps_passed == maps_tested,
     maps_passed .. "/" .. maps_tested .. " passed")
-- }}}

-- {{{ Summary
print("\n" .. string.rep("=", 50))
print(string.format("Tests: %d passed, %d failed, %d total",
                    pass_count, fail_count, test_count))
if fail_count > 0 then
    print("SOME TESTS FAILED")
    os.exit(1)
else
    print("ALL TESTS PASSED")
    os.exit(0)
end
-- }}}

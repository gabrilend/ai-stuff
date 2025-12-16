#!/usr/bin/env lua
-- Test script for MPQ file extraction
-- Run from project root: lua src/tests/test_extract.lua

-- {{{ Setup
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"

package.path = DIR .. "/src/?.lua;" .. package.path

local extract = require("mpq.extract")
local hashtable = require("mpq.hashtable")
local blocktable = require("mpq.blocktable")
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

-- {{{ Load test archive
test_section("Load Test Archive")

local test_file = DIR .. "/assets/DAoW-2.1.w3x"
local file = io.open(test_file, "rb")
local file_data = file:read("*a")
file:close()

local hdr_result = header.open_w3x(test_file)
test("Header parsed", hdr_result ~= nil)

local hash_tbl = hashtable.parse(file_data, hdr_result.mpq)
test("Hash table parsed", hash_tbl ~= nil)

local block_tbl = blocktable.parse(file_data, hdr_result.mpq)
test("Block table parsed", block_tbl ~= nil)

local sector_size = hdr_result.mpq.sector_size
test("Sector size determined", sector_size > 0, "size=" .. tostring(sector_size))
-- }}}

-- {{{ Test: File key computation
test_section("File Key Computation")

local w3i_idx = hashtable.find_file(hash_tbl, "war3map.w3i")
local w3i_block = blocktable.get_block(block_tbl, w3i_idx)

test("Found war3map.w3i block", w3i_block ~= nil)

if w3i_block then
    local key = extract.compute_file_key("war3map.w3i", w3i_block)
    test("Key computed", key ~= nil and key > 0)
    print(string.format("  Key for war3map.w3i: 0x%08X", key or 0))
end
-- }}}

-- {{{ Test: Extract war3map.wts (trigger strings - text file)
test_section("Extract war3map.wts")

local wts_data, wts_err = extract.extract_file(
    file_data, hash_tbl, block_tbl, sector_size, "war3map.wts"
)

test("war3map.wts extracted", wts_data ~= nil, wts_err)

if wts_data then
    test("wts has content", #wts_data > 0)
    -- WTS files start with "STRING" keyword
    local starts_with_string = wts_data:find("STRING", 1, true) ~= nil
    test("wts contains STRING keyword", starts_with_string)

    print(string.format("  Size: %d bytes", #wts_data))
    print("  First 100 chars:")
    print("  " .. wts_data:sub(1, 100):gsub("\n", "\\n"))
end
-- }}}

-- {{{ Test: Extract war3map.w3i (map info - binary)
test_section("Extract war3map.w3i")

local w3i_data, w3i_err = extract.extract_file(
    file_data, hash_tbl, block_tbl, sector_size, "war3map.w3i"
)

test("war3map.w3i extracted", w3i_data ~= nil, w3i_err)

if w3i_data then
    local expected_size = w3i_block.uncompressed_size
    test("w3i has expected size", #w3i_data == expected_size,
         string.format("got %d, expected %d", #w3i_data, expected_size))

    -- W3I files start with version number (typically 25 for TFT)
    local version = string.unpack("<I4", w3i_data, 1)
    test("w3i has valid version", version == 25 or version == 18,
         "version=" .. tostring(version))

    print(string.format("  Size: %d bytes", #w3i_data))
    print(string.format("  Version: %d", version))
end
-- }}}

-- {{{ Test: Extract war3map.w3e (terrain - largest file)
test_section("Extract war3map.w3e")

local w3e_data, w3e_err = extract.extract_file(
    file_data, hash_tbl, block_tbl, sector_size, "war3map.w3e"
)

test("war3map.w3e extracted", w3e_data ~= nil, w3e_err)

if w3e_data then
    local w3e_idx = hashtable.find_file(hash_tbl, "war3map.w3e")
    local w3e_block = blocktable.get_block(block_tbl, w3e_idx)
    local expected_size = w3e_block.uncompressed_size

    test("w3e has expected size", #w3e_data == expected_size,
         string.format("got %d, expected %d", #w3e_data, expected_size))

    -- W3E files start with "W3E!" magic
    local magic = w3e_data:sub(1, 4)
    test("w3e has W3E! magic", magic == "W3E!")

    print(string.format("  Size: %d bytes", #w3e_data))
end
-- }}}

-- {{{ Test: Non-existent file
test_section("Error Handling")

local fake_data, fake_err = extract.extract_file(
    file_data, hash_tbl, block_tbl, sector_size, "nonexistent.txt"
)

test("Non-existent returns nil", fake_data == nil)
test("Error message provided", fake_err ~= nil and #fake_err > 0)
-- }}}

-- {{{ Test: All maps can extract war3map.w3i
test_section("All Maps - Extract war3map.w3i")

local maps_tested = 0
local maps_passed = 0

local assets_dir = DIR .. "/assets"
local handle = io.popen("ls -1 " .. assets_dir .. "/*.w3x 2>/dev/null")
if handle then
    for filepath in handle:lines() do
        maps_tested = maps_tested + 1
        local basename = filepath:match("([^/]+)$")

        local f = io.open(filepath, "rb")
        local data = f:read("*a")
        f:close()

        local h = header.open_w3x(filepath)
        if h and h.mpq then
            local ht = hashtable.parse(data, h.mpq)
            local bt = blocktable.parse(data, h.mpq)

            if ht and bt then
                local extracted, err = extract.extract_file(
                    data, ht, bt, h.mpq.sector_size, "war3map.w3i"
                )

                if extracted and #extracted > 0 then
                    maps_passed = maps_passed + 1
                    print("  [OK] " .. basename)
                else
                    print("  [FAIL] " .. basename .. ": " .. (err or "empty"))
                end
            else
                print("  [FAIL] " .. basename .. ": table parse failed")
            end
        else
            print("  [FAIL] " .. basename .. ": header failed")
        end
    end
    handle:close()
end

test("All maps extract war3map.w3i", maps_passed == maps_tested,
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

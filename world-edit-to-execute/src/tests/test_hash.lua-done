#!/usr/bin/env lua
-- Test script for MPQ hash and hashtable modules
-- Run from project root: lua src/tests/test_hash.lua

-- {{{ Setup
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"

-- Add src to package path
package.path = DIR .. "/src/?.lua;" .. package.path

local hash = require("mpq.hash")
local hashtable = require("mpq.hashtable")
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

-- {{{ Test: Crypto table generation
test_section("Crypto Table Generation")

local crypt_table = hash.get_crypt_table()
test("Crypto table created", crypt_table ~= nil)
test("Crypto table has 1280 entries", crypt_table and #crypt_table == 1279)  -- 0-1279

-- Verify a few known values (from reference implementations)
-- The first few values should be predictable
test("First entry exists", crypt_table[0] ~= nil)
-- }}}

-- {{{ Test: Hash function
test_section("Hash Function")

-- Test known hash values
local hash_table_key = hash.mpq_hash("(hash table)", hash.HASH_FILE_KEY)
test("Hash table key correct", hash_table_key == 0xC3AF3770,
     string.format("got 0x%08X, expected 0xC3AF3770", hash_table_key))

local block_table_key = hash.mpq_hash("(block table)", hash.HASH_FILE_KEY)
test("Block table key correct", block_table_key == 0xEC83B3A3,
     string.format("got 0x%08X, expected 0xEC83B3A3", block_table_key))

-- Test case insensitivity
local hash_lower = hash.mpq_hash("war3map.w3i", hash.HASH_NAME_A)
local hash_upper = hash.mpq_hash("WAR3MAP.W3I", hash.HASH_NAME_A)
test("Hash is case insensitive", hash_lower == hash_upper)

-- Test path separator normalization
local hash_forward = hash.mpq_hash("path/to/file", hash.HASH_NAME_A)
local hash_back = hash.mpq_hash("path\\to\\file", hash.HASH_NAME_A)
test("Hash normalizes path separators", hash_forward == hash_back)
-- }}}

-- {{{ Test: Hash table parsing
test_section("Hash Table Parsing")

local test_file = DIR .. "/assets/DAoW-2.1.w3x"
local file = io.open(test_file, "rb")
local file_data = file:read("*a")
file:close()

-- Parse header first
local hdr_result = header.open_w3x(test_file)
test("Header parsed", hdr_result ~= nil and hdr_result.mpq ~= nil)

-- Parse hash table
local hash_tbl, err = hashtable.parse(file_data, hdr_result.mpq)
test("Hash table parsed", hash_tbl ~= nil, err)

if hash_tbl then
    test("Has expected entry count", hash_tbl.entry_count == 32)

    -- List valid entries
    local files = hashtable.list_files(hash_tbl)
    test("Has valid entries", #files > 0, "found " .. #files)
    test("Entry count matches block count",
         #files == hdr_result.mpq.block_table_entries,
         string.format("files=%d, blocks=%d", #files, hdr_result.mpq.block_table_entries))
end
-- }}}

-- {{{ Test: File lookup
test_section("File Lookup")

if hash_tbl then
    -- Test known WC3 map files
    local w3i_idx = hashtable.find_file(hash_tbl, "war3map.w3i")
    test("Can find war3map.w3i", w3i_idx ~= nil)

    local w3e_idx = hashtable.find_file(hash_tbl, "war3map.w3e")
    test("Can find war3map.w3e", w3e_idx ~= nil)

    local wts_idx = hashtable.find_file(hash_tbl, "war3map.wts")
    test("Can find war3map.wts", wts_idx ~= nil)

    local j_idx = hashtable.find_file(hash_tbl, "war3map.j")
    -- Note: war3map.j may not exist in all maps (some use triggers only)
    test("war3map.j lookup works (nil ok)", j_idx == nil or type(j_idx) == "number")

    -- Test non-existent file
    local fake_idx = hashtable.find_file(hash_tbl, "nonexistent.txt")
    test("Returns nil for non-existent file", fake_idx == nil)

    -- Test case insensitivity
    local w3i_upper = hashtable.find_file(hash_tbl, "WAR3MAP.W3I")
    test("Case insensitive lookup", w3i_upper == w3i_idx)

    -- Test has_file helper
    test("has_file returns true", hashtable.has_file(hash_tbl, "war3map.w3i"))
    test("has_file returns false", not hashtable.has_file(hash_tbl, "fake.txt"))

    -- Print some info
    print("\n--- Found Files ---")
    print("war3map.w3i -> block " .. tostring(w3i_idx))
    print("war3map.w3e -> block " .. tostring(w3e_idx))
    print("war3map.wts -> block " .. tostring(wts_idx))
    print("war3map.j   -> block " .. tostring(j_idx))
end
-- }}}

-- {{{ Test: All map files
test_section("All Map Files")

local maps_tested = 0
local maps_passed = 0

local assets_dir = DIR .. "/assets"
local handle = io.popen("ls -1 " .. assets_dir .. "/*.w3x 2>/dev/null")
if handle then
    for filepath in handle:lines() do
        maps_tested = maps_tested + 1
        local basename = filepath:match("([^/]+)$")

        -- Open and parse
        local f = io.open(filepath, "rb")
        local data = f:read("*a")
        f:close()

        local h = header.open_w3x(filepath)
        if h and h.mpq then
            local ht = hashtable.parse(data, h.mpq)
            if ht then
                -- Try to find a common file
                local found = hashtable.find_file(ht, "war3map.w3i")
                if found ~= nil then
                    maps_passed = maps_passed + 1
                    print("  [OK] " .. basename)
                else
                    print("  [FAIL] " .. basename .. ": cannot find war3map.w3i")
                end
            else
                print("  [FAIL] " .. basename .. ": cannot parse hash table")
            end
        else
            print("  [FAIL] " .. basename .. ": cannot parse header")
        end
    end
    handle:close()
end

test("All maps lookup war3map.w3i", maps_passed == maps_tested,
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

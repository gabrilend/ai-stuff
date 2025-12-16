#!/usr/bin/env lua
-- Test script for MPQ block table module
-- Run from project root: lua src/tests/test_blocktable.lua

-- {{{ Setup
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"

-- Add src to package path
package.path = DIR .. "/src/?.lua;" .. package.path

local blocktable = require("mpq.blocktable")
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

-- {{{ Test: Flag parsing
test_section("Flag Parsing")

-- Test individual flags
local FLAGS = blocktable.FLAGS
test("EXISTS flag parsed", FLAGS.EXISTS == 0x80000000)
test("COMPRESS flag parsed", FLAGS.COMPRESS == 0x00000200)
test("ENCRYPTED flag parsed", FLAGS.ENCRYPTED == 0x00010000)
test("SINGLE_UNIT flag parsed", FLAGS.SINGLE_UNIT == 0x01000000)
-- }}}

-- {{{ Test: Block table parsing
test_section("Block Table Parsing")

local test_file = DIR .. "/assets/DAoW-2.1.w3x"
local file = io.open(test_file, "rb")
local file_data = file:read("*a")
file:close()

-- Parse header first
local hdr_result = header.open_w3x(test_file)
test("Header parsed", hdr_result ~= nil and hdr_result.mpq ~= nil)

-- Parse block table
local block_tbl, err = blocktable.parse(file_data, hdr_result.mpq)
test("Block table parsed", block_tbl ~= nil, err)

if block_tbl then
    test("Has expected entry count", block_tbl.entry_count == 26)

    -- Check individual entries
    local entry0 = blocktable.get_block(block_tbl, 0)
    test("Block 0 exists", entry0 ~= nil)
    test("Block 0 has EXISTS flag", entry0 and entry0.flags.exists)
    test("Block 0 has valid offset", entry0 and entry0.file_offset > 0)
    test("Block 0 has valid sizes", entry0 and entry0.compressed_size > 0)

    -- List all files
    local files = blocktable.list_files(block_tbl)
    test("Can list files", #files > 0, "found " .. #files)
    test("File count matches entry count", #files == block_tbl.entry_count,
         string.format("files=%d, entries=%d", #files, block_tbl.entry_count))
end
-- }}}

-- {{{ Test: Cross-reference with hash table
test_section("Cross-Reference Hash & Block Tables")

if block_tbl then
    -- Parse hash table
    local hash_tbl = hashtable.parse(file_data, hdr_result.mpq)
    test("Hash table parsed", hash_tbl ~= nil)

    if hash_tbl then
        -- Look up war3map.w3i and get its block
        local w3i_block_idx = hashtable.find_file(hash_tbl, "war3map.w3i")
        test("Found war3map.w3i in hash table", w3i_block_idx ~= nil)

        if w3i_block_idx then
            local w3i_block = blocktable.get_block(block_tbl, w3i_block_idx)
            test("Got block info for war3map.w3i", w3i_block ~= nil)

            if w3i_block then
                test("war3map.w3i block exists", w3i_block.flags.exists)
                test("war3map.w3i has valid offset", w3i_block.file_offset > 0)
                test("war3map.w3i has valid size", w3i_block.uncompressed_size > 0)

                print(string.format("\n--- war3map.w3i Block Info ---"))
                print(string.format("Offset: %d", w3i_block.file_offset))
                print(string.format("Compressed: %d bytes", w3i_block.compressed_size))
                print(string.format("Uncompressed: %d bytes", w3i_block.uncompressed_size))
                print(string.format("Encrypted: %s", tostring(w3i_block.flags.encrypted)))
                print(string.format("Compressed: %s", tostring(w3i_block.is_compressed)))
            end
        end

        -- Look up war3map.w3e
        local w3e_block_idx = hashtable.find_file(hash_tbl, "war3map.w3e")
        if w3e_block_idx then
            local w3e_block = blocktable.get_block(block_tbl, w3e_block_idx)
            test("war3map.w3e block exists", w3e_block and w3e_block.flags.exists)
        end
    end
end
-- }}}

-- {{{ Test: Compression detection
test_section("Compression Detection")

-- Test compression name function
test("zlib detected", blocktable.get_compression_name(0x02) == "zlib")
test("PKWARE detected", blocktable.get_compression_name(0x08) == "PKWARE")
test("bzip2 detected", blocktable.get_compression_name(0x10) == "bzip2")
test("Combined detected", blocktable.get_compression_name(0x0A) == "zlib+PKWARE")
test("None detected", blocktable.get_compression_name(0x00) == "none")
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
            local bt = blocktable.parse(data, h.mpq)
            if bt then
                -- Verify entries exist and make sense
                local valid = true
                for i = 0, bt.entry_count - 1 do
                    local entry = bt.entries[i]
                    if entry.flags.exists and entry.file_offset == 0 and entry.compressed_size == 0 then
                        valid = false
                        break
                    end
                end
                if valid then
                    maps_passed = maps_passed + 1
                    print("  [OK] " .. basename)
                else
                    print("  [FAIL] " .. basename .. ": invalid entries")
                end
            else
                print("  [FAIL] " .. basename .. ": cannot parse block table")
            end
        else
            print("  [FAIL] " .. basename .. ": cannot parse header")
        end
    end
    handle:close()
end

test("All maps parse block tables", maps_passed == maps_tested,
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

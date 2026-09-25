#!/usr/bin/env luajit
-- test_codecs.lua - the MPQ decompression methods, one by one
--
-- zlib and bzip2: data compressed here with the system libraries must come
-- back unchanged, and damaged data must be an error.
-- Sector rules: a sector stored at its full size is returned as-is; an
-- unknown method byte is an error.
-- Huffman and ADPCM: real sound files from the owner's Warcraft III install
-- (wc3-installs/reign-of-chaos/war3.mpq), read by both the project's reader
-- and StormLib, must match. Without the install that part is skipped with a
-- loud notice: counted as neither pass nor fail.
--
-- Run: luajit src/tests/test_codecs.lua [DIR]
-- Issue: issues/completed/113-remaining-mpq-compressions.md

-- {{{ Setup
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local ffi = require("ffi")
local codecs = require("mpq.system_codecs")
local extract = require("mpq.extract")

ffi.cdef[[
int compress2(unsigned char *dest, unsigned long *destLen,
              const unsigned char *source, unsigned long sourceLen, int level);
int BZ2_bzBuffToBuffCompress(char *dest, unsigned int *destLen,
                             char *source, unsigned int sourceLen,
                             int blockSize100k, int verbosity, int workFactor);
]]
local libz = ffi.load("libz.so.1")
local libbz2 = ffi.load("libbz2.so.1")
-- }}}

-- {{{ Test utilities
local test_count, pass_count, fail_count, skip_count = 0, 0, 0, 0

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

local function skip(name, reason)
    skip_count = skip_count + 1
    print("  [SKIP] " .. name .. " -- " .. reason .. " --")
end

local function test_section(name)
    print("\n=== " .. name .. " ===")
end
-- }}}

-- {{{ Fixtures
-- Text with enough repetition to compress, and some variety.
local SAMPLE = {}
for i = 1, 400 do
    SAMPLE[#SAMPLE + 1] = string.format("unit %04d hfoo footman hp=420 dmg=12-13; ", i)
end
SAMPLE = table.concat(SAMPLE)

-- {{{ local function zlib_compress
local function zlib_compress(text)
    local cap = #text + 1024
    local out = ffi.new("unsigned char[?]", cap)
    local out_len = ffi.new("unsigned long[1]", cap)
    assert(libz.compress2(out, out_len, text, #text, 9) == 0)
    return ffi.string(out, out_len[0])
end
-- }}}

-- {{{ local function bzip2_compress
local function bzip2_compress(text)
    local cap = #text + 1024
    local out = ffi.new("char[?]", cap)
    local out_len = ffi.new("unsigned int[1]", cap)
    local src = ffi.new("char[?]", #text)
    ffi.copy(src, text, #text)
    assert(libbz2.BZ2_bzBuffToBuffCompress(out, out_len, src, #text, 9, 0, 0) == 0)
    return ffi.string(out, out_len[0])
end
-- }}}
-- }}}

-- {{{ Tests: zlib and bzip2
test_section("zlib")
local z = zlib_compress(SAMPLE)
local z_out, z_err = codecs.zlib(z, #SAMPLE)
test("round trip", z_out == SAMPLE, z_err)
local damaged = z:sub(1, -2) .. string.char((z:byte(-1) + 1) % 256)
test("damaged checksum is an error", codecs.zlib(damaged, #SAMPLE) == nil)
local via_sector = extract.decompress_sector(string.char(0x02) .. z, false, true, #SAMPLE)
test("sector with method byte 0x02", via_sector == SAMPLE)

test_section("bzip2")
local b = bzip2_compress(SAMPLE)
local b_out, b_err = codecs.bzip2(b, #SAMPLE)
test("round trip", b_out == SAMPLE, b_err)
test("damaged data is an error", codecs.bzip2(b:sub(1, 20), #SAMPLE) == nil)
local via_sector_b = extract.decompress_sector(string.char(0x10) .. b, false, true, #SAMPLE)
test("sector with method byte 0x10", via_sector_b == SAMPLE)
-- }}}

-- {{{ Tests: sector rules
test_section("Sector rules")
local raw = string.char(0x02) .. string.rep("x", 99)
test("a sector at its full size is returned as stored",
    extract.decompress_sector(raw, false, true, #raw) == raw)
local unknown, unknown_err = extract.decompress_sector(string.char(0x20) .. "abc", false, true, 100)
test("unknown method (0x20 sparse) is an error", unknown == nil, "got data instead of an error")
test("the error names the mask", unknown_err and unknown_err:match("0x20") ~= nil, tostring(unknown_err))
-- }}}

-- {{{ Tests: Huffman and ADPCM against StormLib on real sound files
test_section("Huffman and ADPCM on war3.mpq sound (vs StormLib)")
local war3 = DIR .. "/wc3-installs/reign-of-chaos/war3.mpq"
local probe = io.open(war3, "rb")
if not probe then
    skip("war3.mpq sounds", "no Warcraft III install at " .. war3)
else
    probe:close()
    local mpq = require("mpq")
    local stormlib = require("mpq.stormlib")
    local counts = {}
    local original = extract.decompress_sector
    extract.decompress_sector = function(data, imp, comp, size)
        if comp and data and #data > 0 and #data ~= size then
            local m = data:byte(1)
            counts[m] = (counts[m] or 0) + 1
        end
        return original(data, imp, comp, size)
    end
    local ours = assert(mpq.open(war3))
    local theirs = stormlib.open(war3)
    local checked, same, first_bad = 0, 0, nil
    for _, e in ipairs(theirs:list("*.wav")) do
        if checked >= 60 then break end
        checked = checked + 1
        local a = theirs:read(e.name)
        local b = ours:extract(e.name)
        if a == b then same = same + 1 elseif not first_bad then first_bad = e.name end
    end
    ours:close()
    theirs:close()
    extract.decompress_sector = original
    test(string.format("%d of %d sound files identical", same, checked), checked > 0 and same == checked, first_bad)
    test("ADPCM mono + Huffman (0x41) exercised", (counts[0x41] or 0) > 0)
    test("ADPCM stereo + Huffman (0x81) exercised", (counts[0x81] or 0) > 0)
end
-- }}}

-- {{{ Summary
print("\n" .. string.rep("=", 50))
print(string.format("Tests: %d passed, %d failed, %d total (%d skipped)",
    pass_count, fail_count, test_count, skip_count))
if fail_count > 0 then
    print("SOME TESTS FAILED")
    os.exit(1)
else
    print("ALL TESTS PASSED")
    os.exit(0)
end
-- }}}

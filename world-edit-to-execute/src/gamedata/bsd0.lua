--[[
bsd0.lua - Blizzard's "BSD0" binary diffs, as shipped in Warcraft III patches

Each changed file in a Warcraft III patch (for example 1.21b's
War3TFT_121b_English.exe) is stored as a small header plus either the whole
new file or a diff against the old one. The diff is a BSDIFF40 patch whose
three parts (control, data, extra) are stored uncompressed, and the whole
diff is packed with a simple run-length code. This module unpacks and applies
it, checking the old file's CRC32 before and the new size after.

Entry header, 24 bytes, little-endian (worked out 2026-09-24 from the 1.21b
patch and confirmed against real base files):
  0  uint16  header size (0x18)
  2  uint8   0x04 (seen on every entry)
  3  uint8   kind: 0x01 = the whole new file follows; 0x04 = a BSD0 diff follows
  4  uint32  CRC32 of the old file (0 for whole files)
  8  uint32  size of the old file (0 for whole files)
 12  uint32  size of the new file
 16  uint64  a Windows FILETIME (when the file was made)

The run-length code and the BSDIFF40 application follow StormLib's
SFilePatchArchives.cpp (Decompress_RLE, ApplyFilePatch_BSD0):
  Copyright (c) Ladislav Zezula; StormLib is released under the MIT licence
  (deps/licenses/stormlib/LICENSE when built by scripts/build-dependencies.sh).

Needs LuaJIT (FFI byte buffers and the system zlib for CRC32).

Usage:
  local bsd0 = require("gamedata.bsd0")
  local header = bsd0.read_header(entry_bytes)
  local new_bytes, err = bsd0.apply(entry_bytes, old_bytes)   -- old_bytes nil for whole files

Issue: issues/112b-game-version-layers-per-map.md
]]

local ffi = require("ffi")
local bit = require("bit")

ffi.cdef[[
unsigned long crc32(unsigned long crc, const unsigned char *buf, unsigned int len);
]]
local zlib = ffi.load("libz.so.1")

local M = {}

M.KIND_WHOLE = 0x01
M.KIND_DIFF = 0x04
local HEADER_SIZE = 24

-- {{{ local function u32
local function u32(s, pos)
    local a, b, c, d = s:byte(pos, pos + 3)
    return a + b * 256 + c * 65536 + d * 16777216
end
-- }}}

-- {{{ function M.crc32
-- CRC32 of a Lua string, as an unsigned number.
function M.crc32(s)
    return tonumber(zlib.crc32(0, s, #s))
end
-- }}}

-- {{{ function M.read_header
-- Returns {kind, old_crc, old_size, new_size} or nil and an error.
function M.read_header(entry)
    if #entry < HEADER_SIZE then
        return nil, "entry shorter than its 24-byte header"
    end
    local header_size = entry:byte(1) + entry:byte(2) * 256
    if header_size ~= HEADER_SIZE then
        return nil, string.format("unexpected header size %d", header_size)
    end
    return {
        kind = entry:byte(4),
        old_crc = u32(entry, 5),
        old_size = u32(entry, 9),
        new_size = u32(entry, 13),
    }
end
-- }}}

-- {{{ local function unpack_rle
-- The run-length code: a byte with the top bit set means "copy the next
-- (byte & 0x7F) + 1 bytes as they are"; otherwise "leave (byte + 1) zero
-- bytes". The first 4 bytes of the packed data are its unpacked size.
-- Returns an FFI byte buffer and its size.
local function unpack_rle(packed, first)
    local unpacked_size = u32(packed, first)
    local out = ffi.new("uint8_t[?]", unpacked_size)   -- zero-filled
    local src = ffi.cast("const uint8_t *", packed)
    local pos = first - 1 + 4                            -- 0-based, after the size
    local stop = #packed
    local n = 0
    while pos < stop and n < unpacked_size do
        local byte = src[pos]
        pos = pos + 1
        if bit.band(byte, 0x80) ~= 0 then
            local count = bit.band(byte, 0x7F) + 1
            for _ = 1, count do
                if n == unpacked_size or pos == stop then break end
                out[n] = src[pos]
                n = n + 1
                pos = pos + 1
            end
        else
            n = n + byte + 1
        end
    end
    return out, unpacked_size
end
-- }}}

-- {{{ local function read_u64
local function read_u64(buf, at)
    local low = buf[at] + buf[at + 1] * 256 + buf[at + 2] * 65536 + buf[at + 3] * 16777216
    local high = buf[at + 4] + buf[at + 5] * 256 + buf[at + 6] * 65536 + buf[at + 7] * 16777216
    return low + high * 4294967296
end
-- }}}

-- {{{ local function read_u32
local function read_u32(buf, at)
    return buf[at] + buf[at + 1] * 256 + buf[at + 2] * 65536 + buf[at + 3] * 16777216
end
-- }}}

-- {{{ local function apply_bsdiff
-- patch: FFI buffer holding "BSDIFF40", three uint64 sizes, then the control
-- block (triples of uint32: bytes to add from the data block, bytes to copy
-- from the extra block, how far to move in the old file), the data block and
-- the extra block. "Add" means byte-wise addition to the old file's bytes.
local function apply_bsdiff(patch, patch_size, old, old_size, expected_new_size)
    if patch_size < 32 or ffi.string(patch, 8) ~= "BSDIFF40" then
        return nil, "diff does not start with BSDIFF40"
    end
    local ctrl_size = read_u64(patch, 8)
    local data_size = read_u64(patch, 16)
    local new_size = read_u64(patch, 24)
    if new_size ~= expected_new_size then
        return nil, string.format("diff makes %d bytes, header says %d", new_size, expected_new_size)
    end
    if 32 + ctrl_size + data_size > patch_size then
        return nil, "diff blocks run past the end of the diff"
    end

    local ctrl = 32
    local data = 32 + ctrl_size
    local extra = data + data_size
    local new = ffi.new("uint8_t[?]", new_size)
    local new_pos, old_pos = 0, 0

    while new_pos < new_size do
        if ctrl + 12 > 32 + ctrl_size then
            return nil, "control block ended before the new file was complete"
        end
        local add = read_u32(patch, ctrl)
        local copy = read_u32(patch, ctrl + 4)
        local move = read_u32(patch, ctrl + 8)
        ctrl = ctrl + 12

        if new_pos + add > new_size then
            return nil, "diff adds past the end of the new file"
        end
        ffi.copy(new + new_pos, patch + data, add)
        data = data + add

        -- Add the old file's bytes, as far as the old file reaches.
        local combine = add
        if old_pos + add >= old_size then
            combine = old_size - old_pos
        end
        for i = 0, combine - 1 do
            new[new_pos + i] = bit.band(new[new_pos + i] + old[old_pos + i], 0xFF)
        end
        new_pos = new_pos + add
        old_pos = old_pos + add

        if new_pos + copy > new_size then
            return nil, "diff copies past the end of the new file"
        end
        ffi.copy(new + new_pos, patch + extra, copy)
        extra = extra + copy
        new_pos = new_pos + copy

        -- The move is sign-and-magnitude: the top bit means "backwards".
        if move >= 0x80000000 then
            move = -(move - 0x80000000)
        end
        old_pos = old_pos + move
    end
    return ffi.string(new, new_size)
end
-- }}}

-- {{{ function M.apply
-- entry: the whole patch entry (header and payload), as a string.
-- old: the old file's bytes (string), required for diffs, ignored for whole files.
-- Returns the new file's bytes, or nil and an error. A diff whose old file
-- doesn't have the CRC32 and size the header names is refused: it was made
-- against a different file.
function M.apply(entry, old)
    local header, err = M.read_header(entry)
    if not header then
        return nil, err
    end

    if header.kind == M.KIND_WHOLE then
        local body = entry:sub(HEADER_SIZE + 1)
        if #body ~= header.new_size then
            return nil, string.format("whole file is %d bytes, header says %d", #body, header.new_size)
        end
        return body
    end

    if header.kind ~= M.KIND_DIFF then
        return nil, string.format("unknown entry kind 0x%02X", header.kind)
    end
    if old == nil then
        return nil, "a diff needs the old file"
    end
    if #old ~= header.old_size then
        return nil, string.format("old file is %d bytes, diff expects %d", #old, header.old_size)
    end
    local crc = M.crc32(old)
    if crc ~= header.old_crc then
        return nil, string.format("old file CRC32 0x%08X, diff expects 0x%08X", crc, header.old_crc)
    end

    local unpacked_size = u32(entry, HEADER_SIZE + 1)
    local packed_length = #entry - HEADER_SIZE - 4
    if packed_length >= unpacked_size then
        return nil, "uncompressed diff payload (not seen in any patch yet; format unconfirmed)"
    end
    local patch, patch_size = unpack_rle(entry, HEADER_SIZE + 1)

    local old_buf = ffi.new("uint8_t[?]", #old)
    ffi.copy(old_buf, old, #old)
    return apply_bsdiff(patch, patch_size, old_buf, #old, header.new_size)
end
-- }}}

return M

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
                 (run-length packed); 0x02 = a BSDIFF40 diff follows as is, with no
                 size word and no packing (two entries in Reign of Chaos 1.18a-1.20e);
                 0x00 = the oldest diff format, copy-and-insert (1.01-1.14b; below)
  4  uint32  CRC32 of the old file (0 for whole files)
  8  uint32  size of the old file (0 for whole files)
 12  uint32  size of the new file
 16  uint64  a Windows FILETIME (when the file was made)

The run-length code and the BSDIFF40 application follow StormLib's
SFilePatchArchives.cpp (Decompress_RLE, ApplyFilePatch_BSD0):
  Copyright (c) Ladislav Zezula; StormLib is released under the MIT licence
  (deps/licenses/stormlib/LICENSE when built by scripts/build-dependencies.sh).

Two generations of the run-length code (issue 112d, 2026-09-25). Patches
from 1.21a on count runs from 1: a byte with the top bit set copies
(byte & 0x7F) + 1 bytes, any other byte stands for byte + 1 zeros. Patches
before it (1.19a-1.20e seen) count from 32: (byte & 0x7F) + 32 bytes, or
byte + 32 zeros. Found by lining up the same file's diff in 1.20e and 1.21a,
and confirmed on all 218 of 1.20e's archive diffs: each rebuilds exactly the
file 1.21a's does. The bytes can't tell the two apart, so the caller says
which (M.RUN_STEP_1_21, M.RUN_STEP_1_20), chosen by the patch's version.

Needs LuaJIT (FFI byte buffers and the system zlib for CRC32).

Usage:
  local bsd0 = require("gamedata.bsd0")
  local header = bsd0.read_header(entry_bytes)
  local new_bytes, err = bsd0.apply(entry_bytes, old_bytes)   -- old_bytes nil for whole files
  local new_bytes, err = bsd0.apply(entry_bytes, old_bytes, bsd0.RUN_STEP_1_20)   -- a 1.20e-era patch

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
M.KIND_DIFF_OLDEST = 0x00     -- the copy-and-insert diff of 1.01-1.14b (see below)
M.KIND_DIFF_UNPACKED = 0x02   -- a BSDIFF40 diff stored as is (Reign of Chaos 1.18a-1.20e, rarely)
local HEADER_SIZE = 24

-- The run-length code's step: what a run's count byte is added to.
M.RUN_STEP_1_21 = 1    -- 1.21a and later
M.RUN_STEP_1_20 = 32   -- 1.19a-1.20e (and possibly earlier; issue 112d)

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
local function unpack_rle(packed, first, step)
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
            local count = bit.band(byte, 0x7F) + step
            for _ = 1, count do
                if n == unpacked_size or pos == stop then break end
                out[n] = src[pos]
                n = n + 1
                pos = pos + 1
            end
        else
            n = n + byte + step
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

        -- Every length is checked before memory is touched: these buffers are
        -- raw memory, and a malformed or misread diff (1.20b's War3.exe once
        -- was) otherwise reads past them and crashes the process.
        if new_pos + add > new_size then
            return nil, "diff adds past the end of the new file"
        end
        if data + add > extra then
            return nil, "diff adds past the end of its data block"
        end
        ffi.copy(new + new_pos, patch + data, add)
        data = data + add

        -- Add the old file's bytes where the old position lies inside the old
        -- file (as the reference bsdiff does; a move can take it outside).
        local first = math.max(0, -old_pos)
        local last = math.min(add, old_size - old_pos) - 1
        for i = first, last do
            new[new_pos + i] = bit.band(new[new_pos + i] + old[old_pos + i], 0xFF)
        end
        new_pos = new_pos + add
        old_pos = old_pos + add

        if new_pos + copy > new_size then
            return nil, "diff copies past the end of the new file"
        end
        if extra + copy > patch_size then
            return nil, "diff copies past the end of its extra block"
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

-- {{{ The oldest diff format (entry kind 0x00; patches 1.01 to 1.14b)
--[[
Worked out 2026-09-25 (issue 112d) by lining up known answers: files a
1.14b diff produced that no later patch changed appear byte for byte in the
1.19a layer. The rules below rebuild all 110 such files (six more differ
only by edits later patches made, a fixed typo, tuned numbers), and every
kind 0x00 diff in 1.14b (178), 1.11 (110) and Reign of Chaos 1.01 (9) and
1.06 (36) decodes to its declared size.

After the 24-byte header: two uint32 lengths, then two blocks of exactly
those lengths.

Block A rebuilds the file from records. Each starts with a little-endian
uint16: the top two bits are the record's type, the low 14 its length.
  type 0  insert: the next `length` bytes, as they are
  type 1  copy `length` bytes from the old file; a signed number follows,
          which changes the running offset (old position - new position)
  type 2  the same copy, adding a constant to every 16-bit word copied: the
          constant is the last two-byte insert (model files, whose index
          lists shift when vertices are added: 01 00 02 00 -> 05 00 06 00)
  type 3  `length` zero bytes (padding); no number follows
Block B then adds to 16-bit little-endian words of the rebuilt file, in
groups by amount, in ascending order of amount: a signed number (the first
group's amount) or an unsigned one (each later group's increase), then
unsigned position steps from 0 until a zero; a zero amount ends the list.

Numbers are variable length, low bits first, each form's later bytes
little-endian:
  0xxxxxxx                 7 bits
  10xxxxxx + 1 byte        6 bits + byte * 64
  110xxxxx + 2 bytes       5 bits + uint16 * 32
  1110xxxx + 3 bytes       4 bits + uint24 * 16 (not seen yet; by pattern)
Signed numbers take the last part as two's complement (0x68 is -24; a4 0c
is 804; b4 f3 is -780); unsigned ones don't (0x74 is 116).
]]

-- {{{ local function varnum
-- Reads a variable-length number at 1-based pos in s; returns it and the
-- next position. signed: whether the last part is two's complement.
local function varnum(s, pos, signed)
    local b = s:byte(pos)
    if not b then
        error("diff ends inside a number")
    end
    local low, rest, rest_bits, next_pos
    if b < 0x80 then
        low, rest, rest_bits, next_pos = 0, b, 7, pos + 1
        if signed and rest >= 64 then rest = rest - 128 end
        return rest, next_pos
    elseif b < 0xC0 then
        low, rest, rest_bits, next_pos = b % 64, s:byte(pos + 1), 8, pos + 2
        return low + ((signed and rest >= 128) and rest - 256 or rest) * 64, next_pos
    elseif b < 0xE0 then
        rest = s:byte(pos + 1) + s:byte(pos + 2) * 256
        return (b % 32) + ((signed and rest >= 32768) and rest - 65536 or rest) * 32, pos + 3
    end
    rest = s:byte(pos + 1) + s:byte(pos + 2) * 256 + s:byte(pos + 3) * 65536
    return (b % 16) + ((signed and rest >= 8388608) and rest - 16777216 or rest) * 16, pos + 4
end
-- }}}

-- {{{ local function apply_kind0
local function apply_kind0(entry, old, new_size)
    local a_length = u32(entry, HEADER_SIZE + 1)
    local b_length = u32(entry, HEADER_SIZE + 5)
    local a_first = HEADER_SIZE + 9
    if a_first + a_length + b_length - 1 > #entry then
        return nil, "diff blocks run past the end of the entry"
    end
    local A = entry:sub(a_first, a_first + a_length - 1)
    local B = entry:sub(a_first + a_length, a_first + a_length + b_length - 1)
    local new = ffi.new("uint8_t[?]", new_size + 1)   -- +1: a word add may touch the last byte's neighbour
    local old_size = #old
    local new_pos, offset, word_add = 0, 0, 0
    local pos = 1
    while pos <= #A do
        if pos + 1 > #A then
            return nil, "record header cut short"
        end
        local w = A:byte(pos) + A:byte(pos + 1) * 256
        pos = pos + 2
        local kind, length = bit.rshift(w, 14), bit.band(w, 0x3FFF)
        if new_pos + length > new_size then
            return nil, "diff writes past the end of the new file"
        end
        if kind == 0 then
            if pos + length - 1 > #A then
                return nil, "insert runs past the end of the diff"
            end
            ffi.copy(new + new_pos, A:sub(pos, pos + length - 1), length)
            if length == 2 then
                word_add = A:byte(pos) + A:byte(pos + 1) * 256
            end
            pos = pos + length
        elseif kind == 3 then
            ffi.fill(new + new_pos, length, 0)
        else
            local change
            change, pos = varnum(A, pos, true)
            offset = offset + change
            local from = new_pos + offset
            if from < 0 or from + length > old_size then
                return nil, "copy reaches outside the old file"
            end
            ffi.copy(new + new_pos, old:sub(from + 1, from + length), length)
            if kind == 2 then
                for i = 0, length - 2, 2 do
                    local word = (new[new_pos + i] + new[new_pos + i + 1] * 256 + word_add) % 65536
                    new[new_pos + i] = word % 256
                    new[new_pos + i + 1] = bit.rshift(word, 8)
                end
            end
        end
        new_pos = new_pos + length
    end
    if new_pos ~= new_size then
        return nil, string.format("diff makes %d bytes, header says %d", new_pos, new_size)
    end

    pos = 1
    local amount, first_group = 0, true
    while pos <= #B do
        local change
        change, pos = varnum(B, pos, first_group)
        if change == 0 then
            break
        end
        first_group = false
        amount = amount + change
        local at = 0
        while true do
            local step
            step, pos = varnum(B, pos, false)
            if step == 0 then
                break
            end
            at = at + step
            if at >= new_size then
                return nil, "word addition past the end of the new file"
            end
            local word = (new[at] + new[at + 1] * 256 + amount) % 65536
            new[at] = word % 256
            if at + 1 < new_size then
                new[at + 1] = bit.rshift(word, 8)
            end
        end
    end
    return ffi.string(new, new_size)
end
-- }}}
-- }}}

-- {{{ function M.apply
-- entry: the whole patch entry (header and payload), as a string.
-- old: the old file's bytes (string), required for diffs, ignored for whole files.
-- Returns the new file's bytes, or nil and an error. A diff whose old file
-- doesn't have the CRC32 and size the header names is refused: it was made
-- against a different file.
function M.apply(entry, old, run_step)
    run_step = run_step or M.RUN_STEP_1_21
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

    if header.kind ~= M.KIND_DIFF and header.kind ~= M.KIND_DIFF_UNPACKED and header.kind ~= M.KIND_DIFF_OLDEST then
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

    if header.kind == M.KIND_DIFF_OLDEST then
        return apply_kind0(entry, old, header.new_size)
    end

    -- Kind 0x02: the BSDIFF40 diff is stored as is, right after the header.
    if header.kind == M.KIND_DIFF_UNPACKED then
        local raw_size = #entry - HEADER_SIZE
        local patch = ffi.new("uint8_t[?]", raw_size)
        ffi.copy(patch, entry:sub(HEADER_SIZE + 1), raw_size)
        local old_buf = ffi.new("uint8_t[?]", #old)
        ffi.copy(old_buf, old, #old)
        return apply_bsdiff(patch, raw_size, old_buf, #old, header.new_size)
    end

    local unpacked_size = u32(entry, HEADER_SIZE + 1)
    local packed_length = #entry - HEADER_SIZE - 4
    if packed_length >= unpacked_size then
        return nil, "uncompressed diff payload (not seen in any patch yet; format unconfirmed)"
    end
    local patch, patch_size = unpack_rle(entry, HEADER_SIZE + 1, run_step)

    local old_buf = ffi.new("uint8_t[?]", #old)
    ffi.copy(old_buf, old, #old)
    return apply_bsdiff(patch, patch_size, old_buf, #old, header.new_size)
end
-- }}}

return M

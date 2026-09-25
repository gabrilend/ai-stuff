-- PKWARE DCL (Data Compression Library) Decompression
-- Pure Lua implementation of the "explode" algorithm used in older MPQ archives.
-- Based on StormLib's pklib/explode.c implementation.
-- Compatible with both LuaJIT and Lua 5.3+.

local compat = require("compat")
local band, bor, lshift, rshift = compat.band, compat.bor, compat.lshift, compat.rshift

local pkware = {}

-- {{{ Constants
local CMP_BINARY = 0
local CMP_ASCII = 1
-- }}}

-- {{{ Lookup Tables

-- Length code bit lengths (16 entries, 0-indexed in original)
local LenBits = {
    0x03, 0x02, 0x03, 0x03, 0x04, 0x04, 0x04, 0x05,
    0x05, 0x05, 0x05, 0x06, 0x06, 0x06, 0x07, 0x07,
}

-- Length codes (16 entries)
local LenCode = {
    0x05, 0x03, 0x01, 0x06, 0x0A, 0x02, 0x0C, 0x14,
    0x04, 0x18, 0x08, 0x30, 0x10, 0x20, 0x40, 0x00,
}

-- Extra bits for length codes (16 entries)
local ExLenBits = {
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
}

-- Base values for length codes (16 entries)
local LenBase = {
    0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007,
    0x0008, 0x000A, 0x000E, 0x0016, 0x0026, 0x0046, 0x0086, 0x0106,
}

-- Distance code bit lengths (64 entries)
local DistBits = {
    0x02, 0x04, 0x04, 0x05, 0x05, 0x05, 0x05, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06,
    0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07,
    0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07,
    0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08,
}

-- Distance codes (64 entries)
local DistCode = {
    0x03, 0x0D, 0x05, 0x19, 0x09, 0x11, 0x01, 0x3E, 0x1E, 0x2E, 0x0E, 0x36, 0x16, 0x26, 0x06, 0x3A,
    0x1A, 0x2A, 0x0A, 0x32, 0x12, 0x22, 0x42, 0x02, 0x7C, 0x3C, 0x5C, 0x1C, 0x6C, 0x2C, 0x4C, 0x0C,
    0x74, 0x34, 0x54, 0x14, 0x64, 0x24, 0x44, 0x04, 0x78, 0x38, 0x58, 0x18, 0x68, 0x28, 0x48, 0x08,
    0xF0, 0x70, 0xB0, 0x30, 0xD0, 0x50, 0x90, 0x10, 0xE0, 0x60, 0xA0, 0x20, 0xC0, 0x40, 0x80, 0x00,
}

-- Character bit lengths for ASCII mode (256 entries)
local ChBitsAsc = {
    0x0B, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x08, 0x07, 0x0C, 0x0C, 0x07, 0x0C, 0x0C,
    0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0D, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C,
    0x04, 0x0A, 0x08, 0x0C, 0x0A, 0x0C, 0x0A, 0x08, 0x07, 0x07, 0x08, 0x09, 0x07, 0x06, 0x07, 0x08,
    0x07, 0x06, 0x07, 0x07, 0x07, 0x07, 0x08, 0x07, 0x07, 0x08, 0x08, 0x0C, 0x0B, 0x07, 0x09, 0x0B,
    0x0C, 0x06, 0x07, 0x06, 0x06, 0x05, 0x07, 0x08, 0x08, 0x06, 0x0B, 0x09, 0x06, 0x07, 0x06, 0x06,
    0x07, 0x0B, 0x06, 0x06, 0x06, 0x07, 0x09, 0x08, 0x09, 0x09, 0x0B, 0x08, 0x0B, 0x09, 0x0C, 0x08,
    0x0C, 0x05, 0x06, 0x06, 0x06, 0x05, 0x06, 0x06, 0x06, 0x05, 0x0B, 0x07, 0x05, 0x06, 0x05, 0x05,
    0x06, 0x0A, 0x05, 0x05, 0x05, 0x05, 0x08, 0x07, 0x08, 0x08, 0x0A, 0x0B, 0x0B, 0x0C, 0x0C, 0x0C,
    0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D,
    0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D,
    0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D,
    0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C,
    0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C,
    0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C,
    0x0D, 0x0C, 0x0D, 0x0D, 0x0D, 0x0C, 0x0D, 0x0D, 0x0D, 0x0C, 0x0D, 0x0D, 0x0D, 0x0D, 0x0C, 0x0D,
    0x0D, 0x0D, 0x0C, 0x0C, 0x0C, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D, 0x0D,
}

-- Character codes for ASCII mode (256 entries)
local ChCodeAsc = {
    0x0490, 0x0FE0, 0x07E0, 0x0BE0, 0x03E0, 0x0DE0, 0x05E0, 0x09E0,
    0x01E0, 0x00B8, 0x0062, 0x0EE0, 0x06E0, 0x0022, 0x0AE0, 0x02E0,
    0x0CE0, 0x04E0, 0x08E0, 0x00E0, 0x0F60, 0x0760, 0x0B60, 0x0360,
    0x0D60, 0x0560, 0x1240, 0x0960, 0x0160, 0x0E60, 0x0660, 0x0A60,
    0x000F, 0x0250, 0x0038, 0x0260, 0x0050, 0x0C60, 0x0390, 0x00D8,
    0x0042, 0x0002, 0x0058, 0x01B0, 0x007C, 0x0029, 0x003C, 0x0098,
    0x005C, 0x0009, 0x001C, 0x006C, 0x002C, 0x004C, 0x0018, 0x000C,
    0x0074, 0x00E8, 0x0068, 0x0460, 0x0090, 0x0034, 0x00B0, 0x0710,
    0x0860, 0x0031, 0x0054, 0x0011, 0x0021, 0x0017, 0x0014, 0x00A8,
    0x0028, 0x0001, 0x0310, 0x0130, 0x003E, 0x0064, 0x001E, 0x002E,
    0x0024, 0x0510, 0x000E, 0x0036, 0x0016, 0x0044, 0x0030, 0x00C8,
    0x01D0, 0x00D0, 0x0110, 0x0048, 0x0610, 0x0150, 0x0060, 0x0088,
    0x0FA0, 0x0007, 0x0026, 0x0006, 0x003A, 0x001B, 0x001A, 0x002A,
    0x000A, 0x000B, 0x0210, 0x0004, 0x0013, 0x0032, 0x0003, 0x001D,
    0x0012, 0x0190, 0x000D, 0x0015, 0x0005, 0x0019, 0x0008, 0x0078,
    0x00F0, 0x0070, 0x0290, 0x0410, 0x0010, 0x07A0, 0x0BA0, 0x03A0,
    0x0240, 0x1C40, 0x0C40, 0x1440, 0x0440, 0x1840, 0x0840, 0x1040,
    0x0040, 0x1F80, 0x0F80, 0x1780, 0x0780, 0x1B80, 0x0B80, 0x1380,
    0x0380, 0x1D80, 0x0D80, 0x1580, 0x0580, 0x1980, 0x0980, 0x1180,
    0x0180, 0x1E80, 0x0E80, 0x1680, 0x0680, 0x1A80, 0x0A80, 0x1280,
    0x0280, 0x1C80, 0x0C80, 0x1480, 0x0480, 0x1880, 0x0880, 0x1080,
    0x0080, 0x1F00, 0x0F00, 0x1700, 0x0700, 0x1B00, 0x0B00, 0x1300,
    0x0DA0, 0x05A0, 0x09A0, 0x01A0, 0x0EA0, 0x06A0, 0x0AA0, 0x02A0,
    0x0CA0, 0x04A0, 0x08A0, 0x00A0, 0x0F20, 0x0720, 0x0B20, 0x0320,
    0x0D20, 0x0520, 0x0920, 0x0120, 0x0E20, 0x0620, 0x0A20, 0x0220,
    0x0C20, 0x0420, 0x0820, 0x0020, 0x0FC0, 0x07C0, 0x0BC0, 0x03C0,
    0x0DC0, 0x05C0, 0x09C0, 0x01C0, 0x0EC0, 0x06C0, 0x0AC0, 0x02C0,
    0x0CC0, 0x04C0, 0x08C0, 0x00C0, 0x0F40, 0x0740, 0x0B40, 0x0340,
    0x0300, 0x0D40, 0x1D00, 0x0D00, 0x1500, 0x0540, 0x0500, 0x1900,
    0x0900, 0x0940, 0x1100, 0x0100, 0x1E00, 0x0E00, 0x0140, 0x1600,
    0x0600, 0x1A00, 0x0E40, 0x0640, 0x0A40, 0x0A00, 0x1200, 0x0200,
    0x1C00, 0x0C00, 0x1400, 0x0400, 0x1800, 0x0800, 0x1000, 0x0000,
}
-- }}}

-- {{{ Build decode lookup tables
-- These are inverse lookup tables for O(1) decoding.
-- GenDecodeTabs: For each code with N bits, fill every 2^N-spaced index with that code.

-- {{{ gen_decode_tabs
local function gen_decode_tabs(codes, bits, count, table_size)
    local positions = {}
    for i = 0, table_size - 1 do
        positions[i] = 0
    end

    for i = 1, count do
        local code = codes[i]
        local nbits = bits[i]
        if nbits > 0 then
            local step = lshift(1, nbits)
            local index = code
            while index < table_size do
                positions[index] = i - 1  -- 0-based position
                index = index + step
            end
        end
    end

    return positions
end
-- }}}

-- Build lookup tables at module load time
local LenPositions = gen_decode_tabs(LenCode, LenBits, 16, 256)
local DistPositions = gen_decode_tabs(DistCode, DistBits, 64, 256)
-- }}}

-- {{{ BitStream class
local BitStream = {}
BitStream.__index = BitStream

-- {{{ new
function BitStream.new(data)
    local self = setmetatable({}, BitStream)
    self.data = data
    self.pos = 1
    self.bit_buff = 0
    self.extra_bits = 0
    return self
end
-- }}}

-- {{{ fill_buffer
function BitStream:fill_buffer()
    while self.extra_bits <= 24 and self.pos <= #self.data do
        local byte = self.data:byte(self.pos)
        self.bit_buff = bor(self.bit_buff, lshift(byte, self.extra_bits))
        self.extra_bits = self.extra_bits + 8
        self.pos = self.pos + 1
    end
end
-- }}}

-- {{{ peek_bits
function BitStream:peek_bits(n)
    self:fill_buffer()
    return band(self.bit_buff, lshift(1, n) - 1)
end
-- }}}

-- {{{ read_bits
function BitStream:read_bits(n)
    self:fill_buffer()
    if self.extra_bits < n then
        return nil
    end
    local value = band(self.bit_buff, lshift(1, n) - 1)
    self.bit_buff = rshift(self.bit_buff, n)
    self.extra_bits = self.extra_bits - n
    return value
end
-- }}}

-- {{{ waste_bits
function BitStream:waste_bits(n)
    self:fill_buffer()
    if self.extra_bits < n then
        return false
    end
    self.bit_buff = rshift(self.bit_buff, n)
    self.extra_bits = self.extra_bits - n
    return true
end
-- }}}
-- }}}

-- {{{ Decoding functions

-- {{{ decode_len
-- Decodes a length code using the lookup table.
local function decode_len(stream)
    -- Peek 8 bits and use lookup table
    local peek = stream:peek_bits(8)
    local len_pos = LenPositions[peek]
    local nbits = LenBits[len_pos + 1]

    -- Consume the bits
    if not stream:waste_bits(nbits) then
        return nil
    end

    -- Get extra bits if needed
    local extra_bits = ExLenBits[len_pos + 1]
    local base = LenBase[len_pos + 1]

    local extra_val = 0
    if extra_bits > 0 then
        extra_val = stream:read_bits(extra_bits)
        if extra_val == nil then
            return nil
        end
    end

    return base + extra_val
end
-- }}}

-- {{{ decode_dist
-- Decodes a distance value using the lookup table.
local function decode_dist(stream, dict_bits, rep_length)
    -- Peek 8 bits and use lookup table
    local peek = stream:peek_bits(8)
    local dist_pos = DistPositions[peek]
    local nbits = DistBits[dist_pos + 1]

    -- Consume the bits
    if not stream:waste_bits(nbits) then
        return nil
    end

    -- Read additional distance bits
    local extra_bits
    if rep_length == 2 then
        extra_bits = 2  -- For length 2, always use 2 bits
    else
        extra_bits = dict_bits
    end

    local dist_low = stream:read_bits(extra_bits)
    if dist_low == nil then
        return nil
    end

    -- Distance = (position << extra_bits) | low_bits + 1
    return bor(lshift(dist_pos, extra_bits), dist_low) + 1
end
-- }}}

-- {{{ decode_lit_binary
-- Decodes a literal or length code in binary mode.
local function decode_lit_binary(stream)
    -- First bit: 0 = literal byte, 1 = length code
    local flag = stream:read_bits(1)
    if flag == nil then
        return nil
    end

    if flag == 0 then
        -- Literal: read 8 bits directly
        return stream:read_bits(8)
    else
        -- Length code
        local length = decode_len(stream)
        if length == nil then
            return nil
        end
        -- Return value >= 0x100 indicates length code
        return 0x100 + length
    end
end
-- }}}

-- {{{ decode_lit_ascii
-- Decodes a literal or length code in ASCII mode.
-- ASCII mode uses the ChBitsAsc/ChCodeAsc tables for literals.
local function decode_lit_ascii(stream)
    -- First bit: 0 = ASCII literal, 1 = length code
    local flag = stream:read_bits(1)
    if flag == nil then
        return nil
    end

    if flag == 0 then
        -- ASCII literal: need to decode from the character tables
        -- This is more complex - need to try different bit lengths
        for nbits = 4, 13 do
            local peek = stream:peek_bits(nbits)
            for char = 0, 255 do
                if ChBitsAsc[char + 1] == nbits and ChCodeAsc[char + 1] == peek then
                    stream:waste_bits(nbits)
                    return char
                end
            end
        end
        return nil  -- No match found
    else
        -- Length code (same as binary)
        local length = decode_len(stream)
        if length == nil then
            return nil
        end
        return 0x100 + length
    end
end
-- }}}
-- }}}

-- {{{ pkware.decompress
-- Set to true to enable debug output
local DEBUG = os.getenv("PKWARE_DEBUG") == "1"

-- Decompresses PKWARE DCL data.
-- @param data: Compressed data including 2-byte header (cmp_type, dict_bits)
-- @param expected_size: Optional expected output size (from MPQ block table)
-- @return Decompressed data or nil, error
function pkware.decompress(data, expected_size)
    if not data or #data < 4 then
        return nil, "Invalid PKWARE data: too short"
    end

    -- Read header
    local cmp_type = data:byte(1)
    local dict_bits = data:byte(2)

    if DEBUG then
        print(string.format("[PKWARE] cmp_type=%d, dict_bits=%d, data_len=%d, expected=%s",
            cmp_type, dict_bits, #data, expected_size or "unknown"))
    end

    -- Validate
    if cmp_type ~= CMP_BINARY and cmp_type ~= CMP_ASCII then
        return nil, string.format("Invalid compression type: %d", cmp_type)
    end

    if dict_bits < 4 or dict_bits > 6 then
        return nil, string.format("Invalid dictionary bits: %d", dict_bits)
    end

    -- Create bit stream (skip 2-byte header)
    local stream = BitStream.new(data:sub(3))

    -- Select decode function
    local decode_lit = (cmp_type == CMP_ASCII) and decode_lit_ascii or decode_lit_binary

    -- Output buffer
    local output = {}
    local out_pos = 1
    local iteration = 0

    -- Main decompression loop
    while true do
        iteration = iteration + 1

        -- Check if we've output enough bytes (when expected_size is provided)
        if expected_size and (out_pos - 1) >= expected_size then
            if DEBUG then
                print(string.format("[PKWARE] Reached expected size %d at iter=%d", expected_size, iteration))
            end
            break
        end

        local literal = decode_lit(stream)

        if DEBUG and iteration <= 20 then
            print(string.format("[PKWARE] iter=%d, literal=%s, out_pos=%d",
                iteration, literal and string.format("0x%X", literal) or "nil", out_pos))
        end

        if literal == nil then
            break  -- End of stream or error
        end

        if literal < 0x100 then
            -- Literal byte
            output[out_pos] = string.char(literal)
            out_pos = out_pos + 1
        else
            -- Length code: literal - 0xFE gives the repetition length
            local rep_length = literal - 0xFE

            -- Check for end marker (length code that produces 0x305 - 0xFE = 519)
            if rep_length > 518 then
                break  -- End of stream
            end

            if DEBUG and iteration <= 20 then
                print(string.format("[PKWARE]   rep_length=%d, calling decode_dist", rep_length))
                print(string.format("[PKWARE]   stream state: pos=%d/%d, extra_bits=%d, bit_buff=0x%X",
                    stream.pos, #stream.data, stream.extra_bits, stream.bit_buff))
            end

            -- Decode distance
            local distance = decode_dist(stream, dict_bits, rep_length)
            if distance == nil then
                -- If we're close to expected output and stream is exhausted, treat as success
                if expected_size and (out_pos - 1) >= expected_size then
                    break
                end
                if DEBUG then
                    print(string.format("[PKWARE] FAIL: decode_dist returned nil at iter=%d", iteration))
                    print(string.format("[PKWARE]   stream: pos=%d/%d, extra_bits=%d, bit_buff=0x%X",
                        stream.pos, #stream.data, stream.extra_bits, stream.bit_buff))
                end
                return nil, "Failed to decode distance"
            end

            if DEBUG and iteration <= 20 then
                print(string.format("[PKWARE]   distance=%d", distance))
            end

            -- Validate distance
            if distance > out_pos - 1 then
                return nil, string.format("Invalid distance %d at position %d", distance, out_pos)
            end

            -- Copy bytes from output buffer
            local copy_from = out_pos - distance
            for _ = 1, rep_length do
                output[out_pos] = output[copy_from]
                out_pos = out_pos + 1
                copy_from = copy_from + 1
                -- Stop if we've reached expected size
                if expected_size and (out_pos - 1) >= expected_size then
                    break
                end
            end
        end
    end

    if DEBUG then
        print(string.format("[PKWARE] Done: %d bytes output", out_pos - 1))
    end

    return table.concat(output)
end
-- }}}

-- {{{ pkware.is_pkware
function pkware.is_pkware(data)
    if not data or #data < 2 then
        return false
    end

    local cmp_type = data:byte(1)
    local dict_bits = data:byte(2)

    return (cmp_type == CMP_BINARY or cmp_type == CMP_ASCII)
        and dict_bits >= 4 and dict_bits <= 6
end
-- }}}

-- {{{ Exports
pkware.CMP_BINARY = CMP_BINARY
pkware.CMP_ASCII = CMP_ASCII
-- }}}

return pkware

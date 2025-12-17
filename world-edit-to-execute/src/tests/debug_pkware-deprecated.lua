#!/usr/bin/env lua5.4
-- Temporary debug script to test PKWARE DCL decompression
-- Tests extraction from Daow6.2.w3x (uses PKWARE DCL compression)
-- Delete after implementation verified

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local mpq = require("mpq")
local compat = require("compat")
local band, bor, lshift, rshift = compat.band, compat.bor, compat.lshift, compat.rshift

-- {{{ Hex dump utility
local function hex_dump(data, limit)
    limit = limit or 32
    local result = {}
    for i = 1, math.min(limit, #data) do
        result[i] = string.format("%02X", data:byte(i))
    end
    return table.concat(result, " ")
end
-- }}}

-- {{{ Binary dump utility
local function bin_dump(value, bits)
    bits = bits or 8
    local result = {}
    for i = bits - 1, 0, -1 do
        result[#result + 1] = band(rshift(value, i), 1) == 1 and "1" or "0"
    end
    return table.concat(result)
end
-- }}}

-- {{{ Inline PKWARE decompressor with verbose debugging
local function decompress_verbose(data)
    print("\n=== Verbose PKWARE Decompression ===\n")

    if not data or #data < 4 then
        return nil, "Data too short"
    end

    local cmp_type = data:byte(1)
    local dict_bits = data:byte(2)

    print(string.format("Compression type: %d (%s)", cmp_type, cmp_type == 0 and "BINARY" or "ASCII"))
    print(string.format("Dictionary bits: %d (window size: %d bytes)", dict_bits, lshift(1, dict_bits + 6)))
    print("")

    -- Tables (same as pkware.lua)
    local LenBits = {
        0x03, 0x02, 0x03, 0x03, 0x04, 0x04, 0x04, 0x05,
        0x05, 0x05, 0x05, 0x06, 0x06, 0x06, 0x07, 0x07,
    }
    local LenCode = {
        0x05, 0x03, 0x01, 0x06, 0x0A, 0x02, 0x0C, 0x14,
        0x04, 0x18, 0x08, 0x30, 0x10, 0x20, 0x40, 0x00,
    }
    local ExLenBits = {
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
    }
    local LenBase = {
        0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007,
        0x0008, 0x000A, 0x000E, 0x0016, 0x0026, 0x0046, 0x0086, 0x0106,
    }
    local DistBits = {
        0x02, 0x04, 0x04, 0x05, 0x05, 0x05, 0x05, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x06,
        0x06, 0x06, 0x06, 0x06, 0x06, 0x06, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07,
        0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07,
        0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08,
    }
    local DistCode = {
        0x03, 0x0D, 0x05, 0x19, 0x09, 0x11, 0x01, 0x3E, 0x1E, 0x2E, 0x0E, 0x36, 0x16, 0x26, 0x06, 0x3A,
        0x1A, 0x2A, 0x0A, 0x32, 0x12, 0x22, 0x42, 0x02, 0x7C, 0x3C, 0x5C, 0x1C, 0x6C, 0x2C, 0x4C, 0x0C,
        0x74, 0x34, 0x54, 0x14, 0x64, 0x24, 0x44, 0x04, 0x78, 0x38, 0x58, 0x18, 0x68, 0x28, 0x48, 0x08,
        0xF0, 0x70, 0xB0, 0x30, 0xD0, 0x50, 0x90, 0x10, 0xE0, 0x60, 0xA0, 0x20, 0xC0, 0x40, 0x80, 0x00,
    }

    -- Build lookup tables
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
                    positions[index] = i - 1
                    index = index + step
                end
            end
        end
        return positions
    end

    local LenPositions = gen_decode_tabs(LenCode, LenBits, 16, 256)
    local DistPositions = gen_decode_tabs(DistCode, DistBits, 64, 256)

    -- Print some lookup table entries for verification
    print("Length lookup table sample (first 16):")
    for i = 0, 15 do
        print(string.format("  LenPositions[%02X] = %d", i, LenPositions[i]))
    end
    print("")

    print("Distance lookup table sample (first 16):")
    for i = 0, 15 do
        print(string.format("  DistPositions[%02X] = %d", i, DistPositions[i]))
    end
    print("")

    -- Bit stream
    local stream = {
        data = data:sub(3),
        pos = 1,
        bit_buff = 0,
        extra_bits = 0,
    }

    local function fill_buffer()
        while stream.extra_bits <= 24 and stream.pos <= #stream.data do
            local byte = stream.data:byte(stream.pos)
            stream.bit_buff = bor(stream.bit_buff, lshift(byte, stream.extra_bits))
            stream.extra_bits = stream.extra_bits + 8
            stream.pos = stream.pos + 1
        end
    end

    local function peek_bits(n)
        fill_buffer()
        return band(stream.bit_buff, lshift(1, n) - 1)
    end

    local function read_bits(n)
        fill_buffer()
        if stream.extra_bits < n then
            return nil
        end
        local value = band(stream.bit_buff, lshift(1, n) - 1)
        stream.bit_buff = rshift(stream.bit_buff, n)
        stream.extra_bits = stream.extra_bits - n
        return value
    end

    local function waste_bits(n)
        fill_buffer()
        if stream.extra_bits < n then
            return false
        end
        stream.bit_buff = rshift(stream.bit_buff, n)
        stream.extra_bits = stream.extra_bits - n
        return true
    end

    -- Decompression
    local output = {}
    local out_pos = 1
    local iteration = 0
    local max_iterations = 50  -- Limit for debugging

    print("=== Starting decompression loop ===\n")

    while iteration < max_iterations do
        iteration = iteration + 1

        fill_buffer()
        print(string.format("--- Iteration %d ---", iteration))
        print(string.format("  Stream pos: %d/%d, bit_buff: 0x%08X, extra_bits: %d",
            stream.pos, #stream.data, stream.bit_buff, stream.extra_bits))

        -- Read first bit (literal vs length flag)
        local flag = read_bits(1)
        if flag == nil then
            print("  END: No more bits for flag")
            break
        end

        print(string.format("  Flag bit: %d (%s)", flag, flag == 0 and "LITERAL" or "LENGTH"))

        if flag == 0 then
            -- Literal byte
            local literal = read_bits(8)
            if literal == nil then
                print("  ERROR: Not enough bits for literal")
                break
            end
            print(string.format("  Literal byte: 0x%02X ('%s')", literal,
                (literal >= 32 and literal < 127) and string.char(literal) or "?"))
            output[out_pos] = string.char(literal)
            out_pos = out_pos + 1
        else
            -- Length code
            local peek = peek_bits(8)
            print(string.format("  Length decode: peek=%02X (%s)", peek, bin_dump(peek)))
            local len_pos = LenPositions[peek]
            local nbits = LenBits[len_pos + 1]
            print(string.format("  Length lookup: pos=%d, nbits=%d", len_pos, nbits))

            if not waste_bits(nbits) then
                print("  ERROR: Not enough bits for length code")
                break
            end

            local extra_bits = ExLenBits[len_pos + 1]
            local base = LenBase[len_pos + 1]
            print(string.format("  Length params: base=%d, extra_bits=%d", base, extra_bits))

            local extra_val = 0
            if extra_bits > 0 then
                extra_val = read_bits(extra_bits)
                if extra_val == nil then
                    print("  ERROR: Not enough bits for length extra")
                    break
                end
                print(string.format("  Length extra value: %d", extra_val))
            end

            local length = base + extra_val
            local rep_length = length + 2  -- Actual repeat count

            print(string.format("  Decoded length: %d, rep_length: %d", length, rep_length))

            -- Check for end marker
            if length >= 0x105 then  -- End of stream marker
                print("  END: Stream end marker reached")
                break
            end

            -- Decode distance
            print("")
            print("  Distance decode:")
            fill_buffer()
            print(string.format("    bit_buff before: 0x%08X, extra_bits: %d", stream.bit_buff, stream.extra_bits))

            peek = peek_bits(8)
            print(string.format("    peek=%02X (%s)", peek, bin_dump(peek)))
            local dist_pos = DistPositions[peek]
            local dist_nbits = DistBits[dist_pos + 1]
            print(string.format("    dist_pos=%d, dist_nbits=%d", dist_pos, dist_nbits))

            if not waste_bits(dist_nbits) then
                print("    ERROR: Not enough bits for distance code")
                return nil, "Failed to decode distance code bits"
            end

            -- Extra bits for distance
            local dist_extra_bits
            if rep_length == 2 then
                dist_extra_bits = 2
            else
                dist_extra_bits = dict_bits
            end
            print(string.format("    dist_extra_bits=%d (rep_length=%d)", dist_extra_bits, rep_length))

            fill_buffer()
            print(string.format("    bit_buff after waste: 0x%08X, extra_bits: %d", stream.bit_buff, stream.extra_bits))

            local dist_low = read_bits(dist_extra_bits)
            if dist_low == nil then
                print("    ERROR: Not enough bits for distance low bits")
                return nil, "Failed to decode distance low bits"
            end
            print(string.format("    dist_low=%d", dist_low))

            local distance = bor(lshift(dist_pos, dist_extra_bits), dist_low) + 1
            print(string.format("    DISTANCE = (%d << %d) | %d + 1 = %d",
                dist_pos, dist_extra_bits, dist_low, distance))

            -- Validate
            if distance > out_pos - 1 then
                print(string.format("    ERROR: Invalid distance %d (output has %d bytes)", distance, out_pos - 1))
                return nil, string.format("Invalid distance %d at position %d", distance, out_pos)
            end

            -- Copy
            print(string.format("    Copying %d bytes from offset -%d", rep_length, distance))
            local copy_from = out_pos - distance
            local copied = {}
            for _ = 1, rep_length do
                output[out_pos] = output[copy_from]
                copied[#copied + 1] = string.format("%02X", output[copy_from]:byte())
                out_pos = out_pos + 1
                copy_from = copy_from + 1
            end
            print("    Copied: " .. table.concat(copied, " "))
        end

        print("")
    end

    print(string.format("\n=== Decompression finished ==="))
    print(string.format("Output: %d bytes", out_pos - 1))
    if out_pos > 1 then
        print("First 32 bytes: " .. hex_dump(table.concat(output), 32))
    end

    return table.concat(output)
end
-- }}}

-- {{{ Test actual pkware module extraction
local function test_pkware_module()
    print("\n=== Test pkware.lua Module Extraction ===\n")

    local map_path = DIR .. "/assets/Daow6.2.w3x"
    local archive = mpq.open(map_path)
    if not archive then
        print("Cannot open archive")
        return false
    end

    local data, err = archive:extract("war3map.w3i")
    archive:close()

    if data then
        print("SUCCESS: " .. #data .. " bytes")
        print("First 32 bytes: " .. hex_dump(data, 32))
        return true
    else
        print("FAILED: " .. tostring(err))
        return false
    end
end
-- }}}

-- {{{ Main test
local function main()
    print("=== PKWARE DCL Debug Script ===\n")

    local map_path = DIR .. "/assets/Daow6.2.w3x"

    local archive = mpq.open(map_path)
    if not archive then
        print("Cannot open archive")
        return
    end
    print("Archive opened: " .. map_path)

    -- Get a file with PKWARE compression
    local filename = "war3map.w3i"
    local block = archive:get_block_info(filename)
    if not block then
        print("File not found: " .. filename)
        archive:close()
        return
    end

    print("\nBlock info for " .. filename .. ":")
    print("  compressed_size: " .. block.compressed_size)
    print("  uncompressed_size: " .. block.uncompressed_size)
    print("  flags.implode: " .. tostring(block.flags.implode))
    print("  flags.compress: " .. tostring(block.flags.compress))

    -- Get raw sector data
    local extract = require("mpq.extract")
    local hashtable = require("mpq.hashtable")
    local blocktable = require("mpq.blocktable")
    local header = require("mpq.header")

    local headers = header.open_w3x(map_path)
    local f = io.open(map_path, "rb")
    local file_data = f:read("*a")
    f:close()

    local hash_table = hashtable.parse(file_data, headers.mpq)
    local block_table = blocktable.parse(file_data, headers.mpq)

    local block_index = hashtable.find_file(hash_table, filename)
    local block_info = blocktable.get_block(block_table, block_index)

    local sectors, err = extract.extract_file_data(file_data, block_info, headers.mpq.sector_size, filename)
    if not sectors then
        print("Failed to extract sectors: " .. tostring(err))
        archive:close()
        return
    end

    print(string.format("\nGot %d sector(s)", #sectors))

    -- Look at first sector
    local sector = sectors[1]
    print(string.format("\nSector 1: %d bytes", #sector))
    print("Raw: " .. hex_dump(sector, 48))

    local comp_flag = sector:byte(1)
    print(string.format("Compression flag: 0x%02X", comp_flag))

    if comp_flag == 0x08 then
        print("-> PKWARE DCL compression")
        local pkware_data = sector:sub(2)
        print("PKWARE data (" .. #pkware_data .. " bytes): " .. hex_dump(pkware_data, 32))

        -- Verbose decompression
        decompress_verbose(pkware_data)
    else
        print("Not PKWARE compression, flag = " .. comp_flag)
    end

    archive:close()
end
-- }}}

-- Run tests
print("=== Running pkware module test first ===")
local module_works = test_pkware_module()

if not module_works then
    print("\n=== Module failed, running verbose debug ===")
    main()
else
    print("\npkware.lua module is working correctly!")
end

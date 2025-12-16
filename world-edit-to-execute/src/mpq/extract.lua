-- MPQ File Extraction
-- Extracts files from MPQ archives with decryption and decompression.
-- Uses Python3 zlib for decompression (temporary solution until pure Lua).
-- Compatible with both LuaJIT and Lua 5.3+.

local compat = require("compat")
local band, bxor = compat.band, compat.bxor
local hash = require("mpq.hash")

local extract = {}

-- {{{ Constants
local COMPRESSION = {
    HUFFMAN      = 0x01,
    ZLIB         = 0x02,
    PKWARE       = 0x08,
    BZIP2        = 0x10,
    SPARSE       = 0x20,
    ADPCM_MONO   = 0x40,
    ADPCM_STEREO = 0x80,
}
-- }}}

-- {{{ compute_file_key
-- Computes the decryption key for an encrypted file.
function extract.compute_file_key(filename, block)
    -- Extract base filename (remove path, use backslash as separator)
    local basename = filename:match("\\([^\\]+)$") or filename:match("/([^/]+)$") or filename

    -- Compute base key from filename
    local key = hash.mpq_hash(basename, hash.HASH_FILE_KEY)

    -- Adjust key if FIX_KEY flag is set
    if block.flags.fix_key then
        key = band(bxor(key + block.file_offset, block.uncompressed_size), 0xFFFFFFFF)
    end

    return key
end
-- }}}

-- {{{ decrypt_sector
-- Decrypts a single sector of data.
-- Handles non-aligned data by padding to 4-byte boundary.
function extract.decrypt_sector(data, key)
    local original_len = #data
    local remainder = original_len % 4

    if remainder == 0 then
        return hash.decrypt_block(data, key)
    end

    -- Pad with zeros to 4-byte boundary
    local padded = data .. string.rep("\0", 4 - remainder)
    local decrypted = hash.decrypt_block(padded, key)
    -- Return only the original length
    return decrypted:sub(1, original_len)
end
-- }}}

-- {{{ decompress_zlib
-- Decompresses zlib data using Python3 (temporary solution).
-- MPQ files use zlib format but the Adler-32 checksum may be corrupted
-- due to decryption padding, so we use raw deflate mode.
local function decompress_zlib(data)
    -- Check for zlib header and skip it
    local has_zlib_header = #data >= 2 and data:byte(1) == 0x78
    local deflate_data = data
    if has_zlib_header then
        -- Skip 2-byte zlib header, use raw deflate
        deflate_data = data:sub(3)
    end

    -- Write compressed data to temp file
    local tmp_in = os.tmpname()
    local tmp_out = os.tmpname()

    local f = io.open(tmp_in, "wb")
    f:write(deflate_data)
    f:close()

    -- Use Python3 for decompression with raw deflate mode (-15)
    local cmd = string.format(
        'python3 -c "' ..
        'import sys,zlib; ' ..
        'd=open(\'%s\',\'rb\').read(); ' ..
        'sys.stdout.buffer.write(zlib.decompress(d,-15))" > "%s" 2>/dev/null',
        tmp_in, tmp_out
    )

    local ok = os.execute(cmd)

    -- Read decompressed data
    local result = nil
    if ok then
        f = io.open(tmp_out, "rb")
        if f then
            result = f:read("*a")
            f:close()
        end
    end

    -- Cleanup
    os.remove(tmp_in)
    os.remove(tmp_out)

    return result
end
-- }}}

-- {{{ decompress_sector
-- Decompresses a sector based on compression flags.
function extract.decompress_sector(data, is_implode, is_compress)
    if not data or #data == 0 then
        return ""
    end

    if not is_implode and not is_compress then
        return data
    end

    if is_implode then
        -- PKWARE DCL - not implemented yet
        return nil, "PKWARE DCL decompression not implemented"
    end

    if is_compress then
        -- Multi-compression: first byte indicates methods
        local flags = data:byte(1)
        if not flags then
            return data  -- Empty data
        end
        data = data:sub(2)

        -- Handle each compression in reverse order
        if band(flags, COMPRESSION.BZIP2) ~= 0 then
            return nil, "bzip2 decompression not implemented"
        end

        if band(flags, COMPRESSION.PKWARE) ~= 0 then
            return nil, "PKWARE DCL decompression not implemented"
        end

        if band(flags, COMPRESSION.ZLIB) ~= 0 then
            local decompressed = decompress_zlib(data)
            if not decompressed then
                return nil, "zlib decompression failed"
            end
            data = decompressed
        end

        if band(flags, COMPRESSION.HUFFMAN) ~= 0 then
            return nil, "Huffman decompression not implemented"
        end

        return data
    end

    return data
end
-- }}}

-- {{{ read_sector_offsets
-- Reads the sector offset table for multi-sector files.
local function read_sector_offsets(data, start_offset, num_entries)
    local offsets = {}
    for i = 0, num_entries - 1 do
        local pos = start_offset + (i * 4) + 1
        offsets[i] = compat.unpack_uint32(data, pos)
    end
    return offsets
end
-- }}}

-- {{{ extract_file_data
-- Extracts raw file data (after decryption, before decompression).
-- Note: block.absolute_offset is a 1-based Lua string position
function extract.extract_file_data(file_data, block, sector_size, filename)
    local offset = block.absolute_offset

    -- Determine number of sectors
    local num_sectors
    if block.flags.single_unit then
        num_sectors = 1
    else
        num_sectors = math.ceil(block.uncompressed_size / sector_size)
    end

    -- For encrypted files, compute the key
    local key = nil
    if block.flags.encrypted then
        if not filename then
            return nil, "Filename required for encrypted file extraction"
        end
        key = extract.compute_file_key(filename, block)
    end

    local sectors = {}

    if block.flags.single_unit then
        -- Single unit: entire file as one chunk
        -- offset is 1-based, so use directly
        local raw = file_data:sub(offset, offset + block.compressed_size - 1)

        if key then
            raw = extract.decrypt_sector(raw, key)
        end

        sectors[1] = raw
    else
        -- Multi-sector: read sector offset table first
        local offset_table_size = (num_sectors + 1) * 4
        -- offset is 1-based, so use directly
        local offset_table_data = file_data:sub(offset, offset + offset_table_size - 1)

        if key then
            -- Sector offset table is encrypted with key - 1
            offset_table_data = extract.decrypt_sector(offset_table_data, key - 1)
        end

        local offsets = read_sector_offsets(offset_table_data, 0, num_sectors + 1)

        -- Read each sector
        for i = 0, num_sectors - 1 do
            -- offsets[i] is relative to file data start (0-based)
            -- Convert to absolute 1-based position
            local sector_start = offset + offsets[i]
            local sector_size_actual = offsets[i + 1] - offsets[i]
            local sector_data = file_data:sub(sector_start, sector_start + sector_size_actual - 1)

            if key then
                -- Each sector encrypted with key + sector_index
                sector_data = extract.decrypt_sector(sector_data, key + i)
            end

            sectors[i + 1] = sector_data
        end
    end

    return sectors
end
-- }}}

-- {{{ extract_file
-- Extracts and decompresses a complete file.
-- Returns the uncompressed file contents or nil, error.
function extract.extract_file(file_data, hash_table, block_table, sector_size, filename)
    -- Find file in hash table
    local hashtable = require("mpq.hashtable")
    local blocktable = require("mpq.blocktable")

    local block_index = hashtable.find_file(hash_table, filename)
    if not block_index then
        return nil, "File not found: " .. filename
    end

    -- Get block info
    local block = blocktable.get_block(block_table, block_index)
    if not block then
        return nil, "Invalid block index: " .. block_index
    end

    if not block.flags.exists then
        return nil, "File deleted: " .. filename
    end

    -- Handle uncompressed files
    if not block.is_compressed or block.compressed_size == block.uncompressed_size then
        local offset = block.absolute_offset
        -- offset is 1-based, use directly
        local data = file_data:sub(offset, offset + block.uncompressed_size - 1)

        if block.flags.encrypted then
            local key = extract.compute_file_key(filename, block)
            -- For uncompressed files, we still need to handle sector-based decryption
            -- But if it's a single unit and not compressed, decrypt directly
            if block.flags.single_unit then
                data = extract.decrypt_sector(data, key)
            end
        end

        return data
    end

    -- Extract sectors (handles decryption)
    local sectors, err = extract.extract_file_data(file_data, block, sector_size, filename)
    if not sectors then
        return nil, err
    end

    -- Decompress each sector
    local output = {}
    for i, sector in ipairs(sectors) do
        local decompressed, decomp_err = extract.decompress_sector(
            sector, block.flags.implode, block.flags.compress
        )
        if not decompressed then
            return nil, "Sector " .. i .. " decompression failed: " .. (decomp_err or "unknown")
        end
        output[i] = decompressed
    end

    return table.concat(output)
end
-- }}}

-- {{{ extract_to_file
-- Extracts a file and writes it to disk.
function extract.extract_to_file(file_data, hash_table, block_table, sector_size, filename, output_path)
    local data, err = extract.extract_file(file_data, hash_table, block_table, sector_size, filename)
    if not data then
        return nil, err
    end

    local f = io.open(output_path, "wb")
    if not f then
        return nil, "Cannot write to: " .. output_path
    end

    f:write(data)
    f:close()

    return #data
end
-- }}}

return extract

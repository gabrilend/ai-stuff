-- MPQ File Extraction
-- Extracts files from MPQ archives with decryption and decompression.
-- Decompression: PKWARE, Huffman and ADPCM in Lua (pkware.lua, huffman.lua,
-- adpcm.lua); zlib and bzip2 through the system libraries via LuaJIT's FFI
-- (system_codecs.lua). Needs LuaJIT for zlib/bzip2 sectors.

local compat = require("compat")
local band, bxor = compat.band, compat.bxor
local hash = require("mpq.hash")
local pkware = require("mpq.pkware")
local huffman = require("mpq.huffman")
local adpcm = require("mpq.adpcm")
local system_codecs = require("mpq.system_codecs")

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
-- MPQ encryption works on whole 4-byte words. When a sector's length isn't a
-- multiple of 4, Storm decrypts only the whole words and leaves the last 1-3
-- bytes exactly as stored. (An earlier version padded those bytes with zeros
-- and decrypted them too, which garbled the end of any sector with an odd
-- length; found 2026-09-24 when StormLib and this reader disagreed on the last
-- 7 bytes of Daow6.2.w3x's war3map.w3e.)
function extract.decrypt_sector(data, key)
    local whole = #data - (#data % 4)
    if whole == #data then
        return hash.decrypt_block(data, key)
    end
    return hash.decrypt_block(data:sub(1, whole), key) .. data:sub(whole + 1)
end
-- }}}

-- {{{ decompression steps
-- The methods a sector's first byte can name, in the order Storm undoes them
-- (StormLib's dcmp_table): bzip2, PKWARE, zlib, Huffman, ADPCM stereo, ADPCM
-- mono. Each step's output is capped at the sector's expected size.
local DECOMPRESS_ORDER = {
    { mask = COMPRESSION.BZIP2, name = "bzip2",
      run = function(data, size) return system_codecs.bzip2(data, size) end },
    { mask = COMPRESSION.PKWARE, name = "PKWARE DCL",
      run = function(data, size) return pkware.decompress(data, size) end },
    { mask = COMPRESSION.ZLIB, name = "zlib",
      run = function(data, size) return system_codecs.zlib(data, size) end },
    { mask = COMPRESSION.HUFFMAN, name = "Huffman",
      run = function(data, size) return huffman.decompress(data, size) end },
    { mask = COMPRESSION.ADPCM_STEREO, name = "ADPCM stereo",
      run = function(data, size) return adpcm.decompress(data, size, 2) end },
    { mask = COMPRESSION.ADPCM_MONO, name = "ADPCM mono",
      run = function(data, size) return adpcm.decompress(data, size, 1) end },
}

local KNOWN_METHODS = 0
for _, step in ipairs(DECOMPRESS_ORDER) do
    KNOWN_METHODS = KNOWN_METHODS + step.mask
end
-- }}}

-- {{{ decompress_sector
-- Decompresses one sector.
-- @param data: the sector's stored bytes (already decrypted)
-- @param is_implode: the file's IMPLODE flag (whole file uses PKWARE, no method byte)
-- @param is_compress: the file's COMPRESS flag (each sector starts with a method byte)
-- @param expected_size: the sector's uncompressed size
--
-- A sector whose stored size already equals its expected size was stored
-- raw: the writer found compression didn't help and kept the bytes as they
-- were, with no method byte (StormLib does the same check). Treating such a
-- sector's first byte as a method byte would corrupt it.
function extract.decompress_sector(data, is_implode, is_compress, expected_size)
    if not data or #data == 0 then
        return ""
    end
    if not is_implode and not is_compress then
        return data
    end
    if expected_size and #data == expected_size then
        return data
    end

    if is_implode then
        local decompressed, err = pkware.decompress(data, expected_size)
        if not decompressed then
            return nil, "PKWARE DCL decompression failed: " .. (err or "unknown")
        end
        return decompressed
    end

    local methods = data:byte(1)
    if band(methods, KNOWN_METHODS) ~= methods then
        return nil, string.format("unsupported compression method mask 0x%02X", methods)
    end
    data = data:sub(2)

    for _, step in ipairs(DECOMPRESS_ORDER) do
        if band(methods, step.mask) ~= 0 then
            local decompressed, err = step.run(data, expected_size)
            if not decompressed then
                return nil, step.name .. " decompression failed: " .. (err or "unknown")
            end
            data = decompressed
        end
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

    local block_index = hashtable.find_file(hash_table, filename, block_table.entry_count)
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
            if block.flags.single_unit then
                -- One chunk, one key.
                data = extract.decrypt_sector(data, key)
            else
                -- Uncompressed files are still stored in sectors, and each
                -- sector is encrypted with key + its index, like compressed
                -- ones. (An earlier version returned these files still
                -- encrypted; found 2026-09-24 on Daow1.23.1B.w3x's (listfile).)
                local parts = {}
                local index = 0
                for start = 1, #data, sector_size do
                    local chunk = data:sub(start, start + sector_size - 1)
                    parts[#parts + 1] = extract.decrypt_sector(chunk, key + index)
                    index = index + 1
                end
                data = table.concat(parts)
            end
        end

        return data
    end

    -- Extract sectors (handles decryption)
    local sectors, err = extract.extract_file_data(file_data, block, sector_size, filename)
    if not sectors then
        return nil, err
    end

    -- Calculate number of sectors and remaining size
    local num_sectors = #sectors
    local remaining_size = block.uncompressed_size

    -- Decompress each sector
    local output = {}
    for i, sector in ipairs(sectors) do
        -- Calculate expected decompressed size for this sector
        -- Last sector may be smaller than sector_size
        local expected_sector_size
        if i == num_sectors then
            expected_sector_size = remaining_size
        else
            expected_sector_size = math.min(sector_size, remaining_size)
        end

        local decompressed, decomp_err = extract.decompress_sector(
            sector, block.flags.implode, block.flags.compress, expected_sector_size
        )
        if not decompressed then
            return nil, "Sector " .. i .. " decompression failed: " .. (decomp_err or "unknown")
        end
        output[i] = decompressed
        remaining_size = remaining_size - #decompressed
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

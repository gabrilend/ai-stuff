-- MPQ Block Table Parser
-- Parses block tables to get file metadata: offset, sizes, compression, encryption.
-- Each block describes how a file is stored in the archive.

local hash = require("mpq.hash")

local blocktable = {}

-- {{{ Constants
local BLOCK_ENTRY_SIZE = 16

-- Block flags
blocktable.FLAGS = {
    IMPLODE       = 0x00000100,  -- PKWARE DCL compressed
    COMPRESS      = 0x00000200,  -- Multi-method compressed (check first byte)
    ENCRYPTED     = 0x00010000,  -- File is encrypted
    FIX_KEY       = 0x00020000,  -- Encryption key adjusted by offset
    PATCH_FILE    = 0x00100000,  -- Patch file (not used in WC3)
    SINGLE_UNIT   = 0x01000000,  -- File stored as single unit (no sectors)
    DELETE_MARKER = 0x02000000,  -- File is deleted
    SECTOR_CRC    = 0x04000000,  -- Sector CRCs present
    EXISTS        = 0x80000000,  -- File exists
}

-- Compression method flags (first byte of compressed data)
blocktable.COMPRESSION = {
    HUFFMAN      = 0x01,
    ZLIB         = 0x02,
    PKWARE       = 0x08,
    BZIP2        = 0x10,
    SPARSE       = 0x20,
    ADPCM_MONO   = 0x40,
    ADPCM_STEREO = 0x80,
}
-- }}}

-- {{{ parse_flags
-- Parses block flags bitmask into a table of booleans.
local function parse_flags(flags)
    local F = blocktable.FLAGS
    return {
        implode       = (flags & F.IMPLODE) ~= 0,
        compress      = (flags & F.COMPRESS) ~= 0,
        encrypted     = (flags & F.ENCRYPTED) ~= 0,
        fix_key       = (flags & F.FIX_KEY) ~= 0,
        patch_file    = (flags & F.PATCH_FILE) ~= 0,
        single_unit   = (flags & F.SINGLE_UNIT) ~= 0,
        delete_marker = (flags & F.DELETE_MARKER) ~= 0,
        sector_crc    = (flags & F.SECTOR_CRC) ~= 0,
        exists        = (flags & F.EXISTS) ~= 0,
        raw = flags,
    }
end
-- }}}

-- {{{ parse_entry
-- Parses a single block table entry (16 bytes).
local function parse_entry(data, offset, archive_offset)
    local entry = {}

    -- Raw values from table
    entry.file_offset = string.unpack("<I4", data, offset)
    entry.compressed_size = string.unpack("<I4", data, offset + 4)
    entry.uncompressed_size = string.unpack("<I4", data, offset + 8)
    entry.flags_raw = string.unpack("<I4", data, offset + 12)

    -- Parse flags
    entry.flags = parse_flags(entry.flags_raw)

    -- Calculate absolute offset in file
    entry.absolute_offset = archive_offset + entry.file_offset

    -- Determine compression status
    entry.is_compressed = entry.flags.implode or entry.flags.compress
    entry.needs_decompression = entry.is_compressed and
                                 entry.compressed_size ~= entry.uncompressed_size

    return entry
end
-- }}}

-- {{{ parse
-- Parses an MPQ block table from raw archive data.
-- file_data: the entire file contents
-- mpq_header: parsed MPQ header from header.lua
-- Returns: block_table object or nil, error
function blocktable.parse(file_data, mpq_header)
    local offset = mpq_header.block_table_abs
    local entry_count = mpq_header.block_table_entries
    local archive_offset = mpq_header.archive_offset

    -- Calculate block table size
    local table_size = entry_count * BLOCK_ENTRY_SIZE

    -- Check bounds
    if offset + table_size > #file_data then
        return nil, "Block table extends beyond file"
    end

    -- Extract encrypted block table data
    local encrypted = file_data:sub(offset + 1, offset + table_size)

    -- Decrypt the block table
    local decrypted = hash.decrypt_table(encrypted, "(block table)")

    -- Parse entries
    local entries = {}
    for i = 0, entry_count - 1 do
        local entry_offset = i * BLOCK_ENTRY_SIZE + 1
        entries[i] = parse_entry(decrypted, entry_offset, archive_offset)
    end

    return {
        entries = entries,
        entry_count = entry_count,
        _decrypted_data = decrypted,  -- Keep for debugging
    }
end
-- }}}

-- {{{ get_block
-- Gets block entry by index.
function blocktable.get_block(block_table, index)
    if index < 0 or index >= block_table.entry_count then
        return nil, "Block index out of range"
    end
    return block_table.entries[index]
end
-- }}}

-- {{{ get_compression_name
-- Returns human-readable compression method name.
function blocktable.get_compression_name(first_byte)
    local C = blocktable.COMPRESSION
    local methods = {}

    if (first_byte & C.HUFFMAN) ~= 0 then methods[#methods + 1] = "Huffman" end
    if (first_byte & C.ZLIB) ~= 0 then methods[#methods + 1] = "zlib" end
    if (first_byte & C.PKWARE) ~= 0 then methods[#methods + 1] = "PKWARE" end
    if (first_byte & C.BZIP2) ~= 0 then methods[#methods + 1] = "bzip2" end
    if (first_byte & C.SPARSE) ~= 0 then methods[#methods + 1] = "sparse" end
    if (first_byte & C.ADPCM_MONO) ~= 0 then methods[#methods + 1] = "ADPCM-mono" end
    if (first_byte & C.ADPCM_STEREO) ~= 0 then methods[#methods + 1] = "ADPCM-stereo" end

    if #methods == 0 then
        return "none"
    end
    return table.concat(methods, "+")
end
-- }}}

-- {{{ list_files
-- Returns list of all valid (existing) blocks.
function blocktable.list_files(block_table)
    local files = {}
    for i = 0, block_table.entry_count - 1 do
        local entry = block_table.entries[i]
        if entry.flags.exists and not entry.flags.delete_marker then
            files[#files + 1] = {
                index = i,
                offset = entry.file_offset,
                compressed_size = entry.compressed_size,
                uncompressed_size = entry.uncompressed_size,
                encrypted = entry.flags.encrypted,
                compressed = entry.is_compressed,
            }
        end
    end
    return files
end
-- }}}

-- {{{ format_entry
-- Returns a human-readable string for a single block entry.
function blocktable.format_entry(entry, index)
    local lines = {}
    lines[#lines + 1] = string.format("Block %d:", index)
    lines[#lines + 1] = string.format("  Offset: %d (0x%X)", entry.file_offset, entry.file_offset)
    lines[#lines + 1] = string.format("  Compressed: %d bytes", entry.compressed_size)
    lines[#lines + 1] = string.format("  Uncompressed: %d bytes", entry.uncompressed_size)
    lines[#lines + 1] = string.format("  Ratio: %.1f%%",
        entry.compressed_size * 100 / math.max(1, entry.uncompressed_size))

    local flag_names = {}
    if entry.flags.exists then flag_names[#flag_names + 1] = "EXISTS" end
    if entry.flags.compress then flag_names[#flag_names + 1] = "COMPRESS" end
    if entry.flags.implode then flag_names[#flag_names + 1] = "IMPLODE" end
    if entry.flags.encrypted then flag_names[#flag_names + 1] = "ENCRYPTED" end
    if entry.flags.fix_key then flag_names[#flag_names + 1] = "FIX_KEY" end
    if entry.flags.single_unit then flag_names[#flag_names + 1] = "SINGLE_UNIT" end
    if entry.flags.sector_crc then flag_names[#flag_names + 1] = "SECTOR_CRC" end
    lines[#lines + 1] = "  Flags: " .. table.concat(flag_names, " | ")

    return table.concat(lines, "\n")
end
-- }}}

-- {{{ format
-- Returns a human-readable string representation of the block table.
function blocktable.format(block_table)
    local lines = {}
    lines[#lines + 1] = "=== MPQ Block Table ==="
    lines[#lines + 1] = "Entry Count: " .. block_table.entry_count
    lines[#lines + 1] = ""

    -- Summary statistics
    local total_compressed = 0
    local total_uncompressed = 0
    local encrypted_count = 0
    local compressed_count = 0

    for i = 0, block_table.entry_count - 1 do
        local entry = block_table.entries[i]
        if entry.flags.exists then
            total_compressed = total_compressed + entry.compressed_size
            total_uncompressed = total_uncompressed + entry.uncompressed_size
            if entry.flags.encrypted then encrypted_count = encrypted_count + 1 end
            if entry.is_compressed then compressed_count = compressed_count + 1 end
        end
    end

    lines[#lines + 1] = string.format("Total Compressed: %d bytes", total_compressed)
    lines[#lines + 1] = string.format("Total Uncompressed: %d bytes", total_uncompressed)
    lines[#lines + 1] = string.format("Overall Ratio: %.1f%%",
        total_compressed * 100 / math.max(1, total_uncompressed))
    lines[#lines + 1] = string.format("Encrypted Files: %d", encrypted_count)
    lines[#lines + 1] = string.format("Compressed Files: %d", compressed_count)
    lines[#lines + 1] = ""

    -- Individual entries
    lines[#lines + 1] = "Entries:"
    for i = 0, block_table.entry_count - 1 do
        local entry = block_table.entries[i]
        if entry.flags.exists then
            lines[#lines + 1] = string.format(
                "  [%2d] offset=%6d comp=%6d uncomp=%6d %s%s",
                i, entry.file_offset, entry.compressed_size, entry.uncompressed_size,
                entry.flags.encrypted and "ENC " or "",
                entry.is_compressed and "CMP" or ""
            )
        end
    end

    return table.concat(lines, "\n")
end
-- }}}

return blocktable

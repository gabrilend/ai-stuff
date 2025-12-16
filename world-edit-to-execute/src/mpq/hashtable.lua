-- MPQ Hash Table Parser
-- Parses and provides lookup for MPQ hash tables.
-- The hash table maps filenames to block table indices.

local hash = require("mpq.hash")

local hashtable = {}

-- {{{ Constants
local HASH_ENTRY_SIZE = 16       -- Each entry is 16 bytes
local EMPTY_SLOT = 0xFFFFFFFF    -- Unused slot
local DELETED_SLOT = 0xFFFFFFFE  -- Deleted entry (continue search)
-- }}}

-- {{{ parse_entry
-- Parses a single hash table entry (16 bytes).
local function parse_entry(data, offset)
    local entry = {}
    entry.hash_a = string.unpack("<I4", data, offset)
    entry.hash_b = string.unpack("<I4", data, offset + 4)
    entry.locale = string.unpack("<I2", data, offset + 8)
    entry.platform = string.unpack("<I2", data, offset + 10)
    entry.block_index = string.unpack("<I4", data, offset + 12)
    return entry
end
-- }}}

-- {{{ parse
-- Parses an MPQ hash table from raw archive data.
-- file_data: the entire file contents
-- mpq_header: parsed MPQ header from header.lua
-- Returns: hash_table object or nil, error
function hashtable.parse(file_data, mpq_header)
    local offset = mpq_header.hash_table_abs
    local entry_count = mpq_header.hash_table_entries

    -- Calculate hash table size
    local table_size = entry_count * HASH_ENTRY_SIZE

    -- Check bounds
    if offset + table_size > #file_data then
        return nil, "Hash table extends beyond file"
    end

    -- Extract encrypted hash table data
    local encrypted = file_data:sub(offset + 1, offset + table_size)

    -- Decrypt the hash table
    local decrypted = hash.decrypt_table(encrypted, "(hash table)")

    -- Parse entries
    local entries = {}
    for i = 0, entry_count - 1 do
        local entry_offset = i * HASH_ENTRY_SIZE + 1
        entries[i] = parse_entry(decrypted, entry_offset)
    end

    return {
        entries = entries,
        entry_count = entry_count,
        _decrypted_data = decrypted,  -- Keep for debugging
    }
end
-- }}}

-- {{{ find_file
-- Looks up a filename in the hash table.
-- Returns block index if found, nil if not found.
function hashtable.find_file(hash_table, filename)
    local entry_count = hash_table.entry_count
    local entries = hash_table.entries

    -- Compute hashes for the filename
    local hash_offset = hash.mpq_hash(filename, hash.HASH_TABLE_OFFSET)
    local hash_a = hash.mpq_hash(filename, hash.HASH_NAME_A)
    local hash_b = hash.mpq_hash(filename, hash.HASH_NAME_B)

    -- Starting slot based on hash
    local start_slot = hash_offset % entry_count

    -- Linear probe through the table
    for i = 0, entry_count - 1 do
        local slot = (start_slot + i) % entry_count
        local entry = entries[slot]

        -- Empty slot means file not in archive
        if entry.block_index == EMPTY_SLOT then
            return nil
        end

        -- Skip deleted slots but continue searching
        if entry.block_index ~= DELETED_SLOT then
            -- Check if this entry matches our filename
            if entry.hash_a == hash_a and entry.hash_b == hash_b then
                return entry.block_index
            end
        end
    end

    -- Searched entire table without finding
    return nil
end
-- }}}

-- {{{ list_files
-- Returns a list of block indices for all valid entries.
-- Note: We cannot recover original filenames since MPQ only stores hashes.
function hashtable.list_files(hash_table)
    local files = {}
    for i = 0, hash_table.entry_count - 1 do
        local entry = hash_table.entries[i]
        if entry.block_index ~= EMPTY_SLOT and entry.block_index ~= DELETED_SLOT then
            files[#files + 1] = {
                slot = i,
                block_index = entry.block_index,
                locale = entry.locale,
                platform = entry.platform,
            }
        end
    end
    return files
end
-- }}}

-- {{{ has_file
-- Checks if a filename exists in the archive (wrapper around find_file).
function hashtable.has_file(hash_table, filename)
    return hashtable.find_file(hash_table, filename) ~= nil
end
-- }}}

-- {{{ get_entry
-- Gets the full hash table entry for a filename.
function hashtable.get_entry(hash_table, filename)
    local entry_count = hash_table.entry_count
    local entries = hash_table.entries

    local hash_offset = hash.mpq_hash(filename, hash.HASH_TABLE_OFFSET)
    local hash_a = hash.mpq_hash(filename, hash.HASH_NAME_A)
    local hash_b = hash.mpq_hash(filename, hash.HASH_NAME_B)

    local start_slot = hash_offset % entry_count

    for i = 0, entry_count - 1 do
        local slot = (start_slot + i) % entry_count
        local entry = entries[slot]

        if entry.block_index == EMPTY_SLOT then
            return nil
        end

        if entry.block_index ~= DELETED_SLOT then
            if entry.hash_a == hash_a and entry.hash_b == hash_b then
                return entry, slot
            end
        end
    end

    return nil
end
-- }}}

-- {{{ format
-- Returns a human-readable string representation of the hash table.
function hashtable.format(hash_table)
    local lines = {}
    lines[#lines + 1] = "=== MPQ Hash Table ==="
    lines[#lines + 1] = "Entry Count: " .. hash_table.entry_count

    local valid_count = 0
    for i = 0, hash_table.entry_count - 1 do
        local entry = hash_table.entries[i]
        if entry.block_index ~= EMPTY_SLOT and entry.block_index ~= DELETED_SLOT then
            valid_count = valid_count + 1
        end
    end
    lines[#lines + 1] = "Valid Entries: " .. valid_count

    lines[#lines + 1] = ""
    lines[#lines + 1] = "Entries (showing valid only):"

    for i = 0, hash_table.entry_count - 1 do
        local entry = hash_table.entries[i]
        if entry.block_index ~= EMPTY_SLOT and entry.block_index ~= DELETED_SLOT then
            lines[#lines + 1] = string.format(
                "  [%2d] block=%2d hash_a=0x%08X hash_b=0x%08X locale=%d",
                i, entry.block_index, entry.hash_a, entry.hash_b, entry.locale
            )
        end
    end

    return table.concat(lines, "\n")
end
-- }}}

return hashtable

-- MPQ Hash Table Parser
-- Parses and provides lookup for MPQ hash tables.
-- The hash table maps filenames to block table indices.
-- Compatible with both LuaJIT and Lua 5.3+.

local compat = require("compat")
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
    entry.hash_a = compat.unpack_uint32(data, offset)
    entry.hash_b = compat.unpack_uint32(data, offset + 4)
    entry.locale = compat.unpack_uint16(data, offset + 8)
    entry.platform = compat.unpack_uint16(data, offset + 10)
    entry.block_index = compat.unpack_uint32(data, offset + 12)
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

-- {{{ local function probe
-- Walks the hash table the way the game's own Storm.dll does, and returns the
-- first entry matching filename plus its slot, or nil.
--
-- Why it is written exactly so (found 2026-09-24 when StormLib and this reader
-- disagreed on a protected map, DAoW-5.2.w3x):
--   - The start slot is  hash & (size - 1),  and each step is
--     (slot + 1) & (size - 1).  Real tables are a power of two in size, where
--     this equals "% size". Map protectors write tables of other sizes (that
--     map's has 132 slots); there "& (size - 1)" and "% size" start in
--     different places, and a protector who plants two entries under the same
--     name gets a different file depending on which one is used. The game uses
--     the mask, so this does too.
--   - An entry whose block index points past the end of the block table is
--     skipped, not returned: another planted decoy. block_count (the block
--     table's entry count) enables that check; without it, only the empty and
--     deleted markers are recognised.
--   - An empty slot ends the search (the name isn't there); a deleted slot
--     doesn't.
--   - The walk stops when it comes back to its start slot, which with a
--     non-power-of-two size can happen before every slot has been seen.
--   - **Duplicates: the last one wins.** A protected map can hold several
--     entries under one name, all marked language-neutral (locale 0). Storm
--     walks every matching entry and keeps the *last* one that is neutral or in
--     the wanted language (StormLib's GetHashEntryLocale, reverse engineered
--     from Storm_2016.dll, does the same). In DAoW-5.2.w3x, war3map.w3d sits at
--     slots 12 (a 59,659-byte decoy) and 18 (the 61,537-byte file the game
--     reads); returning the first match read the decoy.
--   - locale (optional): a non-zero wanted language. An entry in exactly that
--     language is returned at once; otherwise the last neutral-or-matching entry.
local function probe(hash_table, filename, block_count, locale)
    local entries = hash_table.entries
    local mask = hash_table.entry_count - 1
    local wanted = locale or 0

    local hash_a = hash.mpq_hash(filename, hash.HASH_NAME_A)
    local hash_b = hash.mpq_hash(filename, hash.HASH_NAME_B)
    local start_slot = compat.band(hash.mpq_hash(filename, hash.HASH_TABLE_OFFSET), mask)

    local best_entry, best_slot = nil, nil
    local slot = start_slot
    repeat
        local entry = entries[slot]
        if entry.block_index == EMPTY_SLOT then
            break
        end
        local in_range = (block_count == nil) or (entry.block_index < block_count)
        if entry.block_index ~= DELETED_SLOT and in_range
            and entry.hash_a == hash_a and entry.hash_b == hash_b then
            if wanted ~= 0 and entry.locale == wanted then
                return entry, slot
            end
            if entry.locale == 0 or entry.locale == wanted then
                best_entry, best_slot = entry, slot
            end
        end
        slot = compat.band(slot + 1, mask)
    until slot == start_slot

    return best_entry, best_slot
end
-- }}}

-- {{{ find_file
-- Looks up a filename in the hash table.
-- block_count: the block table's entry count (optional, but callers that have
-- the block table should pass it, so planted out-of-range entries are skipped).
-- Returns the block index if found, nil if not.
function hashtable.find_file(hash_table, filename, block_count)
    local entry = probe(hash_table, filename, block_count)
    return entry and entry.block_index or nil
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
function hashtable.get_entry(hash_table, filename, block_count)
    return probe(hash_table, filename, block_count)
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

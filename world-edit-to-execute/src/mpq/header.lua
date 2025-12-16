-- MPQ Header Parser
-- Parses MPQ archive headers from Warcraft 3 map files (.w3x/.w3m).
-- WC3 maps have a 512-byte HM3W wrapper header before the MPQ archive.

local header = {}

-- {{{ Constants
local MPQ_MAGIC = "MPQ\x1A"
local MPQ_SHUNT = "MPQ\x1B"
local HM3W_MAGIC = "HM3W"
local HM3W_HEADER_SIZE = 512
-- }}}

-- {{{ read_uint32
local function read_uint32(data, pos)
    return string.unpack("<I4", data, pos)
end
-- }}}

-- {{{ read_uint16
local function read_uint16(data, pos)
    return string.unpack("<I2", data, pos)
end
-- }}}

-- {{{ read_int16
local function read_int16(data, pos)
    return string.unpack("<i2", data, pos)
end
-- }}}

-- {{{ read_cstring
local function read_cstring(data, pos, max_len)
    max_len = max_len or 256
    local end_pos = data:find("\0", pos, true)
    if end_pos and end_pos <= pos + max_len then
        return data:sub(pos, end_pos - 1), end_pos + 1
    end
    return data:sub(pos, pos + max_len - 1), pos + max_len
end
-- }}}

-- {{{ parse_hm3w_header
-- Parses the HM3W wrapper header found at the start of WC3 map files.
-- Returns nil if not an HM3W file.
function header.parse_hm3w(data)
    if #data < HM3W_HEADER_SIZE then
        return nil, "File too small for HM3W header"
    end

    local magic = data:sub(1, 4)
    if magic ~= HM3W_MAGIC then
        return nil, "Not an HM3W file (magic: " .. magic:gsub("[^%w]", "?") .. ")"
    end

    local hm3w = {}
    hm3w.magic = magic
    hm3w.unknown = read_uint32(data, 5)

    -- Map name is null-terminated string starting at offset 8
    hm3w.map_name, _ = read_cstring(data, 9, 256)

    -- After the map name, there are flags and max players
    -- The exact offset depends on map name length, but typically around 0x22-0x26
    -- For simplicity, we scan for the flags after the null terminator
    local name_end = data:find("\0", 9, true)
    if name_end then
        local flags_pos = name_end + 1
        if flags_pos + 7 <= HM3W_HEADER_SIZE then
            hm3w.map_flags = read_uint32(data, flags_pos)
            hm3w.max_players = read_uint32(data, flags_pos + 4)
        end
    end

    hm3w.mpq_offset = HM3W_HEADER_SIZE

    return hm3w
end
-- }}}

-- {{{ parse_mpq_header
-- Parses an MPQ archive header from the given data at the specified offset.
-- Returns the header table and the archive base offset on success.
function header.parse_mpq(data, offset)
    offset = offset or 1

    -- Check minimum size
    if #data < offset + 31 then
        return nil, "Data too small for MPQ header"
    end

    local magic = data:sub(offset, offset + 3)

    -- Handle MPQ shunt (user data header)
    if magic == MPQ_SHUNT then
        local user_data_size = read_uint32(data, offset + 4)
        local header_offset = read_uint32(data, offset + 8)
        -- Recurse with the actual header offset
        return header.parse_mpq(data, offset + header_offset)
    end

    if magic ~= MPQ_MAGIC then
        return nil, "Invalid MPQ magic (expected 'MPQ\\x1A', got '" ..
                    magic:gsub("[^%w]", "?") .. "')"
    end

    local mpq = {}
    mpq.magic = magic
    mpq.archive_offset = offset

    -- Parse header fields (all little-endian)
    -- Note: HeaderSize field appears to have unexpected values in WC3 maps
    -- We read it but don't rely on it
    mpq.header_size_raw = read_uint32(data, offset + 4)
    mpq.archive_size = read_uint32(data, offset + 8)
    mpq.format_version = read_uint16(data, offset + 12)
    mpq.sector_size_shift = read_uint16(data, offset + 14)
    mpq.hash_table_offset = read_uint32(data, offset + 16)
    mpq.block_table_offset = read_uint32(data, offset + 20)
    mpq.hash_table_entries = read_uint32(data, offset + 24)
    mpq.block_table_entries = read_uint32(data, offset + 28)

    -- Calculate derived values
    mpq.sector_size = 512 * (2 ^ mpq.sector_size_shift)

    -- Calculate absolute offsets (relative to file start)
    mpq.hash_table_abs = offset + mpq.hash_table_offset - 1
    mpq.block_table_abs = offset + mpq.block_table_offset - 1

    return mpq
end
-- }}}

-- {{{ open_w3x
-- Opens a WC3 map file and parses both HM3W and MPQ headers.
-- Handles the common case where HM3W wraps the MPQ archive.
function header.open_w3x(filepath)
    local file, err = io.open(filepath, "rb")
    if not file then
        return nil, "Cannot open file: " .. tostring(err)
    end

    local data = file:read("*a")
    file:close()

    if not data or #data == 0 then
        return nil, "Empty file"
    end

    local result = {
        filepath = filepath,
        file_size = #data,
    }

    -- Try parsing as HM3W wrapped file
    local hm3w, hm3w_err = header.parse_hm3w(data)
    if hm3w then
        result.hm3w = hm3w
        result.mpq_offset = hm3w.mpq_offset

        -- Parse MPQ header at the offset indicated by HM3W
        local mpq, mpq_err = header.parse_mpq(data, hm3w.mpq_offset + 1)
        if not mpq then
            return nil, "HM3W found but MPQ header invalid: " .. tostring(mpq_err)
        end
        result.mpq = mpq
    else
        -- Try parsing as raw MPQ at offset 0
        local mpq, mpq_err = header.parse_mpq(data, 1)
        if mpq then
            result.mpq_offset = 0
            result.mpq = mpq
        else
            -- Try scanning for MPQ magic at common offsets
            for _, scan_offset in ipairs({0, 512, 1024}) do
                local pos = scan_offset + 1
                if data:sub(pos, pos + 3) == MPQ_MAGIC or
                   data:sub(pos, pos + 3) == MPQ_SHUNT then
                    mpq, mpq_err = header.parse_mpq(data, pos)
                    if mpq then
                        result.mpq_offset = scan_offset
                        result.mpq = mpq
                        break
                    end
                end
            end

            if not result.mpq then
                return nil, "No valid MPQ header found"
            end
        end
    end

    return result
end
-- }}}

-- {{{ validate_header
-- Validates that the parsed header contains sensible values.
function header.validate(mpq)
    local errors = {}

    if mpq.archive_size <= 0 then
        errors[#errors + 1] = "Invalid archive size: " .. mpq.archive_size
    end

    if mpq.hash_table_entries == 0 then
        errors[#errors + 1] = "Hash table has 0 entries"
    end

    if mpq.block_table_entries == 0 then
        errors[#errors + 1] = "Block table has 0 entries"
    end

    -- Hash table entries should be power of 2
    local hash_count = mpq.hash_table_entries
    if hash_count > 0 and (hash_count & (hash_count - 1)) ~= 0 then
        errors[#errors + 1] = "Hash table entries not power of 2: " .. hash_count
    end

    if mpq.hash_table_offset >= mpq.archive_size then
        errors[#errors + 1] = "Hash table offset beyond archive"
    end

    if mpq.block_table_offset >= mpq.archive_size then
        errors[#errors + 1] = "Block table offset beyond archive"
    end

    if #errors > 0 then
        return false, errors
    end

    return true
end
-- }}}

-- {{{ format_header
-- Returns a human-readable string representation of the header.
function header.format(result)
    local lines = {}

    lines[#lines + 1] = "File: " .. result.filepath
    lines[#lines + 1] = "Size: " .. result.file_size .. " bytes"
    lines[#lines + 1] = ""

    if result.hm3w then
        lines[#lines + 1] = "=== HM3W Header ==="
        lines[#lines + 1] = "Map Name: " .. (result.hm3w.map_name or "(unknown)")
        lines[#lines + 1] = "Map Flags: 0x" .. string.format("%08X", result.hm3w.map_flags or 0)
        lines[#lines + 1] = "Max Players: " .. (result.hm3w.max_players or "(unknown)")
        lines[#lines + 1] = ""
    end

    local mpq = result.mpq
    lines[#lines + 1] = "=== MPQ Header ==="
    lines[#lines + 1] = "Archive Offset: " .. result.mpq_offset .. " (0x" ..
                        string.format("%X", result.mpq_offset) .. ")"
    lines[#lines + 1] = "Archive Size: " .. mpq.archive_size .. " bytes"
    lines[#lines + 1] = "Format Version: " .. mpq.format_version
    lines[#lines + 1] = "Sector Size: " .. mpq.sector_size .. " bytes (shift=" ..
                        mpq.sector_size_shift .. ")"
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Hash Table:"
    lines[#lines + 1] = "  Offset: " .. mpq.hash_table_offset .. " (abs: " ..
                        mpq.hash_table_abs .. ")"
    lines[#lines + 1] = "  Entries: " .. mpq.hash_table_entries
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Block Table:"
    lines[#lines + 1] = "  Offset: " .. mpq.block_table_offset .. " (abs: " ..
                        mpq.block_table_abs .. ")"
    lines[#lines + 1] = "  Entries: " .. mpq.block_table_entries

    return table.concat(lines, "\n")
end
-- }}}

return header

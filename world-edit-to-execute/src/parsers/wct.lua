-- war3map.wct Parser
-- Parses WC3 custom text trigger files containing raw JASS code.
-- The WCT format stores per-trigger custom JASS and a map header comment.
-- Custom text triggers are created when users "Convert to Custom Text" in
-- the World Editor, losing GUI representation in favor of editable JASS.

local compat = require("compat")

local wct = {}

-- {{{ Constants
-- WCT format versions
-- Version 0: Reign of Chaos
-- Version 1: The Frozen Throne (most common)
local SUPPORTED_VERSIONS = { [0] = true, [1] = true }
-- }}}

-- {{{ Binary reading utilities
local function read_int32(data, pos)
    return compat.unpack_int32(data, pos)
end

local function read_uint32(data, pos)
    return compat.unpack_uint32(data, pos)
end

-- {{{ read_sized_string
-- Reads a string with a preceding int32 length field.
-- If length is 0, returns empty string.
-- The string data does NOT include a null terminator (it's length-prefixed).
-- Returns: string, new_position, error_message
local function read_sized_string(data, pos)
    local length, new_pos = read_int32(data, pos)
    if not length then
        return nil, pos, "Failed to read string length at offset " .. pos
    end

    if length < 0 then
        return nil, pos, "Invalid negative string length " .. length .. " at offset " .. pos
    end

    if length == 0 then
        return "", new_pos, nil
    end

    -- Check bounds
    if new_pos + length - 1 > #data then
        return nil, pos, "String length " .. length .. " exceeds data size at offset " .. pos
    end

    local str = data:sub(new_pos, new_pos + length - 1)
    return str, new_pos + length, nil
end
-- }}}
-- }}}

-- {{{ parse_header
-- Parses the WCT file header and extracts version and header comment.
-- Returns: { version, header_comment, _offset }, error_message
local function parse_header(data, offset)
    offset = offset or 1

    -- Check minimum size for version field
    if #data < offset + 3 then
        return nil, "Invalid WCT file: too short (need at least 4 bytes for version)"
    end

    -- Extract version (int32 little-endian)
    local version, new_offset = read_uint32(data, offset)
    offset = new_offset

    -- Validate supported version
    if not SUPPORTED_VERSIONS[version] then
        return nil, "Unsupported WCT version: " .. version .. " (expected 0 or 1)"
    end

    -- Version 1 (TFT) has a header comment, version 0 (RoC) does not
    local header_comment = ""
    if version >= 1 then
        -- Read header comment (length-prefixed string)
        local str, next_pos, err = read_sized_string(data, offset)
        if err then
            return nil, "Failed to read header comment: " .. err
        end
        header_comment = str
        offset = next_pos
    end

    return {
        version = version,
        header_comment = header_comment,
        _offset = offset,
    }, nil
end
-- }}}

-- {{{ parse_triggers
-- Parses the trigger custom text entries.
-- Returns: { triggers = { [index] = string or nil }, count = N }, error_message
local function parse_triggers(data, offset)
    -- Check bounds before reading trigger count
    if offset + 3 > #data then
        return nil, "Truncated WCT file: missing trigger count at offset " .. offset
    end

    -- Read trigger count
    local count, new_offset = read_uint32(data, offset)
    if not count then
        return nil, "Failed to read trigger count at offset " .. offset
    end
    offset = new_offset

    local triggers = {}

    -- Parse each trigger entry
    for i = 1, count do
        local text, next_pos, err = read_sized_string(data, offset)
        if err then
            return nil, "Failed to read trigger " .. i .. " text: " .. err
        end

        -- Store nil for empty entries (non-custom triggers), actual text for custom
        if text and #text > 0 then
            triggers[i] = text
        else
            triggers[i] = nil
        end

        offset = next_pos
    end

    return {
        triggers = triggers,
        count = count,
        _offset = offset,
    }, nil
end
-- }}}

-- {{{ parse
-- Parses war3map.wct data and returns structured content.
-- @param data: Raw binary data from war3map.wct file
-- @return table: Parsed WCT structure
-- @return string|nil: Error message if parsing failed
function wct.parse(data)
    if not data or #data == 0 then
        return nil, "Empty WCT data"
    end

    -- Parse header (version + optional header comment)
    local header, err = parse_header(data, 1)
    if not header then
        return nil, err
    end

    -- Parse trigger entries
    local trigger_data, err2 = parse_triggers(data, header._offset)
    if not trigger_data then
        return nil, err2
    end

    return {
        version = header.version,
        header_comment = header.header_comment,
        triggers = trigger_data.triggers,
        trigger_count = trigger_data.count,
    }, nil
end
-- }}}

-- {{{ extract
-- Extracts war3map.wct content from an MPQ archive.
-- Returns the parsed WCT structure, or nil and error message.
-- @param archive: An opened MPQ archive object
-- @return table|nil: Parsed WCT structure or nil on failure
-- @return string|nil: Error message if extraction failed
function wct.extract(archive)
    if not archive then
        return nil, "No archive provided"
    end

    if not archive:has("war3map.wct") then
        return nil, "war3map.wct not found in archive"
    end

    local data = archive:extract("war3map.wct")
    if not data then
        return nil, "Failed to extract war3map.wct"
    end

    return wct.parse(data)
end
-- }}}

-- {{{ merge_with_wtg
-- Merges WCT custom text into WTG trigger data.
-- This associates the JASS source code with the appropriate triggers.
-- @param wct_data: Result from wct.parse()
-- @param wtg_data: Result from wtg.parse()
-- @return boolean: true if merge succeeded
-- @return string|nil: Error message if merge failed
function wct.merge_with_wtg(wct_data, wtg_data)
    if not wct_data then
        return false, "No WCT data provided"
    end

    if not wtg_data then
        return false, "No WTG data provided"
    end

    if not wtg_data.triggers then
        return false, "WTG data has no triggers array"
    end

    -- Warn if counts don't match but continue anyway
    -- (some maps may have mismatched counts due to corruption or protection)
    local wtg_count = #wtg_data.triggers
    local wct_count = wct_data.trigger_count or 0

    if wtg_count ~= wct_count then
        -- Non-fatal: just merge what we can
        io.stderr:write(string.format(
            "Warning: WTG has %d triggers, WCT has %d entries\n",
            wtg_count, wct_count))
    end

    -- Merge custom text into triggers
    for i, trigger in ipairs(wtg_data.triggers) do
        local custom_text = wct_data.triggers[i]
        if custom_text then
            trigger.custom_jass = custom_text
        end
    end

    -- Add header comment to wtg data
    if wct_data.header_comment and #wct_data.header_comment > 0 then
        wtg_data.header_comment = wct_data.header_comment
    end

    return true, nil
end
-- }}}

-- {{{ get_custom_trigger_count
-- Returns the number of triggers that have custom text.
-- @param wct_data: Result from wct.parse()
-- @return number: Count of triggers with custom JASS
function wct.get_custom_trigger_count(wct_data)
    if not wct_data or not wct_data.triggers then
        return 0
    end

    local count = 0
    for i = 1, wct_data.trigger_count do
        if wct_data.triggers[i] then
            count = count + 1
        end
    end
    return count
end
-- }}}

-- {{{ format
-- Returns a human-readable summary of parsed WCT data.
-- @param wct_data: Result from wct.parse()
-- @return string: Formatted summary
function wct.format(wct_data)
    local lines = {}

    lines[#lines + 1] = "=== WCT (Custom Text Triggers) Summary ==="
    lines[#lines + 1] = string.format("Version: %d", wct_data.version or 0)
    lines[#lines + 1] = ""

    -- Header comment
    if wct_data.header_comment and #wct_data.header_comment > 0 then
        lines[#lines + 1] = "Header Comment:"
        -- Show first few lines
        local preview_lines = 0
        for line in wct_data.header_comment:gmatch("[^\n]+") do
            preview_lines = preview_lines + 1
            if preview_lines <= 5 then
                lines[#lines + 1] = "  " .. line
            end
        end
        if preview_lines > 5 then
            lines[#lines + 1] = string.format("  ... (%d more lines)", preview_lines - 5)
        end
        lines[#lines + 1] = ""
    else
        lines[#lines + 1] = "Header Comment: (none)"
        lines[#lines + 1] = ""
    end

    -- Trigger summary
    local custom_count = wct.get_custom_trigger_count(wct_data)
    lines[#lines + 1] = string.format("Triggers: %d total, %d with custom text",
        wct_data.trigger_count or 0, custom_count)

    -- List custom triggers with preview
    if custom_count > 0 then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Custom Triggers:"
        local shown = 0
        for i = 1, wct_data.trigger_count do
            local text = wct_data.triggers[i]
            if text then
                shown = shown + 1
                if shown <= 10 then
                    -- Show first line of JASS
                    local first_line = text:match("^([^\n]*)")
                    if #first_line > 60 then
                        first_line = first_line:sub(1, 57) .. "..."
                    end
                    lines[#lines + 1] = string.format("  [%d] %s", i, first_line)
                end
            end
        end
        if shown > 10 then
            lines[#lines + 1] = string.format("  ... (%d more)", shown - 10)
        end
    end

    return table.concat(lines, "\n")
end
-- }}}

return wct

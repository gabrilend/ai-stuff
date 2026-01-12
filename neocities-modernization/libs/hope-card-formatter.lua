-- hope-card-formatter.lua
-- Formats poems for words-pdf input (80-dash separated text format)
--
-- This module converts neocities poem data into the format expected by
-- the words-pdf project: plain text poems separated by 80 dashes.
--
-- INPUT:  Table of poem objects from poems.json
-- OUTPUT: String formatted for words-pdf (or written to file)

local M = {}

-- {{{ M.DASH_SEPARATOR
M.DASH_SEPARATOR = string.rep("-", 80)
-- }}}

-- {{{ M.format_poem_for_wordspdf
-- Formats a single poem for words-pdf output
-- @param poem: Poem object from poems.json
-- @return string: Formatted poem text
function M.format_poem_for_wordspdf(poem)
    if not poem then return "" end

    local lines = {}

    -- Add poem content lines
    if poem.content then
        -- Content is a single string, split by newlines
        for line in poem.content:gmatch("[^\n]+") do
            -- Ensure line doesn't exceed 80 characters
            if #line > 80 then
                -- Word wrap long lines
                local wrapped = M.wrap_line(line, 80)
                for _, wrapped_line in ipairs(wrapped) do
                    table.insert(lines, wrapped_line)
                end
            else
                table.insert(lines, line)
            end
        end
    elseif poem.lines then
        -- Content is already split into lines
        for _, line in ipairs(poem.lines) do
            if #line > 80 then
                local wrapped = M.wrap_line(line, 80)
                for _, wrapped_line in ipairs(wrapped) do
                    table.insert(lines, wrapped_line)
                end
            else
                table.insert(lines, line)
            end
        end
    end

    return table.concat(lines, "\n")
end
-- }}}

-- {{{ M.wrap_line
-- Wraps a line that exceeds max_width by breaking at word boundaries
-- @param line: String to wrap
-- @param max_width: Maximum characters per line (default 80)
-- @return table: Array of wrapped lines
function M.wrap_line(line, max_width)
    max_width = max_width or 80

    if #line <= max_width then
        return {line}
    end

    local wrapped = {}
    local current = ""

    -- Split on whitespace and rebuild within width
    for word in line:gmatch("%S+") do
        if current == "" then
            -- First word on line
            if #word > max_width then
                -- Single word exceeds width - hard break it
                table.insert(wrapped, word:sub(1, max_width))
                current = word:sub(max_width + 1)
            else
                current = word
            end
        elseif #current + 1 + #word <= max_width then
            -- Word fits on current line
            current = current .. " " .. word
        else
            -- Start new line
            table.insert(wrapped, current)
            current = word
        end
    end

    -- Add remaining text
    if current ~= "" then
        table.insert(wrapped, current)
    end

    return wrapped
end
-- }}}

-- {{{ M.format_poems_to_string
-- Formats multiple poems into a single words-pdf compatible string
-- @param poems: Array of poem objects
-- @return string: Complete formatted text with 80-dash separators
function M.format_poems_to_string(poems)
    if not poems or #poems == 0 then
        return ""
    end

    local output_parts = {}

    for i, poem in ipairs(poems) do
        local formatted = M.format_poem_for_wordspdf(poem)
        table.insert(output_parts, formatted)

        -- Add separator after each poem (including the last one)
        table.insert(output_parts, M.DASH_SEPARATOR)
    end

    return table.concat(output_parts, "\n")
end
-- }}}

-- {{{ M.write_to_file
-- Writes formatted poems to a file for words-pdf consumption
-- @param poems: Array of poem objects
-- @param output_path: File path to write to
-- @return boolean: Success status
-- @return string: Error message if failed
function M.write_to_file(poems, output_path)
    local formatted_text = M.format_poems_to_string(poems)

    local file, err = io.open(output_path, "w")
    if not file then
        return false, "Cannot open file for writing: " .. (err or "unknown error")
    end

    file:write(formatted_text)
    file:close()

    return true, nil
end
-- }}}

-- {{{ M.generate_hope_card_filename
-- Generates a descriptive filename for a hope card
-- @param anchor_id: The anchor poem ID
-- @param poem_count: Number of poems in the card
-- @return string: Filename (without path)
function M.generate_hope_card_filename(anchor_id, poem_count)
    return string.format("hope-card-%04d-%dpoems.txt", anchor_id, poem_count)
end
-- }}}

return M

-- {{{ text-formatter.lua
-- Issue 8-056: Shared text formatting module for poem content rendering.
-- Used by both main thread (chronological pages) and effil worker threads
-- (similar/different pages) to ensure identical whitespace handling.
--
-- Design principle: Poetry is artistic content. The author's spacing decisions
-- (leading whitespace, multi-space runs, paragraph breaks, indentation) must be
-- respected regardless of source category. This module does NO word-wrapping.
-- }}}

local M = {}

-- {{{ function M.format_poem_lines
-- Splits poem text into lines, preserving all whitespace.
-- Returns a table of lines with no modifications to spacing.
--
-- Input/Output examples:
--   "   hello world"  ->  {"   hello world"}   (leading spaces preserved)
--   "hello    world"  ->  {"hello    world"}   (multi-space run preserved)
--   "a\nb\n\nc"       ->  {"a", "b", "", "c"}  (paragraph breaks preserved)
--   "short line"      ->  {"short line"}       (no modification)
--   90-char line      ->  {90-char line}       (no re-flow)
--
-- Why no word-wrapping: The `%S+` pattern used in word-wrapping destroys
-- all whitespace structure. Poetry in poems.json already contains the
-- author's intended line breaks. The rendering layer should faithfully
-- reproduce them, not re-flow the text.
function M.format_poem_lines(text)
    if not text or text == "" then
        return {}
    end

    local lines = {}
    -- Match lines including empty ones (paragraph breaks)
    -- The pattern (.-)\n matches everything up to each newline
    -- Adding \n to the end ensures we capture the last line even without trailing newline
    for line in (text .. "\n"):gmatch("(.-)\n") do
        table.insert(lines, line)
    end

    -- Remove the extra empty line added by the trailing \n if the text
    -- didn't originally end with a newline
    if #lines > 0 and lines[#lines] == "" and not text:match("\n$") then
        table.remove(lines)
    end

    return lines
end
-- }}}

-- {{{ function M.format_poem_content
-- Convenience function: formats poem content and returns as single string.
-- Each line gets a 1-space left padding (standard for poem content area).
-- Preserves all whitespace within lines.
--
-- This is the main entry point for both main thread and worker thread
-- poem content formatting.
function M.format_poem_content(text)
    local lines = M.format_poem_lines(text)
    local padded_lines = {}

    for _, line in ipairs(lines) do
        -- 1-space left padding for content alignment within poem box
        table.insert(padded_lines, " " .. line)
    end

    return padded_lines
end
-- }}}

-- {{{ function M.decode_html_entities_for_width
-- Decodes HTML entities to their display characters for accurate width counting.
-- Used when calculating padding - the visible width differs from byte count
-- when content contains escaped entities like &gt; (4 bytes, 1 display char).
--
-- NOTE: This only decodes for WIDTH CALCULATION. The actual rendered content
-- must keep the entities for correct HTML display.
function M.decode_html_entities_for_width(content)
    local decoded = content
    -- Strip HTML tags first (they're invisible in display)
    decoded = decoded:gsub("<[^>]+>", "")
    -- Decode common HTML entities to their display characters
    decoded = decoded:gsub("&gt;", ">")
    decoded = decoded:gsub("&lt;", "<")
    decoded = decoded:gsub("&amp;", "&")
    decoded = decoded:gsub("&quot;", '"')
    decoded = decoded:gsub("&#39;", "'")
    decoded = decoded:gsub("&nbsp;", " ")
    -- Numeric entities
    decoded = decoded:gsub("&#(%d+);", function(n)
        local num = tonumber(n)
        if num and num < 256 then
            return string.char(num)
        end
        return ""
    end)
    return decoded
end
-- }}}

-- {{{ function M.utf8_char_count
-- Counts UTF-8 characters (not bytes) in a string.
-- Box-drawing chars are 3 bytes each, ASCII is 1 byte.
-- This is important for correct padding calculations.
function M.utf8_char_count(str)
    if not str then return 0 end
    -- Remove UTF-8 continuation bytes (0x80-0xBF), count what remains
    local stripped = str:gsub("[\128-\191]", "")
    return #stripped
end
-- }}}

-- {{{ function M.calculate_visible_width
-- Calculates the visible display width of a string containing HTML entities.
-- Combines entity decoding and UTF-8 character counting.
-- Used for padding calculations in golden poem formatting.
function M.calculate_visible_width(content)
    local decoded = M.decode_html_entities_for_width(content)
    return M.utf8_char_count(decoded)
end
-- }}}

return M
-- }}}

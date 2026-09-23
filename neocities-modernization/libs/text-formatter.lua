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
-- Convenience function: formats poem content with word wrapping and left padding.
-- Each line gets a 1-space left padding (standard for poem content area).
-- Long lines are wrapped at word boundaries while preserving leading whitespace.
--
-- Issue 10-021: Re-enabled word wrapping (was disabled by 8-056) but now uses
-- wrap_preserving_indent() which maintains artistic whitespace.
--
-- This is the main entry point for both main thread and worker thread
-- poem content formatting.
function M.format_poem_content(text, max_width)
    max_width = max_width or 80
    local lines = M.format_poem_lines(text)
    local result_lines = {}

    for _, line in ipairs(lines) do
        -- Add 1-space left padding, then wrap if needed
        local padded_line = " " .. line
        local wrapped = M.wrap_preserving_indent(padded_line, max_width)
        for _, wrapped_line in ipairs(wrapped) do
            table.insert(result_lines, wrapped_line)
        end
    end

    return result_lines
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

-- {{{ function M.slice_by_visible_width
-- Cuts `str` after `width` VISIBLE columns and returns the two pieces as
-- (chunk, rest). Walks the string one display unit at a time so a cut can never
-- land in the middle of something the reader sees as indivisible:
--
--   <em> ... >     an HTML tag -- swallowed whole, costs zero columns
--   &amp; &#39;    an entity   -- swallowed whole, costs one column
--   0xC0-0xF4 ...  a UTF-8 sequence -- swallowed whole, costs one column
--   anything else  one byte, one column
--
-- Only the long-word path (URLs, mostly) needs this. Slicing at a byte offset
-- instead is what would cut "<em>" into "<e" + "m>" and leak raw angle brackets
-- onto the page the moment an emphasized word grew long enough to break.
function M.slice_by_visible_width(str, width)
    local byte_pos = 1
    local columns = 0
    local length = #str

    while byte_pos <= length and columns < width do
        local char = str:sub(byte_pos, byte_pos)

        if char == "<" then
            -- A complete tag costs nothing; a lone "<" that never closes is a
            -- real character the author typed, so it costs a column.
            local tag_end = str:find(">", byte_pos, true)
            if tag_end then
                byte_pos = tag_end + 1
            else
                byte_pos = byte_pos + 1
                columns = columns + 1
            end
        elseif char == "&" then
            -- "&amp;" is five bytes wearing the face of one ampersand. Anything
            -- that does not look like an entity is just an ampersand.
            local entity = str:match("^&#?%w+;", byte_pos)
            if entity then
                byte_pos = byte_pos + #entity
            else
                byte_pos = byte_pos + 1
            end
            columns = columns + 1
        else
            local byte = str:byte(byte_pos)
            local sequence_length = 1
            if byte >= 0xF0 then
                sequence_length = 4
            elseif byte >= 0xE0 then
                sequence_length = 3
            elseif byte >= 0xC0 then
                sequence_length = 2
            end
            byte_pos = byte_pos + sequence_length
            columns = columns + 1
        end
    end

    return str:sub(1, byte_pos - 1), str:sub(byte_pos)
end
-- }}}

-- {{{ function M.wrap_preserving_indent
-- Issue 10-021: Wraps a single line to max_width while preserving leading whitespace.
-- Continuation lines inherit the same indentation as the original line.
--
-- Key behaviors:
--   - Lines <= max_width of VISIBLE text: returned unchanged (single-element table)
--   - Leading whitespace: captured and prepended to all wrapped lines
--   - Long words (URLs): broken at character boundaries if they exceed available width
--   - Multi-space runs: preserved within content (splits on space boundaries)
--
-- Every measurement here asks how WIDE a piece of text looks, never how many
-- bytes it weighs. Poem lines arrive already HTML-escaped and markdown-formatted,
-- so an emphasized word carries an <em></em> pair -- nine bytes that occupy no
-- columns at all -- and an escaped ampersand carries "&amp;" for one column of
-- "&". Measuring bytes made the budget shrink by however much invisible markup a
-- line happened to contain, so emphasized lines wrapped early: a 78-column line
-- holding one *word* measured 87 and shed its last two words for no visible
-- reason, while the plain 79-column line below it stayed put.
--
-- Returns a table of wrapped lines.
function M.wrap_preserving_indent(line, max_width)
    max_width = max_width or 80

    -- Short lines pass through unchanged
    if M.calculate_visible_width(line) <= max_width then
        return {line}
    end

    -- Capture leading whitespace separately
    local leading, remainder = line:match("^(%s*)(.*)$")
    leading = leading or ""
    remainder = remainder or line
    local indent_width = M.utf8_char_count(leading)
    local content_width = max_width - indent_width

    -- Edge case: if indent is so large we can't fit meaningful content
    if content_width < 10 then
        return {line}
    end

    local result_lines = {}
    local current = ""
    local current_width = 0

    -- Split remainder into words, preserving the spaces after each word
    -- Pattern: capture non-spaces followed by any trailing spaces.
    --
    -- Measuring each word on its own is safe because the tags markdown emits
    -- never contain a space: emphasis spanning two words arrives as "<em>two"
    -- and "words</em>", and each half strips its own tag cleanly. A tag that DID
    -- carry a space -- an <a href="..."> anchor -- would be torn apart by this
    -- split, which is why the callers route link text through wrap_external_url
    -- instead of here.
    for word, trailing_space in remainder:gmatch("(%S+)(%s*)") do
        local segment = word .. trailing_space
        local segment_width = M.calculate_visible_width(segment)

        if current_width + segment_width <= content_width then
            -- Fits on current line
            current = current .. segment
            current_width = current_width + segment_width
        else
            -- Doesn't fit - flush current line first
            if #current > 0 then
                -- Trim trailing spaces from the line being flushed
                table.insert(result_lines, leading .. current:gsub("%s+$", ""))
            end

            -- Handle very long words (URLs) that exceed content_width
            local word_width = M.calculate_visible_width(word)
            if word_width > content_width then
                -- Break the long word at character boundaries
                local remaining_word = word
                local remaining_width = word_width
                while remaining_width > content_width do
                    local chunk, rest = M.slice_by_visible_width(remaining_word, content_width)
                    table.insert(result_lines, leading .. chunk)
                    remaining_word = rest
                    remaining_width = M.calculate_visible_width(remaining_word)
                end
                -- Whatever is left becomes start of new current line
                current = remaining_word .. trailing_space
                current_width = remaining_width + M.calculate_visible_width(trailing_space)
            else
                -- Normal word, just starts a new line
                current = segment
                current_width = segment_width
            end
        end
    end

    -- Flush final line
    if #current > 0 then
        table.insert(result_lines, leading .. current:gsub("%s+$", ""))
    end

    return result_lines
end
-- }}}

-- {{{ function M.wrap_external_url(prefix, url, content_width)
-- Render `prefix .. url` as lines no wider than content_width, BREAKING the URL
-- across lines so it fits its box instead of overflowing (the user prefers
-- wrapping over truncation -- nothing is lost). The box renderer draws each
-- line separately, so a single <a> spanning lines would be split across the box
-- walls; therefore each line carries its OWN <a href=url> wrapping the same full
-- URL, keeping every chunk clickable. Returns a "\n"-joined string ready for the
-- box renderer. URLs are ASCII so byte slicing == character slicing here.
function M.wrap_external_url(prefix, url, content_width)
    prefix = prefix or ""
    local lines = {}
    local pos = 1
    local budget = content_width - M.utf8_char_count(prefix)
    if budget < 1 then budget = content_width end
    while pos <= #url do
        local chunk = url:sub(pos, pos + budget - 1)
        local linked = string.format('<a href="%s" target="_blank" rel="noopener">%s</a>', url, chunk)
        lines[#lines + 1] = (#lines == 0) and (prefix .. linked) or linked
        pos = pos + budget
        budget = content_width
    end
    if #lines == 0 then lines[1] = prefix end
    return table.concat(lines, "\n")
end
-- }}}

-- {{{ local function take_cw_line
-- Takes one line of at most `width` visible columns off the front of `rest`.
-- Returns (line, remaining_text).
--
-- Break preference, latest first: at a space (the space is dropped), or just
-- after a dash (the dash stays at the end of the line -- owner, 2026-09-22:
-- "the dash stays at the end").  Content warnings are often long dash-joined
-- chains with no spaces at all, which is why dashes count as break points
-- here and not in poem text.  With neither available inside the width -- a
-- URL, a magnet link -- the text is cut at the edge.
--
-- Dashes inside an HTML tag would also count; warning text carries no tags.
local function take_cw_line(rest, width)
    if M.calculate_visible_width(rest) <= width then
        return rest, ""
    end
    local chunk, tail = M.slice_by_visible_width(rest, width)
    -- The line is exactly full and a space follows: break on that space.
    if tail:sub(1, 1) == " " then
        return chunk, (tail:gsub("^ +", ""))
    end
    local last_space, last_dash
    local search = 1
    while true do
        local at = chunk:find("[ %-]", search)
        if not at then break end
        if chunk:sub(at, at) == " " then last_space = at else last_dash = at end
        search = at + 1
    end
    -- Where each candidate would END the line (in bytes): a space break ends
    -- before the space, a dash break ends on the dash.  The later end wins.
    local space_end = last_space and (last_space - 1) or -1
    local dash_end = last_dash or -1
    if dash_end > 0 and dash_end >= space_end then
        return chunk:sub(1, dash_end), (chunk:sub(dash_end + 1) .. tail)
    elseif space_end > 0 then
        return chunk:sub(1, space_end), ((chunk:sub(last_space + 1) .. tail):gsub("^ +", ""))
    end
    return chunk, tail
end
-- }}}

-- {{{ function M.format_cw_box
-- Issue 9-011: the one content-warning box every page type draws.
--
-- text      : string, the warning as it should read ("CW: re: ...").  Runs of
--             whitespace, newlines included, become single spaces: a warning
--             is one phrase, and the box decides where its lines break.
-- box_width : number, total visible width of every line of the box,
--             corners and walls included.  The text area is box_width - 4
--             ("│ " + text + " │").
-- returns   : string, the box's lines joined by "\n" -- a top rule, the
--             wrapped text lines, a bottom rule -- every one exactly
--             box_width visible columns wide.  No leading indentation; the
--             caller places the box.
--
-- Widths are counted in visible columns (UTF-8 characters, HTML entities as
-- one), never bytes: the old builder padded by byte length, so a warning with
-- an accented letter or an escaped ampersand came out a column short or long.
function M.format_cw_box(text, box_width)
    assert(type(text) == "string", "format_cw_box: text must be a string")
    assert(type(box_width) == "number" and box_width >= 5,
        "format_cw_box: box_width must be a number of at least 5")
    local inner = box_width - 4
    local rest = text:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")

    local lines = { "┌" .. string.rep("─", box_width - 2) .. "┐" }
    repeat
        local line
        line, rest = take_cw_line(rest, inner)
        local pad = inner - M.calculate_visible_width(line)
        lines[#lines + 1] = "│ " .. line .. string.rep(" ", pad) .. " │"
    until rest == ""
    lines[#lines + 1] = "└" .. string.rep("─", box_width - 2) .. "┘"
    return table.concat(lines, "\n")
end
-- }}}

return M
-- }}}

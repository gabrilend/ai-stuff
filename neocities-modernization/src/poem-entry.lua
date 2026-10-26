-- {{{ poem-entry.lua
-- The one drawer for a poem's whole entry on a page: its top bar, its warning
-- boxes, its text, its pictures, its navigation boxes and its bottom bar --
-- or, for a boost, the boost frame, and for a picture-only entry, the picture
-- box. Every page that shows a poem (chronological, similar, different) asks
-- this module, so a poem looks the same wherever it appears. (Issue 8-058.)
--
-- Why it exists: four copies of this job had grown in four places (the
-- similar/different workers, the chronological page loop, the single-threaded
-- builder and the word pages) and had drifted apart. Measured over 8,622 poems
-- on 2026-10-20, chronological pages styled *emphasis* in 968 poems that the
-- other pages showed as plain asterisks, kept 1,214 lines of exactly 80
-- columns whole that the other pages wrapped, and boxed a content warning
-- written partway down 3 poems that the other pages left as text. The owner
-- chose the chronological behaviour for all three; it is the only behaviour
-- here.
--
-- How a worker uses it: each worker thread is its own Lua state and cannot
-- call the main program's functions, but it can load this file from disk the
-- way it loads the bar drawers -- once, a few dozen KB. (What made workers
-- slow before, Issue 10-034, was each loading 700 MB of neighbour DATA; the
-- orchestrator still hands them only their slice.)
--
-- The shared drawers this builds on (each owns its own geometry):
--   poem-bars      -- the top and bottom bars, the navigation boxes
--   boost-bars     -- the nested boost frame
--   text-formatter -- line splitting, indent-keeping wrapping, warning boxes
--   image-render   -- the box for a picture-only entry
-- }}}

local poem_bars = require("poem-bars")
local boost_bars = require("boost-bars")
local text_formatter = require("text-formatter")
local image_render = require("image-render")

local M = {}

-- {{{ settings
-- Set once per Lua state by configure(); every value is required, because a
-- drawer that guessed a colour or a width would draw a page that looks right
-- and is not.
--   palette    : table, colour name (string) -> "#rrggbb" (string); config.lua
--                semantic_colors, as the main program reads it
--   text_width : number, the text column (80): golden poems put their walls
--                around it ("║ " before, " │" after); regular poems have no
--                walls but the same 2-column indent, so their text starts in
--                the same column and only the borders tell them apart (owner,
--                2026-10-25)
local settings = nil
-- }}}

-- {{{ local function configure()
-- {{{ function M.configure
-- opts: { palette = {name -> hex}, boost_palette = {arrow=, outer_frame=,
--         inner_box=, content_text=}, text_width = number }
function M.configure(opts)
    -- every field must be present: there is no default to fall back on
    if type(opts) ~= "table" or type(opts.palette) ~= "table"
        or type(opts.boost_palette) ~= "table" or type(opts.text_width) ~= "number" then
        error("poem-entry.configure needs palette, boost_palette and text_width")
    end
    if not opts.palette.gray then
        error("poem-entry.configure: the palette has no gray, the colour of an uncoloured poem")
    end
    settings = { palette = opts.palette, text_width = opts.text_width }
    poem_bars.configure(opts.palette, opts.text_width)
    boost_bars.configure(opts.boost_palette)
end
-- }}}
-- }}}

-- {{{ local function require_settings()
local function require_settings()
    if not settings then
        error("poem-entry: configure() was not called in this Lua state")
    end
end
-- }}}

-- {{{ function M.escape_html
-- Poem text as safe page text: control bytes (all but tab, newline, carriage
-- return) removed, then & < > escaped -- & first, or "&lt;" would become
-- "&amp;lt;". Must run BEFORE apply_markdown, so the tags emphasis adds are
-- not escaped. A poem containing "</pre>" would otherwise end the page's
-- preformatted block (Issue 8-041).
-- Line endings become plain newlines first: a poem saved with Windows line
-- endings ("\r\n") would otherwise leave a carriage return at the end of each
-- line inside the page's text block (found by the 8-058 before/after render).
function M.escape_html(text)
    return (text
        :gsub("\r\n", "\n"):gsub("\r", "\n")
        :gsub("[%z\1-\8\11\12\14-\31]", "")
        :gsub("&", "&amp;")
        :gsub("<", "&lt;")
        :gsub(">", "&gt;"))
end
-- }}}

-- {{{ function M.apply_markdown
-- Emphasis renders styled AND keeps the typed marks visible (owner, Issue
-- 4-003: "both"): *love* shows as *love* with only the word slanted. The marks
-- sit outside the tag, because the styling belongs to what the author
-- emphasised, not to the marks used to say so. Marks already used are held as
-- \1 placeholders so the narrower single-asterisk pass cannot match inside a
-- bold span; escape_html removed every \1 from the text beforehand, so a
-- placeholder cannot collide with poem text.
function M.apply_markdown(text)
    -- *\*text*\* -- an old escaped-italics convention, handled first so the
    -- plain passes never half-consume its backslash form
    text = text:gsub("%*\\%*([^%*]+)%*\\%*", "\1<em>%1</em>\1")
    -- **bold** before *italic*, so the pair is not split in two
    text = text:gsub("%*%*([^%*]+)%*%*", "\1\1<strong>%1</strong>\1\1")
    -- *italic*: starts and ends on a non-space and stays on one line, so
    -- "2 * 3 * 4" and asterisk bullet lists are not emphasis (two passes: Lua
    -- patterns have no alternation, so one for 2+ characters, one for one)
    text = text:gsub("%*([^%s%*][^%*\n]-[^%s%*])%*", "\1<em>%1</em>\1")
    text = text:gsub("%*([^%s%*])%*", "\1<em>%1</em>\1")
    -- ~~struck~~ and `code`: the marks stay outside the span, as above
    text = text:gsub("~~([^~]+)~~", "~~<del>%1</del>~~")
    text = text:gsub("`([^`\n]+)`", "`<code>%1</code>`")
    -- placeholders back to the asterisks the author typed
    return (text:gsub("\1", "*"))
end
-- }}}

-- {{{ function M.media_href
-- Where a picture lives under the site's media/ folder, url-encoded for an
-- <img src>. Art images (a path under input/images/<source>/...) KEEP their
-- source and sub-folders, because human-given names collide across folders;
-- fediverse attachments (content hashes) keep only the file name. This MUST
-- match where the page builder copies the pictures (its media flattening
-- step) and image-render.lua's copy of this rule. Slashes kept; space, ?, #
-- and % percent-encoded.
function M.media_href(path)
    local sub = path:match("input/images/(.+)$") or (path:match("([^/]+)$") or path)
    return (sub:gsub("[^%w%-%._~/]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end
-- }}}

-- {{{ local function media_tags()
-- The picture, sound and video tags for a poem's attachments, or an empty
-- list. Each attachment: { media_type = "image/png" | "audio/..." |
-- "video/...", relative_path = string, description or alt_text = string,
-- width = number, height = number } (width and height for images and video
-- only, and only sometimes). Other media types draw nothing.
-- Pages sit one folder below the site root, so "../media/" reaches the
-- pictures from every page type.
local function media_tags(attachments)
    local tags = {}
    for _, att in ipairs(attachments) do
        local media_type = att.media_type or ""
        local src = "../media/" .. M.media_href(att.relative_path or "")
        -- {{{ dispatch on the kind of media
        if media_type:match("^image/") then
            -- alt text: the post's description (ActivityPub) or alt_text, as
            -- one line with quotes escaped, since it sits in an attribute; it
            -- is also the hover title (Issue 8-053)
            -- Escaped in full, not just its quotes: a description quoting
            -- code ("#include <stdio.h>") put a raw "<" inside the attribute
            -- (found by the 8-013 text exports, which measured it short).
            local alt = att.description or att.alt_text or "Image attachment"
            alt = M.escape_html(alt:gsub("\n", " "):gsub("\r", "")):gsub('"', "&quot;")
            -- width/height (when known) let the browser hold the space
            local size = (att.width and att.height)
                and string.format(' width="%d" height="%d"', att.width, att.height) or ""
            tags[#tags + 1] = string.format(
                '  <img src="%s" alt="%s" title="%s" loading="lazy"%s style="display:block; max-width:min(100%%,800px); height:auto">',
                src, alt, alt, size)
        elseif media_type:match("^audio/") then
            tags[#tags + 1] = string.format(
                '  <audio controls preload="metadata" style="display:block; max-width:100%%">\n'
                .. '    <source src="%s" type="%s">\n'
                .. '    Your browser does not support the audio element.\n'
                .. '  </audio>', src, media_type)
        elseif media_type:match("^video/") then
            local size = (att.width and att.height)
                and string.format(' width="%d" height="%d"', att.width, att.height) or ""
            tags[#tags + 1] = string.format(
                '  <video controls preload="metadata"%s style="display:block; max-width:min(100%%,800px); height:auto">\n'
                .. '    <source src="%s" type="%s">\n'
                .. '    Your browser does not support the video element.\n'
                .. '  </video>', size, src, media_type)
        end
        -- any other media type: nothing to draw
        -- }}}
    end
    return tags
end
-- }}}

-- {{{ local function add_media()
-- Appends the attachments' tags to out (a list of lines). The tags go OUTSIDE
-- the page's <pre> block: inside it a picture sizes to its own width and
-- ignores max-width (Issue 8-005), so the block is closed before them and
-- reopened after.
local function add_media(out, poem)
    if not poem.attachments then return end
    local tags = media_tags(poem.attachments)
    if #tags == 0 then return end
    out[#out + 1] = "</pre>"
    for _, tag in ipairs(tags) do out[#out + 1] = tag end
    out[#out + 1] = "<pre>"
end
-- }}}

-- {{{ local function bar_line()
-- A bar as page text: the shared drawer's picture of it, inside a span that
-- carries its screen-reader label ("eighty dashes. yellow."), so a reader
-- using one hears what the line is instead of eighty dashes.
local function bar_line(dashes)
    return string.format("<span %s>%s</span>", dashes.accessibility, dashes.visual)
end
-- }}}

-- {{{ local function text_lines()
-- A poem's text as lines for the frame, before any indent or walls:
--   1. a content warning from the post itself (ActivityPub's summary field)
--      in a box, then two blank lines;
--   2. each line of the text: a line that starts "CW:" or "content warning:"
--      (wherever it falls in the poem) becomes a box and two blank lines;
--      any other line wraps at the text column, keeping its leading indent
--      (Issue 10-021), so the author's spacing survives (Issue 8-056).
-- text is already escaped and has its emphasis applied.
local function text_lines(poem, text)
    local width = settings.text_width
    local lines = {}
    -- {{{ local function add_box()
    local function add_box(warning)
        local box = text_formatter.format_cw_box(warning, width, true)
        for box_line in box:gmatch("[^\n]+") do lines[#lines + 1] = box_line end
        lines[#lines + 1] = ""
        lines[#lines + 1] = ""
    end
    -- }}}
    -- the post's own warning: present -> a box first; absent -> nothing
    if poem.content_warning and poem.content_warning ~= "" then
        add_box("CW: " .. M.escape_html(poem.content_warning))
    end
    for _, line in ipairs(text_formatter.format_poem_lines(text)) do
        local lower = line:lower()
        if lower:match("^%s*cw%s*:") or lower:match("^%s*content warning%s*:") then
            -- a warning line in the text: boxed where it stands
            add_box(line)
        else
            -- an ordinary line: wrapped at the text column, indent kept,
            -- and any spaces at its end dropped: the text is at most the
            -- text column wide, and a trailing space past the 80th character
            -- would push into the frame's own space (owner, 2026-10-25)
            -- (before wrapping too: an 80-character line with a space after it
            -- would otherwise be wrapped one word early)
            local trimmed = line:gsub("%s+$", "")
            for _, wrapped in ipairs(text_formatter.wrap_preserving_indent(trimmed, width)) do
                lines[#lines + 1] = (wrapped:gsub("%s+$", ""))
            end
        end
    end
    return lines
end
-- }}}

-- {{{ local function golden_walls()
-- A golden poem's lines between its walls: the left wall ║ in the poem's
-- colour, a space, the line padded to the text column by its VISIBLE width
-- (tags and entities do not count; a box-drawing character is one column),
-- a space, and the right wall │. A line already at or past the column is left
-- as it is, so nothing is cut.
local function golden_walls(lines, hex_color)
    local width = settings.text_width
    local wall = string.format('<font color="%s"><b>║</b></font>', hex_color)
    local walled = {}
    for i, line in ipairs(lines) do
        local visible = text_formatter.calculate_visible_width(line)
        local padded = visible >= width and line or (line .. string.rep(" ", width - visible))
        walled[i] = wall .. " " .. padded .. " │"
    end
    return walled
end
-- }}}

-- {{{ local function placeholder()
-- A picture, sound or video as a line of text: "[Image: <description>]",
-- "[Audio: <file name>]", "[Video: <file name>]" (the text exports, Issue
-- 8-013). tag is one HTML media tag (or block); indent is the spaces it had.
local function placeholder(indent, tag)
    local alt = tag:match('alt="([^"]*)"')
    if tag:match("^<img") then
        return indent .. "[Image: " .. (alt or "picture") .. "]"
    end
    local src = tag:match('<source src="([^"]*)"') or ""
    local name = src:match("([^/]+)$") or src
    if tag:match("^<audio") then
        return indent .. "[Audio: " .. name .. "]"
    end
    return indent .. "[Video: " .. name .. "]"
end
-- }}}

-- {{{ local function decode_entities()
-- Entities back to their characters, for text that is no longer HTML.
-- "&amp;" goes last: "&amp;lt;" is the text "&lt;", not "<".
local function decode_entities(s)
    return (s:gsub("&#x(%x+);", function(h) return M.utf8_char(tonumber(h, 16)) end)
        :gsub("&#(%d+);", function(d) return M.utf8_char(tonumber(d)) end)
        :gsub("&quot;", '"'):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&amp;", "&"))
end
-- }}}

-- {{{ function M.utf8_char
-- One Unicode code point as UTF-8 bytes (LuaJIT has no utf8 library).
function M.utf8_char(cp)
    if cp < 0x80 then return string.char(cp) end
    if cp < 0x800 then
        return string.char(0xC0 + math.floor(cp / 0x40), 0x80 + cp % 0x40)
    end
    if cp < 0x10000 then
        return string.char(0xE0 + math.floor(cp / 0x1000),
            0x80 + math.floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40)
    end
    return string.char(0xF0 + math.floor(cp / 0x40000), 0x80 + math.floor(cp / 0x1000) % 0x40,
        0x80 + math.floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40)
end
-- }}}

-- {{{ function M.to_plain
-- An entry's HTML as plain text, for the text exports (Issue 8-013): each
-- picture, sound or video becomes one placeholder line (wrapped at the text
-- column if its description is long), the <pre> breaks around them and the
-- <hr> rules of a picture entry go, every other tag is removed, and entities
-- become their characters. The frames are box-drawing characters already, so
-- they survive as they are.
function M.to_plain(html)
    -- the column width comes from configure() (config.lua layout); drawing
    -- plain text before it was set is an error, not a guess at 80
    local width = settings and settings.text_width
        or error("poem-entry.to_plain: configure() has not given a text width")
    -- multi-line media blocks (audio, video) become one line first
    html = html:gsub("(%s*)(<audio.-</audio>)", function(ind, tag) return placeholder(ind:gsub("\n", ""), tag) end)
    html = html:gsub("(%s*)(<video.-</video>)", function(ind, tag) return placeholder(ind:gsub("\n", ""), tag) end)
    local out = {}
    for line in (html .. "\n"):gmatch("(.-)\n") do
        local indent, img = line:match("^(%s*)(<img .*)$")
        if img then
            -- {{{ a picture: its placeholder, wrapped at the text column
            -- Wrapped while still escaped, then decoded: the wrapper measures
            -- width by skipping anything shaped like a tag, so a description
            -- quoting "#include <stdio.h>" would measure short once decoded
            -- and run past the frame.
            local text = placeholder(indent, img)
            for _, piece in ipairs(text_formatter.wrap_preserving_indent(text, width)) do
                out[#out + 1] = decode_entities(piece)
            end
            -- }}}
        elseif line == "</pre>" or line == "<pre>" or line == "<hr>" then
            -- page structure around pictures: nothing to show in text
        else
            out[#out + 1] = decode_entities(line:gsub("<[^>]+>", ""))
        end
    end
    return table.concat(out, "\n")
end
-- }}}

-- {{{ local function boost_entry()
-- A boost (someone else's post, shared): the nested boost frame from
-- boost-bars around the shared text, then its pictures. Its text is
-- escaped, wrapped to the frame's content width and given emphasis, like a
-- poem's. A boost whose text was lost shows where it came from instead.
local function boost_entry(poem, entry)
    local text = M.escape_html(poem.content or "")
    -- {{{ blank text: the original address if known, else say it is missing
    if text:match("^%s*$") then
        local uri = poem.metadata and poem.metadata.original_uri
        if uri then
            text = "External post: " .. M.escape_html(uri)
        else
            text = "(Boost content unavailable)"
        end
    end
    -- }}}
    -- {{{ an external address wraps as one link; other text wraps by line
    local width = boost_bars.CONTENT_WIDTH
    local url = text:match("^External post: (https?://[^%s]+)$")
    if url then
        text = text_formatter.wrap_external_url("External post: ", url, width)
    else
        local wrapped = {}
        for line in (text .. "\n"):gmatch("(.-)\n") do
            for _, piece in ipairs(text_formatter.wrap_preserving_indent(line, width)) do
                wrapped[#wrapped + 1] = piece
            end
        end
        text = table.concat(wrapped, "\n")
    end
    -- }}}
    text = M.apply_markdown(text)
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
    -- the navigation strip inside the frame: on a page; not in a text export
    local out = { boost_bars.format_boost(lines, entry.progress_pct / 100,
        entry.similar_link, entry.different_link, entry.chrono_link or nil, not entry.plain) }
    add_media(out, poem)
    return table.concat(out, "\n")
end
-- }}}

-- {{{ local function draw_entry()
-- The entry as HTML; format_entry below turns it into text for an export.
local function draw_entry(poem, entry)
    -- {{{ dispatch on the kind of entry
    if poem.is_image then
        -- a picture-only entry: its own box (Issue 9-013)
        return image_render.format_image_entry(poem)
    end
    if poem.metadata and poem.metadata.is_boost then
        -- a boost: the boost frame (Issue 8-057)
        return boost_entry(poem, entry)
    end
    -- }}}
    local is_golden = (poem.metadata and poem.metadata.is_golden_poem) and true or false
    local hex_color = settings.palette[entry.color_name]
    if not hex_color then
        error("poem-entry: colour '" .. tostring(entry.color_name) .. "' is not in the palette")
    end
    local progress = { percentage = entry.progress_pct, poem_id = poem.poem_index }
    local top = poem_bars.progress_dashes(progress, entry.color_name, is_golden, "top", false)
    -- the bottom bar joins the navigation boxes on a page; in a text export
    -- there are none, so it is the plain bar
    local bottom = poem_bars.progress_dashes(progress, entry.color_name, is_golden, "bottom", not entry.plain)
    -- the navigation boxes are tinted as far as the top bar is filled
    local fill = top.raw_progress
    local chrono_link = entry.chrono_link or nil

    local lines = text_lines(poem, M.apply_markdown(M.escape_html(poem.content or "")))
    local out = { bar_line(top) }
    -- {{{ golden (exactly 1024 characters when posted): walls; else an indent
    if is_golden then
        for _, line in ipairs(golden_walls(lines, hex_color)) do out[#out + 1] = line end
    else
        -- the 2-column indent (as wide as a golden poem's "║ ") goes on lines
        -- with text, so regular and golden text start in the same column and
        -- only the borders tell them apart (owner, 2026-10-25); a blank line
        -- stays empty (spaces show nothing and cost bytes on every blank line
        -- of ~52,000 pages)
        for _, line in ipairs(lines) do
            out[#out + 1] = line == "" and "" or ("  " .. line)
        end
    end
    -- }}}
    -- pictures go before the navigation boxes, for golden poems too, so the
    -- golden frame stays in one piece
    add_media(out, poem)
    -- {{{ navigation boxes: golden's join its walls; regular ones stand alone;
    -- a text export has none (no links to follow in a text file)
    if entry.plain then
        -- no boxes
    elseif is_golden then
        out[#out + 1] = poem_bars.golden_corner_box_separator(hex_color, fill)
        out[#out + 1] = poem_bars.golden_corner_box_nav_line(
            entry.similar_link, entry.different_link, chrono_link, hex_color, fill)
    else
        out[#out + 1] = poem_bars.corner_box_top(fill, hex_color)
        out[#out + 1] = poem_bars.corner_box_nav_line(
            entry.similar_link, entry.different_link, chrono_link, fill, hex_color)
    end
    -- }}}
    out[#out + 1] = bar_line(bottom)
    return table.concat(out, "\n")
end
-- }}}

-- {{{ function M.format_entry
-- One poem's entry, with no trailing newline (the page puts its own spacing
-- between entries).
-- poem  : a poem from poems.json (or a picture-only entry, is_image = true)
-- entry : {
--   color_name     = string, the poem's semantic colour ("gray" if none),
--   progress_pct   = number 0-100, how far through the writing timeline,
--   similar_link   = string, <a> to its similar page,
--   different_link = string, <a> to its different page,
--   chrono_link    = string <a> to its chronological page, or false on the
--                    chronological pages themselves (an empty centre box),
--   plain          = true for a text export (Issue 8-013): no navigation
--                    boxes and no HTML; absent or false for a page,
-- }
function M.format_entry(poem, entry)
    require_settings()
    local html = draw_entry(poem, entry)
    -- a text export: the same entry as plain text; a page: as drawn
    if entry.plain then return M.to_plain(html) end
    return html
end
-- }}}

return M

-- markdown.lua
-- A small, dependency-free Markdown -> HTML renderer (Issue 10-055, Feature B).
--
-- General description (for the reader skimming): the source browser used to dump
-- .md files as plain numbered text, so tables were ASCII soup and headings were
-- not headings. This turns the common Markdown the repo actually uses -- ATX
-- headings, bold/italic, inline + fenced code, ordered/unordered lists, GitHub
-- pipe tables, blockquotes, horizontal rules, and links -- into clean HTML. It
-- is intentionally a pragmatic subset, not a CommonMark engine: it must run
-- server-side in LuaJIT with no JavaScript on the page (the deploy platform
-- forbids script), and it must be readable. Anything it does not recognize falls
-- through as an escaped paragraph, so unknown input degrades to plain text
-- rather than breaking.
--
-- Public surface: M.render(markdown_text) -> html_string.

local M = {}

-- {{{ local function escape_html()
-- Escape the three characters that would otherwise be read as markup. Done to
-- the RAW text before any tags are emitted, so our own <em>/<a>/... are the only
-- angle brackets that survive. Ampersand first, or we would double-escape the
-- entities we just produced.
local function escape_html(s)
    return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end
-- }}}

-- {{{ local function render_inline()
-- Turn one already-trusted line of text into inline HTML. Order matters:
--   1. escape, so user text can never inject tags;
--   2. lift out `code spans` into placeholders, so the * and _ inside code are
--      not later mistaken for emphasis (the classic bug if you gsub naively);
--   3. links, then bold (**), then italic (* or _);
--   4. drop the code spans back in as <code>.
-- The placeholder bytes (\1 .. \2) cannot appear in normal text, so they make a
-- safe stash that the emphasis passes skip over.
local function render_inline(text)
    text = escape_html(text)

    local code_spans = {}
    text = text:gsub("`([^`]+)`", function(code)
        code_spans[#code_spans + 1] = code
        return "\1" .. #code_spans .. "\2"
    end)

    -- Images first (![alt](src)) so the leading ! is consumed before links.
    text = text:gsub("!%[([^%]]*)%]%(([^%)%s]+)[^%)]*%)", function(alt, src)
        return string.format('<img src="%s" alt="%s">', src, alt)
    end)
    -- Links [text](url).
    text = text:gsub("%[([^%]]*)%]%(([^%)%s]+)[^%)]*%)", function(label, url)
        return string.format('<a href="%s">%s</a>', url, label)
    end)
    -- Bold before italic, so **x** is not eaten by the single-* rule.
    text = text:gsub("%*%*(.-)%*%*", "<strong>%1</strong>")
    text = text:gsub("__(.-)__", "<strong>%1</strong>")
    text = text:gsub("%*([^%s][^%*]-)%*", "<em>%1</em>")
    -- Underscore italic only between word boundaries, so snake_case_names survive.
    text = text:gsub("%f[%w_]_([^_]+)_%f[^%w_]", "<em>%1</em>")

    text = text:gsub("\1(%d+)\2", function(n)
        return "<code>" .. code_spans[tonumber(n)] .. "</code>"
    end)
    return text
end
-- }}}

-- {{{ local function is_table_separator()
-- A GitHub table's second line: pipes around dashes, optionally with colons for
-- alignment, e.g. |:---|---:|. Recognizing it is what tells row 1 it was a header.
local function is_table_separator(line)
    if not line:find("|") then return false end
    local body = line:gsub("^%s*|?", ""):gsub("|?%s*$", "")
    for cell in (body .. "|"):gmatch("(.-)|") do
        if not cell:match("^%s*:?%-+:?%s*$") then return false end
    end
    return true
end
-- }}}

-- {{{ local function split_row()
-- Split a table row on unescaped pipes, trimming each cell. Leading/trailing
-- pipes are optional in the source, so we strip them before splitting.
local function split_row(line)
    local cells = {}
    local body = line:gsub("^%s*|", ""):gsub("|%s*$", "")
    for cell in (body .. "|"):gmatch("(.-)|") do
        cells[#cells + 1] = (cell:gsub("^%s+", ""):gsub("%s+$", ""))
    end
    return cells
end
-- }}}

-- {{{ M.render()
-- Block-level pass. Walk the lines once, and at each line decide which block it
-- starts (fence, table, list, quote, rule, heading) or whether it joins a
-- paragraph. Blocks that contain code are emitted verbatim-escaped with NO inline
-- pass; everything else gets render_inline so emphasis/links/code work.
function M.render(md)
    local lines = {}
    for line in (md .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end

    local out = {}
    local i, n = 1, #lines
    while i <= n do
        local line = lines[i]

        -- Fenced code block: ```lang ... ``` . Content is literal, escaped, no inline.
        local fence = line:match("^```(.*)$")
        if fence ~= nil then
            local lang = fence:match("^%s*(%S*)")
            local code = {}
            i = i + 1
            while i <= n and not lines[i]:match("^```") do
                code[#code + 1] = escape_html(lines[i]); i = i + 1
            end
            i = i + 1  -- consume the closing fence
            local cls = (lang ~= "" and lang) and string.format(' class="lang-%s"', lang) or ""
            out[#out + 1] = string.format("<pre><code%s>%s</code></pre>", cls,
                table.concat(code, "\n"))

        -- Pipe table: a line with pipes whose NEXT line is a separator row.
        elseif line:find("|") and lines[i + 1] and is_table_separator(lines[i + 1]) then
            local header = split_row(line)
            i = i + 2  -- skip header + separator
            local thead = {}
            for _, c in ipairs(header) do thead[#thead + 1] = "<th>" .. render_inline(c) .. "</th>" end
            local rows = { "<tr>" .. table.concat(thead) .. "</tr>" }
            while i <= n and lines[i]:find("|") and lines[i]:match("%S") do
                local tds = {}
                for _, c in ipairs(split_row(lines[i])) do tds[#tds + 1] = "<td>" .. render_inline(c) .. "</td>" end
                rows[#rows + 1] = "<tr>" .. table.concat(tds) .. "</tr>"
                i = i + 1
            end
            out[#out + 1] = "<table>" .. table.concat(rows) .. "</table>"

        -- Horizontal rule: a line of only ---, ***, or ___ (3+).
        elseif line:match("^%s*%-%-%-+%s*$") or line:match("^%s*%*%*%*+%s*$")
            or line:match("^%s*___+%s*$") then
            out[#out + 1] = "<hr>"; i = i + 1

        -- ATX heading: #..###### then text.
        elseif line:match("^#+%s") then
            local hashes, text = line:match("^(#+)%s+(.*)$")
            local level = math.min(#hashes, 6)
            out[#out + 1] = string.format("<h%d>%s</h%d>", level, render_inline(text), level)
            i = i + 1

        -- Blockquote: consecutive lines starting with >.
        elseif line:match("^%s*>") then
            local quoted = {}
            while i <= n and lines[i]:match("^%s*>") do
                quoted[#quoted + 1] = render_inline((lines[i]:gsub("^%s*>%s?", "")))
                i = i + 1
            end
            out[#out + 1] = "<blockquote>" .. table.concat(quoted, "<br>") .. "</blockquote>"

        -- Unordered list: -, *, or + markers.
        elseif line:match("^%s*[%-%*%+]%s+") then
            local items = {}
            while i <= n and lines[i]:match("^%s*[%-%*%+]%s+") do
                items[#items + 1] = "<li>" .. render_inline((lines[i]:gsub("^%s*[%-%*%+]%s+", ""))) .. "</li>"
                i = i + 1
            end
            out[#out + 1] = "<ul>" .. table.concat(items) .. "</ul>"

        -- Ordered list: 1. 2. ...
        elseif line:match("^%s*%d+%.%s+") then
            local items = {}
            while i <= n and lines[i]:match("^%s*%d+%.%s+") do
                items[#items + 1] = "<li>" .. render_inline((lines[i]:gsub("^%s*%d+%.%s+", ""))) .. "</li>"
                i = i + 1
            end
            out[#out + 1] = "<ol>" .. table.concat(items) .. "</ol>"

        -- Blank line: paragraph separator, nothing to emit.
        elseif line:match("^%s*$") then
            i = i + 1

        -- Otherwise a paragraph: gather consecutive "plain" lines until a blank
        -- line or a line that starts some other block.
        else
            local para = {}
            while i <= n do
                local l = lines[i]
                if l:match("^%s*$") or l:match("^#+%s") or l:match("^```")
                    or l:match("^%s*>") or l:match("^%s*[%-%*%+]%s+")
                    or l:match("^%s*%d+%.%s+")
                    or l:match("^%s*%-%-%-+%s*$")
                    or (l:find("|") and lines[i + 1] and is_table_separator(lines[i + 1])) then
                    break
                end
                para[#para + 1] = render_inline(l)
                i = i + 1
            end
            out[#out + 1] = "<p>" .. table.concat(para, "<br>") .. "</p>"
        end
    end

    return table.concat(out, "\n")
end
-- }}}

return M

#!/usr/bin/env luajit
-- validate-output-worker.lua -- checks one share of the site's pages.
--
-- WHAT IT DOES (for a CEO): the site is drawn out of fixed-width text; a line
-- one character too long breaks the frames around a poem, and a link to a
-- file that was never written is a page-not-found.  This reads a batch of
-- pages and writes down every over-wide line and every broken link it finds.
-- scripts/validate-output runs many of these at once, one per processor, and
-- merges what they found.  (Issue 9-006.)
--
-- Usage: luajit scripts/validate-output-worker.lua MAX_WIDTH FINDINGS_FILE PAGE...
--   MAX_WIDTH      widest allowed line inside a poem column, in visible
--                  characters (84: the golden frame, the widest one drawn)
--   FINDINGS_FILE  where this worker writes its findings, one per line:
--                  wide <TAB> page <TAB> line number <TAB> width <TAB> cause
--                       <TAB> excerpt
--                  link <TAB> page <TAB> line number <TAB> target <TAB> count
--                       <TAB> (empty)
--                  An over-wide line is one row each.  A missing link target
--                  is ONE row per target per worker, carrying how many times
--                  it was seen and the first page/line it was seen on: a site
--                  with its similar pages missing has millions of broken
--                  links, and one row each filled 4 GB of RAM.
--   PAGE...        the HTML files to check

local MAX_WIDTH = tonumber(arg[1])
local FINDINGS_FILE = arg[2]
assert(MAX_WIDTH and FINDINGS_FILE and arg[3],
    "usage: validate-output-worker.lua MAX_WIDTH FINDINGS_FILE PAGE...")

-- {{{ local function visible_width
-- Width as a reader sees it: tags removed, each entity (&amp; &#39;) one
-- character, each UTF-8 character one column.
local function visible_width(text)
    local plain = text:gsub("<[^>]*>", "")
    plain = plain:gsub("&#?%w+;", "x")
    local without_continuation_bytes = plain:gsub("[\128-\191]", "")
    return #without_continuation_bytes, plain
end
-- }}}

-- {{{ local function cause_of
-- Groups an over-wide line by what made it wide, so a report of thousands of
-- lines reads as a handful of problems.  Order matters: a URL inside a
-- content-warning box is reported as the warning box, which is what to fix.
local CAUSE_RULES = {
    { "cw",    function(plain) return plain:find("│ CW", 1, true) or plain:find("CW:", 1, true) end },
    { "url",   function(plain) return plain:find("https?://") or plain:find("magnet:", 1, true) end },
    { "bar",   function(plain) return plain:match("^[%s═─━┄╌]+$") ~= nil end },
    { "frame", function(plain) return plain:match("^%s*[║│┃╎]") or plain:match("[║│┃╎]%s*$") end },
}
local function cause_of(plain)
    for _, rule in ipairs(CAUSE_RULES) do
        if rule[2](plain) then return rule[1] end
    end
    return "text"
end
-- }}}

-- {{{ local function file_exists
local exists_cache = {}
local function file_exists(path)
    local known = exists_cache[path]
    if known ~= nil then return known end
    local handle = io.open(path, "r")
    if handle then handle:close() end
    exists_cache[path] = handle ~= nil
    return handle ~= nil
end
-- }}}

-- {{{ local function resolve
-- A relative link resolved against the folder of the page it sits in, with
-- "." and ".." walked out, so the check asks the filesystem about the real
-- target.  Returns nil for links that are not files on this site.
local function resolve(page_dir, href)
    if href:match("^%a[%w+.-]*:") or href:sub(1, 1) == "#" or href:sub(1, 1) == "/" then
        return nil  -- http:, mailto:, magnet:, in-page anchors, site-absolute
    end
    href = href:gsub("#.*$", ""):gsub("%?.*$", "")
    if href == "" then return nil end
    href = href:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end)
    local parts = {}
    for part in (page_dir .. "/" .. href):gmatch("[^/]+") do
        if part == ".." then
            parts[#parts] = nil
        elseif part ~= "." then
            parts[#parts + 1] = part
        end
    end
    return "/" .. table.concat(parts, "/")
end
-- }}}

local out = assert(io.open(FINDINGS_FILE, "w"))

-- {{{ local function record
-- Over-wide lines: written as they are found.
local function record(kind, page, line_number, value, cause, excerpt)
    excerpt = excerpt:gsub("[\t\r\n]", " "):sub(1, 160)
    out:write(table.concat({ kind, page, tostring(line_number), tostring(value), cause, excerpt }, "\t"), "\n")
end
-- }}}

-- {{{ local function record_missing_link
-- Missing links: counted per target in memory, written once at the end.
-- missing_links : target (string) -> { count, first_page, first_line }
local missing_links = {}
local function record_missing_link(page, line_number, target)
    local seen = missing_links[target]
    if seen then
        seen.count = seen.count + 1
    else
        missing_links[target] = { count = 1, page = page, line = line_number }
    end
end
-- }}}

-- {{{ check each page
for i = 3, #arg do
    local page = arg[i]
    local page_dir = page:match("^(.*)/[^/]*$") or "."
    local handle = io.open(page, "r")
    if not handle then
        record_missing_link(page, 0, "(unreadable page) " .. page)
    else
        local inside_pre = false
        local line_number = 0
        for line in handle:lines() do
            line_number = line_number + 1

            -- Links: every href and src on the line.
            for attr_value in line:gmatch('href="([^"]*)"') do
                local target = resolve(page_dir, attr_value)
                if target and not file_exists(target) then
                    record_missing_link(page, line_number, attr_value)
                end
            end
            for attr_value in line:gmatch("href='([^']*)'") do
                local target = resolve(page_dir, attr_value)
                if target and not file_exists(target) then
                    record_missing_link(page, line_number, attr_value)
                end
            end
            for attr_value in line:gmatch('src="([^"]*)"') do
                local target = resolve(page_dir, attr_value)
                if target and not file_exists(target) then
                    record_missing_link(page, line_number, attr_value)
                end
            end

            -- Widths: only the part of the line inside a <pre> poem column.
            local measured = nil
            local open_start, open_end = line:find("<pre[^>]*>")
            local close_start = line:find("</pre>", 1, true)
            if open_start then
                measured = line:sub(open_end + 1, (close_start or 0) - 1)
                inside_pre = not close_start
            elseif inside_pre then
                measured = close_start and line:sub(1, close_start - 1) or line
                if close_start then inside_pre = false end
            end
            if measured then
                local width, plain = visible_width(measured)
                if width > MAX_WIDTH then
                    record("wide", page, line_number, width, cause_of(plain), plain)
                end
            end
        end
        handle:close()
    end
end
-- }}}

-- {{{ write the missing-link tallies
for target, seen in pairs(missing_links) do
    out:write(table.concat({ "link", seen.page, tostring(seen.line), target, tostring(seen.count), "" }, "\t"), "\n")
end
-- }}}

out:close()

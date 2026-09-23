#!/usr/bin/env luajit

-- Guards issue 10-036's "next page is page-not-found": every Previous/Next
-- link on a similar/different page must name a page this build wrote.
--
-- Why this test exists. A ranking long enough to fill several pages used to
-- give page 1 a "Next Page" link to page 2 even when the build wrote only
-- page 1 (the default) -- a link to a file that was never written, on every
-- poem's first page.  Here a ranking fills three pages; the cases write one,
-- all three, and pages 1 and 3 only, and check every link against the files
-- that actually exist.
--
-- Run directly:  luajit src/flat-html-generator.page-links.test.lua [project-dir]

local DIR = arg and arg[1] or nil

-- {{{ local function setup_path()
local function setup_path()
    local this = debug.getinfo(1, "S").source:sub(2)
    local src_dir = this:match("(.*/)") or "./"
    local project_dir = DIR or src_dir:gsub("src/$", "")
    package.path = src_dir .. "?.lua;" .. project_dir .. "libs/?.lua;" .. package.path
end
-- }}}

setup_path()
local generator = require("flat-html-generator")

local SCRATCH = "/tmp/neocities-modernization/tmp/page-links-test"

local passed, failed = 0, 0

-- {{{ local function check()
local function check(name, condition, detail)
    if condition then
        passed = passed + 1
        print("  ok   " .. name)
    else
        failed = failed + 1
        print("  FAIL " .. name .. (detail and ("  -- " .. detail) or ""))
    end
end
-- }}}

-- {{{ local function read_file()
local function read_file(path)
    local handle = io.open(path, "r")
    if not handle then return nil end
    local contents = handle:read("*a")
    handle:close()
    return contents
end
-- }}}

-- {{{ local function page_links()
-- Every Previous/Next target on a page, as a list of filenames.
local function page_links(html)
    local targets = {}
    for href in html:gmatch('<a href="(%d%d%d%d%-%d+%.html)">') do
        targets[#targets + 1] = href
    end
    return targets
end
-- }}}

-- A corpus big enough to fill three pages of the configured page size.
local per_page = generator.get_pagination_config().poems_per_page
local poem_count = per_page * 2 + 5
local poems = {}
for i = 1, poem_count do
    poems[i] = {
        poem_index = i, id = i, category = "messages",
        title = "Poem " .. i, content = "words of poem " .. i,
        creation_date = string.format("2020-01-%02dT00:00:00Z", (i % 28) + 1),
    }
end
local mapping = generator.compute_chronological_mapping({ poems = poems }, nil)
local ranking = {}
for i = 2, poem_count do ranking[#ranking + 1] = { id = i, poem = poems[i] } end

-- {{{ local function build()
-- Writes the requested pages into a fresh folder and returns, for each file
-- written, its Previous/Next targets -- plus the set of files that exist.
local function build(pages)
    os.execute('rm -rf "' .. SCRATCH .. '"')
    os.execute('mkdir -p "' .. SCRATCH .. '"')
    local result = generator.generate_all_paginated_pages_for_poem(
        poems[1], ranking, "similar", 1, SCRATCH, pages, mapping, false)
    local links, exists = {}, {}
    for _, path in ipairs(result.files_generated) do
        local name = path:match("([^/]+)$")
        exists[name] = true
        links[name] = page_links(read_file(path) or "")
    end
    return links, exists
end
-- }}}

-- {{{ local function all_links_resolve()
local function all_links_resolve(links, exists)
    for page, targets in pairs(links) do
        for _, target in ipairs(targets) do
            if not exists[target] then return false, page .. " -> " .. target end
        end
    end
    return true
end
-- }}}

-- {{{ Case: only page 1 written (the default build)
do
    local links, exists = build({ 1 })
    check("page 1 only: one page written", exists["0001-01.html"] and not exists["0001-02.html"])
    check("page 1 only: no Next link to an unwritten page", #(links["0001-01.html"] or {}) == 0,
        table.concat(links["0001-01.html"] or {}, ", "))
end
-- }}}

-- {{{ Case: all three pages written
do
    local links, exists = build({ 1, 2, 3 })
    local ok, bad = all_links_resolve(links, exists)
    check("all pages: every Previous/Next link resolves", ok, bad)
    -- Navigation is drawn above and below the poems, so each target twice.
    local targets = {}
    for _, t in ipairs(links["0001-02.html"] or {}) do targets[t] = true end
    check("all pages: page 2 links back to 1 and on to 3",
        targets["0001-01.html"] and targets["0001-03.html"],
        table.concat(links["0001-02.html"] or {}, ", "))
end
-- }}}

-- {{{ Case: pages 1 and 3, skipping 2
do
    local links, exists = build({ 1, 3 })
    local ok, bad = all_links_resolve(links, exists)
    check("pages 1 and 3: every link resolves", ok, bad)
    check("pages 1 and 3: page 1's Next goes to page 3",
        (links["0001-01.html"] or {})[1] == "0001-03.html",
        tostring((links["0001-01.html"] or {})[1]))
end
-- }}}

-- {{{ Case: a requested page past the end is not written or linked
do
    local links, exists = build({ 1, 9 })
    check("page past the end: not written", not exists["0001-09.html"])
    check("page past the end: not linked", #(links["0001-01.html"] or {}) == 0)
end
-- }}}

os.execute('rm -rf "' .. SCRATCH .. '"')
print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)

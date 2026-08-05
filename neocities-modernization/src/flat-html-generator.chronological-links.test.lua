#!/usr/bin/env luajit

-- Guards the one promise the "chronological" link on every similar/different
-- page makes: it names the chronological page that actually holds that poem.
--
-- Why this test exists. A full site build once shipped 694,530 chronological
-- links that ALL pointed at page 1, because the poem-index-to-page mapping was
-- computed correctly and then quietly not passed down the chain of five
-- functions that lead to the link. Nothing failed; the formatter had a
-- "guess 01" fallback that turned a missing argument into plausible-looking
-- output. So these cases assert the PLUMBING, not just the formatting: if any
-- function in that chain stops forwarding the mapping, a link here moves to the
-- wrong page and the test fails.
--
-- Run directly:  luajit src/flat-html-generator.chronological-links.test.lua
-- Optional argument: project directory (defaults to this file's parent).

-- Hard-coded project directory, overridable by the first argument, so the test
-- runs from anywhere.
local DIR = arg and arg[1] or nil

-- {{{ local function setup_path()
-- Resolves the module and library paths relative to this file, so the test does
-- not care what directory it was launched from.
local function setup_path()
    local this = debug.getinfo(1, "S").source:sub(2)
    local src_dir = this:match("(.*/)") or "./"
    local project_dir = DIR or src_dir:gsub("src/$", "")
    package.path = src_dir .. "?.lua;" .. project_dir .. "libs/?.lua;" .. package.path
    return project_dir
end
-- }}}

local PROJECT_DIR = setup_path()
local generator = require("flat-html-generator")

-- Ephemeral scratch space. The pages this test writes are throwaway artifacts,
-- so they belong on the RAM tier rather than in the repository. Created here
-- because the project tmp/ symlink may not exist on a fresh checkout.
local SCRATCH = "/tmp/neocities-modernization/tmp/chronological-link-test"
os.execute(string.format('mkdir -p "%s/similar" "%s/different"', SCRATCH, SCRATCH))

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

-- {{{ local function make_poem()
-- Minimal poem shaped the way the formatter reads it. poem_index is the field
-- the chronological mapping is keyed by; everything else is filler so the
-- renderer has something to draw.
local function make_poem(index)
    return {
        poem_index = index,
        id = index,
        title = "Poem " .. index,
        content = "a line of text for poem " .. index,
        category = "messages",
        filename = "messages/" .. index,
    }
end
-- }}}

-- {{{ local function make_ranking()
-- The sorted-neighbour list the similar/different pages are built from.
local function make_ranking(indices)
    local ranking = {}
    for _, index in ipairs(indices) do
        table.insert(ranking, { id = index, poem = make_poem(index), similarity = 0.5 })
    end
    return ranking
end
-- }}}

-- {{{ local function make_mapping()
-- Builds the poem_index -> {page_number, total_pages, ...} table exactly as
-- compute_chronological_mapping does, from a plain index-to-page list. Written
-- by hand rather than computed so the expected page numbers are visible in the
-- test itself, not derived by the same arithmetic under test.
local function make_mapping(pages_by_index, total_pages)
    local mapping = {}
    for index, page in pairs(pages_by_index) do
        mapping[index] = {
            position = (page - 1) * 88 + 1,
            page_number = page,
            total_poems = total_pages * 88,
            total_pages = total_pages,
            timeline_progress = 50,
        }
    end
    return mapping
end
-- }}}

-- {{{ local function chrono_targets()
-- Extracts every chronological link from generated HTML as
-- {["poem-7320"] = "83"} so a case can assert one poem's page without caring
-- about the order poems were rendered in. "index" is recorded as the page for
-- the unpaginated / fallback target.
local function chrono_targets(html)
    local targets = {}
    for page, anchor in html:gmatch("chronological/([a-z0-9]+)%.html#(poem%-%d+)") do
        targets[anchor] = page
    end
    return targets
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

-- The corpus these cases pretend to be walking: 5 poems scattered across a
-- 90-page chronological view, deliberately NOT on page 1, because page 1 is the
-- value the old fallback produced and would otherwise look like a pass.
local PAGES_BY_INDEX = { [7] = 7, [120] = 2, [3549] = 41, [7320] = 83, [96] = 90 }
local TOTAL_PAGES = 90
local ANCHOR_INDEX = 7
local NEIGHBOUR_INDICES = { 120, 3549, 7320, 96 }

-- {{{ Case: paginated build aims every link at its own page
-- The regression case. Each poem must land on its own chronological page, and
-- the anchor poem is included because it is rendered by a separate call inside
-- the formatter and could drop the mapping independently of its neighbours.
do
    local mapping = make_mapping(PAGES_BY_INDEX, TOTAL_PAGES)
    local html = generator.generate_flat_poem_list_html(
        make_poem(ANCHOR_INDEX), make_ranking(NEIGHBOUR_INDICES), "similar", ANCHOR_INDEX,
        mapping, true)
    local targets = chrono_targets(html)

    check("anchor poem links to its own page", targets["poem-7"] == "07",
        "got " .. tostring(targets["poem-7"]) .. ", wanted 07")
    check("neighbour on page 2 links to 02", targets["poem-120"] == "02",
        "got " .. tostring(targets["poem-120"]))
    check("neighbour on page 41 links to 41", targets["poem-3549"] == "41",
        "got " .. tostring(targets["poem-3549"]))
    check("neighbour on page 83 links to 83", targets["poem-7320"] == "83",
        "got " .. tostring(targets["poem-7320"]))
    check("neighbour on page 90 links to 90", targets["poem-96"] == "90",
        "got " .. tostring(targets["poem-96"]))

    -- The shape of the failure being guarded against: everything collapsing to
    -- one page. Stated separately so a regression reads as "all links collapsed"
    -- rather than four unrelated failures.
    local distinct = {}
    local count = 0
    for _, page in pairs(targets) do
        if not distinct[page] then distinct[page] = true; count = count + 1 end
    end
    check("links are spread across pages, not collapsed onto one", count == 5,
        "found " .. count .. " distinct target pages, wanted 5")
end
-- }}}

-- {{{ Case: page numbers are zero-padded to match the written filenames
-- The chronological writer emits %02d names (01.html, 07.html). A link of
-- "7.html" would 404 even though the page number is right.
do
    local mapping = make_mapping({ [7] = 7 }, TOTAL_PAGES)
    local html = generator.generate_flat_poem_list_html(
        make_poem(7), make_ranking({}), "similar", 7, mapping, true)
    check("single-digit page is zero-padded", html:find("chronological/07%.html") ~= nil,
        "no 07.html link found")
    check("unpadded page name is never emitted", html:find("chronological/7%.html") == nil)
end
-- }}}

-- {{{ Case: unpaginated build targets index.html
-- When the chronological view is NOT split into pages, the only file written is
-- chronological/index.html. Linking to 01.html there names a file that does not
-- exist, so the link must follow the writer's branch, not assume pagination.
do
    local mapping = make_mapping(PAGES_BY_INDEX, 1)
    local html = generator.generate_flat_poem_list_html(
        make_poem(ANCHOR_INDEX), make_ranking(NEIGHBOUR_INDICES), "similar", ANCHOR_INDEX,
        mapping, false)
    local targets = chrono_targets(html)
    check("unpaginated build links to index.html", targets["poem-3549"] == "index",
        "got " .. tostring(targets["poem-3549"]))
    check("unpaginated build emits no numbered page", html:find("chronological/%d+%.html") == nil)
end
-- }}}

-- {{{ Case: a missing mapping never guesses a page number
-- The old behaviour. With no mapping the generator cannot know the page, so it
-- must fall back to the one file that exists in both modes (index.html, which
-- is a redirect when paginated) rather than assert "01" and be wrong for
-- roughly 99% of a real corpus.
do
    local html = generator.generate_flat_poem_list_html(
        make_poem(ANCHOR_INDEX), make_ranking(NEIGHBOUR_INDICES), "similar", ANCHOR_INDEX,
        nil, true)
    check("missing mapping does not guess page 01",
        html:find("chronological/01%.html") == nil,
        "the '01' guess is back")
    check("missing mapping falls back to index.html",
        html:find("chronological/index%.html") ~= nil)
end
-- }}}

-- {{{ Case: a poem absent from the mapping falls back rather than guessing
do
    local mapping = make_mapping({ [7] = 7 }, TOTAL_PAGES)
    local html = generator.generate_flat_poem_list_html(
        make_poem(7), make_ranking({ 3549 }), "similar", 7, mapping, true)
    local targets = chrono_targets(html)
    check("mapped poem still resolves", targets["poem-7"] == "07")
    check("unmapped poem falls back to index.html", targets["poem-3549"] == "index",
        "got " .. tostring(targets["poem-3549"]))
end
-- }}}

-- {{{ Case: the mapping survives the paginated page writer
-- This is the function whose signature was missing the mapping parameter for a
-- full release, so the chain is exercised all the way to a file on disk rather
-- than stopping at the HTML-string call above.
do
    local mapping = make_mapping(PAGES_BY_INDEX, TOTAL_PAGES)
    local result = generator.generate_all_paginated_pages_for_poem(
        make_poem(ANCHOR_INDEX), make_ranking(NEIGHBOUR_INDICES), "similar", ANCHOR_INDEX,
        SCRATCH, { 1 }, mapping, true)

    check("page writer reported a generated file",
        result ~= nil and result.files_generated ~= nil and #result.files_generated > 0)

    local written = result and result.files_generated and result.files_generated[1]
    local html = written and read_file(written)
    check("generated page is readable", html ~= nil, "path: " .. tostring(written))

    if html then
        local targets = chrono_targets(html)
        check("written page aims at page 83", targets["poem-7320"] == "83",
            "got " .. tostring(targets["poem-7320"]))
        check("written page does not collapse onto page 01",
            targets["poem-3549"] == "41",
            "got " .. tostring(targets["poem-3549"]))
    end
end
-- }}}

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)

#!/usr/bin/env luajit

-- Guards what a poem's progress bar means: how far through the writing span
-- the poem was written (issue 8-045).
--
-- Why this test exists. The single-threaded page builder used to divide a
-- poem's number in the combined list by the largest number on the page.
-- Poems are numbered source by source, so a message's number says nothing
-- about when it was written: messages/260, written early, drew a nearly full
-- bar, and some bars ran past 100% and out of their frame.  Here three poems
-- are numbered in the REVERSE of their date order, so a bar built from the
-- numbers comes out backwards and fails.
--
-- Run directly:  luajit src/flat-html-generator.progress-bars.test.lua [project-dir]

local DIR = arg and arg[1] or nil

-- {{{ local function setup_path()
local function setup_path()
    local this = debug.getinfo(1, "S").source:sub(2)
    local src_dir = this:match("(.*/)") or "./"
    local project_dir = DIR or src_dir:gsub("src/$", "")
    package.path = src_dir .. "?.lua;" .. project_dir .. "libs/?.lua;" .. package.path
    return project_dir
end
-- }}}

setup_path()
local generator = require("flat-html-generator")

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
local function make_poem(index, date)
    return {
        poem_index = index,
        id = index,
        title = "Poem " .. index,
        content = "a line of text for poem " .. index,
        category = "messages",
        creation_date = date,
    }
end
-- }}}

-- {{{ local function top_bar_fills()
-- The filled length of every top progress bar on a page, in page order.  A top
-- bar is a line made only of ═ (filled) and ─ (not yet) once tags are removed;
-- bottom bars carry corner characters and are skipped.
local function top_bar_fills(html)
    local fills = {}
    for line in html:gmatch("[^\n]+") do
        local text = line:gsub("<[^>]*>", "")
        if text:match("^[═─]+$") then
            local filled = select(2, text:gsub("═", ""))
            fills[#fills + 1] = filled
        end
    end
    return fills
end
-- }}}

-- Numbered 1, 2, 3; written 2026, 2024, 2022.
local poems_data = { poems = {
    make_poem(1, "2026-01-01T00:00:00Z"),
    make_poem(2, "2024-01-01T00:00:00Z"),
    make_poem(3, "2022-01-01T00:00:00Z"),
} }

-- {{{ Case: the map orders poems by date, not by number
local mapping = generator.compute_chronological_mapping(poems_data, nil)
check("earliest-written poem (number 3) starts the timeline",
    mapping[3].timeline_progress == 0, tostring(mapping[3].timeline_progress))
check("latest-written poem (number 1) ends it",
    mapping[1].timeline_progress == 100, tostring(mapping[1].timeline_progress))
check("the 2024 poem sits halfway (by time elapsed)",
    math.abs(mapping[2].timeline_progress - 50) < 0.2, tostring(mapping[2].timeline_progress))
-- }}}

-- {{{ Case: a page's bars follow the dates
do
    local ranking = {
        { id = 2, poem = poems_data.poems[2], similarity = 0.9 },
        { id = 3, poem = poems_data.poems[3], similarity = 0.8 },
    }
    local html = generator.generate_flat_poem_list_html(
        poems_data.poems[1], ranking, "similar", 1, mapping, false)
    local fills = top_bar_fills(html)
    check("three top bars drawn (anchor + two neighbours)", #fills == 3,
        "found " .. #fills)
    check("latest poem's bar is full (83 of 83)", fills[1] == 83, tostring(fills[1]))
    check("2024 poem's bar is about half (41 of 83)", fills[2] == 41, tostring(fills[2]))
    check("earliest poem's bar is empty", fills[3] == 0, tostring(fills[3]))
end
-- }}}

-- {{{ Case: a poem with no date anywhere stops the build
do
    local undated = { poems = {
        make_poem(1, "2026-01-01T00:00:00Z"),
        { poem_index = 2, id = 2, category = "notes", content = "no date here" },
    } }
    local ok, err = pcall(generator.compute_chronological_mapping, undated, nil)
    check("an undated poem is refused, not placed at 1970", not ok, "a map was built")
    check("the refusal names the poem", tostring(err):find("poem 2 ", 1, true) ~= nil,
        tostring(err))
end
-- }}}

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)

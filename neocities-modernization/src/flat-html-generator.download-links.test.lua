#!/usr/bin/env luajit

-- Guards the download offer at the top of every similar/difference page: the
-- link must name a file that was actually written, at an address that resolves
-- from where the page lives.
--
-- Why this test exists. The offer shipped with three separate faults at once,
-- any one of which alone makes it dead:
--   1. it built the filename from the numeric poem index ("4355.txt") while the
--      writer names exports by category-prefixed id ("fediverse-4355.txt");
--   2. it prefixed the directory ("similar/...") on a page already inside
--      similar/, so browsers resolved it to similar/similar/...;
--   3. it advertised an .html archive that the shipped config never generates.
-- None of these are visible in the generated HTML unless you compare it against
-- what is on disk, which is why they survived.
--
-- Run directly:  luajit src/flat-html-generator.download-links.test.lua

-- {{{ local function setup_path()
local function setup_path()
    local this = debug.getinfo(1, "S").source:sub(2)
    local src_dir = this:match("(.*/)") or "./"
    local project_dir = src_dir:gsub("src/$", "")
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
-- category and id are the two fields the export filename is built from; they
-- are deliberately different from poem_index here, because using poem_index by
-- mistake is exactly the bug under test.
local function make_poem(poem_index, category, id)
    return {
        poem_index = poem_index,
        id = id or poem_index,
        category = category or "messages",
        title = "Poem " .. poem_index,
        content = "a line of text for poem " .. poem_index,
        filename = (category or "messages") .. "/" .. poem_index,
    }
end
-- }}}

-- {{{ local function make_ranking()
local function make_ranking(indices)
    local ranking = {}
    for _, index in ipairs(indices) do
        table.insert(ranking, { id = index, poem = make_poem(index), similarity = 0.5 })
    end
    return ranking
end
-- }}}

-- {{{ local function render()
-- Builds one similar page and returns its HTML. total_pages drives the plural.
local function render(anchor, total_pages)
    return generator.generate_paginated_poem_page_html(
        anchor, make_ranking({ 120, 3549 }), "similar", anchor.poem_index,
        1, total_pages or 1, 400, nil, false)
end
-- }}}

-- {{{ local function download_hrefs()
-- Every href that appears inside the download offer line.
local function download_hrefs(html)
    local line = html:match("Download[^\n]*")
    if not line then return {} end
    local hrefs = {}
    for href in line:gmatch('href="([^"]+)"') do table.insert(hrefs, href) end
    return hrefs
end
-- }}}

-- The anchor: poem_index 4355 but a category-prefixed export name of
-- "fediverse-0777", so a link built from the index cannot accidentally pass.
local ANCHOR = make_poem(4355, "fediverse", 777)

-- {{{ Case: the link names the file the writer actually produces
do
    local hrefs = download_hrefs(render(ANCHOR))
    check("a download link is offered", #hrefs > 0)
    check("link uses the category-prefixed export name",
        hrefs[1] == "fediverse-0777.txt",
        "got " .. tostring(hrefs[1]))
    check("link does not use the numeric poem index",
        hrefs[1] ~= "4355.txt" and hrefs[1] ~= "similar/4355.txt",
        "got " .. tostring(hrefs[1]))
end
-- }}}

-- {{{ Case: the link resolves from inside the page's own directory
-- The page lives at similar/NNNN-01.html and the export at similar/<id>.txt, so
-- they are siblings. Any directory component makes the browser look one level
-- too deep.
do
    local hrefs = download_hrefs(render(ANCHOR))
    check("link carries no directory component",
        hrefs[1] and not hrefs[1]:find("/"),
        "got " .. tostring(hrefs[1]))
    check("link is not double-nested",
        hrefs[1] ~= "similar/fediverse-0777.txt",
        "got " .. tostring(hrefs[1]))
end
-- }}}

-- {{{ Case: no link is offered for an export that is not generated
-- generate_html_archives ships off, so the .html archive does not exist. A link
-- to it is dead on arrival.
do
    local hrefs = download_hrefs(render(ANCHOR))
    local archive_offered = false
    for _, href in ipairs(hrefs) do
        if href:find("%-archive%.html$") then archive_offered = true end
    end
    check("archive link is withheld while archives are disabled",
        not archive_offered,
        "an -archive.html link was offered")
end
-- }}}

-- {{{ Case: the label counts the pages in front of the reader
do
    check("one page reads as singular",
        render(ANCHOR, 1):find("Download this page:") ~= nil)
    check("several pages read as plural",
        render(ANCHOR, 4):find("Download these pages:") ~= nil)
    check("singular wording is not used for several pages",
        render(ANCHOR, 4):find("Download this page:") == nil)
end
-- }}}

-- {{{ Case: a different anchor gets a different filename
-- Guards against the name being derived from anything page-global rather than
-- from the anchor poem.
do
    local other = make_poem(9, "notes", 12)
    local hrefs = download_hrefs(render(other))
    check("second anchor gets its own export name",
        hrefs[1] == "notes-0012.txt",
        "got " .. tostring(hrefs[1]))
end
-- }}}

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)

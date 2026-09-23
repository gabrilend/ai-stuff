#!/usr/bin/env luajit

-- Guards issue 10-025: a similar/different page shows its anchor poem once,
-- and never hides a different poem by mistake.
--
-- Why this test exists. Poems carry two numbers: poem_index, unique across
-- the whole corpus, and id, which restarts at 1 in every source (fediverse,
-- messages, notes...).  The similar list used to open with the anchor stamped
-- with its poem_index while the page's "skip the anchor" check compared ids,
-- so the anchor never matched and was printed twice.  The same check also hid
-- any poem from another source that happened to share the anchor's id.  Here
-- the anchor is messages poem_index 7 / id 7, and a neighbour from notes has
-- poem_index 12 but id 7 as well.
--
-- Run directly:  luajit src/flat-html-generator.anchor-once.test.lua [project-dir]

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
local function make_poem(index, id, category, date)
    return {
        poem_index = index, id = id, category = category,
        title = "Poem " .. index,
        content = "the words of poem " .. index,
        creation_date = date,
    }
end
-- }}}

-- {{{ local function count()
local function count(haystack, needle)
    local n, from = 0, 1
    while true do
        local s, e = haystack:find(needle, from, true)
        if not s then return n end
        n, from = n + 1, e + 1
    end
end
-- }}}

local anchor   = make_poem(7, 7, "messages", "2024-01-01T00:00:00Z")
local lookalike = make_poem(12, 7, "notes", "2025-01-01T00:00:00Z")  -- same id, other source
local other    = make_poem(20, 3, "fediverse", "2026-01-01T00:00:00Z")
local poems_data = { poems = { anchor, lookalike, other } }
local mapping = generator.compute_chronological_mapping(poems_data, nil)

-- The cache lists the anchor itself first, as a similarity cache may.
generator.use_similarity_rankings_for_tests({ rankings = { ["7"] = { 7, 12, 20 } } })

-- {{{ Case: the ranked list holds only the neighbours
local ranking = generator.generate_similarity_ranked_list(7, poems_data, nil)
check("ranked list leaves the anchor out", #ranking == 2, "length " .. #ranking)
check("ranked list keys entries by poem_index",
    ranking[1] and ranking[1].id == 12 and ranking[2] and ranking[2].id == 20,
    ranking[1] and tostring(ranking[1].id))
-- }}}

-- {{{ Case: the page shows the anchor once and keeps the lookalike
local html = generator.generate_flat_poem_list_html(anchor, ranking, "similar", 7, mapping, false)
check("anchor's words appear exactly once", count(html, "the words of poem 7") == 1,
    "found " .. count(html, "the words of poem 7"))
check("the notes poem sharing the anchor's id is still shown",
    count(html, "the words of poem 12") == 1)
check("the third poem is shown", count(html, "the words of poem 20") == 1)
-- }}}

-- {{{ Case: a hand-built list that still contains the anchor is handled too
-- (the older diversity lists, and any caller building its own list)
local with_anchor = {
    { id = 7, poem = anchor }, { id = 12, poem = lookalike }, { id = 20, poem = other },
}
local html2 = generator.generate_flat_poem_list_html(anchor, with_anchor, "similar", 7, mapping, false)
check("a list containing the anchor still prints it once",
    count(html2, "the words of poem 7") == 1, "found " .. count(html2, "the words of poem 7"))
check("... and still keeps the lookalike", count(html2, "the words of poem 12") == 1)
-- }}}

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)

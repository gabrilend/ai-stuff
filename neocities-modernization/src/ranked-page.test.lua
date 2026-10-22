-- Tests for ranked-page.lua, the similar/different page module the workers
-- use (Issue 8-058). They carry over what the old single-threaded builder's
-- tests checked -- that builder is gone, and it was never the code the site
-- was built with:
--   anchor-once      : the anchor is drawn once; a lookalike stays (10-025)
--   chronological-links: each poem links to its own chronological page (10-036)
--   download-links   : the download line names the export the worker writes (8-013)
--   page-links       : navigation links only pages that are written (10-036)
--   progress-bars    : a bar fills by place on the writing timeline (8-045)
-- Run: luajit src/ranked-page.test.lua [project-dir]

-- {{{ local function setup_path()
local function setup_path()
    local this = debug.getinfo(1, "S").source:sub(2)
    local src_dir = this:match("(.*/)") or "./"
    local project_dir = arg[1] or src_dir:gsub("src/$", "")
    package.path = project_dir .. "/src/?.lua;" .. project_dir .. "/libs/?.lua;" .. package.path
end
-- }}}

setup_path()
local entry = require("poem-entry")
entry.configure({
    palette = { gray = "#787878", blue = "#3c78dc", yellow = "#c8b428" },
    boost_palette = { arrow = "#dc3c3c", outer_frame = "#3c78dc", inner_box = "#2aa198", content_text = "#c8b428" },
    text_width = 80,
})
local R = require("ranked-page")

local passed, failed = 0, 0
-- {{{ local function check()
local function check(name, cond, detail)
    if cond then
        passed = passed + 1
        print("  ok   " .. name)
    else
        failed = failed + 1
        print("  FAIL " .. name .. (detail and ("  -- " .. detail) or ""))
    end
end
-- }}}

-- {{{ fixtures: six poems, two sharing a per-source id
local poems = {
    { poem_index = 7, id = 7, category = "fediverse", content = "the anchor poem speaks" },
    { poem_index = 8, id = 7, category = "notes", content = "a lookalike with the anchor's id",
        metadata = { source_file = "lookalike" } },
    { poem_index = 9, id = 2, category = "messages", content = "a message" },
    { poem_index = 10, id = 3, category = "messages", content = "another message" },
    { poem_index = 11, id = 4, category = "messages", content = "a third message" },
    { poem_index = 12, id = 5, category = "messages", content = "the last message" },
}
local by_index = {}
for _, p in ipairs(poems) do by_index[p.poem_index] = p end
local function ctx(paged)
    return {
        colors = { [7] = { color = "blue" } },
        chrono_map = {
            [7] = { page_number = 2, total_pages = 90, timeline_progress = 100 },
            [8] = { page_number = 41, total_pages = 90, timeline_progress = 50 },
            [9] = { page_number = 83, total_pages = 90, timeline_progress = 0 },
            [10] = { page_number = 90, total_pages = 90, timeline_progress = 10 },
            [11] = { page_number = 1, total_pages = 90, timeline_progress = 20 },
            [12] = { page_number = 5, total_pages = 90, timeline_progress = 30 },
        },
        chrono_paged = paged,
        poems_per_page = 2,
        head_block = "<!-- head -->",
    }
end
local anchor = by_index[7]
-- }}}

-- {{{ anchor once (10-025)
do
    local list = R.ranked_list({ 7, 8, 9, 10, 11, 12 }, 7, by_index)
    check("the ranked list leaves the anchor out", #list == 5 and list[1].poem.poem_index == 8)
    check("the lookalike sharing the anchor's id stays", list[1].poem.category == "notes")
    local html = R.page_html(anchor, list, "similar", 1, 3, false, ctx(true))
    local _, n = html:gsub("the anchor poem speaks", "")
    check("the anchor's words appear exactly once", n == 1, tostring(n))
    check("an unknown number in a ranking is an error",
        not pcall(R.ranked_list, { 7, 99 }, 7, by_index))
end
-- }}}

-- {{{ chronological links (10-036)
do
    local list = R.ranked_list({ 7, 8, 9, 10 }, 7, by_index)
    local html = R.page_html(anchor, list, "similar", 1, 2, false, ctx(true))
    check("the anchor links to its own chronological page", html:find("chronological/02.html#poem-7", 1, true) ~= nil)
    check("a neighbour on page 41 links to 41", html:find("chronological/41.html#poem-8", 1, true) ~= nil)
    check("a neighbour on page 83 links to 83", html:find("chronological/83.html#poem-9", 1, true) ~= nil)
    check("a single-digit page is zero-padded", not html:find("chronological/2.html", 1, true))
    local flat = R.page_html(anchor, list, "similar", 1, 2, false, ctx(false))
    check("an unpaginated view links to index.html",
        flat:find("chronological/index.html#poem-7", 1, true) ~= nil and not flat:find("chronological/02.html", 1, true))
    local missing = ctx(true)
    missing.chrono_map[8] = nil
    local ok, err = pcall(R.page_html, anchor, list, "similar", 1, 2, false, missing)
    check("a poem missing from the chronological map stops the page", not ok)
    check("the error names the poem", tostring(err):find("poem 8", 1, true) ~= nil, tostring(err))
end
-- }}}

-- {{{ download line and text export (8-013)
do
    local list = R.ranked_list({ 7, 8, 9, 10, 11, 12 }, 7, by_index)
    local with = R.page_html(anchor, list, "different", 1, 3, { file = "0007.txt", count = 5 }, ctx(true))
    check("the download line names the export file",
        with:find("download this list as text: <a href='0007.txt'>0007.txt</a> (5 poems)", 1, true) ~= nil)
    local without = R.page_html(anchor, list, "different", 1, 3, false, ctx(true))
    check("no export, no download line", not without:find("download", 1, true))
    local text = R.text_export(anchor, list, "different", 5, ctx(true))
    check("the export holds no HTML", not text:find("<%a") and not text:find("</%a"))
    check("the export holds every poem the pages hold", select(2, text:gsub("%-%-%- #%d+ ", "")) == 5)
    check("the export has no navigation boxes", not text:find("similar", 1, true))
end
-- }}}

-- {{{ page navigation and the plan (10-036)
do
    local list = R.ranked_list({ 7, 8, 9, 10, 11, 12 }, 7, by_index)   -- 5 poems, 2 per page
    local pages, count, total = R.plan(list, { 1 }, 2, 15)
    check("page 1 only: one page, two poems, one page of navigation", #pages == 1 and count == 2 and total == 1)
    local one = R.page_html(anchor, list, "similar", 1, total, false, ctx(true))
    check("page 1 only: no Next link", not one:find("Next", 1, true))
    pages, count, total = R.plan(list, "all", 2, 15)
    check("all pages: three pages hold all five poems", #pages == 3 and count == 5 and total == 3)
    local two = R.page_html(anchor, list, "similar", 2, total, false, ctx(true))
    check("page 2 links back to 1 and on to 3",
        two:find("<a href='0007-01.html'>‹ Prev</a>", 1, true) ~= nil and two:find("<a href='0007-03.html'>Next ›</a>", 1, true) ~= nil)
    pages, count, total = R.plan(list, { 1, 2, 3, 4 }, 2, 15)
    check("a requested page past the end is not counted", total == 3)
    check("a page past the end is not drawn", R.page_html(anchor, list, "similar", 4, total, false, ctx(true)) == nil)
    pages = R.plan(list, "all", 2, 2)
    check("\"all\" stops at the storage cap", #pages == 2)
end
-- }}}

-- {{{ progress bars by the writing timeline (8-045)
do
    local function filled(html, needle)
        -- the line holding the poem's text, then the bar above it
        local lines = {}
        for line in (html .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
        for i, line in ipairs(lines) do
            if line:find(needle, 1, true) then
                -- filled columns are ═, empty ones ─ (counted whole: a Lua
                -- pattern's + would repeat only the last byte of ═)
                local _, n = lines[i - 1]:gsub("═", "")
                return n
            end
        end
    end
    local list = R.ranked_list({ 7, 8, 9 }, 7, by_index)
    local html = R.page_html(anchor, list, "similar", 1, 1, false, ctx(true))
    check("the latest poem's bar is full (83 of 83)", filled(html, "the anchor poem speaks") == 83)
    check("a poem halfway through the timeline is about half (41 of 83)", filled(html, "a lookalike") == 41)
    check("the earliest poem's bar is empty", filled(html, "a message") == 0)
end
-- }}}

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)

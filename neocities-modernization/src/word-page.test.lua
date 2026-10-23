#!/usr/bin/env luajit

-- Tests for the word pages as worker jobs (Issue 10-035): the page module
-- (src/word-page.lua) and the "word_page" job of the page-worker pool. The
-- poems are made up and travel in the jobs, so the test needs no build.
--
-- Run directly:  luajit src/word-page.test.lua [project-dir]

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
-- The model whose poem colours the workers read (config.lua names no
-- default model, owner 2026-10-21).
require("inference-server-config").set_selected_server("local")
require("inference-server-config").set_selected_model("embeddinggemma-2")
local word_page = require("word-page")

local SCRATCH = "/tmp/neocities-modernization/tmp/word-page-test"

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

-- {{{ fixtures
local function poem(index, category, id, content)
    -- source_key as the extractor gives it (Issue 8-019)
    return { poem_index = index, id = id, category = category, content = content,
        source_key = category .. "-" .. id }
end
local poems = {
    poem(3, "fediverse", 3, "the first poem, 100% sure of itself"),
    poem(4, "messages", 9, "a second poem with *emphasis*"),
    poem(5, "notes", 1, "a note"),
}
poems[3].metadata = { source_file = "reddit-comments/a-note" }
-- }}}

-- {{{ the page module
do
    check("a file name is the word in lower case, letters and digits only",
        word_page.file_name("Don't") == "dont.html", word_page.file_name("Don't"))
    local e = word_page.entry(poems[1], "blue", 50, "03.html")
    check("an entry starts with its file line", e:find("^ %-> file: fediverse/3\n") ~= nil, e:sub(1, 40))
    check("an entry links to its chronological page and anchor",
        e:find("../chronological/03.html#fediverse-3", 1, true) ~= nil)
    check("an entry links to its similar and different pages",
        e:find("../similar/fediverse-3-01.html", 1, true) ~= nil and e:find("../different/fediverse-3-01.html", 1, true) ~= nil)
    local page = word_page.page_html("love", "#dc3c3c", "../chronological/02.html#poem-4", 1, e .. "\n")
    check("the page heading names the word in its colour",
        page:find('<font color="#dc3c3c">love</font>', 1, true) ~= nil)
    check("the page links to the centre poem", page:find('href="../chronological/02.html#poem-4"', 1, true) ~= nil)
    check("a percent sign in a poem survives the page frame", page:find("100% sure", 1, true) ~= nil)
end
-- }}}

-- {{{ the worker job
do
    os.execute('rm -rf "' .. SCRATCH .. '"')
    local jobs = {
        { word = "first", header_color = "#3c78dc", centre_link = "../chronological/01.html#poem-3",
          entries = {
            { poem = poems[1], progress_pct = 10, chrono_file = "01.html" },
            { poem = poems[2], progress_pct = 60, chrono_file = "01.html" },
          } },
        { word = "Second", header_color = "#3cb45a", centre_link = "../chronological/01.html#poem-5",
          entries = { { poem = poems[3], progress_pct = 90, chrono_file = "01.html" } } },
    }
    local written = generator.generate_word_pages_on_workers(jobs, SCRATCH, 2)
    check("two jobs on two workers write two pages", written == 2, tostring(written))
    local first = read_file(SCRATCH .. "/wordcloud/first.html")
    local second = read_file(SCRATCH .. "/wordcloud/second.html")
    check("each page is written under wordcloud/ by its word", first ~= nil and second ~= nil)
    if first then
        local a = first:find("fediverse/3", 1, true)
        local b = first:find("messages/9", 1, true)
        check("the poems keep the order the job gives", a and b and a < b)
        check("the page names how many poems it holds", first:find("The 2 poems closest", 1, true) ~= nil)
    end
    if second then
        check("a note shows its path in the notes folder",
            second:find("notes/reddit-comments/a-note", 1, true) ~= nil)
    end
    check("no thread count is an error", not pcall(generator.generate_word_pages_on_workers, jobs, SCRATCH, nil))
    os.execute('rm -rf "' .. SCRATCH .. '"')
end
-- }}}

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)

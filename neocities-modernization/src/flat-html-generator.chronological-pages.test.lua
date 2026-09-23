#!/usr/bin/env luajit

-- Builds real chronological pages from a few made-up poems, paginated and
-- not, and checks they come out whole.
--
-- Why this test exists. The shared page head's stylesheet says "100%;", and
-- string.format reads "%;" as a broken placeholder.  The paginated
-- chronological template is formatted twice -- once for page numbers and the
-- head, again for the poems -- and the head went in plain, so the second pass
-- crashed stage 9 of a full overnight build (2026-09-23), after hours of
-- earlier stages.  No test built these pages, so nothing caught it first.
--
-- Run directly:  luajit src/flat-html-generator.chronological-pages.test.lua [project-dir]

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

local SCRATCH = "/tmp/neocities-modernization/tmp/chronological-pages-test"

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

-- Five poems, one of them containing a percent sign of its own.
local poems = {}
for i = 1, 5 do
    poems[i] = {
        poem_index = i, id = i, category = "notes",
        title = "Poem " .. i,
        content = (i == 3) and "one hundred % sure" or ("words of poem " .. i),
        creation_date = string.format("2024-01-%02dT00:00:00Z", i),
    }
end
local poems_data = { poems = poems }

-- {{{ Case: paginated -- two poems per page, three pages
do
    os.execute('rm -rf "' .. SCRATCH .. '"')
    os.execute('mkdir -p "' .. SCRATCH .. '"')
    local ok, err = pcall(generator.generate_chronological_index_with_navigation,
        poems_data, SCRATCH, 2)
    check("paginated pages build without error", ok, tostring(err))
    local page1 = read_file(SCRATCH .. "/chronological/01.html")
    local page3 = read_file(SCRATCH .. "/chronological/03.html")
    check("page 1 and page 3 were written", page1 ~= nil and page3 ~= nil)
    if page1 then
        check("the stylesheet's 100% reaches the page as one %",
            page1:find("text-size-adjust: 100%;", 1, true) ~= nil
            and page1:find("100%%;", 1, true) == nil)
        check("page 1 carries its poems", page1:find("words of poem 1", 1, true) ~= nil)
    end
    local page2 = read_file(SCRATCH .. "/chronological/02.html")
    check("a poem's own % survives both passes",
        page2 ~= nil and page2:find("one hundred % sure", 1, true) ~= nil)
end
-- }}}

-- {{{ Case: unpaginated -- everything on one page
do
    os.execute('rm -rf "' .. SCRATCH .. '"')
    os.execute('mkdir -p "' .. SCRATCH .. '"')
    local ok, err = pcall(generator.generate_chronological_index_with_navigation,
        poems_data, SCRATCH, nil)
    check("single-page build runs without error", ok, tostring(err))
end
-- }}}

os.execute('rm -rf "' .. SCRATCH .. '"')
print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)

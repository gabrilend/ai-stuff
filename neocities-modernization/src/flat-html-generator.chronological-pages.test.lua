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
-- Run directly:  luajit src/flat-html-generator.chronological-pages.test.lua [--dir PATH]

-- The project folder from --dir PATH, or nil when it was not given (the
-- default below is then used); a stray word on the command line stops the
-- program, named (libs/project-dir.lua, Issue 10-076).
local PROJECT_DIR_ARG = (function()
    local own = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./"
    local dir = dofile(own .. "../libs/project-dir.lua").read(arg, "")
    if dir == "" then return nil end
    return dir
end)()

local DIR = PROJECT_DIR_ARG or nil

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
-- The model whose colours and caches these pages are drawn with. Named
-- here because config.lua names no default model (owner, 2026-10-21); a
-- test that drew with "whatever the default is" tested nobody's choice.
-- config.lua testing names the model and server the checks use
local testing = require("config-loader").load().testing
require("inference-server-config").set_selected_server(testing.server)
require("inference-server-config").set_selected_model(testing.model)

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
        poem_index = i, id = i, category = "notes", source_key = "notes-" .. i,
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
        poems_data, SCRATCH, 2, 1)
    check("paginated pages build without error", ok, tostring(err))
    local page1 = read_file(SCRATCH .. "/chronological/01.html")
    local page3 = read_file(SCRATCH .. "/chronological/03.html")
    check("page 1 and page 3 were written", page1 ~= nil and page3 ~= nil)
    if page1 then
        check("the stylesheet's 100% reaches the page as one %",
            page1:find("text-size-adjust: 100%;", 1, true) ~= nil
            and page1:find("100%%;", 1, true) == nil)
        check("page 1 carries its poems", page1:find("words of poem 1", 1, true) ~= nil)
        -- Issue 8-019: a poem is found on its page by its source key
        check("each poem is anchored by its source key", page1:find('<span id="notes-1">', 1, true) ~= nil)
        check("no anchor is named by number", not page1:find('id="poem%-'))
    end
    local page2 = read_file(SCRATCH .. "/chronological/02.html")
    check("a poem's own % survives both passes",
        page2 ~= nil and page2:find("one hundred % sure", 1, true) ~= nil)
end
-- }}}

-- {{{ Case: a golden poem's frame is the shared design
-- Chronological pages used to draw golden poems with their own older copy of
-- the frame: a single-line "similar" box (╟─┐ │) with ╧ under it, while every
-- other page drew the shared double-line box (╠═╗ ║) with ╩. The owner chose
-- the shared design (2026-10-07) and the chronological pages now draw through
-- src/poem-bars.lua. This pins it: if a private copy creeps back, it fails here.
do
    os.execute('rm -rf "' .. SCRATCH .. '"')
    os.execute('mkdir -p "' .. SCRATCH .. '"')
    local golden_poems = {}
    for i = 1, 3 do
        golden_poems[i] = {
            poem_index = i, id = i, category = "notes", source_key = "notes-" .. i,
            title = "Poem " .. i,
            content = "a golden poem, number " .. i,
            creation_date = string.format("2024-02-%02dT00:00:00Z", i),
            metadata = { is_golden_poem = (i == 3) },
        }
    end
    local ok, err = pcall(generator.generate_chronological_index_with_navigation,
        { poems = golden_poems }, SCRATCH, 2, 1)
    check("a page with a golden poem builds", ok, tostring(err))
    -- Two per page puts the golden poem (third) on page 2. (Had everything
    -- fit on one page, the build writes chronological/index.html instead.)
    local page = read_file(SCRATCH .. "/chronological/02.html") or ""
    local plain = page:gsub("<[^>]+>", "")
    -- The last poem is the furthest through the timeline, so its bar has
    -- filled past the "similar" box: the shared drawer's double-line form.
    check("golden box top is the shared double-line form (╠ … ╗)",
        plain:find("╠═════════╗", 1, true) ~= nil, "no ╠═════════╗ on the page")
    check("golden nav line walls the similar box with ║ on both sides",
        plain:find("║ similar ║", 1, true) ~= nil, "no ║ similar ║ on the page")
    check("golden bottom joins the similar box with ╩",
        plain:find("╚═════════╩", 1, true) ~= nil, "no ╚═════════╩ on the page")
    check("the old private shape is gone (╟ … ┐, │ similar, ╧ joint)",
        plain:find("╟─────────┐", 1, true) == nil
            and plain:find("╚═════════╧", 1, true) == nil)
end
-- }}}

-- {{{ Case: unpaginated -- everything on one page
do
    os.execute('rm -rf "' .. SCRATCH .. '"')
    os.execute('mkdir -p "' .. SCRATCH .. '"')
    local ok, err = pcall(generator.generate_chronological_index_with_navigation,
        poems_data, SCRATCH, nil, 1)
    check("single-page build runs without error", ok, tostring(err))
end
-- }}}

os.execute('rm -rf "' .. SCRATCH .. '"')
print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)

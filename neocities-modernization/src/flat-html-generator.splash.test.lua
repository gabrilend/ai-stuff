#!/usr/bin/env luajit

-- Guards issue 11-006: the splash page in front of the word cloud.
--
-- What it pins. The splash is built from its editable template with the live
-- numbers filled in, is written where config.lua says (the site folder's own
-- index.html), leads on to the word cloud, is built by the same call that
-- builds the explore pages, and refuses a bad configuration instead of writing
-- somewhere unexpected.
--
-- It copies page-templates/ into input/pages/ the way run.sh does
-- (scripts/sync-page-templates; input/ is ignored by git) and writes pages to a
-- scratch folder.
--
-- Run directly:  luajit src/flat-html-generator.splash.test.lua [project-dir]

local DIR = arg and arg[1] or nil

-- {{{ local function setup_path()
local function setup_path()
    local this = debug.getinfo(1, "S").source:sub(2)
    local src_dir = this:match("(.*/)") or "./"
    local project_dir = DIR or src_dir:gsub("src/$", "")
    if project_dir == "" then project_dir = "./" end
    package.path = src_dir .. "?.lua;" .. project_dir .. "libs/?.lua;" .. package.path
    return project_dir
end
-- }}}

local PROJECT = setup_path()
local generator = require("flat-html-generator")

local SCRATCH = "/tmp/neocities-modernization/tmp/splash-test"

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

-- {{{ local function fresh_scratch()
local function fresh_scratch()
    os.execute('rm -rf "' .. SCRATCH .. '"')
    os.execute('mkdir -p "' .. SCRATCH .. '"')
end
-- }}}

local poems_data = { poems = {
    { poem_index = 1, id = 1, category = "notes", content = "first", creation_date = "2019-03-01T10:00:00Z" },
    { poem_index = 2, id = 2, category = "fediverse", content = "second", creation_date = "2021-06-01T10:00:00Z" },
    { poem_index = 3, id = 3, category = "notes", content = "third", creation_date = "2024-12-31T10:00:00Z" },
} }

local synced = os.execute('"' .. PROJECT .. 'scripts/sync-page-templates" "' .. PROJECT .. '" >/dev/null')
check("the page templates are synced into input/pages (the splash template included)",
    (synced == 0 or synced == true) and read_file(PROJECT .. "input/pages/wordcloud-splash.txt") ~= nil)

-- {{{ Case: the shipped configuration
do
    local cfg = dofile(PROJECT .. "config.lua").word_cloud.splash
    check("config.lua has a splash section, switched on", type(cfg) == "table" and cfg.enabled == true)
    check("it is written to the site folder's own address", cfg and cfg.output_file == "index.html")

    fresh_scratch()
    local ok, path = pcall(generator.generate_splash_page, SCRATCH, poems_data)
    check("the splash builds from config.lua", ok and path == SCRATCH .. "/index.html", tostring(path))
    local page = read_file(SCRATCH .. "/index.html") or ""
    check("it leads on to the word cloud", page:find('<a href="wordcloud.html">', 1, true) ~= nil)
    check("the live numbers are filled in", page:find("3 poems, written from 2019 to 2024", 1, true) ~= nil)
    check("no marker is left unfilled", not page:find("{%u[%u_]*}"))
    check("it is titled with the site's name", page:find("<title>Similar Different</title>", 1, true) ~= nil)
    check("it sits on the site's black background", page:find('bgcolor="#000000"', 1, true) ~= nil)
    check("the word cloud itself is not touched", read_file(SCRATCH .. "/wordcloud.html") == nil)
end
-- }}}

-- {{{ Case: built with the explore pages
do
    fresh_scratch()
    local ok, err = pcall(generator.generate_simple_discovery_instructions, SCRATCH, poems_data)
    check("the explore-family call builds without error", ok, tostring(err))
    check("and writes the splash beside explore.html",
        read_file(SCRATCH .. "/index.html") ~= nil and read_file(SCRATCH .. "/explore.html") ~= nil)
end
-- }}}

-- {{{ Case: no dated poems
do
    fresh_scratch()
    local ok, err = pcall(generator.generate_splash_page, SCRATCH, nil)
    check("the splash builds without a poem list", ok, tostring(err))
    local page = read_file(SCRATCH .. "/index.html") or ""
    check("and drops the line it has no numbers for", not page:find("written from", 1, true)
        and page:find("wordcloud.html", 1, true) ~= nil)
end
-- }}}

-- {{{ Case: configuration it refuses, and switching it off
do
    local function cfg(fields)
        local c = { enabled = true, output_file = "index.html", template = "wordcloud-splash.txt" }
        for k, v in pairs(fields) do c[k] = v end
        return c
    end
    fresh_scratch()
    check("a path for the output is refused",
        not pcall(generator.generate_splash_page, SCRATCH, poems_data, cfg({ output_file = "../index.html" })))
    check("writing over the word cloud is refused",
        not pcall(generator.generate_splash_page, SCRATCH, poems_data, cfg({ output_file = "wordcloud.html" })))
    check("a missing template is refused",
        not pcall(generator.generate_splash_page, SCRATCH, poems_data, cfg({ template = "no-such-page.txt" })))
    check("a missing section is refused",
        not pcall(generator.generate_splash_page, SCRATCH, poems_data, false))

    local ok, path = pcall(generator.generate_splash_page, SCRATCH, poems_data, cfg({ enabled = false }))
    check("switched off, it writes nothing", ok and path == nil and read_file(SCRATCH .. "/index.html") == nil)

    ok, path = pcall(generator.generate_splash_page, SCRATCH, poems_data, cfg({ output_file = "welcome.html" }))
    check("another plain file name is honoured", ok and read_file(SCRATCH .. "/welcome.html") ~= nil)
end
-- }}}

os.execute('rm -rf "' .. SCRATCH .. '"')
print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)

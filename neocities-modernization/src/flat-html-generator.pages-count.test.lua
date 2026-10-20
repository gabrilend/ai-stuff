#!/usr/bin/env luajit

-- Pins what a --pages value means to the page writer (stage 9).
--
-- Why this test exists. "--pages 3" is a COUNT everywhere else: run.sh's help
-- says "pages generated per poem", and stages 7 and 8 build caches deep enough
-- for three pages. The page writer alone read it as "only page number 3", so
-- a full build wrote nothing but NNNN-03.html for every poem while every link
-- on the site pointed at NNNN-01.html -- 1,341,208 broken links in one run.
--
-- Run directly:  luajit src/flat-html-generator.pages-count.test.lua [project-dir]

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
local parse = generator.parse_pages_specification

local passed, failed = 0, 0

-- {{{ local function check
local function check(name, ok, detail)
    if ok then
        passed = passed + 1
        print("  ok   " .. name)
    else
        failed = failed + 1
        print("  FAIL " .. name .. (detail and ("  -- " .. detail) or ""))
    end
end
-- }}}

-- {{{ local function list
local function list(t)
    return t and table.concat(t, ",") or "nil"
end
-- }}}

local three = parse("3")
check("\"3\" writes pages 1, 2 and 3", list(three.pages) == "1,2,3", list(three.pages))
check("\"1\" writes page 1", list(parse("1").pages) == "1", list(parse("1").pages))
check("\"all\" asks for every page", parse("all").is_all == true)
check("\"0\" is refused", not pcall(parse, "0"))
check("\"2.5\" is refused", not pcall(parse, "2.5"))
-- Ranges were removed 2026-10-07 (owner: never needed); one is now refused
-- rather than read as some set of pages.
check("a range \"2-5\" is refused", not pcall(parse, "2-5"))

print("")
print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)

#!/usr/bin/env lua

-- Tests for page-head: the one module that decides what goes in every
-- generated page's <head>.  Run directly:  luajit src/page-head.test.lua
-- Each case pins a tag some phone depends on, because a missing tag fails
-- silently -- the page still loads, it just renders wrong on one device.

-- {{{ setup_path()
local function setup_path()
    local this = debug.getinfo(1, "S").source:sub(2)
    local dir = this:match("(.*/)") or "./"
    package.path = dir .. "?.lua;" .. package.path
    return dir
end
-- }}}

setup_path()
local page_head = require("page-head")

local passed, failed = 0, 0

-- {{{ check()
local function check(name, cond)
    if cond then
        passed = passed + 1
        print("  ok   " .. name)
    else
        failed = failed + 1
        print("  FAIL " .. name)
    end
end
-- }}}

local metas = page_head.viewport_meta()
check("viewport tag present",
    metas:find('<meta name="viewport" content="width=device-width, initial-scale=1">', 1, true) ~= nil)
-- Issue 11-009: forced dark mode on phones repaints pages it thinks are light.
check("colour-scheme dark tag present (11-009)",
    metas:find('<meta name="color-scheme" content="dark">', 1, true) ~= nil)

local head = page_head.head({ title = "t", base_path = ".." })
check("full head carries the colour-scheme tag",
    head:find('name="color-scheme" content="dark"', 1, true) ~= nil)
check("stylesheet declares color-scheme: dark too",
    head:find("color-scheme: dark", 1, true) ~= nil)
check("full head carries the viewport tag",
    head:find('name="viewport"', 1, true) ~= nil)

local ok = pcall(page_head.head, { title = "t" })
check("head refuses a missing base_path", not ok)

print(string.format("passed %d, failed %d", passed, failed))
os.exit(failed == 0 and 0 or 1)

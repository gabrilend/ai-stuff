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

-- Issue 11-009: every page's <body> is built from the one site theme.
local theme = { background = "#000000", text = "#FFFFFF", link = "#6699FF", vlink = "#9966FF" }
check("body tag carries the theme in bgcolor/text/link/vlink order (11-009)",
    page_head.body_tag(theme) == '<body bgcolor="#000000" text="#FFFFFF" link="#6699FF" vlink="#9966FF">')
check("body tag refuses a missing theme", not pcall(page_head.body_tag, nil))
check("body tag refuses a theme with no background",
    not pcall(page_head.body_tag, { text = "#FFFFFF", link = "#6699FF", vlink = "#9966FF" }))
check("body tag refuses a colour that is not #RRGGBB",
    not pcall(page_head.body_tag, { background = "black", text = "#FFFFFF", link = "#6699FF", vlink = "#9966FF" }))
check("body tag refuses a colour carrying a %",
    not pcall(page_head.body_tag, { background = "#00%000", text = "#FFFFFF", link = "#6699FF", vlink = "#9966FF" }))

-- The shipped config is the theme every generator passes in: it must be
-- accepted, and its background must be the OLED-unlit pure black.
local project_dir = (debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./") .. "../"
local config = dofile(project_dir .. "config.lua")
local shipped_ok, shipped_tag = pcall(page_head.body_tag, config.html_theme)
check("config.lua's html_theme builds a body tag", shipped_ok)
check("config.lua's background is pure black (11-009)",
    shipped_ok and shipped_tag:find('bgcolor="#000000"', 1, true) ~= nil)

print(string.format("passed %d, failed %d", passed, failed))
os.exit(failed == 0 and 0 or 1)

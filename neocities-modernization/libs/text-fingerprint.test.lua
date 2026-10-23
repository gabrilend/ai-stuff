#!/usr/bin/env luajit

-- Tests for libs/text-fingerprint.lua (Issue 8-019): the same text gives the
-- same code, a one-letter change gives another, and the codes match the
-- published FNV-1a 64-bit values, so another program could check them.
--
-- Run directly:  luajit libs/text-fingerprint.test.lua [project-dir]

-- {{{ local function setup_path()
local function setup_path()
    local this = debug.getinfo(1, "S").source:sub(2)
    local libs_dir = this:match("(.*/)") or "./"
    package.path = libs_dir .. "?.lua;" .. package.path
end
-- }}}

setup_path()
local fp = require("text-fingerprint")

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

-- published FNV-1a 64 values
check("the empty text is FNV-1a 64's starting value", fp.of("") == "cbf29ce484222325", fp.of(""))
check('"a" matches the published value', fp.of("a") == "af63dc4c8601ec8c", fp.of("a"))
check('"foobar" matches the published value', fp.of("foobar") == "85944171f73967e8", fp.of("foobar"))
-- behaviour
local poem = "the anchor poem speaks\nand the lookalike answers"
check("the same text gives the same code", fp.of(poem) == fp.of(poem .. ""))
check("one letter changed gives another code", fp.of(poem) ~= fp.of(poem:gsub("speaks", "speaky")))
check("a code is 16 hex digits", fp.of(poem):match("^%x+$") and #fp.of(poem) == 16)
check("bytes beyond ASCII are folded in", fp.of("café") ~= fp.of("cafe"))
check("a non-string is an error", not pcall(fp.of, 42))

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)

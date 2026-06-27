#!/usr/bin/env lua

-- Tests for page-template: the marker substitution engine behind the editable
-- explore-page copy (Issue 11-005). Run directly:  luajit src/page-template.test.lua
-- Every behavior the explore generators rely on has a case here, because the
-- whole point of the module is that a typo'd marker fails loudly instead of
-- shipping broken text to the live site.

-- {{{ setup_path()
-- Resolve the module relative to this test file so it runs from any directory.
local function setup_path()
    local this = debug.getinfo(1, "S").source:sub(2)
    local dir = this:match("(.*/)") or "./"
    package.path = dir .. "?.lua;" .. package.path
    return dir
end
-- }}}

local DIR = setup_path()
local tmpl = require("page-template")

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

-- Plain scalar substitution, strings and numbers both stringified.
do
    local out = tmpl.substitute("{A} poems across {B} sources", { A = 42, B = "three" })
    check("scalars fill in", out == "42 poems across three sources")
end

-- Lowercase braces are not markers and must survive untouched.
do
    local out = tmpl.substitute("keep {this} literal {NAME}", { NAME = "ok" })
    check("lowercase braces untouched", out == "keep {this} literal ok")
end

-- An unknown marker is an error, and the message names it (the core promise).
do
    local out, err = tmpl.substitute("hello {MISSING}", {})
    check("missing marker -> nil", out == nil)
    check("missing marker named in error", err ~= nil and err:find("MISSING", 1, true) ~= nil)
end

-- Every missing marker is reported at once, not one rebuild at a time.
do
    local _, err = tmpl.substitute("{ONE} {TWO}", {})
    check("all missing markers reported", err:find("ONE", 1, true) and err:find("TWO", 1, true))
end

-- OMIT drops the whole line that mentions it, leaving no blank gap.
do
    local t = "line one\n{GONE} should vanish\nline three"
    local out = tmpl.substitute(t, { GONE = tmpl.OMIT })
    check("OMIT drops the line", out == "line one\nline three")
end

-- A surviving (kept) line with a real value is unaffected by OMIT elsewhere.
do
    local t = "{KEEP} stays\n{DROP} goes"
    local out = tmpl.substitute(t, { KEEP = "X", DROP = tmpl.OMIT })
    check("OMIT is per-line", out == "X stays")
end

-- Percent signs in a value must not be treated as gsub specials.
do
    local out = tmpl.substitute("rate {R}", { R = "50% done %s" })
    check("percent signs are literal", out == "rate 50% done %s")
end

-- A multi-line block value (the way the source list / bar charts are injected).
do
    local block = "  a\n  b\n  c"
    local out = tmpl.substitute("head:\n{BLOCK}\ntail", { BLOCK = block })
    check("block value spans lines", out == "head:\n  a\n  b\n  c\ntail")
end

-- Trailing-newline structure is preserved through the OMIT split/rejoin.
do
    local out = tmpl.substitute("a\nb\n", { })
    check("trailing newline preserved", out == "a\nb\n")
end

-- Wrong argument types are caught at the door.
do
    local out, err = tmpl.substitute(nil, {})
    check("non-string template -> error", out == nil and err ~= nil)
end

-- render_file: a missing file is a clear error, not a crash.
do
    local out, err = tmpl.render_file(DIR .. "no-such-template.txt", {})
    check("missing file -> error", out == nil and err ~= nil and err:find("could not open", 1, true))
end

print(string.format("\npage-template: %d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)

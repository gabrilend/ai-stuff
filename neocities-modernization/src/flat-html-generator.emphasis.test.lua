#!/usr/bin/env luajit

-- Guards where the markdown delimiters land relative to the tag they open.
--
-- Issue 4-003 settled that a poem shows BOTH the styling and the marks the
-- author typed: *love* renders as *love*, italic, asterisks still there. It put
-- the delimiters INSIDE the tag, so the asterisks came out slanted too. They
-- belong outside: the emphasis is on the word, and the asterisks are the
-- author pointing at it, not part of what is being pointed at.
--
-- The second half of this file is the reason the first half matters. Those tags
-- travel with the line into the wrapper, and for as long as the wrapper counted
-- bytes, every emphasized line lost budget to markup nobody can see. The
-- end-to-end case below is the poem that exposed it.
--
-- Run directly:  luajit src/flat-html-generator.emphasis.test.lua

-- {{{ local function setup_path()
local function setup_path()
    local this = debug.getinfo(1, "S").source:sub(2)
    local src_dir = this:match("(.*/)") or "./"
    local project_dir = src_dir:gsub("src/$", "")
    package.path = src_dir .. "?.lua;" .. project_dir .. "libs/?.lua;" .. package.path
    return project_dir
end
-- }}}

setup_path()
local generator = require("flat-html-generator")
local tf = require("text-formatter")

local passed, failed = 0, 0

-- {{{ local function check()
local function check(name, condition, detail)
    if condition then
        passed = passed + 1
        print("  ok   " .. name)
    else
        failed = failed + 1
        print("FAIL   " .. name)
        if detail then print("         " .. detail) end
    end
end
-- }}}

-- {{{ local function rendered()
-- Run one snippet through the markdown pass and turn the sentinels back into
-- the asterisks they stand for, which is what the page finally carries.
local function rendered(src)
    return (generator.apply_markdown_formatting(src):gsub("\1", "*"))
end
-- }}}

print("markdown delimiter placement tests")

-- {{{ delimiters sit outside the tag
check("italics: asterisks outside the em",
    rendered("a *want* word") == "a *<em>want</em>* word",
    rendered("a *want* word"))

check("single-character italics",
    rendered("a *x* word") == "a *<em>x</em>* word",
    rendered("a *x* word"))

check("bold: both asterisks outside the strong",
    rendered("a **loud** word") == "a **<strong>loud</strong>** word",
    rendered("a **loud** word"))

check("strikethrough: tildes stay unstruck",
    rendered("a ~~gone~~ word") == "a ~~<del>gone</del>~~ word",
    rendered("a ~~gone~~ word"))

check("inline code: backticks outside the code span",
    rendered("a `call` word") == "a `<code>call</code>` word",
    rendered("a `call` word"))
-- }}}

-- {{{ things that are not emphasis stay untouched
check("arithmetic asterisks are not emphasis",
    rendered("2 * 3 * 4") == "2 * 3 * 4",
    rendered("2 * 3 * 4"))

check("a bold span is not re-read as two italics",
    not rendered("a **loud** word"):find("<em>"),
    rendered("a **loud** word"))
-- }}}

-- {{{ the too-harsh line, end to end
-- 78 visible columns, one emphasized word, an 80-column margin. This wrapped
-- two words early for as long as the wrapper measured bytes.
local source_line =
    "who would have thought, people *want* to do good. People also want to take the"
local formatted = generator.apply_markdown_formatting(source_line)
local wrapped = tf.wrap_preserving_indent(formatted, 80)

check("the poem line is 78 columns wide as written",
    tf.calculate_visible_width(source_line) == 78,
    "got " .. tf.calculate_visible_width(source_line))

check("emphasis adds bytes but no columns",
    tf.calculate_visible_width(formatted) == 78 and #formatted > #source_line,
    "columns " .. tf.calculate_visible_width(formatted) .. ", bytes " .. #formatted)

check("the line survives the wrapper whole",
    #wrapped == 1, table.concat(wrapped, " | "):gsub("\1", "*"))

check("its last words are still its last words",
    (wrapped[1]:gsub("\1", "*")):match("take the$") ~= nil,
    (wrapped[1]:gsub("\1", "*")))
-- }}}

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)

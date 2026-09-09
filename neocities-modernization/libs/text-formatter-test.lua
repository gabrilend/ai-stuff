#!/usr/bin/env luajit

-- Guards the one thing the poem line-wrapper has to get right: it must measure
-- how WIDE a line looks, never how many bytes it weighs.
--
-- Why this test exists. A note called "too-harsh" came out of the generator with
-- the words "take the" pushed onto a line of their own, two words short of the
-- margin, while the line two rows below it sat at 79 columns and stayed whole.
-- The difference between them was one emphasized word. The wrapper was counting
-- bytes, so the invisible <em></em> around *want* -- nine bytes wide, zero
-- columns wide -- ate nine characters of a line's budget and pushed its tail
-- over the edge. Escaped ampersands (&amp;, five bytes for one column) and any
-- non-ASCII punctuation (an em dash, three bytes for one column) do the same.
--
-- Run directly:  luajit libs/text-formatter-test.lua [project-dir]

-- {{{ local function setup_dir_path()
local function setup_dir_path(provided)
    if provided then return provided end
    local this = debug.getinfo(1, "S").source:sub(2)
    local libs_dir = this:match("(.*/)") or "./"
    return (libs_dir:gsub("libs/$", ""))
end
-- }}}

local DIR = setup_dir_path(arg and arg[1])
package.path = DIR .. "/libs/?.lua;" .. DIR .. "libs/?.lua;" .. package.path
local tf = require("text-formatter")

local passed, failed = 0, 0

-- {{{ local function check()
-- Assert a condition, printing `detail` when it does not hold so the failure
-- says what the wrapper actually produced rather than merely that it was wrong.
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

-- {{{ local function show()
-- Render a list of wrapped lines as one quoted, pipe-joined string for failure
-- messages, with the emphasis sentinel spelled back out as the asterisk it is.
local function show(lines)
    local parts = {}
    for i, line in ipairs(lines) do
        parts[i] = "[" .. (line:gsub("\1", "*")) .. "]"
    end
    return table.concat(parts, " | ")
end
-- }}}

print("text-formatter wrapping tests")

-- {{{ the too-harsh regression
-- The exact pair of lines from notes/too-harsh, in the state they reach the
-- wrapper: escaped, markdown-applied, sentinels still standing in for the
-- author's asterisks. The first is 78 visible columns and carries emphasis; the
-- second is 79 visible columns and carries none. Neither may wrap at 80.
local emphasized_line =
    "who would have thought, people \1<em>want</em>\1 to do good. People also want to take the"
local plain_line =
    "these things can be true. The issue is, of course, when doing good is not one of"

check("emphasized line measures 78 visible columns",
    tf.calculate_visible_width(emphasized_line) == 78,
    "got " .. tf.calculate_visible_width(emphasized_line))

check("emphasized line weighs more bytes than it shows",
    #emphasized_line > 80,
    "bytes: " .. #emphasized_line)

local wrapped_emphasized = tf.wrap_preserving_indent(emphasized_line, 80)
check("emphasized 78-column line stays on one line",
    #wrapped_emphasized == 1, show(wrapped_emphasized))

local wrapped_plain = tf.wrap_preserving_indent(plain_line, 80)
check("plain 79-column line stays on one line",
    #wrapped_plain == 1, show(wrapped_plain))
-- }}}

-- {{{ the margin itself still holds
check("81-column line does wrap",
    #tf.wrap_preserving_indent(("a"):rep(40) .. " " .. ("b"):rep(40), 80) == 2)

check("exactly 80 columns does not wrap",
    #tf.wrap_preserving_indent(("a"):rep(39) .. " " .. ("b"):rep(40), 80) == 1)

-- An emphasized line genuinely past the margin must still break -- the fix is
-- about measuring honestly, not about letting emphasis buy extra room.
local overlong = "\1<em>emphasis</em>\1 " .. ("word "):rep(20)
check("emphasized line past the margin still wraps",
    #tf.wrap_preserving_indent(overlong, 80) > 1)
-- }}}

-- {{{ entities and multi-byte characters cost one column each
check("&amp; costs one column, not five",
    tf.calculate_visible_width("a &amp; b") == 5,
    "got " .. tf.calculate_visible_width("a &amp; b"))

-- 79 letters plus one escaped ampersand = 80 columns, but 84 bytes.
local with_entity = ("x"):rep(75) .. " &amp; y"
check("line of 80 columns holding an entity does not wrap",
    #tf.wrap_preserving_indent(with_entity, 80) == 1,
    show(tf.wrap_preserving_indent(with_entity, 80)))

-- An em dash is three bytes for one column of ink.
local with_em_dash = ("x"):rep(70) .. " \226\128\148 yz"
check("line of 80 columns holding an em dash does not wrap",
    #tf.wrap_preserving_indent(with_em_dash, 80) == 1,
    show(tf.wrap_preserving_indent(with_em_dash, 80)))
-- }}}

-- {{{ whitespace promises from 10-021 are unchanged
local indented = "   " .. ("word "):rep(30)
local wrapped_indented = tf.wrap_preserving_indent(indented, 80)
check("continuation lines inherit the leading indent",
    #wrapped_indented > 1 and wrapped_indented[2]:sub(1, 3) == "   ",
    show(wrapped_indented))

check("every wrapped line fits the margin",
    (function()
        for _, line in ipairs(wrapped_indented) do
            if tf.calculate_visible_width(line) > 80 then return false end
        end
        return true
    end)(), show(wrapped_indented))

check("empty line survives format_poem_lines",
    (function()
        local lines = tf.format_poem_lines("a\n\nb")
        return #lines == 3 and lines[2] == ""
    end)())
-- }}}

-- {{{ long words break by column, and never through a tag
local long_url = "https://example.com/" .. ("a"):rep(120)
local wrapped_url = tf.wrap_preserving_indent(long_url, 80)
check("a long URL is broken into pieces that fit",
    (function()
        if #wrapped_url < 2 then return false end
        for _, line in ipairs(wrapped_url) do
            if tf.calculate_visible_width(line) > 80 then return false end
        end
        return true
    end)(), show(wrapped_url))

check("a broken URL loses nothing",
    table.concat(wrapped_url, "") == long_url,
    show(wrapped_url))

-- The slicer is the piece that would have cut "<em>" into "<e" + "m>" back when
-- the break was taken at a byte offset.
local chunk, rest = tf.slice_by_visible_width("<em>abcdefgh</em>", 4)
check("slicing counts columns and swallows the opening tag whole",
    chunk == "<em>abcd" and rest == "efgh</em>",
    "chunk=[" .. chunk .. "] rest=[" .. rest .. "]")

local dash_chunk, dash_rest = tf.slice_by_visible_width("ab\226\128\148cd", 3)
check("slicing never cuts a UTF-8 sequence in half",
    dash_chunk == "ab\226\128\148" and dash_rest == "cd",
    "chunk=[" .. dash_chunk .. "] rest=[" .. dash_rest .. "]")

local ent_chunk, ent_rest = tf.slice_by_visible_width("a&amp;bc", 2)
check("slicing keeps an entity whole",
    ent_chunk == "a&amp;" and ent_rest == "bc",
    "chunk=[" .. ent_chunk .. "] rest=[" .. ent_rest .. "]")
-- }}}

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)

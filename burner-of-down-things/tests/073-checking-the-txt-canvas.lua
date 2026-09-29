-- 073-checking-the-txt-canvas.lua
--
-- Checks issue 807a: the `table` word's columns line up in characters, not
-- bytes, even when a cell holds a multi-byte glyph.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local txt_canvas = require("072-the-txt-canvas")

kit.equal(txt_canvas.char_width("abc"), 3, "an ascii cell counts one byte per character")
kit.equal(txt_canvas.char_width("café"), 4, "a multi-byte glyph (é, 2 bytes) still counts as one character")

-- {{{ local function column_two_start
-- The character column the second field starts at, on a rendered line.
local function column_two_start(line)
    local before = line:match("^(.-)%s%s")
    return before and txt_canvas.char_width(before) + 2 or nil
end
-- }}}

local rendered = txt_canvas.table({
    { "café", "x" },
    { "abcd", "y" },
})
local lines = {}
for line in rendered:gmatch("[^\n]+") do
    lines[#lines + 1] = line
end
kit.equal(#lines, 2, "one line per row")
kit.equal(column_two_start(lines[1]), column_two_start(lines[2]),
    "the multi-byte row's second column starts at the same character column as the plain row")

local three_rows = txt_canvas.table({
    { "a", "bb", "ccc" },
    { "dddd", "e", "f" },
})
local three_lines = {}
for line in three_rows:gmatch("[^\n]+") do
    three_lines[#three_lines + 1] = line
end
kit.equal(#three_lines, 2, "one line per row, three columns")
kit.check(three_lines[1]:find("a%s+bb%s+ccc"), "columns pad out to the widest cell in that column")

kit.finish()

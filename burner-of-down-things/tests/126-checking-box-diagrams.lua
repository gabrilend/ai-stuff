-- 126-checking-box-diagrams.lua
--
-- Checks issue 807c: a two-box diagram with one arrow matches a stored
-- expected file byte for byte; so does a three-box diagram whose arrows
-- cross and run backwards; boxes line up in characters, not bytes; the
-- same diagram always gives the same text; a diagram the drawing could
-- only get wrong is refused, naming why.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local txt_canvas = require("072-the-txt-canvas")

local expected = kit.project.fixtures .. "/box-diagrams"

local two = {
    boxes = { { name = "ledger", text = "the ledger" }, { name = "center", text = "the center" } },
    arrows = { { from = "ledger", to = "center", there = "read", here = "weighed" } },
}
local drawn = txt_canvas.box_diagram(two)
kit.equal(drawn .. "\n", kit.fs.read(expected .. "/two-boxes.txt"),
    "a two-box diagram with one arrow matches the stored file byte for byte")

local three = {
    boxes = { { name = "survey" }, { name = "blueprint" }, { name = "design" } },
    arrows = {
        { from = "survey", to = "blueprint", there = "read", here = "described" },
        { from = "blueprint", to = "design", there = "planned", here = "built" },
        { from = "design", to = "survey", there = "checked", here = "café" },
    },
}
kit.equal(txt_canvas.box_diagram(three) .. "\n", kit.fs.read(expected .. "/three-boxes.txt"),
    "three boxes with crossing and backward arrows match the stored file byte for byte")
kit.equal(txt_canvas.box_diagram(three), txt_canvas.box_diagram(three), "the same diagram gives the same text")

-- The look's there-here arrow: a line from the source, an arrowhead at the
-- target, a label at each end.
local lines = {}
for line in (drawn .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = line end
kit.equal(#lines, 5, "three box rows, the row where arrows meet the boxes, one lane")
local source_col = lines[4]:find("|", 1, true)
local head_col = lines[4]:find("^", 1, true)
kit.check(source_col and source_col < 15, "the arrow leaves from under the source box")
kit.check(head_col and head_col > 20, "the arrowhead sits under the target box")
kit.check(lines[5]:find("- read -", 1, true) and lines[5]:find("read", 1, true) < lines[5]:find("weighed", 1, true),
    "the there label sits at the source end of the lane, the here label at the target end")

-- Measured in characters: a box holding a multi-byte glyph is as wide, in
-- characters, as one holding the same number of ASCII letters.
local accented = txt_canvas.box_diagram({ boxes = { { name = "x", text = "café" } } })
local plain = txt_canvas.box_diagram({ boxes = { { name = "x", text = "cafe" } } })
local function widths(t)
    local out = {}
    for line in (t .. "\n"):gmatch("([^\n]*)\n") do out[#out + 1] = txt_canvas.char_width(line) end
    return table.concat(out, ",")
end
kit.equal(widths(accented), widths(plain), "a multi-byte glyph takes one column, so its box lines up")

-- Refusals.
kit.raises(function() txt_canvas.box_diagram({ boxes = {} }) end, "at least one box", "an empty diagram is refused")
kit.raises(function()
    txt_canvas.box_diagram({ boxes = { { name = "a" }, { name = "a" } } })
end, "two boxes are named 'a'", "two boxes of one name are refused")
kit.raises(function()
    txt_canvas.box_diagram({ boxes = { { name = "a" } }, arrows = { { from = "a", to = "b" } } })
end, "names no box ('b'; boxes are a)", "an arrow to a box not drawn is refused, naming the boxes")
kit.raises(function()
    txt_canvas.box_diagram({ boxes = { { name = "a" }, { name = "b" } }, arrows = { { from = "a", to = "a" } } })
end, "to itself", "an arrow from a box to itself is refused")

kit.finish()

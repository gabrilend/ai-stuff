-- 135-checking-diagrams-by-level.lua
--
-- Checks issue 805c: a diamond of four boxes lays out in three columns;
-- every arrow starts on its `from` box and ends on its `to` box; a circle
-- of arrows and a bad name are refused.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local diagram = require("134-the-diagram-canvas")

local diamond = {
    boxes = { { name = "top" }, { name = "left" }, { name = "right" }, { name = "bottom", text = "the end" } },
    arrows = {
        { from = "top", to = "left", there = "a", here = "b" },
        { from = "top", to = "right" },
        { from = "left", to = "bottom" },
        { from = "right", to = "bottom", here = "joined" },
    },
}

local laid = diagram.layout(diamond, 600, 300)
kit.equal(laid.columns, 3, "a diamond of four boxes lays out in three columns")
kit.equal(laid.boxes.top.level, 0, "the top is in the first column")
kit.equal(laid.boxes.left.level, 1, "left is in the second")
kit.equal(laid.boxes.right.level, 1, "right is in the second")
kit.equal(laid.boxes.bottom.level, 2, "the bottom is in the third")
kit.equal(laid.boxes.bottom.text, "the end", "a box keeps its text")
kit.check(laid.boxes.left.x == laid.boxes.right.x, "one column's boxes share an x")
kit.check(laid.boxes.left.y + laid.boxes.left.h <= laid.boxes.right.y, "one column's boxes do not overlap")
kit.check(laid.boxes.top.x + laid.boxes.top.w < laid.boxes.left.x, "columns run left to right without overlap")
kit.equal(table.concat(laid.order, " "), "top left right bottom", "boxes in column then name order")

for i, arrow in ipairs(laid.arrows) do
    kit.check(diagram.on_edge(arrow.start, laid.boxes[arrow.from]), "arrow " .. i .. " starts on its from box")
    kit.check(diagram.on_edge(arrow.finish, laid.boxes[arrow.to]), "arrow " .. i .. " ends on its to box")
    kit.check(not diagram.on_edge(arrow.finish, laid.boxes[arrow.from]), "arrow " .. i .. " does not end where it began")
    kit.check(arrow.finish.x > arrow.start.x, "arrow " .. i .. " runs rightwards")
end
kit.equal(laid.arrows[1].there.text, "a", "there sits at the start")
kit.equal(laid.arrows[1].there.x, laid.arrows[1].start.x, "there sits at the start's x")
kit.equal(laid.arrows[4].here.x, laid.arrows[4].finish.x, "here sits at the finish's x")
kit.equal(laid.arrows[2].there, nil, "an arrow with no label has none")

local lone = diagram.layout({ boxes = { { name = "only" } } }, 100, 100)
kit.equal(lone.columns, 1, "a single box is one column")

kit.raises(function()
    diagram.layout({ boxes = { { name = "a" }, { name = "b" } },
        arrows = { { from = "a", to = "b" }, { from = "b", to = "a" } } }, 10, 10)
end, "round in a circle", "a circle of arrows is refused")
kit.raises(function() diagram.layout({ boxes = { { name = "two words" } } }, 10, 10) end,
    "one word", "a box name with a space is refused")
kit.raises(function() diagram.layout({ boxes = { { name = "a" } }, arrows = { { from = "a", to = "z" } } }, 10, 10) end,
    "the boxes are a", "an arrow to no box is refused, listing the boxes")
kit.raises(function() diagram.layout({ boxes = { { name = "a" } }, arrows = { { from = "a", to = "a" } } }, 10, 10) end,
    "to itself", "an arrow from a box to itself is refused")
kit.raises(function() diagram.layout({ boxes = {} }, 10, 10) end, "at least one box", "no boxes is refused")

kit.finish()

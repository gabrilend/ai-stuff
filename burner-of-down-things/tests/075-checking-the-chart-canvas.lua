-- 075-checking-the-chart-canvas.lua
--
-- Checks issue 805a: bar heights in pixels are proportional to the data.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local chart_canvas = require("074-the-chart-canvas")

local boxes = chart_canvas.bars({ 10, 20, 5 }, 300, 100)
kit.equal(#boxes, 3, "one box per datum")
kit.equal(boxes[2].h, 100, "the largest value reaches the full height")
kit.equal(boxes[1].h, 50, "half the largest value is half the height")
kit.equal(boxes[3].h, 25, "a quarter of the largest value is a quarter of the height")

for i = 1, #boxes - 1 do
    kit.check(boxes[i].x + boxes[i].w <= boxes[i + 1].x, "bar " .. i .. " does not overlap the next")
end

kit.raises(function() chart_canvas.bars({}, 100, 100) end, "at least one value",
    "an empty data array is refused")
kit.raises(function() chart_canvas.bars({ 0, 0 }, 100, 100) end, "must be positive",
    "data with no positive value is refused")

kit.finish()

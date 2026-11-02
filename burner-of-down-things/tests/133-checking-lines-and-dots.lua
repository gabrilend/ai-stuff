-- 133-checking-lines-and-dots.lua
--
-- Checks issue 805b: a line chart's points fall on the same axis positions
-- 805a's bar geometry computes for the same data; dots sit where the
-- line's points do; the axis geometry is one, shared by every kind.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local chart = require("074-the-chart-canvas")

local data = { 10, 20, 5, 15 }
local bars = chart.bars(data, 400, 100)
local line = chart.lines(data, 400, 100)
local dots = chart.dots(data, 400, 100)

kit.equal(#line.points, #data, "one point per datum")
kit.equal(#line.segments, #data - 1, "one segment between each pair of neighbours")
for i, bar in ipairs(bars) do
    kit.equal(line.points[i].x, bar.x + bar.w / 2, "point " .. i .. " is at bar " .. i .. "'s middle")
    kit.equal(line.points[i].y, bar.y, "point " .. i .. " is at bar " .. i .. "'s top")
    kit.equal(dots[i].x, line.points[i].x, "dot " .. i .. " is where the line's point is, across")
    kit.equal(dots[i].y, line.points[i].y, "dot " .. i .. " is where the line's point is, up")
    kit.check(dots[i].r > 0 and dots[i].r < bar.w / 2, "dot " .. i .. " fits in its slot")
end
for i, seg in ipairs(line.segments) do
    kit.check(seg.x1 == line.points[i].x and seg.y2 == line.points[i + 1].y,
        "segment " .. i .. " joins point " .. i .. " to point " .. (i + 1))
end
kit.equal(line.points[2].y, 0, "the largest value reaches the top")
kit.equal(line.points[3].y, 75, "a quarter of the largest is three quarters of the way down")

local one = chart.lines({ 3 }, 100, 50)
kit.equal(#one.segments, 0, "a single datum is a point with no segment")

local word = chart.chart({ kind = "dots", data = data, labels = { "a", "b", "c", "d" }, width = 400, height = 100 })
kit.equal(word.kind, "dots", "the chart word keeps its kind")
kit.equal(word.labels[3].x, dots[3].x, "a label sits under its datum")
kit.equal(word.marks[4].y, dots[4].y, "the chart word's marks are the kind's own")

kit.raises(function() chart.chart({ kind = "pie", data = data, width = 1, height = 1 }) end,
    "is not one of bars, lines, dots", "an unknown kind is refused, naming the kinds")
kit.raises(function() chart.chart({ kind = "lines", data = data, labels = { "a" }, width = 1, height = 1 }) end,
    "1 labels for 4 data", "labels that do not match the data are refused")
kit.raises(function() chart.lines({ 1, -1 }, 10, 10) end, "negative", "a negative datum is refused")
kit.raises(function() chart.dots({}, 10, 10) end, "at least one value", "no data is refused")

kit.finish()

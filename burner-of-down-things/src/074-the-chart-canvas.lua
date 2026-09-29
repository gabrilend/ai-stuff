-- 074-the-chart-canvas.lua
--
-- The .png (and .txt) end's `chart` word, bars first (docs/067, issue
-- 805a). This piece is the geometry alone: data in, pixel heights out. It
-- does not paint — that is 804's raylib painter — nor colour the midline
-- (801c's flair function, drawn on once it exists); it only decides where
-- each bar's box sits, so painting and flair can both build on one answer.

local chart_canvas = {}

-- {{{ function chart_canvas.bars
-- data: array of numbers. width, height: the chart's pixel box.
-- Returns an array of bar boxes { x, y, w, h }, left to right, each bar's
-- height in pixels proportional to its value against the largest value in
-- data (so the tallest bar always reaches the top of the box).
function chart_canvas.bars(data, width, height)
    if #data == 0 then
        error("chart_canvas.bars: data must hold at least one value")
    end
    local largest = data[1]
    for i = 2, #data do
        if data[i] > largest then
            largest = data[i]
        end
    end
    if largest <= 0 then
        error("chart_canvas.bars: the largest value must be positive, got " .. tostring(largest))
    end
    local gap = width / (#data * 4)
    local bar_width = (width - gap * (#data + 1)) / #data
    local boxes = {}
    for i, value in ipairs(data) do
        local bar_height = height * (value / largest)
        boxes[i] = {
            x = gap * i + bar_width * (i - 1),
            y = height - bar_height,
            w = bar_width,
            h = bar_height,
        }
    end
    return boxes
end
-- }}}

return chart_canvas

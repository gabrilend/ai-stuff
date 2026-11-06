-- 074-the-chart-canvas.lua
--
-- The .png (and .txt) end's `chart` word (docs/067): bars (issue 805a),
-- lines and dots (805b), all over one axis geometry. This piece is the
-- geometry alone: data in, pixel positions out. It does not paint — that
-- is 804's raylib painter — nor colour a bar's midline (801c's flair,
-- drawn on once the painter exists); it only decides where each mark sits,
-- so painting and flair can both build on one answer.

local chart_canvas = {}

-- The kinds of chart, in docs/067's order.
chart_canvas.KINDS = { "bars", "lines", "dots" }

-- A dot's radius, as a share of one datum's slot width, so dots scale with
-- the chart instead of vanishing on a wide one or crowding on a narrow one.
chart_canvas.DOT_SHARE = 0.15

-- {{{ function chart_canvas.axes
-- The axis geometry every kind shares (805b's step 1, factored out of
-- 805a's bars). data: array of numbers, none negative, the largest
-- positive. width, height: the chart's pixel box. Returns
--   { n, largest, width, height, gap, slot,
--     x = function(i)      -- the left edge of datum i's slot
--     centre = function(i) -- the middle of datum i's slot
--     y = function(value)  -- the pixel row a value reaches (0 at the top) }
-- Slots are laid left to right with a gap of a quarter slot-share between
-- them and at either end, as 805a's bars always were.
function chart_canvas.axes(data, width, height)
    if type(data) ~= "table" or #data == 0 then
        error("chart_canvas: data must hold at least one value")
    end
    local largest = data[1]
    for i, value in ipairs(data) do
        if type(value) ~= "number" then
            error("chart_canvas: datum " .. i .. " is not a number: " .. tostring(value))
        end
        if value < 0 then
            error("chart_canvas: datum " .. i .. " is negative (" .. value .. "); the axis starts at 0")
        end
        if value > largest then
            largest = value
        end
    end
    if largest <= 0 then
        error("chart_canvas: the largest value must be positive, got " .. tostring(largest))
    end
    local n = #data
    local gap = width / (n * 4)
    local slot = (width - gap * (n + 1)) / n
    local axes = { n = n, largest = largest, width = width, height = height, gap = gap, slot = slot }
    function axes.x(i)
        return gap * i + slot * (i - 1)
    end
    function axes.centre(i)
        return axes.x(i) + slot / 2
    end
    function axes.y(value)
        return height - height * (value / largest)
    end
    return axes
end
-- }}}

-- {{{ function chart_canvas.bars
-- data: array of numbers. width, height: the chart's pixel box.
-- Returns an array of bar boxes { x, y, w, h }, left to right, each bar's
-- height in pixels proportional to its value against the largest value in
-- data (so the tallest bar always reaches the top of the box).
function chart_canvas.bars(data, width, height)
    local axes = chart_canvas.axes(data, width, height)
    local boxes = {}
    for i, value in ipairs(data) do
        local top = axes.y(value)
        boxes[i] = { x = axes.x(i), y = top, w = axes.slot, h = height - top }
    end
    return boxes
end
-- }}}

-- {{{ local function points
local function points(axes, data)
    local out = {}
    for i, value in ipairs(data) do
        out[i] = { x = axes.centre(i), y = axes.y(value) }
    end
    return out
end
-- }}}

-- {{{ function chart_canvas.lines
-- A line through the data's points (805b): each point at its slot's middle
-- and the height its value reaches on the shared axes. Returns
-- { points = {{x, y}, ...}, segments = {{x1, y1, x2, y2}, ...} }, one
-- segment between each pair of neighbours (none for a single datum).
function chart_canvas.lines(data, width, height)
    local axes = chart_canvas.axes(data, width, height)
    local pts = points(axes, data)
    local segments = {}
    for i = 1, #pts - 1 do
        segments[i] = { x1 = pts[i].x, y1 = pts[i].y, x2 = pts[i + 1].x, y2 = pts[i + 1].y }
    end
    return { points = pts, segments = segments }
end
-- }}}

-- {{{ function chart_canvas.dots
-- One point per datum (805b), at the same places `lines` puts its points,
-- each with a radius of DOT_SHARE of a slot. Returns {{x, y, r}, ...}.
function chart_canvas.dots(data, width, height)
    local axes = chart_canvas.axes(data, width, height)
    local out = points(axes, data)
    for _, p in ipairs(out) do
        p.r = axes.slot * chart_canvas.DOT_SHARE
    end
    return out
end
-- }}}

-- {{{ function chart_canvas.chart
-- The canvas word itself: chart{ kind, data, labels, width, height }.
-- Returns { kind, marks, labels }, where marks is what bars, lines or dots
-- returns, and labels pairs each label (optional, one per datum) with its
-- slot's middle: {{text, x}, ...}.
function chart_canvas.chart(spec)
    local make = ({ bars = chart_canvas.bars, lines = chart_canvas.lines, dots = chart_canvas.dots })[spec.kind]
    if not make then
        error("chart_canvas.chart: the kind '" .. tostring(spec.kind) .. "' is not one of "
            .. table.concat(chart_canvas.KINDS, ", "))
    end
    local labels = spec.labels or {}
    if #labels > 0 and #labels ~= #(spec.data or {}) then
        error("chart_canvas.chart: " .. #labels .. " labels for " .. #(spec.data or {}) .. " data")
    end
    local axes = chart_canvas.axes(spec.data, spec.width, spec.height)
    local placed = {}
    for i, text in ipairs(labels) do
        placed[i] = { text = tostring(text), x = axes.centre(i) }
    end
    return { kind = spec.kind, marks = make(spec.data, spec.width, spec.height), labels = placed }
end
-- }}}

return chart_canvas

-- 134-the-diagram-canvas.lua
--
-- The .png end's `diagram` word (docs/067, issue 805c): boxes and arrows,
-- laid out by levels the way the blueprint graph is (043). A box is a node
-- and an arrow an edge: an arrow from `a` to `b` makes `b` build on `a`, so
-- `b` sits one column further right than its highest-placed source. Like
-- the chart canvas (074) this is geometry alone — pixel boxes and arrow
-- ends — for 804's painter to draw once it exists.

local graph = require("043-the-graph")

local diagram_canvas = {}

-- A box's share of its column's width and of its row's height; the rest is
-- the space between boxes, where the arrows run.
diagram_canvas.BOX_SHARE = 0.6

-- {{{ local function check
-- Refuses what would not lay out, naming it: no boxes, a box with no name
-- or a name with a space (043 reads names as space-separated words), a
-- repeated name, an arrow naming no box, an arrow from a box to itself.
local function check(spec)
    if type(spec) ~= "table" or type(spec.boxes) ~= "table" or #spec.boxes == 0 then
        error("diagram_canvas: a diagram needs at least one box")
    end
    local known, names = {}, {}
    for i, box in ipairs(spec.boxes) do
        local name = box.name
        if type(name) ~= "string" or name == "" or name:find("%s") then
            error("diagram_canvas: box " .. i .. " needs a name of one word, got " .. tostring(name))
        end
        if known[name] then
            error("diagram_canvas: the box '" .. name .. "' is named twice")
        end
        known[name] = true
        names[#names + 1] = name
    end
    for i, arrow in ipairs(spec.arrows or {}) do
        for _, end_name in ipairs({ "from", "to" }) do
            if not known[arrow[end_name]] then
                error("diagram_canvas: arrow " .. i .. "'s " .. end_name .. " '" .. tostring(arrow[end_name])
                    .. "' is no box; the boxes are " .. table.concat(names, ", "))
            end
        end
        if arrow.from == arrow.to then
            error("diagram_canvas: arrow " .. i .. " goes from '" .. arrow.from .. "' to itself")
        end
    end
end
-- }}}

-- {{{ function diagram_canvas.graph
-- Boxes and arrows read into a 043-shaped graph (805c's step 1): one
-- outline-like row per box, its blocked_by the boxes with an arrow to it.
-- Refuses a circle of arrows, since a circle has no levels.
function diagram_canvas.graph(spec)
    check(spec)
    local into = {}
    for _, arrow in ipairs(spec.arrows or {}) do
        into[arrow.to] = into[arrow.to] or {}
        local list = into[arrow.to]
        list[#list + 1] = arrow.from
    end
    local rows = {}
    for i, box in ipairs(spec.boxes) do
        rows[i] = {
            id = box.name, name = box.text or box.name,
            blocked_by = table.concat(into[box.name] or {}, " "), covers = "",
        }
    end
    local ok, built = pcall(graph.build, rows)
    if not ok then
        error("diagram_canvas: the arrows go round in a circle, so the boxes have no levels")
    end
    return built
end
-- }}}

-- {{{ function diagram_canvas.layout
-- Level layout turned into pixel positions (805c's step 2): one column per
-- level, left to right; within a column the boxes in name order, top to
-- bottom, each centred in an equal share of the height. Returns
--   { columns = n,
--     boxes = { [name] = { name, text, level, x, y, w, h } },
--     order = { name, ... }              -- left to right, top to bottom
--     arrows = { { from, to, start = {x, y}, finish = {x, y},
--                  there = {text, x, y} | nil, here = {text, x, y} | nil } } }
-- An arrow always runs rightwards (its target's level is higher), from the
-- middle of its source's right edge to the middle of its target's left
-- edge; `there` sits at the start, `here` at the finish.
function diagram_canvas.layout(spec, width, height)
    local g = diagram_canvas.graph(spec)
    local levels = graph.levels(g)
    local column_w = width / #levels
    local box_w = column_w * diagram_canvas.BOX_SHARE
    local boxes, order = {}, {}
    for column, ids in ipairs(levels) do
        local row_h = height / #ids
        local box_h = row_h * diagram_canvas.BOX_SHARE
        for row, id in ipairs(ids) do
            local node = g.nodes[id]
            boxes[id] = {
                name = id, text = node.name, level = node.level,
                x = column_w * (column - 1) + (column_w - box_w) / 2,
                y = row_h * (row - 1) + (row_h - box_h) / 2,
                w = box_w, h = box_h,
            }
            order[#order + 1] = id
        end
    end
    local arrows = {}
    for i, arrow in ipairs(spec.arrows or {}) do
        local a, b = boxes[arrow.from], boxes[arrow.to]
        local start = { x = a.x + a.w, y = a.y + a.h / 2 }
        local finish = { x = b.x, y = b.y + b.h / 2 }
        arrows[i] = {
            from = arrow.from, to = arrow.to, start = start, finish = finish,
            there = arrow.there and { text = arrow.there, x = start.x, y = start.y } or nil,
            here = arrow.here and { text = arrow.here, x = finish.x, y = finish.y } or nil,
        }
    end
    return { columns = #levels, boxes = boxes, order = order, arrows = arrows }
end
-- }}}

-- {{{ function diagram_canvas.on_edge
-- Whether point p lies on box b's outline (within `slack` pixels), the
-- check that an arrow starts and ends on its boxes.
function diagram_canvas.on_edge(p, b, slack)
    slack = slack or 1e-9
    local inside_x = p.x >= b.x - slack and p.x <= b.x + b.w + slack
    local inside_y = p.y >= b.y - slack and p.y <= b.y + b.h + slack
    if not (inside_x and inside_y) then
        return false
    end
    return math.abs(p.x - b.x) <= slack or math.abs(p.x - (b.x + b.w)) <= slack
        or math.abs(p.y - b.y) <= slack or math.abs(p.y - (b.y + b.h)) <= slack
end
-- }}}

return diagram_canvas

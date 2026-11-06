-- 136-the-machine-drawn.lua
--
-- The machine drawn by itself (docs/067, issue 805d): its own things as
-- the studio's first real content. Adapters only — each turns something
-- the machine already holds into the data of a canvas word — so the
-- drawing stays the chart and diagram canvases' (074, 134) and the things
-- drawn stay the blueprint's (043), the center's (058) and the ledger's
-- (016). Nothing here reads a file: callers hand in what they read.

local center = require("058-the-center")

local machine_drawn = {}

-- How many of the center's weights a chart shows when not told: the
-- heaviest few read as a shape; every weight in a long case reads as noise.
machine_drawn.CENTER_BARS = 8

-- {{{ function machine_drawn.blueprint_diagram
-- A blueprint graph (043's build) as `diagram`'s boxes and arrows: one box
-- per issue, named by its id and showing "id name"; one arrow from each
-- blocker to the issue built on it. Ids in the graph's own order, so the
-- same blueprint always gives the same diagram.
function machine_drawn.blueprint_diagram(g)
    local boxes, arrows = {}, {}
    for _, id in ipairs(g.ids) do
        local node = g.nodes[id]
        boxes[#boxes + 1] = { name = id, text = id .. " " .. node.name }
        for _, blocker in ipairs(node.blocked_by) do
            arrows[#arrows + 1] = { from = blocker, to = id }
        end
    end
    return { boxes = boxes, arrows = arrows }
end
-- }}}

-- {{{ function machine_drawn.center_chart
-- A center (058's compute) as `chart`'s data and labels: the `n` heaviest
-- abouts (CENTER_BARS when not given), heaviest first, ties by name, as
-- center.heaviest orders them. `kind` defaults to bars. Refuses a center
-- with no weights, since an empty chart says nothing.
function machine_drawn.center_chart(c, n, kind)
    local heaviest = center.heaviest(c, n or machine_drawn.CENTER_BARS)
    if #heaviest == 0 then
        error("machine_drawn.center_chart: the center has no weights yet; nothing has been asked of the case")
    end
    local data, labels = {}, {}
    for i, t in ipairs(heaviest) do
        data[i] = t.weight
        labels[i] = t.about
    end
    return { kind = kind or "bars", data = data, labels = labels }
end
-- }}}

-- {{{ function machine_drawn.ledger_chart
-- Ledger lines (016's read) as `chart`'s data and labels: how many lines of
-- each kind, most first, ties by kind name. Refuses no lines.
function machine_drawn.ledger_chart(lines, kind)
    local counts, kinds = {}, {}
    for _, line in ipairs(lines) do
        if not counts[line.kind] then
            counts[line.kind] = 0
            kinds[#kinds + 1] = line.kind
        end
        counts[line.kind] = counts[line.kind] + 1
    end
    if #kinds == 0 then
        error("machine_drawn.ledger_chart: the ledger has no lines")
    end
    table.sort(kinds, function(a, b)
        if counts[a] ~= counts[b] then return counts[a] > counts[b] end
        return a < b
    end)
    local data = {}
    for i, k in ipairs(kinds) do
        data[i] = counts[k]
    end
    return { kind = kind or "bars", data = data, labels = kinds }
end
-- }}}

return machine_drawn

-- 137-checking-the-machine-drawn.lua
--
-- Checks issue 805d: the notes fixture's blueprint renders as a diagram
-- whose boxes match its issue ids exactly; the center and the ledger's
-- totals become charts whose bars follow their numbers.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local text_tables = require("014-text-tables")
local graph = require("043-the-graph")
local center = require("058-the-center")
local chart = require("074-the-chart-canvas")
local diagram = require("134-the-diagram-canvas")
local drawn = require("136-the-machine-drawn")

local rows = text_tables.read(kit.DIR .. "/tests/fixtures/tiny-notes-blueprint/outline.tsv")
local g = graph.build(rows)
local spec = drawn.blueprint_diagram(g)
local laid = diagram.layout(spec, 900, 400)

local ids = {}
for _, row in ipairs(rows) do ids[#ids + 1] = row.id end
table.sort(ids)
local drawn_ids = {}
for name in pairs(laid.boxes) do drawn_ids[#drawn_ids + 1] = name end
table.sort(drawn_ids)
kit.equal(table.concat(drawn_ids, " "), table.concat(ids, " "), "the diagram's boxes are the blueprint's issue ids exactly")
kit.equal(laid.boxes["301"].text, "301 the-notes-command", "each box shows its id and name")
kit.equal(laid.columns, #graph.levels(g), "one column per level of the blueprint")
kit.equal(laid.boxes["301"].level, g.nodes["301"].level, "a box's column is its issue's level")

local edges = 0
for _, row in ipairs(rows) do
    local _, n = (" " .. row.blocked_by .. " "):gsub("%d%d%d", "")
    edges = edges + n
end
kit.equal(#laid.arrows, edges, "one arrow per blocker in the outline")
for _, arrow in ipairs(laid.arrows) do
    kit.check(diagram.on_edge(arrow.start, laid.boxes[arrow.from]) and diagram.on_edge(arrow.finish, laid.boxes[arrow.to]),
        "arrow " .. arrow.from .. " -> " .. arrow.to .. " joins its boxes")
end

local lines = {
    { kind = "request-received", about = "tags", text = "" },
    { kind = "built", about = "101", text = "" },
    { kind = "build-failed", about = "201", text = "" },
    { kind = "graded", about = "tags", text = "touched 101 201" },
    { kind = "built", about = "201", text = "" },
}
local c = center.compute(lines)
local cspec = drawn.center_chart(c)
local heaviest = center.heaviest(c, 8)
kit.equal(#cspec.data, #heaviest, "one bar per weight")
kit.equal(cspec.labels[1], heaviest[1].about, "the heaviest is drawn first")
kit.equal(cspec.data[1], heaviest[1].weight, "a bar's value is its weight")
local bars = chart.chart({ kind = cspec.kind, data = cspec.data, labels = cspec.labels, width = 400, height = 100 })
kit.equal(bars.marks[1].h, 100, "the heaviest weight's bar is the full height")
kit.equal(#drawn.center_chart(c, 2).data, 2, "a chart of the heaviest two holds two")

local lspec = drawn.ledger_chart(lines)
kit.equal(table.concat(lspec.labels, " "), "built build-failed graded request-received", "ledger kinds, most lines first, ties by name")
kit.equal(table.concat(lspec.data, " "), "2 1 1 1", "each kind's count of lines")

kit.raises(function() drawn.center_chart(center.compute({})) end, "no weights", "an empty center is refused")
kit.raises(function() drawn.ledger_chart({}) end, "no lines", "an empty ledger is refused")

kit.finish()

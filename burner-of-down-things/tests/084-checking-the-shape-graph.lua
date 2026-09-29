-- 084-checking-the-shape-graph.lua
--
-- Checks issue 905a: a station table of three rows builds a graph of the
-- right nodes and edges, one per row.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local shape_graph = require("083-the-shape-graph")

local rows = {
    { name = "the-record-reader", input = "table", output = "integer-array" },
    { name = "the-chart-canvas",  input = "integer-array", output = "image" },
    { name = "the-json-reader",   input = "results", output = "finding" },
}
local graph = shape_graph.build(rows)

kit.equal(#graph.edges, 3, "one edge per row")
kit.equal(graph.edges[2].from, "integer-array", "an edge's from is its row's input")
kit.equal(graph.edges[2].to, "image", "an edge's to is its row's output")
kit.equal(graph.edges[2].station, "the-chart-canvas", "an edge names its station")

-- table, integer-array, image, results, finding: five distinct shapes,
-- "integer-array" appearing as both an output and an input counts once.
kit.equal(#graph.nodes, 5, "every distinct shape is one node, shared shapes not doubled")

local found_integer_array = false
for _, node in ipairs(graph.nodes) do
    if node == "integer-array" then found_integer_array = true end
end
kit.check(found_integer_array, "a shape used as both input and output still appears as a node")

kit.finish()

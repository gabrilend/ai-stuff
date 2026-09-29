-- 094-checking-the-station-table.lua
--
-- Checks issue 902d: a shape finds the right station, and a shape no
-- station gives is said plainly, not silently dropped. Then proves the
-- strategem this piece follows (build-to-the-shape-not-the-neighbor): the
-- real table, once it exists, slots into 905a's shape graph unchanged.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local station_table = require("093-the-station-table")
local shape_graph = require("083-the-shape-graph")

-- The real table finds its one real station.
local row = station_table.find(station_table.TABLE, "table", "text")
kit.check(row ~= nil, "the real station table finds the txt-table station")
kit.equal(row.name, "txt-table", "the found station is named txt-table")
kit.equal(row.run({ { "a", "b" } }), "a  b", "the found station's run function is the real one")

-- The matching function itself, proven with a fixture bigger than today's
-- real table (902d does not have to wait for 804/806/808 to exist first).
local fixture = {
    { name = "txt-table", input = "table", output = "text" },
    { name = "chart-canvas", input = "integer-array", output = "image" },
    { name = "record-reader", input = "results", output = "finding" },
}
local found = station_table.find(fixture, "integer-array", "image")
kit.equal(found.name, "chart-canvas", "a fixture shape finds its station")

local missing, near = station_table.find(fixture, "integer-array", "clip")
kit.equal(missing, nil, "an uncovered shape finds no station")
kit.equal(#near, 1, "the near-miss list names the station sharing half the shape")
kit.equal(near[1], "chart-canvas", "the near miss is named, not dropped silently")

-- Strategem check: 905a was built against "any table shaped like 902d's
-- own rows" before 902d existed. The real TABLE, unchanged, slots in.
local graph = shape_graph.build(station_table.TABLE)
kit.equal(#graph.edges, #station_table.TABLE, "the real station table builds a shape graph, unchanged from 905a")

kit.finish()

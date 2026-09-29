-- 083-the-shape-graph.lua
--
-- The station table (902d) read as a graph: a node per shape, an edge per
-- station (docs/068, issue 905a). Built generically from any table shaped
-- like 902d's own rows, so this piece does not have to wait for 902d
-- itself; the shortest-chain search (905b) is the first piece that will
-- hand it a real station table.

local shape_graph = {}

-- {{{ function shape_graph.build
-- rows: array of {name, input, output} — a station's name and its input
-- and output shapes, as strings (902d's own row shape). Returns
-- {nodes = sorted array of every shape seen, edges = array of
-- {from, to, station}, one per row, in row order}.
function shape_graph.build(rows)
    local seen, nodes = {}, {}
    local edges = {}
    for i, row in ipairs(rows) do
        if not seen[row.input] then
            seen[row.input] = true
            nodes[#nodes + 1] = row.input
        end
        if not seen[row.output] then
            seen[row.output] = true
            nodes[#nodes + 1] = row.output
        end
        edges[i] = { from = row.input, to = row.output, station = row.name }
    end
    table.sort(nodes)
    return { nodes = nodes, edges = edges }
end
-- }}}

return shape_graph

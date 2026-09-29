# 083-the-shape-graph.lua

The station table read as a graph (docs/068, issue 905a). Takes any table
shaped like 902d's own rows, so it does not need 902d itself to be built.
905b's shortest-chain search is the first piece to hand it a real table.

| Function | In | Out |
|---|---|---|
| `build(rows)` | array of `{name, input, output}` (a station's name and its input/output shapes) | `{nodes = sorted array of every shape seen, edges = array of {from, to, station}, one per row}` |

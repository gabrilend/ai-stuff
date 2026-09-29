# 905a — The shape graph

The first piece of 905.

## Current Behavior

Built. `src/083-the-shape-graph.lua`'s `build(rows)` turns any table
shaped like a station table (name, input shape, output shape) into
`{nodes, edges}`. It takes any such table, not only 902d's real one, so it
did not have to wait for 902d to exist. Checked by
`tests/084-checking-the-shape-graph.lua`.

## Intended Behavior

The station table (902d) read as a graph: a node per shape, an edge per
station (its input shape to its output shape) — the structure a plan
searches over.

## Suggested Implementation Steps

1. The shape-graph builder from the station table. Done:
   `083-the-shape-graph.lua`'s `build`. **Test:** a station table of three
   rows builds a graph of the right nodes and edges (one per row). Done.

## Blocked by

- 902d

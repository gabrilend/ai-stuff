# 306 — Cycle detector

## Current behavior

After the encap splicer (305) flattens sub-maps and the wire
connector (304) hooks producer outputs to consumer slots, the
runtime has a complete graph. A cycle in that graph — box A's
output reaches its own input through some path — would, if
allowed to fire, deadlock the gathering function: the box can
never accumulate the input value it needs without the output
landing first. The runtime needs to refuse such maps at load
time.

## Intended behavior

A standard DFS on the directed graph identifies cycles. The
detector walks every box, marks it in-progress when entered,
recursively visits every consumer reachable through the box's
connections list, and detects a back-edge (an edge to an
in-progress vertex) as a cycle.

Hitting a cycle aborts the load with a structured error: which
box the cycle was detected at, the path along it. The caller
of `map_load` (303) receives the error and frees its allocations.

A small exception: a few patterns deliberately re-fire a box
periodically using a self-link through a delay-like routing kind
(soramech proper's timer-box design is one). The detector treats
self-loops through routing kinds that mark themselves as
*self-arming* as not-a-cycle. Phase 3 ships with no such kinds —
the seven routing kinds 307 implements are all non-self-arming —
but the detector's check is parameterized on the descriptor's
self-arming flag so phase 5 (input drivers) and phase 7 (network
polling) can add self-arming patterns without changing the
detector.

## Suggested implementation steps

1. `cycle_detect(map_t *)` — top-level entry.
2. `dfs_visit(box_instance_t *, state)` — recursive visit.
3. State enum: unvisited / in-progress / done.
4. Error path: report cycle path through the debug stream.

## Related documents

- `docs/012-soramech-runtime.md`.

## Blocked by

301, 304, 305.

## Blocks

308 (no map runs until cycle detection passes), 311.

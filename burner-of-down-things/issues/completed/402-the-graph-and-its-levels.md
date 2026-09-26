# 402 — The graph and its levels

Which issue builds on which, as a structure every later phase reads
([006](../docs/006-datapath-the-blueprint.md), *the graph*).

## Current Behavior

Built as `src/043-the-graph.lua`, with the `graph` command in `src/046-the-blueprint-commands.lua` (marks each issue described, built, failed from the ledger). Checked by tests/047 on a diamond and on the tiny-notes fixture (three levels; showing-notes reaches 2 of 6).

## Intended Behavior

- **Build the graph** (outline rows): nodes as in
  [002](../docs/002-the-terms.md) (*a graph node*): id, file, blocked-by,
  blocks (reverse edges), level. Levels by repeated passes until every node
  has one (the outline is known acyclic by now).
- **Levels** (graph): arrays of ids per level, ids in order within each.
- **Reach** (graph, ids): the ids plus everything that transitively blocks
  on them, as a sorted array.
- **Command `graph`**: prints each level and its issues with their names and
  blockers; the viewing side, separate from the building.

## Suggested Implementation Steps

1. Build and levels. **Test:** a diamond (A; B and C on A; D on B and C) gives
   levels 0, 1, 1, 2.
2. Reach. **Test:** reach of A is all four; of B is B and D; of D is D.

## Blocked by

- 401

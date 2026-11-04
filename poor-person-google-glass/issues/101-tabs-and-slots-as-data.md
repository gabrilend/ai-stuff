# 101 — Tabs and slots as data

**Phase:** 1 — The mask
**Blocks:** 102, 103, 104
**Related documents:** docs/core-terms.md, docs/datapath-light.md

## Current Behavior
No model of the tabs exists.

## Intended Behavior
A tab is described by its axis position along the pipe (number, mm), its
length (number, mm), its swing angle (number, degrees), and a row of slots
(list of booleans). From a set of tabs, compute the mask: the grid of cells
(booleans) where every overlapping tab is open.

## Suggested Implementation Steps
1. Tab and mask structures in Lua (LuaJIT syntax), with a `.info.md`.
2. Mask from tabs, one row of cells per worker job.
3. Tests: two crossing tabs with one open slot each light exactly one cell.

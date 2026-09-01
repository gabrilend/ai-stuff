# 403 — A Path Is Found Once And Kept

| | |
| --- | --- |
| Phase | 4 — The Wandering |
| Blocked by | 107, 401 |
| Blocks | 603, 604, 707 |
| Reads | [walking the surface graph](../docs/014-walking-the-surface-graph.md) |
| Open questions | none |

## Current behavior

Bodies wander and cannot go anywhere in particular.

## Intended behavior

A-star over the surface graph, with the estimate being straight-line distance in
cells plus the difference in layers.

Three things bound the cost, and all three are the point of the issue:

**The component label is checked first.** If the destination is in a different
component there is no path, and one comparison saves the entire search. From
issue 107.

**A path is computed once and stored** as a list of surfaces, recomputed only
when the destination changes or the stone does. A body that pathfinds every tick
costs a hundred times what it should to do the same thing.

**The search gives up.** After `search_budget` surfaces examined it stops,
returns nothing, and the body falls back to wandering — and **says so**, as a
count in the report. A search that quietly failed leaves a body standing still
looking stuck for no reason, and the count is how anybody finds out it is
happening at all. This is the fallback rule: a fallback is permitted, it is
announced, and it is counted.

## Suggested implementation steps

1. Write the open set as a binary heap over a preallocated array, not a sorted
   table. The heap is rebuilt per search rather than allocated.
2. Pack a surface into one integer — cell and layer — so the came-from map is a
   flat array rather than a table of tables.
3. Write the search with the budget, returning the path reversed into a
   preallocated per-body path array.
4. Write path following: advance an index as each surface is reached; recompute
   if the next surface is no longer adjacent, which is what happens after a fall.
5. Count abandoned searches, paths recomputed, and mean path length into the
   report.
6. Test: on a maze with a known longest path, a search across it succeeds and its
   length matches breadth-first search's answer. A search to an unreachable
   surface returns immediately without examining anything.

## Related documents and tools

- [Walking the surface graph](../docs/014-walking-the-surface-graph.md)
- [Standing somewhere and going elsewhere](../docs/004-standing-somewhere-and-going-elsewhere.md)

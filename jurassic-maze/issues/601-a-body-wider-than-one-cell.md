# 601 — A Body Wider Than One Cell

| | |
| --- | --- |
| Phase | 6 — The Habitat |
| Blocked by | 107, 301, 308, 401 |
| Blocks | 603, 604, 702 |
| Reads | [dinosaurs in a habitat](../docs/019-dinosaurs-in-a-habitat.md) |
| Open questions | none |

## Current behavior

Every body occupies exactly one cell.

## Intended behavior

The `striding` row: the ordinary walk with the enterability check applied to
**every cell of the body's footprint** at the destination instead of one. The
same graph, the same step, the same timing.

Three consequences, all of the surprising-later kind:

**A dinosaur cannot go everywhere a little guy can.** A one-cell corridor does
not admit a three-cell animal. This is correct and it is the most interesting
thing about them sharing a maze — the little guys have a whole network of
boltholes, and nobody added it. It was in the maze all along.

**A dinosaur's stance is its centre**, which may be over a cell it could not
stand on alone. The footprint decides; the stance is only for indexing.

**A dinosaur occupies several buckets.** Issue 308's placement takes a footprint
for exactly this reason. A three-cell animal in one bucket is invisible to
anything standing beside its tail, and the meet pass's greater-id rule already
handles the duplicate pairs that follow.

Two dinosaurs do not push each other. They step around by the same rule any two
walkers do, and one that cannot fit past another waits. Waiting looks like
deference and costs nothing.

## Suggested implementation steps

1. Write `footprint_cells(bodies, id)` from `radius`, returning a small range
   rather than a list.
2. Write the `striding` row calling into the walking step's machinery with the
   footprint check substituted, not duplicating it.
3. Wire the footprint into the bucket placement and into the meet pass's
   neighbourhood.
4. Write the wait: a strider whose destination footprint is occupied holds its
   position and re-decides, rather than pathing around, which would make a
   corridor full of dinosaurs thrash.
5. Test: a dinosaur cannot enter a one-cell corridor and a little guy can, on the
   same maze, from the same cell. A dinosaur appears in every bucket of its
   footprint and no others.

## Related documents and tools

- [Dinosaurs in a habitat](../docs/019-dinosaurs-in-a-habitat.md)
- [Bodies are bucketed by cell](308-bodies-are-bucketed-by-cell.md)

# 105 — The Maze Is A Spanning Tree Over Rooms

| | |
| --- | --- |
| Phase | 1 — The Stone |
| Blocked by | 103, 104 |
| Blocks | 106, 108 |
| Reads | [carving the maze](../../docs/003-carving-the-maze.md) |
| Open questions | none |

## Current behavior

A spanning **forest**, not a tree, and it runs after the staircases rather than
before them.

A single walk carves exactly the terrace it started on and stops, because the
height filter will not let it step across a four-layer terrace edge. Every other
terrace was left with all its links closed — solid, with nothing inside it, which
looks entirely deliberate from above. The walk now restarts from every room it
has not reached, and each restart carves another terrace.

The flights laid by issue 106 arrive already open and the carver may add to them
but never take one away. Braiding reopens a fraction of the closed links where
the height rule permits.

## Intended behavior

The second generator pass. A randomized depth-first walk over the room lattice
that opens the link cell between each pair it steps across, leaving behind a
spanning tree — a maze with exactly one route between any two rooms.

The walk's neighbour relation is **filtered by height**. From a room at height
`h`, a room two cells away at height `h'` is a candidate only when `|h - h'|` is
at most two, because two is the largest gap a single link cell can bridge:

| Difference | The link's height | The climb |
| --- | --- | --- |
| 0 | the same | flat |
| 1 | the lower room's | one step |
| 2 | one above the lower room | two steps of one |
| 3 or more | — | needs [a staircase](106-staircases-are-cut-not-built.md) |

So this pass leaves several components behind wherever a slab was piled higher
than two layers in one place, and that is expected and correct. Issue 106 joins
them.

Then **braiding**: a `braid` fraction of the still-closed links are reopened at
random. A perfect maze has no loops, and on a maze with no loops there is one
route between any two rooms, so a chase has a known ending and a body fleeing is
always cornered. [The games](../../docs/020-games-that-creatures-play.md) need loops
to exist at all.

The walk is iterative with an explicit stack. A recursive one blows the Lua
stack somewhere around a few thousand rooms, which a 129-cell maze reaches, and
it does it as a crash that looks unrelated to the maze.

## Suggested implementation steps

1. Write the room-neighbour iterator: the four rooms two cells away, in an order
   shuffled from the `carve` stream, filtered by the height rule above.
2. Write the walk with an explicit stack of room indices and a visited bitmap.
   Record, per opened link, the height it should take from the table above.
3. Record which rooms were reached. Rooms left unvisited are components for the
   next pass to join.
4. Braid: sweep every closed link, draw from the `braid` stream, reopen those
   under the threshold — but only where the height rule permits, or the braid
   would open links a body cannot use and the maze would look connected where it
   is not.
5. Report the component count and the sizes, since that number is what issue 106
   consumes and what issue 108 asserts about.
6. Test: same seed, same maze. Every opened link's height is within one of both
   rooms it joins. Every visited room is reachable from the walk's start by
   opened links only.

## Related documents and tools

- [Carving the maze](../../docs/003-carving-the-maze.md)
- [Staircases are cut, not built](106-staircases-are-cut-not-built.md)

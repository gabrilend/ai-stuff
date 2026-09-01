# 106 — Staircases Are Cut, Not Built

| | |
| --- | --- |
| Phase | 1 — The Stone |
| Blocked by | 104, 105 |
| Blocks | 108 |
| Reads | [carving the maze](../../docs/003-carving-the-maze.md) |
| Open questions | none |

## Current behavior

Flights are laid **before the maze is carved**, not cut into it afterwards, and a
flight is expressed entirely in the room heights.

Cutting into a finished maze was tried first and is the wrong architecture. A
flight that lands correctly still drops the room it passes through three layers
below the corridor that room belonged to, severing whatever was reachable only
through it — so the flight joins two pieces and breaks a third, the count of
pieces does not fall, and the flight is rejected. Six hundred per maze were built
and thrown away, terraces stayed unreachable, and the generator blamed its
parameters while its own diagnosis reported hundreds of perfectly good places to
put a staircase.

Placing them first costs almost nothing, because rooms sit two cells apart and
the link between two rooms two layers apart takes the height exactly between
them. **A run of rooms whose heights step by two is already a staircase of
single-layer steps** once the realise pass fills the links in. So a flight is:
set the rooms along the way to h+2, h+4, …, and force the links between them
open. Nothing here touches stone.

The destructive version survives as the repair pass, which on a healthy maze
finds nothing to do — and that claim is worth testing on every maze, which is why
it still runs.

## Intended behavior

Cut staircases until one piece remains.

A staircase is a **straight run of cells** whose heights step by exactly one
layer from the low end to the high end. Take the closest pair of rooms in two
different components; take the run between them; overwrite the height of each
cell in the run so it ramps.

The word that matters is **cut**. Where the run passes through a slab, the slab
is notched — cells are lowered into steps. Where it passes over open ground, the
ground is raised. In the reference picture every staircase is a gash cut into the
side of a block, not a structure standing on top of one, and that is why this
pass runs after the terraces rather than before: there has to be something to cut
into.

Cutting a run through a terrace can sever a branch of that terrace's maze, since
lowering a cell by three disconnects it from neighbours it used to reach. That is
acceptable and it is why [the validator](108-the-validator-refuses-a-broken-maze.md)
runs afterwards rather than being trusted to be unnecessary.

The pass repeats until one component remains or `stair_attempts` is exhausted.
**Running out is an error**, loudly, with the component sizes printed. It is not
repaired with a fallback tunnel: a maze needing a fallback to be connected is a
maze whose parameters are wrong, and hiding that behind a repair means the
parameters stay wrong forever. Warnings are errors here.

## Suggested implementation steps

1. Label components over the opened-link graph — flood fill, iterative.
2. For each pair of adjacent components, find the closest room pair by walking
   the border rather than by comparing every room to every room, which is
   quadratic in a maze with thousands of rooms.
3. Choose the pair from the `stair` stream among the closest few rather than
   taking the single closest, so that two mazes from adjacent seeds do not both
   put their staircase in the same obvious place.
4. Cut the run: walk from low to high, setting each cell's height one above the
   last. Mark those cells as stair cells so pass four does not overwrite them.
5. Re-label and repeat.
6. Fail loudly on exhaustion, printing the count and the sizes.
7. Test: after this pass the component count is one; every stair run's
   consecutive heights differ by exactly one; a stair's ends are at the heights of
   the rooms it joins.

## Related documents and tools

- [Carving the maze](../../docs/003-carving-the-maze.md)
- [The validator refuses a broken maze](108-the-validator-refuses-a-broken-maze.md)

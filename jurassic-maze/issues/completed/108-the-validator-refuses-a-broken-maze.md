# 108 — The Validator Refuses A Broken Maze

| | |
| --- | --- |
| Phase | 1 — The Stone |
| Blocked by | 102, 104, 105, 106, 107 |
| Blocks | 206, and every phase after |
| Reads | [carving the maze](../docs/003-carving-the-maze.md), [ways this could go wrong](../docs/027-ways-this-could-go-wrong.md) |
| Open questions | none |

## Current behavior

Runs on every generated maze. Hard errors: a column with a hole in it, a floor
cell not standing on its own height, a rim cell that is floor, or a floor in more
than one mutually-reachable piece. Counted: surfaces, wall-top pieces, dead ends,
ledges, the diameter, and the fill fraction.

Connectivity floods **through floor only**. Flooding through every cell and then
counting which pieces happen to contain floor reports a maze as whole that is
not: two terraces with no staircase between them are joined by any chain of wall
tops that happens to run between them at climbable heights — a route along the
tops of the walls, which nothing can reach and nothing would take. The generator
then cuts no staircase, believing there is nothing to join.

The failure message carries a diagnosis: per piece, its size, its height range,
how many straight runs out of it reach other floor, and how much longer the
shallowest flight would need to be. "It is in four pieces" is not actionable on
its own.

## Intended behavior

Every generated maze goes through the validator before anything else sees it.
The validator's findings split cleanly into two kinds, and the split is the
point:

**Hard errors — the maze is not returned.**

- More than one connected component. A maze in two pieces is a maze where bodies
  pile up in whichever piece they spawned in, and from a camera two hundred cells
  away that looks like a busy corner and a quiet one. It looks exactly like a
  maze working.
- A column that is not height-shaped, until something deliberately makes one.
- A surface outside the layer range, or a cell outside the footprint.
- A rim cell that is not wall. The rim is the only thing stopping a body leaving
  the world.

**Counted, reported, and not fatal.**

- **Pits** — surfaces a walker can enter and not climb out of. Legal, and worth
  counting, because a maze full of them slowly drains the aquarium into a corner.
- **The longest shortest path** between two rooms. Not a correctness question at
  all. It is the number that says whether the maze is interesting, and a maze
  whose longest path is short is a maze that is mostly plaza.
- The height histogram, the surface count, the stair count, the largest bucket a
  spawn would land in.

A warning is an error here. Anything that is genuinely acceptable is *counted*,
which is a number in a report, not a message in a log that gets ignored the first
time and becomes invisible the second.

## Suggested implementation steps

1. Write the component count using the labels from issue 107 — they are already
   computed, so this is a sweep and a set.
2. Write the pit check: for each surface, whether any of the four directions
   gives a not-blocked answer with the walker's climb limit. A surface with none
   is a pit; a surface reachable only downward is the interesting case and needs
   the reverse test too.
3. Write the longest shortest path by breadth-first search from the surface
   furthest from an arbitrary start, then again from what that finds — the
   standard two-sweep trick. It is not exact on a graph with cycles and it is
   close enough for a number that exists to be compared against itself.
4. Write the report as a table of named numbers, not as printed prose, so the
   headless runner and the phase demo can both consume it.
5. Make the hard errors raise with the seed and the parameters in the message. A
   maze that failed and cannot be regenerated is not a bug report.
6. Test: a hand-built maze in two pieces is rejected; a hand-built maze with a
   pit is accepted and the pit is counted; a generated maze from a fixed seed
   produces exactly the report it produced last time.

## Related documents and tools

- [Carving the maze](../docs/003-carving-the-maze.md)
- [Ways this could go wrong](../docs/027-ways-this-could-go-wrong.md)
- `./run-maze --describe`

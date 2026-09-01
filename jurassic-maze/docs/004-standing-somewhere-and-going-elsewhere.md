# Standing Somewhere And Going Elsewhere

Where a body is, and whether it may move, are two questions with exact answers.
This page gives both, because every kind of creature in the project asks them and
they must all get the same reply.

## Where a body is

A **stance** is two numbers: a cell index and a layer.

| Field | Type | Meaning |
| --- | --- | --- |
| `cell` | integer | `x + y * width`, the column the body is over |
| `layer` | integer, 0 to 31 | the surface it is standing on, meaning the top of the stone block in that layer |

A stance is only valid when that layer really is a surface of that column —
stone with air above it. Any code that constructs a stance out of thin air is
wrong; stances come from the generator, from a spawn point, or from a move that
was checked.

A body that moves continuously carries a fractional position **as well**, but
its stance is still exactly this, rounded to the cell it is over. The stance is
the truth about which stone it is on; the fractional position is the truth about
where in the cell it is. See
[a body and what it carries](011-a-body-and-what-it-carries.md).

## Whether it may move

Given a stance and one of the four compass directions, there is exactly one
answer, and it is one of four kinds:

| Answer | When | What happens |
| --- | --- | --- |
| **flat** | the neighbour has a surface at the same layer | walk onto it |
| **step up** | the neighbour has a surface at `layer + 1`, and there is headroom | climb it |
| **step down** | the neighbour's highest surface below the current layer is within `drop_limit` | walk down onto it |
| **blocked** | anything else | the move does not happen |

That is the whole rule, and it is one function that every locomotion kind calls.
It is not reimplemented per creature. A dinosaur and a ball and a stone golem all
get the same answer to the same question, which is the only way the maze can be
trusted to mean one thing.

### The two limits, and why they are different numbers

`climb_limit` is **one layer** and it is not a knob anybody should turn. It is
the number the generator's `wall_rise` was chosen against: a wall stands two
layers above the corridor precisely because one layer is climbable and two is
not. Raising the climb limit to two does not make bodies more agile, it deletes
every wall in the maze.

`drop_limit` is **two layers for a walker** and is per-creature rather than
global, because falling is not the same act as climbing. A body may safely go
down further than it can come up, which is why a maze can collect bodies in a pit
— they walk in, and cannot walk out. The validator counts those pits for exactly
that reason.

A ball has no drop limit at all. It leaves the ledge and
[gravity takes it](013-rolling-with-momentum.md). What a walker treats as a wall
it must go around, a ball treats as a cliff it goes over. Same stone, same
question, different creature, different answer — and that difference lives in
the creature's row of the locomotion table and nowhere else.

### Headroom

A step up is only a step up if the body fits. A body has a **height in layers**
— one for a ball or a person, two for most dinosaurs, three for a stone golem.
Before entering a cell, the number of consecutive air layers above the
destination surface is counted, and if it is less than the body's height the
move is blocked no matter how flat the floor is.

Nothing today has a ceiling over it, so this check always passes and could be
deleted. It is not deleted, because [the delve](021-the-delve.md) is a dungeon
and a dungeon has ceilings, and a check that was never written is much harder to
add than one that was written and always passed.

## The surface graph

The four-answers rule above, applied to every surface and every direction,
defines a graph. That graph is what pathfinding walks, what the validator counts
components of, and what a
[graph-walking creature](014-walking-the-surface-graph.md) moves along.

It is **not stored**. There is no adjacency list anywhere in the project. The
neighbours of a stance are computed when asked, out of four columns and a
handful of bit operations, and the computation is cheaper than the cache miss
that reading a stored list would have cost. A stored graph would also be a
second copy of the maze that has to be invalidated every time a golem walks
through a wall, and there is no version of that which does not eventually
disagree with the stone.

What *is* stored is the **component label** — one small integer per surface,
saying which connected piece of the maze it belongs to. It is computed once
after generation, it answers "can this body possibly reach that body" in one
comparison instead of a search, and it is what the validator asserts is uniform.

## Diagonals, and why there are none

Movement is four-directional. A body cannot cut a corner.

This is a choice and it has a cost: paths look slightly boxy, and a creature
crossing an open terrace takes a staircase pattern instead of a straight line.
The reason to accept that cost is that a diagonal move between two open cells
whose two shared neighbours are both wall would have a body passing through the
seam where two stone blocks meet, and the only ways out of that are to forbid the
move as a special case, or to let bodies clip through corners. Both are worse than
boxy paths.

Continuous movers are not bound by this. A rolling ball has a real velocity
vector pointing wherever it likes, and it collides against
[wall faces](013-rolling-with-momentum.md) rather than asking this question at
all. The four directions are the *graph's* structure, not the world's.

## Related documents and tools

- [The stone and what is inferred](002-the-stone-and-what-is-inferred.md) — where surfaces come from
- [Locomotion is a dispatch table](012-locomotion-is-a-dispatch-table.md) — who asks this and who does not
- `./run-maze --describe` — reports the component count and the pit count

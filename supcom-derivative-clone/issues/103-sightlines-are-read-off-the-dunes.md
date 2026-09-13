# 103 — Sightlines are read off the dunes

| | |
| --- | --- |
| Phase | 1 — The Dunes and the Clock |
| Blocked by | 102 |
| Blocks | 205 |
| Reads | [the dunes and the sightlines](../docs/002-the-dunes-and-the-sightlines.md) |
| Open questions | C2 |

## Current behavior

Nothing. The question "can this point see that point" is described in the dunes
document and answered by nothing. The phase 1 test program looks for a source
file whose stem is `sightlines` and reports its absence by name.

## Intended behavior

One function answers the most-asked question in the simulation:

    can_see(field, x1, y1, eye, x2, y2, profile)  ->  boolean

The viewer stands at the first position with its eye `eye` above the ground
there; the target stands at the second with its profile `profile` above the
ground there. The answer is true if the straight segment between those two
heights never passes below the ground at any cell it crosses. There is **no
maximum distance**: range is unlimited and the field is folded, and every fold
is a wall.

Both endpoint heights are computed from the field, so a plane is a target whose
profile is its flight altitude plus its hull, and an enforcer is a viewer whose
eye is the highest of any land unit — and is seen over more crests too, because
the same function is asked the other way round.

Two things keep it cheap:

- **A coarse pass first.** The lower of the two endpoint heights is compared to
  the tallest cell in every coarse region the segment crosses, read from the
  field's `tallest` array. If the segment's lowest point is above all of them,
  the answer is true without a walk.
- **The walk is a straight loop over integers.** The cells a segment crosses are
  found by a grid traversal, and at each crossed cell the segment's height is
  interpolated by how far along the segment the cell's centre projects. A
  single cell where ground exceeds the segment ends the walk with false.

The function is pure over the field and its arguments, with one exception kept
on purpose: a count of questions asked, readable through `questions_asked()`
and cleared by `reset_questions()`, because whether the coarse pass suffices is
a measurement the headless runner reports, not an argument.

Every position is a double and every cell is an integer, and the same operations
in the same order produce the same booleans on every machine.

## Suggested implementation steps

1. Claim the file with `./new-source-file --summary "Answers whether one point sees another over the dunes." sightlines`.
2. Write the grid traversal as its own folded function: start cell, end cell,
   and a step that yields each crossed cell in order.
3. Write the coarse pass over the `tallest` regions the traversal touches.
4. Write `can_see` as the coarse pass, then the walk, comparing interpolated
   segment height to ground at each cell strictly between the endpoints.
5. Write the counter and its two accessors.
6. Fill the companion, and state in it that the endpoints themselves are never
   tested — a unit always sees its own cell.

## Related documents and tools

- [The dunes and the sightlines](../docs/002-the-dunes-and-the-sightlines.md)
- [A unit and what it carries](../docs/004-a-unit-and-what-it-carries.md)
- The test program: [the dunes and the clock](../tests/019-the-dunes-and-the-clock.lua)

## Still open

- C2: whether units block sightlines. The working ruling is no — only ground
  blocks sight — and this function reads nothing but the field.
- Whether the coarse pass needs a second level for large fields. The runner's
  count of questions and their cost is what answers it.

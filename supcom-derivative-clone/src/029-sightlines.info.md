# 029-sightlines

Answers whether one point sees another over the dunes.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

The question every shooter asks of every candidate: can this point see that
one? The viewer's eye is `eye` above the ground at its position; the target's top
is `profile` above the ground at its. The answer is true when the straight
segment between those two heights is never below the ground of any cell it
crosses. There is no maximum distance. Only ground blocks a sightline; units do
not (open question C2's working ruling), and this file reads nothing but the
field and its arguments.

Positions are in cell units with each cell's centre at its integer coordinates,
the same rule as `cell_of` in the dunes. The two end cells are never tested: a
unit always sees out of its own cell and is always seen in its own.

How the answer is found:

1. **The coarse pass.** The lower of the two end heights is compared with the
   tallest cell of every coarse region the segment crosses (the field's
   `tallest`). If it is above all of them, the answer is true without a walk. A
   field built by hand without regions skips straight to the walk; the coarse
   pass is only ever a short cut to the walk's own answer.
2. **The walk.** The cells the segment crosses are visited in order by a grid
   traversal (Amanatides and Woo's). At each one strictly between the ends, the
   cell's centre is projected onto the segment and the segment's height there is
   interpolated between the two ends; ground above that height ends the walk
   with false. Where the segment passes exactly through a cell corner, both
   neighbours are visited, x first -- grazing two crests at once is blocked by
   either.

The walk always runs from the end that comes first in row order, swapping the
heights with the ends, so the answer is the same whichever way round it is
asked when eye and profile are equal. The same doubles in the same order give
the same booleans on every machine.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `can_see(field, x1, y1, eye, x2, y2, profile)` | a field with `size` and `height` (and, when raised, `region`, `regions`, `tallest`); viewer position and eye height; target position and profile height, all numbers | a boolean |
| `questions_asked()` | | how many questions have been asked since the last reset |
| `reset_questions()` | | nothing; clears the count |

## Data structures it owns

One integer: the count of questions asked. It is the only state in the file,
kept on purpose, because whether the coarse pass is enough is a measurement the
headless runner reports.

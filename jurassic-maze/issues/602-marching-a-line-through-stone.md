# 602 — Marching A Line Through Stone

| | |
| --- | --- |
| Phase | 6 — The Habitat |
| Blocked by | 101 |
| Blocks | 603, 604, 707 |
| Reads | [line of sight through stone](../docs/018-line-of-sight-through-stone.md) |
| Open questions | 8 (does a creature remember) |

## Current behavior

Every creature knows where every other creature is, always.

## Intended behavior

Can the body at surface A see the body at surface B? Answered by marching the
straight line between them in three dimensions and testing the stone at each
step. Reach B, there is sight; hit stone, there is not.

The march visits cells, in steps of at most half a cell so none is skipped, and
each step is **one array read and one bit test**. That cheapness is what makes
asking it often affordable, and it is a direct consequence of
[the column being one integer](completed/101-a-column-is-one-integer.md).

The height along the line is interpolated between the two surfaces, both raised
by an **eye height** of one layer. Without the offset the line runs exactly along
the surface and grazes every block, so two creatures on the same terrace cannot
see each other across a completely open plaza.

Bounded by `sight_range` — beyond it the answer is no with no marching, two
subtractions and a comparison.

**Asked on a cadence, not every tick**, and each body carries a phase offset so
the population does not all check on the same tick and produce a periodic stall.
Spreading regular-but-not-urgent work by giving each body a phase is a technique
worth naming, because the cost becomes flat instead of spiky.

Deliberately not modelled: no cone of vision (a facing cone means creatures can
be snuck up on, which is a game mechanic and this is not a game), no light, and
no memory.

## Suggested implementation steps

1. Write the march with a fixed step, not a Bresenham variant — the third
   dimension and the fractional endpoints make the integer version more code for
   no gain at these lengths.
2. Write the eye-height offset and comment it with the open-plaza failure.
3. Write the cadence with the per-body phase offset.
4. Count sight checks per tick into the report; a number that spikes means the
   phase offsets are not spread.
5. Test: two bodies with a wall between them cannot see each other; the same two
   with the wall lowered by one layer can. A body can see another across an open
   terrace at every distance up to `sight_range` and none beyond.

## Related documents and tools

- [Line of sight through stone](../docs/018-line-of-sight-through-stone.md)

## Still open

Open question 8: remembering the last known position is one field and it is what
makes a search look intelligent rather than random. Not built, not forgotten.

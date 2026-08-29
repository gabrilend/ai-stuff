# 505 — The Weave

| | |
| --- | --- |
| Phase | 5 — Filters and the Weave |
| Blocked by | 204, 503, 504, 506 |
| Blocks | — |
| Reads | [filters and the weave](../docs/006-filters-and-the-weave.md) |
| Open questions | — |

## Current behavior

Interwoven filters are grouped but not resolved. Drawing them in turn buries all
but the last.

## Intended behavior

Interwoven hatchings **pass over and under each other**, the way basket weave
does, so that no filter is ever wholly hidden by another.

### Why stacking fails and weaving does not

Two hatchings drawn one on top of the other bury one of them. At three it is mud.
The lower filters are still being drawn — they are simply not visible, which is
worse than not drawing them, because the person believes they are looking at
three things.

Weaving shares the **crossings** rather than ordering the **layers**. Every filter
gets an equal share of the overs, so every one stays readable, and the arrangement
degrades gracefully as more are added instead of collapsing at three.

### The rule

Weaving is a property of the crossings, not of either thread, so the interwoven
set **cannot be drawn by looping over filters**. They resolve together, in one
pass.

Number the lines in each filter's hatching. Where a pixel falls inside a stroke of
more than one filter at once, **sum the line indices of every filter crossing
there and take it modulo how many are crossing**; that picks which is on top at
that spot.

With two filters, line *i* of one crossing line *j* of the other puts the first on
top when *i + j* is even and the second when it is odd — so the two hatchings pass
over and under each other down the whole block, and neither dominates.

### Why a shader, and how it works out

For each pixel:

1. read its place from the identity buffer — [204](204-the-identity-buffer.md)
2. for each active interwoven filter, get that place's reading for the current
   person; skip it if the answer is nothing
3. from the reading, get the spacing; from the pixel's painting position and the
   filter's angle, get its line index and whether it lies within a stroke
4. collect the filters whose strokes contain this pixel
5. if one, paint it. If several, sum their line indices, take modulo the count,
   and paint the winner
6. if none, leave the painting showing through

That is a handful of arithmetic per filter per pixel, with no branching on data
that varies across the surface except the count — which is what makes it
affordable at any number of filters.

## Suggested implementation steps

1. Pass the active interwoven filters to the shading pass as a set, with colour,
   angle and mode.
2. Compute the line index analytically: project the painting position onto the
   axis perpendicular to the angle, divide by spacing, take the whole part; the
   fractional part says whether it is within a stroke.
3. Implement the parity resolution exactly as written; a subtly different rule
   produces a grid rather than a weave and it looks wrong without being nameable.
4. Order the set consistently frame to frame, so the modulo picks the same winner
   at the same crossing and the pattern does not shimmer.
5. Test visually with two filters at forty-five degrees to each other, and confirm
   both threads are continuously traceable across a block.
6. Test with four, and confirm none has disappeared.

## Related documents and tools

- [Filters and the weave](../docs/006-filters-and-the-weave.md)
- [506 — hatching anchored to the ground](506-hatching-anchored-to-the-ground.md)

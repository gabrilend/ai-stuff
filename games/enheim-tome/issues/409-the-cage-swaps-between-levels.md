# 409 — The Cage Swaps Between Levels

| | |
| --- | --- |
| Phase | 4 — The Places |
| Blocked by | 206, 207, 405, 408 |
| Blocks | — |
| Reads | [the map surface](../docs/002-the-map-surface.md) |
| Open questions | — |

## Current behavior

The cage shows one level at a time and the zoom picks which. Crossing from one
level to the next replaces every line on the map at once, in a single frame.

## Intended behavior

**Cross-fade the two levels through each other**, over a short interval, rather
than cutting.

A cut replaces the entire cage between one frame and the next. Every line you
were reading vanishes and a different set appears, and because they are all the
same colour there is no visual continuity to carry your eye across — it reads as
a glitch rather than as a change of scale.

Crossing back and forth over the threshold while nudging the zoom would then
strobe, which is much worse than either state.

## What this issue is instead of

It was going to be *the cage at four weights* — quadrant heaviest down to
building finest, so the hierarchy could be read from line thickness.

That is gone, and for a good reason: **the line is one pixel, so it is one colour
for all lines**, and a single pixel carries neither a weight nor a gradient. The
hierarchy is expressed by *which* level is drawn rather than by how it is drawn.
See [207](207-the-cage-shows-one-level.md).

Which leaves this issue with the one thing the swap still needs: how it looks
while it happens.

## Hysteresis, not just a fade

A fade alone does not stop the strobing — it makes each strobe smoother. What
stops it is **not putting the boundary at a single value**: the level rises at
one zoom and falls at a different, lower one, so sitting exactly on the threshold
is impossible.

The two ought to be far enough apart that ordinary nudging never crosses both,
and close enough that the level you get always feels like the one you asked for.

## What must not happen during a swap

**Selection is not lost.** If a block is selected and you zoom out until districts
are the level, the block stays selected — the cage stopped showing block
boundaries, which is a statement about drawing rather than about what you were
looking at. The tome keeps showing the block.

Otherwise zooming out to see where something sits would be a way of forgetting
what you were looking at, which is the opposite of what a person wants when they
zoom out.

## Suggested implementation steps

1. Two thresholds per level boundary rather than one, from
   `input/what-to-start-with`.
2. Hold both levels' edge sets during the crossing and draw each at a share of
   full, summing to one, so total ink stays roughly constant.
3. Keep the interval short — a fraction of a second. This is a transition, not an
   animation to be admired.
4. Leave the selection alone across a swap, and confirm the tome does not change.
5. Test by zooming slowly across a boundary and back, watching for any frame in
   which the map has no cage at all, and for strobing when parked on the
   threshold.

## Related documents and tools

- [207 — the cage shows one level](207-the-cage-shows-one-level.md)
- [408 — the zoom picks the level](408-the-zoom-picks-the-level.md)

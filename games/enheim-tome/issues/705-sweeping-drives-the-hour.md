# 705 — Sweeping Drives the Hour

| | |
| --- | --- |
| Phase | 7 — The Day |
| Blocked by | 507, 702, 704 |
| Blocks | 706 |
| Reads | [the day and the curve](../docs/008-the-day-and-the-curve.md) |
| Open questions | — |

## Current behavior

Curves draw. Nothing happens when you touch one.

## Intended behavior

Dragging along a curve **drives the global hour**, so everything that reads the
hour moves with your mouse:

- the great willow's shadow swings across the north-west
- **everybody** slides along their own day, not only the person whose curve you
  are touching
- that person's block glows, so you can see where they are as you sweep

The city becomes one thing you can play backwards and forwards by hand.

### It is a reading, not a journey

Nothing is being advanced. The world does not move — see
[702](702-the-world-advances-on-a-move.md). Sweeping consults your model of what
people do, which is what planning is.

This is why the interface needs no "you are looking at a hypothetical" indicator,
and why the whole class of problems around scrubbing a live clock does not exist
here.

### Every curve moves, not just the one under your hand

Worth being explicit, because the tempting implementation moves only the curve
being touched.

The hour is **global** — [701](701-the-hour-is-global.md) — so the mark showing
the current hour moves on every visible curve at once. Sweeping one person's
morning shows you **the whole city's morning**: who else is busy at the moment
this one is idle, who is at rest when everyone else is working.

With several curves pinned, that is the feature. One curve alone would be a
readout; several make it an instrument for noticing.

### The hour has many drivers now

Its own control, and every visible curve. So the value must live in one place with
one setter, and each driver calls it rather than keeping its own idea of the time.

## Suggested implementation steps

1. On drag within a curve, map the horizontal position to an hour and set the
   global hour.
2. Clamp to the day's ends rather than wrapping — sweeping off the right edge
   should stop at the end of the day, not jump to dawn.
3. Glow the block that person occupies at that hour, using
   [703](703-whereabouts-is-a-function.md) and the existing glow.
4. Redraw the hour mark on **every** visible curve from the shared value.
5. Ensure the shade filter and every other hour-reading filter re-evaluate.
6. Test that sweeping one curve moves the hour mark on three pinned curves and
   changes the shade hatching, all from one drag.

## Related documents and tools

- [The day and the curve](../docs/008-the-day-and-the-curve.md)
- [The map surface](../docs/002-the-map-surface.md)

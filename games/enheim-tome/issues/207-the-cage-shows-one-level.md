# 207 — The Cage Shows One Level

| | |
| --- | --- |
| Phase | 2 — The Cage |
| Blocked by | 102, 205, 206 |
| Blocks | 408, 409 |
| Reads | [the fence network](../docs/004-the-fence-network.md) |
| Open questions | — |

## Current behavior

Every edge in the network draws whenever it is on screen, so the whole-city view
is a wireframe drawing of two thousand blocks rather than a painting.

## Intended behavior

**Draw the boundaries of the level you can currently select. Only those.**

At the city view you are selecting quadrants, so you see the two dozen quadrant
lines over an otherwise clean painting. Descend and the cage **swaps** to
districts. Descend again and it is blocks, then buildings.

```
   far out          mid              close
   ┌────────┐      ┌────────┐      ┌────────┐
   │   │    │      │ │ │  │ │      │┬┬│┬│┬┬││
   │───┼────│      │─┼─┼──┼─│      │┼┼┼┼┼┼┼┼│
   │   │    │      │ │ │  │ │      ││┬│┬┬│┬││
   └────────┘      └────────┘      └────────┘
    quadrants       districts        blocks

   the cage swaps as you descend. It does not thicken.
```

## Why this replaced a fade

The first version of this issue had every boundary fading in on its own
on-screen width, ramping from nothing to solid between about 24 and 64 pixels.
It carried three problems, and **one decision removed all three**: *the line is
one pixel, so it is one colour for all lines.*

A single pixel cannot carry a gradient. So there is no opacity to ramp, no
weights to distinguish levels by, and — most importantly — **nothing for two
places to disagree about**.

That last one was the real fault. Since the fence runs down the middle of a
street, nearly every edge in the city is shared by exactly two blocks, and each
would have wanted its own opacity. A harbour block 300 pixels across against an
alley 28 pixels across, one line, one stroke, two different answers. Taking the
larger left small blocks with lopsided part-drawn outlines; taking the smaller
put faint patches in large ones that read as the drawing failing; drawing it
twice made shared edges brighter than unshared ones.

With one colour there is no number to arbitrate. The question stops being *how
brightly* and becomes *whether*, and the answer to that already existed in the
design.

## It makes an existing promise exactly true

[408](408-the-zoom-picks-the-level.md) says the zoom decides which level a click
selects, and claimed that what you can select is what you can see outlined. With
a fade that was approximate — a place could be half-drawn and fully selectable.

Now it is exact. **The cage is the set of things you can click.** The interface
never has to explain itself, because the visible lines *are* the explanation.

## It bounds its own density

Nothing needs to cap how much is drawn. Blocks only become the selectable level
when they are roughly 24 to 64 screen pixels across, which at a 1180-wide pane is
around 250 of them on screen. You never see the whole city's blocks at once,
because by the time blocks are the level you are not looking at the whole city.

## Three things it deletes

- **the opacity ramp** and its two tunable thresholds
- **the hover override** — *whatever is under the pointer draws at full strength*
  existed to rescue places too small to draw, and at the selectable level nothing
  is ever too small
- **per-place on-screen size in the drawing** — size still chooses the level, once
  per frame, but no longer touches any edge

## Suggested implementation steps

1. Ask [408](408-the-zoom-picks-the-level.md) for the current selectable level.
2. Get that level's boundary edges — for blocks, every edge; for coarser levels,
   the derived sets from [405](405-boundaries-derived-from-members.md).
3. Cull to the visible rectangle and stroke each once, one pixel, one colour, in
   screen space — [206](206-the-fence-is-one-pixel-in-screen-space.md).
4. Do not vary anything per edge. If a variable enters this drawing, the decision
   above has been lost.
5. Check by eye that the whole-city view reads as a painting with a few dozen
   lines on it, and that descending swaps the cage rather than adding to it.

## Related documents and tools

- [The fence network](../docs/004-the-fence-network.md)
- [409 — the cage swaps between levels](409-the-cage-swaps-between-levels.md) — what the swap looks like

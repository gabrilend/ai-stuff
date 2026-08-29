# 206 — The Fence Is One Pixel, in Screen Space

| | |
| --- | --- |
| Phase | 2 — The Cage |
| Blocked by | 102, 201 |
| Blocks | 207, 409 |
| Reads | [the fence network](../docs/004-the-fence-network.md) |
| Open questions | — |

## Current behavior

The network exists and can be walked. Nothing draws it.

## Intended behavior

The cage is drawn **outside the map's zoom transform**. Each vertex is converted
from painting pixels to screen pixels by hand, and the line is stroked at a
literal width of one.

### Why not inside the transform

Because then the line's thickness scales with the zoom, and there is no width that
works at both ends of the range. At the whole-city view a one-painting-pixel line
is a fifth of a screen pixel — invisible. At native zoom the same line drawn to
survive that would be a fat three-pixel worm across the streets.

Drawn in screen space it is **exactly one pixel at every zoom**, which is what
makes it read as a cage laid over the painting rather than as paint on it. The
painting keeps its own detail; the cage is clearly a separate, thinner thing.

### What gets stroked

A block's boundary as yielded by the walk in
[201](201-vertices-edges-and-loops.md), converted point by point. Shared edges are
stroked **once**, not once per adjoining block — drawing them twice doubles the
work and produces subtly heavier lines wherever two blocks meet, which reads as an
inconsistency nobody can name.

So the natural unit to draw is the **edge**, not the block. Walk the edge table,
stroke each edge once, and the cage emerges. Block loops matter for filling and
hit-testing; edges matter for stroking.

### Culling

Only edges whose extent intersects the visible rectangle are converted at all.
With around two thousand blocks the untouched majority should cost nothing.

## Suggested implementation steps

1. Walk the edge table rather than the block table.
2. Cull by each edge's bounding box against the visible rectangle, computed in
   painting space before any conversion.
3. Convert the surviving paths point by point into screen coordinates.
4. Stroke at width one, with no scaling applied, antialiased so a diagonal lane
   does not stair-step.
5. Confirm by eye that the line is the same weight at 0.192 and at 1.0 — this is
   the check that the transform was genuinely escaped rather than merely
   compensated for.
6. Confirm that a shared street shows one line, not two.

## Related documents and tools

- [The fence network](../docs/004-the-fence-network.md)
- [The map surface](../docs/002-the-map-surface.md)

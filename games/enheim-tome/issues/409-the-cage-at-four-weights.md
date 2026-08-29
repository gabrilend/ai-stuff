# 409 — The Cage at Four Weights

| | |
| --- | --- |
| Phase | 4 — The Places |
| Blocked by | 206, 207, 405, 408 |
| Blocks | — |
| Reads | [the fence network](../docs/004-the-fence-network.md) |
| Open questions | — |

## Current behavior

Every fence draws at the same weight, so the city has no visible structure above
the block.

## Intended behavior

Four nested boundaries, four line weights: **quadrant heaviest, then district,
then block, with buildings finest**.

### The existing rule does the rest

Nothing new decides when each appears. Because every boundary already fades on its
own on-screen width — [207](207-each-boundary-fades-on-its-own-size.md) — the
hierarchy sorts itself out:

| Zoom | What is wide enough to draw |
| --- | --- |
| whole city | quadrants only — the map shows the great divisions |
| descending | districts appear |
| closer | blocks |
| close | buildings |

**The cage thickens and deepens together as you go in.** No level-of-detail
system, no per-level thresholds, no switching. One rule, applied to four sets of
edges.

### An edge belongs to more than one boundary

A street between two districts is a block boundary *and* a district boundary, and
possibly a quadrant boundary too. It must be stroked **once, at the heaviest
weight that applies**, not three times.

Drawn three times, the line would be darker there than elsewhere in a way that
looks like an artefact, and it would cost three times the work on exactly the
edges that appear most often.

So the drawing walks edges, and for each asks the highest level at which it is a
boundary — using the derived sets from
[405](405-boundaries-derived-from-members.md) — then strokes once.

### Weight is in screen pixels

Like the block fence, weights do not scale with zoom. A quadrant boundary is
perhaps three screen pixels and a building's is one, at every zoom. See
[206](206-the-fence-is-one-pixel-in-screen-space.md).

The four weights come from `input/what-to-start-with`, because the difference
between a legible hierarchy and a muddy one is a matter of a pixel either way and
wants adjusting against the real painting.

## Suggested implementation steps

1. Build, per edge, the highest level at which it is a boundary — from the derived
   boundary sets, computed once and cached with them.
2. Walk edges once; stroke at the weight of that level, with the opacity from the
   fade rule applied to **the place whose boundary it is at that level**, not to
   the block.
3. Keep the hover and selection override, which still draws the pointed-at place
   at full strength whatever its size.
4. Confirm by eye at the whole-city view that the four quadrants read clearly and
   nothing finer is visible; then descend and confirm each level arrives in turn.
5. Confirm no edge is drawn twice by counting stroke calls against distinct edges
   in view.

## Related documents and tools

- [The fence network](../docs/004-the-fence-network.md)
- [The map surface](../docs/002-the-map-surface.md)

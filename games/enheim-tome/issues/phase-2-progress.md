# Phase 2 — The Cage

The fence network as a structure and as an appearance.

**Eight issues. None complete. Nothing has been built.**

| Issue | State |
| --- | --- |
| [201 — vertices, edges and loops](201-vertices-edges-and-loops.md) | not started |
| [202 — junctions and shape points are derived](202-junctions-and-shape-points-are-derived.md) | not started |
| [203 — adjacency is a shared edge](203-adjacency-is-a-shared-edge.md) | not started |
| [204 — the identity buffer](204-the-identity-buffer.md) | not started |
| [205 — hit-testing is one pixel](205-hit-testing-is-one-pixel.md) | not started |
| [206 — the fence is one pixel, in screen space](206-the-fence-is-one-pixel-in-screen-space.md) | not started |
| [207 — the cage shows one level](207-the-cage-shows-one-level.md) | not started |
| [208 — the network validator](208-the-network-validator.md) | not started |

## Why this comes before anything can be traced

It decides whether the hand-tracing in phase 3 is worth doing. Two thousand
loops drawn against the wrong structure is two thousand loops drawn twice, so the
structure is settled first and proven on a four-block fixture before a real city
is committed to it.

## What was settled before any of it was written

**Blocks are faces of a shared network, not outlines of their own.** The failure
that forces this is invisible: with per-block point lists, dragging a shared
corner leaves a hairline gap *and* silently stops the two blocks being neighbours,
while looking perfectly correct on screen.

**Adjacency is a shared edge, and it is the only nearness the game has.** No
distances, ever, because the painting's scale swings three or fourfold across the
frame. Influence walks the graph instead, which means a rampart stops it without
any special case for walls — they work by not being streets.

**One identity buffer answers at every level.** Each pixel holds the finest place
covering it; everything coarser resolves by walking the containment chain. That
makes hit-testing a single pixel read and makes the filter pass in phase 5
possible at all.

**The fence is one pixel, so it is one colour for all lines — and that deleted
three mechanisms.**

The design had every boundary fading in on its own on-screen width. But since the
fence runs down the middle of a street, **nearly every edge in the city is shared
by exactly two blocks**, and each would have wanted a different opacity for one
line stroked once. A harbour block 300 pixels across beside an alley of 28: take
the larger and small places get lopsided part-drawn outlines; take the smaller
and large ones get faint patches that read as a fault; stroke it twice and shared
edges come out brighter than unshared ones.

One colour removes the number they were disagreeing about. The question stops
being *how brightly* and becomes *whether* — and the answer already existed:
**draw the boundaries of the level you can currently select, and only those.**
The cage swaps as you descend rather than thickening.

Gone with it: the two fade thresholds, the four line weights that were to have
carried the hierarchy, and the override that drew whatever was under the pointer
at full strength. That last one existed to rescue places too small to see, and at
the selectable level nothing is ever too small.

It also made an existing promise exact rather than approximate. **The cage is the
set of things you can click**, so the interface never has to explain itself.

## The failure this phase exists to prevent

A near-miss snap during tracing produces two hairlines a pixel apart down one lane
— indistinguishable from one line — after which the blocks either side are not
neighbours and never will be. Nothing announces it. The validator in 208 is the
expensive defence; the feedback in phase 3 is the cheap one.

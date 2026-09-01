# Phase 2 — The Cage

The fence network as a structure and as an appearance.

**Nine issues. None complete. Nothing has been built.**

| Issue | State |
| --- | --- |
| [201 — vertices, edges and places](201-vertices-edges-and-places.md) | not started |
| [209 — blocks are faces of the graph](209-blocks-are-faces-of-the-graph.md) | not started — as foundational as 201 |
| [202 — junctions and shape points are derived](202-junctions-and-shape-points-are-derived.md) | not started |
| [203 — adjacency is a shared edge](203-adjacency-is-a-shared-edge.md) | not started |
| [204 — the identity buffer](204-the-identity-buffer.md) | not started |
| [205 — hit-testing is one pixel](205-hit-testing-is-one-pixel.md) | not started |
| [206 — the fence is one pixel, in screen space](206-the-fence-is-one-pixel-in-screen-space.md) | not started |
| [207 — the cage shows one level](207-the-cage-shows-one-level.md) | not started |
| [208 — the network validator](208-the-network-validator.md) | not started |

## Why this comes before anything can be traced

It decides whether the partitioning in phase 3 is worth doing. Two thousand cuts
made against the wrong structure is two thousand cuts made twice, so the
structure is settled first and proven on a four-region fixture before a real city
is committed to it.

## What was settled before any of it was written

**Places are faces of a planar graph, derived rather than stored.** The city is
subdivided rather than assembled, so coverage is always complete and a whole
class of fault became unrepresentable rather than merely checked for: loops that
do not close, edges belonging to nothing, edges shared by three places, places
that look adjacent without being so.

In exchange it gained one hard requirement. **Planarity** — no two edges crossing
except at a shared vertex — is what the face walk rests on, and violating it
fails silently and remotely, producing plausible regions that are wrong.

A name cannot live on a derived face, since faces are renumbered on every edit.
It lives on a **place** anchored by a seed point inside the region, which degrades
correctly: cut a region and the named half keeps its name; sever a link and two
names must be resolved, which the person is asked about rather than guessed at.

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

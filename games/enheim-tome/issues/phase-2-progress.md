# Phase 2 — The Cage

The fence network as a structure and as an appearance.

**Eight issues. None complete. Nothing has been built.**

| Issue | State |
| --- | --- |
| [201 — vertices, edges and loops](201-vertices-edges-and-loops.md) | not started |
| [202 — junctions and shape points are derived](202-junctions-and-shape-points-are-derived.md) | not started |
| [203 — adjacency is a shared edge](203-adjacency-is-a-shared-edge.md) | not started |
| [204 — the identity buffer](204-the-identity-buffer.md) | not started |
| [205 — hit-testing is one pixel](205-hit-testing-is-one-pixel.md) | not started — clicks on undefined ground blocked on open question 2 |
| [206 — the fence is one pixel, in screen space](206-the-fence-is-one-pixel-in-screen-space.md) | not started |
| [207 — each boundary fades on its own size](207-each-boundary-fades-on-its-own-size.md) | not started |
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

**Each boundary fades on its own on-screen width, not on the global zoom.** A
harbour block is 300 screen pixels across at native zoom while a northern one is
40; no single threshold is right for both. Fading per place handles the
perspective without anyone correcting for it.

## The failure this phase exists to prevent

A near-miss snap during tracing produces two hairlines a pixel apart down one lane
— indistinguishable from one line — after which the blocks either side are not
neighbours and never will be. Nothing announces it. The validator in 208 is the
expensive defence; the feedback in phase 3 is the cheap one.

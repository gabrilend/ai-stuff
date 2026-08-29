# Phase 3 — The Tracing Tool

The second program, and the only thing that ever writes a fence network.

**Eleven issues. None complete. Nothing has been built.**

| Issue | State |
| --- | --- |
| [301 — a second program, sharing the canvas](301-a-second-program-sharing-the-canvas.md) | not started |
| [302 — the click does three things](302-the-click-does-three-things.md) | not started |
| [303 — the pointer shows what is about to happen](303-the-pointer-shows-what-is-about-to-happen.md) | not started |
| [304 — snapping is measured on the screen](304-snapping-is-measured-on-the-screen.md) | not started |
| [305 — dragging a junction moves the corner](305-dragging-a-junction-moves-the-corner.md) | not started |
| [306 — naming a block, and a corner](306-naming-a-block-and-a-corner.md) | not started |
| [307 — placing a building's rough zone](307-placing-a-buildings-rough-zone.md) | not started |
| [308 — assigning membership](308-assigning-membership.md) | not started — blocked on open questions 11 and 12 |
| [309 — the coverage report](309-the-coverage-report.md) | not started — where it lives is open question 9 |
| [310 — undo over a shared network](310-undo-over-a-shared-network.md) | not started — open question 10 |
| [311 — autosave to the RAM tier](311-autosave-to-the-ram-tier.md) | not started |

## Why this phase gates everything

It is the instrument for the largest cost in the project: two thousand traced
loops and ten thousand placed zones, over months of evenings. **It is finished
properly before the campaign begins rather than alongside it** — doubly so given
the board is a stand-in and every traced hour is provisional.

## What was settled before any of it was written

**Edge adoption is the whole design.** Per-block tracing approaches every street
twice, and unless the second approach can take the first one's work wholesale, the
two sides end up as separate near-identical hairlines with no adjacency between
them. Adopting the entire run makes them the same record by definition rather than
by luck.

**The pointer says which of the three things is about to happen**, because the
failure it prevents leaves no visible mark.

**Snapping is measured in screen pixels**, which matches how precisely a hand can
point at that moment — and which forces the tool to *refuse* work below a zoom
rather than accept imprecision that looks fine until somebody zooms in a week
later.

**Undo keeps copies, not inverses.** The structure that makes dragging a corner
trivial makes reversing a merge hard: rewriting many edge paths to point at a
survivor cannot be undone by a rule, only by having kept what was there. This is
irreplaceable hand-work and correctness is worth more than economy.

## The thing most likely to end the project

Losing an hour of tracing. Hence 311, and hence autosave writing whatever state
exists — including a half-traced loop — rather than validating first.

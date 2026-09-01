# Phase 3 — The Tracing Mode

**A mode inside the game**, so that a map is a thing players can make. The city
starts whole and gets cut up.

**Twelve issues. None complete. Nothing has been built.**

| Issue | State |
| --- | --- |
| [301 — the tracing mode](301-the-tracing-mode.md) | not started |
| [302 — cutting and severing](302-cutting-and-severing.md) | not started |
| [303 — the pointer shows what is about to happen](303-the-pointer-shows-what-is-about-to-happen.md) | not started |
| [304 — snapping is measured on the screen](304-snapping-is-measured-on-the-screen.md) | not started |
| [305 — dragging a junction moves the corner](305-dragging-a-junction-moves-the-corner.md) | not started |
| [306 — naming a block, and a corner](306-naming-a-block-and-a-corner.md) | not started |
| [307 — placing a building's rough zone](307-placing-a-buildings-rough-zone.md) | not started |
| [308 — assigning membership](308-assigning-membership.md) | not started — blocked on open questions 11 and 12 |
| [309 — the coverage report](309-the-coverage-report.md) | not started |
| [310 — undo over a shared network](310-undo-over-a-shared-network.md) | not started |
| [311 — autosave to the RAM tier](311-autosave-to-the-ram-tier.md) | not started |
| [312 — a map is a bundle](312-a-map-is-a-bundle.md) | not started |

## What this phase became

It was a separate developer program that traced each block's closed loop, one at
a time. It is now **a mode inside the game that subdivides a whole**, and both
halves of that changed for good reasons.

**The editor moved into the game so that maps are mods.** If it were a developer
tool, nobody but the author could ever make a city. The cost is real and worth
naming rather than glossing: the game can no longer be *physically incapable* of
corrupting a network, because it now contains code that writes one. What replaces
that guarantee is a discipline — the editing code in its own files, and the
shared canvas code never asking which mode is running it.

**The city is now subdivided rather than assembled.** It starts whole and gets
cut up, so coverage is always one hundred percent and there is no such thing as
untraced ground. Cutting and severing are exact inverses, which is what makes the
model easy to hold in the head and undo natural.

## What that deleted

The load-bearing feature of the old design was **adopting a whole edge** — without
it, approaching a street from its second side produced two near-identical
hairlines and two places that silently were not neighbours. That entire failure
mode is gone: places are faces of one graph, so there is only ever one line down
a street and adjacency is true by construction.

Most of the validator went with it. Loops that do not close, edges belonging to
nothing, edges shared by three places — none can be expressed. **Having less to
validate is the reward for choosing a structure that cannot state the fault.**

## What it gained

**Planarity as a hard requirement.** The face walk is only correct when no two
edges cross except at a shared vertex, and violating that fails silently and
remotely: the walk still produces closed rings, just wrong ones, and what you
notice weeks later is two places behaving as neighbours when they are not. The
mode refuses crossings, and the validator asserts it anyway.

**A bundle format**, because a map players can build is a map somebody
distributes — carrying its picture, its partition, its names, and a notice saying
where the artwork came from.

## The thing most likely to end the project

Losing an hour of work. Hence 311, and hence autosave writing whatever state
exists rather than validating first.

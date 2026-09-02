# 202 — Junctions and Shape Points Are Derived

| | |
| --- | --- |
| Phase | 2 — The Cage |
| Blocked by | 201 |
| Blocks | 208, 305, 306 |
| Reads | [the fence network](../docs/004-the-fence-network.md) |
| Open questions | — |

## Current behavior

Vertices exist. They are all alike.

## Intended behavior

Two kinds of vertex, distinguished by **where they appear rather than by a field
that says so**.

| Kind | What it is | What dragging it does |
| --- | --- | --- |
| **junction** | a vertex at the start or end of any edge | every fence running into that corner follows, so a corner stays a corner |
| **shape point** | a vertex only in the interior of exactly one edge | that one stretch of fence bends; nothing else moves |

Grab the corner of a block and the neighbourhood re-corners with it. Grab the
middle of a lane and you nudge the lane. That is what a hand expects, and it costs
**no extra field** — it is a consequence of the same vertex index appearing in
more than one edge's path.

### Why derived rather than stored

A stored flag can disagree with the structure. If a vertex is marked "junction"
but only one edge ends there, or marked "shape point" while three edges meet, then
dragging behaves one way and the network is shaped another, and the two drift
apart silently over a long tracing session.

Deriving it means the question *is this a corner?* is answered by looking, and the
answer cannot be stale.

### What must be built

An index from vertex to the edges that touch it, and how — as an endpoint or as
an interior point. Built once when the network loads, updated when the tracing
tool changes something.

That index is what makes both the derivation and the dragging cheap. Without it,
asking whether a vertex is a junction means scanning every edge, which is fine
once and ruinous during a drag.

## Suggested implementation steps

1. On load, walk every edge's path. Record, per vertex, the edges that name it and
   whether each names it at an end or in the middle.
2. A vertex is a junction when at least one edge names it as an endpoint.
3. A vertex used as an endpoint by one edge and as an interior point by another is
   **malformed** — refuse it loudly rather than picking a behaviour. It means two
   streets disagree about whether they meet there.
4. Keep the index alongside the network and rebuild the affected entries whenever
   an edge changes.
5. Test on the fixture: the crossroads vertex reports as a junction with four
   edges; a mid-lane vertex reports as a shape point with one.

## Related documents and tools

- [The fence network](../docs/004-the-fence-network.md)
- [201 — vertices, edges and places](201-vertices-edges-and-places.md)

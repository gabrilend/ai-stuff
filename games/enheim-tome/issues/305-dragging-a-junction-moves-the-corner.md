# 305 — Dragging a Junction Moves the Corner

| | |
| --- | --- |
| Phase | 3 — The Tracing Tool |
| Blocked by | 202, 304 |
| Blocks | 310 |
| Reads | [the fence network](../docs/004-the-fence-network.md) |
| Open questions | — |

## Current behavior

Vertices can be created. None can be moved.

## Intended behavior

Grab a vertex and move it. What follows depends on what kind of vertex it is —
and, crucially, **the shared-vertex structure means this needs no special code**.

| Grabbed | What moves |
| --- | --- |
| a **junction** | every fence running into that corner, because every one of them names this same vertex |
| a **shape point** | that one stretch of fence bends; nothing else |

Grab the corner of a block and the neighbourhood re-corners with it. Grab the
middle of a lane and you nudge the lane.

### The point worth being explicit about

**Nothing here iterates over the affected edges.** Moving a junction updates one
entry in the vertex table. Every edge that names that vertex is drawn from the
table, so they all follow because they were never holding their own copy.

This is the entire payoff of [201](201-vertices-edges-and-places.md) choosing a
network over per-block point lists. Had blocks owned their own points, this
operation would be a search for coincident points, a decision about tolerance,
and a correctness problem forever. Instead it is an assignment.

If the implementation finds itself hunting for other vertices to move in
sympathy, the structure has been misunderstood — stop and re-read the network
document rather than making the hunt work.

### Live feedback

While dragging, every fence into that corner redraws each frame, so you see the
neighbourhood deform under your hand. That is both the pleasure of the tool and
the check that you grabbed what you meant.

### The zoom floor applies

Dragging is subject to the same refusal as placing — see
[304](304-snapping-is-measured-on-the-screen.md). Nudging a corner forty painting
pixels because you were zoomed out is a mistake nobody notices.

### Snapping while dragging

A dragged vertex can be dropped **onto** another vertex, which merges them. That
is how a mistakenly separate corner gets joined to the one it should always have
been. Merging is destructive and must be confirmed rather than silent, since it
changes which blocks are adjacent.

## Suggested implementation steps

1. On press within the snap radius of a vertex, begin a drag on that vertex.
2. Each frame, set the vertex's position from the pointer converted into painting
   coordinates; change nothing else.
3. Redraw the affected edges from the table, as usual — no special path.
4. Refuse to begin a drag below the zoom floor.
5. On release over another vertex, ask before merging, naming the blocks whose
   adjacency will change.
6. Run the affected part of the validator on release.
7. Test: drag the fixture crossroads vertex and assert all four blocks' boundaries
   moved and all four still report the same neighbours.

## Related documents and tools

- [The fence network](../docs/004-the-fence-network.md)
- [202 — junctions and shape points are derived](202-junctions-and-shape-points-are-derived.md)

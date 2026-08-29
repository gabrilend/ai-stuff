# 201 — Vertices, Edges and Loops

| | |
| --- | --- |
| Phase | 2 — The Cage |
| Blocked by | — |
| Blocks | 202, 203, 204, 208, 301 |
| Reads | [the fence network](../docs/004-the-fence-network.md) |
| Open questions | — |

## Current behavior

Nothing exists. There is no fence network.

## Intended behavior

The structure that the whole hand-tracing campaign writes into. **Get this wrong
and the tracing has to be done twice**, which is why it is settled before any
tracing tool exists.

### It is a network, not a list of shapes

The obvious structure — each block holding its own closed list of points — fails
the moment anything is dragged. A vertex on the fence between two blocks belongs
to both; move it in one and the other stays behind, leaving a hairline gap.

The gap is the visible half of the failure. The invisible half is worse: the two
blocks are **no longer recorded as touching**, so nothing propagates between them,
and the city quietly stops being connected while looking perfectly fine on
screen.

So blocks are **faces of a shared network**, and a block owns no points at all.

### The tables

| Table | Field | Type | Meaning |
| --- | --- | --- | --- |
| **vertices** | `x`, `y` | numbers | position in painting pixels |
| **edges** | `path` | ordered list of integers | vertex indices, walked end to end. One run of street. |
| **blocks** | `name` | string | what the place is called |
| | `loop` | ordered list of pairs | an edge index and a direction flag each |
| | `district` | integer | which district it belongs to |
| | `default_filter` | string or nothing | the filter that opens with it |

An edge is a **polyline**, not a segment, because streets curve. Its interior
vertices are its own; its two endpoints are shared with whatever else meets
there.

### The direction flag is not decoration

An edge is shared by the blocks on either side of it, and they walk it in
opposite directions. The flag says which way this block traverses it, so that
following a block's loop produces a closed ring with consistent winding no matter
which order the edges were adopted in.

Without it, a block whose loop happens to name edges in mixed directions produces
a self-crossing tangle that fills wrongly and hit-tests wrongly, and the cause is
extremely hard to see.

### On disk

A plain text format, readable and diffable, because this file is the single most
valuable artefact in the project and will be edited by hand when something goes
wrong. Not a binary blob. Not a format that reorders itself on save — stable
ordering means a version-control diff shows what actually changed.

## Suggested implementation steps

1. Define the three tables as flat arrays of primitives; assign the memory first
   and fill it, rather than growing per-record objects.
2. Write the reader and writer together, and a test that round-trips a small
   hand-made network unchanged, byte for byte.
3. Make the writer's ordering deterministic.
4. Provide a walk that yields a block's boundary as a sequence of painting points,
   honouring direction flags. Everything downstream — filling, stroking, hit
   testing — uses that one walk rather than re-deriving it.
5. Build a tiny fixture network by hand — four blocks around one crossroads —
   and keep it as the fixture every later test loads.

## Related documents and tools

- [The fence network](../docs/004-the-fence-network.md)
- [The places of the city](../docs/003-the-places-of-the-city.md)

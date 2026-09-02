# 201 — Vertices, Edges, and Places

| | |
| --- | --- |
| Phase | 2 — The Cage |
| Blocked by | — |
| Blocks | 202, 203, 204, 206, 208, 209, 301, 312, 401 |
| Reads | [the fence network](../docs/004-the-fence-network.md) |
| Open questions | — |

## Current behavior

Nothing exists. There is no fence network.

## Intended behavior

The structure the whole partitioning campaign writes into. **Get this wrong and
two thousand cuts have to be made twice**, which is why it is settled before any
editing exists.

### The graph is the truth; the regions are derived

| Table | Field | Type | Meaning |
| --- | --- | --- | --- |
| **vertices** | `x`, `y` | numbers | position in painting pixels |
| **edges** | `path` | ordered list of integers | vertex indices, walked end to end. One run of street. |
| **places** | `seed` | a point | somewhere inside the region this names |
| | `name` | string | what it is called |
| | `district` | integer | which district it belongs to |
| | `default_filter` | string or nothing | the filter that opens with it |

**Faces are not stored.** The regions the graph cuts the painting into are
computed from it — see [209](209-blocks-are-faces-of-the-graph.md).

An edge is a **polyline**, not a segment, because streets curve. Its interior
vertices are its own; its endpoints are shared with whatever meets there.

### There is no stored loop, and no direction flag

An earlier version had each place holding an ordered loop of edges with a
direction flag apiece, assembled by hand one block at a time.

Both are gone. A face's boundary comes out of the walk in
[209](209-blocks-are-faces-of-the-graph.md) already ordered and already wound
consistently, because that is what the walk produces. The direction flag existed
to stop a hand-assembled loop from self-crossing, and a derived boundary cannot.

### A name lives on a place, not on a face

Faces are recomputed whenever the graph changes, so their numbering is unstable
and a name cannot live on one.

It lives on a **place**, anchored by a **seed** — a point inside the region. After
any recomputation, each face adopts the place whose seed it contains.

That degrades correctly:

- **Cut a region in two.** The seed lands in one half, which keeps the name; the
  other half is new and unnamed. Cutting Tanner's Row leaves one half still
  Tanner's Row and one half waiting to be named, which is right.
- **Sever a link.** Two faces merge, two seeds are now inside one face, and one
  name must lose. **The person is asked.** Hand-written names are the expensive
  part of this work and none may vanish silently.

A seed for a new face must be **guaranteed inside it**. A centroid is not — a
concave face's average position readily falls outside it, which would attach a
name to the wrong region in a way nobody would ever notice.

### On disk

Plain text, readable and diffable, because this file is the most valuable
artefact in the project and will be edited by hand when something goes wrong. Not
a binary blob, and not a format that reorders itself on save: stable ordering
means a version-control diff shows what actually changed.

## Suggested implementation steps

1. Define the three tables as flat arrays of primitives; assign the memory and
   fill it rather than growing per-record objects.
2. Write the reader and writer together, with a test that round-trips a small
   hand-made network byte for byte.
3. Make the writer's ordering deterministic.
4. Implement a robust interior-point routine for seeding new places, and test it
   on a deliberately concave face whose centroid falls outside.
5. Build a fixture by hand — a boundary rectangle cut twice, giving four regions
   around one crossroads — and keep it as what every later test loads.

## Related documents and tools

- [The fence network](../docs/004-the-fence-network.md)
- [209 — blocks are faces of the graph](209-blocks-are-faces-of-the-graph.md)

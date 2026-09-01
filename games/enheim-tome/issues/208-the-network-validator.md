# 208 — The Network Validator

| | |
| --- | --- |
| Phase | 2 — The Cage |
| Blocked by | 201, 202, 209 |
| Blocks | 302, 309, 310 |
| Reads | [the fence network](../docs/004-the-fence-network.md) |
| Open questions | — |

## Current behavior

A network can be loaded and its faces found. Nothing checks whether it makes
sense.

## Intended behavior

A program that walks a network and reports every way it is malformed. It **reads
and reports; it never repairs** — a validator that quietly fixes things hides the
editing mistake that caused them, and the mistake will be repeated.

It runs on every save and as part of the test run.

### Most of its old list stopped being possible

An earlier design had places holding hand-assembled loops, and this checked for
loops that did not close, edges belonging to no place, edges named by three
places, and places that looked adjacent without being so.

**None of those can now occur.** Regions are faces of a planar graph, and the walk
that finds them closes every ring and traverses every edge exactly twice by
construction — see [209](209-blocks-are-faces-of-the-graph.md).

Worth stating rather than quietly deleting, because it is the second time in this
project that changing the representation removed a whole class of check. **Having
less to validate is the reward for choosing a structure that cannot express the
fault.**

### What it checks now

| Fault | Why it matters |
| --- | --- |
| **two edges crossing without a shared vertex** | the face walk still terminates on a non-planar graph and still produces closed rings — **wrong ones**, quietly, with the damage appearing far from its cause |
| **not exactly one negatively wound face** | there must be precisely one outer face; none or several means the graph is disconnected or inverted |
| **a place whose seed lies inside no face** | its name is orphaned and about to be lost |
| **two seeds inside one face** | two names for one region, from a sever that was never resolved |
| **a face containing no seed** | an unnamed region — normal early on, so reported as work rather than as a fault |
| **two vertices closer than the grab radius at native zoom** | almost always a mis-click rather than an intention |
| **a place with no name** | unreachable by search, unnameable in the tome |

### The first one is the important one

Planarity is the assumption the whole structure rests on, and violating it fails
**silently and remotely**. The walk produces plausible-looking regions that are
wrong, and what you notice weeks later is two places behaving as neighbours when
they are not.

The editor refuses crossings where edges are made — see
[302](302-cutting-and-severing.md) — but an invariant this load-bearing is
asserted rather than trusted, because the refusal is one code path and the file
can also be edited by hand.

### The report

Named places, not indices. "Tanner's Row and Fishgate are separated by a crossing
with no corner in it" is actionable; "edge 2201 crosses edge 1180" is a lookup
task. Where a place has no name yet, say where it is on the painting.

## Suggested implementation steps

1. Test every pair of edges whose bounding boxes overlap for a crossing that is
   not at a shared vertex. Bucket by a coarse grid so this stays near-linear
   rather than comparing every edge with every other.
2. Take signed areas from the face walk; assert exactly one is negative.
3. Match seeds to faces; report orphaned seeds, doubled seeds and seedless faces
   separately, since only the first two are faults.
4. For near-duplicate vertices, bucket by a coarse grid as above.
5. Exit non-zero on anything in the fault column, so it can fail a build. Unnamed
   and seedless regions are counted, not failed on.
6. Test each fault by deliberately breaking a copy of the fixture one way at a
   time and asserting the right complaint comes out.

## Related documents and tools

- [The fence network](../docs/004-the-fence-network.md)
- [209 — blocks are faces of the graph](209-blocks-are-faces-of-the-graph.md)
- [The tracing mode](../docs/005-the-tracing-mode.md)

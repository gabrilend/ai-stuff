# 209 — Blocks Are Faces of the Graph

| | |
| --- | --- |
| Phase | 2 — The Cage |
| Blocked by | 201 |
| Blocks | 203, 204, 208, 302 |
| Reads | [the fence network](../docs/004-the-fence-network.md) |
| Open questions | — |

*Read alongside [201](201-vertices-edges-and-places.md); it is as foundational,
and only sits later because inserting it earlier would have renumbered the phase.*

## Current behavior

Vertices and edges exist. Nothing knows what regions they cut the painting into.

## Intended behavior

**The regions are computed from the graph**, by the standard walk over a planar
subdivision.

At each vertex, sort its incident edges by angle. To trace a face: follow an
edge; at the far end, take the next edge clockwise from the reverse of the one
you arrived on; repeat until you return to the start. Each walk closes, and
together the walks traverse **every edge exactly twice — once from each side**,
which is precisely the two regions that edge separates.

That last property is the useful one. It is not a coincidence to be checked; it
is what the walk *is*, and it is why several faults the old design could have are
now unrepresentable:

| | |
| --- | --- |
| a boundary that does not close | every walk closes; that is the terminating condition |
| an edge belonging to no region | every edge is traversed, twice |
| an edge shared by three regions | an edge has two sides |
| two regions that look adjacent but are not | adjacency *is* sharing an edge |

## Planarity is a requirement, not an assumption

The walk is only correct on a **planar** graph — no two edges crossing except at
a shared vertex. Given a crossing, the angular sort at each end is still
well-defined, so the walk still terminates and still produces closed rings. It
just produces **wrong** ones, quietly, and the damage shows up somewhere else
entirely.

So planarity is enforced where edges are made — see
[302](302-cutting-and-severing.md) — and checked here by
[208](208-the-network-validator.md), because an invariant the whole structure
rests on should be asserted rather than trusted.

## The outer face

The walk produces one region that is not a region: the unbounded outside. It
comes out wound the opposite way from all the others, which is how it is
recognised — its signed area is negative where the real faces are positive.

If the graph begins as a boundary around the painting, the outer face is
everything beyond that boundary, and it is discarded. **It is not a place**, holds
no name, and never appears in the identity buffer.

## When it runs

On load, and after any change to the graph. That is often — every cut, every
sever, every dragged vertex during an edit.

A full recomputation is a walk over every edge, which for a few thousand edges is
trivial and can simply be done. **Do the simple thing first**, measure, and only
consider recomputing locally if measurement demands it. Incremental face
maintenance is a known source of subtle wrongness, and it would be traded for
speed nobody has yet shown is needed.

After each recomputation, faces are matched to places by seed containment — see
[201](201-vertices-edges-and-places.md).

## Suggested implementation steps

1. Build, per vertex, its incident edge-ends sorted by angle. This is the one
   structure the walk needs.
2. Walk every edge-side exactly once, collecting closed rings.
3. Compute each ring's signed area; discard the negatively wound one as the outer
   face; refuse loudly if there is not exactly one.
4. Match faces to places by testing which face contains each seed.
5. Create a place, with a guaranteed-interior seed, for any face that contains no
   existing one.
6. Test on the fixture: a rectangle cut twice yields four faces plus one outer,
   each interior face has four sides, and diagonally opposite faces are **not**
   adjacent since they share only a vertex.

## Related documents and tools

- [The fence network](../docs/004-the-fence-network.md)
- [201 — vertices, edges and places](201-vertices-edges-and-places.md)
- [208 — the network validator](208-the-network-validator.md)

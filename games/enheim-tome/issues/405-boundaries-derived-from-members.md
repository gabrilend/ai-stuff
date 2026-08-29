# 405 — Boundaries Derived From Members

| | |
| --- | --- |
| Phase | 4 — The Places |
| Blocked by | 203, 404 |
| Blocks | 409 |
| Reads | [the places of the city](../docs/003-the-places-of-the-city.md) |
| Open questions | — |

## Current behavior

Districts and quadrants are sets of members with no shape.

## Intended behavior

The outline of any place above the block is **the outer edges of its members**,
computed on demand and never stored.

### How it is computed

Cheaply, using the edge-to-blocks index already built for
[203](203-adjacency-is-a-shared-edge.md):

> An edge is on a district's boundary when **exactly one** of the blocks naming it
> belongs to that district.

An edge with both its blocks inside is interior. An edge with neither is
elsewhere. An edge with one is the border. That is the whole rule, it needs no
geometry, and it works identically for quadrants and groups by asking the same
question one level up.

The result is a set of edges, not an ordered ring — which is all that stroking
needs. Ordering them into a closed loop is only necessary if something wants to
fill a district, and nothing does.

### That it may be several loops is correct

A district on both banks of a river has a boundary in two pieces. A quadrant
containing a megastructure has a hole in it. Neither is an error, and code that
assumes one loop will be wrong on the real city.

Working in **sets of edges rather than rings** avoids the question entirely, which
is the main reason to prefer it.

### Everything above the block is free

This is the payoff being cashed. Three levels of the hierarchy — district,
quadrant, group — cost only the decision of what belongs to what. Not one line is
drawn by hand for any of them, and no boundary can ever disagree with the blocks
it is made of.

### Caching

The set changes only when membership or the network changes, so it is computed
once and kept until one of those happens. During a pan or zoom nothing is
recomputed; only the drawing changes.

## Suggested implementation steps

1. One function, taking a level and a place, returning the set of edges whose
   two blocks straddle its boundary.
2. Use it for districts, quadrants and groups without specialising.
3. Cache per place, invalidated on membership or network change.
4. Pass the sets to the cage drawing in [409](409-the-cage-at-four-weights.md),
   which strokes them at the weight of their level.
5. Test on a fixture where two blocks of four belong to one district: the derived
   boundary is the four outer edges and excludes the shared inner one.
6. Test the two-piece case explicitly, since it is the one a naive implementation
   gets wrong.

## Related documents and tools

- [The places of the city](../docs/003-the-places-of-the-city.md)
- [The fence network](../docs/004-the-fence-network.md)

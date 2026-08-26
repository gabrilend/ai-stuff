# 304 — The tetrahedra in the corners

Produces `src/023-corner-parity-plumbing.md`.

## Current behavior

Nothing. `005` states the parity result and calls it pretty; nobody has proved it
or used it to size anything.

## Intended behavior

**The manifold topology, with the graph theory that justifies it written out.**
This is the shortest blueprint in phase 3 and the one the rest of the plumbing
leans on.

### What is being claimed

Two networks share the twelve edges: a supply channel and a return channel side by
side in every rail, joined three-at-a-time at every corner block, never joined to
each other anywhere. Four corners are fed and four drained, chosen by the parity
of the corner's coordinates.

Three properties follow, and the blueprint must **prove** each rather than assert
it, because `305`'s entire flow balance and `306`'s uniformity assumption rest on
them:

**One. Every edge joins an even corner to an odd one.** An edge changes exactly one
coordinate, which flips the parity. So the eight corners split into two sets of
four with no edge inside either set — the cube's graph is bipartite and the parity
is the bipartition.

**Two. Every corner is a feed point or adjacent to three of them.** Each corner has
three edges and every edge crosses the parity, so an odd corner's three neighbours
are all even. No point of the supply network is more than one edge from pressure,
and the same holds for the return. This is what makes the pressure distribution
uniform without any balancing orifices, and it is the property that would be lost
by choosing the four fed corners any other way.

**Three. The four fed corners form a regular tetrahedron.** Any two even-parity
corners differ in exactly two coordinates, so every pairwise distance is the face
diagonal. Six equal edges is a regular tetrahedron. The odd corners give its
mirror, and the two interpenetrating tetrahedra are a stella octangula.

The third property is decorative and the blueprint should say so. The first two
are load-bearing.

### What it is worth

Any other choice of four corners breaks property two. Take the four corners of one
face: the opposite face's four corners are then all at distance one from a feed —
fine — but the four fed corners are mutually adjacent in pairs, so the supply
network short-circuits along those edges and the flow through them does no work.
The parity choice is the unique one, up to swapping the sets, that makes every
supply channel carry flow toward a load.

**That is the finding worth having**: the cube does not merely permit this
arrangement, it has exactly one good one, and it comes from the shape rather than
from the designer.

## Symbols this must publish

Corner counts by parity, edges per corner, channels per network, the incidence
between faces and rails, which two rails feed each face's field and in which
direction, and the flow split ratios that follow.

## Constraints this must assert

- Inlets equal outlets equal half the corners.
- Three times the corner count equals twice the edge count.
- Every face is bounded by two supply-reachable and two return-reachable rails.
- Opposite faces run their fields in perpendicular directions, so no rail pair
  carries two full face loads.
- The bipartition is complete: no edge joins two corners of the same parity. This
  one is checked by enumeration over all twelve edges and is the closest thing in
  the project to a unit test.

## Suggested implementation steps

1. Draw the cube with corners labelled by their bits and shaded by parity.
2. Write the three proofs. Each is three lines.
3. Draw the two tetrahedra, once, because it will be the picture people remember.
4. Enumerate the twelve edges and their endpoints, and let the checker verify the
   bipartition over the enumeration rather than over an assertion.
5. Assign each face's field direction and check the perpendicularity rule.

## Blocks

`305`, `306`.

## Blocked by

`101`, `204`.

## Related documents

`005`. This is the one place in the project where a piece of pure mathematics
does real engineering work, and `090` should point a reader at it.

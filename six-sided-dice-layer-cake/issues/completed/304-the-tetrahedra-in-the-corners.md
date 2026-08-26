# 304 — The tetrahedra in the corners

Produces `src/023-corner-parity-plumbing.md`.

## Current behavior

**Done.** `src/023-corner-parity-plumbing.md` exists with all three proofs
written out and the third labelled decoration.

**The uniqueness argument is the part worth having, and it was not obvious.**
Feeding the four corners of one face keeps every point within one edge of a
supply -- so the domination property survives -- but four of the twelve edges
then join two fed corners, have no pressure across them, and carry no flow toward
any load. A third of the network does nothing. The test generalises: a choice of
four corners works exactly when no edge joins two of them, which is exactly when
they are one side of the bipartition. There are two such choices and they are
mirrors.

**The argument became load-bearing while the phase was being written.** `016`
withdrew the claim that the manifold is negligible, so what keeps the flow even
is no longer that the rails are invisible -- it is that no point of either
network is more than one edge from a port and every channel carries flow toward a
load. That was always the stronger argument and it was simply not the one being
relied on.

## What was missing, and how it was closed

**Which rail feeds which face is now assigned**, by search rather than by hand.

The rule was written and the enumeration was not. Opposite faces run their fields
perpendicular so that no pair of rails carries two full loads; six faces must each
take one of the twelve supply rails, the rail must lie on that face's own
boundary, and no rail may serve two faces. `102` enumerates all five hundred and
twelve arrangements, keeps the sixty-four that break no rule, solves the hydraulic
network for each, and takes the one that starves the worst face least.

**The result was not what the rule anticipated.** Sixteen of the sixty-four
distribute the coolant exactly evenly; the other forty-eight leave one face five
or six per cent short. The sixteen are the ones where a single fed corner has all
three of its supply channels tapped and the other three fed corners have one each
— a threefold rotation about a body diagonal, which is the symmetry that carries
every face of a cube onto another. The forty-eight spread the plenums two and two,
which looks more balanced and is not. **The choice of assignment is a real design
decision and it was very nearly made by accident.**

**The proofs are enumerations now.** `C-023-1` counted and `C-023-2` declared;
neither read the twelve-edge list in `010`. `C-023-7` takes each edge in turn and
compares the parity of its two ends. `C-023-8` reads the twelve edges written out
in `010`'s prose and checks that they are the twelve edges of a cube built from
its definition — the document and the object had never been compared, and a slip
in a corner label there would have put a drawing and a program at odds with
nothing to notice.

**Nine constraints were added** and the blueprint gained a section on the
assignment. Fourteen constraints in `023` now, up from six.

## What is still not done

**The threefold-axis result is observed and not proved.** `102` finds that the
sixteen even arrangements are exactly the ones with all three of a fed corner's
channels tapped, and the symmetry argument says why that would make the six faces
equivalent. But the program checks the count, not the symmetry: it never applies
the rotation and confirms the plumbing maps onto itself. A dozen more lines would
turn an observation into a proof.

**Why one family of eight costs three and a half per cent more to pump than the
other is measured and not explained.** The difference is whether the threefold
axis runs through a fed corner or a drained one. The number is in the report and
the mechanism is nowhere.

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

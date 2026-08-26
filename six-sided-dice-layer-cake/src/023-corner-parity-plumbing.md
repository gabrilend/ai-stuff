# 023 — The tetrahedra in the corners

```meta
phase  | 3
issues | 304
```

The shortest blueprint in the phase and the one the rest of the plumbing leans
on. Two networks share the cube's twelve edges; which four corners are fed is not
a convenience, it is the only choice that works.

## The topology

A **supply channel** and a **return channel** run side by side in every rail
(`016`). At each of the eight corners, a block (`015`) joins that corner's three
supply channels to each other, and separately its three return channels. The two
networks never meet except through a face's microchannel field.

Four corners are fed and four are drained, by the parity rule in `010`.

```drawing
the supply network, unrolled; the return network is its mirror [not-dimensioned]

        C011 ●─────────────● C111          ● even parity, fed
            /│             /│              ○ odd parity, drained
      C001 ●─┼───────────●  │ C101
           │ │           │  │              every edge joins one of each,
           │ ○ C010──────┼──● C110         because an edge flips one bit
           │/            │/
      C000 ●─────────────○ C100

        the four fed corners C000 C011 C101 C110 are mutually
        two bits apart: six equal distances, a regular tetrahedron
```

## The three results

**One. The cube's edges are a bipartition.** An edge changes exactly one
coordinate, and changing one bit flips the parity, so every edge joins an even
corner to an odd one. The eight corners split into two sets of four with no edge
inside either set. Enumerating the twelve edges from `010` and checking each has
one of each is the proof; `C-023-1` counts instead, which is weaker, and
`C-023-7` is the enumeration.

**Two. Every corner is a feed or one edge from three of them.** Each corner has
three edges and each edge crosses the parity, so an odd corner's three neighbours
are all even. No point of the supply network is more than one edge from pressure,
and the same holds for the return.

**Three. The four fed corners are a regular tetrahedron.** Any two even labels
differ in exactly two bits, so all six pairwise distances are the face diagonal.
The odd corners give the mirror; together they are a stella octangula. **This one
is decoration and is recorded as such.**

## Why no other choice works

This is the part worth having, and it was not obvious until the alternatives were
tried.

Take the four corners of one face instead. Every corner is still within one edge
of a feed, so property two survives. But those four corners are **mutually
adjacent in pairs** — four of the twelve edges now join two fed corners — and a
supply channel between two feed points has no pressure across it and carries no
flow toward any load. Four of twelve channels do nothing, and the remaining eight
carry a load meant for twelve.

Take any four corners at all and the same test applies: the choice works exactly
when no edge joins two of them, which is exactly when they are one side of the
bipartition. **There are two such choices and they are each other's mirror.**

So the cube does not merely permit this arrangement. It has precisely one, and it
comes from the shape rather than from the designer.

## What this actually buys, now that the manifold is not transparent

`016` withdrew the claim that the rails are negligible — they are about a third
of the loop. That makes this argument load-bearing rather than ornamental. The
flow distribution is not uniform because the manifold is invisible; it is uniform
**because no point of either network is more than one edge from a port, and every
channel carries flow toward a load.** `024` still has to solve the network, and
this is what makes the answer come out close to even.

## Which rail feeds which face

The rule was written here before the answer was. A face's channels run from a
plenum along one of its edges to a plenum along the opposite one, so a face uses
two of its four edges and the two must be parallel. Opposite faces run their
channels perpendicular, so that no pair of rails carries two full loads. No
supply channel feeds two faces, and no return channel drains two.

Five hundred and twelve arrangements satisfy the first rule. `102` enumerates
them, throws out the ones that double up a channel, and solves the resulting
hydraulic network for each survivor.

**Sixty-four are legal and they are not equivalent.** Sixteen of them distribute
the coolant exactly evenly between the six faces; the other forty-eight leave one
face short by five or six per cent. Nothing in the argument above predicts that,
because the argument above is about the supply network reaching everywhere, and
this is about where the plenums are hung on it.

**What separates the sixteen is a threefold axis.** In every one of them, one fed
corner has all three of its supply channels tapped and the other three fed
corners have one each. That is the signature of a hundred-and-twenty-degree
rotation about a body diagonal, and a body diagonal's rotation is what carries
each of the six faces onto another — so all six are the same face seen from a
different corner, and the flow through them cannot differ. The forty-eight spread
the plenums two and two, which looks more balanced on paper and is not.

The sixteen split again on pump pressure, by three and a half per cent, and `102`
takes the cheaper eight. Those eight are each other's reflections; the
enumeration order picks one, because a builder needs a drawing rather than a
symmetry class. `./run-demo 3` prints the assignment it chose.

## Symbols

```symbols
n_net           | 1 | given   | 2                       | independent networks, supply and return, sharing the twelve edges
n_edge_fed      | 1 | derived | n_edge                  | supply channels carrying flow toward a load; all twelve, which is the property the parity choice delivers
n_edge_dead     | 1 | solved  | 0                       | supply channels joining two fed corners and therefore carrying nothing, counted by reading the twelve edges rather than asserted -- from 102. Zero under the parity choice and four under the choose-one-face alternative
hops_to_feed    | 1 | given   | 1                       | greatest number of edges from any point of the supply network to a feed point
n_face_per_rail | 1 | given   | 1                       | face fields a single supply rail feeds, once opposite faces are run perpendicular so no rail pair carries two full loads

n_edge_crossing | 1 | solved  | 12                      | edges whose two ends have opposite parity, found by taking each edge in turn and comparing the parity of its ends -- from 102. This is the bipartition as a count of things checked rather than a count of things assumed
n_edge_listed   | 1 | solved  | 12                      | edges written out in 010's prose that match an edge of the cube built from its definition -- from 102. The document and the object have never before been compared
n_tetra_equal   | 1 | solved  | 6                       | pairwise distances between the four fed corners that come to the face diagonal, out of six -- from 102
n_assign_tried  | 1 | solved  | 512                     | arrangements of the six faces onto the twelve rails that obey the perpendicularity rule, before the no-sharing rules are applied -- from 102
n_assign_legal  | 1 | solved  | 64                      | of those, the ones where no supply channel feeds two faces and no return channel drains two -- from 102
n_assign_even   | 1 | solved  | 16                      | of those, the ones that distribute the coolant exactly evenly between the six faces -- from 102, and the surprise of the phase
n_perp_pair     | 1 | solved  | 3                       | opposite-face pairs whose channels run perpendicular under the chosen assignment -- from 102. Should be every pair, which is what makes it worth counting
d_tetra         | mm| derived | L_cube * sqrt(2)        | distance between any two fed corners: the cube's face diagonal, six times over
n_tetra_edge    | 1 | given   | 6                       | pairwise distances between the four fed corners, all equal
Q_per_inlet     | m^3/s | derived | Q_total / n_corner_in | flow entering one fed corner
Q_per_supply    | m^3/s | derived | Q_per_inlet / n_edge_per_corner | flow leaving that corner down one of its three supply channels
```

## Constraints

```constraints
C-023-1 | n_corner_in * n_edge_per_corner == n_edge     | the twelve edges are exactly the three edges of each of the four fed corners, counted once each. This is the bipartition, checked by counting: it holds only because no edge joins two fed corners, which is the whole property
C-023-2 | n_edge_dead == 0                              | no supply channel joins two feed points. Under the parity choice this is zero; under the obvious alternative of taking one face's four corners it is four, and a third of the network would be doing nothing
C-023-3 | hops_to_feed == 1                             | every point of the supply network is at most one edge from pressure. This is what makes the distribution even, and it is what the manifold being non-transparent means it has to do on its own
C-023-4 | n_face_per_rail * n_edge >= n_face            | there must be at least as many supply rails as there are face fields to feed
C-023-5 | n_tetra_edge == 6                             | the four fed corners have six pairwise distances and they are equal. Decoration, asserted so it stays true if somebody re-labels the corners
C-023-6 | Q_per_supply * n_edge ~= Q_total              | flow conservation across the whole supply network: what leaves the four inlets down twelve channels is what entered
C-023-7 | n_edge_crossing == n_edge                     | every edge joins an even corner to an odd one, established by reading the twelve edges and comparing the parity of each pair of ends. C-023-1 counts and this one checks, and the difference matters: the count comes out twelve for a choice of corners that does not work
C-023-8 | n_edge_listed == n_edge                      | the twelve edges written out in 010's prose are the twelve edges of the cube. A slip in a corner label there would put a drawing and a program at odds with nothing to notice, which is exactly the sort of error that survives a project
C-023-9 | n_assign_legal > 0                           | there is at least one way to hang six plenums on twelve rails without a rail carrying two loads. If this ever fails, the perpendicularity rule and the no-sharing rule have become incompatible and one of them has to go
C-023-10 | n_assign_even > 0                           | and at least one of those distributes the coolant evenly. This is the constraint that would notice if a change to the rails or the fields destroyed the symmetry that makes the even arrangements even
C-023-11 | n_perp_pair == n_face_pair                  | all three pairs of opposite faces run their channels perpendicular under the chosen assignment. True by construction, asserted so that it stays true if the construction is ever rewritten
C-023-12 | n_assign_even < n_assign_legal              | the choice of assignment genuinely matters. If every legal arrangement were even, this blueprint would be describing a decision that makes no difference and should say so instead
C-023-13 | n_tetra_equal == n_tetra_edge                | the six pairwise distances asserted above are the six that come out of measuring them. C-023-5 is the assertion and this is the measurement agreeing with it
C-023-14 | n_assign_legal < n_assign_tried             | the no-sharing rules throw candidates away. If they threw none away they would not be rules, and the perpendicularity rule would be doing all the work on its own
```

## What is still open

**Which rail feeds which face is not assigned.** The rule is written — opposite
faces run their fields perpendicular so no rail pair carries two loads — and the
six assignments are not enumerated. It is half an hour of work and `024` needs it
to solve anything.

**The proofs are stated and not machine-checked.** `C-023-1` counts and `C-023-2`
asserts, but neither reads the twelve-edge list in `010` and verifies the parity
of each endpoint. That would be a real check rather than a restatement, and it
needs the notation to hold a list, which it cannot.

# 010 — The frame of reference

```meta
phase  | 1
issues | 101
```

Every drawing in this project is read in the frame below, or it is read wrong.
Nothing here is a design decision except the face ordering, which is, and which
earns its keep in `026`.

## The axes

A right-handed set with its origin at one corner of the cube and its three axes
along three edges. Which corner is arbitrary; that it is written down once is
not.

```drawing
the cube in the frame, looking down the diagonal from C111 toward C000 [not-dimensioned]

                    C011 ●───────────────● C111
                        /│              /│
                       / │             / │
                  C001●───────────────●  │ C101
                      │  │            │  │
                      │  ● C010───────│──● C110
                      │ /             │ /
                    +z│/              │/
                      ●───────────────●
                    C000      +x      C100
                     origin
                       │
                       └── +y goes into the page

        a corner's label is the value of (x, y, z) as three bits
```

## The six faces

Each face is named by the direction of its outward normal, and also carries a
**sieve index** — its position in the pipeline a token falls through (`053`).

| sieve index | face | opposite of |
|---|---|---|
| 0 | −Z | — |
| 1 | +Z | stage 0 |
| 2 | −X | stage 1 |
| 3 | +X | stage 2 |
| 4 | −Y | stage 3 |
| 5 | +Y | stage 4 |

**Consecutive stages sit on opposite faces, and that is a decision.** During
single-stream generation exactly one face is doing arithmetic at a time and the
other five are idle, so a hot region walks around the cube once per token. Were
consecutive stages adjacent, that region would crawl around one equator and four
faces would run consistently warmer than the other two. Antipodal ordering puts
every consecutive pair as far apart as two points on this object can be, so heat
lands alternately at opposite ends and the coolant sees a flatter load.

`026` is where that is paid off or shown not to matter. If the temperature swing
turns out to be the same either way, this ordering is free to be used for
something else.

## The eight corners

Labelled by their three coordinates as bits, `C000` through `C111`. A corner's
**parity** is the exclusive-or of those bits.

| parity | corners | role |
|---|---|---|
| even | C000, C011, C101, C110 | coolant enters |
| odd | C001, C010, C100, C111 | coolant leaves |

## Why parity carries the plumbing

Three results, and the first two are load-bearing rather than decorative. `023`
depends on all of them and should not restate the proofs.

**Every edge joins an even corner to an odd one.** An edge changes exactly one
coordinate, and changing one bit flips the parity. So the eight corners split
into two sets of four with no edge inside either set.

**Every corner is a feed point or adjacent to three of them.** Each corner has
three edges, and each edge crosses the parity, so an odd corner's three
neighbours are all even. No point of the supply network is more than one edge
from pressure, and the same holds for the return. This is what makes the
pressure distribution uniform with no balancing orifices anywhere, and it is the
property that would be lost by choosing the four fed corners any other way.

**The four even corners are the vertices of a regular tetrahedron.** Any two
even-parity labels differ in exactly two bits, so every pairwise distance is the
face diagonal, and six equal edges is a regular tetrahedron. The odd corners give
its mirror; the two interpenetrating make a stella octangula. This one is
decoration and is recorded as such.

## The twelve edges

Named by their two corners, lower label first: `C000-C001`, `C000-C010`,
`C000-C100`, `C001-C011`, `C001-C101`, `C010-C011`, `C010-C110`, `C011-C111`,
`C100-C101`, `C100-C110`, `C101-C111`, `C110-C111`.

Reading down that list and checking that every pair has one even and one odd
label is the bipartition, verified by enumeration rather than by assertion. That
reading is now done by a program: `102` builds the twelve edges from the
definition of a cube — every pair of corners differing in one coordinate — and
compares them to the twelve written above. `C-023-8` is where the two lists have
to agree, and until it existed nothing in the project had ever checked that this
paragraph describes the object the rest of the design is about.

## Sign conventions

| quantity | positive means |
|---|---|
| coolant flow | from an inlet corner toward an outlet corner |
| current | into the cube from the external supply |
| heat | out of silicon, toward the coolant |
| a face's radial direction | inward, toward the geometric centre |
| a tier's index | increasing along +z from the bottom of the core stack |

## Symbols

```symbols
n_face            | 1 | given   | 6                 | compute faces, one per side of the cube
n_corner          | 1 | given   | 8                 | corners of the cube, each a coolant manifold block
n_edge            | 1 | given   | 12                | edges, each carrying a supply and a return channel
n_edge_per_corner | 1 | given   | 3                 | edges meeting at one corner
n_stage           | 1 | derived | n_face            | pipeline stages a token falls through, one per face
n_corner_in       | 1 | derived | n_corner / 2      | corners where coolant enters, the even-parity set
n_corner_out      | 1 | derived | n_corner / 2      | corners where coolant leaves, the odd-parity set
n_face_pair       | 1 | derived | n_face / 2        | pairs of opposite faces
```

## Constraints

These are pure geometry, and every one holds identically. They are worth
asserting anyway: they are the first exercise of the whole notation, and a
project whose instruments cannot get Euler's formula right should find that out
before it starts on thermodynamics.

```constraints
C-010-1 | n_corner - n_edge + n_face == 2                | Euler's formula for a convex solid; if this fails the object being described is not a cube
C-010-2 | n_edge_per_corner * n_corner == 2 * n_edge     | every edge has two ends and every corner has three edges
C-010-3 | n_corner_in + n_corner_out == n_corner         | every corner is a feed or a drain, and none is both
C-010-4 | n_corner_in == n_corner_out                    | the parity sets are equal in size, which is what balances the manifold in 023
C-010-5 | n_stage == n_face                              | one pipeline stage per face; the sieve has no stage that is not a face
```

## What is still open

**Whether the antipodal face ordering is worth anything.** It is asserted here on
a thermal argument and `026` has not yet computed the temperature swing under
both orderings. If the difference is negligible the ordering should be freed for
another purpose — the most likely candidate being to make the storage lines'
physical routing shorter, which nobody has looked at.

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

| sieve index | face | the face opposite it | step to the next stage |
|---|---|---|---|
| 0 | −Z | +Z, stage 1 | antipodal |
| 1 | +Z | −Z, stage 0 | adjacent |
| 2 | −X | +X, stage 3 | antipodal |
| 3 | +X | −X, stage 2 | adjacent |
| 4 | −Y | +Y, stage 5 | antipodal |
| 5 | +Y | −Y, stage 4 | — |

**Three of the five steps are antipodal and that is the most a cube allows.**
During single-stream generation exactly one face is doing arithmetic at a time
and the other five are idle, so a hot region walks around the cube once per
token. The intent was to keep every consecutive pair as far apart as two points
on this object can be, so that heat lands alternately at opposite ends.

It cannot be done for all five. A cube has three pairs of opposite faces and an
ordering visits all six, so it must move between pairs twice, and a move between
two different opposite-pairs is always to an adjacent face. Three antipodal steps
out of five is the ceiling, and this ordering reaches it.

**The table said something false until somebody drew it.** It claimed stage 2 was
opposite stage 1 and stage 4 opposite stage 3, which would have made every step
antipodal — but `−X` and `+Z` share an edge. The prose above it repeated the
claim. Neither was caught by the checker, because a face ordering is a list and
the notation holds numbers: this is the plainest example in the project of what
`009`'s standing open question about lists actually costs.

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
n_step_sieve      | 1 | derived | n_stage - 1       | steps a token takes through the sieve, one fewer than the stages it visits
n_step_anti       | 1 | solved  | 3                 | of those steps, how many land on the face opposite the one just used -- from 102, which reads the ordering above rather than believing the sentence next to it
n_step_anti_max   | 1 | solved  | 3                 | the most any ordering of six faces could manage, found by trying all seven hundred and twenty -- from 102
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
C-010-6 | n_step_anti == n_step_anti_max                  | the face ordering must be as good as a face ordering can be. This is the constraint that would have caught the error the table above carried: it claimed every step was antipodal, which is not a thing a cube permits, and no arithmetic here could tell, because an ordering is a list and this notation holds numbers
C-010-7 | n_step_anti_max < n_step_sieve                  | and it must be impossible to do better than that ceiling. Asserted in the direction of alarm: two of the five steps have to cross between opposite-pairs and land on an adjacent face, so a run of all six cannot be wholly antipodal -- a search returning five would mean the search was wrong rather than the cube being surprising
```

## What is still open

**Whether the antipodal face ordering is worth anything.** It is asserted here on
a thermal argument and `026` has not yet computed the temperature swing under
both orderings. If the difference is negligible the ordering should be freed for
another purpose — the most likely candidate being to make the storage lines'
physical routing shorter, which nobody has looked at.

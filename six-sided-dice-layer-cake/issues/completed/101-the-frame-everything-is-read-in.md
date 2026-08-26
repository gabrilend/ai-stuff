# 101 — The frame everything is read in

Produces `src/010-frame-of-reference.md`.

## Current behavior

**Done.** `src/010-frame-of-reference.md` exists. It fixes the right-handed axis
set with its origin at `C000`, names the six faces by their outward normal and
by their sieve index, labels the eight corners by their coordinate bits, and
lists the twelve edges by name so that the bipartition can be checked by reading
rather than by trusting.

The antipodal face ordering is in, with the thermal argument that motivates it
and an explicit note that `026` has not yet confirmed the argument is worth
anything.

All three parity proofs are written out. Seven counts are published and five
geometric constraints assert them; all five hold, including Euler's formula and
the handshake between corners and edges. Those five were the first exercise of
the whole notation and getting them right is what showed the instruments worked
before any physics was attempted.

## Intended behavior

One blueprint that fixes, for the whole project:

**The coordinate frame.** A right-handed set with its origin at one corner of the
cube and its three axes along three edges. Which corner and which edges is
arbitrary and must therefore be written down once, because every later drawing is
read in this frame or is read wrong.

**The names of the six faces.** Each face is named by its outward normal — `-Z`,
`+X`, and so on — and also carries a **sieve index** from zero to five, which is
its position in the pipeline a token falls through.

The mapping between the two is a real decision and not a convention. Consecutive
sieve stages should sit on **opposite** faces, not adjacent ones:

| sieve index | face | opposite of |
|---|---|---|
| 0 | −Z | — |
| 1 | +Z | stage 0 |
| 2 | −X | stage 1 |
| 3 | +X | stage 2 |
| 4 | −Y | stage 3 |
| 5 | +Y | stage 4 |

The reason is thermal. During single-stream generation exactly one face is doing
arithmetic at a time and the others are idle, so a hot region walks around the
cube once per token. If consecutive stages were adjacent, that hot region would
crawl around the equator and the four equatorial faces would run consistently
warmer than the poles. Antipodal ordering makes every consecutive pair as far
apart as two points on this object can be, so the heat is deposited alternately at
opposite ends and the coolant sees a much flatter load. `026` is where this is
paid off; here it is only named.

**The names of the eight corners.** Each corner is labelled by its three
coordinates as bits: `C000` through `C111`. The **parity** of a corner is the
exclusive-or of those three bits.

**The names of the twelve edges.** Each by its two corners, lower label first.

**Sign conventions**, stated once so no blueprint has to guess:

| quantity | positive means |
|---|---|
| coolant flow | from an inlet corner toward an outlet corner |
| current | into the cube from the external supply |
| heat | out of silicon, toward the coolant |
| a face's radial direction | inward, toward the geometric centre |

## Why parity is load-bearing and not decorative

Every edge of a cube changes exactly one coordinate, so every edge joins a corner
of even parity to one of odd parity. That single fact carries the entire coolant
manifold design in `023`, and this blueprint is where it is established. The four
even corners become inlets and the four odd corners outlets.

Two consequences follow that `023` will rely on and that should be *proved* here
rather than asserted, because the proofs are three lines each and the plumbing
argument collapses without them:

- **Every corner is an inlet or adjacent to three inlets.** Each corner has three
  edges and each edge crosses parity, so an odd corner's three neighbours are all
  even. No point of the supply network is more than one edge from a feed.
- **The four even corners are the vertices of a regular tetrahedron.** Any two of
  them differ in exactly two coordinates, so all six pairwise distances equal the
  face diagonal. The odd corners give the mirror tetrahedron, and the two together
  are a stella octangula.

## Symbols this must publish

| symbol | unit | meaning |
|---|---|---|
| `n_face` | 1 | six |
| `n_corner` | 1 | eight |
| `n_edge` | 1 | twelve |
| `n_stage` | 1 | pipeline stages, one per face |
| `n_corner_in` | 1 | corners fed with coolant |
| `n_corner_out` | 1 | corners drained |
| `n_edge_per_corner` | 1 | three |

## Constraints this must assert

These are pure geometry and every one of them must hold identically. They are
worth writing because the checker running them proves the notation and the
instruments work before a single physical dimension is entered.

- Euler's formula for the cube: corners minus edges plus faces equals two.
- Each corner has three edges and each edge has two corners, so three times the
  corner count equals twice the edge count.
- Inlets plus outlets equals the corner count, and inlets equals outlets.
- The pipeline has one stage per face.

## Suggested implementation steps

1. Choose the origin corner and the axis directions and draw them. One isometric
   drawing with the corner labels on it is worth more than the paragraph
   describing it.
2. Write the face table with both names and the sieve index, and put the thermal
   reason for the antipodal ordering in the file rather than only here — the
   blueprint is what a materials engineer reads.
3. Write the corner and edge naming.
4. Write the parity definition and both proofs.
5. Write the sign conventions table.
6. Declare the seven counts and the four geometric constraints.

## Blocks

Every other blueprint in the project. Nothing can be drawn before this exists.

## Blocked by

`1401` through `1405` — the instruments, or nothing can check the constraints.

## Related documents

`002` for the notation. `005` for the plumbing argument that rests on the parity
result. `023` is where that argument is made properly.

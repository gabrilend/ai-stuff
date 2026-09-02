# Roadmap

Phases are clusters of related design work, not a schedule. They are ordered by
dependency: a low-numbered phase is foundational and things stand on top of it,
a high-numbered phase has many things it must wait for. The last phase is a
capstone that only makes sense once everything below it exists.

It is normal for the final piece of work in this project to belong to Phase 1.

---

## Phase 1 — The Spine

The parts of the line that are the same no matter which release mechanism wins.
Everything else depends on this, so it comes first.

- The material walk, station by station, with invariants at every boundary.
  *(written — [001](001-the-material-walk.md))*
- The invariant ledger. *(written — [002](002-the-invariant-ledger.md))*
- The gas train: sources, purifiers, mass flow control, the assay before the
  tube, and the abatement after it.
- The reactor: tube or chamber, how it is heated, how uniform the hot zone must
  be across a face, and what the wall is made of given that the wall sees
  hydrogen, methane, and possibly chlorine.
- The heat budget. What it costs to hold a block at 1000 C, what fraction is
  recoverable, and whether the cooling water is a heat source worth using.

## Phase 2 — The Block

The workpiece. Distinct from Phase 1 because the block is the one piece of the
factory that is neither machine nor material, and every design decision about
it echoes through the whole line.

- Geometry. Faces, edges, and what an edge does to a growing sheet, since a
  sheet growing toward a corner has to stop or turn.
- Crystallinity. Single-crystal billet against cast against rolled-and-annealed,
  and what each costs to buy and to maintain.
- Orientation. Cutting the block so the working faces present (111).
- The fixture. How a block is held, rotated, and moved without touching the
  faces that matter.
- Face scheduling. How many faces are in production simultaneously, and what
  the others are doing meanwhile. A block with one working face wastes five
  sixths of itself; a block with six working faces on a rotation is a carousel
  and a much more interesting machine.

## Phase 3 — The Release Slot

Three complete designs for the same socket, developed side by side rather than
in sequence, because the point is the comparison.

- The slot itself: the boundary conditions all three must satisfy, stated once
  so the three designs are actually comparable.
- **Halide vapour transport.** Copper leaves as a gas and comes back as a
  gas, driven by a temperature difference alone.
- **Reversed electric current.** Copper leaves as ions and comes back as
  metal, driven by the sign of a voltage.
- **Bubbling delamination.** Copper does not leave. Gas is generated in the
  gap and pries the sheet up.
- The failure modes each one has that the others do not.

## Phase 4 — The Carrier and the Landing

Currently the weakest part of the design and the one most likely to embarrass
the rest of it. Removing the copper consumable only to add a polymer consumable
would be a lateral move dressed up as progress.

- The adhesion squeeze: the carrier has to hold the sheet harder than copper
  does and let go more easily than the substrate takes it. That window is the
  whole problem.
- Candidate carriers, including ones that are themselves reusable.
- Landing without trapping gas.
- Residue, and why it is measured as a doping shift rather than as a thickness.

## Phase 5 — Measurement

Turning invariants into instruments. Several invariants can be stated and not
checked, which means the factory would be blind exactly where it most needs
eyes.

- Seeing film continuity and layer count without opening the furnace.
- Reading a surface's crystal orientation fast enough not to be the bottleneck.
- What each measurement costs in throughput, and which invariants are cheaper
  to guarantee by construction than to verify.

## Phase 6 — The Comparison and the Cross-Pollination

The reason all three release mechanisms are being built. Comes late because it
needs all three finished.

- All three judged against the closure invariant first, then against
  everything else.
- Which parts of each design transplant into the others.
- Whether a hybrid is better than any of the three, or whether the hybrid
  inherits every weakness and none of the strengths.

## Phase 7 — The Floor

The capstone. Footprints, clearances, and the arrangement of machines in a
building. Last because a machine's footprint is not knowable until the machine
is designed, and the arrangement is not knowable until the footprints are.

- Each machine's floor area, clearance, and service access.
- Utility routing: gas, power, water, and exhaust.
- What the smallest viable plant looks like, and how it grows.
- Placement rules — which machines must be adjacent, which must be far apart,
  and which distances are set by safety rather than by convenience.

---

## Issues

Issue files are blueprints, not work logs, and they are not written yet on
purpose. Several of the design decisions they would encode are still open
questions with no answer, and an issue file written around an unanswered
question is a blueprint for a building nobody has decided the shape of.

They get written phase by phase as the questions in
[open questions](004-open-questions.md) are settled.

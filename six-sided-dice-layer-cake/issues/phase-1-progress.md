# Phase 1 — Datum: progress

**The frame, the materials, and the master dimensions. Complete.**

| ticket | blueprint | state |
|---|---|---|
| `101` | `010-frame-of-reference` | done |
| `102` | `011-material-properties` | done |
| `103` | `012-master-dimensions` | done |

## What the phase set out to do

Fix the small number of things every other blueprint would otherwise each decide
for itself: which way is up in a shape with no up, what copper conducts at, and
which lengths in this machine were chosen rather than derived.

## What it produced

**A frame.** Six faces named twice — by their outward normal and by their
position in the pipeline — eight corners labelled by their coordinate bits,
twelve edges listed by name, and four sign conventions. The face ordering is the
one decision in the phase: consecutive pipeline stages sit on opposite faces so
that the hot region walking around the cube during single-stream generation
lands alternately at opposite ends.

**Forty-five material properties**, every one at a stated temperature. Silicon's
conductivity is the value at 350 K rather than the textbook one, which matters
because the hot spot calculation happens at the hot end and the room-temperature
figure is about twelve per cent optimistic.

**Eleven chosen lengths, and sixteen derived from them.** Everything else in the
machine is an expression over these.

## What was learned

**The Prandtl cross-check earns its keep more than any other kind of
constraint.** Three properties of a fluid are transcribed from somewhere; a
fourth quantity relates them and is independently known. Computing the fourth
from the three catches a transcription error in any of them, which no amount of
care while typing does. There are four of these in `011` and they should be the
model for how `measured` values are guarded everywhere else.

**Euler's formula was the right first constraint to write.** It cannot fail
unless the instruments are broken, which is exactly why it was worth writing —
it proved the units engine, the expression parser, the ledger and the checker
all worked before anything with real physics in it was attempted.

**The two-chain check does not fire yet, and that is the point.** `C-012-9`
requires the core's edge, derived from the cube's outside inward, to equal the
same edge derived from the memory stack outward. The second half lives in phase
5 and does not exist, so the checker reports it under *not yet*. It is written
and waiting, and it will be the first thing to complain when somebody adds a
tier.

## What is still open

Both entries are in `009` rather than here.

**No tolerances anywhere** (`X2`). Every one of the eleven given lengths is a
point value. This is the largest single omission in the handoff package and it
is a change to the notation, not to `012`.

**Whether sixty millimetres is right at all** (`B4`). The chain in `012` says
the cube's size is set by the size of a transformer layer in the reference
model. If that model is the wrong anchor, the cube is the wrong size, and
nobody has run the calculation for a smaller one.

# Phase 9 — The Spout: progress

**The face that became a tube of wire. Complete, and the hand estimates held.**

| ticket | blueprint | state |
|---|---|---|
| `901` | `062-spout-concept` | done |
| `902` | `063-spout-pad-array` | done |
| `903` | `064-spout-driver-and-receiver` | done |
| `904` | `065-spout-skew-and-timing` | done |
| `905` | `066-spout-bonded-grade` | done |
| `906` | `067-spout-cabled-grade` | done |
| `907` | `068-spout-byte-mode` | done |
| `908` | `069-spout-integrity` | done |
| `909` | `069a-the-translation-unit` | done — **closes `009` entry O1** |
| `910` | `069b-the-cube-as-memory` | done |

**Three hundred and forty-eight constraints hold across sixty-two blueprints.**

## The numbers written by hand, confirmed by derivation

`007` was written before any blueprint existed, with a pocket calculator. The
pane's size, the energy of a transfer, the time to move the whole core and the
comparison against a network link were all estimated there. Derived from the fine
zone's geometry, the bitcell up:

| | by hand, phase 0 | derived, phase 9 |
|---|---|---|
| conductors in the pane | 16,777,216 | 16,777,216 |
| the pane | 2 MiB | 2.097 MB |
| energy, one pane | ~168 nJ | 168 nJ |
| whole core, at the burst rate | ~33 µs | 34.3 µs |
| against a fast network link | ~42,000× | 41,943× |

That agreement is the strongest evidence so far that the early documents were
arithmetic rather than atmosphere.

## What sixteen million wires actually buy

Not throughput. `C-069a-2`: **the cube is occupied for under a thousandth of the
time a whole-core handover takes.** It is a zero-cost output, not a fast one — one
edge on the cube's side, and however long the far end needs, during which the cube
is generating. That is the property that justifies the manufacturing risk, and it
only became visible once `069a` existed.

## The conflict that got resolved rather than papered over

`069a` required the cube-side interface to be identical across every variant.
`067` found that a pane serialised over hundreds of lanes arrives over hundreds
of nanoseconds in lane order, which is **not the same thing arriving**.

The requirement moved to the **core side**. The core, the cage and the pane window
are identical in every variant; a fixed-function serialiser on the face is what
differs, which is exactly what `056` already said about port field populations.

## Twenty-seven hand-written unit conversions, in one sweep

The dominant defect in this project, and this phase is where it was finally
systematic enough to sweep for. Every one multiplied or divided by a thousand, a
million or eight thousand million inside a derivation, in a notation that already
converts between units.

Three had produced visible failures. The rest were silent, and **one was silent
because two errors cancelled** — a via count a million times too large, divided by
an area a million times too large, giving the right ratio and the wrong count.

**The rule that every literal is dimensionless prevents an unlabelled quantity
entering a derivation and does nothing about a labelled one being converted
twice.** A warning on every dimensionless literal above ten would have caught all
twenty-seven, and `095` should have one. That is a change to the instruments and
it is the most valuable thing this phase learned.

## What is still open

**The failure record has nowhere to live** (`069`). `063`'s spare remap needs to
know which conductors are bad and it must outlive a power cycle. **Three
blueprints now need the same missing non-volatile store** — this one, `033`'s
fault record and `040`'s repair map.

**The memory mode's bandwidth is not in `055`** (`069b`). One pane a millisecond
against a hundred thousand a second, and neither blueprint has reconciled.

**Two mappings are rules rather than permutations** (`063`, `068`). Bit to pad and
bit to conductor are both stated as requirements and neither is written out, and
`069`'s receiver needs them to reassemble anything.

**Nothing records which grade a cube is built with.** The recommendation is byte
mode; `082` must sequence it and `088` must price all three.

**No serial standard is named** for the cabled grade, exactly as in `057`.

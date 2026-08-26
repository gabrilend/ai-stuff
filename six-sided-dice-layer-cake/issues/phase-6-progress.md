# Phase 6 — The Faces: progress

**One compute face, six times. Complete, and it closed the thermal chain.**

| ticket | blueprint | state |
|---|---|---|
| `601` | `041-face-floorplan` | done |
| `602` | `042-face-tile-and-reticle` | done |
| `603` | `043-instruction-set` | done |
| `604` | `044-scalar-core` | done |
| `605` | `045-matrix-engine` | done |
| `606` | `046-numeric-formats` | done |
| `607` | `047-face-cache-slice` | done |
| `608` | `048-face-sequencer` | done |
| `609` | `049-face-control-and-status` | done |

**Two hundred and thirty-three constraints hold across forty blueprints.** Only
thirty-four remain unevaluated, all reaching into phases 7 through 11.

## The chain that had been waiting

`025` has been carrying the largest term in the machine's thermal budget as a
pair of guesses since phase 3. `041` now derives both from a layout, and the
chain closes end to end for the first time:

| | |
|---|---|
| heat to remove | 1891 W |
| junction, hottest point, worst-served face | 318.9 K — about 46 °C |
| margin to the silicon's limit | **59 K** |
| the hot spot's share of everything above the inlet | 47 % |
| usable core capacity | 71.9 GB |
| aggregate core bandwidth | 38.4 TB/s |

Every one of those is within about a per cent of what the documentation written
in phase 3 estimated by hand, which is the first real evidence that the estimates
were not fiction.

## The finding that reverses an intention

**Lateral spreading through a thinned die does not work, at all.**

Scattering the multiplier array into sixty-four tiles was meant to let heat
spread sideways into the cold memory around each one. Moving one tile's share two
millimetres sideways through a hundred micron die costs **over a hundred kelvin**
— more than ten times the local convection excess it was supposed to relieve.

`C-041-5` now asserts that in the failing direction rather than being deleted,
because it is a reasonable expectation and somebody will have it again.

The scattering stays, for two reasons that are real and were not the stated ones:
the coolant picks the heat up evenly along its path instead of dumping the whole
engine load on twenty channels, and sixty amperes spread across a die is a power
grid `030` can build where sixty amperes into one block is not.

**The actual remedy for the hot spot is still unexplored**: vary the channel
density across the cold plate to match the power map. Manufacturable, absent from
`022`, and the best uncosted idea in the thermal design.

## What the checker caught

**Four duplicate declarations.** `020` had been estimating the array's operation
rate, its power and its operand demand before `045` existed; `025` had been
guessing the engine's area and power shares before `041` did. The ledger refuses
a name declared twice, which is what forced the ownership question to be answered
rather than drifting.

**Two more hand-written unit conversions**, bringing the running total to five
across four phases. One turned nineteen nanoseconds into six and a half seconds.
They are by a wide margin the most common defect in this project, and the rule
that every literal is dimensionless does nothing about them.

**A power grid four times too thin.** Seventy amperes across a die through three
microns of top metal is a hundred millivolts against a twenty-two millivolt
allowance. Sixteen microns, three quarters given to power, regulators moved
directly beneath the dies.

**A constraint that checked its own definition.** The hold-up capacitance was
derived from what it needed to achieve, so comparing the two proved nothing. It
is a component somebody buys now, and the constraint checks the choice.

## A small piece of notation

A width is a number of bits; an exponent is a pure number. Two-to-the-width needs
a conversion between them, so `046` declares one unit quantity for the purpose.
It is the only such thing in the project and it is worth knowing it was needed.

## What is still open

**`E_op` is the most load-bearing unsourced number in the project** (`045`). A
quarter of a picojoule per operation, with the cold plate's channel width and the
radiator's face area both downstream of it.

**The counter constraint is weaker than it reads** (`609`). It counts twelve
counters against seven model terms, which proves there are enough and nothing
about whether they measure the right things.

**Nothing reports an out-of-range address** (`609`, `038`), because there is no
mechanism to detect one.

**Three questions from `009` remain untouched by this phase**: where the sampler
runs (F3), whether the group scale should be eight bits (F1), and whether a face
should hold three layers rather than two (F2). All three are priced now and none
is decided.

# 605 — Sixty-five thousand multipliers

Produces `src/045-matrix-engine.md`.

## Current behavior

**Done.** `src/045-matrix-engine.md` exists and opens by admitting the array is
idle most of the time, with the justification: prompt processing and batched
serving both sit above the crossover, and single-stream generation is the case
the machine must not be slow at rather than the case it is sized for.

**The transposed multiply that training needs is priced three ways and the
cheapest chosen**: stream differently during the backward pass rather than making
the array bidirectional or holding weights twice. It costs operand bandwidth,
which the slice has, rather than area or capacity, which it does not.

Seven constraints. This blueprint also **took ownership of three symbols `020`
had been estimating** — the array's operation rate, its power, and its operand
demand — which the ledger caught as duplicate declarations.

**`E_op` is the most load-bearing unsourced number in the project.** A quarter of
a picojoule per operation, and everything from the cold plate's channel width to
the radiator's area is downstream of it.

## Intended behavior

**The multiplier array: its shape, its dataflow, how a four-bit weight becomes an
operand, and where its heat is.** This is where nearly all the transistors and
nearly all the power in the machine are, and it is what `306` is waiting for.

### The array

Two hundred and fifty-six by two hundred and fifty-six cells, sixty-five thousand
five hundred and thirty-six multiply-accumulate units, at one point four gigahertz.
Two operations per cell per cycle gives about a hundred and eighty-three trillion
operations a second per die, four and a half quadrillion for the machine.

**And it is idle most of the time**, which the blueprint must say plainly on the
first page rather than letting a reader discover it in `1106`. Generating one
token requires two operations per weight and reading the weight takes twenty-eight
times as long as doing them. The array only earns itself above a batch of about
twenty-eight, and below that it is waiting for memory.

That raises a fair question — *why is it this big?* — and the blueprint must answer
it: because prompt processing and batched serving both operate above the crossover,
and those are the workloads the machine is for. Single-stream generation is the
case it must not be *slow* at, not the case it is *sized* for. If that argument
does not hold for the intended use, the array should shrink and the die with it,
and the cube would get smaller.

### The dataflow

Weights stationary, activations streaming, is the arrangement that suits this
machine: a weight is read once from the slice and used for every sequence in the
batch, which is exactly the reuse `004`'s third leg describes. The blueprint must
show the reuse factor as a function of batch size and mark where it saturates.

### Weight expansion, in the datapath

Weights arrive as four-bit indices into a sixteen-entry table shared by a group of
a hundred and twenty-eight, with one scale per group. They must become operands.

**The expansion happens in the datapath, not in a separate pass.** A separate pass
would mean writing expanded weights somewhere, and expanded weights are four times
the size, which the slice cannot hold. So the table lookup and the scale
multiplication sit between the slice and the array and run at full rate. This is a
real circuit with a real area and it belongs here rather than being assumed away.

### The heat, which `306` needs

Sixty square millimetres of array making about forty watts is two thirds of a watt
per square millimetre against a die average of a tenth. The blueprint must produce
a **power map at tile resolution** so that `601` can checkerboard it and `306` can
integrate it. This is the deliverable that unblocks the largest open question in
the project.

It must also produce the **slew**: how fast the array's current rises when
operands arrive, which is what `404`'s thirty-four microfarads exists for, and how
much a sixty-four cycle ramp reduces it.

## Symbols this must publish

Array dimensions and cell count. Clock. Operations per second per die and per
machine. Cell area and array area. Energy per operation. Power at full and at
typical utilisation. Reuse factor against batch size. Expansion path area and
energy. Power map at tile resolution. Peak current and slew rate. Accumulator
width.

## Constraints this must assert

- Array area plus expansion plus accumulators is within `601`'s allocation.
- Operations per second times energy per operation equals the engine power in
  `301`.
- Peak current matches the step in `404`, which sized the decoupling from it.
- The crossover batch derived here agrees with `1105`'s. Two blueprints, two
  routes, one number.
- Accumulator width is sufficient that no reduction in `1103` overflows, at the
  largest matrix in the reference model.

## Suggested implementation steps

1. Fix the array shape and derive the throughput.
2. Write the paragraph about it being idle, and the justification, before anything
   else, because it changes how the rest is read.
3. Specify the dataflow and the reuse curve.
4. Design the expansion path and give it its area.
5. Produce the power map at tile resolution and hand it to `601` and `306`.
6. Derive peak current and the ramped version and hand both to `404`.

## Blocks

`306`, `601`, `404`, `1103`, `1106`.

## Blocked by

`603`, `606`, `607`.

## Related documents

`004` for the reuse this exists to harvest. `008` entry 5.

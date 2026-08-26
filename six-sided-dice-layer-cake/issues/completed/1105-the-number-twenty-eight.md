# 1105 — The number twenty-eight

Produces `src/079-batching-and-occupancy.md`.

## Current behavior

**Done.** `src/079-batching-and-occupancy.md` exists with the one-line derivation
first and the three corrections after it.

Six constraints. `C-079-1` is the check that says the machine is balanced rather
than accidentally sized: `047` chose the batch to provision the slice for, this
derives the crossover from bandwidth and arithmetic, and the two arrive at the
same number within fifteen per cent by completely different routes.

**One correction had its sign wrong and the checker found it.** Including the
cache was assumed to *lower* the crossover, on the reasoning that more memory
traffic means the memory wall arrives sooner. It raises it: cache traffic scales
with batch, so it lifts both lines and the arithmetic one has further to climb.

**The array utilisation is a `given`** -- what a weights-stationary array achieves
when tile reloads are not perfectly overlapped, and `045` has not said whether
they are. **And the starved region is named without being bounded.**

## Intended behavior

**The crossover between the bandwidth-bound and compute-bound regimes, derived
from first principles, with the occupancy consequences on either side.**

### The derivation

Per step — one token for every sequence in the batch:

- **Weight traffic** is the whole model, once, regardless of batch. Thirty-five
  gigabytes at thirty-nine terabytes a second is nine tenths of a millisecond.
- **Arithmetic** is two operations per weight per sequence. A hundred and forty
  gigaflop times the batch, at four and a half petaflop a second, is thirty-two
  microseconds times the batch.

Equal when the batch is about twenty-eight. Below it the machine waits for memory
and the multipliers are nearly free. Above it the memory has been amortised and
the multipliers are the wall.

**One division, and it governs everything about how this machine should be used.**
The blueprint should present it that plainly and then complicate it, rather than
the other way round.

### Where the simple derivation is wrong

Three terms it omits, and the blueprint must add them:

**The cache.** Key and value traffic scales with batch *and* with context, so at
long context the memory side is not constant in batch and the crossover moves
down. `1102` has the crossover length; this blueprint has to combine them into a
crossover *surface*.

**The pipeline.** Above the crossover, all six faces must be busy, which needs at
least six microbatches in flight. A batch of twenty-eight split six ways is
microbatches of four or five — fine. A batch of eight is microbatches of one or
two, which is above the crossover in aggregate and starved per stage. **There is a
region where the machine is compute-bound and still cannot fill its pipeline**,
and the blueprint must find it.

**Efficiency, not peak.** The four and a half petaflop figure assumes every
multiplier has an operand every cycle. At small microbatch the array is partly
idle even when it is running. The blueprint must give achieved rather than peak,
which moves the crossover up.

### What it means for how the machine is used

Below the crossover: latency is nine tenths of a millisecond per token and adding
sequences is free. **This is the region a single user experiences and it is the
machine at its most impressive** — a seventy billion parameter model at over a
thousand tokens a second.

Above it: throughput saturates and latency grows with batch. The operator's job is
to sit at the crossover.

The blueprint should give the curve — tokens per second and latency per token,
both against batch — because that curve is the machine's actual specification and
`1303` will print it.

## Symbols this must publish

Weight traffic per step. Arithmetic per step per sequence. Achieved rather than
peak arithmetic rate against microbatch size. Crossover batch, simple and
corrected. Crossover surface against context length. Minimum batch for a full
pipeline. Throughput and latency curves against batch.

## Constraints this must assert

- Crossover batch derived here equals `605`'s and `704`'s. **Three blueprints,
  three routes, one number.**
- Minimum batch for a full pipeline is at least the stage count.
- Throughput at the crossover equals `1106`'s figure.
- Achieved arithmetic rate at the design microbatch is within a stated fraction of
  peak, or the array is oversized and `605` should be told.

## Suggested implementation steps

1. Do the one-line derivation and state the result before complicating it.
2. Add the cache term and produce the surface.
3. Find the compute-bound-but-starved region.
4. Replace peak with achieved and move the crossover.
5. Produce both curves.

## Blocks

`704`, `1106`, `1303`.

## Blocked by

`605`, `704`, `1102`, `1104`.

## Related documents

`008` entry 5. `003` for the two regimes as a story.

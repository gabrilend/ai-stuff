# 704 — The schedule the machine exists to run

Produces `src/053-sieve-schedule.md`.

## Current behavior

**Done.** `src/053-sieve-schedule.md` exists with both regimes drawn separately,
because the machine's schedule genuinely changes shape between them and one
diagram would have been wrong in one of the two.

Seven constraints. **`009` entry S1 is closed**: the bubble from a sequence
ending mid-pipeline propagates, and the arithmetic says why that is the right
answer rather than the lazy one — at the batch sizes this machine is for it costs
under a per cent, and the alternative interacts with `039`'s ordering in a way
nobody has traced.

This blueprint also took ownership of the stage time, which `026` had been
estimating since phase 3.

**The tolerance on stage equality is a `given` and `075` has not been told.** Five
per cent is what the balance must achieve, and nothing has checked that an
integer number of layers per face can achieve it when face zero carries an
embedding table and face five an output projection.

## Intended behavior

**The pipeline: what each of the six faces is doing at each moment, in both
operating regimes, with the handoff protocol and the bubble rules.**

### The two regimes are different machines

**Bandwidth-bound, below a batch of about twenty-eight.** One face works at a time
and takes the core's entire bandwidth. The others are idle and this costs nothing,
because they would have been queueing for the same memory. A token takes six
stages of about a hundred and fifty microseconds each, nine tenths of a millisecond
in total, and the engines are busy for about four per cent of it.

**Compute-bound, above the crossover.** All six faces must work at once on
different microbatches, or five sixths of the arithmetic is wasted. This needs **at
least six microbatches in flight**, one per stage, and that requirement is the
central rule of this blueprint.

The blueprint must present both and must be explicit that the machine's schedule
changes shape between them, because a single schedule that is correct in one regime
is wrong in the other.

### The handoff

Stage *n* finishes, writes its staging buffer, and executes `506`'s release. Stage
*n+1* has been polling and executes an acquire. Two barriers, one buffer, no locks.

The blueprint must state the **polling cost**: a face waiting on a flag is issuing
reads into the core, and six faces polling is bandwidth that could have been
weights. A back-off is required and its parameters belong here.

### The bubbles

Three of them, each with a rule:

**Fill and drain.** The first five microbatches enter an empty pipeline and the
last five leave a draining one. For a prompt of any length this is negligible; for
a single short generation it is the whole cost. The blueprint should give the
crossover length.

**A sequence that ends mid-pipeline.** `009` entry S1. Six microbatches in flight,
one has produced its end marker, and the stages behind it now carry a partly empty
batch. Letting the bubble propagate wastes a sixth of a step. Letting a face pull
work forward interacts with `506`'s ordering in a way nobody has traced. **This
ticket must close it**, and the safe answer — let it propagate, and refill at the
next entry to stage zero — should be chosen unless the arithmetic says the waste
is large.

**An uneven stage.** `1101` gives face zero and face five extra work. If the stages
are not equal, the slowest sets the rate and every other face waits. The blueprint
must state the tolerance and hand the balancing requirement back to `1101`.

## Symbols this must publish

Stage time in each regime. Tokens per second in each regime. Crossover batch.
Minimum microbatches in flight. Staging buffer size required. Barrier cost. Polling
back-off parameters. Fill and drain cost. Bubble cost per ended sequence. Stage
imbalance tolerance.

## Constraints this must assert

- Microbatches in flight is at least the stage count, in the compute-bound regime.
- Staging buffer size times count is within `505`'s allocation.
- Stage imbalance is within tolerance, checked against `1101`'s assignment.
- Crossover batch derived here equals `605`'s and `1105`'s. **Three blueprints,
  three routes, one number** — the most valuable cross-check in the project.
- Polling bandwidth is under a stated fraction of aggregate.

## Suggested implementation steps

1. Write both regimes separately and give each its own timing diagram.
2. Specify the handoff and cost the polling.
3. Close `009` entry S1 with arithmetic rather than a preference.
4. Give the fill and drain cost and the prompt length where it stops mattering.
5. Hand the imbalance tolerance to `1101`.

## Blocks

`705`, `706`, `1101`, `1105`, `1106`.

## Blocked by

`504`, `505`, `506`, `703`, `608`.

## Related documents

`003`. `008` entry 5, which this blueprint is the mechanism behind.

# 706 — The arithmetic the claim rests on

Produces `src/055-sieve-bandwidth.md`.

## Current behavior

**Done.** `src/055-sieve-bandwidth.md` exists with the chain from the tiers to
the engine and a margin at every stage.

`C-055-1` is the architecture's central claim reduced to a single number that
must be one: **one face gets the whole aggregate.** Three separate blueprints must
each permit it and any one failing would kill it, and this is where that is
checked rather than assumed.

Six constraints, all holding. Non-weight traffic comes out well under a per cent.

**The spout's average is a use assumption, not a hardware property.** A pane every
millisecond is ordinary operation; a machine being used as memory through `069b`
takes them far more often, and `C-055-5` would be the first thing to notice —
which means **the memory mode has a bandwidth cost nothing has budgeted for.**

**The sensitivity table the ticket asked for is deliberately not here**, because
it belongs in `080` and putting it in two places is the duplication this project
exists to avoid. So this answers *does it keep up* and not *what if it changes*.

## Intended behavior

**The bandwidth accounting for the whole interconnect, end to end, showing where
the bottleneck is and by how much.**

### The chain

```
   the array           bits per tier per cycle × tiers × clock     39 TB/s
        │
        ▼
   the crossbar        bisection, from 504                        must exceed
        │
        ▼
   one radial link     energy budget, from 702                    ~50 TB/s
        │
        ▼
   the slice           write port, from 607                       must exceed
        │
        ▼
   the engine          operand rate, from 605                      the consumer
```

**The bottleneck must be the array**, and the blueprint's job is to show that
every other stage exceeds it with a stated margin. If any stage is narrower, that
stage becomes the machine's speed and every performance number in `1106` is wrong.

### The question this blueprint answers

*Can one face take all of it?*

This is the load-bearing claim of the whole architecture. `008` entry 5 argues that
passing tokens through six faces in series costs nothing because the faces would
have been contending for the same memory anyway — and that argument is only true if
a single face can pull the full thirty-nine terabytes a second when the others are
idle. If it can only pull a sixth, the sieve costs a factor of six in latency and
the machine is six times slower at exactly the thing people will measure first.

Three things must each be shown to permit it, and any one of them failing kills it:

- `504`'s crossbar must route the whole array to one port.
- `702`'s link must carry it inside its power allocation.
- `607`'s slice must absorb it.

### The other traffic

The weight stream is the whole story, but the blueprint must account for the rest
so that nobody discovers later that it mattered: staging handoffs, sequencer small
reads, spout panes, scrub traffic, and polling. Each as a fraction of aggregate.
**The expected answer is that all of them together are under a per cent**, and if
polling is not, `704`'s back-off is wrong.

### Where it goes when the model changes

A sensitivity table. Double the model and the time per token doubles. Halve the
weight width and it halves. Raise the batch and nothing changes until the crossover,
then everything does. This table is what `1106` builds on and what somebody
evaluating the machine will actually read.

## Symbols this must publish

Bandwidth at every stage of the chain. Margin at each. Bottleneck identification.
Single-face maximum as a fraction of aggregate. Per-class traffic fractions. Time
per token in both regimes. Sensitivity to model size, weight width and batch.

## Constraints this must assert

- Every stage after the array exceeds the array's bandwidth with a stated margin.
- Single-face maximum equals aggregate. **The claim, as a constraint.**
- Non-weight traffic is under a stated fraction of aggregate.
- Time per token derived here matches `1106`'s. Two routes, one number.

## Suggested implementation steps

1. Build the chain and find the bottleneck. If it is not the array, stop and fix
   whichever stage it is, because the design intends the array.
2. Check the three single-face conditions individually.
3. Account for every other traffic class.
4. Build the sensitivity table.

## Blocks

`1105`, `1106`.

## Blocked by

`501`, `504`, `605`, `607`, `702`, `703`, `704`.

## Related documents

`004`. `008` entry 5. This is the blueprint the machine's central claim lives in.

# 045, 046 — what a thinking machine costs — info

How much memory a machine needs in order to think, itemised, and whether that
fits on a given board. One calculation, used by everything that has to know.

## Running it

```
luajit src/046-what-fits.lua [--context N] [--precision NAME]
```

Prints a table for several model shapes across several board sizes, then checks
the arithmetic against itself.

## What `045` exports

| Name | Meaning |
|---|---|
| `PRECISION_BYTES` | bytes per number, per storage format |
| `weights(shape, precision, shapes)` | what the model itself costs |
| `cache(shape, context, width)` | what remembering costs |
| `working(shape, width)` | the vectors one step needs while it happens |
| `total(options)` | all of it, itemised, plus which term is largest |
| `longest_thought(options, available, resident)` | how much context fits |
| `strategy(options, available)` | which rung of the ratchet is affordable |

## Why this is the most important arithmetic here

The whitepaper names the fitting constraint as the risk most likely to be
fatal: weights must fit the medium, then fit in memory *alongside* working
space and a growing cache, then leave enough speed to be useful, and the model
must still be capable enough to write correct assembly unaided.

Nothing here answers whether such a model exists. What it does is make the
question **arithmetic rather than argument**.

## Which term runs out first is more useful than the sum

The report says which one dominates, because the remedy differs. Weights
dominating means a smaller model is the only answer. Cache dominating means a
shorter thought is *also* an answer, and a machine that cannot hold its full
context can still think in shorter breaths — which is better than refusing to
start.

At the reference points: a small model at a 2048 context is weight-dominated; a
very small one at the same context is **cache**-dominated, because fewer key
heads were not used there. The arrangement of a model changes which wall it
hits.

## Two functions that must be told the same thing

`strategy` may choose to keep only part of the model resident. `longest_thought`
must then be told how much is actually resident, or it answers for a different
machine — which it did, reporting a thought of zero beside a strategy that would
have worked. It now takes that figure and the caller passes what the strategy
chose.

## What the engine can read is asked, not remembered

`046` plans in whatever precision it is told, and the format (`024`) describes
more precisions than the arithmetic implements — so the report says on the same
line as its numbers when it is costing a currency the engine will not accept.

**That claim used to be a literal list here, and it went stale.** It said f32 and
nothing else, which was true when written and was still on the page long after
the quantised kernel landed on all three architectures — so every weight figure
in the report carried a warning that it was seven times too small, while the
engine was reading those weights correctly. Fixed on 2026-08-08 by asking
`043-emit-kernels` instead, through `reads(precision)`, which resolves a
precision to the kernel that reads it and confirms that kernel is actually in
the emitted list. Deleting a kernel now withdraws the claim by itself.

This is the same defect `401` paid for and named — a hand-kept table of what
exists, and a check that agreed with it because both were reading the same stale
copy. It is worth expecting in any file that describes another file's
capabilities.

## Checks in `046`

The cache is linear in thought length, so nothing is counted per layer that
should be counted once. The longest thought that fits actually fits, and one
position longer does not — an off-by-one there is a machine that fails partway
into its first long thought, which is the worst moment to find out. A board far
too small is refused rather than given a strategy it cannot run. More memory
never selects a slower rung. And the compact storage format is genuinely
smaller than the plain one, or there is no reason to carry its complication
into the inner loop.

## Result on 2026-08-08

9 of 9. It read 6 of 6 here from 2026-08-02 until checks were added without
anyone coming back to this line — the same drift that put a stale claim about
the engine's precisions in the report itself. A dated record of a run is fine to
write down; a live claim about what another file can do is not, and should be
asked for instead.

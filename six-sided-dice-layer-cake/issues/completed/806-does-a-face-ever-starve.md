# 806 — Does a face ever starve

Produces `src/061-feed-bandwidth.md`.

## Current behavior

**Done.** `src/061-feed-bandwidth.md` exists with four inequalities and their
timescales stated separately, because the four are easy to conflate and only the
middle two ever bind.

The below-crossover answer is written plainly: **the face starves and this is the
intended state.** `C-061-6` asserts it in the confirming direction, because a
design in which it were false would mean the array had become too small rather
than the memory too fast.

`C-061-3` is the one that earns the blueprint: `040` asserts that scrubbing is
invisible, and **this is the only place that claim is tested against the traffic
it would have to be invisible against.**

Six constraints. `C-061-5` closes the project's third triple check — time per
token derived here, in `053` and in `055`, by three different routes.

**The uneven stage is not modelled.** `075` gives two faces extra work; this
checks a face's margin against an average layer, and the face carrying the output
projection reads a larger one in the same stage time.

## Intended behavior

**The feed accounting: what a face consumes, what each tier can supply, and the
margin at every point in the chain, at every operating point.**

Where `706` accounts for the interconnect, this accounts for the *supply* — the
same chain seen as a question about whether the engine ever waits.

### The chain, as a rate balance

```
   what the engine eats      operands per second, from 605
        must be ≤
   what the slice serves     read port rate, from 607
        must be ≤ (over a layer)
   what the core delivers    per-face share of 39 TB/s, from 504
        must be ≤ (over a load)
   what the media delivers   1.28 TB/s, from 802     -- only at load
```

Each inequality has a different timescale and the blueprint must be explicit about
which, because they are easy to conflate. The engine's is per cycle. The slice's is
per layer. The core's is per token. The media's is per power cycle.

### The two answers

**Below the crossover**, the engine is starved by design and it does not matter.
It waits for the core, the core is the bottleneck, and the machine's speed is the
core's bandwidth divided by the model size. The right statement is not "the face
does not starve" but "**the face starves and this is the intended state**", which
is a much clearer thing to write down.

**Above the crossover**, the engine must not wait, and whether it does depends
entirely on `805`'s prefetch keeping ahead against `504`'s contention. This is
where the arithmetic earns its keep, and where the answer is genuinely uncertain
until `504`'s arbitration policy is fixed.

### The cases that break it

The blueprint should look for the corner rather than reporting the average:

- **All six faces prefetching simultaneously.** Each gets a sixth. Is the lead time
  in `805` still enough?
- **A scrub cycle landing on the bank a face is reading.** `507` says scrub is
  invisible; here is where that is checked rather than assumed.
- **A spout burst.** Two mebibytes at low priority, but `504` gives it a bounded
  worst-case wait, and during that wait it is consuming.
- **An uneven stage.** `1101` gives face zero and face five extra work; they read
  more per stage and have the same time to do it in.

### The load case

Separate and much easier. Thirty-five gigabytes over five lines at a quarter of a
terabyte each is thirty milliseconds, and the only thing that can go wrong is the
relay of the sixth slice in `802`, which adds a fifth. The blueprint should give
the number and move on.

## Symbols this must publish

Consumption rate per tier per operating point. Supply rate per tier. Margin at
each inequality. Starvation cycles per token in each corner case. Load time with
and without the relay. Worst-case face and why it is the worst.

## Constraints this must assert

- Slice read rate meets engine consumption at full utilisation.
- Per-face core share under six-way contention meets prefetch demand at the design
  batch.
- Scrub traffic does not push any face's supply below its demand. The check `507`
  needs and cannot do itself.
- Load time is under the stated ceiling from `802`.
- Time per token derived from this chain agrees with `706`'s and `1106`'s. **Three
  routes, one number**, and the third of the project's triple cross-checks.

## Suggested implementation steps

1. Write the four inequalities with their timescales stated.
2. Write the below-crossover paragraph plainly — the engine starves on purpose.
3. Work each corner case and report the worst, not the mean.
4. Do the load case in a paragraph.
5. Close the three-way agreement with `706` and `1106`.

## Blocks

`1106`.

## Blocked by

`504`, `507`, `605`, `607`, `802`, `805`, `1101`.

## Related documents

`004`. `706` is the same chain from the interconnect's side.

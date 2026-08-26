# 805 — Fetching the next layer while computing this one

Produces `src/060-prefetch-and-double-buffer.md`.

## Current behavior

Nothing. `607` sized the slice for two layers on the strength of a prefetch that
has never been specified.

## Intended behavior

**The policy that keeps a face's engine fed: when the next layer's weights are
requested, into which buffer, and what happens when they are late.**

### The easiest prefetch problem there is

Almost every prefetcher in computing has to guess. This one does not. `608`'s
descriptor chain is built at load time and never changes, so **the address of every
byte a face will read for the rest of the token is known before the token starts.**

There is no prediction, no history table, no confidence counter and no
mis-speculation. The blueprint should say so early, because a reader arriving from
general-purpose processors will expect a much more complicated document.

### What it actually has to get right

**When to start.** Early enough that the layer is resident before the engine wants
it, and no earlier, because starting early means holding a buffer longer. The
lead time is the core's worst-case latency from `703` plus the transfer time,
and the blueprint must use worst case rather than typical — a prefetch that is
usually early is a machine that occasionally stalls.

**Not disturbing the engine.** The prefetch writes into one slice buffer while the
engine reads the other. `607`'s banking must let both run at full rate, and this
blueprint must confirm the rate rather than assume it.

**Sharing the core with five other faces.** Six faces prefetching at once is the
compute-bound regime's normal state, and each gets a share of `504`'s arbitration
rather than the whole. The lead time must be computed against the *contended*
latency, not the uncontended one, or every face stalls whenever all six are busy.

### When it is late

It will be, occasionally: a bank conflict, a corrected error, a scrub cycle that
landed badly. The options are to stall the engine, or to begin the layer with a
partial buffer and hope the rest arrives.

**Stall.** Simple, correct, and measurable — `609` should count the cycles so that
`1106`'s model can be checked against reality. Beginning on a partial buffer is
the kind of optimisation that works until the day it does not and then produces a
wrong answer instead of a slow one.

### The third buffer

`009` entry F2. A third buffer would let the prefetch run two layers ahead and
absorb contention. It costs four hundred and thirty-seven megabytes that do not
fit on the current die. This blueprint should quantify **how often a stall
actually happens with two buffers**, because that number is what decides whether
the third one is worth a larger die, and nobody has produced it.

## Symbols this must publish

Lead time, uncontended and contended. Transfer time per layer. Buffer count and
the swap rule. Stall probability with two buffers at each operating point. Stall
cycles per token. Engine and prefetch concurrent bandwidth requirement. The
counter `609` must provide.

## Constraints this must assert

- Lead time at contended worst-case latency is shorter than the time the engine
  spends on the previous layer. **The constraint the whole scheme rests on.**
- Engine read plus prefetch write bandwidth is within `607`'s concurrent capacity.
- Stall cycles per token are under a stated fraction of a token, at the design
  operating point.
- Slice capacity is at least buffer count times layer size. Restated from `607`
  so that changing the buffer count here fails there.

## Suggested implementation steps

1. State that the access pattern is known in advance and that no prediction
   exists.
2. Derive the lead time from `703`'s contended worst case.
3. Confirm concurrency against `607`'s banking.
4. Choose stalling over partial starts and specify the counter.
5. Produce the stall probability so the third buffer can be argued about.

## Blocks

`806`, `609`, `1106`.

## Blocked by

`504`, `607`, `608`, `703`, `804`.

## Related documents

`004` for the leg this hides. `009` entry F2.

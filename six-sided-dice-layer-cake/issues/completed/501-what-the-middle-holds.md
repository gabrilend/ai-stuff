# 501 — What the middle holds

Produces `src/034-core-organisation.md`.

## Current behavior

**Done, and the tier count changed while it was being written.**
`src/034-core-organisation.md` exists with the capacity chain as symbols.

Thirty-two tiers was the first sketch. `035` then derived an areal density from
the bitcell upward rather than quoting one, and at that density thirty-two tiers
hold half again what the reference model needs — silicon nobody uses, paying
leakage forever. **Twenty-four lands just above sixty-four gibibytes usable**, and
gives each tier a thicker cooling lamina into the bargain. The tier count came
out of the chain rather than going into it, which is what the chain is for.

Six constraints. The one that matters is `C-034-2`: one face may take the whole
bandwidth. Every other blueprint in the project would continue to check if that
were quietly a sixth, and `008` entry 5 would be wrong.

**A division by a thousand nearly ruined it.** `C_tier` was written with a manual
megabyte-to-gigabyte conversion in a notation that does conversions itself. Being
a dimensionless literal it was silent, and it made the core a thousand times too
small.

**The bank collision estimate assumes independent addresses** and they are six
streams walking six contiguous regions in step. `038` owes the real analysis.

## Intended behavior

**The core's capacity, its division into banks, and its aggregate bandwidth,
derived from `012`'s geometry and `035`'s areal density rather than chosen.**

### The capacity chain

```
   tier footprint            [L_core] squared          1600 mm²
        × areal density      from 035                  1.55 MB/mm²
   = capacity per tier                                 2.48 GB
        × [n_tier]                                     32
   = raw capacity                                      79.4 GB
        − error correction   from 040                  −12.5 %
        − spare rows and columns                       −2 %
        − one redundant tier reserved                  −3.1 %
   = usable capacity                                   ≈ 64 GiB
```

Every step is a symbol. The interesting property of writing it this way is that
`078` can ask *what model fits* and get an answer that moves when the tier count
or the node does.

### Banking

Six faces read this simultaneously and the sieve gives them access patterns that
are large, sequential and disjoint — face two is reading face two's layers and
nobody else is. That is the easiest possible pattern to bank for and the blueprint
should say so, because it justifies a simple scheme where a complicated one would
otherwise be assumed.

The bank count must be large enough that six streams plus the spout plus scrub
traffic rarely collide, and small enough that the crossbar in `504` stays
buildable. The blueprint must derive the collision probability rather than
asserting a bank count is enough.

### Bandwidth

Thirty-nine terabytes a second aggregate, and it is not a chosen number either:

    tiers × bits per tier per cycle × clock

Thirty-two tiers, eight thousand one hundred and ninety-two bits each, at one point
two gigahertz. The blueprint must show what limits each factor — the bits per cycle
by the macro count and the local routing, the clock by `035`'s access time — so
that a reader can see which one to attack.

**And it must state the property the whole architecture rests on: one face may
take all of it.** If the crossbar can only give a face a sixth, the sieve becomes a
six-times latency penalty for single-stream generation instead of being free. This
is the single most consequential requirement the core places on `504`.

## Symbols this must publish

Capacity per tier, raw, and usable, with every deduction named. Bank count, bank
size, bank interleave. Bits per tier per cycle. Core clock. Aggregate read and
write bandwidth. Per-face maximum bandwidth. Collision probability at six streams.

## Constraints this must assert

- Usable capacity exceeds the reference model's residency requirement from `078`,
  with the key and value cache included.
- Per-face maximum bandwidth equals aggregate bandwidth. The single-face-takes-all
  requirement, as a constraint rather than a paragraph.
- Aggregate bandwidth times the read energy from `035` equals the core power in
  `301`. A cross-check between two blueprints in different phases.
- Bank count is a power of two and the interleave granularity matches the sieve's
  transfer size from `703`.

## Suggested implementation steps

1. Build the capacity chain in symbols with every deduction visible.
2. Derive bandwidth from the three factors and say what limits each.
3. Choose the banking from the collision analysis, not from habit.
4. Write the single-face-takes-all requirement as a constraint and make sure `504`
   cites it.

## Blocks

`502`, `503`, `504`, `505`, `1104`.

## Blocked by

`103`, `502` for the density, `301` for the power cross-check.

## Related documents

`004` for the middle leg of a weight's journey. `000` for the shape.

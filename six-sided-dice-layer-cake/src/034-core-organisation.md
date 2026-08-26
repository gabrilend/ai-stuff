# 034 — What the middle holds

```meta
phase  | 5
issues | 501
```

The core's capacity, its banking and its bandwidth, derived from `012`'s geometry
and `035`'s areal density rather than chosen.

## The capacity chain

```drawing
from a tier's footprint to what a model can use [not-dimensioned]

   one tier's area            [A_core_side]
        × areal density       [d_areal]
   = capacity per tier        [C_tier]
        × tier count          [n_tier]
   = raw                      [C_core_raw]
        − error correction    [f_ecc_overhead]
        − spare rows          [f_spare]
        − one redundant tier  [f_redundant]
   = usable                   [C_core_usable]
```

Every step is a symbol, so `078` can ask *what model fits* and get an answer that
moves when the tier count or the node does.

**The tier count came out of this chain rather than going into it.** Thirty-two
tiers was the first sketch, chosen because it made the stack pitch a round
number. At the areal density `035` actually derives, thirty-two tiers holds far
more than the reference model needs, and the excess is silicon nobody uses and
leakage everybody pays. Twenty-four tiers lands just above sixty-four gibibytes,
and gives each tier a thicker cooling lamina into the bargain.

## Banking

Six faces read this at once, and the sieve gives them the easiest access pattern
there is: **large, sequential and disjoint.** Face two is reading face two's
layers and nobody else wants them.

That justifies a simple banking scheme where a complicated one would otherwise be
assumed, and the blueprint should say so rather than letting a reader think the
simplicity was carelessness. The bank count has to be large enough that six
streams plus the spout plus the scrubber rarely collide, and small enough that
`037`'s crossbar stays buildable.

## Bandwidth, and the property the architecture rests on

Bits per tier per cycle, times tiers, times the core clock. Each factor is
limited by something nameable — the width by the macro count and the tier's own
routing, the clock by `035`'s access time — so a reader can see which one to
attack.

And then the requirement that matters more than the number: **one face may take
all of it.**

If the crossbar can only give a face a sixth, the sieve becomes a six-fold
latency penalty for single-stream generation instead of being free, and `008`
entry 5 — the most interesting result in the project — stops being true. This is
the single most consequential thing the core asks of `037`.

## Symbols

```symbols
w_tier_port   | bit | given | 10240 | bits one tier delivers per cycle, set by its macro count and the routing it can support across a forty millimetre die
f_core        | GHz | given | 1.25  | core clock, set by the array access time in 035
f_ecc_overhead| 1   | derived | n_ecc_check / (n_ecc_line + n_ecc_check) | share of raw capacity spent on check bits
f_spare       | 1   | given | 0.02  | share held as spare rows and columns within a tier, blown at test
f_redundant   | 1   | derived | 1 / n_tier | share held as one whole spare tier, mapped in if another fails
n_bank        | 1   | given | 256   | independent banks across the whole core
n_bank_min    | 1   | given | 1000  | how many cycles' worth of read the smallest sensible bank holds

C_tier        | GB    | derived | A_core_side * d_areal                   | capacity of one tier. Written first with a division by a thousand to turn megabytes into gigabytes, which is exactly the manual conversion the notation exists to make unnecessary -- and which, being a dimensionless literal, silently made the core a thousand times too small
C_core_raw    | GB    | derived | n_tier * C_tier                         | raw capacity of the stack
C_core_usable | GB    | derived | C_core_raw * (1 - f_ecc_overhead) * (1 - f_spare) * (1 - f_redundant) | what a model may actually use
B_core        | bit/s | derived | n_tier * w_tier_port * f_core           | aggregate read bandwidth, every tier delivering at once
B_face_max    | bit/s | derived | B_core                                  | what a single face may take when the others are idle. Equal to the aggregate, deliberately, and 037 has to deliver it
B_face_even   | bit/s | derived | B_core / n_face                         | and what it gets when all six are asking equally
C_bank        | GB    | derived | C_core_raw / n_bank                     | capacity of one bank
p_collide     | 1     | derived | 1 - (1 - 1/n_bank)^(n_face + 2)         | chance that two of the eight clients -- six faces, the spout and the scrubber -- want the same bank in the same cycle, assuming their addresses are independent
t_core_sweep  | s     | derived | C_core_raw * 8 / B_core                 | how long it takes to read the whole core once at full bandwidth, which is what 040's scrub and 069b's memory mode are both measured against
```

## Constraints

```constraints
C-034-1 | C_core_usable > C_resident      | usable capacity must exceed what the reference model needs resident, weights and cache together, from 078
C-034-2 | B_face_max == B_core            | one face may take the whole of it. The single-face-takes-all requirement as a constraint rather than a paragraph, because 008 entry 5 depends on it and a crossbar that quietly delivered a sixth would leave every other blueprint still checking
C-034-3 | B_core * E_core_bit ~= P_core_read | bandwidth times read energy is the core's read power in 020. A cross-check between two phases, and what it catches is one of the two being retuned alone
C-034-4 | p_collide < 0.05                | eight clients wanting the same bank at once must be rare, or 037's arbiter is arbitrating rather than switching
C-034-5 | C_bank > w_tier_port * n_bank_min | a bank must be much larger than a single cycle's worth of read, or the banking is finer than the transfers and every transfer straddles two banks
C-034-6 | n_tier > 4                      | a stack too short to lose a tier to redundancy without losing a quarter of the capacity is not a stack; this is what makes the redundant-tier scheme affordable
```

## What is still open

**The areal density is the most optimistic number in the project** and `035`
derives rather than quotes it. Everything above scales linearly with it: at three
quarters of the assumed figure the reference model no longer fits, and the
machine's central claim goes.

**The collision estimate assumes independent addresses.** They are not — six
faces walking six contiguous regions in step is about as correlated as access
patterns get, and whether that makes collisions rarer or more frequent depends on
`038`'s interleaving. The number here is a placeholder for an analysis `038`
should do and does not.

# 053 — The schedule the machine exists to run

```meta
phase  | 7
issues | 704
```

## The two regimes are different machines

```drawing
below the crossover, one sequence [not-dimensioned]

   face 0  ████████████                                          weights
   face 1              ████████████                              streaming;
   face 2                          ████████████                  the engines
   face 3                                      ████████████      are idle
   face 4                                                  ███   four fifths
   face 5                                                     ██ of the time
           └──────────────── one token ────────────────────────┘

   five faces idle at any moment, and it costs nothing: they would
   have been queueing for the same memory


above the crossover, six microbatches in flight

   face 0  ████ A ████ B ████ C ████ D ████ E ████ F ████
   face 1       ████ A ████ B ████ C ████ D ████ E ████
   face 2            ████ A ████ B ████ C ████ D ████
   face 3                 ████ A ████ B ████ C ████
   face 4                      ████ A ████ B ████
   face 5                           ████ A ████

   every face busy; fewer than six microbatches and it is not
```

**Below the crossover** one face works at a time and takes the core's entire
bandwidth. The others are idle and it costs nothing, because they would have been
contending for the same memory. This is why the sieve is free rather than
expensive, and it is the whole of `008` entry 5.

**Above it** all six must work at once on different microbatches, or five sixths
of the arithmetic is wasted. That needs **at least six microbatches in flight**,
and that requirement is the central rule of this blueprint.

## The handoff

Stage *n* finishes, writes its staging buffer, releases. Stage *n+1* has been
polling and acquires. Two barriers, one buffer, no locks.

**Polling costs bandwidth.** A face waiting on a flag is issuing reads into the
core, and six faces polling is weight traffic that did not happen. A back-off is
required and its parameters are here rather than left to an implementation.

## The bubbles

**Fill and drain.** The first five microbatches enter an empty pipeline and the
last five leave a draining one. Negligible for a prompt of any length; for a
single short generation it is the whole cost, and the crossover length is given
below.

**A sequence that ends mid-pipeline.** `009` entry S1. Letting the bubble
propagate wastes a sixth of a step; letting a face pull work forward interacts
with `039`'s ordering in a way nobody has traced. **The bubble propagates**, and
the arithmetic below says why that is affordable: at the batch sizes this machine
is for, a sixth of a step lost per ended sequence is under a per cent.

**An uneven stage.** If the stages are not equal the slowest sets the rate.
`075` owes the balance and this blueprint owes it a tolerance.

## Symbols

```symbols
n_microbatch  | 1 | given | 6      | microbatches in flight above the crossover, one per stage
f_poll_backoff| 1 | given | 0.01   | share of a stage a polling face spends actually issuing reads, the rest being back-off
tol_stage     | 1 | given | 0.05   | how unequal the six stages may be before the slowest visibly sets the rate
f_end_rate    | 1 | given | 0.02   | share of steps in which some sequence in the batch produces an end marker

t_token       | s | derived | C_weights * 8e9 / B_core           | time for one token, bandwidth-bound: every weight read once at the core's aggregate rate
t_stage       | s | derived | t_token / n_stage                  | how long one face works before the sieve moves on
t_token_comp  | s | derived | batch_design * flop_token / ops_machine | and what one step would take if arithmetic were the wall
C_stage_buf   | MB | derived | C_activation * batch_design / n_microbatch | one staging buffer: a microbatch of activation vectors
C_stage_min   | MB | derived | C_activation                        | the least a staging buffer can be and still hold one sequence's activations
B_poll        | bit/s | derived | n_face * f_poll_backoff * w_transfer / t_link_rt | bandwidth six polling faces consume
f_poll_cost   | 1 | derived | B_poll / B_core                      | that as a share of the core's
n_fill        | 1 | derived | n_stage - 1                          | microbatches that enter an empty pipeline before it is full
f_fill_cost   | 1 | derived | n_fill / (n_fill + n_token_typical)  | what filling and draining costs on a generation of typical length
n_token_typical | 1 | given | 500                                  | tokens in a generation long enough to be worth measuring
f_bubble_cost | 1 | derived | f_end_rate / n_stage                 | what letting an ended sequence's bubble propagate costs
```

## Constraints

```constraints
C-053-1 | n_microbatch >= n_stage       | there must be at least one microbatch per stage above the crossover, or a face has nothing of its own to work on and five sixths of the arithmetic is idle. The central rule of the sieve
C-053-2 | C_stage_buf >= C_stage_min    | a staging buffer must hold at least one sequence's activations
C-053-3 | f_poll_cost < 0.001           | six faces polling must cost under a thousandth of the core's bandwidth, which is what the back-off is for
C-053-4 | f_fill_cost < 0.02            | filling and draining the pipeline must cost under a fiftieth on a generation worth measuring
C-053-5 | f_bubble_cost < 0.01          | letting an ended sequence's bubble propagate must cost under a hundredth, which is what makes the simple answer to 009 entry S1 the right one
C-053-6 | t_token > t_token_comp        | the machine must be bandwidth-bound at the design batch, which is what the whole architecture assumes. If this inverts, the crossover has been passed and 079's analysis applies rather than this one
C-053-7 | t_link_rt < t_stage * tol_stage | a link round trip must be small against the tolerance on stage equality, or the interconnect's own variation is what makes the stages unequal
```

## What is still open

**The tolerance on stage equality is a `given` and `075` has not been told.**
Five per cent is what the balance has to achieve and nothing has checked whether
an integer number of layers per face can achieve it, given that face zero carries
an embedding table and face five an output projection.

**The back-off parameters are one number.** A share of a stage spent issuing is
not a back-off policy — it is the result one would produce. What the policy
actually is, and how it behaves when a stage runs long, is not written.

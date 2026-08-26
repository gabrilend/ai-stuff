# 079 — The number twenty-eight

```meta
phase  | 11
issues | 1105
```

## The derivation, in one line

Per step — one token for each sequence in the batch:

**Weight traffic is the whole model, once, regardless of batch.** **Arithmetic is
two operations per weight per sequence.** They are equal at one particular batch,
and that number governs everything about how this machine should be used.

```drawing
the two lines that cross [not-dimensioned]

   time per step
     │
     │  ╲                            ╱  arithmetic: rises with batch
     │   ╲                        ╱
     │    ╲__________________ ╱
     │     weights: flat        ╳
     │                        ╱   ╲
     └────────────────────────┴──────────────▶ batch
                         the crossover
        bandwidth-bound  │  compute-bound
        sieve is free    │  pipeline must be full
```

## Where the simple derivation is wrong

Three terms it omits, and the blueprint adds them.

**The cache.** Key and value traffic scales with batch *and* with context, so the
memory side is not constant in batch and the crossover moves **down** at long
context. It is a surface, not a point.

**The pipeline.** Above the crossover all six faces must be busy, needing at least
six microbatches in flight. A batch of eight split six ways is microbatches of one
or two — **compute-bound in aggregate and starved per stage**, which is a real
region and the blueprint finds it.

**Efficiency, not peak.** The peak arithmetic figure assumes every multiplier has
an operand every cycle. At small microbatch the array is partly idle even while
running, which moves the crossover **up**.

## What it means for how the machine is used

**Below**: latency is one bandwidth-bound token and adding sequences is free. This
is the region a single user experiences, and it is the machine at its most
impressive.

**Above**: throughput saturates and latency grows with batch. The operator's job
is to sit at the crossover.

## Symbols

```symbols
eta_array_util | 1 | given | 0.82   | share of cycles a multiplier has an operand at the design microbatch, which is below one because a tile reload is not overlapped perfectly
n_micro_min    | 1 | derived | n_stage | microbatches needed to keep every stage busy

t_step_weights | s | derived | C_weights / B_core                     | time for one step's weight traffic, which does not depend on batch
t_step_kv      | s | derived | B_kv_tok / B_core                      | and its cache traffic, which does
t_step_mem     | s | derived | t_step_weights + t_step_kv             | the memory side of a step
ops_achieved   | flop/s | derived | ops_machine * eta_array_util      | arithmetic the machine actually delivers rather than its peak
t_step_arith   | s | derived | batch_design * flop_token / ops_achieved | the arithmetic side at the design batch
batch_cross    | 1 | derived | t_step_weights * ops_achieved / flop_token | the batch at which the two are equal, ignoring the cache
batch_cross_kv | 1 | derived | t_step_weights / (flop_token / ops_achieved - t_step_kv / batch_design) | and including it. It comes out *higher*, not lower: the cache adds to the memory side in proportion to batch, so the arithmetic line has further to climb before it crosses
f_batch_err    | 1 | derived | abs(batch_cross - batch_design) / batch_design | how far the batch the machine is provisioned for sits from the crossover it derives
micro_size     | 1 | derived | batch_design / n_micro_min             | sequences in one microbatch at the design batch
tok_per_s_1    | 1/s | derived | 1 / t_token                          | tokens a second, one sequence
tok_per_s_agg  | 1/s | derived | batch_design / max(t_step_mem, t_step_arith) | and aggregate at the design batch
gain_batch     | 1 | derived | tok_per_s_agg / tok_per_s_1            | what batching buys, which is the number an operator cares about most
```

## Constraints

```constraints
C-079-1 | f_batch_err < 0.15          | the batch the machine is provisioned for must be within fifteen per cent of the crossover it independently derives. 047 chose the provisioning and this derives the crossover from bandwidth and arithmetic; the two arriving at the same number by different routes is what says the machine is balanced rather than accidentally sized
C-079-2 | micro_size >= 1             | there must be at least one sequence per microbatch at the design batch, or the pipeline cannot be filled and the compute-bound region is unreachable
C-079-3 | n_micro_min == n_stage      | one microbatch per stage is the minimum, which is 053's central rule restated where the batch arithmetic lives
C-079-4 | gain_batch > 10             | batching must buy more than an order of magnitude, or the whole compute-bound regime is not worth provisioning for
C-079-5 | eta_array_util < 1          | achieved arithmetic must be below peak. Asserted in the confirming direction, because a performance model built on peak is the commonest way to be wrong about a machine like this by twenty per cent
C-079-6 | batch_cross_kv >= batch_cross | including the cache must raise the crossover. Written the other way round first, on the assumption that more memory traffic means the memory wall arrives sooner -- but cache traffic scales with batch, so it lifts both lines and the arithmetic one has further to climb
```

## What is still open

**The array utilisation is a `given`.** Eighty-two per cent is what a
weights-stationary array achieves when tile reloads are not perfectly overlapped,
and `045` has not said whether they are.

**The starved region is described and not bounded.** A batch above the crossover
but too small to fill six stages is a real region and the blueprint names it
without saying where it begins and ends.

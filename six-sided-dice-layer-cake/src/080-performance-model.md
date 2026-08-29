# 080 — The two numbers it is judged on

```meta
phase  | 11
issues | 1106
```

## The model

    t_token  =  t_weights + t_cache + t_arith + t_handoff
                + t_barrier + t_stall + t_bubble

Seven terms. The first dominates by orders of magnitude below the crossover — and
the model carries all seven anyway, because **the small ones are where the machine
will actually fall short of prediction**, and `049` is required to provide a
counter for each.

That requirement is the most valuable thing here. A performance model with no
instrumentation is a claim; one with a counter per term is **a hypothesis
somebody can test in `085`**.

## Where each term comes from

| term | owner |
|---|---|
| weights | `076`'s traffic over `055`'s bandwidth |
| cache | `076`'s cache traffic, growing with context |
| arithmetic | `079`'s achieved rate |
| handoff | `053`'s staging write and read |
| barrier | `039`'s release and acquire, six times |
| stall | `060`'s prefetch misses |
| bubble | `053`'s fill, drain and ended-sequence bubbles |

**Nothing is estimated here.** A term with no owner is missing from the design,
not from the model.

## The two numbers

**Single-stream latency**, which is what one person waits — and the surprising
part, from `008` entry 5, is that the six-stage pipeline costs almost nothing to
get it.

**Aggregate throughput at the crossover**, which is what an operator buys.

Both are published, and the sheet in `089` must say which is which — because a
machine evaluated on one chat window at a time is being measured on the first
number while being sold on the second.

## Prefill, which is a third case

Reading a prompt is not generating. Every position is available at once, so the
arithmetic scales with prompt length while the weight traffic does not — **prefill
is compute-bound almost immediately** and runs at the array's rate. For long
prompts it is most of the wall-clock time a user experiences, so it is given
separately.

## The comparison

Both halves, because either alone misleads. The machine wins on **memory
bandwidth**, which is what generation is bound by. It does not win on
**capacity**, where its figure is unremarkable.

## Symbols

```symbols
t_weights     | s | derived | C_weights / B_core                    | reading every weight once
t_cache       | s | derived | B_kv_seq / B_core                     | reading one sequence's cache, since the number this model is judged on is what one person waits
t_arith       | s | derived | flop_token / ops_achieved             | the arithmetic for one sequence
t_handoff_m   | s | derived | C_handoff * n_stage / B_core          | writing and reading the staging buffers
t_barrier_m   | s | derived | t_handoff * n_stage                   | the barriers, once per stage
t_stall_m     | s | derived | t_stall_token * n_stage               | prefetches that arrived late
t_bubble_m    | s | derived | t_token * (f_fill_cost + f_bubble_cost) | filling, draining, and sequences that ended
t_token_model | s | derived | max(t_weights + t_cache, t_arith) + t_handoff_m + t_barrier_m + t_stall_m + t_bubble_m | one token, everything counted: memory and arithmetic overlap, the rest do not

f_t_weights   | 1 | derived | t_weights / t_token_model             | the weight term's share, which is what makes this a bandwidth machine
f_overhead_tok | 1 | derived | (t_token_model - t_token) / t_token  | what the five small terms cost above the memory-bound floor 053 derives
n_model_term_d| 1 | given | 7                                       | terms in this model, which 049 must have a counter for each of
tok_s_single  | 1/s | derived | 1 / t_token_model                    | tokens a second, one sequence
tok_s_agg     | 1/s | derived | batch_design / t_step                | and aggregate at the design batch, where the weights are read once for everybody

r_tok_per_W   | 1/(s*W)      | derived | tok_s_agg / P_heat  | tokens a second for every watt the machine burns. The figure somebody buying a room full of these optimises, as opposed to the two above, which are what somebody using one notices
r_tok_per_L   | 1/(s*L)      | derived | tok_s_agg / V_cube  | and for every litre it occupies. A cube is 0.216 of a litre, so this is the number that says what the shape is worth
r_tok_per_kg  | 1/(s*kg)     | derived | tok_s_agg / m_cube  | and for every kilogram of it
f_batch_gain  | 1            | derived | tok_s_agg / tok_s_single | how much the machine gains by serving many sequences at once rather than one. It is the ratio that decides what this machine is for
t_prefill_tok | s | derived | flop_token / ops_achieved             | one prompt token during prefill, which is compute-bound
tok_s_prefill | 1/s | derived | 1 / t_prefill_tok                    | prompt tokens a second
gain_prefill  | 1 | derived | tok_s_prefill / tok_s_single          | how much faster reading a prompt is than writing one
B_ref_hbm     | bit/s | measured | 2.7e13 | memory bandwidth of an accelerator with stacked memory, as the comparison
C_ref_hbm     | GB | measured | 141.0   | and its capacity
gain_bw       | 1 | derived | B_core / B_ref_hbm                     | the ratio the machine wins on
gain_cap      | 1 | derived | C_core_usable / C_ref_hbm              | and the one it does not

t_year        | yr | given | 1.0 | one year as a quantity. A count of compounding periods is a pure number -- it is a ratio of two logarithms -- and multiplying by this is what turns it into a duration. The notation forbids a literal from carrying a unit, so the unit has to come from something with a name, and the ledger caught the first attempt at this: a time declared in years whose derivation was dimensionless
f_ref_slow    | 1 | given | 0.20  | annual improvement in the comparator's memory bandwidth, at the cautious end. **This is a number the reader supplies, not one this project knows.** It is declared here so that a claim about the future is an assumption somebody can change rather than a sentence somebody wrote
f_ref_mid     | 1 | given | 0.30  | the same, at the rate the last several generations of stacked memory have roughly managed
f_ref_fast    | 1 | given | 0.40  | and at a rate faster than has been sustained, which is the one worth quoting because it is the one that fails first

t_parity_slow | yr | derived | t_year * log(gain_bw) / log(1 + f_ref_slow) | years before a comparator improving at the cautious rate reaches the bandwidth this design starts at
t_parity_mid  | yr | derived | t_year * log(gain_bw) / log(1 + f_ref_mid)  | and at the middle rate
t_parity_min  | yr | given | 5.0 | the least the bandwidth advantage may last and still be worth attempting. A limit rather than a result, named so it is not a bare number sitting in a constraint
t_parity_fast | yr | derived | t_year * log(gain_bw) / log(1 + f_ref_fast) | and at the fast one. This is the number an investor should be shown, because it is the least favourable of the three and it is still years away
```

## Constraints

```constraints
C-080-1 | f_overhead_tok < 0.05        | the five small terms -- handoff, barriers, stalls, bubbles -- must cost under a twentieth above the memory-bound floor 053, 055 and 061 all derive by different routes. Written first as an exact agreement, which was wrong: those three derive the floor and this one adds what sits on top of it, so they cannot be the same number and requiring it would have hidden the overhead rather than measuring it
C-080-2 | n_counter >= n_model_term_d  | 049 must have a counter for every term here. This is what turns the model from a claim into a hypothesis somebody can test, and it is enumerated across two blueprints because neither can see the other's list
C-080-3 | f_t_weights > 0.5            | the weight term must be more than half of a token. If it stops being so, this is no longer a bandwidth machine and every argument in 008 entry 5 has to be redone
C-080-4 | gain_bw > 5                  | the machine must win on memory bandwidth by a wide margin, which is the only reason to build a core out of static memory
C-080-5 | gain_cap < 1                 | and it must lose on capacity. Asserted in the failing direction deliberately: the honest comparison has both halves, and a specification sheet quoting only the first would be selling something the machine is not
C-080-6 | gain_prefill > 10            | reading a prompt must be an order of magnitude faster than writing one, which is what makes the two cases worth separating
C-080-7 | f_batch_gain > 10            | serving many sequences at once must be worth at least an order of magnitude over serving one, or this machine has no reason to exist in a rack rather than on a desk. It comes to nineteen, and that number is the whole statement of what the machine is for
C-080-8 | f_batch_gain < batch_design  | the gain from batching cannot exceed the batch itself. Trivially true and worth asserting: it is the one place a performance model can flatter itself without anybody noticing, by counting a sequence twice
C-080-9 | t_parity_fast > t_parity_min | even against a comparator improving faster than stacked memory has ever sustained, the bandwidth advantage must last more than five years, or the machine is obsolete before anybody could build one. This is the constraint that decides whether the whole design is worth attempting, and it is the one most sensitive to an assumption nobody here owns
C-080-10 | t_parity_fast < t_parity_mid | a faster-improving comparator must catch up sooner. Arithmetically certain and asserted anyway: it is the cheapest possible check that the three rates were not transcribed in the wrong order, which would invert the whole argument while every number still looked plausible
C-080-11 | t_parity_mid < t_parity_slow | and the same for the middle against the cautious one
```

## What is still open

**Attention's own arithmetic is not in `t_arith`.** `076` omits it and this
inherits the omission. It scales with context length rather than with parameter
count, so at long context this model understates the arithmetic side and the
crossover in `079` is optimistic.

**`C-080-2` counts and does not name.** Twelve counters against seven terms proves
there are enough and nothing about whether they measure these seven. It is the
third place in the project with that weakness, after `072` and `077`, and all
three have the same cause: the notation holds numbers and not lists.

**The comparison is against one part.** One accelerator, one bandwidth, one
capacity — chosen because it is the obvious comparison and not because it is the
right one for any particular buyer.

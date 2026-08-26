# 1106 — The two numbers it is judged on

Produces `src/080-performance-model.md`.

## Current behavior

**Done.** `src/080-performance-model.md` exists with all seven terms, each taken
from the blueprint that owns it and none estimated.

The numbers: **about a thousand tokens a second on one sequence**, nineteen and a
half thousand aggregate at the design batch, and twenty-five thousand prompt
tokens a second during prefill. Against an accelerator with stacked memory the
machine wins **eleven times over on bandwidth** and loses on capacity, at about
half -- and `C-080-5` asserts the losing half **in the failing direction**, because
a sheet quoting only the first would be selling something this machine is not.

**The aggregate figure is lower than phase 0 estimated by hand**, and the reason
is real: that estimate omitted cache traffic, which at the reference context and
batch is a substantial share of a step.

`C-080-1` had to be rewritten. It required this model's token time to equal what
three other blueprints derive, which was wrong -- **those three derive the
memory-bound floor and this one adds what sits on top of it.** It now bounds the
overhead instead, which measures the five small terms rather than hiding them.

**Attention's own arithmetic is missing**, inherited from `076`, so at long
context this understates the arithmetic side.

## Intended behavior

**The end-to-end performance model: time per token as a sum of terms, each from the
blueprint that owns it, at every operating point.**

### The model

    t_token  =  t_weights + t_cache + t_arith + t_handoff + t_barrier
                + t_stall + t_bubble

Seven terms. The first dominates by two orders of magnitude below the crossover
and the blueprint should say so — but it must carry all seven, because the small
ones are where the machine will actually fall short of prediction, and `609` is
required to provide a counter for each so that the model can be checked against a
running machine.

That requirement is the most valuable thing in this ticket: **every term in this
model has a counter that measures it**. A performance model with no instrumentation
is a claim; one with a counter per term is a hypothesis somebody can test in
`1205`.

### Where each term comes from

| term | owner |
|---|---|
| `t_weights` | `1102`'s traffic over `706`'s bandwidth |
| `t_cache` | `1102`'s cache traffic, which grows with context |
| `t_arith` | `1105`'s achieved rate |
| `t_handoff` | `704`'s staging write and read |
| `t_barrier` | `506`'s release and acquire, six times |
| `t_stall` | `805`'s prefetch misses |
| `t_bubble` | `704`'s fill, drain and ended-sequence bubbles |

Nothing is estimated here. If a term has no owner it is missing from the design,
not from the model.

### The two numbers

**Single-stream latency**, which is what one person waits. Nine tenths of a
millisecond per token for the reference model, or about eleven hundred tokens a
second — and the surprising part, from `008` entry 5, is that the six-stage
pipeline costs almost nothing to get it.

**Aggregate throughput at the crossover**, which is what an operator buys. Around
thirty-one thousand tokens a second at a batch of twenty-eight.

The blueprint must present both and must say which is which, because a machine
evaluated on one chat window at a time is being measured on the first number while
being sold on the second.

### Prefill, which is a third case

Reading a prompt is not generating. Every position is available at once, so the
arithmetic scales with prompt length while the weight traffic does not — prefill
is compute-bound almost immediately and runs at the array's rate. The blueprint
must give prompt processing separately, in tokens a second, because for long
prompts it is most of the wall-clock time a user experiences.

### The comparison

Somebody will ask how this compares to an accelerator with high-bandwidth memory.
The honest comparison is the memory bandwidth ratio, since both are
bandwidth-bound: about twelve to one. The blueprint should give it, and should
also give the ratio the machine does *not* win on — capacity, where sixty-four
gibibytes is unremarkable.

## Symbols this must publish

Each of the seven terms. Time per token at each operating point. Tokens per second
single-stream and aggregate. Prefill rate. Sensitivity to model size, weight
width, context and batch. The counter in `609` corresponding to each term. The
comparison ratios.

## Constraints this must assert

- Time per token derived here agrees with `706`'s and `806`'s. **Three routes,
  one number** — the project's third triple check.
- Every term has a counter in `609`. Enumerated across two blueprints.
- Terms sum to the total, with nothing unattributed.
- Aggregate throughput at the crossover agrees with `1105`.

## Suggested implementation steps

1. Write the seven-term sum and get each from its owner.
2. Evaluate at every operating point.
3. Do prefill separately.
4. Walk `609` and confirm a counter per term.
5. Give the comparison, including the ratio the machine loses on.

## Blocks

`609`, `1303`.

## Blocked by

`506`, `609`, `704`, `706`, `805`, `806`, `1102`, `1105`.

## Related documents

`003`. `008` entry 5. This is the blueprint a buyer reads.

# Phase 11 — The Recipe: progress

**Cutting a model up and pouring it through. Complete, and it closed the set.**

| ticket | blueprint | state |
|---|---|---|
| `1101` | `075-layer-assignment` | done |
| `1102` | `076-token-flow` | done |
| `1103` | `077-numerics-and-accuracy` | done |
| `1104` | `078-model-capacity` | done |
| `1105` | `079-batching-and-occupancy` | done |
| `1106` | `080-performance-model` | done |
| `1107` | `076a-the-sieve-in-reverse` | done |

**Four hundred and sixty-five constraints hold across seventy-four blueprints.**
Four remain unevaluated and all four wait on a lifetime figure in `086`.

Fifty constraints had been waiting since phase 2 for the reference model. They
now resolve.

## The machine, as derived

| | |
|---|---|
| tokens a second, one sequence | **1,021** |
| tokens a second, aggregate at the design batch | **19,490** |
| prompt tokens a second, prefill | 25,594 |
| memory bandwidth against an accelerator with stacked memory | **11.4×** |
| capacity against the same | 0.51× |
| weight traffic's share of a token | over half |

The last two rows are asserted as constraints, including the losing one — because
a specification sheet quoting only the winning half would be selling something
this machine is not.

## What the estimates got right, and what they missed

Single-stream latency was estimated by hand in phase 0 at about eleven hundred
tokens a second. Derived: **a thousand and twenty-one.**

Aggregate throughput was estimated at thirty-one thousand. Derived: **nineteen and
a half thousand** — and the reason is real. The estimate **omitted cache traffic
entirely**, which at the reference context and batch is a substantial share of a
step. Weight traffic does not scale with batch; cache traffic does, and three
blueprints had been using one number where they meant the other.

## Three corrections the checker forced

**The prefetch was hiding behind the wrong thing.** A layer time derived from
memory traffic, used to size a prefetch that is itself memory traffic — which is
circular. Below the crossover a prefetch and the compute it hides behind are the
*same* traffic and cannot overlap at all. Double buffering earns itself **above**
the crossover, where arithmetic is the wall and the transfer runs underneath. The
layer time is now the arithmetic time and the prefetch has a fifth of it in hand.

**The accumulator was checked against a row.** `045` compared its accumulator
width against the width of one row of the multiplier array. The array accumulates
across many passes; the reduction is the model's widest tensor.

**The cache correction to the crossover had its sign wrong.** Including it was
assumed to lower the crossover — more memory traffic, memory wall sooner. It
raises it, because cache traffic scales with batch and so lifts both lines.

## The constraint that was asking the wrong question

`C-080-1` required this model's token time to *equal* what three other blueprints
derive. That was wrong: **those three derive the memory-bound floor and this one
adds what sits on top of it.** Requiring equality would have hidden the five small
terms rather than measuring them. It bounds the overhead now.

## What is still open

**`009` entry B4 is now askable.** Every number in the project is anchored to one
model shape, and nobody has asked what a smaller one would do to the cube — which
`012`'s chain says would shrink.

**Attention's own arithmetic is not counted** (`076`, `080`). It scales with
context rather than parameter count, so at long context the model understates the
arithmetic side and `079`'s crossover is optimistic.

**Three constraints count rather than name** (`072`, `077`, `080`). Enough
counters against enough terms proves the numbers match and nothing about whether
the same things are meant. All three have the same cause: the notation holds
numbers, not lists.

**`009` entry F1 has an answer that needs checking.** An eight-bit group scale
costs under five per cent more error and saves three per cent of the read that
dominates everything — from `measured` entries with no source.

**Only one model shape is expressed** (`078`), and `058`'s media format and
`048`'s chains both assume it.

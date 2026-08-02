# 051 — how fast it thinks — info

Times the real kernels over a real model and extrapolates to models worth
carrying. Issue `106`.

## Running it

```
luajit src/051-measure-engine.lua [--seconds N]
```

## What is measured, and what is not

**Measured:** the actual kernels, natively, doing every operation a forward
pass does. The instructions timed are the instructions a bare machine runs.

**Not measured:** a bare machine's memory system, which has no operating system
caching behind it; the other two architectures; and anything about a real
model, since the timing model is small and the rest is extrapolation.

## Results on 2026-08-02

| | tokens per second |
|---|---|
| the readable version | 10,774 |
| the assembly, one at a time | 47,038 |
| the assembly, four at a time | 54,315 |

**1.18 billion multiply-and-adds per second.**

Extrapolated by weight count, which carries better than most extrapolations
because a forward pass is very nearly one multiply-and-add per weight — though
a large model does not fit in the processor's own memory and will do worse:

| model | weights | tokens/s | a page of assembly |
|---|---|---|---|
| very small | 134 M | 8.8 | about 6 minutes |
| small | 1,100 M | 1.1 | about 46 minutes |
| medium | 8,031 M | 0.15 | about 5½ hours |

## The finding worth carrying forward

**Reading four numbers at a time is only 1.15 times faster, not four.**

The wide kernel keeps a single running total and folds each group of four into
it in order, because that is what makes it bit-identical to the plain version.
Floating-point addition is not associative, so four independent partial sums
would give a different answer — and would also be very much faster, since the
additions could then proceed in parallel instead of waiting for one another.

So this is the measured price of exact comparability: **most of the available
speedup**. It was not previously known to be that large.

That does not settle the question. It sharpens it into a choice worth making
deliberately, and both halves of it already exist in the tree: the exact kernel
is here, and a faster one would need its own reference and its own recorded
answer, at which point the two are simply different specifications rather than
one being wrong.

## What it says about the project

The bottom row is the one that matters. A machine that takes five and a half
hours to write a page of assembly is not going to build very much software. A
machine that takes six minutes is, given that it has nothing else to do and no
deadline.

Nothing here says whether a model at the top of that table is good enough to
write correct assembly unaided. That remains the question no arithmetic and no
measurement answers.

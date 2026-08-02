# 051, 063 — how fast it thinks, and the boards — info

`051` times the real kernels over a real model, natively, and extrapolates
to models worth carrying. `063` switches on the three emulated boards and
times each from power to the machine finding its own model and saying what
room it has. Issue `106`, both halves. Together with `046` they are the
phase 1 demo (`issues/completed/demos/phase-1-the-engine.sh`, reachable
through `run-demo` at the project root).

Both write their results as data under `tmp/shared-memory/measurements/`,
so a later architecture or a real board is a new row rather than a rewrite —
and so no document has to carry a figure and go stale. Run the tools when a
number is needed; the tables below are a dated record, not the truth.

## Running them

```
luajit src/051-measure-engine.lua [--seconds N]
luajit src/063-measure-boards.lua [--seconds N]
```

## What is measured, and what is not

**Measured:** the actual kernels and the assembly conducting, natively,
doing every operation a forward pass does. The instructions timed are the
instructions a bare machine runs. And per board: seconds from power to the
payload's report, and the engine-plus-weights footprint as a fraction of
what the firmware says the board has.

**Not measured:** a bare machine's memory system, which has no operating
system caching behind it; the other two architectures' engines, which do
not exist yet (`401`); real wall-clock on real silicon — the board times are
the emulator's clocks, which rank the roads against each other and say what
development costs, nothing more; and the accelerator comparison `docs/010`
wants, which cannot be made until something drives an accelerator.

## Results on 2026-08-02

| | tokens per second |
|---|---|
| the readable version | 9,912 |
| the assembly, one at a time | 44,007 |
| the assembly, four at a time | 56,233 |
| the assembly, conducted end to end | 62,401 |

**1.36 billion multiply-and-adds per second**, conducting included.

Per board, from power to the full self-report: x86-64 in about three and a
half seconds, ARM in six and a half, RISC-V in about nine — emulator time,
under one firmware road each.

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

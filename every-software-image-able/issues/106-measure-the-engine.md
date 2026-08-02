# 106 — Measure the engine

## Current behavior

**Timed, on real kernels, natively.** `src/051`, on 2026-08-02: the assembly
manages about 1.18 billion multiply-and-adds per second on this processor, four
times the readable version.

Extrapolated by weight count — which carries better than most extrapolations,
since a forward pass is very nearly one multiply-and-add per weight — a small
model writes roughly a page of assembly in six minutes, a middling one in
three quarters of an hour, and a large one in five and a half hours. The last
of those is a machine that will not build very much; the first is one that
will, given that it has no deadline and nothing else to do.

**The finding that was not expected: reading four numbers at a time is only
1.15 times faster, not four.** The wide kernel keeps a single running total so
that its answer is bit-identical to the plain one, which forces the additions
to wait for each other. Four independent partial sums would run in parallel and
be very much faster, and would give a different answer. That is the measured
price of exact comparability, and it is most of the available speedup.

Still to measure: time from power to first token on a real board, memory as a
fraction of what a board has, and anything at all on the other two
architectures. The accelerator comparison the ticket asks for cannot be made
until something drives an accelerator.

## Intended behavior

A tool that reports the numbers this project's feasibility actually rests on, so
that no document has to state a figure and go stale (`docs/011`). Run it and it
tells you where you are.

## Suggested implementation steps

1. Measure, on real hardware rather than in a simulator: time from power to first
   token; tokens per second sustained; bytes occupied by engine, by weights, and
   by working memory at full context; and the largest context that fits.
2. Report the memory numbers as a fraction of what the board has, not only in
   bytes. "Nine hundred megabytes" means nothing without the second number beside
   it.
3. Run across whatever boards are to hand, and keep the results as data rather
   than prose, so a later architecture can be added to the table without anything
   being rewritten.
4. Make it the thing the phase 1 demo runs. A demo that describes the engine is
   less useful than one that prints how many tokens per second it managed on the
   board in front of you, and the demos are part of the deliverable rather than a
   development artifact.
5. Include the one number that decides the driver question in `docs/010`: how
   much slower thinking is on the processor alone than it would be with the
   accelerator the board has. If nobody measures it, the choice between bundling
   a driver and writing one from scratch gets made on feeling.

## Blocks

The phase 1 demo, and the choice of target boards for every later phase.

## Blocked by

`105`.

## Related documents

`docs/011-roadmap.md` — demos show numbers rather than describing features.

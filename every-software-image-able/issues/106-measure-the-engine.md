# 106 — Measure the engine

## Current behavior

The engine runs. Nobody knows how fast, how large, or on what hardware it stops
being viable.

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

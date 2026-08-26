# 207 -- The phase two demo

**Phase:** 2, the world can be seen
**Blocked by:** every other issue in phase 2.
**Blocks:** nothing. It is the capstone of the phase.
**Documents:** [the roadmap](../docs/015-roadmap.md)

## Current behaviour

`./run-phase-demo` reports that no demos exist.

## Intended behaviour

An executable at `issues/completed/demos/phase-2-demo` that draws, in the
terminal, what one body can see in a generated dungeon -- then walks it down a
corridor a step at a time, showing sight change ahead of it and fog accumulate
behind.

This is the first demo that recombines an earlier phase: it loads and validates a
world through phase 1's machinery, and it uses phase 1's fixture-maker to produce
something worth looking at.

### What it shows

**A picture, because this phase is about a geometric fact and a table of numbers
would hide it.** Walls, the visibility polygon, the remembered cells, and the body,
in a terminal, redrawn as it moves. Somebody who has never read a line of this
project should be able to watch it and see what fog of war means here.

**And the numbers, because they are the phase's real result:**

| Reported | Why |
| --- | --- |
| Segments in the world; segments surviving the broad phase | Whether the broad phase is doing anything. A filter that rejects nothing is a filter that costs and buys nothing. |
| Boundaries in the resulting fan | How complicated a real visibility polygon actually is, which is what the wire cost in phase 4 will be. |
| Time for one sweep | The number everything downstream depends on. |
| Time for the whole pass at 1, 2, and all threads | Whether it scales. If it does not, that is a finding now rather than in phase 5. |
| Cells set in the fog, over time | The accumulation, as a number beside the picture. |

**The tick rate falls out of this.** [3.2](../docs/016-open-questions.md) asks how
fast the world should beat, and the honest answer comes from this demo rather than
from a document: sweep cost times the number of viewers gives the budget.

### And it must show the security claim, not just the picture

Place a thing behind a wall. Show it absent from what the body can see, and show
it appearing the moment the corner is turned. That is the whole argument of
[what a viewer is allowed to know](../docs/009-what-a-viewer-is-allowed-to-know.md),
demonstrated before the network exists to enforce it.

## Suggested implementation steps

1. Extend phase 1's fixture-maker rather than writing a second one -- it needs
   rooms, a corridor, a door, and a pillar to cast a shadow.
2. Draw with plain characters and no dependencies. This runs on a fresh checkout
   in a terminal over SSH.
3. Drive it from a scripted path so the demo is the same every run and can be
   compared against itself.
4. Report timings measured during the run. No number in any document is a
   substitute; a document with a hard-coded measurement becomes wrong without
   anybody noticing.
5. Ensure `tmp/shared-memory/` exists before writing anything ephemeral.
6. Confirm `./run-phase-demo` finds it, offers it, and runs it with and without an
   argument.

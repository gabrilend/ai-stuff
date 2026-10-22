# 108 — Phase 1 demo: a scripted conversation fading

phase 1, the fit and the fade

## Current behavior

No demos exist. `run-phase-demo` in the project root reports that no phase
is complete.

## Intended behavior

`issues/completed/demos/phase-1-demo` replays a scripted conversation of
three voices (a folder of frame files, written to show carrying, crossing
between voices, fading and vanishing) into the page keeper's arrivals folder,
then shows the numbers:

- for each page: thoughts listed, fading, hidden by the box;
- for each thought: how many frames it survived, and whether another voice
  carried it;
- a relevance-over-time chart per thought, drawn in the terminal or in a
  small window;
- the fit checker's report for one deliberately oversized frame, exactly as
  a language model would receive it.

The numbers come from the page keeper's log and goodbye receipt, not from
the demo itself, so the demo shows what the page keeper really did.

## Suggested implementation steps

1. Write the scripted frames with a small generator script, not by hand, so
   longer conversations can be made by changing its settings.
2. The run script and the chart.
3. Fill in `issues/phase-1-progress.md`.

## Related documents

- `docs/roadmap.md`, phase 1

## Blocked by

107.

## Blocks

None.

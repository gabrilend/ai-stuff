# 504 — Phase 5 demo: focused and broad

phase 5, looking into the project

## Current behavior

Phase 4's demo shows real turns without the look tool once 406 is done.

## Intended behavior

`issues/completed/demos/phase-5-demo`:

- asks the look tool one question at focus 1, 0.75, 0.5, 0.25 and 0 against
  guide-feature's own index, and shows, for each, the pieces returned and a
  chart of their similarity scores, so the shift from focused to broad can
  be seen;
- runs a few rehearsal rounds with real turns and shows each look call the
  models made: about what, at what focus, what came back;
- reports whether each voice's clone was in RAM or on disk.

## Suggested implementation steps

1. The run script and the chart.
2. Fill in `issues/phase-5-progress.md`.

## Related documents

- `docs/roadmap.md`, phase 5

## Blocked by

503.

## Blocks

None.

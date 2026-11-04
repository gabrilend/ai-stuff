# 306 — Phase 3 demo: the round trip through rmail

phase 3, the relay through rmail

## Current behavior

Phase 2's demo shows versions reaching readers on kuvalu once 206 is done.

## Intended behavior

`issues/completed/demos/phase-3-demo` runs the rehearsal (305) for a few
minutes and shows:

- per voice, a timeline of canvases received, turns run, and canvases sent;
- the round-trip time from version published to the voice's edit blitted,
  as a histogram, which shows rmail's pacing;
- canvases that waited (arrived during a turn) and were replaced before use;
- the canvas itself changing in the terminal with phase 2's marks, so phases
  1–3 run together.

## Suggested implementation steps

1. The run script, reading the rehearsal's log.
2. Fill in `issues/phase-3-progress.md`.

## Related documents

- `docs/roadmap.md`, phase 3

## Blocked by

305.

## Blocks

None.

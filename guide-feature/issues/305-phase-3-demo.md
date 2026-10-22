# 305 — Phase 3 demo: the round trip through rmail

phase 3, the relay through rmail

## Current behavior

Phase 2's demo shows the page reaching readers on kuvalu once 206 is done.

## Intended behavior

`issues/completed/demos/phase-3-demo` runs the rehearsal (304) for a few
minutes and shows:

- per voice, a timeline of frames written and pages received back;
- the round-trip time from frame written to page received, as a histogram,
  which makes rmail's 30-second rhythm visible;
- frames rmail skipped (counted by the frame-number gaps);
- the phase-2 readers watching at the same time, so all three phases' parts
  run together.

## Suggested implementation steps

1. The run script and the timeline/histogram drawing, reading the
   rehearsal's log.
2. Fill in `issues/phase-3-progress.md` and add phase 3 to `run-phase-demo`.

## Related documents

- `docs/roadmap.md`, phase 3
- `docs/rmail-constraints.md`, "Delivery is paced"

## Blocked by

304.

## Blocks

None.

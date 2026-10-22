# 206 — Phase 2 demo: two readers, one page

phase 2, the page protocol

## Current behavior

The phase-1 demo exists once 108 is done.

## Intended behavior

`issues/completed/demos/phase-2-demo` runs the phase-1 replay while two
readers watch, one reading the page files and one holding `GET /page?after=`
requests. It shows:

- pages received by each reader, and that the two copies are byte-for-byte
  equal;
- how long each page took to reach each reader;
- a box change halfway through (a stand-in viewer asking with a smaller
  `box=` under the `smallest-viewer` rule), with the page before and after
  printed side by side at their real sizes.

It also re-runs phase 1's numbers on the same replay, so the phases build on
each other.

## Suggested implementation steps

1. Two reader scripts built on the page reader (202).
2. The run script.
3. Fill in `issues/phase-2-progress.md` and add phase 2 to `run-phase-demo`.

## Related documents

- `docs/roadmap.md`, phase 2

## Blocked by

202, 203, 204, 205.

## Blocks

None.

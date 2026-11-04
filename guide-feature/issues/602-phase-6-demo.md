# 602 — Phase 6 demo: newest and distill, side by side

phase 6, distill mode

## Current behavior

No demo compares the merge modes.

## Intended behavior

`issues/completed/demos/phase-6-demo` replays the same recorded voice
canvases (saved from a rehearsal) through the blitter twice, once per mode,
and shows the two resulting canvases side by side for each version, with:
words changed per version, conflicts (newest mode), distill fit retries and
seconds (distill mode), and how many of each voice's changes survived to the
shared canvas in each mode.

Replaying recorded canvases keeps the comparison fair: both modes see exactly
the same input.

## Suggested implementation steps

1. Record a rehearsal's arrivals, then the run script.
2. Fill in `issues/phase-6-progress.md`.

## Related documents

- `docs/roadmap.md`, phase 6

## Blocked by

601.

## Blocks

None.

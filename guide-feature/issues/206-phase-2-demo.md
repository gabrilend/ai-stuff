# 206 — Phase 2 demo: two readers, marks aging

phase 2, the canvas for viewers

## Current behavior

The phase-1 demo exists once 108 is done.

## Intended behavior

`issues/completed/demos/phase-2-demo` runs the phase-1 series while two
readers watch, one on the canvas files and one holding
`GET /canvas?after=` requests. It shows:

- versions received by each reader, and that the two copies are byte for
  byte equal;
- how long each version took to reach each reader;
- the canvas drawn in the terminal with marks coloured by voice and dimmed
  by age, so the skimming idea can be seen before any real viewer exists;
- per version: cells marked `word`, cells marked `sentence`, marks expired.

## Suggested implementation steps

1. Two small reader scripts on the viewer-side reader (202).
2. The run script.
3. Fill in `issues/phase-2-progress.md`.

## Related documents

- `docs/roadmap.md`, phase 2

## Blocked by

202, 203, 204, 205.

## Blocks

None.

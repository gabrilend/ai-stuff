# 601 — the generator loop

phase 6, the room

**Depends on:** 405

## Current behavior

Films are made one at a time on request.

## Intended behavior

A loop that keeps making films: picks a sound from a pool, writes a brief from a theme list, runs the whole pipeline, keeps the run. Stops cleanly and says goodbye.

## Suggested implementation steps

1. Pools in `input/`.
2. Loop with a stop file.

## Related documents

- docs/datapath-the-room.md

# 404 — the checker loop

phase 4, the writers' room

**Depends on:** 403

## Current behavior

A malformed answer from a role would reach the renderer.

## Intended behavior

Each role's answer is checked (the director's by the shot-list sandbox's checks) and failures are sent back to the same role with the checker's message, a fixed number of times, then the run stops with that message.

## Suggested implementation steps

1. Generic loop: role, answer, checker.
2. Test with a deliberately broken answer.

## Related documents

- docs/datapath-writers-room.md

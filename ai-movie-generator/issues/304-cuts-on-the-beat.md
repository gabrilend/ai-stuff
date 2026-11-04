# 304 — cuts on the beat

phase 3, the ear

**Depends on:** 302, 206

## Current behavior

Shot times are taken as written.

## Intended behavior

Shots with `cut = "beat"` have their start moved to the nearest onset within a tolerance; the previous shot's length adjusts to meet it, staying within 3–6 s or the move is refused with a message.

## Suggested implementation steps

1. Snapping pass between loading and rendering.
2. Test: shots snap; impossible snaps are refused.

## Related documents

- docs/datapath-shot-to-clip.md
- docs/shot-list-format.md

# 402 — the creators arc in semantic space

phase 4, the writers' room

**Depends on:** 401, 302

## Current behavior

No arc is plotted.

## Intended behavior

The creator writes one waypoint per beat-sheet section from the brief. Waypoints are embedded; step distances between neighbours are compared to the music's energy changes; the creator revises until they correspond within a tolerance or a revision limit is hit (then the run stops with the measurements). Output `arc.lua` with waypoints and step sizes. Role instructions in `assets/roles/creator.md`.

## Suggested implementation steps

1. Role file.
2. Embed, measure, compare.
3. Revision loop.

## Related documents

- docs/datapath-writers-room.md

# 201 — the shot list sandbox

phase 2, shots into motion

**Depends on:** 101

## Current behavior

No shot list format exists in code.

## Intended behavior

Loading `shot-list.lua` in a sandbox offering exactly film, cast, place, shot, monologue and the motion constructors. The loader returns one film table: settings, cast and place by name, shots in time order. It checks: unique ids, known cast/place names, shots that tile the film without gaps or overlaps, lengths within 3–6 s for ordinary shots (monologues exempt). Errors name the line and the word.

## Suggested implementation steps

1. The sandbox environment table.
2. The checks, as a list of checker functions run in order.
3. Tests: one good list, one per kind of mistake.

## Related documents

- docs/shot-list-format.md

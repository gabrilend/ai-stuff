# 403 — Waypoint paths that lock

**Phase:** 4 — Factories and engineers
**Blocked by:** 402

**Blocks**: 404, 405, 603
**Related documents:** docs/datapath-production.md, notes/vision (Supreme
Commander paths)

## Current Behavior

Units appear at the factory and stand still.

## Intended Behavior

- A new factory is in the *pathing* state. Its waypoints are given within
  the map-then-dashboard rhythm: map click on a place, then the waypoint
  button; the path is shown as a line; the lock button (map click on the
  factory, then lock) fixes it. A factory does not produce
  until locked.
- Once locked, the path cannot be edited by any command. The simulation
  refuses such commands with an error event.
- Each unit made walks the waypoints in order and, at the last one, joins the
  stand waiting there (a new stand is formed if none is).

## Suggested Implementation Steps

1. Waypoint list + lock flag in the factory; path-editing commands only valid
   while unlocked.
2. Unit walking along the path (reusing stand movement).
3. Tests: commands to a locked path are refused; units arrive in path order.

## Open questions

- Waypoints are places, not stands: is "map click on a place, then the
  waypoint button" the right reading of the rhythm? (Open question 1.)

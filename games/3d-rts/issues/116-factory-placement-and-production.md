# 116 — Factory Placement & Production

## Status

TODO

## Current behavior

There is no factory. Units exist only because of the startup spawn
from issue 106.

## Intended behavior

A single UI button in a corner of the screen reads "Place Factory."
Clicking it enters *placement mode*:

- A ghost factory follows the terrain pick point (using
  `terrain_pick`).
- Left-click commits placement. Right-click cancels.
- Esc also cancels.

Once placed, the factory:

- Renders as a larger box (or short cylinder, distinct from units).
- Owns a production timer. Every `FACTORY_BUILD_INTERVAL_TICKS`
  (e.g. 10 seconds × `SIM_TICK_HZ`), it produces one unit at its
  position, with a default rally of "stand here."

The factory belongs to the player's team. Phase 1 supports exactly one
factory per game (multi-factory is a Phase 2+ concern). When a
factory already exists, the button is disabled.

## Suggested implementation steps

1. Create `src/080-factory.c` / `.h` with a single `Factory` struct
   (placed bool, position, build_timer, rally chains).
2. Render a button overlay using raylib's text drawing — a clickable
   rectangle in screen space. Track hover/click state on main thread.
3. On button click, set `placement_mode = true` on main thread.
4. Each frame in placement mode, draw a translucent ghost of the
   factory at the picked terrain point.
5. On left-click while in placement mode, emit
   `FACTORY_PLACE(world_x, world_y)` and exit placement mode.
6. In sim, on `FACTORY_PLACE`, write the factory's position and start
   its build timer.
7. Each sim tick, advance the build timer; when it reaches the
   interval, spawn a new unit at the factory's location and reset the
   timer. The new unit gets its rally chain from the factory's
   current chain set (rally chains arrive in issues 116/117 — for now,
   the unit just spawns and stands).

## Related documents

- `docs/002-mechanics.md` — factory rules.
- Issues 117, 118 — rally points.

## Notes

A single factory in Phase 1 keeps the round-robin logic for chains
(issue 118) testable in isolation. Multi-factory adds a layer of
"which factory is selected for rally editing" that we'd rather defer.

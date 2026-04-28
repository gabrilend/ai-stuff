# 106 — Unit Entity & Box Rendering

## Status

TODO

## Current behavior

There are no units. The simulation publishes a placeholder marker only.

## Intended behavior

A unit data structure exists in `src/050-units.c` / `.h`. A small fixed
pool (`MAX_UNITS` from config) is allocated up front. A handful of
units are spawned at startup at varied X/Y positions on the terrain,
and they render as colored boxes (raylib `DrawCubeV`/`DrawCubeWires`)
sitting flat on the terrain at their X/Y.

The render loop reads unit positions from the snapshot, never from the
unit array directly.

## Suggested implementation steps

1. Define `Unit` in `src/050-units.h` with: id, position (Vector3),
   facing (float yaw), team id (Phase 1 uses two teams for testing
   combat in later issues), alive bool.
2. Allocate the pool in `units_init()`. No dynamic allocation per unit.
3. Add a `units_spawn(team, x, y)` returning a new unit's id.
4. Add unit array snapshot fields and copy them into the snapshot
   each tick.
5. Render each alive unit as a box of `UNIT_SIZE_WORLD` colored by
   team. Place the box base at `terrain_height_at(x, y)`.
6. Spawn ~6 units of two teams at startup so combat issues have
   something to operate on.

## Related documents

- `docs/002-mechanics.md` — unit rules.

## Notes

Two teams in Phase 1 is a testing scaffold, not a feature: the vision
does not include opposing players, but combat needs targets. Make team
assignment a config knob so the demo can switch to "all one team, no
combat" or "two teams, free-for-all."

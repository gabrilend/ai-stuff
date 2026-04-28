# 107 — Unit Movement on Terrain Surface

## Status

TODO

## Current behavior

Units are stationary. They have no concept of a target position.

## Intended behavior

Each unit has an optional `target_xy` (Vector2). When set, the unit
walks toward it at `UNIT_SPEED_WORLD_PER_SEC`, with its Z always equal
to `terrain_height_at(x, y)` so the unit stays on the surface. When
the unit reaches the target (within a small radius), `target_xy` is
cleared.

The simulation tick advances every unit's position by
`speed * dt_tick` toward `target_xy`. There is no obstacle avoidance
or pathfinding — straight-line movement.

For testing, a temporary key (e.g. `T`) sets every alive unit's target
to a random terrain point so the movement system can be observed
without selection or right-click yet.

## Suggested implementation steps

1. Add `target_xy` and `has_target` to `Unit`.
2. In `units_tick(dt)`, for each unit with `has_target`:
   - Compute 2D delta to target.
   - Step by `min(UNIT_SPEED * dt, distance)`.
   - Clear the target when within `UNIT_REACH_RADIUS`.
   - Update Z from `terrain_height_at`.
3. Add a temporary debug input event for "scatter" that sets random
   targets, hooked to `T`. This is throwaway scaffolding — flag it
   with a `// TODO(issue-109): remove once orders work` comment.
4. Confirm visually that units glide over hills smoothly.

## Related documents

- `docs/002-mechanics.md` — movement rules.

## Notes

The scatter key is the kind of temporary scaffolding the user's
guidelines warn about: write it, keep it through one commit, then
delete it after issue 109 supplies the real input. Track its expected
removal in this issue so it is not forgotten.

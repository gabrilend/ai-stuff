# 112 — Javelin Projectile

## Status

TODO

## Current behavior

There are no projectiles. Units cannot fire.

## Intended behavior

A projectile pool of `MAX_PROJECTILES` cylinders exists in
`src/060-projectiles.c`. A function
`projectile_spawn(origin, target_world_point, shooter_id)` allocates a
projectile from the pool with:

- Initial position = origin (the shooter's eye).
- Velocity = `(target_world_point - origin)` normalized, scaled by
  `JAVELIN_SPEED_WORLD_PER_SEC`. **Velocity is set once and never
  changed** — no homing, no gravity.
- Lifetime in ticks (`JAVELIN_LIFETIME_TICKS`).

Each tick, every alive projectile:

- Advances by `velocity * dt_tick`.
- Decrements its lifetime.
- Checks if it has hit a unit (any team, including friendly fire — the
  vision is silent so we err on simple).
- Checks if it has fallen below the terrain.
- Despawns on hit, ground impact, or lifetime expiry.

Render: cylinders pointing along velocity, scaled small.

## Suggested implementation steps

1. Define `Projectile` struct: id, alive bool, position (Vector3),
   velocity (Vector3), shooter_id, target_id (informational only,
   *not* used to home), ticks_remaining.
2. Implement `projectile_spawn` and `projectile_tick(dt)`.
3. Hit check: cheap AABB-vs-segment test against alive units; first
   hit wins. On hit, *do not* directly mutate the target's HP — emit
   a damage-intent record `(target_id, 10.0, shooter_id,
   projectile_id)` into the tick's intent buffer. The single-threaded
   merge step (described in `docs/004-architecture.md`) applies the
   damage. This indirection is what makes projectile integration safe
   to run as a parallel pass over slices.
4. Ground check: if the projectile's Z drops below
   `terrain_height_at(x, y)`, despawn.
5. Mirror alive projectiles into the snapshot.
6. Render with `DrawCylinderEx(start, end, r, r, slices, color)` where
   start/end are along the velocity direction.

## Related documents

- `docs/002-mechanics.md` — projectile rules.

## Notes

Damage is `JAVELIN_DAMAGE = 10.0f` (config). Units have `UNIT_MAX_HP =
30.0f`, so three javelin hits destroy a unit absent regeneration.
Regeneration of `0.02 HP` every `0.2 s` is documented in
`docs/002-mechanics.md` and applied in issue 113. Damage and HP are
floats so the regen accumulator works without rounding drift.

The damage-intent indirection is non-negotiable: it is what makes the
projectile pass safe under the slice-batching pattern in
`docs/004-architecture.md`. Direct mutation would make adoption of the
coroutine pool a redesign rather than a swap.

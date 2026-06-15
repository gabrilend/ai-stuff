# 115 — Aiming Variance Per (Shooter, Target)

## Status

TODO

## Current behavior

From issue 113, every shot aims dead-center at the target. Every shot
that connects, connects; every shot that misses misses for spatial
reasons unrelated to "aim." The miss-memory rule from the vision is
not yet in place.

## Intended behavior

Each unit keeps a small associative table mapping `target_unit_id` to
`consecutive_miss_count`. When the unit fires at a target:

1. Take the target's X/Y.
2. Sample a 2D offset from a distribution whose width grows with the
   miss count for that target. A simple choice: each axis offset is
   uniformly random in `[-w, w]` where
   `w = MISS_VARIANCE_BASE + MISS_VARIANCE_GROWTH * miss_count`,
   capped at `MISS_VARIANCE_MAX` so it does not run away.
3. Compute `aim_z = terrain_height_at(aim_x, aim_y)` so the javelin is
   thrown at the point on the *ground*, not at the target's body
   floating at variance offset.
4. Spawn the projectile at the aim point.

When a projectile hits the same target id stored on the projectile
(via `target_id` from issue 112), the shooter's miss counter for that
target resets to zero.

When the projectile expires, hits another unit, or hits the ground,
the shooter's miss counter for the original target *increments by one*.

Counts are uncapped except by the variance width cap.

## Suggested implementation steps

1. Add a fixed-capacity miss-table to `Unit`: an array of pairs
   `(target_id, miss_count)`, with linear scan. `MAX_MISS_TARGETS = 8`
   is plenty — when full, evict the least-recently-updated entry.
2. On firing (issue 113), look up the miss count for the chosen target,
   compute the aim X/Y with the variance, set Z from the terrain,
   spawn the projectile with `target_id` recorded.
3. In the merge step (architecture doc), for every despawned
   projectile, look up the shooter's miss table:
   - Hit landed on the projectile's recorded `target_id` → set count
     to 0.
   - Hit landed on any *other* unit → increment count (the shot still
     missed the *intended* target).
   - Hit the ground or expired → increment count.
4. Add a debug overlay (config-flagged) that prints, near each
   selected unit, its current miss counts for each enemy.

## Related documents

- `docs/002-mechanics.md` — variance rules.

## Notes

The choice to aim at the *ground point* (terrain Z under the variance
offset) rather than at "wherever the body would be if you missed" is
explicit in the vision: "thrown toward the point those X/Y values
intersect with the terrain." This gives misses a satisfying
"projectile hits the dirt nearby" character that homing or body-aimed
variance would not.

## Task pool integration

**Recommended priority: 2** — runs as part of the firing-intent
generation in issue 113's targeting+firing slice tasks. Same
priority class. No new task type is introduced.

The variance lookup (per-shooter, per-target) and the variance
sample happen inline inside the firing-intent action of the
targeting slice. The firing intent that gets written to scratch
includes the variance-adjusted aim point, which the merge step's
projectile spawn then uses verbatim — no recomputation.

The miss-counter UPDATE happens in a separate place: the **damage
application merge step** of issue 113 (priority 1) is where
projectiles' fates are known (hit recorded target / hit other
unit / hit ground / expired). That merge step writes back the
shooter's miss counter for the relevant target. Priority 1 is
correct here — the counter must be updated this tick or the next
firing decision uses stale state.

In short: variance read happens at priority 2 (firing decision);
variance write happens at priority 1 (merge step). Both are
inside existing 113 tasks; this issue doesn't add a third task
type.

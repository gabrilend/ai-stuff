# 113 — Combat Targeting & Firing

## Status

TODO

## Current behavior

Units exist, can move, and have line-of-sight queries. Projectiles
exist. Nothing connects them: nobody fires.

## Intended behavior

Each tick, for each alive unit:

1. Find the nearest enemy unit *to which* `los_can_see` returns true
   and whose distance is within `UNIT_FIRE_RANGE_WORLD`.
2. If found and the unit's fire cooldown has expired, fire a javelin
   at that target's position (issue 115 will introduce the variance —
   for this issue, aim is dead-on the target's center).
3. Reset the fire cooldown to `UNIT_FIRE_COOLDOWN_TICKS`.

Firing happens regardless of whether the unit is moving — the vision
explicitly requires "fire while moving."

## Suggested implementation steps

1. Add `fire_cooldown_ticks` (int), `hp` (float, init `UNIT_MAX_HP`),
   and `regen_accum_seconds` (float) to `Unit`.
2. Run a regen pass each tick (slice-batched, slice-disjoint per the
   architecture doc): for each alive unit,
   `regen_accum_seconds += dt_tick`. When `regen_accum_seconds >=
   REGEN_INTERVAL_SECONDS` (0.2), `hp = min(hp + REGEN_AMOUNT (0.02),
   UNIT_MAX_HP)` and subtract the interval from the accumulator
   (loop in case `dt_tick` exceeds 0.2, though that should not happen
   at 60 Hz).
3. Run a targeting+firing pass each tick (slice-batched as a per-task
   *firing-intent* list, not direct projectile spawns):
   - Iterate enemies, compute squared distance, pick nearest with
     LoS within `UNIT_FIRE_RANGE_WORLD`.
   - If a target is found and cooldown ≤ 0, append a firing-intent
     `(shooter_id, target_id, shooter_eye_pos)` to the task scratch.
     The merge step at end-of-tick spawns projectiles from intents
     so the projectile pool is mutated single-threaded.
   - Decrement cooldown otherwise.
4. Track `last_target_id` on each unit (used by issue 115 for the
   miss-memory keyed by target).
5. After the merge step applies damage intents (issue 112), units
   whose HP has dropped to ≤ 0 are marked dead in a final
   single-threaded pass.

## Related documents

- `docs/002-mechanics.md` — combat rules, HP, regen.
- `docs/004-architecture.md` — slice-batching pattern for the per-tick
  passes (regen, targeting, firing).
- Issue 115 — variance.

## Notes

Targeting is "nearest visible enemy" in Phase 1, with no manual attack
order. The vision does not give the player a way to designate targets,
and Phase 3 ("advanced movement") is where attack-move and target
priority belong. Resist any urge to add target-priority knobs here.

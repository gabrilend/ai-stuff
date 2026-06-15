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

## Task pool integration

This issue spans three distinct subsystems with different priority
profiles:

**HP regeneration — priority 4.** Slice-batched per-unit pass.
Regen is gameplay-relevant but slow (0.02 HP per 0.2s); a one-tick
delay is invisible. Lower priority than movement / LoS so it
doesn't preempt them.

```
regen_slice_task_actions = [
    [0] iterate_units_in_slice
    [1] advance_each_units_regen_accumulator
    [2] cap_each_units_hp_at_max
]
```

**Targeting + firing intent — priority 2.** Slice-batched. Higher
than regen because a delay here means a unit doesn't fire when it
could have, which is visible. Each task slice computes firing
intents into per-task scratch; merge step at end of tick spawns
projectile tasks (which then run at priority 1, see issue 112).

```
targeting_slice_task_actions = [
    [0] iterate_units_in_slice
    [1] for_each_find_nearest_enemy_with_los      // reuses 111's LoS
    [2] check_cooldown_decrement
    [3] append_firing_intent_to_scratch_if_ready
    [4] update_last_target_id_for_miss_memory
]
```

**Damage application merge — priority 1.** Single-threaded merge
step at end of tick. Runs at priority 1 because it MUST happen
this tick or the firing/projectile work this tick is stale. One
task, no slicing — by design it serializes the cross-unit writes.

```
damage_merge_task_actions = [
    [0] sort_intents_deterministically
    [1] subtract_hp_per_intent
    [2] mark_units_dead_if_hp_zero
    [3] flush_firing_intents_into_projectile_spawns  // each spawns a priority-1 projectile task per issue 112
]
```

The orchestration order each tick is: regen (priority 4) →
targeting+firing (priority 2) → projectile updates (priority 1,
self-rescheduling chains from prior ticks) → damage merge
(priority 1). The cycler's preference for low-priority-numbers
naturally serves this ordering: a freshly-spawned damage-merge task
beats a freshly-spawned regen task off the queue.

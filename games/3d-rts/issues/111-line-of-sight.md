# 111 — Line of Sight

## Status

TODO

## Current behavior

`terrain_segment_blocked` exists from issue 104 but is unused.

## Intended behavior

A function `los_can_see(shooter_unit_id, target_unit_id)` returns true
iff the segment from the shooter's "head" position to the target's
center does not dip below the heightmap at any sampled point. Both
positions are derived from each unit's current position plus a small
vertical offset (`UNIT_EYE_HEIGHT_WORLD` from config) so the line is
checked from "eye to body," not from the ground.

A debug overlay (gated by a config flag) draws a faint line between
each unit and its nearest enemy, colored green if visible and red if
blocked, so the LoS rule is visible during testing.

## Suggested implementation steps

1. Add `los_can_see` in `src/020-terrain.c` (LoS is a heightmap query)
   or in a new `src/025-los.c` if it gets large.
2. Implement it as a thin wrapper over `terrain_segment_blocked` with
   the eye-height offset baked in.
3. Add a debug-only render pass that draws the LoS lines for each
   alive unit to its nearest enemy unit.
4. Confirm visually that hills break LoS as expected.

## Related documents

- `docs/002-mechanics.md` — LoS rules.

## Notes

Sampling step matters. Too coarse and small ridges are missed; too fine
and the cost spikes for large unit counts. Start with
`step = TILE_SIZE_WORLD * 0.5` and expose it as a config constant so
later phases can tune it without rummaging through code.

## Task pool integration

**Recommended priority: 2** — per-tick parallel-for over the unit
slices, runs once per simulation tick. Same priority class as
movement (issue 107) and combat (issue 113); none of these is more
urgent than another, but all are more urgent than UI / display
updates.

LoS is the canonical example of slice-batched parallel-for in this
project. The terrain heightmap is read-only after init (issue 104
established this), so any number of LoS queries can run concurrently
across worker threads with zero locking. Each slice task:

```
los_slice_task_actions = [
    [0] iterate_units_in_slice
    [1] for_each_find_nearest_enemy_with_los
    [2] write_target_id_to_per_task_scratch
]
```

The merge step (single-threaded, runs at end of tick) reads each
task's scratch and applies the chosen target ids to unit state.
This pattern is exactly the architecture doc's "split-by-tenths"
shape.

Until the pool is adopted, the same code runs serially as a single
loop. The cost of moving to parallel later is replacing the loop
with `for (slice) pool_spawn(...) ; wait_all`.

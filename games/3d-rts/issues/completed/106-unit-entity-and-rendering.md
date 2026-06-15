# 106 — Unit Entity & Box Rendering

## Status

DONE — completed 2026-04-27.

## Current behavior

There are no units. The simulation publishes a placeholder marker only.

## Intended behavior

A unit data structure exists in `src/050-units.c` / `.h`. A small
fixed pool (`UNITS_MAX`) is allocated up front. A handful of units
are spawned at startup at varied X/Y positions on the terrain, and
they render as colored boxes (raylib `DrawCubeV` / `DrawCubeWiresV`)
sitting flat on the terrain at their X/Y.

The render loop reads unit positions from the snapshot, never from
the unit array directly. (Issue 102 lands the snapshot; until then,
the renderer reads the pool directly. Swapping is a one-line change
at the call site, not a redesign of this module.)

## Suggested implementation steps

1. Define `Unit` in `src/050-units.h` with: id, alive bool, team id
   (Phase 1 uses two teams as combat-testing scaffolding), position
   (Vector3 — Z kept synced to terrain at the unit's X/Y), and yaw.
2. Allocate the pool in `units_init()`. No dynamic allocation per
   unit.
3. Add `units_spawn(team, x, y, yaw)` returning the new unit's id
   or -1 on full pool. Spawn snaps Z to `terrain_height_at`.
4. Render each alive unit as a colored box plus a black wireframe
   outline so silhouettes read against the terrain. The cube's
   base sits flush on the surface (center.z = surface + half
   height).
5. Spawn ~6 units of two teams at startup so combat issues have
   something to operate on.
6. Provide read-only accessors (`units_get`, `units_pool`,
   `units_count`) for selection / LoS / combat to consume.

## Related documents

- `docs/002-mechanics.md` — unit rules.

## Notes

Two teams in Phase 1 is testing scaffolding, not a feature: the
vision does not include opposing players, but combat needs targets.
The team palette in `050-units.c` is a const table so future code
can extend it without churning callers.

## Completion log

### What was implemented

- `src/050-units.{h,c}` — fixed pool of `UNITS_MAX = 256` units,
  sparse (count is highest-occupied + 1, iterators skip dead).
- `Unit` struct with id / alive / team / position / yaw. `id` is
  the pool index for stability across the unit's lifetime.
- `units_spawn` allocates the first dead slot, snaps Z from
  `terrain_height_at`. Linear scan is fine at 256.
- Six initial spawns: three blue (team 0) clustered near
  `(-10, -10)` and three red (team 1) near `(+10, +10)`. Hand-
  picked rather than randomized so the world is reproducible.
- `units_render` walks the pool, skipping dead, drawing each as a
  0.8 × 0.8 × 1.5 cube colored by team with a black wire outline.
- Read-only accessors (`units_get` / `units_pool` / `units_count`)
  exposed for the issues that follow.

### What was tested

- Visual: user confirmed six units render correctly on the
  terrain, base flush against the surface, blue and red clearly
  distinguishable on green/tan ground.
- Build: clean compile under `-Wall -Wextra -Wpedantic` after
  adding `<stddef.h>` for `NULL`.

### What was not tested

- Pool exhaustion: the -1 return from `units_spawn` on a full pool
  was not exercised (would need ~250 spawns; relevant when factory
  production lands in issue 116).
- Re-spawn into a dead slot: depends on units actually dying,
  which arrives in issue 113. The slot reuse path is straight-
  forward (`alloc_slot` finds dead slots first) but unproven.
- Cross-thread reads of the pool: irrelevant until issue 102 lands
  the snapshot path.

### Lessons & caveats for later issues

- The pool is **sparse**, not compact. Iterating must skip
  `!alive` entries. Compaction was considered and rejected because
  ids would need to be remapped — the cost falls on the issues
  that hold ids across frames (orders, projectiles, miss-memory)
  and is not worth saving the iteration cost.
- Z is stored in the unit (not derived at render time). Issue 107
  movement must keep this in sync when X/Y changes; a unit whose
  Z lags behind its X/Y will render half-buried in a hill.
- The cube outline is a presentation detail, not a selection cue.
  Issue 108 (selection) will need a *different* visual to mark
  selected units — pick something that stands out from the
  always-present black outline (e.g. yellow wires, a ring on the
  ground, an oversized outline).

## Task pool integration (added retroactively)

This issue establishes the data structure that almost every later
task pool task iterates over. The unit pool itself doesn't run on
the pool — it's just storage — but its design choices shape how
later tasks slice it:

- **Pool is sparse, not compact.** Slice tasks must skip dead
  entries during iteration. Easy: `for (id = lo; id < hi; id++)
  if (units[id].alive) { ... }`.
- **Pool size is fixed at 256.** A 10-task slice-batched pass over
  the pool gives slices of ~25 entries each. Cheap; the per-task
  overhead probably exceeds the per-unit work for that slice
  count. Realistic pool adoption probably uses 4 slices, not 10.
- **`id` is the slot index and stable for the unit's lifetime.**
  Tasks that hold ids across ticks (movement state, miss-memory)
  rely on this. The task pool's GUID is unrelated to unit id;
  don't conflate them.

No task type lives in this issue itself. The issues that do
operate per-unit (107, 108, 111, 113, 115) each declare their own
priority and slice/self-reschedule shape.

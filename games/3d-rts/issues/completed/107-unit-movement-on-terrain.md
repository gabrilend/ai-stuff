# 107 — Unit Movement on Terrain Surface

## Status

DONE — completed 2026-04-27.

## Current behavior

Units are stationary. They have no concept of a target position.

## Intended behavior

Each unit has an optional `target_xy` (Vector2). When set, the unit
walks toward it with **turn-before-walk** behavior: yaw rotates
toward the target heading at a bounded rate, and forward speed
scales with how aligned the unit is. Z is always
`terrain_height_at(x, y)` so the unit stays on the surface. When
the unit reaches the target (within a small radius), `target_xy` is
cleared.

`units_tick(dt)` advances every alive unit with a target. There is
no obstacle avoidance or pathfinding — units curve toward their
destination based on their current heading.

For testing, a temporary `T` key sets every alive unit's target to
a random terrain point so the movement system can be observed
without selection or right-click yet.

## Suggested implementation steps

1. Add `target_xy` and `has_target` to `Unit`.
2. In `units_tick(dt)`, for each unit with `has_target`:
   - Compute 2D delta to target.
   - Compute desired yaw from `atan2(dy, dx)`.
   - Slew yaw toward desired yaw at `UNIT_TURN_RATE`.
   - Compute alignment factor from `cos(angular_error)`, squared
     for a sharper falloff.
   - Step forward along the *current heading* by
     `UNIT_SPEED * dt * alignment_factor` (capped at remaining
     distance).
   - Update Z from `terrain_height_at`.
   - Clear the target when within `UNIT_REACH_RADIUS`.
3. Render: wrap each unit's cubes in `rlPushMatrix` +
   `rlTranslatef` + `rlRotatef` around Z so the body rotates with
   yaw; add a small "nose" cube on the +X face so rotation is
   visible (a square cube is rotation-symmetric in silhouette).
4. Add a temporary debug input for "scatter" that sets random
   targets, hooked to `T`. Throwaway scaffolding — flag it with a
   `// TODO(issue-109): remove once orders work` comment.
5. Confirm visually that units glide over hills smoothly and that
   turning is visibly sequenced before walking.

## Related documents

- `docs/002-mechanics.md` — movement rules.
- `docs/balance-updates.md` — feel-tuning history of
  `UNIT_TURN_RATE` and the alignment falloff.

## Notes

The scatter key is the kind of temporary scaffolding the user's
guidelines warn about: write it, keep it through one commit, then
delete it after issue 109 supplies the real input. Track its
expected removal in this issue so it is not forgotten.

## Completion log

### What was implemented

- `units_tick(float dt)` in `src/050-units.c`. Per-unit:
  desired-yaw computation, capped yaw slew, `cos²(angular_error)`
  speed scaling, forward move along current heading, Z resnap to
  surface, reach-radius arrival check.
- `units_set_target(int id, Vector2 target)` in
  `src/050-units.{h,c}`.
- `Unit` struct gained `has_target` (bool) and `target_xy`
  (Vector2). `yaw` is now mutated each tick when moving.
- Renderer in `draw_unit` rewritten: `rlPushMatrix` /
  `rlTranslatef(unit center)` / `rlRotatef(yaw_deg, 0, 0, 1)` /
  body cube + black wires + dark "nose" cube on +X face / pop.
- `001-main.c`: temporary `T` scatter key — picks random
  X/Y in [-30, 30] for every alive unit. Flagged
  `// TODO(issue-109): remove once orders work`.
- HUD updated to mention the `T` test key.

### What was tested

- Visual: user confirmed units glide smoothly over hills, rotate
  visibly before walking, and "feel like tanks" with the
  squared-cosine alignment falloff.
- Build: clean compile against vendored raylib 6.0 under
  `-Wall -Wextra -Wpedantic`.

### What was not tested

- Mass scatter under load: only six units are spawned. Larger
  populations (which arrive with factory production in 116)
  would exercise the per-tick cost more fully.
- Pool exhaustion / dead-slot reuse: unaffected by this issue but
  still untested from 106.
- Snapshot indirection: still N/A until 102 lands. The render
  path reads the pool directly.

### Lessons & caveats for later issues

- **Movement direction is the unit's heading, not the target
  vector.** This is what gives the curving, tank-like motion.
  Issue 109 will need to remember this — when an order chain
  pops a waypoint, the unit doesn't teleport its heading; it
  just changes which target the heading is slewing toward.
- **The "nose" makes rotation legible.** Pure cube units would
  need either elongation or some other asymmetric feature.
  Future visual tweaks (selection rings, team flags) can stack
  inside the same `rlPushMatrix` block.
- **`cos²` was chosen over plain `cos` for sharper "can't move
  well sideways" feel.** Plain `cos` left units gliding noticeably
  during turning. Documented in `docs/balance-updates.md`.
- **`atan2(dy, dx)` returns `(-π, π]`.** Both desired and current
  yaw are kept in that range so the angular-error fold is a
  single conditional, not a loop.

## Task pool integration

**Recommended priority: 2** — per-tick gameplay state, must update
every tick or units visibly stutter, but not as time-critical as
projectiles in flight (priority 1).

Two valid shapes; pick one when adoption time comes:

**Shape A — slice-batched parallel-for** (matches the "Parallel
batching pattern" already documented in `docs/004-architecture.md`).
The sim thread spawns 10 tasks per tick, each operating on a
contiguous slice of the unit array, all at priority 2. Each task's
single action body iterates its slice and advances each unit's
position. Slice-disjoint writes mean no locks needed.

**Shape B — per-unit self-rescheduling task** (matches the
projectile-arc pattern from issue 112). Each unit with an active
order chain owns a movement task that re-enqueues itself each tick:

```
movement_task_actions = [
    [0] read_target_from_chain_head     // ACT_DONE if chain empty
    [1] step_toward_target_by_dt
    [2] update_z_from_terrain
    [3] check_arrival_pop_chain_if_within_radius
    [4] spawn_next_tick_task_if_still_moving  // priority 2
]
```

Shape B is more honest to the user's "self-rescheduling for things
like walking toward a location" framing, and removes movement from
the sim's per-tick pass entirely — moving units update themselves;
stationary units consume zero scheduler time. The cost is one task
struct per moving unit per tick, which at hundreds of units is
manageable but not free.

Shape A is what the architecture doc already plans for. Shape B is
a more aggressive use of the pool. Decision deferred to whichever
issue actually adopts the pool for movement.

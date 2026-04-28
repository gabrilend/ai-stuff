# 107 — Unit Movement on Terrain Surface

## Status

TODO — re-opened 2026-04-27 to transition the serial implementation
to the task pool (`libs/900-task-pool`). Original serial version
shipped earlier the same day; see "Completion log" below for the
as-shipped reference, and "Re-opened: transition to task pool" at
the bottom for what changes.

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

## Re-opened: transition to task pool

This issue was completed in its serial form (see "Completion log"
above) and re-opened the same day to transition the implementation
to `libs/900-task-pool`. The serial version is the reference
starting point; the work below describes what changes.

### Decision: Shape B (per-unit self-rescheduling)

Of the two shapes documented in "Task pool integration" above, this
transition commits to **Shape B** — per-unit self-rescheduling
tasks matching the projectile-arc pattern. Rationale:

- The user's stated preference for "self-rescheduling for things
  like walking toward a location" is direct guidance for movement
  specifically.
- Removing stationary units from the per-tick pass entirely is a
  meaningful win when only a fraction of units are moving in any
  given tick — and at Phase 1's expected unit counts (six initially,
  hundreds after factory production lands) that fraction is usually
  small.
- The per-tick task overhead (one task struct per moving unit per
  tick) is bounded and acceptable. If profiling later shows it
  dominating, switching to Shape A is mechanical (replace the
  reschedule action with a single per-tick spawn from the sim
  thread).

### What changes vs the as-shipped serial version

- `units_tick(dt)` is removed from the sim thread's per-tick loop
  (the function itself can stay as a deprecated helper for one
  commit per the mono-repo convention, then be removed).
- Each unit gains an associated `task_id_t movement_task_id` field
  (`TASK_ID_NONE` when not moving) so duplicate task spawns are
  prevented.
- When a unit gains a target (today: via the temporary `T` scatter
  key; soon: via issue 109's right-click order), code spawns a
  movement task at priority 2 with the unit's id passed in args.
  The spawn is guarded by `movement_task_id == TASK_ID_NONE`.
- The movement task's actions correspond to the existing per-unit
  body of `units_tick`, broken into a sequence:
  - `read_target` — read the unit's current `target_xy` from
    state. ACT_DONE if `has_target` is now false (target was
    cleared since the task last ran).
  - `rotate_yaw` — slew yaw at `UNIT_TURN_RATE * dt`.
  - `step_forward` — advance position with the
    `cos²(angular_error)` factor.
  - `resnap_z` — pull Z from `terrain_height_at`.
  - `check_arrival` — clear `has_target` if within
    `UNIT_REACH_RADIUS`.
  - `reschedule` — if `has_target` is still true, spawn the next
    tick's task at priority 2 and ACT_DONE; if cleared, set
    `movement_task_id = TASK_ID_NONE` and ACT_DONE.

### What does NOT change

- The `Unit` struct's existing fields (`target_xy`, `has_target`,
  `yaw`, `position`, etc.) all stay. New field is additive.
- The renderer's `rlPushMatrix` / yaw rotation / "nose" cube logic
  is unchanged — render reads unit state, doesn't care how that
  state is updated.
- The temporary `T` scatter key still works; it just calls a
  small wrapper that sets the target AND spawns the task in one
  step (or, equivalently, `units_set_target` is updated to spawn
  internally if no task is running).
- The balance tunables (`UNIT_TURN_RATE`, `cos²` falloff,
  `UNIT_SPEED`, `UNIT_REACH_RADIUS`) all stay.
- Observable behavior: identical. Units glide / rotate / arrive
  the same as before. The only external difference is that the
  sim thread no longer iterates the unit pool for movement.

### Suggested implementation steps

1. Add `task_id_t movement_task_id` to the `Unit` struct,
   initialized to `TASK_ID_NONE` for all spawned units.
2. Pull the per-unit body of `units_tick` apart into the six
   action functions listed above. Each action operates on the
   unit identified by its action args (unit id), reads/writes
   the unit's fields directly, and returns the appropriate
   `action_result_t`.
3. Implement `units_start_movement_task(int unit_id, task_pool_t
   *pool)`: composes the actions / args arrays and calls
   `pool_spawn` at priority 2. Sets `movement_task_id` on the
   unit.
4. Update `units_set_target` to call
   `units_start_movement_task` after setting the target, guarded
   by `movement_task_id == TASK_ID_NONE`.
5. Remove the `units_tick(dt)` call from main's per-frame loop
   (or wherever it's currently driven).
6. Add a new test: `tests/007-task-pool-movement.c` —
   spawn N units with N different random targets, run the pool
   for a short time, verify each unit's `has_target` is false
   (i.e. arrived) at the end. Per `tests/000-index.md`'s
   one-test-per-behavior convention.
7. Re-run the visual test from the original completion log:
   units glide, rotate visibly, and arrive smoothly. Behavior
   should be indistinguishable from the serial version.

### Open question for implementation time

Where does `g_pool` live? The task pool needs to be created
somewhere visible to both `units_set_target` (which spawns
movement tasks) and `001-main.c` (which creates / destroys the
pool at game lifecycle boundaries). Two reasonable options:

- A global `g_pool` in `001-main.c` exposed via `extern`.
- A pool pointer stored on a "game" / "world" struct that gets
  passed into modules that need it.

The first is simpler and matches the project's current style
(unit pool, terrain, camera are all module-global singletons).
The second is more disciplined but requires a wider refactor.
Lean toward the first for the transition; revisit if a second
pool ever appears.

### Caveats

- The pool must be created at game startup (before any unit can
  spawn a movement task) and destroyed at shutdown (after the
  last task has had a chance to terminate). If a unit has a live
  movement task at shutdown, `pool_destroy` leaks it per its
  documented behavior — acceptable at process exit.
- A unit whose target is cleared by external code (e.g. a damage
  event killing it, or issue 109's order replacement clearing
  the chain): the next time the movement task runs, `read_target`
  sees `has_target == false` and returns ACT_DONE without
  rescheduling. The `movement_task_id` field gets set back to
  `TASK_ID_NONE` by the reschedule action's "else" branch.
- Units that change target while a task is mid-flight: the
  `read_target` action reads `target_xy` fresh each tick, so a
  target change just redirects the unit smoothly. No special
  handling needed.

## Addendum (2026-04-28): land with timestamp-based motion + priority-demotion baked in

Two design decisions from a 2026-04-28 conversation that should
ship as part of the Shape B transition rather than be retrofitted
later:

1. **Timestamp-based motion.** Add `last_update_t` (double, seconds)
   to `Unit`. The movement task's first action reads `now`, computes
   `elapsed = now - u->last_update_t`, advances by
   `speed * elapsed * cos²(err)`, writes `now` back to
   `last_update_t`. The task is then free to run at any cadence —
   priority 1 every tick, priority 10 every fifth tick — and the
   unit walks the same total distance, just in different-sized
   steps. Reset `last_update_t` to `now` whenever a new target
   arrives so the first step under a new heading isn't "all the
   time since the last walk."

2. **Priority demotion on block.** Captured in 114's "Addendum
   2026-04-28: priority demotion on block." The library change
   should go in **before** 107 re-opens, so the movement task
   inherits the new behavior from day one. Movement currently
   doesn't block on anything, but combat and projectiles will, and
   we don't want to retrofit demotion semantics into a system
   already adopted at the old shape.

### Render-side consequence

`units_render` should consider extrapolating between task updates
for visual smoothness:

```c
float dt_render = render_now - u->last_update_t;
Vector2 heading = { cosf(u->yaw), sinf(u->yaw) };
float align = cosf(angular_error_to_target);  // or cache it on the unit
align = fmaxf(0.0f, align); align *= align;
float render_x = u->position.x + heading.x * UNIT_SPEED * align * dt_render;
float render_y = u->position.y + heading.y * UNIT_SPEED * align * dt_render;
float render_z = terrain_height_at(render_x, render_y);
```

This is one of the things "the snapshot" in the architecture doc
is supposed to abstract; until 102's snapshot lands, the render
thread reads the unit pool directly with this extrapolation
inline.

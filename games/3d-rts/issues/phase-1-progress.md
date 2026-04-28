# Phase 1 Progress — Basic Movement Options

This file tracks progress through Phase 1. Update it whenever an issue is
completed and moved to `issues/completed/`.

## Goal of Phase 1

Deliver a runnable 3D RTS slice with: heightmap terrain, rectangular box
units with HP/damage/regen, cylinder javelins thrown only along line of
sight, miss-variance memory, a placeable factory, single and shift-chained
orders for both units and factory rally points, and a phase demo that
exercises all of it.

## Issues

| Status | ID  | Title                                |
| ------ | --- | ------------------------------------ |
| DONE   | 101 | Build system & raylib bootstrap      |
| TODO   | 102 | Threading model (pthreads)           |
| DONE   | 103 | Window & 3D camera                   |
| DONE   | 104 | Heightmap terrain                    |
| DONE   | 105 | Terrain ray-pick                     |
| DONE   | 106 | Unit entity & box rendering          |
| TODO   | 107 | Unit movement on terrain surface (re-opened to transition to task pool) |
| TODO   | 108 | Box selection                        |
| TODO   | 109 | Right-click single move order        |
| TODO   | 110 | Shift-chained waypoint orders        |
| TODO   | 111 | Line of sight                        |
| TODO   | 112 | Javelin projectile                   |
| TODO   | 113 | Combat targeting, firing, HP & regen |
| TODO   | 114 | Coroutine pool library (M:N)         |
| TODO   | 115 | Aiming variance per (shooter,target) |
| TODO   | 116 | Factory placement & production       |
| TODO   | 117 | Single rally point with X/Y drag     |
| TODO   | 118 | Shift-chained rally points           |
| TODO   | 119 | Selected-unit chain splitting        |
| TODO   | 120 | Phase 1 demo capstone                |
| TODO   | 121 | raylib build flag manifest           |
| TODO   | 122 | Task pool: game build integration    |

Counts and percentages should be derived by reading this table — not
hard-coded into other documents.

## Notes

The issue ordering is by foundational dependency, not by chronology. A
later-numbered issue can be in progress before an earlier one is fully
done if the dependency is not yet load-bearing — but completion order
should generally follow the table.

Issue 114 (coroutine pool) is **available infrastructure**; the game
systems in 102 and onward run pool-friendly (slice-batched, intent-based
cross-unit effects) so the pool can be adopted later without redesign.
The architectural pattern is in `docs/004-architecture.md` under
"Parallel batching pattern."

Each issue's "Task pool integration" section names the priority its
work would run at if the pool is adopted. Quick reference:

| Priority | Class                          | Issues using it                      |
| -------- | ------------------------------ | ------------------------------------ |
| 1        | Most time-critical per-tick    | 112 projectile-arc, 113 damage merge |
| 2        | Per-tick gameplay              | 107 movement, 111 LoS, 113 firing, 115 variance read |
| 3        | Input handlers (one-shot)      | 108, 109, 110, 117 commit, 118, 119  |
| 4        | Slow per-tick gameplay         | 113 HP regen                         |
| 5        | Production timers              | 116 factory production               |
| 6        | Live drag visual feedback      | 117/118/401 drag-move                |
| 8        | Demo / stats sampling          | 120 stats sampler                    |
| 9        | UI display refresh             | 116 production-percentage display    |

Lower priority numbers run more often per the cycler pattern
`1; 1,2; 1,2,3; ...; 1..10`. A priority-1 task gets scheduled
roughly 9× as often as a priority-10 task. A priority-9 UI refresh
will visibly happen, just not on every tick.

When an issue is completed, append a short retrospective entry below this
line so future readers can see the path the project took.

## Retrospective log

### 2026-04-28 — session-end note: iteration 4 of task pool pending

Conversation in flight on a fourth iteration of the task pool
design. Agreed scope:

- Remove waiting queue + scanner + scanner_running flag.
- ACT_BLOCK re-pushes at min(10, priority+1) on the ready queue.
- pool_spawn_after kept; reimplemented by injecting a synthetic
  check-deps-or-BLOCK first action.
- New optional `promote_if_late` flag for self-rescheduling
  periodics — auto-promote one priority level when wall-time
  gap exceeds the priority's expected gap.

Full design captured in 114's "Addendum 2026-04-28: priority
demotion on block (iteration 4 design pending)" section; that
section also lists the implementation steps. Issue 107's
"Addendum (2026-04-28)" already gates its Shape B transition on
this iteration landing first, so the work order is:
**iteration 4 → 107's transition → 122 adoption.**

Resume next session by promoting 114's pending section into a
proper "Iteration 4" subsection under "Design evolution" and
then doing the code change.

### 2026-04-27 — 107 re-opened: transition to task pool

107 shipped the same day as a serial implementation (entry below)
and was re-opened immediately to transition to
`libs/900-task-pool` per the user's "self-rescheduling for things
like walking toward a location" framing. The serial implementation
remains in 107's "Completion log" as the reference; the new
"Re-opened: transition to task pool" section in 107 describes the
Shape B (per-unit self-rescheduling) plan. Observable behavior is
intended to be identical — the difference is structural (the sim
thread no longer iterates the unit pool for movement; moving units
own their own per-tick task chain).

### 2026-04-27 — 107 Unit movement on terrain

`units_tick(dt)` in `src/050-units.c`: per-unit walk toward
optional `target_xy` with **turn-before-walk** behavior. Unit yaw
slews toward `atan2(dy, dx)` at `UNIT_TURN_RATE = 1.5 rad/s`, and
forward speed scales by `cos²(angular_error)` so units can't
glide sideways — they pivot in place when sharply off-axis and
arc into their target on small course corrections. Z resnaps to
the surface every step so units hug hills.

Renderer wraps each cube in `rlPushMatrix` + `rlTranslatef` +
`rlRotatef` around Z so the body actually rotates with yaw, plus
a small dark "nose" cube on the +X face so rotation is visible
even from above (a square is rotation-symmetric in silhouette).

Temporary `T` key in `001-main.c` scatters all units to random
points; flagged `// TODO(issue-109)` for removal when right-click
orders land.

Tunables landed via two rounds of feel testing — full log in
`docs/balance-updates.md` (`UNIT_TURN_RATE`, `cos²` falloff).

### 2026-04-27 — 106 Unit entity & box rendering

`src/050-units.{h,c}` — fixed pool of 256 units, sparse, indexed-
as-id. Six initial spawns (3 blue + 3 red) at fixed positions for
reproducibility. Render is per-cube + black wireframe outline,
base flush on terrain. Pool reads go directly through accessor
functions today; 102's snapshot will sit in front of them later
without changing the read sites. Iterators **must skip dead**
entries — pool is sparse on purpose so ids stay stable across
issues that hold them (orders, projectiles, miss-memory).

### 2026-04-27 — 105 Terrain ray-pick

`terrain_pick(camera, mouse, out)` in `src/020-terrain.{h,c}`:
ray-march the cursor ray at 0.5-unit steps, binary-search the
above→below crossing, snap final Z to `terrain_height_at`. Miss is
the bool return value, not a sentinel in `*out`. Debug marker
(yellow circle + small sphere) wired into `001-main.c` and tracks
the cursor smoothly. Note for later: raylib's `DrawCircle3D` draws
in local X/Y, which is the ground in our Z-up world — no rotation
needed; rotating around X tips the circle onto its edge.

### 2026-04-27 — 104 Heightmap terrain

`src/020-terrain.{h,c}` — 64×64 tile heightmap, indexed mesh built
by hand (raylib's `GenMeshHeightmap` is Y-up). Procedural noise is
three sine octaves with phase offsets; per-vertex lighting against
a fixed sun direction baked into vertex colors at build time. The
result is readable shaded terrain even though raylib's default
shader is unlit. `terrain_height_at` (bilinear) and
`terrain_segment_blocked` (half-tile sampling) declared but not yet
exercised — 105 and 111 are the first callers. Caveat for future:
any *dynamic* lighting needs a custom shader; tracked as new issue
401 in a freshly-added Phase 4 (rendering polish).

### 2026-04-27 — 103 Window & 3D camera

Singleton camera at `src/030-camera.{h,c}`: target / yaw / pitch /
distance recomputed into a raylib `Camera3D` per frame. WASD +
middle-drag pan, Q / E yaw, scroll zoom, all scaled by current
distance for uniform feel. Established **Z-up** as the world
convention to match the vision text; raylib's heightmap helpers
assume Y-up so 104 will roll terrain mesh generation by hand.
Middle-drag input feel needed two rounds of sign tweaks; final
mapping is `apply_pan(d.y, -d.x)` — log in
`docs/balance-updates.md`. Placeholder grid + axis markers in
`001-main.c` are scaffolding, removed by 104 and 106.

### 2026-04-27 — 101 Build system & raylib bootstrap

Toolchain wired up: Makefile + `scripts/build.sh` + top-level `run`.
Compiles `src/*.c` into `tmp/3d-rts` (which is a symlink to
`/tmp/3d-rts/` on this machine — volatile scratch by design).
`GAME_DIR` baked in via `-D` so the binary resolves `input/`/`output/`
no matter where it is launched from. Mono-repo's input-read /
goodbye-write lifecycle is wired in at the bootstrap stage to spare
later phases a retrofit. raylib is statically linked on this machine
(`/usr/local/lib/libraylib.a`), which surprised nothing but is worth
remembering when reading `ldd` output later.

## Session resume — 2026-04-28

Pick up here, in this order:

1. **114** — implement priority-demotion-on-block per its
   2026-04-28 addendum. Add `tests/007-...`. Library-only.
2. **122** — close out (move to `completed/`, commit). Work is
   done; only paperwork is pending.
3. **107 (re-opened)** — Shape B transition with timestamp-based
   motion. See 107's 2026-04-28 addendum.

After 107 lands, the gameplay road resumes at **108 (box
selection)**.

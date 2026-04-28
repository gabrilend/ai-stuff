# 004 — Architecture

This document describes how the program is organized: which modules exist,
what each owns, how they communicate, and how the threads divide work.

## Modules

Each module is a `.c` file paired with a `.h` file in `src/`. Filenames are
prefixed with an index so they read in narrative order (per mono-repo
convention).

- `001-main.c` — entry point. Initializes the window, spawns the
  simulation thread, runs the render/input loop, joins on exit.
- `010-config.h` — tunables: terrain size, unit count caps, projectile
  speed, fire cadence, variance growth. No magic numbers anywhere else.
- `020-terrain.c` — heightmap generation, mesh build, sampling utilities,
  ray/segment-vs-heightmap queries.
- `030-camera.c` — Camera3D state and update from input.
- `040-input.c` — translates raylib input each frame into a queue of
  semantic events (`SELECT_RECT`, `MOVE_ORDER`, `RALLY_POINT_DRAG`, ...).
- `050-units.c` — unit state, movement, aim, fire, miss-memory.
- `060-projectiles.c` — javelin lifecycle, integration, hit checks.
- `070-orders.c` — order chains for units and rally chains for factories.
  Owns the chain split-and-distribute logic.
- `080-factory.c` — factory placement, production timer, output rotation
  through rally chains.
- `090-selection.c` — current selection, screen-rect picking.
- `100-render.c` — draws the snapshot. No game logic ever here.
- `110-snapshot.c` — the simulation→render handoff: a struct of
  positions/orientations/health/projectiles/orders, double-buffered
  with a tiny mutex-protected swap.
- `120-sim.c` — the simulation thread main: tick loop, fixed timestep,
  drains input queue, runs systems, publishes snapshot.

These indexes are guidance; the issue files in Phase 1 dictate which file
appears when. The number prefix can shift as the picture firms up — the
mono-repo's auto-linter is the right tool for renames.

## Threading model

Three threads of attention, two real OS threads.

```
                 ┌────────────────────────────┐
                 │       main thread          │
                 │  (render + raylib input)   │
                 └─────┬──────────────────┬───┘
       publishes input │                  │ reads snapshot
                       ▼                  │
                ┌──────────────┐          │
                │ input queue  │          │
                └──────┬───────┘          │
       drains          │                  │
       ┌───────────────▼──────────────────┴───┐
       │           simulation thread          │
       │  (tick → systems → publish snapshot) │
       └──────────────────────────────────────┘
```

- **Main thread:** owns the window, polls raylib input, pushes input
  events onto the queue, reads the latest snapshot, and renders. Never
  touches simulation state directly.
- **Simulation thread:** owns all game state. Runs at a fixed tick rate
  (e.g. 60 Hz, configurable in `010-config.h`). Each tick: drain input
  queue, advance orders, update units, integrate projectiles, run
  combat, publish a fresh snapshot.

The boundary is two locks: one mutex for the input queue, one for the
snapshot pointer swap. Everything else is unshared.

## Snapshot

A snapshot is a flat, copyable struct: arrays of positions, orientations,
unit identifiers, projectile states, current orders, current selection,
and any factories. It is sized for the maximum unit count (a config
constant). The simulation builds a fresh snapshot each tick into a back
buffer; on publish, it swaps front/back under a lock that the render
thread also takes briefly to grab the front pointer.

This is the only mechanism by which game state crosses the thread
boundary.

## Input events

The input queue carries small, semantic events:

- `SELECT_RECT(x0,y0,x1,y1)` — screen-space drag rectangle on release.
- `SELECT_CLICK(x,y)` — single-point select on click without drag.
- `MOVE_ORDER(world_x, world_y, shift_chain_id)` — right-click commit.
- `FACTORY_PLACE(world_x, world_y)` — placement mode confirmation.
- `RALLY_DRAG_START(factory_id)` / `RALLY_DRAG_MOVE(x,y)` /
  `RALLY_DRAG_COMMIT(shift_chain_id)`.

`shift_chain_id` is generated on the main thread: each shift-key press-then-
hold opens a fresh ID; releases close it. The simulation thread interprets
these IDs to decide whether a new chain starts or an existing one continues.

This keeps the main thread *stateless about the game* — it only knows about
windowing, input mapping, and chain-id bookkeeping.

## Parallel batching pattern (thread-pool-friendly design)

The simulation thread is the *orchestrator* of a tick, not necessarily the
sole executor of one. The project ships with an M:N coroutine pool in
`libs/900-coroutine-pool.{c,h}` (see `issues/114-coroutine-pool-library.md`
for rationale). It is **not yet adopted** by the game systems, but every
per-unit subsystem in Phase 1 must be designed so adopting it later is a
small, mechanical change rather than a redesign.

The shape to aim for is **split-by-tenths**: when the sim thread runs a
per-unit pass over `N` units, the pass is structured as 10 (or some other
small number) independent task closures, each operating on a contiguous
slice of the unit array — `[0, N/10)`, `[N/10, 2N/10)`, …. Each task
only reads/writes within its slice or to per-task scratch buffers.

For this to be safe with zero locks, each per-unit subsystem must obey two
rules:

1. **Slice-disjoint writes.** A task may only mutate the unit whose slot
   it is processing (and per-task scratch). Cross-unit writes — for
   example, "shooter A causes target B to take damage" — produce
   *intent records* into the task's local scratch buffer, *not* direct
   writes to B. After all tasks finish, a single-threaded merge step
   applies the intents in deterministic order.
2. **Read-only shared input.** The terrain heightmap, the camera state
   (passed in via input events as discussed below), and the previous
   tick's snapshot are all read-only during the parallel pass.

Concrete subsystems and their batching shape:

| Subsystem            | Per-tick work                          | Cross-unit effect           |
| -------------------- | -------------------------------------- | --------------------------- |
| Movement             | Advance position toward chain head     | None — slice-disjoint      |
| HP regeneration      | Add 0.02 HP per regen tick boundary    | None — slice-disjoint      |
| LoS query / target acq | For each unit, find nearest visible enemy | Reads only — slice-disjoint |
| Firing               | Decide whether to spawn projectile     | Adds to a per-task projectile-spawn list |
| Projectile integration | Advance projectile, hit-check        | Adds to a per-task damage-intent list   |
| Apply damage         | Single-threaded merge of damage intents | Mutates target HP, may kill |

The **single-threaded merge step** at the end of each tick is the place
where cross-unit effects are committed: damage intents subtract HP, kill
flags are set, projectile spawn lists are flushed into the projectile pool.
Because intents are sorted deterministically (e.g. by `(shooter_id,
target_id, projectile_id)`) before application, the result is independent
of task scheduling order — the simulation is reproducible regardless of
how the pool happens to dispatch the slices.

In Phase 1, all of this can run on the sim thread *without* the pool —
the slice-iteration code path is identical, just executed serially.
Adopting the pool later means swapping a `for (slice)` loop for `for
(slice) { cpool_spawn(...) } co_join_all(...)`. That is the win this
design is buying.

## Data flow for one tick

1. Main thread polls input → produces events → enqueues them.
2. Sim thread tick begins → drains the queue → applies events to state.
3. Sim thread runs movement, combat, projectile integration, factory
   production.
4. Sim thread builds a snapshot in the back buffer.
5. Sim thread swaps front/back snapshots under lock.
6. Main thread pulls the latest front snapshot and renders.

Steps 1 and 6 happen continuously on the main thread; steps 2–5 happen
once per simulation tick. The main thread never blocks on the simulation
because it always has a snapshot to render — possibly one tick old, which
is fine.

## What this architecture protects against

- Render frame rate decoupled from sim rate: zoom and pan stay smooth
  even if the sim is busy.
- No dropped inputs: the queue absorbs bursts.
- No torn reads: snapshot swap is atomic at the pointer level.
- Every game decision is reproducible from `(prior state, drained input)`,
  which makes future replay or test harnesses possible without redesign.

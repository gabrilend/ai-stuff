# 122 — Task Pool: Game Build Integration

## Status

DONE — 2026-04-28. Pool wired into game build; `game_pool_init` /
`game_pool_shutdown` bracket the raylib loop in `001-main.c`.
First adopter is 107 (re-opened) — Shape B per-unit movement.

## Current behavior

The task pool library at `libs/900-task-pool.{h,c}` is complete and
tested (`tests/000-index.md` lists 9 passing test programs covering
sequential actions, cross-task result-slot waits, mid-task park /
wake, self-rescheduling, priority cycling, result slots, parking
promote semantics, slot-status disambiguation, and many-waiter
bursts). But the library is **not** part of the game build. Game
source files cannot `#include "900-task-pool.h"`, no pool is
created at startup, and in-game code cannot spawn tasks.

## Intended behavior

The task pool source is compiled into the game binary. A thin wrapper
module `040-game-pool` exposes a process-wide pool:

- `game_pool_init(N)` is called once at startup after the world
  modules are ready.
- `game_pool()` returns the singleton handle (`NULL` if not yet
  initialized).
- `game_pool_shutdown()` destroys it before the window closes.

This issue does **not** migrate any existing system to use the pool.
Adoption is per-system: issue **107 (re-opened)** is the first
(movement → Shape B per-unit self-rescheduling tasks). Subsequent
adoptions land with the issues that introduce the systems they
parallelize (113 combat / HP regen, 112 projectile arc, 116 factory
production, …). Each migration carries its own paper trail.

## Suggested implementation steps

1. Update `Makefile`:
   - Add `$(DIR)/libs/900-task-pool.c` to `SRCS` so the library
     compiles into the game binary alongside `src/*.c`.
   - Add `-I$(DIR)/libs` to `CFLAGS` so headers are found by name.
   - Add `-D_XOPEN_SOURCE=600` to `CFLAGS` to match the feature-
     test macro the task-pool test runner uses (the library leans
     on POSIX 2001 thread primitives).
2. Create `src/040-game-pool.{h,c}` exposing the three functions
   above. File-static singleton; `game_pool_init` is idempotent.
3. Update `src/001-main.c` to call `game_pool_init(4)` after
   `units_init`, and `game_pool_shutdown()` before
   `terrain_shutdown` / `CloseWindow`.
4. Verify the project builds clean under `-Wall -Wextra
   -Wpedantic -std=c11` and the game still runs unchanged (movement
   remains serial — the pool is created but no in-game code spawns
   tasks yet).

## Related documents

- `libs/900-task-pool.info.md` — external API summary.
- `issues/114-coroutine-pool-library.md` — full design rationale
  (kept under its original coroutine-pool name per append-only
  convention).
- `docs/004-architecture.md` — slice-batched parallel-for pattern.

## Notes

The 4-worker default is a deliberate guess: typical desktop CPUs are
4–16 cores. If profiling later shows over- or under-subscription,
the number is one constant in `001-main.c`. A
`sysconf(_SC_NPROCESSORS_ONLN)` lookup is a future option but adds a
syscall to startup for marginal benefit at this scale.

There is a deliberate gap between "pool exists" and "pool is used."
That gap is what lets this issue ship without blocking on each
per-system migration. The first migration (107 re-open) follows
immediately; the rest land with their own issues.

## Task pool integration

This issue is the integration scaffolding itself. It does not run
any tasks of its own.

## Session resume — 2026-04-28

**Done:** Pool wired into game build. `Makefile` SRCS now includes
`libs/900-task-pool.c` with `-I.../libs` and `-D_XOPEN_SOURCE=600`.
`src/040-game-pool.{h,c}` exposes `game_pool_init` /
`game_pool_shutdown` / `game_pool()`. `main.c` calls
`game_pool_init(4)` after `units_init` and
`game_pool_shutdown()` before `terrain_shutdown`. Verified: build
clean, binary launches, raylib reports 6.0, no crash on shutdown.

**Status:** 122 awaiting user consent to move to `completed/`. The
work is done; only the close-out (move + retrospective + commit)
is pending.

**Next:** before 107 re-opens, land the **priority-demotion-on-
block** library change captured in 114's 2026-04-28 addendum.
After that, 107 transitions movement to Shape B with
**timestamp-based motion** baked in (107's 2026-04-28 addendum).
Order: 114 demotion change → close 122 → re-do 107.

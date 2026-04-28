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
| TODO   | 104 | Heightmap terrain                    |
| TODO   | 105 | Terrain ray-pick                     |
| TODO   | 106 | Unit entity & box rendering          |
| TODO   | 107 | Unit movement on terrain surface     |
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

When an issue is completed, append a short retrospective entry below this
line so future readers can see the path the project took.

## Retrospective log

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

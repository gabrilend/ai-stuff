# 109 — Soramech: the ceramic engine runs the world

**Phase:** 1 — The world beneath
**Blocked by:** 101

**Blocks**: 105, 106, 107, 110, 406
**Related documents:** docs/architecture.md (Implementation route: the
ceramic engine), libs/ceramic/README.md,
/home/ritz/programming/ai-playground/minimal-soramech/docs/ (001–008),
/mnt/mtwo/programming/ai-stuff/world-edit-to-execute/issues/515-render-graph-on-the-ceramic-engine.md,
/mnt/mtwo/games/azeroth-core/custom-client/issues/110-the-ceramic-shape.md
**Completed:** 2026-10-10

## Current Behavior

Built. The world runs on soramech's C engine — the ceramic engine — and the
program has the ceramic shape: LÖVE's main thread is the render thread only.

- `libs/ceramic/` carries the engine in world-edit-to-execute's improved
  copy (task queue without a lock, batched hand-in), with a README saying
  where it came from and when to replace it with soramech's own.
- `src/020-ceramic-boxes.c` holds two boxes, `unit_chunk` and
  `cuboid_chunk`, each working one chunk of records and writing only those.
- `src/021-ceramics.map` places them at two stations, each one of the
  program's doors (arguments 0 and 1, results 0 and 1).
- `src/022-the-ceramic-host.c` is the render thread's surface: start, point
  at the blocks, hand a stage in as one batch, count what has landed, stop.
- `scripts/build-ceramics` builds serac from minimal-soramech's sources,
  has it emit the construction code, puts the host in place of its main,
  and compiles a shared library into `tmp/tmp/ceramic/`; it rebuilds only
  when a source changed. The run script and the test script build first.
- `src/023-the-ceramic-host.lua` loads the library through LuaJIT's FFI and
  drives a step in two stages, never waiting: unit chunks, then — once all
  have landed — cuboid chunks, then the caller swaps the blocks.

Measured: 144 frames per second held with 192 units and 96 cuboids; a step
takes two frames (the second stage goes in on the next look). Tests: the C
motion matches the Lua reference (006) to float rounding; running every
stage's chunks in reverse gives a byte-identical world after 600 steps.

The Lua stand-in (stations on the main thread, LÖVE threads, one task per
unit per frame through channels; 37 frames per second at 3,000 units) is
retired: its files are kept one commit as `src/008-soramech-stations.lua-done`
and `src/009-soramech-worker.lua-done` (with their `.info.md-done`), then
removed — nothing is expected to use them again; the C boxes replace them
and 006 stays as the reference twin of the motion.

## Intended Behavior

- The world runs on the ceramic engine; LÖVE's main thread only renders,
  hands work in, and counts what has landed — it never waits.
- Boxes are C functions compiled with the map by serac, loaded through FFI.
- Work goes in by the batch, in chunks (32 records a task).
- Boxes write only their own records; the world travels by pointer.
- The Lua stand-in is retired; the Lua move box stays as the reference twin.

## Implementation Steps (as built)

See Current Behavior: libs/ceramic, src/020–023, scripts/build-ceramics,
src/016 (the game drives the host each frame), src/017 (the tests).

## Decisions

- The improved copy of the engine rather than minimal-soramech's own: the
  batched hand-in is what keeps per-frame work cheap, and soramech has not
  taken it in yet (libs/ceramic/README.md).
- The world by pointer rather than as values, as the crowd study did:
  thousands of records cannot travel as box arguments.
- Two stages per step rather than one: a cuboid's claim depends on every
  unit's new choice, so cuboids go in only after all units have landed.

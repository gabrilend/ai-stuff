<!-- written by Claude (Opus 5.5), 2026-10-10: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 016-the-game

The wiring, in the ceramic shape: LÖVE's main thread is the render thread only. Settings; shared memory (units and cuboids, front and back); the ceramic engine (023) taking each step in two stages, never waited on; swapping and writing in names and orders between steps; the chair (scroll wheel) turning the world and sliding the arches; drawing (map from beyond, console layers, world, sheet); input (map click names a unit, button click orders it; Escape opens settings); the goodbye and a run log (frames, steps, deliveries, what haulers and cuboids are doing).

| Offers | |
|---|---|
| `run()` | LÖVE's frame loop, replaced (set as love.run by main.lua) |
| `load`, `update`, `draw`, `mousepressed`, `keypressed`, `wheelmoved`, `quit` | the callbacks |

Run options (after the project folder): `--screenshot SECONDS`, `--click SECONDS X Y`, `--key SECONDS NAME`, `--wheel SECONDS NOTCHES`.

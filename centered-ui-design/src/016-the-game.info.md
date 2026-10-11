<!-- written by Claude (Opus 5.5), 2026-10-10: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 016-the-game

The wiring, in the ceramic shape: LÖVE's main thread is the render thread only. Settings; shared memory (units and cuboids, front and back); the ceramic engine (023) taking each step in two stages, never waited on; swapping and writing in names and orders between steps; the chair (scroll wheel: under the hub camera a whole colour a notch, under the far camera an eighth); the look (depth, standing, blur; switched by the settings menu's toggles); the hour of the light dials from the calendar; drawing (map from beyond, console layers, world with sky or table, the focus ring or not, the sheet); input; the goodbye and a run log.

| Offers | |
|---|---|
| `run()` | LÖVE's frame loop, replaced (set as love.run by main.lua) |
| `load`, `update`, `draw`, `mousepressed`, `keypressed`, `wheelmoved`, `quit` | the callbacks |

Run options (after the project folder): `--screenshot SECONDS`, `--click SECONDS X Y`, `--key SECONDS NAME`, `--wheel SECONDS NOTCHES`.

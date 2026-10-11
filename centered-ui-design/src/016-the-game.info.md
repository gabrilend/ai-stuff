<!-- written by Claude (Opus 5.5), 2026-10-10, for the first renderer slice: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 016-the-game

The wiring: settings, shared memory, workers, the soramech step (clock → a move station per unit → join → swap), the frame loop with the cap, drawing, input (map click names a unit, button click orders it; Escape opens settings), and the goodbye.

| Offers | |
|---|---|
| `run()` | LÖVE's frame loop, replaced (set as love.run by main.lua) |
| `load(arguments)`, `update(seconds)`, `draw()`, `mousepressed(x, y, button)`, `keypressed(key)`, `quit()` | the callbacks |

Run options (after the project folder): `--screenshot SECONDS`, `--click SECONDS X Y`, `--key SECONDS NAME`.

# 045-the-viewer

The engine's callbacks, the accumulator, the panel, and the input.

Read this page rather than the source.

## What it is for

This file and the renderer are the only two that touch the engine. Everything
underneath receives a fixed timestep and returns state; this decides when to ask
for one and what to do with the answer.

`tests/052-layering.lua` greps every other file under `src/` and fails if one
mentions the engine, because the failure that prevents does not look like what it
is: one simulation file asks the graphics library for the elapsed time, and
headless stops working three files away, as a crash about something else.

## Exports

The engine's callbacks, forwarded by `main.lua`: `load`, `update`, `draw`,
`resize`, `keypressed`, `wheelmoved`, `mousepressed`, `mousereleased`,
`mousemoved`. Plus `draw_overlay`.

## What it does per frame

`update` pans on held arrow keys, clamps, and hands the real elapsed time to
`Tick.advance` — which is the only place the engine's variable frame time and the
simulation's fixed timestep meet.

`draw` groups the bodies into bands, then walks the bands: the stone's slice of
the mesh, then that band's bodies, then the next. The meshes were baked at scale
one with no pan, so the camera is a transform — panning and zooming a hundred
thousand polygons costs two numbers.

## Keys

A dispatch table, so adding one is a row.

| Key | |
| --- | --- |
| drag, arrows | pan |
| wheel | zoom at the pointer |
| `f` | fit the whole maze |
| `space` | hold the simulation still |
| `.` | one tick, while held still |
| `n` | a new maze, next seed |
| `1` `2` `3` | balls / little guys / both |
| `h` | hide the overlay |
| right click | print what is under the pointer |
| escape | leave |

## Command line

`--seed --width --depth --layers --terraces --scene --zoom --at X Y
--screenshot PATH --after SECONDS`.

`--screenshot` opens the window, lets the simulation settle for `--after`
seconds, saves a frame and leaves. Used by the phase demos, and whenever a
rendering change needs comparing against the same frame from before it — which
is impossible if the camera is somewhere different, so `--zoom` and `--at` take a
shot back to exactly where the last one was.

# 059-say-back — what the porch heard, in plain lines

Reads a raw score back as pseudo-code English, one line per thing in
it, so a person checks what the porch understood without reading Lua
(issue 704). The lines are written from the calls, never by the model:

    the canvas: 256 pixels square, 4 s at 25 frames a second, under the stars
    the eye stands 7.5 back, tipped down 0.25, seeing 44 degrees
    wanderer: a violet icosahedron, glowing, circles at radius 2.4, once a loop, spinning twice a loop
    pane sign: glass 3 by 3 standing at (0, 0.2, -0.6), facing (0, 0, 1)
    spark, 0 to 4 s: a jade point following wanderer

Order is fixed: canvas, camera, world, shapes, panes, then strokes in
playing order. Each shape and camera motion kind has its own saying; a
word a saying doesn't speak of is still named, as `(also: bob)`, so
nothing in a score goes unmentioned. Where a loop starts (`phase`) and
the seeds change no reading and stay quiet.

## Usable surface

- **lines(raw) → { line, ... }** — raw as `score.read` or
  `porch.collect` leave it.
- **header(raw) → text** — the same lines as Lua comments under
  `-- what the porch heard:`, to head a written score.

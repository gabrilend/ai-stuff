# 045-scene-file — a shape scene as a file

A 3D scene is data, not a program (issue 701c). This reads a scene file in
an empty sandbox (no math, no ipairs, no dofile, no debug) and refuses one
that reaches for anything, naming the way out: a generator. It also writes
a scene table back as canonical text, so a generator's output can be kept
as a plain scene.

## Usable surface

- **read(path) → scene** — the file's returned table, or an error that
  says scenes declare and never compute, and where generators go.
- **write(scene, header) → text** — `return { ... }` with keys in a fixed
  order (array part first, then names sorted), short lists of plain values
  on one line, and every number written so it reads back as exactly the
  same double. `header` is comment lines placed above it. A table met
  twice is written twice.

Used by `039-shape-films.lua`, `042`, `043` (reading) and
`046-make-shapes.lua` (writing).

- **value_text(v, indent) → text** — one value as canonical scene text; the score writer writes a two-space score's camera, world, shapes and panes with it.

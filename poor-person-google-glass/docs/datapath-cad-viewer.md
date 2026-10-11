<!-- Made by Claude (Opus 5.5), 2026-10-10, for phase 0 (issues 001-006), as the datapath for the CAD viewer; updated whenever an issue changes it. -->
# Datapath: the CAD viewer

From a model file on disk to a lit, turnable picture. Reading and drawing
are kept apart: everything left of the shape record knows file formats and
nothing about windows; everything right of it knows windows and nothing
about file formats.

```
input/viewer-settings.lua → checked settings (window size, field of view, colours)

model file (path, string)
  → its ending picks a reader (dispatch table)
      .stl        text or binary, told apart by size      up axis z
      .obj (+.mtl) lines; parts by o/g and material      up axis y
      .gltf/.glb  JSON → nodes → meshes → accessors      up axis y
                  → buffers (base64 inside, or .bin beside)
  → shape record: parts, each { name, colour {r,g,b},
        positions: 9 numbers per triangle, normals: same length }
        + bounds, triangle count, degenerate count
  → stood upright (a z-up file is turned a quarter about x)
  → copied once into the graphics card, one mesh per part
  → every frame: orbit camera (target, yaw, pitch, distance)
        → view and projection matrices → drawn, lit from the camera
          and from above, both sides of every surface
  → panel of figures beside it

mouse, keys, or scripted run options (--drag, --key, --wheel, --screenshot)
  → the same handlers → camera or display toggles

on closing → output/goodbye: file, format, triangles, parts, frames,
             seconds, screenshot and its share of black pixels
```

Test models are never drawn by hand: `scripts/make-test-shapes` writes the
formula-made cube and crown sketch in every format into
`tmp/shared-memory/shapes/`. For current figures (bytes, read times, how far
corners move on a round trip) run `issues/completed/demos/phase-0-demo` or
just its table: `luajit issues/completed/demos/phase-0-compare.lua`.

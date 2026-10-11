# 001 — A shape as triangles

**Phase:** 0 — Tools
**Blocks:** 002, 003, 004, 005, 006, 007
**Related documents:** docs/datapath-cad-viewer.md

## Current Behavior
Built. `src/001-the-shape-record.lua` holds the record and its check;
`src/002-the-test-shapes.lua` makes the cube and the crown sketch (2220
triangles, 6 parts, no slivers). Every reader in phase 0 produces this record
and the viewer draws only this record. Readers may add fields of their own
(path, bytes_on_disk, units, skipped) without the record needing to know.

## Intended Behavior
One record that every CAD reader produces and every viewer draws, so the
readers know nothing about drawing and the viewer knows nothing about file
formats. A **shape** is:

| Field | Type | Meaning |
|---|---|---|
| name | string | the file's name, or the model's own name |
| source_format | string | "stl", "obj", "gltf" or "made" |
| up_axis | string | "y" or "z": which way is up in the file's own convention |
| parts | list of part | one entry per named piece |
| bounds | { min = {x,y,z}, max = {x,y,z} } numbers | the box around every corner |

A **part** is { name: string, colour: {r,g,b} numbers 0–1, positions: flat
list of numbers (x,y,z per corner, three corners per triangle), normals:
flat list of numbers the same length (one direction per corner) }.
Triangles only: every format's polygons are cut into triangles on reading.

Missing normals are computed from each triangle's corners (flat facets — the
look CAD models are drawn with). A triangle whose three corners lie on one
line has no direction; it is counted (`degenerate`) and drawn with a zero
normal, never silently removed.

A second piece, the **test shapes**, makes shapes by formula so tests and
demos never need files drawn by hand: a cube, and a rough sketch of the
crown from docs/core-terms.md (band, emitter blocks at the temples, panel arm,
curved panel). Its sizes are placeholders for phase 5, not design.

## Suggested Implementation Steps
1. `src/001-the-shape-record.lua`: new shape, add part, add triangle,
   finish (flat normals where none were given, bounds, counts), check
   (raises on no triangles, mismatched normals, a corner that is not a
   finite number), size. Positions are one flat list per part, not a list
   of corner tables: one allocation, read in order, copied straight to the
   graphics card.
2. `src/002-the-test-shapes.lua`: helpers for an outward-facing triangle
   and quad (each given a point known to be inside the solid, and turning
   itself to face away from it, so no corner order is worked out by hand),
   a box, an oval band arc, a dial disc, a curved panel; the cube; the
   crown sketch (band 200 × 160 mm oval, emitters behind the temples, light
   pipes forward along each side, three dials a side, panel arm, curved
   panel ~50 mm before the brow — placeholder sizes for phase 5).
3. Tests in `src/011-the-tests.test.lua`: cube is 12 triangles in the unit
   box; every cube face points out; crown has 6 parts and no slivers; a
   sliver is counted, not dropped; an empty shape is refused.

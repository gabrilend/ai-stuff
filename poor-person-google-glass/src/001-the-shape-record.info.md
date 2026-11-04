<!-- written by Claude (Opus 5.5), 2026-10-10, for phase 0 (the CAD viewer): what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 001-the-shape-record

The one shape every CAD reader makes and every viewer draws (issue 001).

**shape**: name (string), source_format ("stl"/"obj"/"gltf"/"made"), up_axis ("y"/"z"), parts (list of part), bounds ({min={x,y,z}, max={x,y,z}}, numbers), triangle_count (whole), degenerate_count (whole). Readers may add: path, bytes_on_disk, units (string), skipped ({word = count}).
**part**: name (string), colour ({r,g,b} numbers 0–1), positions (flat list of numbers, 9 per triangle), normals (flat list, same length).

| Offers | Takes | Gives |
|---|---|---|
| `new(name, source_format, up_axis)` | strings | an empty shape |
| `add_part(shape, name, colour)` | colour may be nil (light grey) | the new part |
| `add_triangle(part, ax..cz, normals)` | 9 numbers; normals: list of 9 or nil | nothing |
| `finish(shape)` | | the shape, with flat normals where none were given, bounds and counts; raises via check |
| `check(shape)` | | nothing; raises naming the first problem (no triangles, normals count mismatch, non-finite corner) |
| `size(shape)` | | {x, y, z} extents |

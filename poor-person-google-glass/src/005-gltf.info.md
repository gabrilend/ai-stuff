<!-- written by Claude (Opus 5.5), 2026-10-10, for phase 0 (the CAD viewer): what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 005-gltf

glTF 2.0, the house format (issue 004): .gltf (JSON, buffers as base64 or a .bin beside it) and .glb (one binary file). Follows scene → nodes (placements multiply down the tree) → meshes → triangle primitives → accessors → bufferViews → buffers. Uses libs/dkjson.lua.

| Offers | Takes | Gives |
|---|---|---|
| `read(bytes, name, read_neighbour)` | | a shape, one part per primitive, colour from baseColorFactor (white with no material); units from asset.extras.units |
| `write(shape, made_by, units)` | units: a word, e.g. "millimetres" | one self-contained .gltf text |
| `base64_encode(bytes)`, `base64_decode(text)` | | strings |

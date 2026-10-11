# 004 — Reading and writing glTF

**Phase:** 0 — Tools
**Blocked by:** 001
**Blocks:** 005, 006, 007

## Current Behavior
Built in `src/005-gltf.lua`, with `libs/dkjson.lua` (copied from the shared
lua libraries) for JSON. Also reads the binary container .glb (the same JSON
and one buffer in a single file), since it is the same reader plus a
12-byte header and two chunks.

## Intended Behavior
glTF 2.0 is the house format for the project's own models: structured JSON
text (the owner prefers structured text like JSON), with parts, colours and
placement. The JSON holds `scenes → nodes → meshes → primitives`; numbers
live in **buffers** (base64 inside the JSON as a `data:` address, or a `.bin`
file beside it), sliced by **bufferViews** and typed by **accessors**
(component type, count, VEC3/SCALAR). Each node may carry a placement
(`matrix`, or `translation`/`rotation`/`scale`) that multiplies down the
tree. Primitives with mode 4 (triangles) are read; indices may be 8, 16 or
32-bit. `materials[].pbrMetallicRoughness.baseColorFactor` gives the colour.
Any other mode, a missing buffer, or an accessor running past its buffer
raises an error. Up axis: "y".

The writer emits one node and mesh per part, positions and normals in one
base64 buffer, and `asset.generator` naming what made the file.

JSON is read with dkjson (copied into libs/ from the shared lua libraries).

## Suggested Implementation Steps
1. `src/005-gltf.lua`: base64 both ways (decoding into one preallocated
   byte block); 4x4 placements in glTF's column order, a node's own from
   matrix or translation/rotation/scale, multiplied down the tree; normals
   turned by the inverse-transpose (cofactor matrix, sign of the
   determinant); a mirroring placement swaps two corners so triangles keep
   facing out; accessors read through typed views honouring byteStride and
   checked against the end of their buffer; .glb split into chunks; a
   primitive with no material is white, as the specification says; units
   kept from asset.extras.units. Writing: one node, mesh and material per
   part, positions and normals in one base64 buffer, POSITION min/max
   (required by glTF), asset.generator saying who made it.
2. Tests: base64 round trip for every byte value and each padding length;
   the crown survives a round trip with names, colours and units; 16-bit
   indices and a node's move are followed; a mirroring scale keeps the
   triangle facing out; an accessor past its buffer's end is refused.

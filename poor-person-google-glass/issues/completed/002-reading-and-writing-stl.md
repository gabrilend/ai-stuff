# 002 — Reading and writing STL

**Phase:** 0 — Tools
**Blocked by:** 001
**Blocks:** 005, 006

## Current Behavior
Built in `src/003-stl.lua`. Reads both kinds, writes both kinds. A shape
whose up is y (made shapes, OBJ, glTF) is turned a quarter about x on the way
out, so it stands the same way when read back as z-up STL: found when the
crown sketch, written without the turn, came back lying on its side.

## Intended Behavior
STL is what every CAD program and 3D printer exports: a bare list of
triangles, one part, no colour. Two kinds exist:
- **text**: `solid NAME`, then per triangle `facet normal nx ny nz / outer
  loop / vertex x y z ×3 / endloop / endfacet`, then `endsolid`.
- **binary**: an 80-byte header, a 32-bit little-endian triangle count, then
  50 bytes per triangle (normal and three corners as 32-bit floats, then a
  2-byte attribute word).

The kinds are told apart by size, not by the first word: a binary file whose
header happens to start with "solid" is common. A file whose size is exactly
84 + 50 × count is binary; otherwise it must parse as text, or the reader
raises an error naming the line. Stored normals are ignored (many exporters
write zeros) and recomputed by the shape record. Up axis: "z".

The writer emits both kinds, the first line or header naming what made the
file, so test shapes can be written and read back.

## Suggested Implementation Steps
1. `src/003-stl.lua`: is-binary (size test), binary reading through a
   float view of each 50-byte record (LuaJIT's ffi), text reading as a
   keyword dispatch table where each keyword checks it came in its place,
   text writing (one solid per part; who made it follows the first solid's
   name, since STL has no comments), binary writing (who made it in the
   header, never starting with "solid"), and the y-up to z-up turn.
2. Tests: the crown survives a text round trip part by part (compared after
   standing it upright again); binary round trip keeps every triangle; a
   y-up shape comes back the same height; a binary header starting with
   "solid" still reads as binary; a facet of two corners names its line.

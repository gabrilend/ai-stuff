# 003 — Reading and writing OBJ

**Phase:** 0 — Tools
**Blocked by:** 001
**Blocks:** 005, 006

## Current Behavior
Built in `src/004-obj.lua` and tested; the round trip keeps names, colours
and every corner. Statement handlers are a dispatch table; a face's
directions (vn) are kept only while every face in its part has them, else
the part falls back to computed flat facets; unread statements are counted
in shape.skipped and shown on the viewer's panel as "not read". Tried on a
real export: MagicaVoxel's x-wing.obj reads (580 triangles) but draws white,
because MagicaVoxel colours by a picture (texture, map_Kd and vt) with Kd
1 1 1. Another x-wing.obj elsewhere names a .mtl that is not beside it and is
refused, as intended. Waiting on the open question below.

## Intended Behavior
OBJ is a line-per-statement text format: `v x y z` corners, `vn` normals,
`f a b c ...` faces made of corner numbers (counted from 1, or negative to
count back from the latest), `o NAME` / `g NAME` starting a new part, and
`usemtl NAME` naming a material. A face with more than three corners is cut
into a fan of triangles. A `mtllib` file beside it gives each material its
colour (`Kd r g b`); a missing material library is an error, not a grey
model. Unknown statements (`vt`, `s`, `l`) are skipped and counted.
Up axis: "y".

The writer emits one `o` per part and a `.mtl` beside it carrying colours.

## Suggested Implementation Steps
1. `src/004-obj.lua`: a dispatch table from statement word to handler.
2. Tests: quads become two triangles; negative indices; parts by `o`;
   colours from the material library; a face naming a missing corner raises
   with its line number; an undefined material is refused; the crown
   survives a round trip.

## Open questions
1. Some exporters colour an OBJ by a picture (texture) instead of material
   colours. Should the reader load the picture (map_Kd) and texture
   coordinates (vt), so those models draw in their colours?

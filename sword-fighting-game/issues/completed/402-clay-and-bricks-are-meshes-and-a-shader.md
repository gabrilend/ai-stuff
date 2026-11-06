# 402 — Clay And Bricks Are Meshes And A Shader

| | |
| --- | --- |
| Phase | 4 — Seeing it |
| Blocked by | 401 |
| Blocks | 403, 404 |
| Files | `src/022-clay-meshes.lua` (vertex data, pure), `src/023-the-renderer.lua` (engine meshes and the shader) |
| Reads | `docs/art-direction.md`, `docs/datapath-rendering.md` |

## Current behavior

Built: `src/022-clay-meshes.lua` (blob, box, brick with four studs,
cylinder) and `src/023-the-renderer.lua` (meshes with a normal attribute, one
shader with clay, brick and flat looks, distance fog). Normals under a
stretched shape are corrected by sending the shape's own scale. Checked by
screenshot (development-history/001 onward).

## Intended behavior

**Shapes as data** (no engine calls, so they are testable headless): each
builder returns a list of triangles as flat vertex rows {x, y, z, nx, ny, nz}:

- `blob` — a squashed sphere (latitude/longitude rings), for clay heads,
  bodies and hands;
- `tube` — a tapered cylinder with rounded ends, for clay limbs;
- `brick` — a box with a stud on top, for armor plates;
- `box` — a plain box, for blades and fences;
- `disc` — a flat circle, for shields and ground patches.

Each is built once at start-up at unit size and drawn at any size by its
model matrix.

**The renderer** turns each shape into an engine mesh (vertex format:
position 3 floats, normal 3 floats), and owns one shader with two looks:

- clay: wide wrap-around light (half-Lambert), a soft sky/ground ambient, and
  a thumbprint wobble — brightness modulated by a few sine waves of the
  world position;
- brick: sharper Lambert plus a small specular highlight.

Drawing is `draw(shape, model_matrix, colour, look)`; the camera's
projection and view matrices are set once per frame. The renderer turns the
depth test on for the 3D pass and back off afterwards, so 2D drawing (the
command screen) is unaffected. The window is opened with a depth buffer.

## Suggested implementation steps

1. Write the builders and test vertex counts and that normals are unit
   length.
2. Write the shader and the draw call; check by screenshot.

# 204 — Model format and loader

**Phase:** 2
**Blocked by:** 201 (mesh-draw seam), 105 (fixed-point types).
**Blocks:** 208, 209, plus all later 3D content work.

## Current behavior

There is no 3D model loading path. The render seam declares mesh-draw
but nothing produces mesh handles.

## Intended behavior

A small in-house binary model format `.srm` (Symbeline Rumble Mesh),
emitted at build time from authoring files (`.obj` initially; `.gltf`
later). The runtime loader is byte-identical on both targets; only the
*upload* to the GPU/3D engine differs (handled in the platform seam).

### `.srm` format

```
header: magic 'SRM\0' (4 bytes)
        version uint16
        flags uint16          (bit 0: has texcoords; bit 1: has normals; bit 2: indexed)
        vertex_count uint32
        index_count uint32
        material_count uint16
        reserved[6]
vertices: vertex_count × {
    fxw_t pos[3]              (Q20.12 world units)
    fxa_t normal[3]           (only if flags bit 1)
    fxw_t uv[2]               (only if flags bit 0; uv is fix-point too)
    uint16 material_idx
}
indices: index_count × uint16  (only if flags bit 2; triangles)
materials: material_count × {
    uint8  texture_id          (0 if untextured)
    uint8  flags
    fxsmall_t tint_rgb[3]
}
```

Fixed-point throughout. **No floats in the runtime path** — the asset
emitter does the float→fix conversion at build time.

### Emitter

`scripts/emit-model.lua source.obj dest.srm`:
- Parse `.obj` (Wavefront — small format, easy to handle in Lua).
- Convert positions and uvs to fix-point.
- Triangulate quads if present.
- Write the binary.
- Idempotent (same source → same bytes).

### Loader

`src/06-model-loader.h`: `mesh_handle model_load(const char* path)`.
Reads `.srm`, mmaps or `read()`s into a buffer, validates header,
returns a handle. Frees via `model_free(handle)`.

The handle is opaque to game code. The platform seam exposes
`platform_render_mesh_upload(model_handle) → mesh_handle` which uploads
to the 3D engine; on NDS this means converting to display lists and
binding textures, on native this means a raylib `Mesh` upload.

## Suggested implementation steps

1. Author `scripts/emit-model.lua` — LuaJIT-compatible, vimfold-
   structured, CEO comment.
2. Define the `.srm` format in `src/06-model-format.info.md` as the
   canonical spec.
3. Author `src/06-model-loader.h` and `.c` — pure-trunk, no platform
   bits, only the format parsing.
4. Extend `platform_render_mesh_upload` and `platform_render_mesh_xform`
   in both target implementations.
5. Add a test cube model in `assets/dev/cube.obj`; emit
   `assets/dev/cube.srm` at build time; render it via the camera test
   from issue 203.

## Deliverable artifacts

- `scripts/emit-model.lua`.
- `src/06-model-loader.h`, `src/06-model-loader.c`, `.info.md`.
- `src/06-model-format.info.md` (the canonical format spec).
- `assets/dev/cube.obj` (test asset).
- `assets/dev/cube.srm` (generated; gitignored).
- Platform impl updates on both targets.

## Related documents

- `docs/008-fixed-point-math.md` — Q-format for positions.
- `docs/004-architecture.md` — asset pipeline philosophy.

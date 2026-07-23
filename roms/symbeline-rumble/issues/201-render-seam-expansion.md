# 201 — Render seam expansion

**Phase:** 2
**Blocked by:** 104 (platform seam).
**Blocks:** every other phase-2 issue.

## Current behavior

`src/01-platform.h` declares a minimal `platform_render_*` surface from
phase 1 — `platform_render_clear`, `platform_render_sprite`,
`platform_render_mesh` — sufficient for the bobbing knight but not for
3D scenes with cameras, lighting, or textured geometry.

## Intended behavior

Expand the platform render surface to support the operations phase 2
needs across both targets:

- **View and projection setup** per frame. `platform_render_set_camera`
  takes a `camera_t` struct (position, target, FOV, near/far) and
  produces the view+projection matrices the backend submits to its 3D
  engine.
- **Mesh draw with transform**. `platform_render_mesh_xform(handle,
  &transform_t)` where `transform_t` is a fixed-point pos+rotation+scale.
- **Texture binding**. `platform_render_bind_texture(handle, slot)` for
  textured meshes.
- **Viewport / scissor**. `platform_render_set_viewport(rect_t)` so we
  can render into the top half, the bottom half, or a sub-region of
  either independently.
- **Depth control**. `platform_render_set_depth_test(bool)`, and a
  depth-clear in `platform_render_clear`.
- **Tilt-shift hook**. `platform_render_begin_tilt_shift(band_top,
  band_bottom)` / `platform_render_end_tilt_shift()`. Pass-through on
  trunk; filled by the tilt-shift divergence patches (issue 206).

The API is *the same on both targets*; implementations differ behind
the seam.

## Suggested implementation steps

1. Extend `src/01-platform.h` with the new declarations. Update
   `src/01-platform.info.md` accordingly.
2. Stub all new functions in `src/platform/nds/01-platform-nds.c` and
   `src/platform/native/01-platform-native.c` with `platform_log` calls
   noting "not implemented; phase-2 issue X will fill."
3. Add a `transform_t` and `camera_t` typedef to the header (or a new
   `src/03-render-types.h` — the index counter advances). Both use
   `fxw_t` for positions and `fxa_t` for angles, per fixed-point rules.
4. Verify the project still builds clean on both targets after the
   surface expansion (stubs only — no behavior change).

## Deliverable artifacts

- Updated `src/01-platform.h`, `src/01-platform.info.md`.
- New `src/03-render-types.h` and `.info.md` for camera/transform.
- Stubbed implementations in both platform impl files.
- `.file-index-counter` bumped to 3.

## Related documents

- `docs/004-architecture.md` — platform seam principles.
- `docs/005-divergence-grid.md` — row D2 (graphics submission) is the
  load-bearing one for this issue.

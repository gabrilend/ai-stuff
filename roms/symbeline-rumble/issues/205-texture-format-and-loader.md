# 205 — Texture format and loader

**Phase:** 2
**Blocked by:** 201 (texture-bind seam).
**Blocks:** 206, 208, 209.

## Current behavior

There is no texture loading path. Materials in `.srm` files reference
texture IDs that point at nothing.

## Intended behavior

A small in-house binary texture format `.srt` (Symbeline Rumble
Texture), emitted at build time from PNG sources. The format differs
internally between targets but is selected at build time, not runtime:

- **NDS profile build**: paletted, 4bpp or 8bpp, 16- or 256-entry
  palette. Constrained to libnds-friendly dimensions (powers of 2,
  ≤256 wide).
- **Native profile build**: RGBA8, arbitrary dimensions up to the same
  NDS-style limits — to honor the parity rule from
  `docs/004-architecture.md`.

The PNG source is the same; the build emitter writes a different
`.srt` per profile into the profile-specific build directory.

### `.srt` format (both variants)

```
header: magic 'SRT\0' (4 bytes)
        version uint16
        format uint8          (0=PAL4, 1=PAL8, 2=RGBA8)
        flags uint8
        width uint16
        height uint16
        palette_count uint16  (0 for RGBA8)
        reserved[8]
palette: palette_count × uint16  (RGB555 for PAL4/PAL8)
data:    width * height * bytes_per_pixel (1/8, 1, or 4 bytes per pixel)
```

### Emitter

`scripts/emit-texture.lua source.png dest.srt --profile=nds|native`:
- For PAL formats: median-cut palette generation, dithering optional.
- For RGBA: straight pixel copy.
- Idempotent: same source + same profile → same bytes.

The emitter is invoked by the build script per profile so each profile
sees the textures appropriate to its constraints.

## Suggested implementation steps

1. Author `scripts/emit-texture.lua`.
2. Define format in `src/07-texture-format.info.md`.
3. Author `src/07-texture-loader.h`, `.c`.
4. Implement `platform_render_bind_texture` on both targets.
5. Add a test texture (a small `dev/grass.png`); emit per profile;
   bind to the cube from issue 204 and render.

## Deliverable artifacts

- `scripts/emit-texture.lua`.
- `src/07-texture-loader.h`, `.c`, `.info.md`.
- `src/07-texture-format.info.md`.
- `assets/dev/grass.png`.
- Profile-specific generated `.srt` files (gitignored).

## Related documents

- `docs/004-architecture.md` — VRAM budgets (NDS texture VRAM ≈ 512 KiB).
- `docs/006-art-direction.md` — palette family.

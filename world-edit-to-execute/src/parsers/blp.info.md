# blp.lua

Reads Warcraft III's BLP1 textures into RGBA pixels, for the renderer, the
editor and the asset tools. Both ways WC3 stores pixels are read: JPEG
(through `parsers/jpeg.lua`) and a 256-colour palette with 0, 1, 4 or 8
bits of alpha a pixel. BLP2, World of Warcraft's version, is refused by
name. Needs LuaJIT (FFI and `bit`).

## Functions

| Function | Takes | Gives |
|----------|-------|-------|
| `header(bytes)` | the file's bytes (string) | `{compression, alpha_bits, width, height, picture_type, has_mipmaps, offsets, sizes, jpeg_header_size}`; offsets and sizes are indexed 0-15 |
| `decode(bytes, level)` | the bytes, a mipmap number (0 = full size, the default) | `{width, height, rgba, alpha_bits, compression}`; `rgba` is a string, four bytes a pixel, rows top first; `compression` is `"jpeg"` or `"paletted"` |
| `decode_all(bytes)` | the bytes | `{width, height, alpha_bits, source_format, levels}`; `source_format` is `"jpeg"` or `"palette"`; `levels` lists `{width, height, rgba}` for every mipmap the file holds, largest first |

Constant: `MAX_SIDE` (16384), the longest side accepted; a longer one
means the header is damaged.

## The format

`BLP1`, then seven 32-bit little-endian numbers (compression: 0 JPEG, 1
palette; alpha bits; width; height; picture type; has mipmaps), sixteen
mipmap offsets and sixteen sizes: 156 bytes. Then:

- **JPEG:** the size of a shared JPEG header, and that header. Each
  mipmap is the rest of a JPEG; joined to the header it decodes as an
  ordinary one. Its four components are B, G, R, A, stored without a
  colour transform, so they are swapped to R, G, B, A here.
- **Palette:** 256 colours, four bytes each (B, G, R, unused). Each
  mipmap is one palette index a pixel, then the alpha values packed at
  the header's depth (low bits first).

## Errors

Every error from a bad file starts `BLP:` and names the part and its
byte offset:

- `BLP: the header at byte 0 needs 156 bytes, but the file ends at byte 24`
- `BLP: the palette at byte 156 needs 1024 bytes, but the file ends at byte 600`
- `BLP: mipmap 2 (1 x 1) at byte 1200 needs 2 bytes, but the file ends at byte 1201`
- `BLP: mipmap 0 (16 x 8), JPEG at byte 282: JPEG: segment C0 at byte 122 claims 65535 bytes, 58 are left`
- an alpha depth that isn't 0, 1, 4 or 8, a side longer than `MAX_SIDE`,
  an unknown compression, or a mipmap the file doesn't hold, each named.

No read goes past the end of the file, in this reader or in the JPEG
reader under it.

## Tests

`src/tests/test_blp.lua` builds paletted and JPEG textures byte by byte;
`src/tests/test_assets.lua` decodes every BLP the test maps carry.

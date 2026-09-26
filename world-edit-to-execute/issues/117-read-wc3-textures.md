# Issue 117: Read WC3 Textures (BLP1)

**Phase:** 1 - File Format Parsing
**Type:** Implementation
**Priority:** High
**Dependencies:** W01 (the binding to the shared reader)
**Blocks:** 516 (drawing models in the engine), 603 (the fetcher's model check)
**Related:** 116 (models name these textures), W01 (reads WoW's BLP2)

---

## Current Behavior

No reader exists for WC3 textures. Models (116) name their textures by path,
and WC3 stores them as BLP1 files. The only BLP reader on this machine is the
custom client's (`/mnt/mtwo/games/azeroth-core/custom-client/issues/107-blp-parser.md`),
which Phase W uses through W01; it reads **BLP2**, WoW's later version, and
not BLP1. The asset loader issue (601) lists BLP loading as a stub and notes
"we may need a decoder or require PNG conversion".

## Intended Behavior

**In the shared reader** (owner, 2026-09-26: "same reader"). BLP1 decoding
is added to the custom client's BLP reader, the library W01 binds
(`libwreaders.so`, read through `src/wow/readers.lua`), so one library reads
both versions of the format and W01's rule of "no second BLP
implementation" holds for WC3 textures too. The work is done in the custom
client's project; this project reads WC3 textures through W01's binding.

A decoder that turns a BLP1 file into an RGBA image (width, height, and
four bytes per pixel) for each of its mip levels, for the renderer (516) to
upload.

**The format.** A BLP1 file starts with the four bytes `BLP1`, then a header:
compression (0 = JPEG, 1 = palette), alpha bits, width, height, a picture
type and a has-mipmaps flag, then sixteen mip-level offsets and sixteen
sizes. The two ways the pixels are stored:
- **JPEG:** a shared JPEG header follows the file header; each mip level is
  that header joined to the level's own bytes, decoded as an ordinary JPEG.
  Its channels are stored blue, green, red, alpha, so they are swapped after
  decoding.
- **Palette:** a 256-colour palette (four bytes each), then per mip level
  one palette index per pixel, followed by alpha values at the header's
  alpha depth (0, 1, 4 or 8 bits per pixel).

**Output** (a Lua table): `width`, `height` (integers), `levels` (a list of
`{ width, height (integers), rgba (string, four bytes per pixel) }`), and
`source_format` (`"jpeg"` or `"palette"`).

## Suggested Implementation Steps

All in the shared reader, in the custom client's project, unless noted:
1. Header reader and mip table for BLP1, beside the BLP2 reader; the magic
   bytes choose which.
2. Palette decoding, with each alpha depth.
3. JPEG decoding: find a JPEG decoder already on the machine (in
   `/home/ritz/programming/ai-stuff/libs/` or the system) before writing
   one; the channel swap after it.
4. The shared reader's `.info.md` gains the BLP1 entry point.
5. Tests: a palette texture and a JPEG texture built by the test itself
   decode to known pixels; a truncated file fails with an error naming the
   mip level and offset.
6. In this project: W01's binding exposes BLP1 decoding, and
   `src/tests/test_blp.lua` checks it end to end.

## Acceptance Criteria

- [ ] Palette BLP1 files decode, at every alpha depth, for every mip level
- [ ] JPEG BLP1 files decode, with the channels in the right order
- [ ] Truncated files fail with errors that name the mip level and offset
- [ ] One library reads BLP1 and BLP2; no second BLP reader exists in this project
- [ ] Tests pass without any downloaded or proprietary file present

## Open Questions

1. ~~A separate reader, or the shared one?~~ Answered 2026-09-26: the shared
   one ("same reader").

## Related Documents

- `issues/116-read-wc3-models.md`
- `issues/516-draw-wc3-models-in-engine.md`
- `issues/W01-read-the-wow-client-archives.md`
- `issues/601-asset-loader-resolution.md`

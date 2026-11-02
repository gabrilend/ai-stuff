# Issue 117: Read WC3 Textures (BLP1)

**Phase:** 1 - File Format Parsing
**Type:** Implementation
**Priority:** High
**Dependencies:** None (W01 was the shared reader's binding; see open question 2)
**Status:** Completed 2026-11-02
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

> **2026-11-02:** superseded by open question 2's answer: BLP1 stays in
> this project's own Lua reader; the shared reader taking it over is the
> idea issue W09. The paragraph below is kept as the record.

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

- [x] Palette BLP1 files decode, at every alpha depth, for every mip level
- [x] JPEG BLP1 files decode, with the channels in the right order
- [x] Truncated files fail with errors that name the mip level and offset
- [x] ~~One library reads BLP1 and BLP2; no second BLP reader exists in this project~~ Decided 2026-11-02 (open question 2): BLP1 stays in this project's own reader, `src/parsers/blp.lua`; one library for both is the idea issue W09
- [x] Tests pass without any downloaded or proprietary file present

## Open Questions

1. ~~A separate reader, or the shared one?~~ Answered 2026-09-26: the shared
   one ("same reader").
2. ~~**Does the shared-reader answer still stand, now that this project has
   its own BLP1 reader?** (Asked 2026-11-02; also `issues/CRITICAL-PATH.md`
   Q-9.) Three days after the answer above, issue 522 built a BLP1 reader
   in Lua inside this project (`src/parsers/blp.lua`), and the renderer,
   editor and asset tools use it. The shared library is in the custom
   client's project, outside this repository, and W01's binding to it
   isn't built. The options: (a) keep the Lua reader for BLP1 and let the
   shared library read BLP2 for Phase W, two readers for two versions;
   (b) move BLP1 into the shared library when W01 binds it, and retire the
   Lua reader then; (c) the reverse: BLP2 added to the Lua reader. Until
   it is answered, the fourth acceptance box stays open and this issue
   stays open.~~ **Answered 2026-11-02 (option a):** the BLP1 reader stays
   this project's own Lua reader. The build session made the call, on the
   owner's standing word to answer open questions: merging BLP1 into the
   shared library would tie this project to the custom client's for a
   reader that already works, and that is a separate change, best made once
   both readers are stable. It is filed, unbuilt, as the idea issue
   `issues/W09-shared-reader-takes-over-blp1.md`. Phase W reads BLP2
   through the shared library as planned.

## Related Documents

- `issues/116-read-wc3-models.md`
- `issues/516-draw-wc3-models-in-engine.md`
- `issues/W01-read-the-wow-client-archives.md`
- `issues/W09-shared-reader-takes-over-blp1.md` (the idea of one reader for both, unbuilt)
- `issues/601-asset-loader-resolution.md`

## Implementation Notes

**Date:** 2026-11-02

### What was already there

Issue 522 (2026-09-29) built a BLP1 reader in this project,
`src/parsers/blp.lua`, on its own JPEG reader (`src/parsers/jpeg.lua`):
both kinds, every alpha depth, any mipmap. Every BLP in the 16 test maps
decodes (285 distinct, 258 JPEG and 27 paletted, 2,046 mipmaps). This file
wasn't updated then. What the reader lacked against this issue's criteria:
errors naming the level and offset, the every-level output shape, and a
test needing no downloaded file. This pass adds those. It doesn't touch the
shared-reader question (open question 2), answered separately below.

### Changes

- **`src/parsers/blp.lua`**
  - Every part is checked to lie inside the file before it is read: the
    header, the JPEG header, the palette, and each mipmap's bytes (for the
    palette kind, its indices and packed alpha). A failed check names the
    part, the byte it starts at, the bytes it needs and where the file
    ends. Before, a cut-short paletted texture failed on arithmetic with a
    missing value ("attempt to perform arithmetic on a nil value"), and a
    cut-short JPEG one was handed to the JPEG reader as it was.
  - The JPEG reader's errors come back prefixed with the mipmap and its
    offset.
  - An alpha depth other than 0, 1, 4 or 8 is refused by number; before,
    it was read as no alpha.
  - A side longer than 16,384 (`blp.MAX_SIDE`) is refused as a damaged
    header, so a wrong size can't ask for gigabytes of pixels.
  - `blp.decode_all(bytes)` gives the shape this issue asked for:
    `{width, height, source_format, levels = {{width, height, rgba}, ...}}`.
    `blp.decode(bytes, level)` is unchanged for its callers.
- **`src/parsers/jpeg.lua`:** its byte reads are bounded too. A segment
  length that ran past the data made the marker loop read raw memory
  beyond the buffer, and a scan cut short read past the end until it
  happened on a marker. Now a segment that runs past the data is an
  error naming it and its byte, and a scan that ends early reads zeros
  from there, as libjpeg does.
- **`src/parsers/blp.info.md`** describes inputs, outputs and errors.

Every one of the 2,046 mipmaps in the test maps decodes to the same
bytes as before.

### Tests (`src/tests/test_blp.lua`, 21 tests, under a second)

The test writes its own textures:
- a 4 x 2 paletted texture with three mipmaps at each alpha depth (0, 1,
  4, 8), every pixel's colour and alpha checked;
- a 16 x 8 JPEG texture with two mipmaps, made by a small JPEG writer in
  the test (four components, solid 8 x 8 blocks, so each block decodes
  exactly). Two differently coloured blocks show the B, G, R, A channels
  come out as R, G, B, A.

Then, for both kinds, a cut at every byte gives an error naming a byte.
The errors name the mipmap and the palette by name, a damaged JPEG
segment is named with the JPEG reader's reason, and every 4-byte window of
a paletted texture overwritten gives only the reader's own errors.
`test_assets`, `test_ground`, `test_imports` and `test_effects` still pass.

### Decisions made while building

1. **Checked against the file, not the header's mipmap size, for the
   paletted kind.** All 27 paletted textures in the test maps declare
   sizes that cover their pixels, but what has to be safe is reading the
   file; a texture whose declared size is a little short but whose bytes
   are there still decodes.
2. **A scan cut short inside a mipmap reads zeros, not an error.** It is
   what libjpeg does, and a mipmap's declared bytes are already checked to
   be in the file, so this case is a damaged JPEG, not a cut file.
3. **The output shape 117 asked for is added beside the old one** rather
   than replacing it: the renderer, editor and asset tools call
   `decode(bytes, level)`.
4. **The reader stays here (open question 2, Q-9).** See the answer under
   Open Questions; the shared reader taking over is W09, an idea not to be
   built until both readers are stable.

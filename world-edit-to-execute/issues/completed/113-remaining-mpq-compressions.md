# Issue 113: The Remaining MPQ Compression Methods

> **Superseded 2026-09-24 by issue 114** (`issues/114-read-maps-through-stormlib.md`): maps are read through StormLib, which reads every stored file including those with no known name; the reader this issue built was retired. This issue stays as the record of how it was built.

**Phase:** 1 - Foundation, File Format Parsing
**Type:** Implementation
**Priority:** Medium
**Dependencies:** None open
**Builds on (completed):** file extraction (102d), PKWARE decompression (109)
**Status:** Completed 2026-09-24

---

## Current Behavior

The project's own MPQ reader decompresses every method Warcraft III and WoW
3.3.5a data use:

| Method | Byte | Implemented in |
|--------|------|----------------|
| PKWARE DCL | 0x08 | `src/mpq/pkware.lua` (Lua; unchanged) |
| Huffman | 0x01 | `src/mpq/huffman.lua` (Lua, ported from StormLib's `huff.cpp`) |
| ADPCM mono / stereo | 0x40 / 0x80 | `src/mpq/adpcm.lua` (Lua, ported from StormLib's `adpcm.cpp`) |
| zlib | 0x02 | `src/mpq/system_codecs.lua` (system `libz.so.1` via LuaJIT FFI) |
| bzip2 | 0x10 | `src/mpq/system_codecs.lua` (system `libbz2.so.1` via LuaJIT FFI) |
| sparse | 0x20 | not implemented: StarCraft II era; reported as an error naming the mask |

`src/mpq/extract.lua`'s `decompress_sector` undoes them in Storm's fixed order
(bzip2, PKWARE, zlib, Huffman, ADPCM stereo, ADPCM mono), caps each step at
the sector's size, returns a sector stored at its full size unchanged (no
method byte), and treats an unknown method bit as an error.

Measured on 2026-09-24:
- All 369 files across the 16 maps in `assets/` read byte-identical to
  StormLib (`src/tests/test_stormlib.lua`), including the two Huffman minimap
  images that failed before.
- 150 Warcraft III sound files from `war3.mpq` read identical to StormLib;
  they exercised 2,951 sectors of Huffman + ADPCM mono (`0x41`) and 856 of
  Huffman + ADPCM stereo (`0x81`).
- `src/tests/test_codecs.lua`: zlib and bzip2 round trips and damaged-input
  errors, the raw-sector and unknown-method rules, and 60 real sound files
  against StormLib (skipped with a loud notice when the install is absent).
- The comparison test runs in about 2 seconds, down from minutes, because the
  old zlib route is gone.

## Intended Behavior

(Met.) Every method Warcraft III uses decompresses in the project's own
reader, which stays an independent check against StormLib.

## How it was built

Chosen by the owner: **port**, not delegate. (Delegating unsupported files to
StormLib was the alternative; it would have made the reader stop being an
independent check for exactly those files, and it is a fallback, which the
house rules treat as an error.)

1. **Huffman** (`huffman.lua`): the decompression half of StormLib's adaptive
   Faller-Gallager-Knuth tree. Nine starting weight tables, one per data type;
   after every byte the byte's weight rises and the tree rebalances; `0x100`
   ends a sector, `0x101` escapes a new byte. StormLib's "quick link" cache was
   left out: it only speeds decoding up. The weight tables were checked value
   by value against `huff.cpp` (all 9 × 256 match).
2. **ADPCM** (`adpcm.lua`): StormLib's decoder, with its two step tables
   (checked against `adpcm.cpp`) and the special codes `0x80` (repeat, shrink
   step) and `0x81` (grow step, no sample).
3. **zlib and bzip2** (`system_codecs.lua`): LuaJIT FFI calls to the system
   libraries StormLib itself links to. This **replaced a Python one-liner**
   the reader used to run on temporary files for zlib, which also skipped
   zlib's header and checksum, a workaround for the trailing-bytes decryption
   bug fixed the same day (see `extract.lua`'s `decrypt_sector`). The checksum
   is verified again.
4. **Sector rules** in `decompress_sector`, as above.
5. Each ported file keeps StormLib's copyright and licence notice; `.info.md`
   beside each new file.
6. `docs/formats/mpq-archive.md` corrected: its decompression order listed
   ADPCM first.

## Acceptance Criteria

- [x] Huffman and ADPCM decompress; the two failing minimap images match StormLib
- [x] bzip2 decompresses
- [x] `src/tests/test_stormlib.lua` passes on every map in `assets/`

## Notes

- zlib and bzip2 now need LuaJIT (the FFI); the rest of the reader still runs
  on plain Lua.
- The full test suite: 105 of 106 files pass; `test_frames.lua` (pathfinding
  direction constants) was already failing before this work and is unrelated.

## Related Documents

- `issues/112a-stormlib-build-and-update-script.md` (the comparison test)
- `docs/formats/mpq-archive.md`
- `src/mpq/huffman.info.md`, `src/mpq/adpcm.info.md`, `src/mpq/system_codecs.info.md`

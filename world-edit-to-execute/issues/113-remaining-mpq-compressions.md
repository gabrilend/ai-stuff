# Issue 113: The Remaining MPQ Compression Methods

**Phase:** 1 - Foundation, File Format Parsing
**Type:** Implementation
**Priority:** Medium (blocks reading some maps' files; blocks 112a's comparison test passing)
**Dependencies:** None open
**Builds on (completed):** file extraction (102d), PKWARE decompression (109)

---

## Current Behavior

The project's own MPQ reader (`src/mpq/extract.lua`) decompresses zlib and
PKWARE. For the other methods a sector's first byte can name, it returns an
error:

| Method | Byte | Used by | Status |
|--------|------|---------|--------|
| Huffman | 0x01 | Warcraft III, mostly on sound, sometimes on other files | "not implemented" |
| ADPCM mono / stereo | 0x40 / 0x80 | Warcraft III sound (lossy), usually together with Huffman | "not implemented" |
| bzip2 | 0x10 | later Blizzard archives (WoW, patches) | "not implemented" |
| sparse | 0x20 | StarCraft II era | not needed |

On 2026-09-24 the reader-vs-StormLib test (`src/tests/test_stormlib.lua`)
compared 369 files across the 16 maps in `assets/`: all match except two
minimap images (`war3mapMap.blp` in `Daow4.4.w3x` and `Daow4.7.3.w3x`), which
are Huffman-compressed.

## Intended Behavior

Every method Warcraft III uses decompresses, and the comparison test passes on
every map. Methods can be combined in one sector (the byte is a bit mask); they
are undone in Storm's fixed order.

## Suggested Implementation Steps

Two ways to get there (open question 1):

- **(a) Port to Lua.** Huffman and ADPCM ported from StormLib's `huff.cpp` and
  `adpcm.cpp` (MIT; the port keeps their notice), about 1,460 lines of C++.
  bzip2 through LuaJIT's FFI to the system's `libbz2`. The project's reader
  stays complete on its own, and the StormLib test keeps checking the port.
- **(b) Hand those methods to StormLib.** When the reader meets a method it
  doesn't implement, it reads that file through `src/mpq/stormlib.lua` instead.
  Less code, but the reader stops being an independent check for exactly those
  files, and it's a fallback, which the house rules treat as an error unless
  named and counted.

Either way:
1. Tests: each method on small fixtures, plus the full comparison test.
2. Update `docs/formats/mpq-archive.md` with the decompression order used.

## Acceptance Criteria

- [ ] Huffman and ADPCM decompress; the two failing minimap images match StormLib
- [ ] bzip2 decompresses
- [ ] `src/tests/test_stormlib.lua` passes on every map in `assets/`

## Open Questions

1. Port (a) or delegate (b)?

## Related Documents

- `issues/112a-stormlib-build-and-update-script.md` (the comparison test)
- `docs/formats/mpq-archive.md`

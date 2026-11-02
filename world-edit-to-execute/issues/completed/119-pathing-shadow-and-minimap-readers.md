# Issue 119: Readers for the Pathing Map, Shadow Map and Minimap Icons

**Phase:** 1 - File Format Parsing
**Type:** Implementation
**Priority:** Medium
**Dependencies:** None
**Related:** A06 (the coverage report that found the gap)
**Status:** Completed 2026-11-02

---

## Current Behavior

The parser coverage report (A06) found three map data files in every one of
the 16 test maps with no reader under `src/parsers/`: the pathing map
(`war3map.wpm`), the shadow map (`war3map.shd`) and the minimap icons
(`war3map.mmp`), 48 files in all. The building-footprint code
(`demo/wc3map/footprint.lua`, issue 536) read `.wpm` with a few lines of its
own that checked only the start and the length.

## Intended Behavior

One reader for each, in `src/parsers/`, in the style of the others: a
`parse` that raises an error saying what is wrong with a damaged file, an
`.info.md` beside it, and a test that builds its own files and also reads
every test map. The coverage report lists all three as read.

## Acceptance Criteria

- [x] `parsers/wpm.lua`, `parsers/shd.lua`, `parsers/mmp.lua`, each with an `.info.md`
- [x] Damaged files are refused with an error naming the problem (start, version, size, length)
- [x] All three read in every test map
- [x] The coverage report counts them as read
- [x] No second `.wpm` reader is left in the project

## Implementation Notes

**Date:** 2026-11-02

- **`src/parsers/wpm.lua`:** the header, a lookup by cell, yes-or-no
  questions for walking, flying, building, water and blight, and counts by
  flag. `wpm.size_for` gives the size from the terrain.
- **`src/parsers/shd.lua`:** takes the grid's size from the caller (the
  file has none); without one it only counts.
- **`src/parsers/mmp.lua`:** each icon's kind, position and colour.
- **`src/demo/wc3map/footprint.lua`:** `parse_wpm` now reads through
  `parsers/wpm.lua`, keeping its old answer shape and its nil for a file it
  refuses. `test_footprint`, `test_new_map`, `test_editor` and
  `test_editor_integration` pass.
- **`src/cli/parser-coverage.lua`:** the three are in its reader table. On
  all 16 test maps: 2,759 files, **2,713 read** (was 2,665) and **46 with
  no reader** (was 94: one MP3 and 45 unnamed files StormLib couldn't name).
  Its test now uses the import list (`war3map.imp`, in neither of its maps)
  as the kind with no reader.
- **`src/tests/test_wpm_shd_mmp.lua`** (42 tests, about 4 seconds): built
  files for each, read back cell by cell and icon by icon; every cut of a
  pathing map refused; and on every test map: all three read, each pathing
  map is four cells per terrain cell each way, the pathing map's water
  agrees with the terrain's south-up (92% on DAoW-2.1 and Daow4.4, against
  68-71% upside down), and all 192 start icons sit within 2 minimap pixels
  of the start of the player in their colour.

### Decisions made while building

1. **Row 0 is the south edge** for the pathing and shadow maps, as for the
   terrain. Checked, not assumed: the pathing map's water agrees with the
   terrain's far better that way up (above). It doesn't agree everywhere:
   the editor's water and the terrain's flag differ at shores and in
   shallows, so the test asks for a clear margin, not a match.
2. **The minimap's y counts from the top, and it shows the playable area**
   (the map less `war3map.w3i`'s margins), found by placing every start
   icon: with the whole map instead, icons were up to 6 pixels out.
3. **Unknown icon types are kept** as kind `"unknown"`, and shadow bytes
   other than 0x00 and 0xFF are counted as shadow (and in `odd_bytes`),
   not refused: neither breaks anything that reads them. An unknown file
   version is refused, as the other readers do.
4. **The shadow map takes its size from the caller.** The file has no
   header; guessing a square from the length would be wrong for maps that
   aren't square.
5. **0x80 in the pathing map is named `UNKNOWN`.** It is set on cliff faces
   and the map's edge, but no description of the format gives it a
   meaning, so the reader doesn't invent one.
6. **The footprint code's own `.wpm` reading now goes through this reader**,
   so the project has one; it is stricter (an unknown version or extra
   bytes are refused), and no map the project writes or reads has either.
7. **Numbered 119**, not 118: 118 is used by the open branch for issue
   118 (`claude/compat-truncated-reads`).

## Related Documents

- `issues/completed/A06-parser-coverage-report.md` (found the gap)
- `issues/completed/536-building-footprints.md` (the footprint code)
- `docs/formats/w3e-terrain.md` (the terrain grid these sit on)

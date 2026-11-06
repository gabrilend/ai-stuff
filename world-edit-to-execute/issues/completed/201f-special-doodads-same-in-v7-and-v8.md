# Issue 201f: The Special Doodads Section Is the Same in Versions 7 and 8

**Phase:** 2 - Data Model
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 201e (open pull request; this branch is cut from it)
**Builds on (completed):** 201 (the parser `src/parsers/doo.lua`), 911a (writing doodads back)
**Related:** 201e's "Still open"

---

## Current Behavior

`war3map.doo` ends with a special doodads section: a version, a count and
the entries. The parser read the entries two ways by the file's version:

- version 8: 16 bytes each, an ID and three int32s (`unknown1`, `x`, `y`);
- version 7: an ID, then item sets (a count, and per set a count and an
  ID and chance per item), as issue 201's plan had it.

Nothing in the files supports the version 7 reading:

- On all 19 test maps, versions 7 and 8 alike, what follows the last
  doodad is exactly 8 bytes and 16 per entry. The two version 7 maps
  (DAoW-5.2, DAoW-5.3) have no entries, so nothing reads wrong today,
  but a version 7 map with entries would be read as item tables and
  thrown out of step.
- The entries on the version 8 maps (Conquest-v8-fix 25, DAoW-2.1 14,
  Daow4.4 and Daow4.7.3 8 each, Master-Crafters-Final-Conquest 4) are
  not item drops: their IDs (YCc1, YCx1, LCc0, LCc2, ...) are never
  the ID of a doodad in the same file, the second int is 0 on every one,
  and x and y are small whole numbers inside each map's 257 by 257 tile
  grid. A doodad's own drops are in its entry (201e).

`doo.format` also assumed the version 7 reading: it counted each special
doodad's `item_sets`, which the version 8 entries don't have, so it
raised an error on the five maps above.

## Intended Behavior

- One reading for both versions: 16 bytes per entry, `id`, `unknown1`,
  `x`, `y`, as the version 8 reading already had it.
- A count that doesn't fit the data gives nil and a message naming the
  section, as 201e does for a doodad's item list.
- `doo.format` lists special doodads by ID and tile position.

## Acceptance Criteria

- [x] `parse_special_doodads` reads versions 7 and 8 the same way
- [x] A cut or impossible count is refused with a message
- [x] `doo.format` works on every test map
- [x] `test_doo` reads, writes back and formats version 7 and 8 files
      with special doodads, refuses a cut section, and on the real maps
      checks that every entry in the section is read and that
      `doo.format` runs
- [x] Every test map's `war3map.doo` still writes back byte for byte

## Implementation Notes

**Date:** 2026-11-06 (Claude, in the background; the owner reviews the draft pull request)

- `src/parsers/doo.lua`: `parse_special_doodads` loses its version
  argument and its item-drop branch, checks the count against the data,
  and always returns `{ version, doodads }`; `doo.parse` passes a refusal
  on; `doo.format` prints `ID at (x, y)`.
- `src/tests/test_doo.lua`: `build_special_doodad` writes the 16-byte
  entry; `build_doo_with_special` writes its doodads in the version it is
  given and can state a wrong count; `test_parse_special_doodads` covers
  versions 7 and 8 and a cut section; the real-map test adds two checks.
- Checked against the old parser: the synthetic test stops on the version
  7 file, and the real-map test fails five maps on `doo.format`.

### Decisions (2026-11-06)

- **Version 7 is read like version 8.** The issue was left open in 201e
  because no test map has a version 7 section with entries. Decided to
  change it anyway: every test map of either version has the section's
  header in the same place, and every map with entries has 16-byte
  entries that aren't item drops. The item-drop reading came from 201's
  plan, not from a file. If a version 7 map with entries ever reads
  otherwise, the synthetic test here is the place to change.
- **The field names stay** (`unknown1`, `x`, `y`). The second int is 0 on
  every test map, so the files don't say what it is; renaming it would
  be a guess. Nothing outside `doo.lua` reads these fields.
- **A section that doesn't fit is refused,** not kept quietly as
  `tail_raw`: all 19 maps fit exactly, so a misfit means a misread, as
  with 201e's item lists.

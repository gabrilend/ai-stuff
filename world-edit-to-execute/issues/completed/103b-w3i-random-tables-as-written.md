# Issue 103b: Random Tables in war3map.w3i, Read as Written

**Phase:** 1 - File Format Parsing
**Type:** Implementation
**Priority:** Medium
**Dependencies:** None open
**Builds on (completed):** 103 (the parser `src/parsers/w3i.lua`), 911b (`w3i.write`)
**Related:** 103a (versions 28 and 31, open pull request; touches other parts of the same file), A03 (the test runner's 2026-11-06 note)

---

## Current Behavior

Found when the test runner began testing the project's own `assets/`
(A03, 2026-11-06): `test_new_map`'s first check, every test map's
`war3map.w3i` written back byte for byte, gives 18 of 19. Conquest-v8-fix
(added 2026-11-02) is the one that differs, from its random item tables on.

The reader and the writer disagree about the random tables:

- **Item tables:** the reader took each item as its ID, then its chance;
  `w3i.write` (911b) writes the chance, then the ID, which is what the file
  has (its first item reads "chance 3, I00C"; read the other way it is
  "ID `\3\0\0\0`, chance 1127231561"). Written back, each item's two halves
  traded places.
- **Unit tables:** the reader took each position as a type, a count and
  that many ID and chance pairs; `w3i.write` writes the positions' types,
  then rows of a chance and one ID per position. No test map has a unit
  table, so no round trip showed it.

The DAoW maps have no random item tables, and the other new maps none
either.

## Intended Behavior

`w3i.parse` reads both kinds of table as `w3i.write` writes them, into the
same tables the writer takes (`positions[j] = { type, units = { { id,
chance }, ... } }`, every position sharing its row's chance; `sets[j].items
= { { id, chance }, ... }`), so every test map's info file writes back
byte for byte.

## Acceptance Criteria

- [x] Conquest-v8-fix's ten random item tables read with IDs such as I00C and chances that are percentages
- [x] All 19 test maps' `war3map.w3i` write back byte for byte (`test_new_map`'s first check)
- [x] A unit table and an item table built in a test are written in the files' layout, read back and written again the same
- [x] `docs/formats/w3i-map-info.md` describes both tables as written

## Implementation Notes

**Date:** 2026-11-06 (Claude, in the background; the owner reviews the draft pull request)

- `src/parsers/w3i.lua`: `parse_random_unit_tables` and
  `parse_random_item_tables` follow `w3i.write`. Nothing else reads these
  tables yet.
- `src/tests/test_w3i_random_tables.lua` (+ `.info.md`, 10 checks): in a
  file of its own, so it doesn't touch `test_w3i.lua`, which 103a's open
  pull request changes. Against the reader before this issue it stops
  with a read past the end.
- `docs/formats/w3i-map-info.md`: the unit table's positions and rows, and
  an item's chance before its ID.

### Decisions (2026-11-06)

- **The writer was right, the reader wrong.** For item tables the file
  itself shows it (the IDs land on four printable characters only when
  the chance comes first). For unit tables no test map has one; the
  layout the writer already used is the one the format descriptions the
  103 issue cites give, so the reader follows it. If a map with a unit
  table turns up that reads otherwise, the test built here is the place
  to change.

### Still open

- The DAoW maps' info files end in 1 or 4 bytes the reader keeps as
  `tail_raw` without naming them (the sections it detects there are
  partial); they write back as read, so nothing fails. Not part of this
  issue.

### Note (2026-11-06)

"Still open" is taken up in 103c: the 4 bytes are the random item tables'
count of 0, missed by an off-by-one; the 1 byte is a lone 0xFF in place of
all four sections, kept as it is.

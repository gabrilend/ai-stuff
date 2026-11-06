# Issue 201e: A Doodad's Drops Come Before Its Creation Number

**Phase:** 2 - Data Model
**Type:** Implementation
**Priority:** High
**Dependencies:** None open
**Builds on (completed):** 201 (the parser `src/parsers/doo.lua`), 911a (writing doodads back)
**Related:** 202f (the same kind of misreading in `war3mapUnits.doo`), A03 (the test runner's 2026-11-06 note)

---

## Current Behavior

Found while fixing 202f: once Conquest-v8-fix's units file read,
`test_map_save`'s next check failed, "doodads (war3map.doo): 18 of 19".
Conquest-v8-fix's `war3map.doo` doesn't write back byte for byte.

The parser read a version 8 doodad as a fixed 50 bytes: life, then the
creation number, then an item table pointer and an item set count. The
files have, after life, the item table pointer, the item sets (a count,
and each set's items), and the creation number last. So on every version
8 map:

- `creation_number` held the item table pointer (-1 on every doodad of
  every test map), `item_table_pointer` the set count, and
  `item_sets_count` the creation number. `DoodadTable.by_creation_number`
  kept one doodad (under -1), and `Doodad:has_item_drops()`, which looks at
  `item_table_pointer >= 0`, said yes for every doodad.
- A doodad that drops items (9 in Conquest-v8-fix) is longer than 50
  bytes; every doodad after it was read out of step, and their floats,
  read from the wrong bytes, didn't write back as read.
- The editor's new doodads were written with the creation number where
  the table pointer goes and -1 as their set count.

## Intended Behavior

- Version 8 entries are read in the files' order, item sets included
  (`item_sets = { { items = { { id, chance }, ... } }, ... }`, with
  `item_sets_count` their number, as before), and written back the same
  way.
- An item list that runs past the end of the data, or a count that can't
  fit, gives nil and a message naming the doodad.

## Acceptance Criteria

- [x] Every test map's `war3map.doo` (19, versions 7 and 8) parses and writes back byte for byte
- [x] On every test map the creation numbers are each their own and none is negative, and what follows the last doodad is exactly the special doodads section (8 bytes and 16 per special doodad)
- [x] Conquest-v8-fix's 9 doodads that drop items read with their sets
- [x] `test_doo` checks the above on the real maps (and fails when a map does) and reads and writes version 8 doodads with drops
- [x] `test_gameobjects`, `test_208b_gameobject_creation`, `test_editor`, `test_mapfile`, `test_data`, `test_editor_integration` pass as before

## Implementation Notes

**Date:** 2026-11-06 (Claude, in the background; the owner reviews the draft pull request)

- How the layout was settled: by the files. Read as before, every
  doodad's "creation number" on every version 8 map was -1 and its "item
  set count" counted up 0, 1, 2, ... (or held numbers in the thousands);
  read in the order above, the creation numbers are distinct and
  non-negative on all 19 maps (262,890 doodads), and each map's last
  doodad ends exactly where its special doodads section begins (that
  section's length checks out on every map). This is also the order the
  published descriptions give.
- `src/parsers/doo.lua`: `parse_doodad_entry` reads the drops, then the
  creation number, and returns nil and a message for a list that can't
  fit; `doo.parse` passes the message on with the doodad's number;
  `doo.write` writes the pointer, the sets and the creation number in that
  order.
- `src/tests/test_doo.lua`: `build_doodad_entry` takes the version and
  writes the drops in version 8; a new test reads and writes version 8
  doodads with and without drops and a cut item list; the real-map test
  checks creation numbers, the special section's length and the round
  trip per map, and now fails the run when a map fails (it used to print
  "PARTIAL" and pass).

### Decisions (2026-11-06)

- **The field names keep their meaning.** `creation_number`,
  `item_table_pointer` and `item_sets_count` now hold what their names
  say; code that read them (`gameobjects/doodad.lua`, the editor) needs no
  change and now gets the right values.
- **The real-map test fails when a map fails.** It counted failures and
  then passed whatever the count; a check that can't fail checks nothing.

### Still open

- The parser reads a version 7 file's special doodads section as item
  drops; on every test map, version 7 included, that section has the
  16-byte entries the version 8 reading uses (all version 7 test maps
  have none, so nothing reads wrong today). Left as it is: no test map
  shows a version 7 section with entries, and `test_doo`'s synthetic
  special-doodad test encodes the item-drop reading.
- `test_map_save` passes only with 202f as well (on this branch alone it
  stops at Conquest-v8-fix's units file).

### Note (2026-11-06)

The first point under "Still open" is taken up in 201f: the special
doodads section is read the same way in versions 7 and 8.

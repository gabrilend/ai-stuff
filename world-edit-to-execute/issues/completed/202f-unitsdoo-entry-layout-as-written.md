# Issue 202f: Read Unit Entries in the Order the Editor Writes Them

**Phase:** 2 - Data Model
**Type:** Implementation
**Priority:** High
**Dependencies:** None open
**Builds on (completed):** 202a-202e (the parser `src/parsers/unitsdoo.lua`), 911a (writing units back)
**Related:** A03 (the test runner's 2026-11-06 note lists the failures this fixes), A06 (parser coverage)

---

## Current Behavior

Found when the test runner began testing the project's own `assets/`
(A03, 2026-11-06): `war3mapUnits.doo` of Conquest-v8-fix (12 units) and
Master-Crafters-Final-Conquest (330 units), two of the maps added on
2026-11-02, make `unitsdoo.parse` read past the end of the data and stop
with a Lua error (`attempt to perform arithmetic on local 'b4'`), which
stops `test_unitsdoo`, `test_map_save` and `test_phase2_integration`.

The cause is the parser's idea of an entry, not the maps. After hp and mp
it read: item drops, abilities, a hero section only for type IDs with a
capital first letter, a random section (flag 1 = "YYU" and a level
character, flag 2 = group and position), waygate, creation number. The
files have, for every entry: item drops; **gold and target acquisition**;
the **hero section for every unit** (level, the three stat bonuses, the
inventory), **before** the abilities; a random section whose flag 0 still
carries four bytes, whose flag 1 is the group and flag 2 a table of its
own; a **custom color**; waygate; creation number. Version 7 (Reign of
Chaos) files have no item table pointer and no stat bonuses.

The DAoW maps never showed it: each holds at most one unit, a start
location, and whatever was misread went into `tail_raw`, which the writer
put back, so the round trip still matched.

## Intended Behavior

- Each entry is read in the order above, for versions 7 and 8; on every
  test map the entries take every byte of the file.
- New fields: `gold`, `target_acquisition`, `custom_color`, and
  `inventory` for every unit (`hero_data`, with its own `inventory`, stays
  for heroes only, as before).
- `random_unit`: `nil` for an entry that isn't random; otherwise
  `{ flag = 0, type, level, item_class }` for a random unit, building or
  item (type IDs `uDNR`, `bDNR`, `iDNR`, and the older `YYU`/`YYI`),
  `{ flag = 1, group_index, position }`, or `{ flag = 2, choices }`.
- A damaged file fails with `nil` and a message naming the unit and the
  place ("war3mapUnits.doo: unit 5/330: player runs past the end of the
  data (byte 497 of 500)"), not a Lua error: every read is checked, a
  count that can't fit what is left is refused, and so is an unknown
  random flag (its length can't be known).

## Suggested Implementation Steps

1. `unitsdoo.lua`: a checked reader; the entry parts in the files' order.
2. `test_unitsdoo.lua`: build its entries in that order, and add a
   non-hero's inventory, a version 7 file, damaged files, and, on the real
   maps, that the entries take every byte.
3. `docs/formats/unitsdoo.md`: the layout as the files have it.

## Acceptance Criteria

- [x] Conquest-v8-fix (12) and Master-Crafters-Final-Conquest (330) parse, every byte read, and write back byte for byte
- [x] Every map's units file that parsed before parses, every byte read, and writes back byte for byte (the five DAoW maps with one)
- [x] A cut file, an impossible count and an unknown random flag give nil and a message
- [x] `test_unitsdoo`, `test_phase2_integration` pass; `test_map_save`'s units round trip passes
- [x] `docs/formats/unitsdoo.md` describes the layout the files have

## Implementation Notes

**Date:** 2026-11-06 (Claude, in the background; the owner reviews the draft pull request)

- How the layout was settled: by reading the files byte by byte. Conquest's
  first start location is 111 bytes (version 8) and Daow4.4's 95 (version
  7); the layout above accounts for each byte, and read as a whole it ends
  exactly at the end of all seven units files in `assets/` (347 units: 3
  heroes, 13 units with items in their inventory, 5 drop sets, gold 12500
  and acquisition -1 on every placed unit, plausible hp/mp and slot
  numbers). The layout matches the published descriptions the 202 issue
  cites (WC3MapSpecification); the 202 issue's own sketch had left out
  gold, target acquisition and custom color, and made the hero section
  heroes' only.
- `src/parsers/unitsdoo.lua`: a `Reader` (each read checked against the
  data's end; errors carry a message, which `parse` turns into nil and the
  message with the unit's number). `read_byte` and `read_id` went; the
  `Reader` does their work. `unitsdoo.write` is unchanged: it writes each
  entry's bytes as read with the first 41 and the last 4 written over, and
  those places are the same in the right layout.
- `format` names the random flags as the files use them.
- `src/tests/test_unitsdoo.lua` (174 checks): its entries were written by
  hand in the old order. They are now built by `make_entry`, one function
  that writes the layout above; every assertion the old tests made is kept,
  with the random test's flags renumbered to what the files use (flag 0 on
  `uDNR` and `iDNR`; flag 1 for the group; flag 2, new, for a table of its
  own). New: a non-hero's inventory, a version 7 file, three damaged
  files, and on the real maps that nothing is left after the last unit.

### Decisions (2026-11-06)

- **The test data changes, and why.** The old synthetic entries encoded
  the old misreading; with the parser reading the files right they no
  longer describe a real file, so they are rebuilt in the files' layout.
  No check was dropped: each old assertion is still made, against an entry
  that a real file could hold. The real-map check is stronger than before
  (every byte read).
- **`hero_data` stays heroes' only.** Every entry has the hero section,
  but code and tests (`gameobjects/unit.lua`, "non-hero has nil
  hero_data") take `hero_data` as "this is a hero"; a non-hero's items are
  in `unit.inventory`, which every unit has.
- **Reforged skin IDs are not read.** No test map has them, and telling
  them apart needs the game version from `war3map.w3i`; left for when a
  map needs it.

### Still open

- `test_map_save` still fails on this branch alone: with the units file
  read, its next check, Conquest-v8-fix's `war3map.doo` written back, fails
  for a like reason in the doodad reader (fixed separately, issue 201e).

# Issue 103c: What Follows the Forces in war3map.w3i

**Phase:** 1 - File Format Parsing
**Type:** Implementation
**Priority:** Low
**Dependencies:** 103b (open pull request; this branch is cut from it)
**Builds on (completed):** 103 (the parser `src/parsers/w3i.lua`), 911b (`w3i.write` and `tail_raw`)
**Related:** 103b's "Still open"; 103a (versions 28 and 31, open pull request; touches other lines of the same function)

---

## Current Behavior

103b left this open: the DAoW maps' info files end in 1 or 4 bytes the
reader keeps as `tail_raw` without naming them. They write back as read,
so nothing fails. Read against the files, the two lengths are two
different things:

- **4 bytes (Daow4.4, Daow4.7.3, the three HvA maps, and
  Master-Crafters-Final-Conquest):** all `00 00 00 00`, standing where the
  random item tables' count goes, after counts of 0 for upgrades, tech and
  random unit tables. The reader looks for each of the four sections only
  when `pos + 4 <= #data`, that is, when at least 5 bytes are left, so a
  count of 0 that is the file's last 4 bytes was never read. An
  off-by-one: these maps have all four sections, the last one empty.
- **1 byte (11 DAoW maps and War-in-the-Plaguelands-[24]-B6a):** a lone
  `FF` straight after the last force's name. None of the four sections is
  there; one byte can't be a count. Players and forces read cleanly up
  to it on every one of these maps, so it isn't a misread earlier in the
  file. The files don't say what put it there: maps saved by the same
  editor version (6052) have the full sections in one case and the lone
  byte in another.

## Intended Behavior

- A section is read when its 4-byte count fits (`pos + 3 <= #data`).
- The lone `FF` stays in `tail_raw`, written back as read; the parser's
  comment and the test name it.

## Acceptance Criteria

- [x] The six maps that end in four zero bytes read all four sections, with nothing left over
- [x] Every test map's `war3map.w3i` is either all four sections with nothing after, or a lone `FF` in their place, and writes back byte for byte
- [x] `test_w3i_random_tables` checks both, on every test map, and Master-Crafters' final count of 0
- [x] `test_w3i`, `test_new_map` pass as before

## Implementation Notes

**Date:** 2026-11-06 (Claude, in the background; the owner reviews the draft pull request)

- `src/parsers/w3i.lua`: the four section checks use `has_count(pos)`
  (`pos + 3 <= #data`); the comment on `tail_raw` says what the test maps
  hold there.
- `src/tests/test_w3i_random_tables.lua`: a section over every test map
  (19: 7 with the four sections, 12 with the lone byte) and
  Master-Crafters' last four bytes. Against the old reader, both new
  checks fail (six maps with 4 bytes after the sections read).
- `docs/formats/w3i-map-info.md`: a note on the end of the file.

### Decisions (2026-11-06)

- **The 4 bytes are a section, not a tail.** The files settle it: on all
  six maps they are a count of 0 in the place the random item tables'
  count goes, after the other three counts; the reader missed them by
  one byte. With the fix `w3i.write` writes the same bytes from
  `sections.random_items` instead of `tail_raw`.
- **The lone `FF` is kept, not named as a field.** Nothing in the files
  says what it means, so a field name would be a guess. It stays in
  `tail_raw` so the file writes back as read, and the test requires it to
  be exactly that one byte with no sections, so anything else after the
  forces shows up as a failure rather than more unnamed bytes.
- **The test goes in `test_w3i_random_tables.lua`,** not `test_w3i.lua`,
  for the reason 103b gives: #248 (103a) changes `test_w3i.lua`.

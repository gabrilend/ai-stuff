# Issue 103a: Read war3map.w3i versions 28 and 31, and the later flags

**Phase:** 1 - Foundation (follow-up to 103)
**Type:** Bug fix
**Priority:** Medium
**Dependencies:** 103-parse-war3map-w3i (completed)

---

## Current Behavior

`src/parsers/w3i.lua` accepts versions 28 and 31 (the 1.31 and 1.32
editors) but reads them as version 25:

- It never skips the four game-version ints that follow the editor
  version, so every later field of such a map is read 16 bytes off.
- It doesn't read the script-language int after the water tint (28 on),
  or the supported-modes and game-data-version ints after it (31 on).
- It doesn't read a player's two enemy-priority words (31 on).
- Its flags table stops at 0x1000.

None of the maps in `assets/` is past version 25, so no test met it. The
W client's own reader (custom-client 083, PR 15) reads these fields and
found the gap; its issue 1109 lists this as a follow-up for this project.

## Code review findings to fix

The code review of 2026-11-05 read the unmerged pull request #248 that build this issue. The issue text above is brought over from the branch; the code is still on the branch. Each point below is to be fixed (or answered) before the code merges and this issue is called complete. "Confirmed" means the review reproduced it by running the branch's code; the rest come from reading it. The review's overall summary is in the message of the "code review results" commit.

- Version checks are open-ended, so any unlisted version (26, 27, 29, 30, 32, 33) is read with a guessed layout; the only sign is a field nothing reads.
- Writing as 28 or 31 without the new fields silently writes zeros (game version 0.0.0.0, supported modes 0).
- The round-trip test only checks the writer against the reader, which share the same guesses; no real 28/31 file is compared byte for byte.
- `local m = base` aliases instead of copying, so each pass starts from the previous pass's edits.
- The new test extracts the map outside the protected helper and drops the open error.
- The format spec (`docs/formats/w3i-map-info.md`) and the writer's header weren't updated.
- The layout is written twice by hand (reader and writer); the fold marker is a sentence; this issue lacks a suggested-steps section and its Current Behavior describes the code before the fix.

## Intended Behavior

Versions 28 and 31 read every field at the right place, and write back
byte for byte as 25 does (911b). The later flags have names.

## Implementation Notes (2026-11-05)

- `w3i.parse` reads `game_version` (4 ints, 28 on), `script_language`
  (28 on), `supported_modes` and `game_data_version` (31 on), and each
  player's `enemy_low` / `enemy_high` (31 on). `w3i.write` writes them
  back for the same versions.
- Flags added: `USE_TERRAIN_FOG` 0x2000, `REQUIRES_EXPANSION` 0x4000,
  `ITEM_CLASSIFICATION` 0x8000, `USE_WATER_TINT` 0x10000,
  `ACCURATE_RANDOM` 0x20000, `CUSTOM_ABILITY_SKINS` 0x40000, as the later
  editors name them.
- `test_w3i.lua` takes the project folder as its first argument (as the
  other tests do) and adds a section that writes the test map's info back
  as versions 28 and 31, reads it again and checks every field, and checks
  the two flags the W client reads.

Decisions (for the owner to overturn):

1. **The fog colour's bytes are left as they were.** The W client reads
   them red first, and this reader takes red from the third byte (blue
   first). The repos don't settle which is right (1109's open question
   13); one look at War in the Plaguelands in WC3 does: blue haze and
   cyan water if red first, orange and yellow if blue first. Changing one
   reader before that look would only move the guess.
2. **Fog style 0 keeps its meaning here.** The W client reads style 0 as
   linear fog shown when flag 0x2000 is set (its decision 76); this
   reader's callers don't draw fog, so nothing here depends on it yet.

Checked: `luajit src/tests/test_w3i.lua <project>` all pass (19 of 19
maps parse); `test_new_map.lua` 22 of 23, the same failure as on main
(one test map that doesn't open).

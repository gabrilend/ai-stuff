# Issue W02i: A Converted Map's Own Light

**Phase:** W - WoW Client Bridge
**Type:** Sub-issue of W02 (written by hand, as W02a-W02f were)
**Priority:** Medium (converted maps lit by another map's light, or the W client's fixed grey day)
**Dependencies:** W02c (the tables, the id scheme, the output forms); the W client's light read through its tables (custom-client #26, branch `claude/light-tables`: 026 on 074, 1109 step 1t)
**Blocks:** nothing; a converted map looks right in the W client and the stock client

---

## Current Behavior

*As written (2026-11-05, before this issue's work):*
- A converted map has no row in Light.dbc. Both clients then fall back to Light's row 1 (a light made for Eastern Kingdoms). With no install, the W client falls back to its fixed grey day.
- The W client lays a test map's own war3map.w3i fog over that light, but its sky, sun, shade and water stay the fallback's.
- The W client's headless run says `light = -1` (the grey day) on a converted build.

*Now:* see Implementation Notes.

## Code review findings to fix

The code review of 2026-11-05 read the unmerged pull request #260 that build this issue. The issue text above is brought over from the branch; the code is still on the branch. Each point below is to be fixed (or answered) before the code merges and this issue is called complete. "Confirmed" means the review reproduced it by running the branch's code; the rest come from reading it. The review's overall summary is in the message of the "code review results" commit.

- If the W client's lighting code fails to compile or load, every client check becomes a skip with the wrong reason ("no $W_CLIENT_SRC") and the test exits 0; `W and w_table(...)` likewise turns a broken Light.dbc into a skip.
- Four unchecked layouts join the stock merge, which raises on any width mismatch, so a wrong guess about LightParams' width now stops every conversion; a stock folder missing only some light tables gives a patch with half the light.
- The band-id rule is written in three places (row writer, registration scheme, test) that can drift.
- This deliberately breaks custom-client's own headless check (light now 20000 where it expects < 0) with nothing making the two land together.
- The light module reads the colour bytes itself because the shared `w3i` parser names them in reverse order; fix the parser instead.
- The fog rule skips the client's guard for a scale not above 0, so a scale of 0 fogs the whole world here while the client draws none.
- The test builds in `/tmp` rather than the project's RAM folders, and re-implements helpers from `test_wow_registration.lua` (now four copies of the reader loader).

## Intended Behavior

- **Its own default light.** Every converted map carries one, in the four light tables (Light, LightParams, LightIntBand, LightFloatBand). They are written in every form W02c writes tables in: the overlay, and the merged tables in `patch-W.MPQ`.
- **Fog and water from the map.** Where the map's war3map.w3i has fog and a water tint, the light uses them.
- **Checked through the W client's light.** The W client's 026 reads the light through its 074 tables. Its headless run reports the light and the fog.

## Suggested Implementation Steps

1. `src/wowbuild/light.lua` (new): the map's fog and tint from its war3map.w3i; the default light, its two parameter sets and their bands.
2. `src/wowbuild/dbc.lua`: the four layouts, in the tables written.
3. `src/wowbuild/registration.lua`: the light's ids in the scheme; the light's rows with the map's other rows. `src/wowbuild/init.lua`: the report says what the light used.
4. Tests, from the project root: `test_wow_light.lua` (new).

## Acceptance Criteria

- [x] A converted map's build holds the four light tables with its rows, read back by the W client's table reader.
- [x] With the fog flag set, the light's fog is the map's (the W client's own rule, distances and colour). Without it, the palette's.
- [x] The water tint colours the light's water, and its alpha sets the shallow water's opacity.
- [x] Ids follow W02c's scheme a slot. Merged stock rows inside the block are replaced and said.
- [x] The W client's light (026 through 074) lights the converted map by its own default. Its headless run reports it (`light` 20000, not -1).
- [ ] The stock client shows the map lit by its own light, from `patch-W.MPQ`, on the owner's machine.

## Open Questions (each answered 2026-11-05, as decisions below; the owner's to overturn)

1. How many lights, and which parameter sets?
2. Which ids?
3. When is the map's fog used, and how is it read?
4. What colour is the fog through the day, and the sky?
5. What does a map without fog get?
6. What does the water tint do?
7. Which forms carry the tables?
8. What is from memory?

## Decisions (2026-11-05; each the owner's to overturn)

1. **One default light, two parameter sets.**
   - The light stands at 0, 0, 0 with no radius: the map's default, used wherever no other light reaches (the W client's 026-light.h).
   - Its sets are clear and under water. Storm, storm under water and the ghost world reuse those two (sets 3, 4 and 5 of the five the W client reads).
   - No skybox: LightSkybox is left alone.
2. **W02c's scheme, extended.**
   - Light: 20000 + slot. LightParams: 20000 + 4 x slot, four a slot (two used).
   - The band rows' numbers follow from a set's, as the clients look them up: LightIntBand set x 18 - 17 + band, LightFloatBand set x 6 - 5 + band. Their blocks are therefore 359983 + 72 x slot and 119995 + 24 x slot.
   - The stock tables' highest ids are a few thousand (from memory, unchecked). A merge replaces any stock row inside these blocks and says so, as W02c's do.
3. **The W client's rule, read the W client's way.**
   - The fog is used when the file has its environment (version 25 and later) and the editor's "use terrain fog" flag (0x2000) is set. That is the rule of the W client's 084-map-fog.h.
   - Its start and end are distances from the eye in WC3 units, times the map's yards per unit (1/30.72). The start is no closer than 0, the end no closer than the start. The style and density aren't used (drawn linear, as the W client does).
   - **Colour bytes:** the colour is the file's first three bytes in order (red, green, blue), as the W client's 083-w3i.c reads them.
     - `parsers.w3i` names those bytes the other way round: its `fog.color_r` is the third byte. Nothing in the converter used those names before, and they are not changed here.
     - Which order Warcraft III means is unchecked against a WC3 source. This follows the W client, so both clients and the overlay agree.
4. **The fog's colour all day; the horizon meets it by day; the palette's sky.**
   - The fog colour is the map's at every hour. WC3 keeps one fog colour, and the W client's test-map fog is constant.
   - The horizon band takes the fog's colour at 6:00, noon and 18:00, and the palette's at midnight. The sky meets the fog by day without a bright horizon at night.
   - WC3 keeps no sky colour in war3map.w3i, so the sky is the palette's.
   - **Not used:** the map's light environment (a tileset letter for WC3's day-night models) and its weather.
   - **Under water:** the fog is 30 yards from the eye, in the river's deep colour.
5. **No fog of its own: the palette's.**
   - The fog ends at 600 yards and starts at a quarter of that, in the palette's colour through the day.
   - The palette (`light.PALETTE`) is four moments a band (midnight, 6:00, noon, 18:00), picked here to look like a clear day.
6. **The tint colours the near water, by day; its alpha is the shallow water's opacity.**
   - With the tint flag (0x10000), the ocean's and the river's near colour is the tint at noon, 0.7 of it at dawn and dusk, and 0.35 at night. The deep colour is 0.4 of the near.
   - The shallow water's opacity is the tint's alpha; deep water is opaque.
   - Without the tint, Ashenvale's opacities (0.5, 1, 0.75, 1; the W client's 026-light.h) and the palette's water.
7. **The client's tables, in the client's forms.**
   - The four tables go in the overlay (`DBFilesClient/`), and merged with the stock tables into `patch-W.MPQ` when the stock tables are given.
   - They are not in `server/dbc.sql` or `server/dbc/`. Whether AzerothCore reads any light table is unchecked, and nothing the server does needs this map's light.
8. **From memory, unchecked:**
   - the meanings of LightIntBand's bands 8-13 (written: the fog's colour, the sun, its halo, the clouds' glow, the clouds, 0);
   - LightFloatBand's bands 2-5 (written: 0.5, 0, 0, 0);
   - LightParams' fields 2, 4 and 5;
   - every value of the palette.

   The W client reads bands 0-7 and 14-17, float bands 0-1, and LightParams 3 and 6-9; those are checked through it.

## Implementation Notes

*(2026-11-05)*

- **`src/wowbuild/light.lua`** (new):
  - `from_w3i(info, yards_per_unit)`: the map's fog and tint, or why there's no fog;
  - `rows(info, ids)`: the four tables' rows, and what was used.
- **`src/wowbuild/dbc.lua`:** the four layouts, 15, 9, 34 and 34 fields wide, as the W client's 097 has them; their `seen` columns are the ones 026 reads. They are in `dbc.TABLES`, so every form writes them.
- **`src/wowbuild/registration.lua`:**
  - the scheme's `light`, `light_params`, `light_int_band` and `light_float_band` blocks, and their kinds for a merge;
  - `rows` adds the light's rows and returns what the light used as a second value.
- **`src/wowbuild/init.lua`:** the conversion report's `registration.light` says what the light used (`fog` "map" or "default", `why_no_fog`, `tint`, `fog_start`, `fog_end`, `light`, `sets`).
- **Tests:** `src/tests/test_wow_light.lua` (new).
  - Results: 48 with the reader library and `$W_CLIENT_SRC`; 38 and 2 skipped with the library alone; 34 and 5 skipped without either.
  - With `$W_CLIENT_SRC`, it compiles the W client's light from its sources with `src/tests/c/light_probe.c`. That probe does what the headless run does for the light: the build an overlay, 074's tables through it, 026's light, and 084's fog laid over.
  - Checked through it:
    - the default lights the map at noon, midnight, 3:00 and under water;
    - the map's fog, the sky, the water's colour and opacity;
    - a second map in the same build lit by its own default;
    - the first map keeping its fog after the root war3map.w3i becomes the second's;
    - a map with no light of its own getting the grey day.
- **The W client's headless run** (089 at custom-client 043420f, built here without a window from its window-free parts, with no install, the baseline set, and its test moves, on a made map with fog and tint):

  | | `light` | fog | sky overhead |
  |---|---|---|---|
  | Before | -1 (the grey day) | 32.6-130.2 yards, the map's (laid over) | 0.6, 0.6, 0.6 |
  | After | 20000 | 32.6-130.2 yards, the map's | 0.165, 0.392, 0.722 (the palette's noon) |

  `light_tables` is 1 in both runs, with 0 placeholder rows. Its log still says "Light.dbc has no row 1", which is harmless: the map has its own default.

**Still open:**
- the stock client on the owner's machine (decision 8's unchecked fields, the merged tables in `patch-W.MPQ`);
- whether AzerothCore reads Light.dbc;
- the map's light environment and weather;
- a palette a tileset;
- the W client's own test program, which on a build converted after this change will see a light where it now expects the grey day (its no-install headless check, `h->light < 0`). That is custom-client's to update.

# Issue W02a: Terrain to ADT Writer

**Phase:** W - WoW Client Bridge
**Type:** Sub-issue of W02
**Priority:** High (the editor's Test Map stops at W02's converter until it exists)
**Dependencies:** W01 (only to check the texture paths against the client; writing needs nothing from it)
**Blocks:** W02b, W02c

---

## Current Behavior

*As written (2026-11-04, before this issue's work):* a `.w3x` map's terrain
is parsed (`src/parsers/w3e.lua`: tile points with height, cliff level,
ground type, water, blight) and drawn in this project's own viewer
(`src/assets/ground.lua`), but nothing writes WoW's ground files. The
editor's Test Map (issue 913, draft PR #239) converts the edited map
through W02 before opening the W client, and with no converter it stops
there.

*Now:* see Implementation Notes. The terrain is written; the texture paths
and the files' behaviour in Noggit, the stock client and AzerothCore's
extractor wait for the owner's machine.

## Intended Behavior

One command turns a WC3 map's terrain into a WoW 3.3.5a map's ground,
written into a build folder:

- **One WDT** (which ADT tiles exist; 8-bit blend maps) and **one ADT per
  533-yard tile** the map covers: every chunk with its 145 heights, normals,
  up to four texture layers with 64 x 64 blend maps, and water (MH2O).
- **Scale and place** by the rule in `docs/wow-client-bridge.md`: one WC3
  tile = one WoW cell (4.1667 yd); WC3 tile points are the ADT's outer
  vertices one-to-one; the ground stands within 0.5 yd of the WC3 height
  field at sampled points (W02's acceptance).
- **The texture reduction rule** from `docs/datapath-wc3-map-into-wow-client.md`:
  a chunk keeps the four textures that cover most of it; each further one is
  folded into the nearest kept texture by colour. Every fold is counted and
  reported as a warning; strict mode stops on it.
- **A WC3-ground-type → WoW-texture-path table, kept as data per WC3
  tileset**, covering every stock tileset. Paths only: Blizzard's textures
  stay in the owner's client and are never copied.
- **A conversion report** counting texture folds and anything unmapped
  (W02's acceptance line 6, terrain part).
- **The converter's entry point** Test Map calls,
  `<convert...> <map.w3x> <build folder>` (issue 913, "The call into W02"),
  doing W02a's part now; W02's later sub-issues add theirs to the same
  command.

## Suggested Implementation Steps

1. Placement and scale in one module the later sub-issues share (W02b
   places doodads and units through it).
2. Heights, normals, layers and blend maps, water per chunk, from the
   parsed terrain; the reduction rule with its counts.
3. The bytes: ADT, WDT (and WDL, the far-off ground the W client also reads)
   through `parsers/binwrite.lua`.
4. The ground table as data, every stock tileset, each row marked
   unchecked against the owner's client.
5. The command and its report; its usage says which parts are built.
6. Tests: made grounds and the maps in `assets/` (the smallest DAoW map
   first), every written file read back through the W client's own ADT
   reader (`src/020-adt.c` in `libwreaders.so`) by LuaJIT's FFI.

## Acceptance Criteria

- [x] One command converts the smallest DAoW map's (`assets/DAoW-2.1.w3x`)
      terrain into a build folder: one WDT, one WDL, four ADTs
- [x] The W client's ADT reader reads every written ADT and the WDT; its
      ground matches the WC3 height field within 0.5 yd at sampled points
      (every outer vertex and every cell centre of every chunk sampled)
- [x] At most four layers a chunk; layer counts, texture paths, blend maps
      and water read back as written
- [x] Texture folds and unmapped ground types are counted in the conversion
      report; strict mode stops on a fold
- [x] The ground table is a data file per WC3 tileset, covering all 18 stock
      tilesets and their cliff textures; nothing proprietary is written or
      committed
- [ ] Every texture path in the table checked against the owner's client
      (W01's archive reader or a listfile); rows corrected and marked
      `checked = true`
- [ ] Noggit opens every written ADT without complaint, at the expected
      place (W02's acceptance, terrain part; needs the owner's machine)
- [ ] AzerothCore's map extractor reads the ADTs (checked in W02d)
- [ ] The character stands on the ground in the W client and in the stock
      client (needs W02c's map registration)

## Notes

- *Splitter.* W02 says its sub-issues are "to be confirmed through the
  issue-splitter's analyze → review → execute flow". The splitter
  (`scripts/issue-splitter.sh`) was **not run** for this file: it handles
  numbered issues only. Its default pattern is `[0-9]*.md`, and every step
  reads ids as digits (`is_subissue` and `extract_recommendations` match
  `^[0-9]+[a-z]`, `get_root_id` keeps the digits, `generate_subissue`
  computes the phase as `parent_id / 100`), so it can neither find W02 nor
  turn a `W02a` row of an analysis into a file. Its model (the `claude`
  CLI) was reachable here, so that was not the reason. This file was
  written by hand in the project's issue style from W02's table row. The
  splitter learning lettered phases (A, B, Q, W, X) would be a Phase 0
  issue of its own.

## Implementation Notes

*2026-11-04, background work the owner asked for (branch
`claude/wete-w02a-terrain-to-adt`). Each decision below is the owner's to
overturn.*

### What was built

| File | Does |
|------|------|
| `src/wowbuild/init.lua` | `wowbuild.convert(map, build, opts)`: the converter W02's later parts add to; writes the files and the report; `wowbuild.summary` |
| `src/wowbuild/coords.lua` | where a WC3 map lands: ADT tiles, WC3 → WoW world (`to_wow`, `to_wc3`), the scale constants |
| `src/wowbuild/terrain.lua` | per chunk: heights, normals, layers and blend maps (the reduction rule), water; counts for the report |
| `src/wowbuild/adt.lua` | the bytes: ADT, WDT, WDL |
| `src/wowbuild/ground_textures.lua` | the WC3 ground → WoW texture path table, data only, per tileset |
| `src/cli/wow-convert.lua` | the command: `luajit src/cli/wow-convert.lua [--strict] [--name N] [--textures F] <map.w3x> <build folder>` |
| `src/tests/test_wow_terrain.lua` | the tests (below) |

Build folder, as the W client reads a loose overlay (its 105a):
`<build>/World/Maps/<dir>/<dir>.wdt`, `<dir>.wdl`, `<dir>_<tx>_<ty>.adt`
(tx west to east, ty north to south) and `<build>/conversion-report.lua`.
For Test Map, the editor's settings name it as
`convert = { "luajit", "<project>/src/cli/wow-convert.lua" }`.

### Checked

`luajit src/tests/test_wow_terrain.lua <project>`: 161 checks pass with the
W client's reader loaded (DAoW-2.1, Conquest-v8-fix and the 257 x 193
War-in-the-Plaguelands map, plus made grounds); 305 with
`WOW_TERRAIN_ALL=1`, all 19 maps in `assets/` (220 ADT tiles); without the
reader library 70 pass and 14 are skipped. The W client's reader
(`libwreaders.so` built from custom-client `origin/main` 55108d3 with
`scripts/build`'s own cc line, into a scratch folder) read every written ADT,
WDT and WDL. Worst height difference from the WC3 field over every sampled
point of every map: 2.5e-6 yd (float rounding; the limit is 0.5). Chunk
positions, layer counts, texture paths, every blend map byte and every water
layer (cells, heights, depths) came back as written. **No disagreement
between this writer and 020-adt was found**, so neither side needed
changing. What 020-adt doesn't read (MHDR's offsets, MCIN, MCNR, the order
and sizes of each chunk's sub-blocks, which Noggit and AzerothCore's
extractor use) is checked by the test's own walk of the blocks.

DAoW-2.1: 2 x 2 ADT tiles from 31_31; chunks with 1/2/3/4 layers
227/274/291/232; 95 texture folds in 74 chunks; nothing unmapped; water in
636 chunks. Across all 19 maps: 23,715 folds, nothing unmapped (every ground
id the maps use has a row).

### Decisions

1. **Placement.** The map's ADT tiles are a block centred on the middle of
   the 64 x 64 grid (`tx0 = 32 - floor(tiles across / 2)`); the WC3 map's
   north-west tile point is the block's north-west corner. A one-tile map
   starts at world (0, 0). Cells of the written tiles beyond the WC3 grid
   take the nearest edge tile point (a flat skirt, not holes, so nothing
   looks into the void at the map's edge).
2. **Map directory name:** `WC3_` and the map file's name with everything
   but letters and digits as `_` (`WC3_DAoW_2_1`), at most 48 characters;
   `--name` overrides. W02c registers it in `Map.dbc`.
3. **Heights:** each tile point's ground height including cliff levels
   (`w3e.ground_z`: +128 units a level above 2), so a cliff is a step of
   4.17 yd across one cell. Inner vertices are their cell's corner average.
   A chunk's base height is its lowest vertex.
4. **Blend:** a texture's share at a blend-map point is the bilinear weight
   of its cell's corners painted with it (WC3's corner rule, smoothed over
   one cell). Layers are stacked in the map's own ground order, blight on
   top as WC3 draws it; each layer's value is its share over the shares of
   itself and the layers below, so stacking gives every texture exactly its
   share and none shows where none of its corners are.
5. **The reduction rule** as the datapath says: rank by coverage (ties: the
   map's order), keep four, fold each other into the kept one nearest by
   the table's `rgb` (the WC3 ground's colour). Each fold is listed with its
   tile and chunk (the first 200 one by one; all counted, and totalled by
   pair). Two WC3 types sharing a WoW path count as one texture.
6. **Blend maps 8-bit, uncompressed** (WDT `MPHD` flag 0x4, 4096 bytes a
   layer), as Northrend's maps are; MCNK flag 0x8000 set.
7. **MCNK blocks:** MCVT, MCNR (435 bytes and 13 of padding, counted in its
   size as Noggit writes it), MCLY, an empty MCRF, MCAL, an empty MCSE, an
   empty MCLQ (`sizeLiquid` 8, which AzerothCore's extractor reads as "no
   old-style water"); no shadow map, no colour tints, holes 0, area 0
   (W02c's AreaTable row fills it).
8. **Normals** stored as world x (north), y (west), z (up), times 127.
   *Unchecked:* no reader at hand reads MCNR (020-adt doesn't), and sources
   disagree on the order; if the stock client lights slopes wrongly, swap
   here.
9. **The low-quality texture map** (MCNK offset 64): per cell the layer
   covering most of it, 2 bits a cell, row by row, lowest bits first.
   *Unchecked* bit order; it only picks ground effects, and every layer's
   ground effect is 0.
10. **Water:** a cell is wet when any corner is wet (`w3e.is_wet`). One MH2O
    layer a chunk over the rectangle of its wet cells, with a which-cells
    map when the rectangle isn't full; LiquidType 1 (water), vertex format
    0; a vertex without the water flag takes the mean surface of the
    chunk's flagged ones; depth is yards times 9, the scale 020-adt measured
    on the original's lakes. Fishable mask = the wet cells; deep mask 0.
11. **A WDL is written too** (not in W02's table): the far-off ground the W
    client reads (`adt_wdl_read`), cheap to make from the same heights.
12. **The build folder** is the converter's (issue 913): a run empties only
    its own map's folder under `World/Maps/` before writing.
13. **The report** is `conversion-report.lua` (data, loadable in an empty
    environment): files written, placement, layer counts, folds, unmapped
    ids with their tile-point counts, water, textures used and how many are
    unchecked, and the W02 stages not built yet. `warnings` = folds +
    unmapped ids. A summary goes to stdout, which Test Map keeps as
    `convert.log`.
14. **No `server-stamp` yet.** The server reads AzerothCore's extracted
    data, not ADTs (the datapath's correction), so the stamp belongs to
    W02d; until then Test Map checksums the whole build, as 913 allows.
15. **Exit codes** 0 built, 1 conversion failed (reason on stderr), 2 bad
    options, the W client's own convention.
16. **The ground table's paths** were written from memory of the 3.3.5a
    archives, one WoW zone per WC3 tileset by look (Lordaeron Summer →
    Elwynn, Barrens → Barrens, Ashenvale → Ashenvale, Felwood → Felwood,
    Lordaeron Fall → Tirisfal, Lordaeron Winter → Dun Morogh, Northrend →
    Dragonblight, Cityscape → Stormwind, Village → Westfall, Village Fall →
    Duskwood, Dalaran → Dalaran, Dalaran Ruins → Alterac, Dungeon →
    Burning Steppes, Underground → Badlands, Sunken Ruins → Azshara,
    Icecrown → Icecrown, Outland → Hellfire, Black Citadel → Shadowmoon).
    **Every row is `checked = false`**; many file names are guesses. A
    missing path shows as the W client's placeholder picture, not a crash.
17. **The placement in the report, for Test Map's camera** (2026-11-04,
    issue 913's camera pass, branch `claude/wete-test-map-camera`). The
    report's `placement.client` is the placement as plain numbers:
    `client x = x0 + scale * wc3 y`, `client y = y0 - scale * wc3 x`
    (yards, x north and y west), and the map's tile-point bounds
    (`Layout:client_placement`). The editor turns its view's point into
    the W client's `--camera` with it (`coords.wc3_to_client`), so the
    camera starts where the editor was looking. The convention was checked
    against the W client's own code (its 018-maps.h, 033-ground-prep.c,
    020-adt.h; and, built from its sources, its `maps_tile_of`,
    `maps_corner_position` and ADT reader). `coords.client_adt` is the
    client's rule for which ADT a world point is in, for W02b and the
    tests. The report's numbers are now written in the shortest form that
    reads back exactly (six digits cut the placement by up to a tenth of a
    yard).

### Left open

1. **Check every texture path** against the owner's client (W01's archive
   reader can test all rows at once) and correct the misses.
2. **Noggit, the stock client and AzerothCore's extractor** on the owner's
   machine: open the DAoW-2.1 build in Noggit (W02's acceptance line 2);
   the stock client and the extractor wait for W02c and W02d.
3. **Which textures the W client paints with.** The W client plans to paint
   WC3's own tilesets and WoW's layers on one mesh (its docs/009, answer 1;
   its 302a reads `war3map.w3e` in C). If it paints a converted map with
   WC3's tilesets from the player's WC3 install, the build should carry
   the map's `war3map.w3e` (or a WC3-path column in this table) beside the
   ADTs, and the WoW paths serve only the stock client. Asked here, not
   decided.
4. **Liquid kinds:** all WC3 water is written as WoW water. Deep water as
   ocean, and tilesets whose water WC3 draws as lava or slime, are not told
   apart yet.
5. **Cliff models:** the height field steps at cliffs; placing a cliff model
   along each edge (the datapath's "optionally") belongs with W02b's
   placements.
6. **Map ids and world placement** (W02's open question 3) are W02c's.

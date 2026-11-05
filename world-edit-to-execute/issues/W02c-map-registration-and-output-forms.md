# Issue W02c: Map Registration and Output Forms

**Phase:** W - WoW Client Bridge
**Type:** Sub-issue of W02
**Priority:** High (without a map id, its rows and a way into the client, a converted map can't be opened anywhere)
**Dependencies:** W01 (the client's tables and archives, for checking), W02a (the ground files), W02b (the displays, factions and spawns this registers)
**Blocks:** W02d (its extractors read `patch-W.MPQ`), W02f (the launcher installs it; the loader teleports to the map id), W02e (scripts name the map, its creatures and factions by number)

---

## Current Behavior

*As written (2026-11-04, before this issue's work):* W02a and W02b's
converter (`src/wowbuild/`, `src/cli/wow-convert.lua`) writes a map's
ground (WDT, WDL, ADTs with doodads), its units as `server/world.sql` and a
placement list. Nothing tells the client or the server that the map
exists. There is no map id, zone, loading screen, creature display row or
faction row, and no `patch-W.MPQ`. The SQL uses placeholder ids:
`@MAP` 9000, `@ENTRY` and `@GUID` 9100000, displays from 50000, faction
templates from 3000. Each block is 100,000 wide.

*Now:* see Implementation Notes. Every row is written in each form that
reads it. None of the column layouts are confirmed against a source. The
stock client, the server and the extractors wait for the owner's machine.
The W client needs the changes listed under "The W client's side".

## Intended Behavior

The same one command also writes:

- **The map's rows in the client's tables.**
  - `Map.dbc`: the id and the folder under `World\Maps\`.
  - `AreaTable.dbc`: one zone, which every ADT chunk names.
  - `LoadingScreens.dbc`: a picture made from the map itself.
  - `CreatureDisplayInfo.dbc` and `CreatureModelData.dbc`: W02b's display ids.
  - `FactionTemplate.dbc` and `Faction.dbc`: W02b's factions, hostile as the WC3 forces are.
- **The same rows for the server.** AzerothCore reads its DBC files and
  overrides rows from the world database's `<table>_dbc` copies.
- **Two forms.**
  - **A loose overlay folder**, which the W client reads.
  - **`patch-W.MPQ`**, for the stock client and for W02d's extractors,
    which read archives.
- **W02c's own id scheme** in place of W02b's placeholders, recorded as a
  decision.
- **Output shaped to how the W client opens a map.** That is custom-client
  issue 1109 (its `--test-map` folder) and its 018-maps, 043-main and
  067-test-map. Where the client must change, the change is described
  here, not made.

## Suggested Implementation Steps

1. Write the table layouts for 3.3.5a (build 12340) as data, and a writer.
   Merge a stock table: keep its rows and drop any row inside our blocks.
2. Settle the id scheme and the slot a map takes in a build folder, and
   record the rows and slot in the map's folder.
3. Build the rows: map, zone, loading screen, displays and models,
   factions with their hostility.
4. Make the loading screen picture.
5. Write the forms: the overlay's tables, the server's SQL and merged
   DBCs, `patch-W.MPQ` (StormLib), and the files the W client's test-map
   run reads (`map.lua`, `world/creatures-<id>.tsv`).
6. Tests: a made map, several maps in one folder, and the maps in
   `assets/`. Read everything back through the W client's own readers
   (LuaJIT FFI) and through StormLib.

## Acceptance Criteria

- [x] One command writes the map's rows in the client's tables, the
      server's copies and `patch-W.MPQ` (`assets/DAoW-2.1.w3x`:
      map 900, zone 9000, 7 factions, a loading screen from its preview)
- [x] The W client's own DBC reader reads every table as written, column
      by column; the map's id finds its folder and the folder holds its WDT
- [x] Every ADT chunk names the map's zone
- [x] Merged over stock tables, the stock rows are kept and any stock row
      inside W02c's blocks is reported and replaced; a table of another
      width is refused
- [x] `patch-W.MPQ` lists its files (StormLib's listfile) and the W
      client's archive reader reads each one byte for byte
- [x] Several maps in one build folder: each keeps its slot, its own
      blocks and its own AreaBit; the tables hold all of them
- [x] The W client's creature list reader (035) reads
      `world/creatures-<id>.tsv`: every spawn in its tile, at its place
- [x] Nothing of Blizzard's is written into this project. Stock tables are
      read from the player's folder at build time and land only in the
      build folder.
- [ ] Every layout checked against a source: AzerothCore's `DBCfmt.h`
      and `DBCStructure.h`, or the owner's own stock tables. Then mark
      `checked = true`.
- [ ] The stock client opens the map from `patch-W.MPQ` and shows its
      loading screen. If it doesn't show encoding 3, write DXT.
- [ ] `server/dbc.sql` (or `server/dbc/`) runs on the owner's AzerothCore
      and `.go xyz 0 0 0 900` reaches the map. Its ground needs W02d.
- [ ] The W client opens it in a test-map run. That needs the changes
      under "The W client's side", made in custom-client.

## Notes

- *Splitter.* Written by hand from W02's table row in the project's issue
  style, as W02a and W02b were. The issue-splitter reads numbered issue
  ids only (W02a's Notes say where).

## Implementation Notes

*2026-11-04, background work the owner asked for (branch
`claude/wete-w02c-registration`, on top of W02b's). The owner said to
answer the open questions and record the answers as decisions; each one
below is the owner's to overturn.*

### What was built

| File | Does |
|------|------|
| `src/wowbuild/dbc.lua` | the seven tables' layouts as data; `write`, `merge` (over a stock table), `sql_values`, `header`, `column` |
| `src/wowbuild/registration.lua` | the id scheme (`SCHEME`, `ids(slot)`, `in_scheme`), slot choice (`choose_slot`, from each map's `registration.lua`), the rows (`rows`), WC3 text made plain (`clean_text`) |
| `src/wowbuild/loadscreen.lua` | the loading screen: the map's preview, or its ground from above; a BLP2 with every smaller copy |
| `src/wowbuild/output.lua` | gathers every map of the build folder and writes the forms |
| `src/wowbuild/init.lua` | `convert` picks the slot and ids, gives the zone to the ADTs, writes the picture, `registration.lua`, the creature list, the forms and `map.lua`; the report and summary say what was registered |
| `src/wowbuild/creatures.lua` | W02b's ids from the scheme; each block's width enforced |
| `src/wowbuild/adt.lua` | each MCNK's area field (header offset 52) holds the zone |
| `src/mpq/stormlib.lua` | `create(path, n, lib, 2)` makes an MPQ version 2 (as 3.3.5a's own archives are) |
| `src/cli/wow-convert.lua` | `--slot N`, `--map-id N` (900-999), `--stock-dbc DIR`, `--no-stock`, `--no-patch` |
| `src/tests/test_wow_registration.lua` | the tests (below) |

Build folder, added to W02a's and W02b's:

| Path | Holds | Read by |
|------|-------|---------|
| `World/Maps/<dir>/registration.lua` | this map's slot, ids and rows (data) | the next conversion into the folder |
| `World/Maps/<dir>/<dir>_loading.blp` | the loading screen | both clients, through LoadingScreens.dbc |
| `DBFilesClient/<Table>.dbc` | the seven tables, **only this folder's maps' rows** | the W client (overlay first, per row; its 106) |
| `map.lua` | which map to open: id, folder, name, zone, the start, the WC3 → WoW transform, the folder's maps (data) | the W client's test-map run (1109's open question 4) |
| `war3map.w3e` | the map's own ground file, copied whole (added 2026-11-05) | the W client's WC3-tileset ground (custom-client 078) |
| `war3map.w3i` | the map's own info file, copied whole (added 2026-11-05) | the W client's WC3 water tint and fog (custom-client 081's plan, step 3) |
| `world/creatures-<id>.tsv` | the spawns, in 035-creatures.h's format | the W client's `--world` |
| `server/dbc.sql` | `REPLACE INTO <table>_dbc` for six tables | AzerothCore's world database |
| `server/dbc/<Table>.dbc` | the stock tables with these maps' rows added (only when stock tables are given; no LoadingScreens) | AzerothCore's `dbc` folder |
| `patch-W.MPQ` | every map's ground files and picture, and the merged tables when stock tables are given | the stock client, W02d's extractors |

### Checked

`luajit src/tests/test_wow_registration.lua <project>`: 89 checks pass
with the W client's readers loaded and StormLib present. Without them, 57
pass and 9 are skipped.

The W client's readers: `libwreaders.so` built from custom-client
`origin/claude/test-map-launch` with `scripts/build`'s cc line into a
scratch folder, and 035-creatures compiled the same way. Nothing was
committed there.

The test converts:

- **A made map:** 129 × 129 points, three players in two forces with
  Blue human, units of three owners. Its made stock folder has a Map,
  AreaTable and FactionTemplate but no Faction, and its AreaTable already
  uses AreaBits 4095 and 4094.
- **A second map into the same folder**, then the first map again.
- **DAoW-2.1 and Master-Crafters-Final-Conquest** from `assets/`.

It checks:

- every column of every table through the W client's `dbc_open`,
  `dbc_u32` and `dbc_text` (a float read as its four bytes);
- the map id → folder → WDT;
- the zone in all 256 chunks;
- the SQL's column counts;
- the merged tables (stock rows kept, ours added, a clash replaced and
  reported, another width refused);
- `patch-W.MPQ` through StormLib and through the W client's
  `mpq_open`/`mpq_read`, every file byte for byte;
- the loading screen through the W client's BLP decoder (512 × 512);
- the faction hostility worked out from the masks, as client and server do;
- `map.lua`'s transform against every spawn (within 0.01 yd);
- the creature list through 035.

`test_wow_placements.lua` (90) and `test_wow_terrain.lua` (161) pass with
the new ids.

**No disagreement between these files and the W client's readers was
found.**

| Map | Map id | Zone (AreaBit) | Looks | Factions | Loading screen | patch-W.MPQ |
|-----|-------:|---------------:|------:|---------:|----------------|-------------|
| DAoW-2.1 | 900 | 9000 (4095) | 0 (no unit file) | 7 | its preview | 7 files (no stock tables here) |
| Master-Crafters-Final-Conquest | 900 | 9000 (4095) | 19 | 4 | its preview | 7 files; its 316 spawns read by 035 |

### Decisions

1. **The id scheme.** Each converted map in a build folder takes a slot,
   0-99. Every id it uses is base + slot × width:

   | Kind | Where | Base | Width | Slots 0-99 cover |
   |------|-------|-----:|------:|------------------|
   | map | Map.dbc, `creature.map` | 900 | 1 | 900-999 |
   | area | AreaTable.dbc, each ADT chunk | 9000 | 10 | 9000-9999 (one zone now; room for sub-zones) |
   | loading_screen | LoadingScreens.dbc | 900 | 1 | 900-999 |
   | display | CreatureDisplayInfo.dbc and CreatureModelData.dbc (same numbers) | 50000 | 1000 | 50000-149999 |
   | faction | FactionTemplate.dbc and Faction.dbc (same numbers) | 3000 | 100 | 3000-12999 |
   | entry | `creature_template.entry` | 9000000 | 10000 | 9000000-9999999 |
   | guid | `creature.guid` | 1000000 | 50000 | 1000000-5999999 |
   | AreaBit | AreaTable's explored-zone bit | 4095 − slot | | moved down past any bit in use |

   Why these numbers:
   - **Map ids keep three digits.** AzerothCore's mmaps generator reads a
     map id from the first three characters of each `.map` file's name,
     and W02d runs it. The 3.3.5a tables end around 724 (from memory).
   - **The other blocks start above the stock tables' highest ids as
     remembered.** Roughly: AreaTable ~4990, LoadingScreens ~260,
     CreatureDisplayInfo ~32000, CreatureModelData ~3000,
     FactionTemplate ~2240, Faction ~1200. None of these is checked.
   - **Every id stays inside the server's limits.** A creature's entry and
     guid are 24 bits in its object id. `creature.map` and the map files'
     areas are 16 bits. The explored-zones field is 128 × 32 bits.
   - **Guids start low**, so the server's own counter (it starts after the
     highest guid) keeps most of its 16.7 million for creatures that
     triggers create (W02e).
   - **The SQL and the tables share each map's block**, so a map's
     displays and factions never meet another map's.

   W02b's SQL keeps its variables (`SET @MAP := 900`, `@ENTRY`, `@GUID`),
   and the DELETE ranges are a slot's width. If the owner's other custom
   patches use any of these blocks, the stock merge reports the clash.

2. **Slots.**
   - A map keeps its slot by its directory: a map converted again into the
     same build folder reads its old `registration.lua`.
   - A new map takes the lowest slot no other map in the folder holds.
   - `--slot N` or `--map-id N` asks for a slot. It is refused, naming
     the other map, when that map holds it.
   - Every table of the folder holds every map's rows, because a table
     replaces another one whole: per row in the W client, whole in an
     archive.

3. **Factions.**
   - Each converted faction takes a group bit of its own, 2^(3+i), from 16
     up. The stock FactionGroup.dbc uses 1 (player), 2 (Alliance),
     4 (Horde) and 8 (monster).
   - A template's FactionGroup and FriendGroup are its own bit.
   - Its EnemyGroup is the OR of its enemies' bits. A template lists only
     four enemies by name, so hostility goes by masks, and the four named
     slots are 0.
   - A stock player's faction is therefore neutral to every converted one.
     Which side the player takes is W02e's or W02g's call.
   - 28 factions at most. A Faction row of the same number gives each
     template a name, with no reputation (ReputationIndex −1).

4. **Map, zone, loading screen.**
   - The map's name is the w3i name with its TRIGSTR resolved and its
     colour codes and line breaks taken out. It falls back to the
     directory.
   - Map row: InstanceType 0 (a continent, so open to everyone),
     expansion 0, no corpse map (−1), no time-of-day override.
   - AreaTable row: one zone with the map's name, flags 0, MinElevation −500.
   - LoadingScreens row: names `World\Maps\<dir>\<dir>_loading.blp`.
   - The text of a localised column is written in all 16 locale slots,
     with the mask 3.3.5a's files carry (`dbc.LOC_MASK`, from memory).

5. **The loading screen picture** is the map's own:
   - its `war3mapPreview.tga` when it holds one;
   - otherwise its ground drawn from above, each point in its WC3 ground's
     colour, water blue, lit by the slope.

   It is a 512 × 512 BLP2, encoding 3 (plain BGRA), 8-bit alpha, with
   every smaller copy down to 1 × 1. Nothing of Blizzard's is used.

6. **Creature looks.**
   - One CreatureDisplayInfo row per W02b display (model and size).
   - One CreatureModelData row of the same number, naming the model.
   - A WoW path is written `.mdx`, as 3.3.5a's own rows are, since the
     client reads the `.m2`. A map's own WC3 model keeps its name.
   - Collision and bounds come from the WC3 unit's radius (width
     radius × 0.5, height radius × 2) until the model file is read.

7. **The forms.**
   - The overlay's tables hold only this folder's maps' rows, because the
     W client reads a table per row with the overlay first (its 106), so
     nothing of Blizzard's is copied.
   - The server's copy is `server/dbc.sql`: positional `REPLACE INTO` over
     `<table>_dbc`, so it can be run again. A row a map no longer uses
     stays until deleted by hand. LoadingScreens is left out because the
     server doesn't load it.
   - When stock tables are given, `server/dbc/` holds them merged, for a
     server that reads files.
   - `patch-W.MPQ` is version 2 with a listfile (which the extractors read
     names from). It holds every map's WDT, WDL, ADTs and picture.
   - With stock tables, `patch-W.MPQ` also holds the merged tables. An
     archive replaces a table whole, so it must carry the stock rows too.
   - Without stock tables it holds no tables. The report says so: a
     warning, or a note when `--no-stock` asked for none.
   - Without StormLib the rest of the build stands, and the report warns
     that no archive was written.

8. **Stock tables are the player's own.**
   - They come from `--stock-dbc DIR`, a folder of the client's `.dbc`
     files (AzerothCore's extracted `dbc` folder is one).
   - By default the converter uses
     `/mnt/mtwo/games/azeroth-core/data-files/dbc` when it is there.
   - They are read at build time, and their rows land only in the build
     folder.
   - A missing table is reported and left out.
   - A stock table of another width (another client build) stops the
     build.
   - The AreaBits the stock AreaTable uses outside our blocks are avoided.

9. **`map.lua` answers 1109's open question 4**: the map id comes from a
   file in the build folder. It holds:
   - the id, folder, name, zone and loading screen;
   - the start: the first human player's start location, else the first
     one, in yards on the converted ground and in WC3 units;
   - the WC3 → WoW transform (`wow_x = x0 + scale·wc3_y`,
     `wow_y = y0 − scale·wc3_x`, scale 1/30.72);
   - the ADT tiles;
   - the creature list's path;
   - every map of the folder.

   It is data only, readable in an empty environment.

10. **`world/creatures-<id>.tsv`** holds the spawns in the W client's own
    format (guid, entry, display, size, x, y, z, facing, name), so the W
    client shows them before a server runs (its `--world`).

### Left open and unchecked

1. **Every column layout is from memory** (AzerothCore's `DBCfmt.h` and
   the community's 3.3.5a table descriptions). No source in either repo
   lists them. Only these columns are confirmed by the W client's readers:
   - Map 1-2;
   - CreatureDisplayInfo 1, 2, 4, 5, 7-9;
   - CreatureModelData 1, 3.

   The counts (66, 36, 4, 16, 28, 14, 57) and `LOC_MASK` need checking
   against the owner's stock files: their headers give the field counts,
   and the test's merge path is ready for them. Then mark
   `checked = true`.
2. **The `<table>_dbc` copies' column order** in the owner's world
   database is unchecked. The SQL is positional, in each table's DBC
   order.
3. **The stock tables' highest ids** (the scheme's margins) are
   remembered, not read. Running with `--stock-dbc` reports any clash.
4. **BLP encoding 3 in the stock client** is unchecked. Its own loading
   screens are DXT. If it shows nothing, write DXT1. The W client
   decodes encoding 3.
5. **Group bits from 16 up** in FactionTemplate: the stock client and
   server compare masks, so bits FactionGroup.dbc doesn't name should
   work. Unchecked.
6. **AreaTable flags** are 0. Whether the client wants a flag for a zone
   of a custom continent (for the minimap or for resting) is unchecked.
7. **`.mdx` in CreatureModelData** for a WoW path, and whether the stock
   client opens a WC3 `.mdx` a map brings (it can't: that's a W client
   case).
8. **MPQ version 2 with AzerothCore's extractors** (W02d) and the stock
   client's patch order (`patch-W.MPQ` after `patch-3.MPQ`; W02f
   installs it).
9. **The server's ground** for the map (`.map`, vmaps, mmaps) is W02d's.
   Until then the server has no heights there.

### The W client's side (custom-client; not changed here)

Read on `origin/claude/test-map-launch` (PR #4: 067-test-map, 018-maps,
043-main, 015-mpq, 016-dbc, 035-creatures, 041-figure, 059, 060). For a
`--test-map <build folder>` run to open the converted map, these changes
are needed there:

1. **Read `<folder>/map.lua`** with 059's data reader. Open `map.id` with
   `map.directory`. Put the camera at `start.x, start.y` unless `--camera`
   is given. Today 043 opens map 1 (Kalimdor) unless `--map ID X Y` is
   given.
2. **Read tables from the overlay first, per row** (its 106). Look in
   `<folder>/DBFilesClient/<Table>.dbc`, then the archive chain. Today
   043 reads `Map.dbc` only from the chain (`mpq_chain_read`), which
   doesn't hold map 900. The rest of its tables are the same.
   - At least Map.dbc is needed. Taking the folder from `map.lua`
     sidesteps it.
   - CreatureDisplayInfo and CreatureModelData, for 041's
     `figure_from_display` on the converted creatures.
   - FactionTemplate, once the client colours or targets by faction.

   The resolver (060) has no table kind yet.
3. **Read the map's WDT, WDL and ADTs through the resolver** with the
   test-map folder first (105a/302). Today 018 reads them only from the
   chain by map name, and the resolver puts the folder first but no
   reader asks it.
4. **Ground heights** come from `--maps` (the server's `.map` files) and
   mmaps. A converted map has none until W02d writes them, so a test-map
   run should either take heights from the ADTs or say "no ground at the
   start" rather than fail.
5. **Default `--world` to `<folder>/world`** in a test-map run, where
   `creatures-<id>.tsv` is.
6. **041 swaps a model's extension to `.m2`** (`figure_from_display`).
   That fits WoW's rows but not a map's own WC3 `.mdx`, which
   CreatureModelData names as it is. It should open a `.mdx` with the
   WC3 model reader when the name says so.
7. **`--camera` units disagree.** The editor (913, `src/editor/test_map.lua`)
   passes WC3 world units, and 1109's contract says WoW yards. One side
   should convert; `map.lua`'s `wc3_to_wow` gives the rule either way.

The client doesn't need `patch-W.MPQ` (W02's answered question 5), and its
archive chain (015) doesn't load it.

### 2026-11-05: the ground file beside `map.lua`

The W client paints converted ground with WC3's own tilesets when the
player has a WC3 install (custom-client PR 10, its issue 1109 decision 35).
It reads the map's `war3map.w3e` from the build folder's root. Until now
the converter wrote none, so that run fell back to the converter's own
pictures.

`wowbuild.convert` now copies the map's `war3map.w3e`, byte for byte, to
`<build>/war3map.w3e` beside `map.lua` (`wowbuild.GROUND_FILE`). The
report lists it as one of the map's own files. It doesn't go into
`patch-W.MPQ`: the stock client has no use for it.

Decisions (answered here, for the owner to overturn):

1. **One ground file at the root, not one per map folder.** `map.lua` at
   the root names one map, the last one converted, and the W client's
   reader looks at the root. The ground file follows `map.lua`: a
   conversion removes the old one first, so the root's ground always
   belongs to `map.lua`'s map. Several maps in one folder would want
   `World/Maps/<dir>/war3map.w3e` and a field in `map.lua`; that waits
   until the client opens more than the last map.
2. **Copied, not rewritten.** It is the map's own file, so it carries no
   Blizzard data, and the W client already reads the format (its 063).
3. **Tests pass the bytes in** (`opts.ground`). The made maps in the
   tests have no archive to copy from.

Checked: `test_wow_registration.lua` (69 pass, 7 skipped here: no W
client library, no StormLib), `test_wow_placements.lua` (72 pass; the
real maps' "nothing else is copied" check allows the ground file),
`test_wow_terrain.lua` (70 pass) and `test_wow_triggers.lua` (138 pass).

### 2026-11-05: the info file beside it too

The W client's WC3 water (custom-client PR 14, its 1109 decision 67)
takes the map's water tint and fog from `war3map.w3i`. The converter now
copies that file to `<build>/war3map.w3i` (`wowbuild.INFO_FILE`) the same
way as the ground file: byte for byte, replacing an earlier map's, and
not into `patch-W.MPQ`. Tests pass the bytes in with `opts.info_bytes`.

Checked: `test_wow_registration.lua` 70 pass (7 skipped),
`test_wow_placements.lua` 72, `test_wow_terrain.lua` 70,
`test_wow_triggers.lua` 138.


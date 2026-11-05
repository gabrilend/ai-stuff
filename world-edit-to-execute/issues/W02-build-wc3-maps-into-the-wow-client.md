# Issue W02: Build WC3 Maps into the WoW Client

**Phase:** W - WoW Client Bridge
**Type:** Implementation (root; expected to split into W02a-W02g)
**Priority:** High
**Dependencies:** W01
**Blocks:** W04, W07, W08
**Builds on (completed):** terrain, doodad and unit parsers (phases 1-2), JASS → Lua transpiler (phase 3)
**Unlocks:** W04, W07

---

## Current Behavior

A `.w3x` map can be fully parsed (phases 1-3): terrain, doodads, units,
regions, cameras and triggers become Lua tables, and JASS becomes Lua. Nothing
turns that into anything the WoW client or AzerothCore can load.

A local AzerothCore server exists at `/mnt/mtwo/games/azeroth-core/azerothcore/`
with the `mod-eluna` Lua scripting module (the project uses its successor, ALE, `mod-ale`, which is not script-compatible with Eluna; the local checkout still needs switching), server data already extracted in
`/mnt/mtwo/games/azeroth-core/data-files/`, and a 3.3.5a client with a wine
launch script at `/mnt/mtwo/games/azeroth-core/client/run`.

Earlier research exists in
`docs/archive/azerothcore-2026-01-07/data-conversion-pipeline.md`; it has one
known error (it puts ADT files on the server; see the datapath document).

## Intended Behavior

The owner picks a `.w3x` file, runs one command, and a few minutes later is
standing on that map inside the WoW client, with its terrain, trees, buildings
and units in place and its triggers running on the server. Every step is done
by tools, so rebuilding a map after a converter fix is the same one command.
Noggit (an open-source WoW map editor) is used to look at and touch up the
result, never as the only way to produce it.

Conversion is described stage by stage in
`docs/datapath-wc3-map-into-wow-client.md`; the scale rule (one WC3 tile = one
WoW terrain cell, 4.1667 yards) is explained in `docs/wow-client-bridge.md`.

## Suggested Implementation Steps

Planned sub-issues (to be confirmed through the issue-splitter's analyze →
review → execute flow):

| ID | Name | Dependencies | Description |
|----|------|--------------|-------------|
| W02a | terrain-to-adt-writer | W01 | WC3 terrain grid → one WDT + ADT files: heights (145 floats per chunk), ≤4 texture layers with 64×64 alpha maps, liquid, normals. Texture reduction rule with counted warnings. A WC3-ground-type → WoW-texture-path table kept as data per WC3 tileset |
| W02b | doodads-and-units-to-placements | W02a | Doodads → M2/WMO placement records in the ADT, through a WC3-type → WoW-model table (data file). Units → SQL rows for creature templates and spawns, one faction per WC3 force |
| W02c | map-registration-and-output-forms | W01, W02a | New rows in `Map.dbc`, `AreaTable.dbc`, `LoadingScreens.dbc` and the matching server-side copies. Written in two forms: a **loose overlay folder** (what the W client reads) and `patch-W.MPQ` (for the stock client and for the extractor tools in W02d). A converted map that loads in the stock client earns the "default client compatible" seal; most won't need it |
| W02d | server-data-for-new-maps | W02c | Run AzerothCore's map, vmap and mmap extractors over the client plus `patch-W.MPQ`, only for the new map ids, and install the results. (The extractors read archives, which is why the patch archive is built even though the W client doesn't need it) |
| W02e | triggers-on-the-server | W02b | Transpiled triggers run in ALE. A shim implements JASS natives with ALE calls (unit creation, timers, region enter events, player resources). Unsupported natives are listed per map, not skipped silently. **This is the rules engine for WC3 maps in the W client** (decided 2026-09-23). Scope widened 2026-10-07: the server must run **every** trigger and every WC3 mechanic (combat, orders, pathing, economy, abilities), not only what a sample map uses; the owner: "We might be able to implement those in Lua ALE? But patches are fine too." So each mechanic goes in ALE where ALE reaches, and in a server patch where it doesn't; this project's Lua runtime is the reference both are checked against. The shim and any server module live in their own folder under AGPL v3, because they run inside AzerothCore (AGPL v3) and ALE (GPL v3); see `docs/licensing-and-boundaries.md` |
| W02f | launcher-and-loader | W02c, W02d | Launcher: start authserver/worldserver, install `patch-W.MPQ` in the client's `Data/`, write `realmlist.wtf`, clear the client's creature/object cache (`Cache/WDB`), start `Wow.exe` under wine. Loader: pick a `.w3x`, run W02a-e, restart the worldserver (it reads map tables only at start), teleport the character to the WC3 start location |
| W02g | rts-controls | W02e | WC3-style control: box select, right-click move, command card, resource bar, top-down camera. **Built in the W client** as its Phase 11 ("WC3 Map Mode", `/mnt/mtwo/games/azeroth-core/custom-client/issues/1108-phase-demo.md`); this sub-issue tracks the stock-client stopgap and the server side of orders. The W client can be changed freely, so it can read ground clicks and point the camera straight down. **Stopgap for the stock client:** an addon with a command card, where "move here" is a ground-targeted spell (in that client, the targeting circle is the only way an addon can hand the server a ground position). Either way, orders reach the server as messages, and server scripts turn them into creature movement |
| W02h | empty-world-database | W02b | Decided 2026-09-23: "for this project we will have an empty database then. Filled only with what we need." The server's world database starts with its tables but no rows; the converter writes only what the map uses (its creatures, objects, factions, spells for converted abilities, one start location). Where the server reads data tables (DBC files) at startup, supply ours, generated from the map's object data (units, abilities, items), instead of Blizzard's where the server allows it. First step: measure what a stock AzerothCore refuses to start without (it may insist on certain rows, such as character creation data) and list each as a borrowed row to replace. **Rows are generated from the map files, dynamically, at map load** (owner, 2026-09-23: custom maps "very rarely use the stock wc3 abilities… Usually it's a copy and modify, so the changes are recorded in the map file. That is what we will dynamically create these tables to be"). Source: the object database (`src/parsers/objectdb.lua`, reading w3u/w3a/w3t/w3b/w3d/w3h/w3q). **Gap:** each modified object stores only its changed fields plus the id of the stock object it copies (`original_id`, e.g. a custom `A000` based on Storm Bolt `AHtb`). Its unchanged fields live in WC3's stock tables (`Units\AbilityData.slk` and friends in the WC3 game archives), which the project didn't have when this was written (`src/validation/init.lua`: "we don't have SLK data"). See open question 7. **Since 2026-09-24 the project reads them**: issue 112's stock rows, merged under each map's changes through its game-version layer (112b, 112c) |

Execution order:
`W02a → W02b → W02c → W02d → W02f` with `W02e` and `W02h` after `W02b`, and `W02g` last.

AzerothCore is **installed by the user, not bundled** (licence reasons, see
`docs/licensing-and-boundaries.md`); the shim from W02e lives in its own AGPL v3
folder. W08 plans a server of our own that would replace AzerothCore here.

Tuning ("lots of tweaking") goes into `docs/balance-updates.md` as it happens,
not into new issues.

## Generated Sub-Issues

- `W02a-terrain-to-adt-writer.md` (2026-11-04): written by hand from the
  table above, not by the issue-splitter, which reads numbered issue ids
  only (W02a's Notes say where). **Built** the same day as background
  work: `src/wowbuild/`, the converter command `src/cli/wow-convert.lua`
  (terrain only; the later sub-issues add theirs to it), the ground
  texture table as data. Left: the texture paths checked against the
  owner's client, Noggit, the stock client and AzerothCore's extractor on
  the owner's machine.
- `W02b-doodads-and-units-to-placements.md` (2026-11-04): written by hand
  the same way. **Built** the same day as background work, on W02a's
  branch: doodads as M2/WMO placements in the ADTs (with each chunk's
  MCRF) through a model table kept as data (`src/wowbuild/models.lua`,
  logical paths for the W client's resolver, which the baseline set
  covers under the same names); units as `server/world.sql` (one template
  per type and faction, one faction per WC3 force, only what the map uses,
  as W02h asks); the map's own models copied into the build; a placement
  list for the W client and W02c. The doodad and unit readers were fixed
  on the way (every Frozen Throne map with units failed to parse). Left:
  the model paths checked against the owner's client, the SQL on the
  owner's AzerothCore, Noggit and the stock client.
- `W02c-map-registration-and-output-forms.md` (2026-11-04): written by
  hand the same way. **Built** the same day as background work, on W02b's
  branch:
  - the map's rows in Map, AreaTable, LoadingScreens, CreatureDisplayInfo,
    CreatureModelData, FactionTemplate and Faction (`src/wowbuild/dbc.lua`,
    layouts as data);
  - an id scheme of 100 slots a build folder (map ids 900-999; open
    question 3 answered for now);
  - a loading screen made from the map;
  - the forms: the W client's overlay (`DBFilesClient/`, `map.lua`,
    `world/creatures-<id>.tsv`), the server's `server/dbc.sql` and merged
    `server/dbc/`, and `patch-W.MPQ` through StormLib;
  - everything read back through the W client's own readers.

  Left: every column layout checked against a source or the owner's
  stock files; the stock client, the SQL on AzerothCore and the
  extractors on the owner's machine; the W client's side (the changes
  listed in W02c's notes, for custom-client).
- `W02e-triggers-on-the-server.md` (2026-11-04): written by hand the
  same way, split into seven steps (coverage and skeleton; the server's
  loader and the real ALE; templates and units' state; orders; groups,
  forces and players' events; the mechanics; the whole of every map).
  **Step 1 built** the same day as background work, on W02c's branch:
  - the shim in its own AGPL v3 folder, `server-side/ale/wc3shim/`
    (requires nothing outside it), with 133 natives in 8 groups: numbers
    and strings, triggers, timers, waits, players' gold and lumber, units
    made at a point as creatures, locations and rects, regions entered
    and left;
  - a fake ALE (`fake_ale.lua`) the shim runs on here, and the shim
    checked line by line against the project's own runtime
    (`src/jass/vm.lua`) on the same scripts;
  - the converter's side (`src/wowbuild/triggers.lua`): each map's script
    transpiled, the data the shim reads, and `natives-report.lua`, every
    native the script calls against what the shim has, in
    `server/triggers/<dir>/`.

  Left: every ALE call checked against mod-ale on the owner's machine
  (all are from memory), the server's loader, and steps 2-7.
- W02d, W02f-W02h: not yet written.

## Progress

- *2026-11-04:* acceptance line 1 is met for the terrain: one command
  converts `assets/DAoW-2.1.w3x`'s ground into a build folder. Line 3's
  height half is checked against the W client's own ADT reader (every
  outer vertex and cell centre within 0.5 yd; worst 2.5e-6). Line 6's
  terrain part (texture folds and unmapped ground types) is in
  `conversion-report.lua`. Line 7 holds for the terrain: everything is
  written into the build folder; the ADTs name WoW's textures by path only.
- *2026-11-04 (W02b):* line 4 is checked against the W client's own
  reader for the doodads: every placed model comes back where WC3 placed
  it (0.01 yd), facing its way through the W client's own placement
  matrix, at its size; units become spawns at their WC3 points. In the
  stock client and on a running server it waits for W02c. Line 6's
  placements part (unmapped doodad and unit types, left-out doodads and
  units) is in `conversion-report.lua`. Line 7 holds: the build carries
  paths, SQL and the map's own imports only. Open question 4 is answered
  for now by a hand-seeded table (W02b's decision 4).
- *2026-11-04 (W02c):* the map is registered.
  - Its rows are in the client's tables (the W client's reader reads every
    column as written) and in the server's copies.
  - `patch-W.MPQ` is written, and StormLib and the W client's archive
    reader read every file of it back.
  - Line 7 holds: stock tables are read from the player's folder at build
    time, and their rows go only into the build folder.
  - Open question 3 is answered for now (W02c's decision 1: map ids
    900-999, a slot per map in a build folder).
  - Lines 2-5 still wait for the owner's machine, W02d (the server's
    ground) and the W client's side (W02c's notes).

- *2026-11-04 (W02e, step 1):* line 6's natives part is in the build
  folder: `server/triggers/<dir>/natives-report.lua` lists every native
  the script calls and which the shim lacks, and `conversion-report.lua`
  counts them. Every map in `assets/` is counted: 745 distinct names over
  19 maps, of which the shim has 101; per map it has 40-85 names, 54-67%
  of the call sites. Line 5 (a timer and a region-enter trigger on the
  server) passes on a fake ALE against the project's runtime; on the
  owner's AzerothCore it waits for W02e's step 2. Line 7 holds: the
  transpiled script and its data are made from the map, in the build
  folder; the shim ships under its own licence.

## Acceptance Criteria

- [ ] One WC3 map (the smallest DAoW map in `assets/`) converts with one command
- [ ] Noggit opens every written ADT without complaint, at the expected place
- [ ] The character can walk the map; ground height matches the WC3 height field within 0.5 yd at sampled points
- [ ] Trees, buildings and units stand where WC3 placed them (checked at sampled points)
- [ ] At least one timer trigger and one region-enter trigger run on the server
- [ ] Texture folds, unmapped doodads/units and unsupported natives are counted in a conversion report
- [ ] `patch-W.MPQ` and all generated files live in a build folder; nothing proprietary is committed

## Open Questions

1. Accept the scale rule 1 WC3 tile = 1 WoW cell?
2. ~~Hero mode or RTS mode first~~. Answered 2026-09-23: RTS control belongs in the custom client ("the purpose of creating a custom client is so that we can heavily modify it"); the stock-client addon is a stopgap. Still open: does W02g wait for the custom client to reach a playable phase, or build the stopgap first?
5. ~~Does the custom client need `patch-W.MPQ`?~~ Answered 2026-09-23: no. The W client reads loose overlay folders. The archive is kept for the stock client ("it'd be neat") and for AzerothCore's extractor tools, which read archives.
7. **Stock values under custom objects.** Where do the unchanged fields of copied-and-modified objects come from? (a) Read WC3's stock tables from the user's own WC3 install at load time, counted as borrowed rows, like the WoW client's files (works now); (b) a stock-object table of our own; (c) (a) now, (b) later.
   *Discussion, 2026-09-23.* The owner: "maybe we could parse it from a wikipedia page that lists the default values? If we need to, we can create that wikipedia page. Though I think that little bit of obfuscation is annoying, it might help protect us legally. I don't think it's possible to clean room it, if we want to be compatible with custom maps which require the exact defaults."
   - Agreed: clean-room adds nothing here. The values must be identical to the stock ones, so any route ends with the same numbers; separating describer and builder can't make identical numbers independent.
   - Against writing a public wiki page ourselves and parsing it back: the numbers would still come from the stock tables, so the page adds no distance, only a detour. The transcripts would record the detour, which argues *against* us rather than for us. Wikipedia also removes game-guide stat tables (it isn't a game guide), so the page wouldn't last.
   - The stronger footing is to say plainly what the values are: **functional facts needed so existing maps work the same**, the kind of interoperability case where compatibility-driven reverse engineering has generally been treated as permissible. That means: take only the fields maps depend on (numbers, flags, ids), never art or text; store them in our own format; say where they came from. (An engineering view, not legal advice.)
   - Community wikis that already publish these numbers (for example Liquipedia's Warcraft III pages, under CC BY-SA) can serve as an independent cross-check, and as the source for the values they cover. Their licence asks for attribution and share-alike on the table built from them.
   - Safest of all is (a): read the stock tables from the player's own WC3 install at load time and ship nothing.
   **Decided 2026-09-23.** Now: (a). Stock values are read from the player's own WC3 install at map load, counted as borrowed rows, and nothing is shipped ("sounds good... for now..."). Later: a table of our own, openly described as the functional facts maps need for compatibility (the owner: "I think you're right"). Community wikis are **a cross-check only, never a source**: the tables are part of the project, which is RGPL, and a table built from CC BY-SA pages would have to be released under CC BY-SA instead. Comparing our numbers against theirs copies nothing into the table.
   **Install found on this machine:** `/mnt/mtwo/games/warcraft-iii/prefix/drive_c/users/ritz/Warcraft-III/` holds `war3.mpq` (Reign of Chaos) only. Most custom maps are Frozen Throne maps, whose stock tables live in `war3x.mpq`, with patch overrides in `War3Patch.mpq`; neither is installed there. The Frozen Throne disc image and patch are in `/mnt/mtwo/games/warcraft-iii/torrent-version/`. The stock-table reader must read the archives in patch order (patch over expansion over base), the same chain rule as the WoW client.
6. ~~Who runs a converted map's rules in the W client?~~ Answered 2026-09-23: AzerothCore, through W02e. Multiplayer comes with the server; every WC3 rule the shim touches must be re-expressed as server logic.
3. Which range of map ids is ours? (Must not collide with Blizzard's rows or other custom patches the owner uses.)
   *Answered for now 2026-11-04 (W02c, the owner's to overturn):* 900-999, one per slot of a build folder (100 maps). Every other id a map takes (zone, loading screen, displays, factions, creature entries and guids) is a block of the same slot. Map ids stay three digits because AzerothCore's mmaps generator reads a map id from a `.map` file's first three characters. A stock row inside these blocks is reported when the stock tables are given. See `W02c-map-registration-and-output-forms.md`, decision 1.
4. Custom units need a WoW model per WC3 unit type. Who fills the WC3 → WoW table first: a hand-seeded table for the melee races, or W05's forge?
   *Answered for now 2026-11-04 (W02b, the owner's to overturn):* a hand-seeded table first (`src/wowbuild/models.lua`: the melee races' common units, creeps, tree walls, rocks and plants), every row unchecked; W05's forge fills the baseline set under the same names, and a row may name its own baseline model once one exists.
8. Should the map and model fetcher (issue 603) also run inside the W client, as a map list in WC3 map mode? Deferred here from 603 by the owner (2026-09-26): "we should answer that question when we're working on the WoW client. I don't see why not, but maybe I will when we're working over there."

## Related Documents

- `docs/wow-client-bridge.md`, `docs/datapath-wc3-map-into-wow-client.md`
- `docs/archive/azerothcore-2026-01-07/data-conversion-pipeline.md`, `custom-ability-bridge.md`
- `docs/formats/w3e-terrain.md`, `docs/formats/unitsdoo.md`

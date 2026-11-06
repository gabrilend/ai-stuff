# Issue W02b: Doodads and Units to Placements

**Phase:** W - WoW Client Bridge
**Type:** Sub-issue of W02
**Priority:** High (a converted map is bare ground until its trees, rocks and units stand on it)
**Dependencies:** W02a (the ADTs the placements go into; the shared placement module)
**Blocks:** W02e (triggers act on the spawned creatures), W02h (the empty world database starts from this SQL)

---

## Current Behavior

*As written (2026-11-04, before this issue's work):* W02a's converter
(`src/wowbuild/`, `src/cli/wow-convert.lua`) writes a map's ground: WDT,
WDL and ADTs with heights, textures and water. Each ADT's chunks hold an
empty MCRF, and the tile has no model or building blocks, so a converted
map is bare ground. The map's doodads (`war3map.doo`) and units
(`war3mapUnits.doo`) are read by the project's own parsers
(`src/parsers/doo.lua`, `src/parsers/unitsdoo.lua`) for its own viewer, but
nothing turns them into WoW placements or server rows.

*Now:* see Implementation Notes. Doodads are placed in the ADTs and units
written as SQL; the model paths, the SQL against a running AzerothCore and
the result in the stock client wait for the owner's machine.

## Code review findings to fix

The code review of 2026-11-05 read the unmerged pull request #242 that build this issue. The issue text above is brought over from the branch; the code is still on the branch. Each point below is to be fixed (or answered) before the code merges and this issue is called complete. "Confirmed" means the review reproduced it by running the branch's code; the rest come from reading it. The review's overall summary is in the message of the "code review results" commit.

- Imported files are written to the build folder plus the archive name, with `..` never refused, so a map can write anywhere on the machine.
- `--map-id` changes only the map number; entry, GUID and display-id ranges are fixed, so a second converted map deletes the first map's templates and collides on GUIDs.
- Neutral players are taken as 24–27 only for map-info version 28+, but 24-player maps are saved as version 25; War in the Plaguelands' players 12–23 get neutral factions.
- Items are recognised only if the map changed them or they're on a ~20-entry list, so most stock items placed on the map spawn as creatures.
- `server/world.sql` and `placements.lua` have fixed names, so a second map into the same folder replaces the first's.
- The archive stays open if any later stage raises.
- A `TRIGSTR_` name lookup re-implements `parsers/wts.lua`, guessing table shapes and missing embedded tokens.
- The archive is opened twice; one `mkdir -p` shell per imported file; the inside-the-tiles test is copied in two modules; `C.used` is never read; fold and info-file rules broken.

## Intended Behavior

The same one command (W02a's) also writes:

- **Doodads as placements in the ADTs.** Each WC3 doodad and destructible
  becomes an M2 placement (`MMDX`/`MMID` names, `MDDF` records) or a WMO
  placement (`MWMO`/`MWID`, `MODF`), where WC3 placed it, facing its way, at
  its size; each chunk's `MCRF` names the placements standing in it.
- **A WC3-type → WoW-model table kept as a data file.** The paths are the
  logical names the W client's resolver looks up in its order
  (`docs/wow-client-bridge.md`, "Our own models are the default"): the
  player's own packs, the server's files (a hosted map's own models travel
  with it), the player's Blizzard install, the baseline standard model set,
  a wire-frame. Blizzard's files are never copied.
- **Units as SQL rows** for AzerothCore's world database: creature templates
  and spawns, **one faction per WC3 force**. Only what the map uses (W02h:
  "an empty database ... Filled only with what we need").
- **Counts in the conversion report:** doodads and units placed, left out
  and why, unmapped types (W02's acceptance line 6, placements part).

## Suggested Implementation Steps

1. Read the map's doodads, units, info, strings and object data with the
   project's existing readers; fix what they get wrong on real maps.
2. The model table as data; the lookup a placement takes to its row.
3. Doodad placements per ADT tile and chunk: positions through W02a's
   `wowbuild/coords.lua`, facing, size, WMO boxes; the bytes in
   `wowbuild/adt.lua`.
4. Units: templates, displays, factions, spawns; the SQL.
5. The map's own models copied into the build at their own paths.
6. A placement list (data) beside the report, for the W client and W02c.
7. Tests: made maps and the maps in `assets/`, every written ADT read back
   through the W client's own reader by LuaJIT's FFI.

## Acceptance Criteria

- [x] One command places the doodads of `assets/DAoW-2.1.w3x` in its ADTs
      (4,937 of 7,206 placed; the rest counted as unmapped types)
- [x] The W client's ADT reader reads every written ADT with its
      placements: model names, positions (0.01 yd), turns and sizes, building
      boxes, one uid for a building on several tiles
- [x] The W client's own placement matrix (`adt_place_matrix`) turns a model
      to face where the WC3 doodad faced
- [x] Each chunk's MCRF names the model placements standing in it, each
      once, and the chunks a building covers (walked by the test: the W
      client's reader skips MCRF)
- [x] Units become SQL rows: one template per type and faction, one faction
      per WC3 force plus the two neutrals, one spawn per placed unit; every
      spawn names a written template (Master-Crafters: 316 spawns, 88
      templates, 4 factions)
- [x] The model table is a data file; a map's own models travel with it
      into the build; nothing of Blizzard's is written or committed
- [x] Placed, left out and unmapped are counted in the conversion report
- [ ] Every model path in the table checked against the owner's client
      (W01's archive reader or a listfile); rows corrected and marked
      `checked = true`
- [ ] Trees, buildings and units stand where WC3 placed them in the stock
      client and in Noggit (W02's acceptance line 4; needs the owner's
      machine and W02c's map registration)
- [ ] `server/world.sql` runs on the owner's AzerothCore and the creatures
      spawn (needs W02c's map ids and W02h's empty database)

## Notes

- *Splitter.* Written by hand in the project's issue style from W02's table
  row, as W02a was: the issue-splitter reads numbered issue ids only (W02a's
  Notes say where), so it can't find or write a `W02b`.

## Implementation Notes

*2026-11-04, background work the owner asked for (branch
`claude/wete-w02b-placements`, on top of W02a's). The owner said to answer
the open questions and record the answers as decisions; each one below is
the owner's to overturn.*

### What was built

| File | Does |
|------|------|
| `src/wowbuild/placements.lua` | doodads → per-tile M2 and WMO placements and chunk references; the model lookup (`find_row`); facing (`rotation_y`, `orientation`); counts |
| `src/wowbuild/creatures.lua` | units → templates, displays, factions, spawns; `creatures.sql` writes them |
| `src/wowbuild/models.lua` | the WC3 type → WoW model table, data only |
| `src/wowbuild/adt.lua` | now writes MMDX, MMID, MWMO, MWID, MDDF, MODF and each chunk's MCRF |
| `src/wowbuild/init.lua` | `wowbuild.read_map` (the map's parts, through the existing readers); `convert` writes the placements, the map's own models, `server/world.sql`, `placements.lua` and their counts |
| `src/cli/wow-convert.lua` | usage says what is built; `--models FILE`, `--map-id N` |
| `src/parsers/doo.lua`, `src/parsers/unitsdoo.lua` | fixed (below) |
| `src/tests/test_wow_placements.lua` | the tests (below) |

Build folder, added to W02a's: `<build>/server/world.sql`,
`<build>/placements.lua` (every doodad, unit and start location and what
became of it; display ids with their paths; factions; data, loadable in an
empty environment) and the map's own model files at their own archive paths
(`<build>/war3mapImported/X.mdx`, with the textures they name that the map
holds).

### Checked

`luajit src/tests/test_wow_placements.lua <project>`: 89 checks pass with
the W client's reader loaded (`libwreaders.so` and `wreaders.h` built from
custom-client `origin/main` 1acf493 with `scripts/build`'s cc line, into a
scratch folder; nothing committed there); without it 71 pass and 5 are
skipped. A made map (two ADT tiles; a tree, a rock, a hidden, an unmapped
and an off-map doodad, a building on the tiles' edge, a map's own model, a
stretched one; nine units of every kind) and three maps in `assets/`
(DAoW-2.1, Master-Crafters-Final-Conquest, War-in-the-Plaguelands) are
converted and read back. The W client's reader returned every model name,
position (within 0.01 yd), turn and size as written, and a building's box
and uid in both tiles it spans. **No disagreement between this writer and
020-adt was found.** 020-adt does not read MCRF (it draws every placement
of a tile, not per chunk), so the test walks it itself; Noggit and the
stock client do read it.

Facing: for 36 angles, the W client's `adt_place_matrix` turns a model's
+x (the way an M2 faces) to the WC3 facing within 1e-4, upright.

Height: WC3 doodads carry their own height, which is kept. On DAoW-2.1
99.4% of placed doodads stand within a yard of the converted ground, on
Master-Crafters 96.6%, on Conquest 98.5%; on War in the Plaguelands 88.7%
(the map raises and sinks its own custom doodads on purpose).

The readers: every map in `assets/` now reads its `war3map.doo` and
`war3mapUnits.doo` to the last byte and writes back the same bytes.

| Map | Doodads | Placed | Left out | Unmapped types | Units | Spawned | Templates |
|-----|--------:|-------:|---------:|---------------:|------:|--------:|----------:|
| DAoW-2.1 | 7,206 | 4,937 | 2,269 unmapped | 247 | (no unit file) | | |
| Master-Crafters-Final-Conquest | 9,227 | 2,940 | 6,286 unmapped, 1 hidden | 130 | 330 | 316 (12 start locations, 2 items left out) | 88, 19 models, 16 types unmapped |
| Conquest-v8-fix | 8,202 | 5,706 | 2,460 unmapped, 36 hidden | 158 | 12 | 0 (12 start locations) | |
| War-in-the-Plaguelands | 19,229 | 11,034 (4,396 by the map's own models) | 8,195 unmapped | 250 | (no unit file) | | |

War in the Plaguelands' 119 own models travel with it (144 files written
with their textures); nothing else of the map is copied.

### Decisions

1. **Placements.** A doodad lands where `wowbuild.coords` puts its WC3
   point; its WC3 z is kept (yards = units / 30.72). MDDF/MODF rotation is
   (0, WC3 degrees + 90, 0), written 0-360: the W client's matrix then
   faces an M2's +x the WC3 way. Size: the mean of the WC3 x, y, z scales
   times the row's `scale` (a placement has one size; stretched ones are
   counted). A placement's uid is its doodad's place in `war3map.doo`
   (from 1), so one doodad is one uid on every tile. An M2 goes in the tile
   and chunk holding its point; a building in every tile and chunk its box
   touches, the same uid in each.
2. **Building boxes** (MODF) come from the row's `size` (width, height in
   yards; 10 x 10 by default), centred on the point, until the model file
   is read. No row of the stock table is a building yet: WC3 buildings are
   units, and the doodads that look like buildings were not matched to
   WMOs. The path is tested with a made table.
3. **Left out, counted:** hidden doodads (flag 0), types with no row, and
   anything off the map. An unmapped doodad is left out of the ADT (rather
   than a stand-in that would mislead in the stock client); the placement
   list still names it, so the W client can draw its WC3 model or a
   wire-frame there. An unmapped unit gets `units.fallback` (a crate) so the
   server can still spawn and script it.
4. **The model table** (`src/wowbuild/models.lua`) names WoW 3.3.5a logical
   paths: the names the W client's resolver looks up, which the baseline
   set must cover under the same names, so a player without Blizzard's
   files sees ours. A row may name its `baseline` model once the forge has
   one; the report counts placements still waiting. The lookup, first
   match wins: the map's own model (the object's model field naming a file
   in the map), the stock WC3 model a custom type points at (`by_model`),
   the type id or the stock id a custom type copies (`types`), the doodad's
   category and tileset letters (`classes`, P plants and R rocks, as
   `LRrk` is a summer rock). Seeded by hand (W02's open question 4: the
   hand-seeded table first, W05's forge later): tree walls per tileset,
   common destructibles, plants and rocks, about forty melee and creep
   units. Every row is `checked = false`.
5. **A map's own models travel with it** (the owner, 2026-11-04): a model
   the map imports is named by its own archive path in the ADT and
   copied into the build at that path, with the textures it names that
   the map holds, so the server's step of the resolver serves it. Only
   files the placements use are copied.
6. **Templates per type and faction.** AzerothCore keeps a creature's
   faction in its template, so red's footmen and blue's are two templates;
   a map's custom type is its own template. Name: the map's change (`unam`,
   its TRIGSTR read from `war3map.wts`), else the row's name, else the
   reader's common names, else the id; a name is made one line. Level: the
   map's `ulev`, else 1. Stock values (hit points, speed) stay
   AzerothCore's defaults: they come from the player's WC3 install at load
   (open question 7) and are W02e's and W02h's to apply.
7. **One faction per WC3 force** (the map's own forces when it uses custom
   forces; otherwise each player slot, as melee games start), then Neutral
   Hostile (everyone's enemy) and Neutral Passive (no one's). A force's
   players are allied when its flag says so; forces are each other's
   enemies. Neutral players are 12-15 in maps saved before the 24-player
   editor (w3i version below 28), 24-27 after. Faction templates are
   numbered from 3000 here; W02c writes them into the client's and
   server's faction tables (the SQL names them by number, since a client
   table can't read SQL variables). The placement list carries each
   faction's players and enemies for that.
8. **Ids.** The SQL starts with `SET @MAP := 9000`, `@ENTRY := 9100000`,
   `@GUID := 9100000`, and every row is relative to them, so W02c (which
   picks map ids, W02's open question 3) changes one line; `--map-id`
   sets `@MAP`. Display ids start at 50000. Each block is 100,000 wide.
   These numbers are placeholders chosen clear of Blizzard's rows and of
   the owner's other custom NPCs seen here (900001-900011).
9. **W02h shapes the SQL:** only the four tables a spawned creature needs
   (`creature_template`, `creature_template_model`, `creature_model_info`,
   `creature`), only this map's rows, nothing borrowed from a stock world
   database. It deletes this map's spawns and its blocks first, so it can
   be run again. The column lists follow the AzerothCore schema the
   owner's other project already applies (`creature.id`, not `id1`;
   `creature_template` with `CreatureImmunitiesId`). Names and paths the
   map maker wrote are quoted, and a line break can't end a comment.
10. **Spawns** stand on the converted ground (the WC3 height field at the
    unit's point), facing the WC3 way (orientation = WC3 angle - 90 deg,
    0-2pi), and respawn after a week (preplaced WC3 units don't come back;
    W02e's rules decide). Start locations (`sloc`), placed items and random
    units are left out of the SQL and counted; start locations are listed
    in the placement list from `war3map.w3i`.
11. **Reader fixes, found on real maps** (each was why a map failed):
    - `doo.lua`: in version 8 the item drops (table pointer, sets) come
      *before* the creation number; it read the pointer as the creation
      number and misaligned every doodad with drops. `doo.write` writes the
      same order.
    - `unitsdoo.lua`: every entry has the gold and target acquisition, the
      hero section (level 1 for other units; stat bonuses in version 8
      only) and a custom colour; the random flag's three kinds read as the
      files hold them (0: level and class, 1: a random group, 2: a list of
      its own). Before, every Frozen Throne map with units failed to parse
      (Conquest-v8-fix, Master-Crafters). `docs/formats/unitsdoo.md` is
      corrected, and `test_unitsdoo.lua`'s made entries now hold the
      sections real files hold (every assertion kept).

### Left open

1. **Check every model path** against the owner's client (W01's archive
   reader can test all rows at once) and correct the misses; then mark rows
   `checked = true`. Many file names are guesses; a missing one shows as the
   W client's wire-frame.
2. **More rows.** Most unmapped doodads are cliffs' and decoration types the
   letters don't cover yet (DAoW-2.1: 247 types). The forge (W05) or the
   owner's eye fills them; the report lists each unmapped id with its count.
3. **Unchecked SQL columns:** `creature_model_info.Gender` and
   `DisplayID_Other_Gender` (written 2 and 0) were not seen in the owner's
   schema here; the rest are from SQL the owner's AzerothCore already runs.
   Running `world.sql` on that server is the check.
4. **Display ids and factions in the client's tables** (CreatureDisplayInfo,
   CreatureModelData, FactionTemplate) are W02c's, from `placements.lua`.
5. **A map's imports that are Blizzard's own models** (custom maps often
   import WoW models) travel like any other import, as the owner's "a
   hosted map's models travel with it" says; whether the server should
   hold such a file back (the bridge doc's question 16: a server never
   hands out Blizzard's files) can't be told from the file. Asked here, not
   decided.
6. **Noggit, the stock client and AzerothCore** on the owner's machine, as
   for W02a.
7. **Cliff models** (W02a's open point 5) are not placed: the ground steps
   at cliffs, and a cliff model along each edge waits for a model row per
   WC3 cliff type and a rule for the edge's direction.

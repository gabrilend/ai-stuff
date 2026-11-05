# Datapath: a WC3 map, played inside the WoW client

**Feature:** W02 (build WC3 maps into the WoW client)
**Status:** Stages 2-4 and 6 (terrain W02a, placements W02b, registration
and packing W02c) built 2026-11-04 in `src/wowbuild/`, run by
`src/cli/wow-convert.lua`; stage 5's first step (W02e: the coverage
report, the transpiled script, the shim's skeleton and first natives in
`server-side/ale/wc3shim/`) built the same day; the other stages
designed, not built.
Update this file when any W02 sub-issue changes the flow.

---

## The whole path

```
 map.w3x ──▶ [1 parse] ──▶ Map object (Lua tables, phases 1-3)
                              │
            ┌─────────────────┼──────────────────┬──────────────────┐
            ▼                 ▼                  ▼                  ▼
      [2 terrain]       [3 placements]     [4 registration]   [5 scripts]
      WDT + ADT files   M2/WMO placements   Map.dbc row,       transpiled Lua
                        (in the ADT) and    AreaTable row,      + native shim
                        SQL spawn rows      LoadingScreen row   for ALE
            │                 │                  │                  │
            └────────┬────────┘                  │                  │
                     ▼                           ▼                  ▼
              [6 pack] patch-W.MPQ  ◀────  client-side DBC   server-side:
                     │                                          SQL + lua_scripts/
                     ▼                                                │
              [7 server data] run AzerothCore's extractors            │
              over the client + patch → maps/ vmaps/ mmaps/ dbc/      │
                     │                                                │
                     └───────────────────┬────────────────────────────┘
                                         ▼
                              [8 launcher/loader]
                    start authserver + worldserver, install the patch,
                    write realmlist, clear the client cache, start Wow.exe
                    under wine, teleport the character onto the new map
                                         │
                                         ▼
                              [9 play] WoW client + control addon
```

## Stages

| # | Stage | Input (type) | Output (type) | Built in |
|---|-------|--------------|---------------|----------|
| 1 | Parse | `.w3x` path (string) | Map object: terrain grid, doodad table, unit table, regions, cameras, triggers (Lua tables) | Phases 1-3 (done) |
| 2 | Terrain | terrain grid: tilepoints (W+1)×(H+1), each with height (float, WC3 units), ground texture index (uint 0-15), cliff level (uint), water flag + level (float) | one WDT (which ADT tiles exist, 64×64 flag grid), one WDL (far-off heights) + up to 16 ADTs, each 256 chunks of 145 height floats, ≤4 texture layers with 64×64 alpha maps (uint8), liquid blocks (MH2O); `conversion-report.lua` with fold and unmapped counts | W02a (built) |
| 3 | Placements | doodad table (type id 4-char string, x/y/z float, facing radians, scale xyz); unit table (type id, owner player uint, position, facing) | doodads: M2/WMO placement records inside the ADT (`MDDF`/`MODF` blocks: file index, unique id uint32, position 3×float, rotation 3×float degrees, scale uint16 where 1024 = 1.0). Units: SQL rows for creature templates and spawns (`server/world.sql`); every doodad, unit and start location in `placements.lua` | W02b (built) |
| 4 | Registration | map name (w3i, strings), start locations, W02b's displays and factions, the build folder's other maps, optionally the player's stock `.dbc` folder | rows in `Map.dbc` (map id uint32 900-999, directory string = folder under `World\Maps\`), `AreaTable.dbc` (one zone; every ADT chunk's area id), `LoadingScreens.dbc` (a BLP2 made from the map), `CreatureDisplayInfo.dbc`/`CreatureModelData.dbc`, `FactionTemplate.dbc`/`Faction.dbc`; written as the overlay's `DBFilesClient/`, `server/dbc.sql`, merged `server/dbc/`; `map.lua` (id, start, WC3 → WoW transform) and `world/creatures-<id>.tsv` for the W client | W02c (built) |
| 5 | Scripts | `war3map.j` (text); W02b's templates, factions and spawns; map.lua's transform | `server/triggers/<dir>/war3map.lua` (the script transpiled, "env" scope), `map-data.lua` (what the shim reads, data), `natives-report.lua` (every native called, with call sites, against what the shim has, data); on the server, the shim (`server-side/ale/wc3shim/`, AGPL v3) runs it with ALE's calls | W02e (steps 1-2 built: report, script, shim with 574 natives, 95.5% of call sites; the server's loader not yet) |
| 6 | Pack | files from 2-4 | `patch-W.MPQ` (an MPQ archive, version 2 with a listfile, the client loads after its own patches, so its files win): every map's ground files and loading screen, and the merged tables when stock tables are given | W02c (built) |
| 7 | Server data | client `Data/` + the patch | `maps/*.map` (height + liquid grid the server uses for ground height), `vmaps/` (collision for line of sight), `mmaps/` (navigation mesh for creature pathing), `dbc/` | W02d |
| 8 | Launch/load | a chosen `.w3x`, launcher config (paths) | running server + client, character on the new map; before that, `server-stamp` (the server's files of the build, by which the editor's Test Map reuses the server) and `install-plan.lua` (which rows into which database table, which files, the shim's included, to which of the server's folders; data) | W02f (steps 1-2 built 2026-11-05: the stamp, the install plan as data; nothing installs it yet) |
| 9 | Play | player input | orders to the server through the control addon | W02g |

## Where WC3 and WoW disagree (each is a conversion rule)

| WC3 has | WoW 3.3.5a has | Rule |
|---------|----------------|------|
| Tile 128 units | Cell 4.1667 yd | 1 tile = 1 cell (see `docs/wow-client-bridge.md`, Scale) |
| Up to 16 ground textures anywhere | ≤4 textures per 33-yard chunk | Keep the 4 that cover the most of the chunk; fold the rest into the nearest by colour. Every fold is counted and reported as a warning; strict mode stops on it |
| Cliffs are separate cliff meshes chosen by cliff level | Terrain is one height field | Raise the height field; optionally place a cliff M2 along the edge |
| Pathing from terrain + doodad pathing textures (`war3map.wpm`) | Server pathing from a navigation mesh built from geometry | Regenerate the mesh (stage 7); check a sample of WC3 pathable/unpathable cells against it |
| Units belong to players 0-23 and obey orders | Creatures belong to factions and follow AI scripts | Units become creatures with a faction per WC3 force; orders come from the control addon through the server |
| Triggers run in the game client | Only the server runs logic | Transpiled triggers run in the server's ALE engine |

## Stage 2 as built (W02a)

```
 war3map.w3e ──▶ parsers/w3e.lua ──▶ wowbuild/terrain.lua ──▶ wowbuild/adt.lua ──▶ <build>/World/Maps/<dir>/
 (in the .w3x)    tile points          per chunk: heights,       ADT, WDT, WDL         <dir>.wdt, <dir>.wdl,
                                       normals, layers +         bytes                 <dir>_<tx>_<ty>.adt
                  wowbuild/coords.lua  blend maps (≤4, folds     (parsers/binwrite)
                  (placement, scale)   counted), water        ──▶ <build>/conversion-report.lua
                  wowbuild/ground_textures.lua (WC3 ground id → WoW texture path, data)
```

The command: `luajit src/cli/wow-convert.lua [--strict] [--name N] <map.w3x> <build folder>`
(exit 0 built, 1 failed, 2 bad options); the editor's Test Map calls it as
issue 913 describes. Each later stage adds its part to the same command.
Decisions and what is unchecked: `issues/W02a-terrain-to-adt-writer.md`.

## Stage 3 as built (W02b)

```
 war3map.doo ──▶ parsers/doo.lua ──────┐                      ┌──▶ ADTs: MMDX/MMID + MDDF (models),
 war3mapUnits.doo ▶ parsers/unitsdoo.lua│  wowbuild/placements │    MWMO/MWID + MODF (buildings),
 war3map.w3i ──▶ parsers/w3i.lua ──────┼──▶ (doodads) ────────┤    each chunk's MCRF
 war3map.wts ──▶ parsers/wts.lua ──────┤  wowbuild/creatures  ├──▶ <build>/server/world.sql
 war3map.w3u/w3b/w3d ▶ parsers/objectdata│  (units, factions)   ├──▶ <build>/placements.lua
                                        │                      └──▶ <build>/<the map's own models>
       wowbuild/models.lua (WC3 type → WoW model path, data) ─┘
```

A doodad's model is found in this order: the map's own imported model
(which travels with the map into the build), the stock WC3 model a custom
type points at, the type id (or the stock id a custom type copies), the
doodad's category and tileset letters; else it is counted as unmapped and
left out of the ADT. The paths are logical names the W client's resolver
looks up (the player's own packs, the server's files, the player's Blizzard
install, the baseline model set, a wire-frame), so a player without
Blizzard's files sees the baseline set's models under the same names.

Units become one creature template per WC3 type and faction (AzerothCore
keeps a creature's faction in its template), one faction per WC3 force plus
Neutral Hostile and Neutral Passive, one display id per model and size, and
one spawn per placed unit. The SQL writes only what the map uses (W02h) and
can be run again; its ids sit behind `@MAP`, `@ENTRY` and `@GUID`, set
from W02c's scheme (map 900 + slot). Decisions and what is unchecked:
`issues/W02b-doodads-and-units-to-placements.md`.

## Stages 4 and 6 as built (W02c)

```
 W02a/W02b's job ──▶ wowbuild/registration ──▶ World/Maps/<dir>/registration.lua (slot, ids, rows)
 (name, starts,      (slot, ids, rows)          │
  displays,          wowbuild/loadscreen ──────▶ World/Maps/<dir>/<dir>_loading.blp
  factions)                                     ▼
 every map's registration.lua in the build ──▶ wowbuild/output ──┬──▶ DBFilesClient/<Table>.dbc (these maps' rows only)
 the player's stock .dbc folder (optional) ──▶ (wowbuild/dbc)    ├──▶ server/dbc.sql, server/dbc/<Table>.dbc (merged)
                                                                  ├──▶ patch-W.MPQ (StormLib)
                                                                  └──▶ map.lua, world/creatures-<id>.tsv
```

How the ids work:

- Each map in a build folder takes a slot, 0-99, and keeps it by its
  directory.
- Every id is a block of that slot: map 900 + slot, zone 9000 + 10·slot,
  displays 50000 + 1000·slot, factions 3000 + 100·slot, creature entries
  and guids.
- All the folder's maps go into every table, because a table replaces
  another whole.

What each reader gets:

- **The W client** reads the overlay's tables per row, before its own. It
  learns which map to open from `map.lua`.
- **The stock client and the extractors** read `patch-W.MPQ`. It carries
  the stock rows too, when the player's stock tables are given.

Decisions, what is unchecked (every column layout is from memory), and the
changes the W client needs: `issues/W02c-map-registration-and-output-forms.md`.

## Stage 5 as built (W02e, steps 1-2)

```
 war3map.j ──▶ jass/lexer + parser ──▶ wowbuild/triggers ──┬──▶ server/triggers/<dir>/natives-report.lua
 (in the .w3x)                          scan: every call,   │    (every native called, the shim's group,
                                        each rawcode made   │     the runtime's answer, what the shim lacks)
 server-side/ale/wc3shim/covered.lua ──▶ (read as data) ────┤
 jass/vm.lua (the reference runtime) ──▶ its native types,  ├──▶ server/triggers/<dir>/war3map.lua
                                        constants, answers  │    (transpiled, env scope)
 W02b's creatures, map.lua's transform ────────────────────┴──▶ server/triggers/<dir>/map-data.lua

 on the server (step 3 loads it):
 ALE (mod-ale) ◀── server-side/ale/wc3shim (AGPL v3): natives on ALE's calls ◀── war3map.lua + map-data.lua
                   timers, waits = one-shot CreateLuaEvent; units = creatures
                   (PerformIngameSpawn, or W02b's spawn adopted in main());
                   regions and deaths = a 100 ms check of the creatures;
                   life = WC3 numbers on the unit, a fraction on the creature;
                   orders = MoveTo / AttackStart / MoveStop;
                   players, forces, alliances, groups = the shim's own
```

The script is scanned once, before W02b's creatures are made: every unit
type it creates gets a template, after the placed ones, in Neutral
Passive's faction, so no unit the script makes is a ghost. `map-data.lua`
also carries the factions' alliances, the map's players and names, the
strings the script uses (`TRIGSTR_*`) and the map's bounds.

The shim is checked against the project's own runtime (`src/jass/vm.lua`)
on the same scripts, on a fake ALE (`fake_ale.lua`), line by line. Every
ALE call it makes is listed in `shim.ALE_USED`, all from memory and
unchecked until the owner's machine. Decisions, coverage per map and what
is open: `issues/W02e-triggers-on-the-server.md`.

## Correction to earlier research

The archived `data-conversion-pipeline.md` (January) places `.adt` files under
the *server's* `maps/` folder. The server never reads ADTs: the *client* reads
WDT/ADT from its MPQ archives, and the server reads its own `.map`, vmap and
mmap files, which AzerothCore's extractor tools produce *from* the client's
archives. That is why stage 7 runs the extractors after stage 6.

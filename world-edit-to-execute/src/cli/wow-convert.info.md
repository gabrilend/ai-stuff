# wow-convert.lua

W02's converter: builds a WC3 map into WoW 3.3.5a's files in a build folder.
The map editor's Test Map (issue 913) runs it as
`<convert...> <map.w3x> <build folder>`; set the editor's
`test_map.convert` to `{ "luajit", "<project>/src/cli/wow-convert.lua" }`.

**Builds today** the terrain (W02a), the doodads and units (W02b), the
map's registration in the client's and server's tables with `patch-W.MPQ`
(W02c), and the first step of its triggers on the server (W02e: the script
transpiled for the shim in `server-side/ale/wc3shim/`, and the report of
which natives the shim has). W02's later sub-issues (server data, the rest
of the triggers, the world database) add their parts to this same command.

## Using it

```bash
luajit src/cli/wow-convert.lua [--strict] [--name NAME] [--textures FILE] [--models FILE]
    [--slot N | --map-id N] [--stock-dbc DIR | --no-stock] [--no-patch]
    [--dir DIR] <map.w3x> <build folder>
```

| Argument | Type | Meaning |
|----------|------|---------|
| `<map.w3x>` | path | the map (`.w3x` or `.w3m`) |
| `<build folder>` | path | where the files go; made if missing. The converter owns it: a run empties its own map's folder under `World/Maps/` first. Several maps may share one folder; each keeps its slot |
| `--strict` | flag | a chunk needing more than four textures stops the build (exit 1), naming the chunk |
| `--name NAME` | string | the WoW map directory (letters, digits, `_`, at most 48); default `WC3_` and the map file's name |
| `--textures FILE` | path | another ground texture table (default `src/wowbuild/ground_textures.lua`) |
| `--models FILE` | path | another WC3 type → WoW model table (default `src/wowbuild/models.lua`) |
| `--slot N` | 0-99 | the map's slot in the build folder (its ids: map 900 + N, ...); default: the slot it had, else the lowest free one. Refused when another map holds it |
| `--map-id N` | 900-999 | the same, by map id |
| `--stock-dbc DIR` | path | a folder of the client's stock `.dbc` files to merge with (AzerothCore's extracted `dbc` folder is one); default `/mnt/mtwo/games/azeroth-core/data-files/dbc` when it is there |
| `--no-stock` | flag | merge with no stock tables (no `server/dbc/`, no tables in `patch-W.MPQ`) |
| `--no-patch` | flag | don't write `patch-W.MPQ` |
| `--dir DIR` | path | this project's folder; found from the script's own path otherwise |

## What it writes

| File | Holds |
|------|-------|
| `World/Maps/<dir>/<dir>.wdt` | which ADT tiles exist; 8-bit blend maps |
| `World/Maps/<dir>/<dir>.wdl` | far-off heights, one 17 x 17 + 16 x 16 grid a tile |
| `World/Maps/<dir>/<dir>_<tx>_<ty>.adt` | one 533-yard tile (tx west to east, ty north to south): heights, normals, up to four texture layers with blend maps, water, the doodads; every chunk names the map's zone |
| `World/Maps/<dir>/<dir>_loading.blp` | the loading screen, made from the map's preview or its ground |
| `World/Maps/<dir>/registration.lua` | the map's slot, ids and table rows (data) |
| `<the map's own models>` | the map's imported models the placements use, at their own paths |
| `DBFilesClient/<Table>.dbc` | Map, AreaTable, LoadingScreens, CreatureDisplayInfo, CreatureModelData, FactionTemplate, Faction: the folder's maps' rows only (the W client's overlay) |
| `map.lua` | which map the W client opens: id, folder, start, the WC3 -> WoW transform (data) |
| `war3map.w3e` | the map's own ground file, copied whole, for the W client's WC3-tileset ground |
| `war3map.w3i` | the map's own info file, copied whole, for the W client's WC3 water tint and fog |
| `world/creatures-<id>.tsv` | the spawns, for the W client's `--world` |
| `server/world.sql` | creature templates, models and spawns |
| `server/dbc.sql` | the tables' rows for AzerothCore's `<table>_dbc` copies |
| `server/dbc/<Table>.dbc` | the stock tables with these maps' rows added (with stock tables only) |
| `patch-W.MPQ` | every map's ground files and loading screen, and the merged tables (with stock tables), for the stock client and AzerothCore's extractors |
| `server/triggers/<dir>/war3map.lua` | the map's script, transpiled to Lua for the server's shim (W02e) |
| `server/triggers/<dir>/map-data.lua` | what the shim reads of the build: map id, the WC3 -> WoW transform, templates, factions, spawns, the script's globals, typed stand-ins, constants (data) |
| `server/triggers/<dir>/natives-report.lua` | every native and Blizzard.j function the script calls, how often, whether the shim has it, what the project's own runtime does with it; the unit types the script makes with no creature template (data) |
| `server/ale/wc3shim/*.lua`, `server/ale/LICENSE` | the server's shim (`server-side/ale/wc3shim/`, AGPL v3), copied as bytes for the install, without its stand-in for ALE (W02f) |
| `install-plan.lua` | what installing the build into AzerothCore means: the SQL files in order and their database, each statement's table, columns and rows, each file to one of the server's folders, what isn't installed and why, what isn't built (data; W02f, nothing installs it yet) |
| `server-stamp` | the files of the folder the server reads, each with its CRC-32 and size, written last; the editor's Test Map reuses the running server while it is the same (W02f) |
| `placements.lua` | every doodad, unit and start location and what became of it (data) |
| `conversion-report.lua` | data: files, placement, layer counts, texture folds, unmapped types, the registration, the triggers' coverage counts, warnings, the stages not built yet. `placement.client` is where the map lands in the W client's world (`client x = x0 + scale * wc3 y`, `client y = y0 - scale * wc3 x`, yards; the map's bounds in `wc3_min`, `wc3_max`): Test Map turns its camera through it (`wowbuild.coords.wc3_to_client`), checked against `map.lua`'s `wc3_to_wow` |

A summary goes to stdout (Test Map keeps it as `convert.log`).

Exit status: 0 built; 1 the map couldn't be converted (why on stderr);
2 bad options.

StormLib reads the map and writes `patch-W.MPQ` (`src/mpq/stormlib.lua`;
`$STORMLIB_PATH` names another library).

Issues: `issues/W02a-terrain-to-adt-writer.md`,
`issues/W02b-doodads-and-units-to-placements.md`,
`issues/W02c-map-registration-and-output-forms.md`,
`issues/W02f-launcher-and-loader.md`

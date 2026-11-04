# wow-convert.lua

W02's converter: builds a WC3 map into WoW 3.3.5a's files in a build folder.
The map editor's Test Map (issue 913) runs it as
`<convert...> <map.w3x> <build folder>`; set the editor's
`test_map.convert` to `{ "luajit", "<project>/src/cli/wow-convert.lua" }`.

**Builds today only the terrain (W02a).** W02's later sub-issues (doodads
and units, map registration and `patch-W.MPQ`, server data, triggers, the
world database) add their parts to this same command.

## Using it

```bash
luajit src/cli/wow-convert.lua [--strict] [--name NAME] [--textures FILE] [--dir DIR] <map.w3x> <build folder>
```

| Argument | Type | Meaning |
|----------|------|---------|
| `<map.w3x>` | path | the map (`.w3x` or `.w3m`) |
| `<build folder>` | path | where the files go; made if missing. The converter owns it: a run empties its own map's folder under `World/Maps/` first |
| `--strict` | flag | a chunk needing more than four textures stops the build (exit 1), naming the chunk |
| `--name NAME` | string | the WoW map directory (letters, digits, `_`, at most 48); default `WC3_` and the map file's name |
| `--textures FILE` | path | another ground texture table (default `src/wowbuild/ground_textures.lua`) |
| `--dir DIR` | path | this project's folder; found from the script's own path otherwise |

## What it writes

| File | Holds |
|------|-------|
| `World/Maps/<dir>/<dir>.wdt` | which ADT tiles exist; 8-bit blend maps |
| `World/Maps/<dir>/<dir>.wdl` | far-off heights, one 17 x 17 + 16 x 16 grid a tile |
| `World/Maps/<dir>/<dir>_<tx>_<ty>.adt` | one 533-yard tile (tx west to east, ty north to south): heights, normals, up to four texture layers with blend maps, water |
| `conversion-report.lua` | data: files, placement, layer counts, texture folds, unmapped ground types, water, the stages not built yet. `placement.client` is where the map lands in the W client's world (`client x = x0 + scale * wc3 y`, `client y = y0 - scale * wc3 x`, yards; the map's bounds in `wc3_min`, `wc3_max`): Test Map turns its camera through it (`wowbuild.coords.wc3_to_client`) |

A summary goes to stdout (Test Map keeps it as `convert.log`).

Exit status: 0 built; 1 the map couldn't be converted (why on stderr);
2 bad options.

StormLib reads the map (`src/mpq/stormlib.lua`; `$STORMLIB_PATH` names
another library).

Issue: `issues/W02a-terrain-to-adt-writer.md`

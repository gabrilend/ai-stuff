# Issue 911c: Map Projects — the Unified Format as a Folder (and a .wex)

**Phase:** 9 (editor)
**Type:** Implementation
**Priority:** Critical
**Parent:** 911 (map format and export)
**Dependencies:** 911a (writing WC3 files back), 911b (new maps), 908a (the map's files named)

---

## Current Behavior

- **Maps are MPQ archives only:** there's no format a person can diff, keep in version control, or edit outside the editor.
- **Protected maps:** DAoW 5.4b strips its listfile, and 83 of its files have no known name. A new archive built from its files by name would lose them: the game finds each one by its hash-table slot.

## Intended Behavior

### The project (`editor/mapfile.lua`)

A map becomes a folder of files. Where it can be, it's text: Lua data, or the file's own text. The rest is kept as it is.

| In the folder | From |
|---|---|
| `manifest.lua` | the format; the map's name and 512-byte header; the archive's whole hash table (every slot, deleted ones too, with the file it finds); and each file's place and form |
| `info.lua` | `war3map.w3i` as Lua |
| `terrain/terrain.lua` + `terrain/points.txt` | `war3map.w3e`: the header as Lua, the points one map row a line, in hex |
| `objects/doodads.lua`, `objects/units.lua` | `war3map.doo`, `war3mapUnits.doo`: one item a line |
| `objects/regions.lua` | `war3map.w3r` |
| `definitions/*.lua` | the seven object-type files: one type a line |
| `scripts/` | the script, the strings, the editor's triggers, AI profiles, other text |
| `assets/` | the imports, at their paths |
| `map/` | other map files as they are (pathing, shadows, minimap, preview) |
| `unnamed/` | files nobody names, by block |
| `wow/` | reserved for the WoW layer of 911's design |

### Export and build

- **Readable forms:** a form is used only if it gives the file back byte for byte (checked when exporting). Otherwise the file is kept as it is.
- **Floats:** Lua data is written so every number comes back exactly, `-0.0` included.
- **Building:** gives back a `.w3x` whose archive puts every file in its original hash-table slot. Every lookup, named or not, finds what it found before.
  - Edits in the text reach the map.
  - Files added under `assets/` are imported by their path and listed.
  - Files taken away are taken out.
  - The hash table grows only when it must, and that can't happen with unnamed files in it.
- **Validation** (`validate(dir, "wc3")`) reports:
  - missing or broken forms;
  - files taken away;
  - stray files;
  - the WoW layer: `wow/` content is left out of a WC3 build, with a warning.
- **Lightweight projects** (`export(..., { lightweight = true })`) leave the assets out. A build then needs `assets_from`: the original map, or a full project.

### One file

- **`.wex`:** `pack(dir, file.wex)` / `unpack(file, dir)` store the folder as a ZIP (no compression), with CRC-32s checked on reading.
- **Refused on unpacking:** paths out of the folder, and compressed entries.

### The editor

- **Opening:** `editor.open(project)` builds a project folder or `.wex` into a map to edit.
- **Saving:** `E:save()` with no path (and the window's Save) writes the project back: the folder, and the `.wex` if it came from one.
- **`wow/` is kept** across saves.

### Command line

```
luajit src/editor/mapfile.lua export MAP DIR [--light] | build DIR OUT [ASSETS_FROM] | pack DIR FILE | unpack FILE DIR | validate DIR
```

## Acceptance Criteria

- [x] Unified format saves all map data: DAoW 5.4b's 201 files, 83 of them unnamed; its header and hash table
- [x] Unified format loads correctly: built back, every hash slot finds the same bytes (DAoW 5.4b 201/201, Daow4.4 31/31), and the game plays the built map
- [x] WC3 import converts to unified format (export)
- [x] Validation reports export issues (missing files, the WoW layer)
- [x] Lightweight export excludes assets, and builds with them from elsewhere
- [x] Format is version-control friendly: text for the map's data; the terrain, doodads, units and object types one row or item per line
- [x] Edits made as text reach the map: the name, a doodad, a terrain point, an object type, an asset added, one taken away
- [x] One `.wex` file, packed and unpacked, damage refused
- [x] The editor opens a `.wex`, edits it, saves it back, and reopens it with the edits
- [x] The command line: export, validate, build (Daow4.4 slot for slot)

## Notes

- **Tests:** `src/tests/test_mapfile.lua` (36 tests).
- **Mode-specific data:** there is no WoW gameplay layer in the engine yet. A project reserves `wow/` for it, and a WC3 build leaves it out with a warning.
- **Not readable yet:** the script stays JASS text; the pathing, shadow and minimap files stay binary. The WE's own `war3map.wtg` / `war3map.wct` are carried as they are when a map has them.
- **Tables, not a ZIP folder layout:** 911's design sketched separate terrain files (`heightmap.bin`, `textures.bin`, …). Instead, one text row per map row holds every field of a point, which keeps the terrain diffable.

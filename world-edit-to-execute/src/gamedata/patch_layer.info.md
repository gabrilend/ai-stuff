# patch_layer.lua

Turns a Warcraft III patch program into a stored layer: every file the patch
produces, built by applying its entries to their bases, without running it.

## Functions

| Function | Takes | Gives |
|----------|-------|-------|
| `build(options)` | table: `patch_program` (path), `install` (Frozen Throne folder), `base_archives` (list of archive names, lowest priority first), `version` (string, e.g. `"1.21b"`), `output` (layer folder), `scratch` (temporary folder) | the manifest table (also written to `<output>/manifest.lua`); raises an error naming the first entry it can't build |

## Layer layout

| Path | Holds |
|------|-------|
| `archive/<path>` | the files the rebuilt `War3Patch.mpq` would hold (backslashes become `/`) |
| `install/<path>` | loose install files (maps, `game.dll`, `war3.exe`), in `patch.lst`'s spelling |
| `manifest.lua` | `version`, `built` (UTC time), `patch_program` (file, size, CRC32), `requires_older_than` (from `patch.cmd`), `base_archives`, `deleted` (from `delete.lst`), `counts`, and `entries`: `{target, place ("archive"/"install"), kind ("diff"/"whole"), base (where the old file came from), size, crc32}` |

A patch rebuilds its whole data archive from its list, so a layer is complete
by itself; layers replace each other rather than stacking.

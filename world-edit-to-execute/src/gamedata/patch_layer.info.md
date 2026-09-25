# patch_layer.lua

Turns a Warcraft III patch program into a stored layer: every file the patch
produces, built by applying its entries to their bases, without running it.

## Functions

| Function | Takes | Gives |
|----------|-------|-------|
| `build(options)` | table: `patch_program` (path), `install` (Frozen Throne folder), `base_archives` (list of archive names, lowest priority first), `version` (string, e.g. `"1.21b"`), `output` (layer folder), `scratch` (temporary folder), optional `lower_layers` (list of `{name, folder}`, highest first) | the manifest table (also written to `<output>/manifest.lua`); raises an error naming the first entry it can't build and the places it tried |
| `target_version(program, scratch, install)` | patch program path; temporary folder; Frozen Throne folder | the version it produces (string, `"1.25.1.6397"`) and the same as four integers (list), read from the `War3.exe` it writes; raises if its script states a different real version |

## Layer layout

| Path | Holds |
|------|-------|
| `archive/<path>` | the files the rebuilt `War3Patch.mpq` would hold (backslashes become `/`) |
| `install/<path>` | loose install files (maps, `game.dll`, `war3.exe`), in `patch.lst`'s spelling |
| `manifest.lua` | `version`, `built` (UTC time), `patch_program` (file, size, CRC32), `requires_older_than` (from `patch.cmd`; a 1.99.99.9999 placeholder from 1.25b on), `base_archives`, `lower_layers` (names offered as bases, highest first), `deleted` (from `delete.lst`), `counts`, and `entries`: `{target, place ("archive"/"install"), kind ("diff"/"whole"), base (where the old file came from: an archive name, `"install"`, or `"layer <name>"`), size, crc32}` |

A patch rebuilds its whole data archive from its list, so a layer's archive
files are complete by themselves. Its install files are not: a file the patch
doesn't list stays as the version below left it. Versions are built in
order, each offered the layers below as bases; a diff's base is the first
copy (highest layer first, then the disc) whose size and CRC32 match the
diff's header.

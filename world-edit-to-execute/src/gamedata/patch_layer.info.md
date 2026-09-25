# patch_layer.lua

Turns a Warcraft III patch program into a stored layer: every file the patch
produces, built by applying its entries to their bases, without running it.

## Functions

| Function | Takes | Gives |
|----------|-------|-------|
| `build(options)` | table: `patch_program` (path), `install` (Frozen Throne folder), `base_archives` (list of archive names, lowest priority first), `version` (string, e.g. `"1.21b"`), `output` (layer folder), `scratch` (temporary folder), optional `lower_layers` (list of `{name, folder}`, highest first) | the manifest table (also written to `<output>/manifest.lua`); raises an error naming the first entry it can't build and the places it tried |
| `program_version(path)` | a Windows program file | its stamped file version (string, `"1.29.2.9231"`); raises if it has none |
| `build_install(options)` | table: `version`, `source_folder` (the fetched files), `archive_order` (names, highest priority first), `game_program`, `editor_program` (file names), `checksums` (name → sha256 from the fetch record), `output` | an install layer for a version with no patch program: archives hard-linked into `<output>/archives/`, manifest with `kind = "install"`, `archive_order`, `archives` ({name, size, sha256}), `game_version`, `editor_builds` (candidate constants, noisy) |
| `target_version(program, scratch, install)` | patch program path; temporary folder; the install folder | the version it produces (string, `"1.25.1.6397"`), the same as four integers (list), and where it came from (string): the `War3.exe` it writes, or, where that is a large binary in the oldest diff format that can't be rebuilt, the script's threshold (said so); raises if the version made is below the script's threshold, or the script has no active check (an incremental patch) |

## Layer layout

| Path | Holds |
|------|-------|
| `archive/<path>` | the files the rebuilt `War3Patch.mpq` would hold (backslashes become `/`) |
| `install/<path>` | loose install files (maps, `game.dll`, `war3.exe`), in `patch.lst`'s spelling |
| `manifest.lua` | `version`, `built` (UTC time), `patch_program` (file, size, CRC32), `requires_older_than` (from `patch.cmd`: a threshold, the version made or just below it; a 1.99.99.9999 placeholder from 1.25b on), `run_step` (the diffs' run-length step, chosen from that threshold's build number), `base_archives`, `lower_layers` (names offered as bases, highest first), `deleted` (from `delete.lst`), `counts`, and `entries`: `{target, place ("archive"/"install"), kind ("diff"/"whole"), base (where the old file came from: an archive name, `"install"`, or `"layer <name>"`), size, crc32}` |

A patch rebuilds its whole data archive from its list, so a layer's archive
files are complete by themselves. Its install files are not: a file the patch
doesn't list stays as the version below left it. Versions are built in
order, each offered the layers below as bases; a diff's base is the first
copy (highest layer first, then the disc) whose size and CRC32 match the
diff's header.

## Finding the patch archive

From 1.14b the outer archive names it in `mpqs.lst`. Programs from 1.11 and
before have unnamed inner files; the patch is the inner archive with a
non-empty `patch.lst`.

## Not built

A manifest's `not_built` lists entries left out, each `{target, reason}`: only
the program binaries over a megabyte in the oldest diff format (War3.exe,
Game.dll, WorldEdit.exe in 1.01–1.14b; issue 112d). The chain never reads
install files, so a layer's game data is complete. Any other entry that
fails stops the build.

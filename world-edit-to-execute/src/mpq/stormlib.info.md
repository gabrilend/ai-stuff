# stormlib.lua

LuaJIT binding to StormLib, the open-source library for Blizzard's MPQ
archives, and the project's only MPQ reader: maps through the `mpq` module
(`src/mpq/init.lua`), and stock archives, patch programs and the game data
chain directly (issue 114). StormLib is built by
`scripts/build-dependencies.sh` into `deps/stormlib/lib/libstorm.so`.

## Functions

| Function | Takes | Gives |
|----------|-------|-------|
| `open(path, lib_path)` | archive path (string); an `.exe` with an archive inside works too. Optional path to `libstorm.so` | an Archive, or raises an error with StormLib's error code |
| `Archive:list(mask, listfile)` | wildcard (string, default `"*"`); optional path of an extra listfile (string; raises if it is missing or empty) | list of entries: `name` (string), `size` (uint32, bytes), `compressed_size` (uint32), `flags` (uint32 bit mask), `locale` (uint32; 0 = neutral), `hash_index`, `block_index` (uint32 table positions). One name can appear more than once |
| `Archive:has(name)` | file name (string, backslash paths) | boolean |
| `Archive:read(name)` | file name, or a position name `FileNNNNNNNN.ext` (the block index, 8 digits) for a file with no known name or a duplicate copy | the file's bytes (string), or raises an error naming the file |
| `Archive:extract(name, dest_path)` | file name; destination path | writes the file; raises on failure |
| `Archive:close()` | — | releases StormLib's handle |

## Notes

- If `libstorm.so` isn't built, loading raises an error naming the build
  script; there is no silent switch to the project's own reader.
- `SFILE_FIND_DATA`'s layout is checked by size at load (1064 bytes on 64-bit
  Linux, StormLib v9.40); a mismatch raises an error.

Issue: `issues/completed/112a-stormlib-build-and-update-script.md`

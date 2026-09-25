# stormlib.lua

LuaJIT binding to StormLib, the reference open-source library for Blizzard's
MPQ archives. It reads every archive the project's own reader can't (patch
programs, expansion archives, WoW data) and serves as the second reader the
project's own is checked against. StormLib is built by
`scripts/build-dependencies.sh` into `deps/stormlib/lib/libstorm.so`.

## Functions

| Function | Takes | Gives |
|----------|-------|-------|
| `open(path, lib_path)` | archive path (string); an `.exe` with an archive inside works too. Optional path to `libstorm.so` | an Archive, or raises an error with StormLib's error code |
| `Archive:list(mask, listfile)` | wildcard (string, default `"*"`); optional path of an extra listfile (string) | list of entries: `name` (string), `size` (uint32, bytes), `compressed_size` (uint32), `flags` (uint32 bit mask), `locale` (uint32; 0 = neutral), `hash_index`, `block_index` (uint32 table positions). One name can appear more than once |
| `Archive:has(name)` | file name (string, backslash paths) | boolean |
| `Archive:read(name)` | file name | the file's bytes (string), or raises an error naming the file |
| `Archive:extract(name, dest_path)` | file name; destination path | writes the file; raises on failure |
| `Archive:close()` | — | releases StormLib's handle |

## Notes

- If `libstorm.so` isn't built, loading raises an error naming the build
  script; there is no silent switch to the project's own reader.
- `SFILE_FIND_DATA`'s layout is checked by size at load (1064 bytes on 64-bit
  Linux, StormLib v9.40); a mismatch raises an error.

Issue: `issues/112a-stormlib-build-and-update-script.md`

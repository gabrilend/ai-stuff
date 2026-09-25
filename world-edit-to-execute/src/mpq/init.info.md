# mpq (src/mpq/init.lua)

Opens Warcraft III maps and reads the files inside, through StormLib
(`stormlib.lua`). Every map parser, the map loader and the tools use it.

| Function | Takes | Gives |
|----------|-------|-------|
| `mpq.open(path)` | a map or MPQ archive path (string) | an Archive, or `nil` and a message |
| `Archive:has(name)` | file name (string, backslash paths) | boolean |
| `Archive:extract(name)` | file name, or a position name `FileNNNNNNNN.ext` | the bytes (string), or `nil` and a message |
| `Archive:extract_to_file(name, path)` | file name; output path | `true`, or `nil` and a message |
| `Archive:list()` | — | every stored file's name (list of strings): known names, `FileNNNNNNNN.ext` for files with no known name, and for a name stored twice both copies by position as well as the name once |
| `Archive:file_count()` | — | files stored (integer, distinct storage positions) |
| `Archive:info()` | — | `filepath` (string), `file_size` (bytes), `file_count`, and from the map wrapper (`map_wrapper.lua`) `map_name`, `max_players`, `map_flags` |
| `Archive:close()` | — | releases the handle; later calls raise |

Nothing here raises for a missing file: callers ask for optional map files
and branch on the answer. Issue: `issues/completed/114-read-maps-through-stormlib.md`.

# standard_names.lua

The file names a Warcraft III map normally holds. Protected maps strip or
falsify their own `(listfile)`, so tools use this list to find the usual files
by name anyway.

## Contents

| Name | Type | Meaning |
|------|------|---------|
| `MAP_FILES` | list of strings | `war3map.w3i`, `war3map.w3e`, `war3map.j`, the object-data files, `(listfile)` and so on (backslash paths) |
| `write_listfile()` | function → string | writes the names to a temporary file, one per line, and returns its path; the caller removes it |

Used by `src/cli/mpq-extract.lua` and `src/tests/test_stormlib.lua`.

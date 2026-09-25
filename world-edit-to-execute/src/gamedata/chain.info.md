# chain.lua

The game data a map sees: the Frozen Throne archives, at most one patch
layer, and the map's data set, assembled in memory per map. Nothing on disk
is changed.

## Functions

| Function | Takes | Gives |
|----------|-------|-------|
| `open(options)` | table: `install` (folder), `layers` (folder of layers), `w3i` (parsed `war3map.w3i`: needs `version`, `editor_version`); optional `layer` (a name to force, or `false` for unpatched), `editor_versions` (table like `editor_versions.lua`) | a Chain |
| `data_set_for(w3i)` | parsed w3i | `"Custom_V0"` (w3i version 18) or `"Custom_V1"` |
| `choose_layer(w3i, layers, options)` | as above | layer name or `nil`; reason (string); fallback (boolean) |
| `Chain:read(path)` | a game path (backslashes), e.g. `Units\UnitWeapons.slk` | bytes (string) and where they came from (string); raises if nothing has it |
| `Chain:find(path)` | same | source name and the matched path, or `nil` |
| `Chain:report()` | — | text: data set, layer and why, warnings |
| `Chain:close()` | — | closes the archives |

## Lookup order

For each of `"<data set>\<path>"`, then `"<path>"`: the layer's files, then
`War3xlocal.mpq`, `War3x.mpq`, `war3.mpq`. A map with no known editor version
gets the newest built layer, and that fallback is listed in `warnings`.

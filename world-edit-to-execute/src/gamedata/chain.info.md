# chain.lua

The game data a map sees: the map's own archive, the Frozen Throne archives,
at most one patch layer, and the map's data set, assembled in memory per map. Nothing on disk
is changed.

## Functions

| Function | Takes | Gives |
|----------|-------|-------|
| `open(options)` | table: `install` (folder), `layers` (folder of layers), `w3i` (parsed `war3map.w3i`: needs `version`, `editor_version`, `game_data_set`, `flags.melee_map`); optional `map` (the map file, searched first), `layer` (a name to force, or `false` for unpatched), `editor_versions` (table like `editor_versions.lua`) | a Chain |
| `data_set_for(w3i)` | parsed w3i: needs `version`, `game_data_set`, `flags.melee_map` | the folder (`"Custom_V0"`, `"Custom_V1"`, `"Melee_V0"`, or `false` for the plain Frozen Throne melee tables) and the choice (`"custom"`/`"melee"`); raises for a value outside 0–2 |
| `choose_layer(w3i, layers, options)` | as above | layer name or `nil`; reason (string); fallback (boolean) |
| `Chain:read(path, options)` | a game path (backslashes), e.g. `Units\UnitWeapons.slk`; optional `{below_map = true}` to skip the map | bytes (string) and where they came from (string, `"map: ..."` when the map's copy won); raises if nothing has it |
| `Chain:find(path, options)` | same | source name (`"map"`, `"layer <name>"` or an archive name) and the matched path, or `nil` |
| `Chain:report()` | — | text: data set and layer, and why |
| `Chain:close()` | — | closes the archives |

## Lookup order

First the map's own archive, for either path below: the game opens a map
above every other source, and map optimizers ship whole object tables there
(DAoW-5.2's custom abilities are defined only in its own
`Units\AbilityData.slk`). Then, for each of `"<data set>\<path>"` (when the map's choice has a
folder), then `"<path>"`: the layer's files, then
`War3xlocal.mpq`, `War3x.mpq`, `war3.mpq`. A map whose editor build has
no entry in `editor_versions.lua`, or whose layer isn't built, is an
error naming what to fetch. An install layer (manifest `kind = "install"`,
1.29.2) replaces the disc's archives with its own, in its `archive_order`.

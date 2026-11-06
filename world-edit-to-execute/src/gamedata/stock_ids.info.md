# stock_ids.lua

Which object ids the game itself defines, as a map's game data chain has
them. The cross-reference validator (`src/validation/init.lua`) asks it about
ids a map uses but doesn't define (issue 112).

## Functions

| Function | Takes | Gives |
|----------|-------|-------|
| `from_chain(chain)` | a chain (`gamedata/chain.lua`, opened with the map so its own tables count) | a lookup; nothing is read until a kind is first asked about |
| `from_sets(sets, searched)` | kind (string) → id (string) → `true`; optional description (string) | a lookup over those sets; a kind left out counts as a table the chain lacks |
| `is_random_placeholder(id)` | an id (string) | `true` for the editor's random-object ids (`YYU`/`YYI` + a level character, `uDNR`, `bDNR`, `iDNR`), which no table defines |
| `lookup:has(kind, id)` | a kind (below); an id | `true` listed, `false` not listed, `nil` when the chain has no such table; raises for an unknown kind |
| `lookup:find(kinds, id)` | a list of kinds; an id | the first kind listing it; `false` when every table was read and none does; `nil` when none does and a table was missing |
| `lookup:missing(kind)` | a kind | the table's path when the chain lacks it, else `nil` |
| `lookup.searched` | — | what was searched, for messages: `"patch layer 1.29.2, data set Custom_V1"` |

## Kinds and their tables

| Kind | Table (first column = the id) |
|------|-------------------------------|
| `unit` | `Units\UnitData.slk` |
| `item` | `Units\ItemData.slk` |
| `ability` | `Units\AbilityData.slk` |
| `destructible` | `Units\DestructableData.slk` |
| `doodad` | `Doodads\Doodads.slk` |

Each table is read once, through the chain, so the map's own copy (map
optimizers ship them), its patch layer and its data set are what count.

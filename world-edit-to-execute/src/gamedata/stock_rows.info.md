# stock_rows.lua

Each object in a map's object file as a full row: its stock parent's row
(read through the map's game data chain) with the map's changes on top. Every
column is copied, and every column is labelled by whose it is.

## Functions

| Function | Takes | Gives |
|----------|-------|-------|
| `load(chain, kind)` | a chain (`gamedata/chain.lua`, opened with the map so its own tables count); `"abilities"`, `"units"` or `"items"` | stock: metadata, tables, profile entries, `missing` (profile files not in the chain), `map_defined` (ids only the map's own copy of a table has → `true`), column-type index |
| `merge(stock, parsed)` | stock; the object file parsed by `parsers/objectdata.lua` | `{rows, problems, counts}` |

## Result

| Field | Type | Meaning |
|-------|------|---------|
| `rows` | id (string) → `{id, parent, fields, origin, defined_in}` (`defined_in = "map table"` for objects only the map's own table has; their parent is their base ability code, else themselves) | `fields` is table name (`AbilityData`, `UnitBalance`, …, `Profile`) → column → value (number or string); `origin` has the same shape, each value a label string |
| `problems` | list of `{kind, object, code, problem}` | `kind` is `"orphan"` (changes filed under an id that is neither stock nor one of the map's objects), `"unknown_parent"`, or `"unknown_code"` (a field code with no metadata row) |
| `counts` | table of integers | `objects`, `changes`, `applied`, `borrowed` (columns across all rows still holding Blizzard's text or art), `map_table_only` (objects defined only in the map's own tables), and one per problem kind |

## Rules

A change's column comes from its metadata row: `field .. level` for
level-dependent fields (`Cool1`), `"Data" .. letter .. level` for ability data
fields (`DataA1`), else `field`. Profile files keep level-dependent fields
under their bare name (`Tip`), all levels in one comma-separated value.

Labels (`field_rules.lua`): `"map"` when the map's changes set the column;
otherwise `"fact"` for ids in `id_columns` and for columns whose metadata type
isn't in `borrowed_types`, `"borrowed"` for those that are, and `"editor"` for
columns no metadata row describes (comments, sort keys).

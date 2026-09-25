# stock_rows.lua

Each object in a map's object file as a full row: its stock parent's row
(read through the map's game data chain) with the map's changes on top,
functional fields only.

## Functions

| Function | Takes | Gives |
|----------|-------|-------|
| `load(chain, kind)` | a chain (`gamedata/chain.lua`); `"abilities"`, `"units"` or `"items"` | stock: metadata, tables, profile entries, `missing` (profile files not in the chain), column-type index |
| `merge(stock, parsed)` | stock; the object file parsed by `parsers/objectdata.lua` | `{rows, problems, counts}` |

## Result

| Field | Type | Meaning |
|-------|------|---------|
| `rows` | id (string) → `{id, parent, fields}` | `fields` is table name (`AbilityData`, `UnitBalance`, …, `Profile`) → column → value (number or string) |
| `problems` | list of `{kind, object, code, problem}` | `kind` is `"orphan"` (changes filed under an id that is neither stock nor one of the map's objects), `"unknown_parent"`, or `"unknown_code"` (a field code with no metadata row) |
| `counts` | table of integers | `objects`, `changes`, `applied`, `not_functional`, and one per problem kind |

## Rules

A change's column comes from its metadata row: `field .. level` for
level-dependent fields (`Cool1`), `"Data" .. letter .. level` for ability data
fields (`DataA1`), else `field`. A column is kept when its metadata type isn't
in `field_rules.dropped_types`, or it is in `field_rules.always_kept`; columns
no metadata row describes (editor comments, sort keys) are dropped.

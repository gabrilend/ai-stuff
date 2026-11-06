# unit_visuals.lua

Each unit type's art fields, read from object data: the map's changes over
the stock row (issue 503b). What 516's model chooser looks a model up by,
and what 503a's placeholder shapes fall back on.

## Functions

| Function | Takes | Gives |
|----------|-------|-------|
| `of(stock, merged, id)` | `stock_rows.load(chain, "units")`; `stock_rows.merge`'s result (or `nil`/`{rows = {}}`); a unit type id | the row, or `nil` and a problem `{kind = "unknown_type", id, problem}` |
| `for_types(stock, merged, ids)` | as above; a list of ids (duplicates read once) | `{rows = id → row, problems = list, counts = {types, from_map, unknown}}` |
| `placeholder(row)` | a row (or any table with `building`, `flyer`, `selection`) | `"cube"`, `"triangle"`, `"cylinder"` or `"circle"` |
| `CODES` | — | field name → metadata code |
| `LARGE_SELECTION` | — | 1.5: the selection scale from which a ground unit is a cylinder |

## A row

| Field | Type | Meaning |
|-------|------|---------|
| `id`, `parent` | string | the type, and its stock parent (itself for a stock type) |
| `model` | string or nil | the model path the map asks for (`umdl`); nil when blank or `_` |
| `scale` | number | `usca`, default 1 |
| `tint` | `{r, g, b}` | `uclr`, `uclg`, `uclb`, 0–255 each, default 255 |
| `selection` | number | `ussc`, default 1 |
| `building` | boolean | `ubdg` |
| `move_type`, `flyer` | string, boolean | `umvt` (`""` for none); `flyer` when it is `"fly"` |
| `shape` | string | `placeholder(row)` |
| `from_map` | field name → true | the fields the map's changes set |
| `no_metadata` | list of codes | codes the metadata table lacks (their defaults were used) |

Each field's table and column come from the metadata row for its code, so a
version keeping the model path in a profile file works too. A problem
`{kind = "no_metadata", code, problem}` is reported once per missing code.

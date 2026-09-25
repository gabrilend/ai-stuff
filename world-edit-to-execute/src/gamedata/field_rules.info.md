# field_rules.lua

Reviewed data used by `stock_rows.lua`: which stock tables and profile files
each object kind reads, and how each copied column is labelled. Every column
is copied; the label says whose it is.

| Key | Type | Meaning |
|-----|------|---------|
| `borrowed_types` | metadata type (string) → note (string) | columns of these types are Blizzard's text or art (names, tooltips, icon/model/sound paths), labelled `"borrowed"`; the note says what replaces them |
| `id_columns` | table name → column → reason | columns no metadata row describes that are still facts (ids, an ability's base `code`); any other column without a metadata row is labelled `"editor"` |
| `kinds` | kind name → `{map_file, has_levels, metadata, tables, profiles}` | `tables` maps the metadata's `slk` names to paths; `profiles` lists INI-style text files (the `*Func.txt` and `*Strings.txt` files) |

Labels: `"fact"` (numbers, flags, ids, order strings), `"borrowed"`,
`"editor"`, and `"map"` (set by the map's own changes, given by `stock_rows`).

Kinds so far: abilities, units, items. Buffs, upgrades, destructibles and
doodads follow the same shape when needed.

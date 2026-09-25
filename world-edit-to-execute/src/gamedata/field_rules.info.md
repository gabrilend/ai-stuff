# field_rules.lua

Reviewed data used by `stock_rows.lua`: which stock tables and profile files
each object kind reads, and which fields count as functional.

| Key | Type | Meaning |
|-----|------|---------|
| `dropped_types` | metadata type (string) → reason (string) | fields of these types are text or asset paths and are dropped |
| `always_kept` | table name → column → reason | columns no metadata row describes but the game needs (ids, an ability's base `code`) |
| `kinds` | kind name → `{map_file, has_levels, metadata, tables, profiles}` | `tables` maps the metadata's `slk` names to paths; `profiles` lists INI-style text files |

Kinds so far: abilities, units, items. Buffs, upgrades, destructibles and
doodads follow the same shape when needed.

<!-- made by scripts/build-info-pages from the comments in 004-catalogue.lua; change the comments and rebuild, not this page -->
# 004-catalogue


Reads the data files the world is made of (assets/catalogue/), lays any
enabled mods over them (mods/<name>/), and checks every entry against its
schema before anything else runs, so a broken entry stops the program at
start-up with the file and field named, never in the middle of a round.

## Functions other files call

| Name | Takes | What it does |
| --- | --- | --- |
| `M.load` | `dir, mods` | Returns { weapons = {...}, ["unit-types"] = {...}, regions = {...}, perks = {...} }, each a table of entry name → entry. |

## Tables of rows

| Name | What it is |
| --- | --- |
| `FILES` | The four files, in the order they are checked: weapons first, because unit types name weapons and perks name unit types and weapons. |
| `COLOR` | (no comment in the source) |
| `SWING_KINDS` | (no comment in the source) |
| `SCHEMA` | Field → what it must be. `ref` names another catalogue file the value must be an entry of; `list` means a list whose items must each be that type. |
| `KIND_CHECKS` | Special checks by kind of field, so a new kind is a new row. |

## Private helpers

| Name | Takes | What it does |
| --- | --- | --- |
| `check_color` | `v, where` | (no comment in the source) |
| `check_damage` | `v, where` | (no comment in the source) |
| `check_list` | `v, item, where` | (no comment in the source) |
| `check_entry` | `file, name, entry, all` | (no comment in the source) |
| `check_perk_refs` | `cat` | Perks name unit types or weapons through their value, depending on the effect, so they are checked once every file is known. |

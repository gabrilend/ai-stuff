# 201 — The World Is Made Of Catalogue Entries

| | |
| --- | --- |
| Phase | 2 — Bodies on the field |
| Blocked by | 101 |
| Blocks | 203, 504, 601, 602, 604 |
| Files | `src/004-catalogue.lua`, `assets/catalogue/weapons.lua`, `assets/catalogue/unit-types.lua`, `assets/catalogue/perks.lua`, `assets/catalogue/regions.lua` |
| Reads | `docs/datapath-catalogue-and-perks.md` |

## Current behavior

Built: `src/004-catalogue.lua` with its schema as data, and the four files
in assets/catalogue/. Weapons: two-handed sword, spear, halberd. Unit types:
swordsman, mega spearman, beastwarrior, skirmisher. Eleven perks. Four
region kinds. Tested in tests/032-bodies-on-the-field.lua.

## Intended behavior

Four data files, each returning a table keyed by entry name:

- **weapons** — `reach` (cells), `swings` (which kinds it may make: stab,
  slash, overhead), `damage` (base damage per kind), `windup` and `recovery`
  multipliers, `brick_color`, `length` (metres, for drawing).
- **unit types** — `weapon` (a weapons name), `health`, `armor` (rating
  points), `thickness` (0 thin, 1 thick), `height` (scale, 1 normal),
  `traits` (a list of trait names the rules read: `always_critical`,
  `guard_while_advancing`, `stabs_only`, `throws_from_front`, `shield`).
- **perks** — `title`, `text`, `affects` ("all" or a count of soldiers),
  `effect` (a name from the perk effects dispatch table, see 601), and the
  effect's arguments.
- **regions** — kinds of ground: `ground_color`, `walk` multiplier, how many
  stones, fences, puddles the scenery scatters.

The loader reads each file with plain `io` into an empty environment, checks
every entry against a schema (field name, type, required or not, and that
names it refers to exist), and stops with "catalogue: weapons.zweihander:
damage.stab must be a number" when one is wrong. Unknown fields are errors.

## Suggested implementation steps

1. Write the schema as data beside the loader: field → { type, required }.
2. Write the four starter files. Only the two-handed sword is the base weapon;
   the spear exists for the mega spearman perk.
3. Test: the shipped catalogue loads; a broken entry stops the load naming
   the field.

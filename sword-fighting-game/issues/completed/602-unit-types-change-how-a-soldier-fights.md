# 602 — Unit Types Change How A Soldier Fights

| | |
| --- | --- |
| Phase | 6 — Growth |
| Blocked by | 201, 304, 601 |
| Blocks | 703 |
| Files | `assets/catalogue/unit-types.lua`, `src/011-hit-resolution.lua`, `src/012-soldier-mind.lua`, `src/008-movement.lua`, `src/013-ranged.lua` |

## Current behavior

Built: the traits are read in the files named; the skirmisher's slipping
back through the line is a `loose` trait (passes allies at full speed).
Tested in tests/035-command-and-growth.lua.

## Intended behavior

The traits each unit type carries are read where the rule they bend lives:

- **mega spearman** — spear (stabs only), armor at the maximum rating plus
  one (the shield), shield trait (parry bonus). Read by swings (stabs only)
  and resolution (shield bonus).
- **beastwarrior** — height 1.5, every hit critical (`always_critical`, read
  by resolution), may guard while walking forward (`guard_while_advancing`:
  others' guard slows their forward step to a shuffle; read by movement).
- **skirmisher** — throws from the front rank when the nearest enemy is
  between one and two battalion lengths away, then falls back through the
  loose formation (it passes allies without the half-speed penalty) to a
  further angle (`throws_from_front`, read by the mind and by ranged).

## Suggested implementation steps

1. Add the trait reads at each rule.
2. Test each trait's rule in isolation.

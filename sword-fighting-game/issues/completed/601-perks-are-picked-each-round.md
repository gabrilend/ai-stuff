# 601 — Perks Are Picked Each Round

| | |
| --- | --- |
| Phase | 6 — Growth |
| Blocked by | 201, 303, 501, 503 |
| Blocks | 602, 603 |
| Files | `src/015-perks.lua`, `assets/catalogue/perks.lua` |
| Reads | `docs/datapath-catalogue-and-perks.md` |

## Current behavior

Built in `src/015-perks.lua` with the effects table. The window and the
headless runner also accept `--perk` for a lone battle. Tested in
tests/035-command-and-growth.lua.

## Intended behavior

A contingent carries a list of perks taken. At battle setup every soldier is
built from its unit type and then every perk is applied, through a dispatch
table of perk effects:

| Effect | Does |
| --- | --- |
| `add_trait` | gives every affected soldier a trait (riposte, harry, bushido) |
| `convert_units` | turns a stated number of soldiers into a unit type (mega spearman, beastwarrior, skirmisher) |
| `add_armor` | adds armor rating points |
| `thicken` | sets thickness to thick (+2 armor points, slower walk) |
| `unlock_ranges` | lets volleys use ranges 1-3 (trained arc) |
| `crit_chance` | adds to critical chance |
| `swap_weapon` | gives every affected soldier another weapon (halberds) |

For a perk that affects a number of soldiers, converted soldiers are chosen
from the back ranks first, and **the player chooses** whether their own
soldier is one of them (the choice is recorded on the match). If no soldiers
of the needed kind are available the question is not asked and the player is
a normal soldier.

The enemy commander picks perks too, from the `perks` stream.

## Suggested implementation steps

1. Write the effects table and the apply step at battle setup.
2. Test: each effect changes what it says; the player's choice is honoured;
   a perk applied twice stacks only where its catalogue entry says it may.

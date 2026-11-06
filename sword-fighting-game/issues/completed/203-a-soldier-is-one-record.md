# 203 — A Soldier Is One Record

| | |
| --- | --- |
| Phase | 2 — Bodies on the field |
| Blocked by | 201 |
| Blocks | 204, 205, 301, 302, 303, 304, 403 |
| Files | `src/006-soldier.lua` |

## Current behavior

Built in `src/006-soldier.lua`. Beyond the planned fields the record
carries: cell_x, cell_y (the claimed cell), dodge and yield (movement in
progress), was_backing and was_siding (so trips fire when a step begins),
open (seconds unparryable after an overhead), look_offset (free look),
distance_walked (for the legs), hurt_flash (for the view), extra_armor,
crit_chance, thick_override, perk_traits, weapon_override, walk_mult and
awareness (derived), and the unit and weapon catalogue entries.

## Intended behavior

Every soldier, the player's included, is one flat record:

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | integer | unique within the battle |
| `team` | integer | 1 (the player's side) or 2 |
| `battalion` | integer | which battalion of its contingent |
| `slot_x`, `slot_y` | integers | its place in the battalion formation |
| `unit` | string | unit-type catalogue name |
| `x`, `y` | numbers | position in cells |
| `vx`, `vy` | numbers | velocity, cells per second |
| `facing` | number | radians, 0 = east, increasing clockwise on the map |
| `health`, `health_max` | numbers | |
| `stamina` | number | 0..1 |
| `armor` | number | rating points after perks |
| `thickness` | integer | 0 thin, 1 thick |
| `u` | number | position on the U, −1..1 |
| `lock` | soldier or false | who the U is drawn around |
| `lock_next`, `lock_timer` | soldier or false, seconds | the pending lock switch |
| `swing` | table or false | the swing in progress (see 302) |
| `last_side` | string | side of the previous swing, for momentum |
| `guard` | boolean | guarding now |
| `tripped` | seconds | time left lying down, 0 standing |
| `stagger` | seconds | time left reeling after being hit or parried |
| `alive` | boolean | |
| `traits` | table | trait name → true, from the unit type and perks |
| `is_player` | boolean | |
| `mind` | table | the soldier mind's private state (see 304) |

Construction takes the unit-type entry and the contingent's perks and fills
the derived numbers once; nothing recomputes them per tick.

## Suggested implementation steps

1. Write the constructor and a `refresh` that recomputes the derived numbers
   after a perk is applied (used by replenish).
2. Test: the constructor's fields match the catalogue; a thick unit type
   carries two more armor points.

# 025-unit-table

Stat rows for every kind of body, and what a wave is made of.

## What it is for

Every body in the game is one record with different numbers in it. This is the
table of those numbers.

**Durations are whole numbers of ticks, never seconds.** Two machines have to
agree about *when* even though they are allowed to disagree in the last bit about
*where*, and a duration in seconds is a duration that depends on how long a frame
took.

**Melee and ranged bodies have the same stats for every commander in the game.** A
knight and a barbarian are the same body with different art. What a commander sets
is the mixture and the captain, not a private stat block.

## One number for how big a body is

Every row carries a **radius**, in paces, and it is the only size in the project. It
is how large the body is drawn, how much ground it stands on, how close another body
may come, and how far something must reach to hit it.

Those were three separate numbers in three separate files before — a drawing table in
the renderer, one shared `personal_space` in the map shape, and a fifth of that shared
number in the targeting pass — and they were free to disagree, which meant a monster
drawn at twenty-six paces kept the same eighteen paces of room as a soldier drawn at
three and a half, so soldiers stood inside it.

The values are the renderer's old ones, because those were the only considered set that
existed. The sight width was `personal_space * 0.20`, which is 3.6 — the melee body's
drawn radius exactly. It had been tuned to the picture and written as a fraction of
something else.

## Exports

| Name | Type | Meaning |
| --- | --- | --- |
| `ticks_per_second` | integer | How many ticks the world advances per second of wall clock. Every duration in every catalogue is a whole number of these. |
| `sync_cycle_seconds` | integer | How often machines correct each other's arithmetic. |
| `decay_ticks` | integer | How long a fallen body holds its slot before its death is final. **Two sync cycles**, written as that multiplication rather than as a number, so that changing the cadence carries this with it. See issue 210. |
| `archetype` | array of rows | One row per kind of body. A body's `archetype` field is an index into this. |
| `max_radius` | number | The biggest body in the catalogue, in paces. **Derived from the rows**, not written down, so an archetype larger than the Golem cannot silently make a spatial query too small to find it. |
| `wave` | table | How often a wave leaves the base, and its one captain. |
| `equipment` | table | Every piece a body can carry: its weight, and what it adds. |
| `deck` | table | What a lane can afford: its deck's entries, its purse and its meters. Every number in it is chosen by Claude and open for Ritz. |

## An archetype row

| Field | Type | Meaning |
| --- | --- | --- |
| `name` | string | For reports and for the terminal viewer. |
| `flavour` | integer | 1 wave, 2 hero, 3 guard, 4 monster. |
| `reach` | integer | **1 melee, 2 ranged.** Read by the frontline queue and by upgrade stamping, and by nothing else. |
| `health` | double | Full health at birth, before upgrades. |
| `damage` | double | Per swing, before upgrades. |
| `armour` | double | Flat subtraction on every blow taken. |
| `range` | double | Weapon reach, in paces. |
| `acquire_range` | double | Wider than `range`, so a body commits to a fight slightly before it can hit. |
| `speed` | double | Paces per tick. |
| `cooldown_max` | integer | Ticks between swings. |
| `kit` | table, optional | `carries`, the pieces always worn, and `maybe`, a list of {piece, chance} tried once each at birth. Only the lane's own soldiers have one. |
| `arcs` | boolean, optional | Shoots over a line rather than needing a clear one. |

The first rows are melee (1), ranged (2), captain (3), guard (4).
Rows 19 to 22 are the lane's own soldiers from issue 213 — heavy infantry, light
infantry, skirmishers and archers — which are what an ordinary wave is drawn from.
Melee and ranged remain for the arena's posed formations and a siege-surge's stream. A body **copies**
these values into its own slot at birth; nothing ever reads a row through a
pointer during a match.

## The wave record

| Field | Type | Meaning |
| --- | --- | --- |
| `interval` | integer | Ticks between one wave leaving the base and the next. |
| `first_at` | integer | Ticks before the very first wave, so a match opens calm. |
| `captain_count` | integer | **One per lane, every wave.** |
| `stagger` | integer | Ticks between two bodies of the same wave stepping out, so a wave leaves as a column. |

One captain per lane per wave is the rule that makes every lane worth contesting:
each carries a body worth about three ordinary ones, so a lane you never contest
is a captain you never collect.

## Why `acquire_range` is wider than `range`

A body that acquired exactly at weapon range would oscillate between walking and
closing on the same target forever. The gap is what lets it commit.

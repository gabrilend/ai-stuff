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

## Exports

| Name | Type | Meaning |
| --- | --- | --- |
| `ticks_per_second` | integer | How many ticks the world advances per second of wall clock. Every duration in every catalogue is a whole number of these. |
| `sync_cycle_seconds` | integer | How often machines correct each other's arithmetic. |
| `decay_ticks` | integer | How long a fallen body holds its slot before its death is final. **Two sync cycles**, written as that multiplication rather than as a number, so that changing the cadence carries this with it. See issue 210. |
| `archetype` | array of rows | One row per kind of body. A body's `archetype` field is an index into this. |
| `wave` | table | What a wave is made of and how often one leaves the base. |

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

The four rows are melee (1), ranged (2), captain (3), guard (4). A body **copies**
these values into its own slot at birth; nothing ever reads a row through a
pointer during a match.

## The wave record

| Field | Type | Meaning |
| --- | --- | --- |
| `interval` | integer | Ticks between one wave leaving the base and the next. |
| `first_at` | integer | Ticks before the very first wave, so a match opens calm. |
| `melee_count` | integer | Melee bodies per wave per lane. |
| `ranged_count` | integer | Ranged bodies per wave per lane. |
| `captain_count` | integer | **One per lane, every wave.** |
| `stagger` | integer | Ticks between two bodies of the same wave stepping out, so a wave leaves as a column. |

One captain per lane per wave is the rule that makes every lane worth contesting:
each carries a body worth about three ordinary ones, so a lane you never contest
is a captain you never collect.

## Why `acquire_range` is wider than `range`

A body that acquired exactly at weapon range would oscillate between walking and
closing on the same target forever. The gap is what lets it commit.

# 041-units

A unit is one row across the world's flat arrays.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

Every unit -- tank, anti-air gun, helicopter, frigate, command truck,
enforcer -- is one row of the world's `unit` group. There is no class and no
per-kind record. This module does two things:

- **The catalogue.** `catalogue()` loads `assets/040-unit-catalogue.lua` once.
  It refuses, by row and field, a missing field, an unknown one, a value of the
  wrong type or out of range, or indices that are not one to the number of
  kinds. It converts every time in seconds to ticks at the rules' rate. A
  weapon is all of a piece: damage, a reach, a shell speed and a reload, or none
  of them.
- **The row.** `spawn` copies what a unit reads constantly out of its kind's row
  into its own: domain, altitude, damage, falloff, eye, profile and claim
  radius. Its health is the cap, written at the increment of now on its kind's
  heal counter, and an enforcer's shield is the same on its recharge counter.
  Nothing a unit does later reaches back to the catalogue, its factory or its
  team.

Zero is the sentinel. A tank's shield is zero, a target of zero is no target,
and a row is never compacted mid-tick.

The catalogue also asks the world for its counters. `counters()` gives one heal
counter per kind (`world.heal.<name>`) and one recharge counter per shielded
kind (`world.recharge.<name>`), in index order. The world adds them to its
counter table when it allocates, so the tick brings them up like any other.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `spawn(world, kind, team, x, y)` | a world; a kind's name; a team from 1; a position in cells | the new row's id; refuses by name an unknown kind, a team the world does not have, a position that is not two numbers, and a full world |
| `alive(world)` | a world | how many units are alive: the pool's kept count |
| `catalogue()` | | the loaded catalogue: `[name] = row` and `kinds[index] = row`, each row with `reload_ticks`, `heal_ticks`, `shield_ticks` and `build_ticks` beside the seconds |
| `validate_catalogue(raw, rate)` | a raw catalogue table; ticks per second | the loaded form, or a refusal naming the row and field |
| `kind(kind)` | a name or an index | that kind's loaded row; refuses an unknown one by name |
| `index_of(name)`, `name_of(index)` | | the kind's index, or its name |
| `counters()` | | the counter rows the world adds: `{path, ticks, extra}` |
| `validate(world)` | a world | nothing; called by the world's validator. Refuses a live row whose kind is not in the catalogue, whose domain is not its kind's, or whose team is not a team of the world. A live row of kind zero is one claimed from the world and not yet filled, and is let through |
| `dump(world, id)` | a world; a row | the row as one line of text, every field in layout order |
| `report()` | | the catalogue as text, every row, then hits to kill in tank shells |
| `DOMAINS`, `DOMAIN_NAMES`, `REACH`, `FIELDS` | | land 1, air 2, sea 3; the reach bits; every catalogue field with its type |

## Data structures it owns

The row columns it fills at birth, in `world.unit` (laid out by `the-world`):

| Column | Type | Set at birth to |
| --- | --- | --- |
| `alive` | integer | one (the world's claim sets it) |
| `kind` | integer | the kind's `index` |
| `team` | integer | the team |
| `x`, `y` | double | the position |
| `domain` | integer | the kind's domain |
| `altitude` | double | the kind's flight height |
| `health`, `health_at` | integer | the cap, and the heal counter's increment of now |
| `damage` | integer | the kind's damage |
| `falloff` | integer | the kind's index: which falloff curve the shots use |
| `eye`, `profile` | double | the kind's |
| `claim_radius` | integer | the kind's |
| `shield`, `shield_at` | integer | the kind's shield and the recharge counter's increment of now; zero for a kind without one |

Everything else in the row -- `reload_at`, `pattern`, `leg`, `mission`, `target`,
`eaten`, and the plane and enforcer fields -- starts at zero and belongs to the
system that writes it.

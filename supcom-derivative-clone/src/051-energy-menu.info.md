# 051-energy-menu

The always-open energy menu: four buttons deciding how many of a team's
engineers go to energy, and never a fifth.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

The vision's menu is one lever: four buttons that trade construction speed
against energy. `LEVELS` is the whole menu, four rows of a name and a share of
the engineers on energy, written as a whole number of thirds:

| Level | Name | On energy |
| --- | --- | --- |
| 1 | none | 0 thirds |
| 2 | a third | 1 third |
| 3 | two thirds | 2 thirds |
| 4 | all | 3 thirds |

Thirds keep the split in exact integer arithmetic, so every machine rounds the
same way.

A team's current level is `world.team.energy_level`. Zero means no button has
been pressed yet, and `level` reads that as level 1, nobody on energy.

`split(world, team, engineers)` divides an engineer count by the level: the
level's thirds, rounded down, go to energy duty, and the rest are build power.
No other code computes the fraction. The roster (issue 304) passes its engineer
count here from `on_energy`. Build power (305) and energy raising (303) read
the two halves.

A press is a command like any other. The door's `set-energy-level` verb asks
`refusal`, then calls `set_level`, so the level changes at the tick the command
is stamped for and not before. A fifth button, a fractional one, or a team the
match does not have is refused by number. `set_level` called directly raises
the same reason. A change takes effect at once, not gradually, because a gradual
change would be a per-engineer state and the roster has none. What the
engineers on energy duty do is issue 303's, and open question D1's.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `LEVELS` | | the four rows `{name, thirds}` |
| `set_level(world, team, level)` | a world; a team; one to four | nothing; raises the menu's reason otherwise |
| `refusal(world, team, level)` | the same | why the press cannot be made, or nil |
| `level(world, team)` | a world; a team | its level, one when no button has been pressed |
| `split(world, team, engineers)` | a world; a team; a whole engineer count | the engineers on energy duty and on build duty |

## Data structures it owns

`LEVELS`. It writes `world.team.energy_level` and nothing else.

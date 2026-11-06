# 040-unit-catalogue

Every number that describes a kind of unit, one row per kind.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

One table, keyed by kind name, one row per kind of the demo: `tank`,
`anti-air`, `helicopter`, `frigate`, `command-truck`, `enforcer`. Every field is
a number or a name and nothing else, so the file is data. The units module
(`src/041-units.lua`) loads it once through `units.catalogue()`, refuses a bad
row by its name and field, and turns every time given in seconds into ticks at
the rules' rate. A unit copies what it needs out of its row at birth and never
reads the catalogue again.

The design is the relations, which the tests assert; the magnitudes are working
values, and every change to one goes in [the balance ledger](../docs/balance-updates.md).

- A tank dies in **four** of its own shells, an anti-air gun in **three**, a
  command truck in **one**, an enforcer in **six**, and the enforcer's shield
  takes **four** more.
- A helicopter dies in **two** and a frigate in **eight** (open question B2's
  working ruling).
- The enforcer is taller than the tank and looks from higher up, and its head
  is above its eye.
- Every kind heals on its own counter, so no two kinds share a heal period.
- Planes fly (an altitude above zero) and nothing else does; a plane claims no
  ground.

`./report-catalogue` (through `units.report()`) prints every row and these
relations in tank shells, so a
document never has to quote a number.

## Exports

The file returns one table: `{[name] = row}`.

| Field | Type | Meaning |
| --- | --- | --- |
| `index` | integer | the kind's number, one to the number of kinds with no gaps; a unit row's `kind` holds it |
| `name` | name | the key the row is filed under |
| `domain` | integer | 1 land, 2 air, 3 sea |
| `reaches` | integer | the domains its weapon may target, as bits: 1 land, 2 air, 4 sea; zero only for a kind with no weapon |
| `tier` | integer | 1, 2, or 3 (experimental) |
| `health` | integer | the heal cap |
| `damage` | integer | per shot at full strength; zero for no weapon (the truck) |
| `falloff_full` | double | cells out to which damage is full |
| `falloff_floor` | double | the fraction of damage it never falls below, zero to one |
| `falloff_end` | double | cells out to which damage falls in a straight line to the floor; never nearer than `falloff_full` for a kind with a weapon |
| `shell_speed` | double | cells per tick; decides when a shot lands |
| `reload_seconds` | double | between shots; becomes `reload_ticks`, the period of `world.reload.<name>` |
| `heal_period` | double | seconds between one point of health coming back; becomes `heal_ticks`, the period of `world.heal.<name>` |
| `speed` | double | cells per tick on flat ground |
| `climb` | double | how much a rise slows a land unit: a step up a rise of r per cell is `speed / (1 + climb * r)`; downhill is never faster; zero for kinds that do not walk the ground |
| `eye`, `profile` | double | how high it looks from, how tall it looks |
| `altitude` | double | flight height above the ground; zero for land and sea |
| `claim_radius` | integer | cells of territory it claims around itself; zero claims nothing |
| `shield` | integer | the enforcer's sphere; zero elsewhere |
| `shield_seconds` | double | the sphere's recharge period; zero where there is no shield; becomes `shield_ticks`, the period of `world.recharge.<name>` |
| `cost_mass`, `cost_energy` | integer | the construction stream's totals |
| `build_seconds` | double | how long the stream runs at unit build power; becomes `build_ticks` |

## Data structures it owns

Only the table above. The loaded form -- the same rows with the tick fields
beside the seconds, and `kinds`, the rows by index -- belongs to the units module.

# 026-structure-table

The numbers for stone, and what killing it pays.

## What it is for

Two rows — a guard tower and a library — plus the two rewards. **Every guard tower
in the game is the same strength as every other one.** There are no tiers.

That flatness is load-bearing. If towers already differed, a slotted upgrade would
be a small adjustment to an existing hierarchy; because they are flat, a slotted
upgrade is the *only* thing that distinguishes one lane's stone from another's,
which makes the slotting decision visible from across the map.

## Exports

| Name | Type | Meaning |
| --- | --- | --- |
| `tower` | table | Every guard tower's numbers. |
| `library` | table | The library's, with its health expressed as a ratio. |
| `reward` | table | How many upgrades a wipe and a felling pay. |

## The tower record

| Field | Type | Meaning |
| --- | --- | --- |
| `health`, `damage`, `range` | double | The usual. |
| `cooldown_max` | integer | Ticks between arrows. |
| `command_radius` | double | The circle around the tower that gates guard replacement and hero placement. Larger than `range`. |
| `guard_cap` | integer | How many guards it may hold at once, before any upgrade raises it. |
| `guard_interval` | integer | Ticks between putting one guard on the ground and the next — **and only counting down while the radius is clear.** |
| `leash_radius` | double | How far a guard may drift before it turns round and goes home. |

## The inversion worth knowing about

A tower fills its patrol back up **only while no enemy stands inside its command
radius.** That is the opposite of what a tower usually does, and it is the whole
mechanic: the way to make a tower approachable is to *reach* it. Grinding its
guards down from outside the radius achieves nothing, because they come straight
back.

`command_radius` is deliberately wider than `range`, so that getting inside is
reachable ground rather than a spot already under maximum fire.

## The library

Its health is stored as `health_in_towers` — a **ratio** of a tower's health, not
a figure — so that retuning towers retunes the library and the two can never drift
apart.

The ratio is smaller than players expect. Once the stone in front of it is gone, a
team gets about one wave's worth of grace rather than a long grinding defence of
the core. A game whose premise is "the frontline must move" cannot afford a
fortress at the end of it.

## The rewards

| Field | Meaning |
| --- | --- |
| `tower_felled_draws` | Three. **Three separate draws**, not one worth three times as much — the plurality is the point, because felling a tower should trigger a burst of placement decisions. |
| `wave_wiped_draws` | One, to the team that did *not* spawn the wave. |

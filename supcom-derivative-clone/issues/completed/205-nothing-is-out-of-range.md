# 205 — Nothing is out of range

| | |
| --- | --- |
| Phase | 2 — Things That Roll, Fly, and Sail |
| Blocked by | 103, 201, 202 |
| Blocks | 206, 405, 502 |
| Reads | [a unit and what it carries](../../docs/004-a-unit-and-what-it-carries.md) |
| Open questions | A3 |

## Current behavior

Built. `src/044-targeting.lua` lets every unit with a ready weapon choose any
enemy it can see that its weapon reaches, at any distance: an enemy command
truck first, then the closest, ties to the lower row, keeping its current
target while it stays valid. `falloff` falls damage in a straight line to a
floor, `flight_ticks` gives a shell's whole ticks of flight, and the tick's
sight-and-aim row runs the pass, sliceable. The terminal viewer has a
sightline layer, fed by `visible`.

## Intended behavior

**A unit may fire at any enemy it can see, and there is no distance past which
it may not.** This is the first of the vision's two changes and the reason the
ground is the game. What distance does is fall the damage and delay the shell;
what it never does is forbid the shot.

The **aim pass** runs for every live unit whose reload counter says it may fire
— `reload_at` against the weapon kind's reload counter, the pair of integers
from issue 106. Such a unit:

1. Considers every live enemy whose domain is in its weapon's `reaches` set.
2. Keeps the ones it has a **sightline** to: `can_see` from issue 103, from the
   shooter's eye height to the candidate's profile height, both at their
   altitudes.
3. Picks by a fixed priority: an enemy command truck first, then the closest.
   Ties break by row index, which is stable, which is what lockstep needs.
4. Keeps its current target if the target is still alive and still in sight and
   nothing higher-priority has appeared, so a unit does not flicker between two
   targets at equal distance.

The pass writes only the shooter's own `target` column and is sliced (issue 209).
It never touches the target's row.

**Falloff** is a function of the shooter's kind and the distance: full damage out
to the catalogue's `falloff_full`, then a straight decline to `falloff_floor`
times full, and never below that. The vision's "some have lower damage from far
away" is the catalogue's business: a kind whose floor is one loses nothing.
Experimental artillery (issue 502) is exactly that row.

**Time of flight** is the distance over the catalogue's `shell_speed`, rounded up
to a whole tick and never less than one. The aim pass computes it; the fire pass
(issue 206) schedules the shot for that tick. What the shot does when it lands —
follow the unit it was fired at, or land where it was aimed — is A3, and the
working ruling is that it follows the unit.

The sightline question is the most-asked question in the simulation. The pass
asks the coarse test before the walk, and the headless runner reports how many
questions a tick asked so the coarse test can be judged rather than argued.

## Suggested implementation steps

1. Claim `src/NNN-targeting.lua` with `./new-source-file targeting`.
2. Write `falloff(kind, distance)`: the catalogue's two numbers and a floor,
   returning the damage as an integer. Refuse a kind the catalogue lacks.
3. Write `flight_ticks(kind, distance)`: distance over shell speed, ceiling,
   minimum one.
4. Write `candidates(world, shooter)`: every live enemy row whose domain is in
   the shooter's `reaches` set, as a range walk over the unit arrays, never a
   hash iteration.
5. Write `aim_pass(world)`: the four steps above, sliced by unit range; writes
   the shooter's `target` only. Count sightline questions into a per-tick
   statistic the runner prints.
6. Give the terminal viewer a sightline layer: from a chosen unit, the enemies it
   can see, so the answer can be looked at before anything can draw it.

## What happened

- **`falloff` returns a fraction, not an integer damage**, because the tests
  (and the tests document) ask for `falloff("tank", 1) == 1`; the fire pass
  multiplies.
- **The straight decline needed an end.** "Full out to `falloff_full`, then a
  straight decline to the floor" names no distance where the floor is reached,
  so the catalogue gained `falloff_end` per kind (three times `falloff_full`,
  give or take, for the demo kinds). Beyond it, the floor.
- **`reload_at` is the increment from which the weapon may fire again**, not
  the one it last fired at: written as now plus one by the fire pass (206), so
  zero means never fired and a unit is ready the moment it is born. Read the
  other way, a unit firing at increment zero would look as if it had never
  fired. Each kind with a weapon has its own reload counter,
  `world.reload.<name>`.
- **Keeping a target** means: alive, still an enemy in a domain it reaches,
  still in sight, and no candidate of a higher class (a truck) in sight. A
  closer enemy of the same class does not take it away.
- **A plane's eye and top are counted from its altitude**, as heights above
  the ground under it, which is what the sightline walk takes. A gun behind a
  ridge sees a helicopter over the far side; a tank there does not see a tank.
- **Sightlines are asked lazily**: only of a candidate that would beat the best
  so far, in row order. The answer is the full rule's.
- **The sightline layer** is an option of the viewer, `seen`, a list of ids
  drawn as `!`. The viewer may not call simulation modules, so the caller
  passes `targeting.visible(world, id)`.
- **Priority stays one rule for all** (`FIRST = "command-truck"`), as the issue
  suggests, until a kind needs otherwise.
- A3 stays open with the working ruling (a shell follows its target); the
  aim pass is the same either way.
- Planes in the cloud are not excluded yet; that is issue 405's.

## Related documents and tools

- [a unit and what it carries](../../docs/004-a-unit-and-what-it-carries.md)
- [the dunes and the sightlines](../../docs/002-the-dunes-and-the-sightlines.md)
- [the tick and the timers](../../docs/003-the-tick-and-the-timers.md) — the reload pair
- `tests/020-things-that-roll-fly-and-sail.lua`

## Still open

- **A3.** Whether a shell tracks the unit it was fired at or lands where it was
  aimed; the working ruling is tracking, and the aim pass is the same either way
  — only issue 206's land pass changes.
- Raised here: whether the target priority should be a table in the catalogue
  (per kind) rather than one rule for all. Written as one rule until a kind
  needs otherwise.

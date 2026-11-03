# 044-targeting

Any enemy in sight may be shot, at any distance; distance falls the damage and
delays the shell.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

Nothing is out of range. Distance never forbids a shot. It does two things:

- **Falloff.** A shot does full damage out to the kind's `falloff_full`, then
  falls in a straight line to `falloff_floor` (a fraction of full) at
  `falloff_end`, and the floor beyond that. A kind whose floor is one loses
  nothing at any distance.
- **Time of flight.** A shell takes the distance over the kind's
  `shell_speed`, rounded up to whole ticks, and never less than one.

**The aim pass.** It runs for every live unit whose weapon is ready, meaning
the increment of now on its kind's reload counter has reached the unit's
`reload_at`. Such a unit:

1. considers every live enemy in a domain its weapon `reaches`;
2. keeps those it has a sightline to, from its eye to the enemy's top, with a
   plane's altitude counted above the ground under it;
3. picks an enemy command truck first, then the closest, with ties going to
   the lower row;
4. keeps its current target while that target lives, stays in sight, is still
   an enemy it reaches, and nothing of a higher class (a truck) has appeared.
   A closer tank does not take a tank target away, so a unit never flickers
   between two.

A sightline is asked only of a candidate that would beat the best found so far,
so the answer is the full rule's and the questions are as few as it allows. The
headless runner prints how many were asked.

The pass is sliced (issue 209). It reads the world and writes only each
shooter's own `target`.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `aim_pass(world)` | a world | nothing; the tick's `sight-and-aim` row |
| `aim_pass_slice(world, first, last)` | a world; a range of unit ids | nothing; the ready shooters in the range choose |
| `falloff(kind, distance)` | a kind's name or index; cells | the fraction of full damage, from the floor to one; refuses a kind the catalogue lacks |
| `flight_ticks(kind, distance)` | a kind; cells | whole ticks, at least one; refuses a kind with no weapon |
| `candidates(world, shooter)` | a world; a unit | the live enemies in domains its weapon reaches, in row order |
| `visible(world, shooter)` | a world; a unit | every live enemy it can see, whatever it reaches, in row order: what the viewer's sightline layer marks |
| `sees(world, a, b)` | a world; two units | whether a sees b; one sightline question |
| `ready(world, id)` | a world; a unit | whether its weapon may fire |
| `distance(world, a, b)` | a world; two units | cells between them |
| `FIRST` | | `"command-truck"`, the kind chosen before any other |

## Data structures it owns

None of its own. It writes `world.unit.target` and reads `reload_at`, which is
the increment from which the weapon may fire again (zero for a weapon never
fired; issue 206's fire pass writes it). It also reads the reload counters
`world.reload.<kind>`, one per kind with a weapon, which the units module asks
the world for.

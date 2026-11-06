# 044-targeting

Any enemy in sight may be shot, at any distance; distance falls the damage and
delays the shell.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

Nothing is out of range. Distance never forbids a shot. It does two things:

- **Falloff.** Each kind's catalogue `falloff` names a shape, a row of the
  dispatch table `FALLOFF` (issue 502). Each row is a name and a curve from the
  kind's row and a distance to a fraction of full damage. There are two shapes:
  - `linear-to-floor`: full damage out to `falloff_full`, then a straight
    line down to `falloff_floor` at `falloff_end`, and the floor beyond. Every
    kind but the artillery uses it.
  - `flat`: nothing lost at any distance. The artillery's.

  Adding a shape means adding a row. A kind naming a shape no row has is
  refused when this module loads.
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

**Team sight** (issue 502). A kind with `team_sight` (the artillery) does not
look for itself. It fires at whatever any unit of its team has chosen as a
target this tick, so a scout on a crest, or a plane, is its eye. That needs a
write across rows, which a slice may not make, so the row has an unsliced step
after its slices, `aim_pass_after`:

1. `gather_sight` rewrites every unit's `seen` from nothing, one bit per team:
   bit t-1 is set when a live unit of team t, firing by its own eyes, chose it.
   A team-sight unit marks nothing, so an artillery's own choice never keeps a
   target seen.
2. Every ready team-sight unit chooses in row order, by the same rule as
   everyone else, with "marked seen by my team" (`seen_by_team`) in place of
   a sightline.

With no friendly eye on an enemy, it holds fire. The slices skip team-sight
kinds. `aim_pass` is the slices and then the step after.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `aim_pass(world)` | a world | nothing; the tick's `sight-and-aim` row |
| `aim_pass_slice(world, first, last)` | a world; a range of unit ids | nothing; the ready shooters in the range that look for themselves choose |
| `aim_pass_after(world)` | a world | nothing; unsliced: gathers the team's sight, then the ready team-sight shooters choose |
| `gather_sight(world)` | a world | nothing; rewrites every unit's `seen` from every chosen target |
| `seen_by_team(world, a, b)` | a world; two units | whether b is marked seen by a's team this tick |
| `FALLOFF`, `SHAPE` | | the falloff shapes as `{name, curve}` rows, and the same by name |
| `falloff(kind, distance)` | a kind's name or index; cells | the fraction of full damage, from the floor to one; refuses a kind the catalogue lacks |
| `flight_ticks(kind, distance)` | a kind; cells | whole ticks, at least one; refuses a kind with no weapon |
| `candidates(world, shooter)` | a world; a unit | the live enemies in domains its weapon reaches, in row order |
| `visible(world, shooter)` | a world; a unit | every live enemy it can see, whatever it reaches, in row order: what the viewer's sightline layer marks |
| `sees(world, a, b)` | a world; two units | whether a sees b; one sightline question |
| `ready(world, id)` | a world; a unit | whether its weapon may fire |
| `distance(world, a, b)` | a world; two units | cells between them |
| `FIRST` | | `"command-truck"`, the kind chosen before any other |

## Data structures it owns

None of its own. It writes `world.unit.target` and `world.unit.seen` (a bit
per team; teams beyond 31 would need a wider column) and reads `reload_at`, which is
the increment from which the weapon may fire again (zero for a weapon never
fired; issue 206's fire pass writes it). It also reads the reload counters
`world.reload.<kind>`, one per kind with a weapon, which the units module asks
the world for.

# 045-combat

Firing changes nothing; a shot lands at its tick, health comes back on a
shared timer, and the dead are taken out.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

Three of the tick's rows, in the order fire, land, die, after the aim pass
(issue 205).

- **Fire** (sliced). Every live unit whose weapon is ready and whose target is
  a live unit appends one shot to `world.shot`: shooter, target, the damage at
  the distance it is fired over, and the arrival tick, which is now plus the
  shell's flight in whole ticks. It rewrites its own `reload_at` to the next
  increment of its kind's reload counter. Nothing else moves, and nobody is
  hurt. Shots are appended in unit-row order, so slices run in ascending order
  append exactly what the whole pass would. (The thread pool, issue 209, has to
  keep that: each slice's shots go in after the slice before it.)
- **Land** (one worker). The queue is walked from one to its count. A shot whose
  arrival tick has come is applied to its target through `hurt` and leaves the
  queue; a shot whose target is no longer a live unit is dropped. The shots
  still flying close up in the order they were, so two machines land the same
  shots in the same order. (The issue suggested moving the last row into the
  freed slot; that reorders the queue, so the compaction is a stable one.)
- **Die** (one worker). Every live unit of a kind whose derived health is at or
  below zero leaves its bones where it stands (`bones.leave`, issue 208) and is
  released, in row order, which lowers the live count, and the shots still
  flying at it are dropped, so a row handed out again is never hit by a shell
  meant for the unit that held it. A raw row with no kind is never killed.

**A shot follows its target** (open question A3's working ruling): it lands on
the unit it was fired at, wherever that unit is by then. A shell that lands on
the ground it was aimed at would be a different land pass and a shot row with a
position.

**Health is derived, never walked.** Every kind has one heal counter,
`world.heal.<kind>`, with the catalogue's `heal_period` as its period. A unit's
health now is

    min(cap, health + (increment_now - health_at))

and `hurt` derives it, takes the amount off, and rewrites the pair with the
increment of now. A thousand tanks healing cost nothing until one is looked at.
The cap is the catalogue's `health`; nothing is ever written above it. The
heal rhythms are printed by `./report-catalogue`, one line per kind with its
period in ticks and seconds, rather than quoted here (B3 awaits evidence).

The case a per-unit countdown gets wrong, and the pair gets right: a tank at
its cap of 100 is hit for 1 at increment N, and for 1 again at increment N. Its
pair is then `98, N`. When the counter reaches N plus one, its health reads 99:
one point back, counted from the second hit, not two.

**Damage.** A shot does the shooter's `damage` times its falloff at the distance
(issue 205's `falloff`), rounded down, and never less than one.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `fire_pass(world)` | a world | nothing; the tick's `fire` row |
| `fire_pass_slice(world, first, last)` | a world; a range of unit ids | nothing; the ready shooters in the range fire |
| `land_pass(world)` | a world | nothing; the tick's `land` row |
| `die_pass(world)` | a world | how many died; the tick's `die` row |
| `hurt(world, id, amount)` | a world; a live unit; a whole number from zero | nothing; refuses anything else |
| `health(world, id)` | a world; a live unit | its health now, from the heal pair; refuses a row that is not a live unit of a kind |
| `damage_at(world, id, distance)` | a world; a unit; cells | what its shot does at that distance |
| `describe(world, index)` | a world; a place in the shot queue | the shot as one line: shooter, target, damage, arrival tick, and the tick it was looked at in. What a test prints when a shot lands early or late |

## Data structures it owns

The shot queue, `world.shot` (a queue group in the world's layout): `shooter`,
`target`, `damage`, `arrives`, all integers, with `count`. Its capacity is the
world's `units` times the rules' `shots_per_unit`; a full queue refuses by name
("the shot queue is full") and never drops a shot. It writes `world.unit.health`,
`health_at` and `reload_at`, releases unit rows, and leaves bones through
the bones module.

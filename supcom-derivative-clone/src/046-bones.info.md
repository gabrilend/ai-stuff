# 046-bones

A dead unit leaves bones: a position and a mass, belonging to nobody, until an
enforcer eats them.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

When the die pass (issue 206) takes a unit out, it first calls `leave`, which
puts a row in the world's bone queue where the unit stood. The row carries the
kind's `bone_share` of its `cost_mass`, rounded down: the only thing a death puts
back into the world. A kind whose share comes to nothing (the command truck,
which cost no mass) leaves no row.

Bones do nothing. They block no step and no sightline, and they belong to no
team, whoever's ground they lie on. The one thing that reads them is the
enforcer (issue 211): its eat pass finds them with `near` and eats them with
`eat`, which hands the mass back for it to share between itself and the
treasury.

Bones are kept apart from the units because the unit arrays are walked every
tick by every sliced system, and a dead row left in them would be a row every
walk had to skip. Only the eat pass walks the bones.

The queue is allocated once and **refuses by name when full** ("the bone queue
is full"). More bones than the parameters allowed is a parameter that was wrong;
forgetting the oldest would forget mass.

**Eating closes the queue up in order**, as every queue in the world does, so
the rows after an eaten one move down by one. An eat pass that eats several of
the rows `near` returned eats them last first. (The issue suggested moving the
last row into the freed slot; the world's queues keep their order, and the cost
of closing up is paid only when something is eaten.)

The bones are a group in the world's layout, so the hash folds them and a
snapshot carries them, and the terminal viewer draws them as `x` where no unit
stands.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `leave(world, id)` | a world; a live unit of a kind, just dead | its bone row, or zero for a kind whose bones carry nothing; called by the die pass only |
| `leave_at(world, x, y, mass)` | a world; a position on the field; a whole mass from one | the new bone row; refuses a position off the field, a mass that is not whole and at least one, and a full queue |
| `near(world, x, y, radius)` | a world; a position; cells | the bone rows within the radius, in queue order |
| `eat(world, id, index)` | a world; a live unit; a bone row | the row's mass; the row leaves the queue, which closes up in order |
| `mass_of(kind)` | a kind's name or index | what its bones carry |
| `total(world)` | a world | all the mass lying in bones |

## Data structures it owns

The bone queue, `world.bone` (a queue group in the world's layout): `x`, `y`
(doubles) and `mass` (an integer, never zero), with `count`. Its capacity is the
world's `units` times the rules' `bones_per_unit`. There is no team column:
bones belong to nobody.

# 052-formations

A wave leaves the base **already in formation**, and marches as one body.

## What it is for

Not a column that deploys into a line when it meets something. There is no moment
of forming up, because there is no moment at which the wave was not formed: it
walks out of the library in its ranks and is battle-ready the whole way down the
lane.

The only thing in this game that ever walks out in single file is a **siege-surge**,
which is a stream rather than a wave and has no formation at all.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `begin(world)` | | — Allocates the scratch list. Once, at assembly. |
| `plan(world)` | | — Advances every wave's anchor and shares out the cohesion budget. Once per tick, before the brain. |
| `assign_wave_slots(world, id, lane, role_index, role, melee_total)` | | — Gives a body its place, once, at birth. |
| `target_of(world, id)` | | Where that place currently is, in lane coordinates. |
| `files_for(lane)` | | How many bodies stand abreast marching down this lane. |
| `file_offset(files, file)` | | Where the nth body in a rank stands across the lane. |
| `side_of_line(world, id)` | | −1, 0 or +1 — which side of the lane a body is on. |

## Held in lane coordinates, which is why a rank survives a corner

A body's place is two numbers: **how far along the lane** its wave's anchor has got
plus this body's offset from it, and **how far across** the lane it stands. Its
world position is derived from those against the lane's own curve.

That is the whole trick. Hold a formation in world coordinates and a rank going
round a bend either tears apart or scythes through the inside of the turn, because
the bodies on the outside have further to walk and nothing tells them so. Hold it
in lane coordinates and **the formation curves to match the path it is on** for
free — every body in a rank shares one distance-along, and the lane carries the
line round the corner as a line.

**Measured by [the sandbox](../tests/060-the-formation-sandbox.info.md) and by the
invariants, and not written down here.** A wave marching a side lane holds its box
through the corner: the sides swap and the block does not break. Run either one to
see by how much.

The figures used to be in this paragraph, and then the ranks were spread out and the
paragraph was describing a formation that no longer exists.

## Cohesion is a budget, not a bonus

Fighting, dying and blocking still pull a formation out of shape. So bodies out of
place correct, and **the correction is conserved**: those furthest behind their
place hurry, and what they gain is taken from those in front of them.

It is expressed as a deviation from the wave's own **mean lag**, which makes the
conservation structural rather than something arithmetic has to be careful about —
the deviations sum to zero, so the speed handed out equals the speed given up,
exactly, without anybody checking.

The mean matters as much as the deviation. A wave whose every member is behind is
not out of formation; it is a wave whose anchor has got ahead of it, and speeding
all of them up would be a wave that accelerates for no reason.

**Only bodies still marching are in the budget.** One that has closed on an enemy
has left the formation's business, and including it would be the formation trying
to drag a body out of a fight by the collar. It also keeps the budget honest: a
body that has charged is a very long way from its place, and averaging that in
would tell every body still in line that it was badly out of position when it is
standing exactly where it should be.

The clamps at either end are allowed to break the conservation, and are supposed to
— a straggler that could sprint would read as teleporting. Each wave records how
far off its own books came out, so a *systematic* drift would be visible; a test
asserts it stays small.

## The arrangement

| Rank | Holds |
| --- | --- |
| front | the captain, in the middle, then melee outward from it |
| behind | more melee, until they run out |
| behind that, with a gap | ranged, shooting over the line |

A rank's positions are laid out evenly and **centred on the lane**, but the *order
they are handed out in* runs from the middle outward. So the captain — always given
the first place — stands in the centre where it is most useful and most visible,
and a rank that is not full is short at its edges rather than at its middle, which
is what a thinning line should look like.

## Where the lane's width earns its keep

`files_for` reads it, and it is the only thing that does.

**Which means the width and the file spacing are one number wearing two hats.**
Spread the ranks out without widening the road and a lane silently carries one body
fewer in every rank — every wave in it a third thinner, and nothing anywhere saying
so. The shape parameters therefore write down how many bodies each lane is *meant*
to carry, and [the map validator](031-map-validator.info.md) refuses a map whose
widths no longer deliver it.

It does **not** decide how many bodies may fight at once — nothing does; the world
is flat and a lane is a suggestion. It decides how wide a formation *travels*,
which is a different question with a real answer: a road's width is how many people
can walk down it side by side without leaving it.

The consequence is the one the wide centre lane always wanted. A wave marching up
the middle arrives with more of itself abreast, so more of it is in contact the
moment contact happens, and a numerical advantage tells sooner.

## When the wave stops

The anchor is the formation's **front**, not its centre of mass, so stopping it when
an enemy is near the front stops the whole wave at the point of contact rather than
letting the ranks behind push the front through the enemy.

A wave advances at its slowest member's pace — the captain's — and keeps that pace
after the captain dies. A wave that sped up when it lost the most valuable body in
it would be a wave rewarded for losing it.

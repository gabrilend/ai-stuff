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
| `radius_of(lane)` | | Half the width of a rank walking it. |
| `abreast_offset(map, from_lane, centre_lane)` | | Where a wave raised for one lane stands, across the lane it is walking. |
| `live_radius(world, members, count)` | | How wide *this* formation actually is, from the places of the bodies in it. |

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

**Which it no longer does.** How many walk abreast is now **declared** in the shape
parameters and read straight off the lane, and the width is the arithmetic that gives
them room. Dividing the count out of the width was fine while a width was a number
somebody chose, and became circular the moment a road was defined as three times the
formation walking it: the road would decide the formation and the formation would
decide the road. [The map validator](031-map-validator.info.md) checks the
arithmetic in both directions.

What the width decides now is **room**: a road is three formation widths across and
the centre is nine, so a wave has a formation's width of shoulder either side to
wander through.

It does **not** decide how many bodies may fight at once — nothing does; the world
is flat and a lane is a suggestion. It decides how wide a formation *travels*,
which is a different question with a real answer: a road's width is how many people
can walk down it side by side without leaving it.

The consequence is the one the wide centre lane always wanted. A wave marching up
the middle arrives with more of itself abreast, so more of it is in contact the
moment contact happens, and a numerical advantage tells sooner.

## The wander, and the column it happens inside

A road divides into **three columns** lengthways. A wave chooses one on its way out
and **keeps it for the whole march**: a wave that started on the left tends to stay on
the left. Inside that column it draws a fresh destination each time it crosses into a
new zone, and drifts toward it at a tenth of its marching pace.

The commitment is the important half. A wave drawing an independent offset in every
zone crosses the road repeatedly on the way down it, which is not an army with an
approach — it is an army that cannot make up its mind. **The column is the decision;
the draw inside it is the imprecision.** You know roughly which side you are going
down, and not exactly where.

Drifting rather than snapping, and slowly: a wave usually reaches one destination
about as it is given the next, so the line it walks is a long shallow curve rather
than a sequence of sidesteps.

**The room is the wave's own.** Half the road, less **its own** radius — see below.

**Its own stream, too**, seeded from the match seed, its team and its own number. A
stream shared across a team is advanced by whichever wave crosses a boundary first, so
a wave's wander would depend on how many other waves that team had walking and where
they were. That turns the wander into an amplifier for any difference between two
machines rather than a property of a wave: two runs a hair apart would take entirely
different roads.

## The circle is resizable, and has to be

`radius_of(lane)` answers "how wide is a full rank on this road" — what the road has
to be built to hold, and what two formations standing abreast have to be separated by.

`live_radius` answers "how wide is **this** wave", which is a different number and
moves. A wave that never had enough melee to fill its rank was born narrow, because
places are handed out from the middle of the line outward and a short rank is short at
its edges. A wave that has been fought down is narrower than it was, for the same
reason from the other end.

Every use of the circle needs the moving one. A bound computed from a full rank puts a
wide formation's edge in the ditch and holds a narrow one further from the verge than
it needs to be.

Measured from the **places** rather than from the positions. A body knocked out of its
file by a corner is not evidence that the formation got wider; it is evidence that the
body is out of place, which the cohesion budget is already dealing with.

Three things decide how far across the road a body's place is, and they **add**: its
place in its own rank, the shift that puts its whole formation abreast of the other
two during a challenge, and the wander. A wave funnelled into the middle still
wanders, and a wandering wave still keeps its place in the three.

## Where a wave is, and where its middle is

The anchor is the formation's **front**. Which zone a wave has reached — and
therefore when it takes the next waypoint — is a question about its **middle**, which
is half the formation's depth behind the front. The depth is accumulated as bodies
are given their places rather than computed from the member count, because the rear
rank is the ranged one and how far back it sits depends on how many melee there were.

## When the wave stops

The anchor is the formation's **front**, not its centre of mass, so stopping it when
an enemy is near the front stops the whole wave at the point of contact rather than
letting the ranks behind push the front through the enemy.

A wave advances at its slowest member's pace — the captain's — and keeps that pace
after the captain dies. A wave that sped up when it lost the most valuable body in
it would be a wave rewarded for losing it.

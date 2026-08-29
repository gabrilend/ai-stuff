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

## Three gears, and nothing ever hurries

Fighting, dying and blocking pull a formation out of shape, so bodies out of place
correct. A body is in a **gear**, not on a dial:

| Gear | | When |
| --- | --- | --- |
| walking | 0.70 of its pace | it has got ahead of its place |
| marching | its pace | it is where it should be, or catching up |
| running | — | leaving. Not here; see issue 212. |

**Nothing exceeds marching pace.** There is no budget and nothing is handed speed: a
formation dresses itself by the inside of a turn slowing rather than by the outside
sprinting, which is what a body of troops actually does. Asking the outer rank to run
is how a line becomes a crowd.

What was here before was a continuous multiplier with the extra taken from whoever
was ahead — conserved, and it read as breathing rather than marching, because every
body was always correcting at its own slightly different rate. It also could not be
measured: "how fast is that soldier going" had a different answer per body per tick.

Two things make the gears work.

**A dead band.** A body changes gear only when it is more than a couple of paces out
of place. Without it a body a hair ahead drops into walking, arrives a hair behind,
goes back to marching, and does that for ever. The width of the band trades the
tidiness of the line against how often a body switches, and both numbers are printed
by [the sandbox](../tests/060-the-formation-sandbox.info.md) every run.

**The front waits.** When the formation has fallen more than half a rank behind its
own anchor, the anchor stops advancing until the line is dressed again. This is what
replaces hurrying: a body on the outside of a bend has further to walk and cannot make
it up by going faster, so the front stops asking.

The mean lag is what the anchor reads. A wave whose every member is behind is not out
of formation; it is a wave whose anchor has got ahead of it, which is precisely the
case where waiting is the right answer.

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

## The arrangement, as bearings

A body's place is written down as a **bearing and a distance from the formation's
centre** — `slot_bearing` and `slot_distance` — because every question asked about a
place is an angular one. Can this body shoot past that one. Is it on the flank or in
the middle where the heavy troops belong. Which way should it face. None of those is
a row and a column.

Bearings run from 0 dead ahead, through a quarter turn at the flanks, to half a turn
at the rear; the sign is which side.

| Bearing | Holds |
| --- | --- |
| around 0 | the line: the captain in the middle, melee out to either side, further ranks behind |
| around five-eighths of a turn | the shoulders: bodies with a reach, behind the line and at its ends |

**Bodies with a reach stand behind the line**, in their own ranks, with a gap so they
read as a second body of troops rather than as the back of the first.

They spent a while at the shoulders, on the reasoning that a body with a javelin
cannot shoot through its own rank. Both halves of that are true and the conclusion was
wrong. An arrow arcs; a bow behind its own line is doing the thing bows are for. The
only weapon here that genuinely cannot pass over a rank is the druid's moon spike,
thrown flat, and that one is **meant** to be blocked — which is what makes the
frontline a targeting constraint and gives a player something to read. See
[line of sight](035-targeting.info.md).

**And the shoulders belong to cavalry**, which does not exist yet and will. Putting
the archers where the horses go means moving them again later and rebuilding whatever
came to depend on it.

A **captain stands in the middle of its own rank**, and which rank is written on its
archetype row — the front of the line for one carrying a shield, back with the archers
for one carrying a bow. The middle always: it is the most useful place and the most
visible, and a player who cannot find the captain cannot read what a lane is worth.

The rank number is a request rather than a promise. How many ranks the line occupies
depends on how many bodies are in it and how wide the road is, so a rank that was
behind the line in one lane is inside it in another — a captain with a reach is
clamped so it can never end up standing in front of the shields.

A captain does **not** consume a place in anybody's numbering. Every slot at or after
its own is shifted by one, so the arrangement either side of it keeps the shape it
would have had and two bodies never land on the same ground.

A rank's positions are laid out evenly and centred, but the *order they are handed
out in* runs from the middle outward, so a rank that is not full is short at its ends
rather than in its middle. That is what a thinning line looks like.

### Why the bearings are written after the wave is built

`settle_the_disc` runs once the whole wave has a place, rather than body by body as
they are born. A circle has a centre and does not have a front, so a bearing has to be
measured from the middle — and where the middle is depends on how deep the formation
turned out to be, which is not known until the last body has somewhere to stand.
Computed as they were born, every bearing came out measured from a centre that was
still moving, and the front rank came out at a quarter turn from dead ahead, which is
where the flanks are.

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

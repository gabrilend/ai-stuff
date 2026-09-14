# 036-the-frontline

The queue that makes a wave read as a wave rather than as a smear.

## What it is for

Soldiers do not overlap and do not push each other. When a body closing on a fight
would end its move inside the personal space of a friendly body ahead of it, it
**stops short instead**. The result is a queue: the front rank fights, the ranks
behind stack up along the lane and step forward as the front rank dies.

That is what makes a lane upgrade legible from across the map. A stronger front rank
visibly holds its ground while the enemy's queue backs up behind it, and a player
reads "I am winning that lane" off the shape of two crowds rather than off a number.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `clear_of_bodies(world, id, x, y)` | a point in **world** coordinates | That point, or the nearest one to it that is not inside anybody. |
| `blocked(world, id)` | | Whether this body must stop short this tick. |
| `separate_pass(world)` | | — Pushes bodies out of buildings, then pushes apart anybody left standing inside anybody. |
| `push_out_of_stone(world)` | | How many bodies it had to move out of a building. |
| `push_body_out_of_stone(world, id)` | | — The same, for one body against every building. |
| `gather_contacts(world)` | | How many gathered pairs are actually overlapping. |
| `relax_contacts(world)` | | — Pushes apart everybody on the gathered list. |
| `for_each_candidate(world, id, spacing, visit)` | | — Every living body within `spacing` of this one. |
| `SEPARATION_SLACK` | *(number)* | How close counts as touching rather than overlapping. |

### Stone is solid, and the order between the two passes decides which rule wins

A building occupies real ground — nineteen paces of masonry for a tower, thirty for a
library — and until a structure carried a radius on its record the only place a tower had
a size at all was a number inside a drawing routine. Bodies walked through towers and a
tower's own guards were placed inside the square being drawn around them.

Stone takes no part in the shoving between bodies, because a building cannot give ground
and there is nothing to share. So it is a **separate pass, and it runs first.**

The order is the whole of it. Run last, pushing a body out of a tower puts it into
whoever was standing beside it and nothing runs afterwards to fix that — a match that had
never had two bodies inside each other started having them. Run first, the residue lands
the other way: a body the crowd shoves into a wall is inside it until the next tick, which
is the same tolerance everything else here has.

It is asked from the stone's side — twenty grid queries, one per building — rather than
by walking every body, because a match has twenty buildings and can have four hundred
bodies.
| `SEPARATION_ROUNDS` | *(number)* | The ceiling on relaxing rounds within one sweep. |

## Refusing, and then separating

Two things keep bodies out of each other, and the second exists because the first
cannot do it alone.

**The refusal** is a question about a step: may I stand on this ground? Three things get
past it, and each was measured rather than argued. A cleared step is shortened afterwards
by the body's own speed limit, so it lands short of the circle it was aimed at — which is
to say inside. Only the deepest of several obstacles is resolved per call. And a body that
is not moving is never asked at all.

**The separation pass** runs after every body has moved and pushes apart anybody still
overlapping, by exactly the overlap, split between the two in inverse proportion to their
area — so a soldier walking into a Golem moves and the Golem barely does. It is a stage of
the tick like any other, so a test that names marching gets it and cannot accidentally
measure a world where bodies may overlap.

Together they hold a stronger property than either: across a whole eight-thousand-tick
match, **no two bodies overlap at any tick**, measured rather than asserted.

### A sweep, then a look, then a sweep

The pass gathers every pair close enough to matter in one walk of the spatial grid, then
relaxes that list over and over until a round finds nothing. Then it **looks again**, and
only leaves after a look that finds nobody overlapping — never straight after a push,
because a push is precisely the thing that has not been checked.

That structure is not caution for its own sake. Gathering once and trusting a margin was
tried, and the pass spent an afternoon *creating* overlaps: a hero dropped onto a wave is
born seven paces inside somebody, pushing it out moves it seven paces, and it lands inside
a body three paces away that was never on the list because it was further off than the
margin.

### Two numbers that had to be measured

**The slack** — a millionth of a pace — is not "close enough", it is the width of the
arithmetic. Two bodies pushed to exactly touching land a few parts in ten thousand million
either side of exact, half the time inside. Both the relaxing *and the look* have to use
it: with an exact comparison in the look, a settled crowd read as still overlapping and
the pass burned its whole sweep ceiling on seven thousand four hundred ticks out of eight
thousand, doing nothing.

**The round ceiling** — a hundred and twenty-eight — is a guarantee of termination rather
than a budget, because the relaxing leaves the moment a round finds nothing. Every smaller
number that looked right was measured and was not: a dozen bodies on a short road converge
in twenty-four, three hundred bodies in three lanes of a real match do not, and the
residue they leave is a few ten-thousandths of a pace — small enough that every arena
scene passed and nothing looked wrong.

### What it costs

A whole match runs about **one and a half times slower** with the pass than without it.
That is the price of the guarantee and it is worth stating plainly; it is paid by the
headless runner, which plays thousands of matches, rather than by anybody watching one.

## Two rules, and they answer different questions

|  | `clear_of_bodies` | `blocked` |
| --- | --- | --- |
| asks | may I stand here | should I push past the man in front of me |
| about | everything on the field, the enemy included | my own side, in my own file |
| distance | the two bodies' radii — about seven paces | a rank's spacing — eighteen, or eleven for a body with a reach |
| its answer | go **there** instead | **wait** |

The first is physical and the second is tactical, and each does something the other
cannot. Deleting the second and keeping only the first was built and measured: bodies
press to touching, a losing wave spreads out and is killed piecemeal instead of
stiffening into a block, and matches stopped running their phase arc.

## The rule about standing on people

A body is about to walk into another body if there is a body within
`self.radius + other.radius` of the ground its next step lands on. If there is, that
ground snaps to the point on the other body's circle nearest to us, and then moves
back toward our own centre by our own radius — landing exactly at the sum of the two
radii, on the side we were coming from.

**The near side matters.** A body pushed round to the far side of an obstacle would
have passed through it to get there, which is the one thing this exists to forbid.

**It is asked about the step, not the destination.** The place a formation has for a
body can be ninety paces away, and whether somebody is standing on it is a question
about the future. Asked about the slot instead, bodies are pushed off their places for
obstacles they are nowhere near, formations stop dressing, and — because the anchor
waits for its own stragglers — waves stop advancing.

**One obstacle per call.** Ground inside two bodies is moved out of the one it is
furthest inside, which may leave it inside the other; the body chooses again next tick.
Resolving all of them at once means iterating toward a fixed point that need not exist.

**Two bodies may never be born in the same place**, because this cannot separate them
afterwards — there is no direction to push them apart along. It raises an event rather
than pretending.

## A rank is a melee thing

The rule above was written when every body wanted the same place — the front — and
everything behind it was waiting its turn to get there. **A ranged body does not want
the front and never did.**

| Reach | Behaviour |
| --- | --- |
| melee | Form the rank. Stop short behind whoever is ahead, step up as the front thins. |
| ranged | Hold at your own reach *behind* the rank and shoot over it. Not queueing for a place you will eventually take. |

Treating a ranged body as a rank-in-waiting pushes it into melee range and deletes
the distinction entirely. So a ranged body keeps a **smaller bubble** — it only needs
enough room not to stand inside a friend, and giving it a full rank's spacing would
push the back of a wave a long way down the lane for no reason.

The consequence for how a frontline reads: **a lane's depth is informative.** A wave
that has lost its melee rank but kept its ranged bodies is about to evaporate, and it
looks different from one that has lost everything. That is a thing a player can see
and act on from across the map, without a number anywhere.

## "Ahead" is a comparison, not a distance

`lane_position` is a body's path index plus how far it is across the current edge.
Comparing two of them is comparing progress down the same corridor. It is **not** a
distance — the steps are only roughly even — and it is never used as one.

Multiplying the difference by `facing` folds the two directions into one comparison,
so team 2's bodies walking backwards down the path array queue exactly like team 1's.

## What does not queue

Only friendly bodies block. An enemy in the way is not an obstacle, it is a target,
and [targeting](035-targeting.info.md) has already had its say by the time this is
asked.

A body with no lane — a guard on patrol — is in nobody's queue. Guards wander; they
are not going anywhere that queueing would help them reach.

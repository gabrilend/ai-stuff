# 214 — Going Round What Is In The Way

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 206, 211c, 111 |
| Blocks | 602 |
| Reads | [standing off and falling back](../docs/022-standing-off-and-falling-back.md) |
| Open questions | W1, W2, W3, H18 |

## Current behavior

**Bodies are solid, and there are two rules that make them so: one that refuses to walk
into somebody, and one that pushes apart anybody who ended up inside somebody anyway.**

Before every move, the ground a body's next step lands on is checked against
everything standing near it. If a body's centre is within `self.radius +
other.radius` of that ground, the step is moved: to the point on that body's circle
nearest to us, and then back toward our own centre by our own radius. The two steps
land it exactly at the sum of the two radii, on the side we were coming from.

**And then, after every body has moved, anyone still overlapping is pushed apart.** That
is the separation pass, it is a stage of the tick like any other, and it is what makes
"no two bodies overlap" a fact rather than an intention. Refusing to walk into somebody
is not enough on its own for three reasons, all of which were measured rather than
argued:

- **A cleared step gets scaled back afterwards.** The correction pushes a body radially
  out of the obstacle, which can make the step longer in the world than the body's own
  speed allows -- so the speed limit shortens it, and the body lands short of the circle
  it was aimed at, which is to say inside. In the scene where a formation meets a lone
  ally this put the leading body four thousandths of a pace inside him at tick 408.
- **Only the deepest obstacle is resolved per call.** Ground inside two bodies is moved
  out of the one it is furthest inside and may still be inside the other.
- **A body that is not moving is never asked.** The refusal is a question about a step.
  Something standing still, inside somebody, stays there for as long as it stands.

It applies to **everything on the field, the enemy included**, and it is asked once
per moving body per tick. Bodies walking a lane are asked about it in lane
coordinates; a guard walking the graph is asked about it in world coordinates, and
keeps the answer as an offset from its edge, because a guard's position is otherwise
re-derived from the graph every tick and any correction written into it lasts exactly
one tick.

**The rank rule is still here and is a different rule.** [The frontline
queue](206-the-frontline-is-a-queue.md) asks whether a body should push past the man
in front of it in its own file — about its own side, at a rank's spacing rather than
a body's width, and its answer is *wait* rather than *go there instead*. Both are
true at once and each does something the other does not.

## Intended behavior

**Occupied ground is not somewhere you may stand.**

That is the whole design and it replaces the two that were written here before —
swarm pathfinding, and formation-respecting avoidance — neither of which was built.
Both were answers to "what is a group of soldiers"; the ruling is that the question
does not need answering at this level, because a group is made of bodies and the
bodies are what cannot overlap. Fifteen of them each declining to stand inside
somebody is a formation flowing round another formation.

### The point it is asked about is the step, not the destination

A marching body has two things that could be called its waypoint: the place its
formation has for it, which can be ninety paces away, and the ground its next step
lands on, which is one pace away. **It is the second.**

Asked about the slot, a body is pushed off its place for obstacles it is nowhere
near, and a formation that never dresses is a wave that never advances, because the
anchor waits for its own stragglers. The distinction is not a refinement; it is the
difference between the game running its arc and being over in the first challenge.

### One obstacle per call, and the deepest one

Ground inside two bodies is moved out of the one it is furthest inside, which may
leave it inside the other. The body chooses again next tick. Resolving all of them at
once, *inside the refusal*, means iterating toward a fixed point that need not exist —
three bodies around a gap one body wide have no answer — and a body that arrives a tick
late is invisible while a frozen frame is not.

### And then nobody is left inside anybody

**No two sprites overlap. Ever.** Not "rarely", not "by less than a hundredth of a
pace" — a body standing inside another body is a picture of a rule that is not working,
and a player reads it that way whatever the number is.

The refusal above cannot deliver that on its own, for the three reasons in the current
behaviour. So after every body has moved, a **separation pass**: every pair still
overlapping is pushed apart along the line between their centres, by exactly the overlap,
**split between the two in inverse proportion to their size.** A soldier walking into a
Golem moves; the Golem barely does. Two soldiers each give half.

Three properties it has to have, and each one rules out an obvious simpler version:

- **Every push is computed before any is applied.** Resolving pairs one at a time makes
  the answer depend on the order the bodies were visited, and two machines that visited
  them differently would produce different worlds out of nothing.
- **A bounded number of rounds, not a solve.** Pushing A out of B can put A into C.
  Iterating to a fixed point is the thing that need not terminate — three bodies round a
  gap one body wide still have no answer — so the pass runs a fixed small number of
  rounds per tick and lets the rest settle over the following ticks. The cost is the same
  every tick, which a search would not be.
- **It is a stage of the tick**, named in the same table as every other stage, so a test
  that wants marching gets separation with it and cannot accidentally measure a world
  where bodies may overlap.

**What this buys beyond tidiness**: it is the first thing in the game that can move a
body *sideways* out of a file. The refusal has no sideways in it when a body walks dead
at somebody — the push runs from the obstacle's centre through ours, and head-on that
direction is straight back the way we came. Separation runs on the same line but acts on
bodies that are already touching, in a crowd, where the lines between centres point every
way at once. That is what W1 through W3 and H18 are about.

### Two bodies may never be *born* in the same place

Two bodies at one point have no direction along which to be pushed apart, so the only
thing available is an arbitrary one, and an arbitrary direction chosen the same way on
every machine is the best that can be done with a situation that should not exist. It is
raised as an event rather than smoothed over. See [215](215-a-body-has-a-size.md) for the
two spawners that were doing it.

## Suggested implementation steps

1. Give every body a radius — [215](215-a-body-has-a-size.md) is a hard prerequisite
   rather than a related improvement, because the rule has no numbers without it.
2. Write the circle test in world coordinates, in the frontline module, beside the
   rank rule it sits next to.
3. Give the walking module a lane-coordinate wrapper: out through the lane's own
   point-and-tangent, back as a local resolution against the tangent and the normal
   rather than a projection, which would be a search per body per tick for an answer
   that agrees to five figures.
4. Route every mover through it — marching, closing, and the graph walk a guard uses
   — and give the graph walk somewhere to keep its answer.
5. Give the walking module one primitive for **nudging a body by a small distance in
   world coordinates**, writing through whichever representation that body's position
   actually lives in — lane coordinates for anything on a road, an offset from a node for
   a guard. Without it a correction written into a lane body's world position is erased
   the next time its lane position is read.
6. Write the separation pass in the frontline module beside the refusal, computing every
   push before applying any, weighted by size, over a fixed small number of rounds.
7. **Gather the contacts once per sweep and relax the list, rather than asking the spatial
   grid on every round.** A hundred grid queries per body per tick makes a whole match
   four and a half times slower on its own.
8. **And then look at the field again, and only stop after a look that finds nothing.**
   A margin on the gathered list is not a bound on how far a push can move a body: a hero
   dropped onto a wave is born seven paces inside somebody, and pushing it out lands it
   inside a body that was never on the list.
9. Use the same slack in the look as in the relaxing. An exact comparison makes a crowd
   that has just been pushed to exactly touching read as still overlapping.
10. Give the tick a named row for it, after the move, and put it in the selections a test
   can name — with the field indexed again in between, because everybody has just moved.
11. Measure the match arc across several seeds before and after. A rule this deep in
   the movement path changes the game, and the phase clock is the thing that says
   whether it changed it for the worse.


## Open questions

**W1. How far to the side, and for how long?** A step aside that is too small never
clears anybody; one that is too large is a body leaving its file over a pebble. And
having gone round, when does a body stop going round?

**W2. What decides which side?** For a single body the cheap answer is whichever side
it is already nearer, the way the orbit picks. For a formation meeting another
formation there is a right answer and a wrong one, and both may pick the same.

**W3. Does a body going round give up its place, or carry it?** A body that keeps its
formation slot while stepping round will be pulled back into line by the cohesion
budget while it is still going round the obstacle, which may be exactly right or may
be the two rules fighting each other.

## Related documents and tools

- [The frontline is a queue](206-the-frontline-is-a-queue.md) — the rule being changed
- [A formation is a circle that faces](211c-a-formation-is-a-circle-that-faces.md)
- [The proving ground](111-the-proving-ground.md) — where this is looked at

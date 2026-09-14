# 215 — A Body Has a Size

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 201, 206, 405 |
| Blocks | 214 |
| Reads | [a unit and what it carries](../docs/004-a-unit-and-what-it-carries.md) |
| Open questions | Z1, Z2, Z3 |

## Current behavior

**Every body carries a radius in paces, stamped at birth from its archetype row like
health and damage, and four things that used to disagree now read it.**

| Reads it | What it used to read |
| --- | --- |
| the rule that keeps two bodies off the same ground | did not exist |
| how large the body is drawn | a table in the renderer, indexed by archetype, with a fallback size for any row somebody forgot |
| how much of a straight shot a body blocks | one fifth of the shared `personal_space` — which is 3.6, the melee body's drawn radius, arrived at by tuning |
| how far a body can reach to hit another | nothing: reach was measured centre to centre |

The values are the renderer's old ones, because those were the only considered set
that existed. The largest is derived rather than written down, so an archetype bigger
than the Golem cannot silently make a spatial query too small to find it.

**Reach is measured to a body's skin.** `range + other.radius`. This is not a
refinement — a soldier stops against a monster at thirty paces from its centre while
its sword reaches seventeen, so measured centre to centre every melee body in the game
misses every monster forever, and what that looks like from outside is a challenge
phase that never ends.

### Two parts of the design below are not built

**Size does not grow with upgrades.** A fed lane still sends out soldiers the same size
as an empty one, so the readable-across-the-map half of this is still owed. Z3 is the
question it waits on.

**The rank rule still uses one global number.** [The frontline
queue](206-the-frontline-is-a-queue.md) keeps its eighteen-pace bubble for every body
alike. That number turned out to be about a *rank's spacing* rather than about a body's
size, so it is not obviously wrong to leave it one number — but it is not the design
below either, and Z1 is the question.

### What it flushed out

Giving bodies sizes made two spawners visibly wrong, both of which had been placing
bodies exactly on top of each other since they were written:

- **Every tower's guards were placed on the tower's own node** — one point, so all of
  a tower's guards stood inside one another. They are now spread across the road,
  alternating sides, on an axis running from that team's library to that tower.
  **The axis has to belong to the tower rather than to the world**: the first version
  used a spiral in world coordinates, and since the map is a mirror, that put one
  team's guards a pace toward the enemy and the other's a pace toward home. Four
  matches with nobody playing, and the same side won all four.
- **A wave deeper than its start distance had its rear ranks placed behind the
  library**, which clamps to zero, and zero is the node all three lanes share. The
  back of every wave leaving a base was born inside the back of the other two. A wave
  now starts in by its own depth plus the margin, so the rearmost body stands where
  the front used to.

## Intended behavior

**A body's size is a property of the body, in the simulation, and everything that cares
about how much room a body takes reads it.**

### Room is a question about two bodies, not one

How far apart two bodies stand is decided by **both of their sizes**, not by one global
number. A soldier beside a soldier stands closer than a soldier beside a monster, and
neither has to be a special case anywhere: it falls out of asking the two bodies.

The existing exception for bodies with a reach stays and means what it always meant —
a body that is not queueing for the front needs only enough room not to stand inside a
friend — but it becomes a modifier on a real distance rather than a fudge of a
universal one.

### Size grows with what a body is carrying

A body **gets bigger as it gains upgrades.** A lane that has been fed sends out
soldiers that are visibly larger than a lane that has not, and the difference is
readable across the map without a number anywhere — which is the same thing every other
part of this design is trying to do, and the one place where a stacked lane currently
looks exactly like an empty one.

It also makes stacked lanes *feel* different to walk into rather than merely hitting
harder: bigger bodies take more room, so fewer of them are in contact at once, so a
heavily upgraded wave is a different shape as well as a different strength.

Stamped at birth from the lane's holdings, like everything else a body carries — see
[405](405-a-soldier-is-stamped-at-birth.md) — and never corrected afterwards.

### And the drawn size becomes the real size

The renderer stops keeping its own table. What it draws is what the body is, so a
player looking at a crowded lane is looking at the actual geometry the simulation is
using rather than at an illustration of it that happens to be scaled differently.

That reverses a decision the renderer states explicitly and defends, and the defence
is worth reading before this is done: the two numbers were separated because a rank
drawn at the spacing it walks at is a solid bar, and what a player has to be able to do
is count a line and see it thin. **Making them one number means the drawing gets that
problem back**, and it has to be solved by drawing rather than by lying — see Z2.

## Suggested implementation steps

1. Put a size on the body, stamped at birth from the archetype row, the way health and
   damage already are.
2. Give the archetype catalogue a size per row, and pick the numbers by looking rather
   than by argument: the viewer's existing drawn radii are the only considered set of
   these that exists, and they are a reasonable first draft.
3. Change the queue's spacing question from one global number to a function of the two
   bodies' sizes.
4. Add size to what an upgrade grants, and to the birth stamp.
5. Watch it in [the proving ground](111-the-proving-ground.md): a scene with one large
   body and several small ones sharing a road, which is a picture that either looks
   right or does not.
6. Only then change the renderer, and check whether a rank still reads as a rank.

## Open questions

**Z1. Is room the sum of two sizes, or something else?** The sum is the obvious answer
and produces bodies that touch exactly. A little more than the sum is a rank that
breathes; a little less is a rank that overlaps at the edges, which may be what makes a
crowd read as a crowd.

**Z2. What does the renderer do about a rank being a solid bar?** The reason the drawn
size and the real size were separated in the first place, and it does not go away by
being ignored. Drawing an outline rather than a fill, or a gap that is drawn smaller
than it is, or accepting the bar — all of these are answers and none has been chosen.

**Z3. How much size does an upgrade buy?** Enough to see, or it is not doing the job it
is being added for; not so much that a fed lane cannot fit down its own road. That is a
number found by looking, not by choosing.

## Related documents and tools

- [The frontline is a queue](206-the-frontline-is-a-queue.md)
- [Going round what is in the way](214-going-round-what-is-in-the-way.md)
- [A soldier is stamped at birth](405-a-soldier-is-stamped-at-birth.md)

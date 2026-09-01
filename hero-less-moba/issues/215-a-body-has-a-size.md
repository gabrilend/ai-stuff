# 215 — A Body Has a Size

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 201, 206, 405 |
| Blocks | 214 |
| Reads | [a unit and what it carries](../docs/004-a-unit-and-what-it-carries.md) |
| Open questions | Z1, Z2, Z3 |

## Current behavior

**Nothing in the simulation knows how big a body is.**

There is one number, `personal_space`, and it is the same eighteen paces for a wave
soldier, a captain at two and a half times the health, a tower guard, a bought hero
and a challenge monster. [The frontline queue](206-the-frontline-is-a-queue.md) uses
it for every body alike, with a single exception: a body with a reach keeps six tenths
of it, because it is not queueing for the front.

The viewer keeps a **second, unrelated** table of how large each archetype is *drawn* —
3.6 paces for a melee body, 5.8 for a captain, 26 for a monster — and the renderer says
in as many words that the two numbers are deliberately unrelated, one being about
standing in a crowd and the other about looking at it.

The consequence is visible the moment anybody looks: **large bodies walk far too close
to everything, and small bodies stand inside large ones.** A monster drawn at twenty-six
paces keeps the same eighteen paces of room as a soldier drawn at three and a half, so
soldiers overlap it; and it in turn crowds whatever it is walking behind.

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

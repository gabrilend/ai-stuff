# 206 — The Frontline Is a Queue

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 202, 203 |
| Blocks | 404, 602 |
| Reads | [a unit and what it carries](../docs/004-a-unit-and-what-it-carries.md), [standing off and falling back](../docs/022-standing-off-and-falling-back.md) |
| Open questions | B11 — does the frontline move at all |

## Current behavior

Bodies do not overlap. A melee body closing on a fight stops short behind a
friendly body ahead of it in the same lane, and ranged bodies keep a smaller
bubble and hold behind the rank at their own reach. That produces ranks, and the
ranks read correctly on screen.

**But they are single file, and they are oriented by the lane.** A lane's width
is drawn and never read, so the wide centre is currently only a picture. And the
ranks form along whatever direction the lane's path happens to run at the point of
contact, which means two hosts meeting at a bend meet corner-first rather than
line-to-line.

The queue is therefore the shape of the corridor rather than the shape of the
fight, which is the thing the section below replaces.

## Intended behavior

**The lane decides the path you take toward the enemy. It does not decide how you
are arranged when you engage.**

Recorded as it was given, because the whole of this issue is in it:

> draw a line toward the enemy, then arrange your formation for the advance. a
> basic one is lines of melee in front of lines of ranged, with cavalry behind so
> they can flank toward the flank of theirs that's weak. Draw a line through the
> enemy like the way the healers do to orient themselves, and then make your rank
> lines parallel to that. The lanes are mostly suggestions, the world is actually
> just a dense mixture of plains, forests, mountains, etc... But for our purposes
> just say it's flat everywhere. The lanes should determine the path that you take
> toward the enemy, but not how you should be arranged when you engage. You should
> make a line parallel to the line through the enemy group, and arrange your guys
> oriented to that line. Once fighting begins it's less important to retain
> cohesion, but the approach is how you engage.

### The line through the enemy already exists

It is not a new idea and it does not need a new mechanism. It is already how a
ranged body with nothing to shoot decides which way to orbit — *draw a line
through the mass of the enemy formation; a body on the left of that line orbits
left, one on the right orbits right.* See
[standing off and falling back](../docs/022-standing-off-and-falling-back.md).

This issue takes that same line and gives it a second job: **it is the line your
own ranks are parallel to.**

One line, computed once per host per tick, answering two questions — which way do
my archers drift, and which way do my ranks face. That is worth saying plainly
because computing it twice, slightly differently, in two files, is how those two
behaviours would quietly stop agreeing with each other.

### Two regimes, and the transition between them is the interesting part

| | |
| --- | --- |
| **Marching** | No enemy host in sight. Walk the lane graph in the ordinary way. The lane is the path. |
| **Forming** | An enemy host is ahead but not yet in reach. **Leave the lane.** Take a slot in a formation oriented to the enemy's line, and move to it in open ground. |
| **Engaged** | In reach. Fight. Cohesion stops being enforced — *once fighting begins it's less important to retain cohesion.* |

**The approach is how you engage.** The formation is not a thing that happens when
swords cross; it is a thing that is already finished by then. So the trigger to
start forming is deliberately **wider than acquisition range** — a body should be
in its slot before it can hit anything, or the formation is a thing that assembles
during the fight, which is not a formation.

### The arrangement

Ranks are lines **parallel to the enemy's line**, stacked back away from it.

| Rank | Holds |
| --- | --- |
| front | melee |
| behind | ranged, at their own reach from the front rank |
| behind that | cavalry, positioned to flank toward whichever of the enemy's flanks is weak |

There is no cavalry archetype yet. The rank exists in the arrangement so that the
place it goes is decided before there is anything to put in it, rather than being
bolted on afterwards — and because *which flank is weak* is a question the
formation is already computing the answer to when it measures the enemy's line.

### How wide is a rank?

**As wide as theirs.** The formation's width follows the extent of the enemy's
line, bounded by how many bodies there are to put in it.

That is the answer to a question this issue used to ask differently. The old text
said a rank is N abreast where N is the lane's width. **It is not.** The world is
flat, the lanes are suggestions, and a host forms a line to match the line it is
walking into. A host with more bodies than the enemy's line is wide puts the
surplus in the ranks behind, which is where a numerical advantage should go.

### What this costs, and it is worth naming

**The centre lane being wider stops meaning anything mechanical.** Its whole
stated purpose was that more bodies get into contact at once there, and that
followed from width capping the rank. Under this design the rank is capped by the
enemy, not by the corridor, so a fight in a side lane and a fight in the middle
are the same fight.

That is a real loss and it is not obviously the wrong trade — a formation system
gives the middle other things to be — but it wants a decision rather than a
silence. Raised as its own question rather than settled here.

### What does not change

Deliberately **not** included: pushing, flowing around, or any collision
resolution that moves a body which did not choose to move. A body either advances
into free space or waits. Anything more is a physics problem, and a physics
problem with a thousand bodies is a frame-rate problem wearing a costume.

Personal space still applies. Bodies still do not overlap. A ranged body still
wants the deepest position inside its own reach rather than the front — that is
the same rule as before, now expressed as *which rank am I in* rather than *how
far behind do I stop*.

### Why this is not cosmetic

1. **Two hosts meet line-to-line rather than corner-first.** At a lane's bend the
   old queue produced a fight that started with two bodies and widened over
   several seconds; a formation arrives already deployed.
2. **A lane upgrade stays legible.** A stronger front rank visibly holds while the
   enemy's ranks back up, which is the same read as before but on a line the
   player can actually see the shape of.
3. **The flanks become a place.** Ranged bodies already drift to the shoulders and
   end up facing each other; with ranks oriented to the enemy's line, the shoulders
   are a definite position rather than wherever the corridor happened to bulge.
4. **The stalemate becomes visible**, which is what the phase-2 demo is for.

## Suggested implementation steps

1. Compute the **enemy line** for a host: the centroid of the enemy bodies near it,
   and the dominant axis of their positions. In two dimensions the axis is a closed
   form on the covariance, not an iterative solve — worth a comment saying so, so
   nobody reaches for a library.
2. Derive the formation frame from it: **along** the line, and **forward**
   perpendicular to it, pointed at the enemy centroid. Anchor the front rank at
   engagement distance from the enemy line rather than from any individual body.
3. Assign slots. Sort the host by role, then within a role **by each body's current
   projection onto the along-axis**, so bodies keep their left-to-right order and
   nobody crosses the whole line to reach a slot. That ordering is what makes the
   assignment stable between ticks; without it the formation shimmers.
4. Give a body a goal position rather than a lane step while forming, and steer to
   it in open ground. Keep the lane's node and progress current underneath, so that
   a body which loses its formation can rejoin the path it was on.
5. Drop cohesion on engagement. A body in reach fights whatever the targeting rules
   say; the slot was for the approach.
6. Recompute per host per tick rather than per body. One line, two consumers.
7. Write a test: two hosts approaching along a bend meet with their front ranks
   parallel, not corner-first.
8. Write a test that a host outnumbering another forms deeper rather than wider.

## Related documents and tools

- [Standing off and falling back](../docs/022-standing-off-and-falling-back.md) —
  the line through the enemy, and the orbit that already uses it
- [A unit and what it carries](../docs/004-a-unit-and-what-it-carries.md)
- The phase-2 demo, which shows the stalemate this makes visible

## Still open

**Does the frontline actually move once upgrades exist?** First evidence is in:
left alone a match stalemates, and one team stacking a lane walks it to the enemy
library. See B11.

**What is the wide centre lane for now?** Its mechanical purpose was capping the
rank, and the rank is now capped by the enemy instead.

**Is the world really flat?** *"the world is actually just a dense mixture of
plains, forests, mountains, etc... But for our purposes just say it's flat
everywhere."* Flat is what is being built. The sentence says it is a simplification
being consciously accepted, and that is worth keeping visible rather than
forgetting it was ever a choice.

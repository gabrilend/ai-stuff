# 206 — The Frontline Is a Queue

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 202, 203 |
| Blocks | 404, 602 |
| Reads | [a unit and what it carries](../docs/004-a-unit-and-what-it-carries.md), [standing off and falling back](../docs/022-standing-off-and-falling-back.md) |
| Open questions | B11 — does the frontline move at all; G8 — what the wide lane is for |

## Current behavior

**A wave is emitted from the base already in its ranks and marches as one body.**
Captain in the centre of the front rank, melee beside and behind it, ranged behind
those at a gap. It is battle-ready from the tick it appears; there is no moment at
which it is a column.

Its place is held in **lane coordinates** — a distance along the lane plus an
offset across it — so the formation curves to match the path. A wave rounding the
top lane's bend holds its block through the turn: the long side and the short side
swap and nothing tears.

Cohesion is a **conserved budget**. Bodies behind their place hurry and bodies in
front of it wait, taken from one another, expressed as deviations from the wave's
own mean lag so the books balance structurally rather than by arithmetic anybody
has to be careful about. Only bodies still marching are in it — one that has closed
on an enemy has left the formation's business.

A wave stops advancing when an enemy comes near its front, and its bodies fight.

**What is not built:** cavalry, and therefore the rank kept for them and the flank
they were to go round. And the enemy's line is not consulted any more — a rank is
perpendicular to the lane, which is parallel to the enemy's line whenever the enemy
is coming down the same lane, and is not when they are not. See *still open*.

## Intended behavior

Two descriptions arrived, in that order, and the second one supersedes the first
where they disagree. Both are recorded verbatim, because between them they are the
whole of this issue and because the first one is still the argument the second one
rests on.

### The first: the lane is the path, not the arrangement

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

### The second: they are formed before they leave

> the waves should be emitted from the base in their formations already, and they
> should move generally as a unit. If they are out of formation, because of turning
> or something, then those that are farthest from their intended location in the
> formation get a speed bonus by taking from those who are in front of or ahead or
> closest, in that order. So that they slow down, and meet them. When they turn
> through the lanes in the map, they should curve the formation to match the path
> they are on. This way they are always battle ready, instead of walking out in
> those lines - they should only do that during the siege-surge.

**There is no forming-up step.** The first description was read as *march in
column, then deploy on contact*, and that is wrong: a wave is in its ranks from the
moment it exists. What the first description is really about is that the corridor
does not dictate the shape — which remains true, and is what makes the formation
worth having at all.

### Held in lane coordinates

A body's place is two numbers: **how far along the lane** its wave's anchor has got
plus this body's own offset from it, and **how far across** the lane it stands. The
world position is derived from those against the lane's own curve.

That is what makes *curve the formation to match the path* fall out rather than be
implemented. Every body in a rank shares one distance-along, so the lane carries the
whole line round a corner as a line. Holding the formation in world coordinates
instead would make a turning rank either tear apart or scythe through the inside of
the bend, because the bodies on the outside have further to walk and nothing tells
them so.

### Cohesion is a conserved budget

Turning is not the only thing that pulls a formation out of shape — dying and
blocking do too. So bodies out of place correct, and **the correction is taken from
somebody**: *those that are farthest from their intended location get a speed bonus
by taking from those who are in front of or ahead or closest, in that order. So that
they slow down, and meet them.*

Expressed as a deviation from the wave's own **mean lag**, which makes the
conservation structural: the deviations sum to zero, so the speed handed out equals
the speed given up, exactly, without anybody counting. It also gets the mean right,
which matters — a wave whose every member is behind is not out of formation, it is a
wave whose anchor has got ahead of it, and hurrying all of them would be a wave that
accelerates for no reason.

Only bodies **still marching** are in the budget. One that has closed on an enemy has
left the formation's business, and including it would be the formation trying to drag
a body out of a fight by the collar.

### The arrangement

| Rank | Holds |
| --- | --- |
| front | the captain, in the middle, then melee outward from it |
| behind | more melee, until they run out |
| behind that, with a gap | ranged, shooting over the line |
| behind that | cavalry, to flank whichever of theirs is weak — **not built** |

Positions in a rank are laid out evenly and **centred on the lane**, but the order
they are handed out in runs from the middle outward — so the captain always stands in
the centre, and a rank that is not full is short at its edges rather than at its
middle, which is what a thinning line should look like.

### The lane's width decides how wide you travel

It does not decide how many bodies may fight at once. Nothing does; the world is flat
and a lane is a suggestion. It decides how wide a formation **travels**, which is a
different question with an obvious answer: a road's width is how many people fit
across it.

That gives the wide centre lane back most of what it wanted, by a different route — a
wave marching up the middle arrives with more of itself abreast, so more of it is in
contact the moment contact happens. Whether that is enough is G8.

### The one thing that walks in a line

*This way they are always battle ready, instead of walking out in those lines - they
should only do that during the siege-surge.* A surge is a stream, one body at a time,
and has no formation at all. That is a note for whoever builds it.

### What does not change

Deliberately **not** included: pushing, flowing around, or any collision resolution
that moves a body which did not choose to move. A body either advances into free
space or waits. Anything more is a physics problem, and a physics problem with a
thousand bodies is a frame-rate problem wearing a costume.

## Suggested implementation steps

1. Give each lane a **cumulative arc length** per path node, and a function that
   answers "where is this lane, this far along, and which way is it heading."
2. Make a body's lane position two numbers rather than an edge and a fraction, and
   derive its world position, its path index and its milestone from them.
3. Assign each body its rank and file **at spawn**, from its role and the lane's
   width, and put it down already standing there.
4. Advance the wave's anchor at its slowest member's pace. Stop it when an enemy is
   near the **front** — the anchor is the front, not the centre, so the ranks behind
   cannot push the front through the enemy.
5. Share out the cohesion budget as deviations from the mean lag, over the marching
   members only, clamped at both ends.
6. Have each wave record how far off its own books came out, so a systematic drift is
   visible from outside without recomputing anything.
7. Test that a wave rounding a bend keeps its ranks, and that its bounding box turns
   rather than growing.
8. Test that the budget balances.

## Related documents and tools

- [Standing off and falling back](../docs/022-standing-off-and-falling-back.md) — the
  line through the enemy, and the orbit that uses it
- [A unit and what it carries](../docs/004-a-unit-and-what-it-carries.md)
- The phase-2 demo, which shows the stalemate this makes visible

## Still open

**The enemy's line is no longer consulted.** A rank is perpendicular to the lane,
which is parallel to the enemy's line exactly when the enemy is coming down the same
lane — which is nearly always, and will stop being so during a challenge, when all
three lanes' bodies funnel into the centre from three directions. At that point
either the ranks turn to face what is in front of them or the formation stops meaning
anything, and the first description above already says which.

**Cavalry do not exist**, so neither does the rank kept for them, nor the flanking
that was the reason for it.

**Does the frontline actually move once upgrades exist?** First evidence is in: left
alone a match stalemates, and one team stacking a lane walks it to the enemy library.
See B11.

**Is the world really flat?** *"the world is actually just a dense mixture of plains,
forests, mountains, etc... But for our purposes just say it's flat everywhere."* Flat
is what is being built. The sentence says it is a simplification consciously
accepted, and that is worth keeping visible rather than forgetting it was a choice.

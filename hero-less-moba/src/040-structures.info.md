# 040-structures

Towers that shoot, the guards they put on the ground, and what happens when one falls.

## What it is for

**Every guard tower is the same strength as every other guard tower.** No tiers, no
inner-tower-is-tougher rule. That flatness is what makes a slotted upgrade
interesting: it is the *only* thing distinguishing one lane's stone from another's,
so the slotting decision is visible from across the map.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `begin(world)` | | — Sets every tower's timer running and gives each its first patrol. |
| `guard_pass(world)` | | — Replacement and leashing. Part of the tick's spawn system. |
| `tower_pass(world)` | | — Towers pick a target and keep it, then shoot. |
| `guard_died(world, id)` | | — One guard gone; its tower forgets it. |
| `tower_fell(world, structure)` | | — Kills its guards, pays three upgrades. |

## The command radius, and the inversion at the heart of it

A tower fills its patrol back up to a cap, **and only while no enemy stands inside its
command radius.**

That is the opposite of what a tower usually does, and the inversion *is* the
mechanic. A tower under attack does not reinforce itself; a tower with clear ground
around it does. So the way to make a tower approachable is to **reach** it — get a body
inside the circle and hold it there. Grinding the guards down from outside achieves
nothing, because they come straight back.

The timer is **held, not reset**, while the ground is contested. Resetting would mean a
single body could shut a tower down permanently by touching the edge of the circle
once a second.

The same circle decides where a hero may be put down. One radius, two jobs, drawn
once — and drawn for **both** teams, which makes it the single piece of information in
this game both sides can see. The attacker needs to know how far in they must get to
shut the reinforcements off; the defender how far out they must push to turn them back
on. Everything else here is hidden until it walks into you.

## What a tower shoots

The **nearest** enemy inside range, and it does not change its mind while that target
lives and stays in range.

Sticky rather than nearest-every-tick: a tower that re-picks constantly spreads its
damage across a whole wave and kills nothing, which makes it feel like weather rather
than a defence. A tower that commits kills one soldier every few seconds, and a player
can watch it happen and count.

**Nearest, not lowest-health** — unlike a body. A tower is defending a piece of ground,
and the body about to walk past it is the one that matters, not the weakest one
somewhere in the crowd.

## Felling a tower pays three

Three **separate** draws, not one worth three times as much. Felling a tower should
trigger a burst of placement decisions, which is a burst of teamwork.

Its living guards die with it. **The lane's slotted upgrades are untouched** — an
upgrade is slotted into a lane's stone as a whole, never into one specific tower, so
there is nothing in a felled tower to return. The lane's other tower keeps it, and
even when both lane towers are gone it keeps firing out of the three base towers,
which inherit every lane's stone.

The rubble stays in the array so the renderer can draw it. "There used to be a tower
here" is information.

## Why `enemy_inside_radius` walks bodies instead of the grid

A command radius is wider than the grid's cell, and there are eighteen towers. The
walk is over the high-water mark rather than the capacity, and eighteen of them a tick
is cheaper than the query would be.

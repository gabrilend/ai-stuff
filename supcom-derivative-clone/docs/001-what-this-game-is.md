# 001 — What This Game Is

## The premise

Take a large-scale real-time strategy game of the Supreme Commander family: a
commander unit, factories that build units, an economy of two resources that are
consumed as construction proceeds rather than paid up front, tiers of technology
rising to enormous experimental machines, and a battlefield big enough that a
shell fired from one side takes real time to land on the other.

Now change two things.

**Nothing is out of range.** Every weapon can fire at anything its owner can see.
What limits a gun is not a circle drawn around it but the ground between it and
the target: a tank in a hollow sees nothing past the crest, and a tank on the
crest is seen by everything on the plain. Distance still matters — some weapons
lose damage the further the shell travels — but distance is a cost, not a wall.
The ground is therefore the whole game, and the ground is **dunes**: a rolling,
randomly raised field where a metre of height is a kilometre of sight.

**Units stop listening once they leave the factory.** A player does not drive
units. A player builds a factory, chooses what it produces, and draws in the sand
the route its output will take. Every tank that ever rolls off that line follows
that drawing. The line cannot be redesigned after it is laid; a player who wants a
different route builds a different factory. The game is a factory game wearing a
tank game's clothes: you design inflows and outflows, production and paths, and
then you watch what you designed meet what the other side designed.

Everything else follows from those two changes.

## What a player does

The vision is explicit that the player's hands are on a small number of things,
and that **everything can be queued** — that is an invariant, not a feature.

- **Build.** Factories, energy buildings, and defences, placed with build power
  that comes from builders (cheap, trivial to make more of) and engineers
  (expensive, slow to replace). See [factories](006-factories-and-patterns-in-the-sand.md).
- **Assign.** An always-open menu of **four buttons** decides how many engineers
  are put toward energy. That is the whole energy economy from the player's side.
  See [the economy](005-territory-mass-and-energy.md).
- **Draw.** When a factory's line is laid, the player draws the pattern its units
  will follow. Once. See [patterns](006-factories-and-patterns-in-the-sand.md).
- **Point.** The command truck can be moved — one of the few things that can —
  and it launches a plane in a direction chosen on a compass wheel centred on
  the truck. See [the command truck](008-the-command-truck-and-its-plane.md).
- **Watch.** The air war happens in a cloud the player can open a small window
  onto, and the field can be looked at through as many lenses as the player
  cares to arrange. See [the views](010-the-views.md).

Nothing on that list is "select a unit and tell it where to go." That absence is
the design.

## The three domains

Land, air, and sea are all in from the first build, because the vision says
scaling is the thing that is hard to unfix once a program has specialised. The
demo's cast is small and covers all three:

| Kind | Domain | Its job |
| --- | --- | --- |
| tank | land | the baseline: the shell every other unit's toughness is measured in |
| anti-air | land | shoots what flies; priced as land and air at once |
| helicopter | air | goes to the cloud and fights there |
| frigate | sea | the naval baseline, priced in both resources equally |
| command truck | land | the player's presence on the field; dies in one hit; launches the plane |
| enforcer | land, tier two | walks forward, eats the dead, grows, and shields what stands near it |

The full game adds submarines, torpedo planes, and the experimentals. The demo
does not, and the vision says the price points of those later units should still
be design guides while the demo is built — which is why the cost table is a
document of its own even though the demo uses a corner of it.

## Territory is the economy

There is no mass extractor to place. **Territory implies mass.** Ground a team
holds pays mass while it is held; lose the ground and the income goes with it —
and so does whatever energy generation was built there while it was held, and so
does a matching share of the engineers and builders, who are hurt when the ground
under them changes hands. Territory is claimed by standing on it and defended by
thorns: build power turned into a defensive capacity that hurts whoever takes the
next percent of ground and shrinks as it is spent.

That is the whole loop. Units take ground; ground pays for units; losing ground
costs the means of making more. See [the economy](005-territory-mass-and-energy.md).

## The air war is somewhere else

Planes do not fly patterns. A plane leaves its factory and goes to **the cloud**,
a churning swarm above the field where both sides' fighters meet. The player
watches it through a small window, television-inside-the-television, and reads
its mood rather than its numbers. Planes that are outmatched leave the cloud and
fly over friendly ground, where the other side's planes can only reach them by
flying over anti-air. A scout plane's report can pull unbothered planes out of
the cloud for a bombing run. See [the cloud](007-the-cloud.md).

## Everything periodic is one shape

The vision spends a paragraph on how tanks heal — one countdown for every tank at
once, and each tank remembering the count it was born at — and then says the
whole game works that way. It does. Every periodic effect in this simulation is a
global counter plus one integer per unit, and a unit's current state is derived
from the difference. That is a few operations, no per-unit timers, and no walk
over every unit when a timer fires. It is what makes the simulation fit on a
handheld and, in the handheld's own runtime, fit in a box. See
[the tick and the timers](003-the-tick-and-the-timers.md).

## Two machines, one match

The game runs on a computer and on a two-screen handheld, and a match can have
one of each in it. The design that allows that is [lockstep](011-other-players.md):
every machine runs the whole simulation and only intent crosses the wire. Intent
is small here — a factory placed, a pattern drawn, a button pressed — because the
game was designed so that units do not need telling.

## Vocabulary

| Word | Means |
| --- | --- |
| **field** | the whole map: a heightfield of dunes with a water line |
| **cell** | one square of the field; territory is painted per cell |
| **dune** | a rise in the heightfield; the thing that blocks a sightline |
| **sightline** | a straight line between two points that never dips below the ground |
| **tick** | one advance of the simulation; the only unit of time the rules know |
| **increment** | one firing of a periodic effect's counter |
| **line** | a factory's production queue, pre-built and not designed by the player |
| **pattern** | the route drawn in the sand when a line is laid; followed by everything that leaves the factory |
| **the cloud** | the air battle, a swarm above the field |
| **command truck** | the player's mobile headquarters; the vision also calls it the command tank |
| **builder** | cheap construction labour |
| **engineer** | expensive construction labour that can be assigned to energy |
| **roster** | the off-field count of builders and engineers, each with health |
| **thorns** | the defensive capacity that hurts an attacker per percent of ground taken |
| **bones** | what a dead unit leaves; mass on the ground that an enforcer can eat |

## Where this came from

[The vision](../notes/vision), in the author's own words. Everything here is a
reading of it; where the reading had to fill a gap, the gap is on the
[open questions](016-open-questions.md) page with the working ruling marked as
one.

Related: [the dunes](002-the-dunes-and-the-sightlines.md) ·
[the roadmap](015-roadmap.md) · [the shape of the code](013-the-shape-of-the-code.md)

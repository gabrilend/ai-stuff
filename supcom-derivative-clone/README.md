# supcom-derivative-clone

A factory war on dunes where nothing is out of range.

This page is the game design and only the game design. How it is built, how it
is tested, and how it runs on two very different machines is in
[the documents](docs/table-of-contents.md); where the design came from is in
[the vision](notes/vision), in the author's own words.

---

## Two changes

Take a large-scale real-time strategy game of the kind where a commander unit
lands on a field, factories build armies, and an economy of two resources is
consumed as construction proceeds rather than paid up front. Then change two
things.

**Nothing is out of range.** Every weapon fires at anything its owner can
*see*. There is no circle around a gun. What limits it is the ground between it
and the target: the field is a rolling expanse of **dunes**, and a sightline is
a straight line that never dips below the sand. A tank in a hollow sees nothing
past the crest; a tank on the crest is seen by everything on the plain. Distance
still costs — some weapons lose damage the further the shell flies, and every
shell takes time to land — but distance is a cost, not a wall. The ground is the
whole game.

**Units stop listening once they leave the factory.** Nobody drives a tank. A
player builds a factory, picks one of the production lines the game ships with,
and **draws in the sand** the route its output will take. Every unit that ever
rolls off that line follows that drawing, fires at whatever it sees along the
way, and holds at the end. The drawing cannot be changed afterwards. A player
who wants a different route builds a different factory. It is a factory game
wearing a tank game's clothes: you design inflows, outflows, production, and
paths, and then you watch what you designed meet what the other side designed.

Everything else follows from those two changes.

## What you do

Your hands are on a small number of things, and every one of them is an order
that takes effect later — **everything can be queued** is the game's invariant.

- **Build.** Factories, energy buildings, and defences, placed with build power.
  Build power comes from builders, who are cheap and trivial to make more of,
  and engineers, who are slow and costly to replace.
- **Assign.** An always-open menu of exactly **four buttons** decides how many
  of your engineers are put toward energy. That is the entire energy economy
  from your side of the screen, and it will never grow a fifth button.
- **Draw.** When a factory's line is laid, you draw its pattern. Once.
- **Point.** Your command truck is one of the few things that moves on command,
  and it launches a plane in a direction you pick on a compass wheel centred on
  the truck.
- **Watch.** The air war happens in a cloud above the field, and you open a
  small window on it — television inside the television — and read its mood.

There is no "select a unit and tell it where to go." That absence is the design.

## Territory is the economy

There are no resource nodes to capture. **Ground you hold pays mass** while you
hold it. Take ground by standing on it; lose it by being pushed off. Lose the
ground and you lose the income — and the energy buildings you raised there, and
a matching share of your engineers and builders, who are hurt whenever the
ground under them changes hands. Lose four percent of your territory and four
percent of your labour force is in the infirmary.

**Energy is built on the ground.** Engineers on energy duty raise generators on
held cells, nearest to the bonus pockets of hydrocarbon the field hides, and a
generator on a cell that changes hands is gone. Every generator is a small bet
on holding a place.

**Construction is a stream.** Nothing is paid for up front. A line building a
tank draws the tank's mass and energy across the ticks it takes, in proportion
to the build power working on it. Run dry and everything stalls together, in
proportion, until income arrives. Overbuilding is a mistake you can see.

**Defences are thorns.** Build power turned into a capacity that hurts whoever
takes the next percent of your ground — and is spent by hurting them. A team
that loses half its ground has lost half its thorns twice over.

The costs are a shape before they are numbers: land units lean ten-to-one on
mass, air units ten-to-one on energy, ships pay both equally, and so does the
anti-air gun, which is a land unit that shoots the sky. Tier two costs ten times
tier one; an experimental, a hundred times.

## The cast of the demo

Six kinds, in three domains from the first build, because the vision says the
thing that is hard to unfix is scaling.

| Kind | Domain | What it is |
| --- | --- | --- |
| **tank** | land | the baseline; every other unit's toughness is measured in its shells |
| **anti-air gun** | land | the only thing that reliably shoots planes |
| **helicopter** | air | leaves the factory and goes straight to the cloud |
| **frigate** | sea | moves only on water |
| **command truck** | land | you, on the field; dies in one shell; launches the plane |
| **enforcer** | land, tier two | walks forward, eats the dead, grows, and shields what stands near it |

The vision's starting toughness, in tank shells: a tank takes four, a gun three,
a truck one, an enforcer six with a shield that takes four more.

Every unit heals, and every kind heals on its own rhythm — one countdown for all
the tanks at once, another for all the guns, another for all the planes. That
one rule turns out to be the shape of every periodic thing in the game.

## The cloud

Planes do not fly patterns. A plane leaves its factory and goes to **the cloud**:
a swarm above the field where both sides' fighters gather, fighting in rounds.
How well they fight is how well you upgraded them — and a plane built before an
upgrade never gets it.

Before each round, every plane compares its side's strength to the other's.
**Outmatched planes leave the cloud and fly defensively over friendly ground.**
Stronger planes seek them out — and to reach them must fly over enemy territory,
where anti-air guns are waiting. Winning the cloud does not win the air. It
moves the fight to where the guns are.

Your command truck's plane is a scout with one missile. It flies the heading you
chose, sees the ground beneath it, and everything it sees is a **report**. A
report reaches the cloud, and any plane there that is unbothered and carrying
bombs leaves on a bombing run to the reported place, drops, and comes back. If
the scout knows where the enemy's command truck is, it hunts that and nothing
else, one missile per target.

## The enforcer

Tier two, and the demo's only tier-two unit. It is **tall**: it sees over crests
that hide a tank, and is seen over them — its head is above its eye, so it is
seen before it sees, and where you send it is the most important drawing you
make. It **eats the bones** of the dead, and what it eats goes partly to your
treasury and partly to its own growth, in a proportion you set when its line is
laid. It claims ground with ease. And it carries a **sphere shield** that
absorbs hits on anything standing inside it — the tanks around an enforcer are
tanks under a shield.

## The big things

Everyone has the same experimentals, and each one takes one attack pattern and
maximises it. Artillery whose shells lose nothing to distance. A gunship that
ignores the cloud and deals the largest single hit in the game. And the
**carriers**: factories that move — building for free while they roll or swim,
holding what they build inside, and **unleashing it the moment they stop**,
unless told to keep hold, in which case they unleash only when hit. The
underwater carrier does this submerged and surfaces to strike. The air-factory
carrier does it with bombers.

Submarines and torpedo planes are the full game's answer to the underwater
carrier. The demo has neither.

## Two machines, one match

The game runs on a computer and on a two-screen handheld, and one match can have
one of each in it. Every machine runs the whole simulation; only intent crosses
the wire — a factory placed, a pattern drawn, a button pressed — and intent is
small, because the game was designed so that units do not need telling. The
wire on the handheld is an ad-hoc radio with no router and no internet, and the
match is a room of machines that can hear each other.

## The field

The dunes are raised by a tool from a seed, so two machines given one number
raise the same field to the last grain. Long swells, ridges laid across them at
an angle, fine roughness on top, a water line that makes the low places sea. The
field is random every time, which is why its look is meant to be generated
rather than drawn — a tileset from an image model, so that random dunes still
look like a place.

## What is deliberately absent

- Selecting a unit and telling it where to go.
- Redesigning a pattern after it is drawn.
- A range circle on anything.
- A fifth button on the energy menu.
- Faction-specific experimentals.
- Internet play, or a server.
- A hand-drawn map.

## Where the design goes from here

Every decision the vision left open is on the [open questions](docs/016-open-questions.md)
page with a working ruling marked as one, and the [roadmap](docs/015-roadmap.md)
groups the work into nine clusters of functionality. The tests were written before
the source, and [the tests come first](docs/014-the-tests-come-first.md) is the
contract between them.

Copyright 2026 gabrilend. GNU Affero General Public License v3 — see
[COPYING.md](COPYING.md).

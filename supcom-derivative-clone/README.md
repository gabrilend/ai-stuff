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
past the crest; a tank on the crest is seen by everything on the plain. Only
ground blocks a sightline — units never do, so an army cannot hide behind
itself. Distance still costs — some weapons lose damage the further the shell
flies, and every shell takes time to land — but distance is a cost, not a wall.
Slope costs too: a land unit climbing a face moves slower than one running the
trough, so the trough is fast and blind and the ridge is slow and seen. The
ground is the whole game.

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
- **Draw.** When a factory's line is laid, you draw its pattern. Once. A line
  can be stopped and started again, and a factory can be demolished for a share
  of the mass that went into it — so a bad drawing is a building you tear down,
  never a route you correct.
- **Point.** Your command truck is one of the few things that moves on command,
  and it launches a plane in a direction you pick on a compass wheel centred on
  the truck. The truck is also your stake in the match: it dies to a single
  shell, and a team whose last truck dies has lost.
- **Watch.** The air war happens in a cloud above the field, and you open a
  small window on it — television inside the television — and read its mood.

There is no "select a unit and tell it where to go." That absence is the design.

A match is **two teams**, any number of players to a side, one command truck
each. The demo is one against one.

## Territory is the economy

There are no resource nodes to capture. **Ground you hold pays mass** while you
hold it. Take ground by standing on it — a claim completes after a short spell
of uninterrupted presence, within two cells of the unit standing there, or four
for an enforcer — and lose it by being pushed off. Lose the ground and you lose
the income, and the energy buildings you raised there, and a matching share of
your engineers and builders, who are hurt whenever the ground under them changes
hands. Lose four percent of your territory and four percent of your labour force
is in the infirmary.

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

**Ground can be improved.** Mass and energy spent on a cell you hold raise what
that cell pays, and the improvement is lost with the cell. It is the only place
to put mass that is not a unit, and it is the question of whether holding ground
compounds or merely pays.

The costs are a shape before they are numbers: land units lean ten-to-one on
mass, air units ten-to-one on energy, ships pay both equally, and so does the
anti-air gun, which is a land unit that shoots the sky. Tier two costs ten times
tier one; an experimental, a hundred times.

## The cast of the demo

Six kinds, in three domains from the first build, because the vision says the
thing that is hard to unfix is scaling.

| Kind | Domain | Shells it takes | What it is |
| --- | --- | --- | --- |
| **tank** | land | four | the baseline; every other unit's toughness is measured in its shells |
| **anti-air gun** | land | three | the only thing that reliably shoots planes |
| **helicopter** | air | two | leaves the factory and goes straight to the cloud |
| **frigate** | sea | eight | moves only on water |
| **command truck** | land | one | you, on the field; launches the plane; the match ends with it |
| **enforcer** | land, tier two | six, and four more of shield | walks forward, eats the dead, grows, and shields what stands near it |

Tank, gun, truck and enforcer are the vision's own figures. The helicopter's two
and the frigate's eight are working rulings — the vision is silent on both, and
they are the sort of number a match is expected to argue with. Every balance
number lives in the catalogue tables under `assets/` and in no document; what
is written here is the shape those tables started from.

Every unit heals, and every kind heals on its own rhythm — one countdown for all
the tanks at once, another for all the guns, another for all the planes. That
one rule turns out to be the shape of every periodic thing in the game: healing,
the cloud's rounds, a claim's progress, an enforcer's shield coming back. The
game beats **ten times a second**, which is often enough that a shell's flight
is several beats and rare enough that ten thousand matches overnight is a real
number.

## The cloud

Planes do not fly patterns. A plane leaves its factory and goes to **the cloud**:
one swarm, above the middle of the field, where both sides' fighters gather and
fight in rounds. It sits above every gun's sight, so nothing on the ground can
reach into it. How well a plane fights is how well you upgraded them — and a
plane built before an upgrade never gets it.

Before each round, every plane compares its side's strength to the other's.
**Outmatched planes leave the cloud and fly defensively over friendly ground.**
Stronger planes seek them out — and to reach them must fly over enemy territory,
where anti-air guns are waiting. Winning the cloud does not win the air. It
moves the fight to where the guns are.

Your command truck's plane is a scout with one missile. It flies the heading you
chose, sees the ground beneath it, and everything it sees is a **report**. A
report reaches the cloud, and any plane there that is unbothered and carrying
bombs leaves on a bombing run to the reported place, drops, and comes back. The
drop hurts what is standing there and claims the cell underneath, so the air war
takes ground as well as lives. If the scout knows where the enemy's command
truck is, it hunts that and nothing else, one missile per target.

## The enforcer

Tier two, and the demo's only tier-two unit. It is **tall**: it sees over crests
that hide a tank, and is seen over them — its head is above its eye, so it is
seen before it sees, and where you send it is the most important drawing you
make. It **eats the bones** of the dead, and what it eats goes partly to your
treasury and partly to its own growth, in a proportion you set when its line is
laid. Growth raises its health, its damage, and its sphere together. It claims
ground with ease — four cells' reach instead of two. And it carries a **sphere
shield** that absorbs hits on anything standing inside it — the tanks around an
enforcer are tanks under a shield.

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
small, because the game was designed so that units do not need telling. A
command takes effect a few beats after it is given, which is the room the wire
is given to deliver it. The wire on the handheld is an ad-hoc radio with no
router and no internet, and the match is a room of machines that can hear each
other.

## The field

The dunes are raised by a tool from a seed, so two machines given one number
raise the same field to the last grain. Long swells, ridges laid across them at
an angle, fine roughness on top, a water line that makes the low places sea. The
field is random every time, which is why its look is meant to be generated
rather than drawn — a tileset from an image model, so that random dunes still
look like a place.

The seed is the first thing the game reads, out of [input/seed](input/seed), and
everything random in a match descends from it through named streams: which dune
is where, which engineer is hurt when ground is lost, which plane a report
reaches first. Same seed and same commands, same match, tick for tick, on every
machine in the room.

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
page, in three states: a **working ruling**, where a document had to fill a gap
and says so; **awaiting evidence**, where only a running match can answer; and
**direction set**, where the choice is made and the alternatives are recorded
rather than deleted. None have been worked through with a person yet, and a
phase whose questions have not been is a phase being built on a guess.

The [roadmap](docs/015-roadmap.md) groups the work into nine clusters of
functionality — foundations at the low numbers, capstones at the high ones — and
each cluster ends with a demo kept working and runnable from `./run-phase-demo`.

The tests were written before the source, and
[the tests come first](docs/014-the-tests-come-first.md) is the contract between
them: ten test programs, one per cluster, each naming the issues it claims to
specify. Every one of them fails today, and fails in exactly one way — the module
it looks for does not exist, reported by name along with the issue that will
build it. `./run-tests` runs both halves and prints a census of the written half
first; at the time of writing it reads seventy-six issues, sixty-one of them
named by a test, and thirty-six questions of which two are directions set and
four await evidence. Those figures move, so run
`./validate-documentation` rather than trust this paragraph.

Copyright 2026 gabrilend. GNU Affero General Public License v3 — see
[COPYING.md](COPYING.md).

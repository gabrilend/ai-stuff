# 015 — Roadmap

Nine phases. They are **clusters of functionality**, not a schedule. Nothing here
is time-gated and nothing here is a progress bar. It is entirely normal for the
last issue completed in this project to belong to phase 1, because phase 1 holds
the foundations and foundations get revisited when the thing standing on them
turns out to be heavier than expected.

The ordering rule: **lower numbers are more foundational**, not earlier in time.
A phase-7 issue has more blockers in front of it than a phase-2 issue. The
capstones — a match between two people, a match between two handhelds, a person
against the bot — are the issues with the most standing under them.

Each phase ends with a **demo** in `issues/completed/demos/`, runnable from
`./run-phase-demo` at the project root. The demos are not development scrap.
They are part of what this project delivers, they are kept working, and each one
shows the previous phases' tools recombined into something the previous phase
could not do on its own.

**The tests were written before any of this.** Each issue below is specified by
a test in `tests/` that names it, and the census in `./validate-documentation`
reports which issues have one. See [the tests come first](014-the-tests-come-first.md).

---

## Phase 1 — The Dunes and the Clock

The world that does nothing. No units, no fighting. A field of dunes raised by a
tool, a way to ask whether one point sees another, a heartbeat, one door for
player intent, a way to get pictures out, and the determinism guarantee that
every later phase and the whole network model depend on.

Ends with: a headless runner that raises a field, advances an empty world ten
thousand ticks, prints the same hash twice, and a terminal viewer that draws the
dunes and the water line as text.

| Issue | |
| --- | --- |
| 101 | The project is built by its tools |
| 102 | The dunes are raised by a tool |
| 103 | Sightlines are read off the dunes |
| 104 | The world is flat arrays |
| 105 | The tick is a dispatch table |
| 106 | A periodic effect is a pair of integers |
| 107 | Randomness comes from named streams |
| 108 | Commands enter through one door |
| 109 | Snapshots, hashes, and replays |
| 110 | The headless runner |
| 111 | A terminal viewer, so we are not blind |
| 112 | Territory is painted on cells |
| 113 | Every mechanic has a test |

## Phase 2 — Things That Roll, Fly, and Sail

The unit. One record for everything that can be shot, in three domains from the
first build, with infinite range bounded by sight, damage that falls with
distance and lands later, and health that comes back on a shared timer.

Ends with: two lines of tanks meeting across a dune field, one on a ridge and one
in a trough, and the ridge losing — because it was seen first.

| Issue | |
| --- | --- |
| 201 | A unit is one record |
| 202 | The unit catalogue |
| 203 | Three domains on one field |
| 204 | Movement follows a pattern |
| 205 | Nothing is out of range |
| 206 | Damage is buffered, then applied |
| 207 | Health comes back on a shared timer |
| 208 | Death leaves bones |
| 209 | The thread pool slices the tick |
| 210 | The command truck moves and dies in one hit |
| 211 | The enforcer walks forward and eats |

## Phase 3 — Inflows and Outflows

The economy: territory pays mass, engineers on a four-button menu raise energy
that is lost with the ground it stands on, construction streams resources into
lines the player did not design, and every line's output follows a pattern drawn
once.

Ends with: a match that plays itself — two bots placing factories and drawing
patterns — in which one side takes ground, the other side's roster goes to the
infirmary, and the report says which dune decided it.

| Issue | |
| --- | --- |
| 301 | Territory implies mass |
| 302 | The energy menu is four buttons |
| 303 | Energy is built on the ground and lost with it |
| 304 | Builders are cheap and engineers are not |
| 305 | Construction is a stream, not a purchase |
| 306 | The cost table is a shape |
| 307 | A factory is a line you did not design |
| 308 | A pattern is drawn once |
| 309 | Losing ground costs bodies |
| 310 | Thorns on the territory |
| 311 | Improving territory |

## Phase 4 — The Cloud

The air war, somewhere else. Planes go to a swarm above the field, fight in
rounds, leave when outmatched, and are chased over the guns. A scout's report
pulls bombers out of it.

Ends with: an air war that one side wins and then loses — winning the cloud,
following the losers over their anti-air, and coming home thinner.

| Issue | |
| --- | --- |
| 401 | The cloud is a place over the field |
| 402 | Planes fly from the factory to the cloud |
| 403 | Fight or avoid |
| 404 | Defensive planes fly over friendly ground |
| 405 | Anti-air shoots what flies over it |
| 406 | A report sends bombers |
| 407 | The plane upgrade table |

## Phase 5 — The Big Things

Everyone's experimentals, and the tier-two enforcer's relatives. Designed now,
built after the demo, because the record shapes have to hold them from the
start.

Ends with: a carrier crossing the field while building, stopping, and unleashing
what it built; and the same carrier told to keep hold, unleashing only when hit.

| Issue | |
| --- | --- |
| 501 | Everyone has the same experimentals |
| 502 | Experimental artillery |
| 503 | The gunship |
| 504 | The carrier builds while it moves |
| 505 | The experimental air factory unleashes bombers |
| 506 | Submarines and torpedo planes |

## Phase 6 — Watching It Happen

The real viewers. Everything up to here has been readable through a terminal and
a report; this is where it becomes a thing you look at and draw in.

Ends with: a person placing a factory, drawing a pattern in the sand with a
mouse, pressing one of four buttons, launching a plane on the compass wheel, and
watching the cloud in a corner of the window.

| Issue | |
| --- | --- |
| 601 | The window and the two snapshots |
| 602 | The dunes draw themselves |
| 603 | A view is a lens you adjust |
| 604 | The energy menu is always on screen |
| 605 | Drawing a pattern in the sand |
| 606 | The cloud in a small window |
| 607 | The compass wheel |
| 608 | The documentation gets its toys |
| 609 | The way in |
| 610 | A tileset raised by a tool |

## Phase 7 — Other Players

Lockstep: every machine runs the whole match, only intent crosses the wire. On a
computer the wire is a local network; on the handheld it is the sibling
project's transport, and that issue is a blueprint with its numbers marked
pending.

| Issue | |
| --- | --- |
| 701 | Lockstep, and why |
| 702 | Commands are scheduled for a later tick |
| 703 | Reaching a peer from a computer |
| 704 | Finding each other |
| 705 | A desync is named, not hidden |
| 706 | Dropping and rejoining |
| 707 | Reaching a peer from the handheld |
| 708 | Two people play a match — **capstone** |

## Phase 8 — The Handheld

The simulation as a map of boxes, two screens, a stylus, and a build the compile
script already knows the shape of.

| Issue | |
| --- | --- |
| 801 | The simulation is a map of boxes |
| 802 | Two screens, two lenses |
| 803 | Buttons, chords, and the four-button menu |
| 804 | Patterns drawn with a stylus |
| 805 | The handheld build |
| 806 | Two handhelds play a match — **capstone** |

## Phase 9 — An Opponent

Single-player. A bot that lays lines and draws patterns is also the instrument
that plays ten thousand matches overnight to find out whether any of this is
balanced. It cannot cheat, and that falls out of lockstep: it sees the same
snapshot a person does.

| Issue | |
| --- | --- |
| 901 | A bot that lays lines and draws patterns |
| 902 | Ten thousand matches overnight |
| 903 | Difficulty without cheating |
| 904 | A person against the bot — **capstone** |

---

## What is deliberately not in any phase

- **Selecting a unit and telling it where to go.** Subtracted, and its absence is
  the premise. Units follow the pattern they were born with.
- **Redesigning a pattern.** The vision forbids it. To change a route, build a
  factory.
- **A range circle.** There is no maximum range on anything. There are sightlines.
- **A fifth button on the energy menu.** Four is the design.
- **Internet play, or a server.** A match is a room of machines that can hear
  each other. The handheld's radio is ad-hoc; the computer's is a local network.
- **Faction-specific experimentals.** Everyone has the same ones.
- **A hand-drawn map.** Fields are raised from seeds.

## Before any of this is finished

The [open questions](016-open-questions.md) page holds every unresolved decision
found while writing these documents, with a working ruling marked as one
wherever a document had to fill a gap. They are meant to be worked through
one at a time with a person; a phase whose questions have not been worked
through is a phase being built on a guess.

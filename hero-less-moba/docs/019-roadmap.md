# 019 — Roadmap

Eight phases. They are **clusters of functionality**, not a schedule. Nothing here
is time-gated and nothing here is a progress bar. It is entirely normal for the
last issue completed in this project to belong to phase 1, because phase 1 holds
the foundations and foundations get revisited when the thing standing on them
turns out to be heavier than expected.

The ordering rule: **lower numbers are more foundational**, not earlier in time.
A phase-6 issue has more blockers standing in front of it than a phase-2 issue.
The final issue of phase 8 is the capstone — a full match, six players, start to
finish.

Each phase ends with a **demo** in `issues/completed/demos/`, runnable from a
script at the project root that asks which phase you want to see. The demos are
not development scrap. They are part of what this project delivers, they are kept
working, and each one shows the previous phases' tools recombined into something
the previous phase could not do on its own.

---

## Phase 1 — The Ground and the Clock

The world that does nothing. No soldiers, no fighting. A map, a heartbeat, a way
to get player intent in, a way to get pictures out, and the determinism guarantee
that every later phase depends on.

Ends with: a headless runner that advances an empty world ten thousand ticks and
a terminal viewer that draws three empty lanes, so that from phase 2 onward
nobody is ever working blind.

| Issue | |
| --- | --- |
| 101 | The path graph is built by a tool |
| 102 | Milestones measure a push |
| 103 | The world is flat arrays |
| 104 | The tick is a dispatch table |
| 105 | Randomness comes from named streams |
| 106 | Commands enter through one door |
| 107 | Snapshots and replays |
| 108 | The headless runner |
| 109 | A terminal viewer, so we are not blind |

## Phase 2 — Things That Walk and Fight

The soldier. One record, one brain, one combat system, used by everything that
will ever move. This is the phase the whole game lives or dies by, because with
heroes subtracted out there is no second system to distract from a bad one.

Ends with: two waves meeting in the middle of a lane and grinding to the
stalemate the vision describes. Seeing the stalemate is the point — it is the
problem statement, rendered.

| Issue | |
| --- | --- |
| 201 | A soldier is one record |
| 202 | Walking an edge of the graph |
| 203 | The brain is five states |
| 204 | Choosing what to attack |
| 205 | Damage is buffered, then applied |
| 206 | The frontline is a queue |
| 207 | Waves spawn on a cadence |
| 208 | A wave knows when it is gone |
| 209 | The thread pool slices the tick |

## Phase 3 — Things That Stand and Hold

Stone. Towers that shoot, guards that patrol, a base that is one open room, and
a library whose fall ends the match. After this phase a game can be won.

Ends with: a match that plays itself to completion — one side wins because of a
seeded coin-flip's worth of asymmetry, and the match report says which lane
did it.

| Issue | |
| --- | --- |
| 301 | A structure is a record with health |
| 302 | A tower picks a target and keeps it |
| 303 | Towers put guards on the ground |
| 304 | Guards are leashed |
| 305 | The base is one open room |
| 306 | Felling a tower pays three |
| 307 | The library ends the game |

## Phase 4 — The Shared Chest

The centre of the game. Upgrades, the pool they sit in, the lanes and stone they
go into, and the lock-and-objection negotiation between teammates.

Ends with: the phase-2 stalemate broken — the same two waves, but one lane's
soldiers are carrying three upgrades and the frontline is moving.

| Issue | |
| --- | --- |
| 401 | The upgrade catalogue |
| 402 | An instance is a thing in a place |
| 403 | Wiping a wave draws an upgrade |
| 404 | Placing an upgrade into a lane |
| 405 | A soldier is stamped at birth |
| 406 | Locking a placement |
| 407 | Two objections open a lock |
| 408 | Slotting upgrades into stone |
| 409 | The base inherits every lane |
| 410 | The library slot is the last stand |
| 411 | Rerolling the deck |

## Phase 5 — Commanders and Heroes

The fast layer. A private currency, bodies bought with it, abilities that fire on
their own, and the sign-posts that steer them.

Ends with: a match where one side's chest is empty and its players are winning on
hero purchases alone, against a side doing the opposite. Two economies, visibly
distinct.

| Issue | |
| --- | --- |
| 501 | The commander catalogue |
| 502 | Killing pays everyone on the team |
| 503 | A hero is a soldier you bought |
| 504 | Abilities are a dispatch table |
| 505 | Spawning onto a wave |
| 506 | Spawning onto a tower, and being pushed back |
| 507 | Spawning onto the library picks the worst lane |
| 508 | Sign-posts stand at the corners |
| 509 | Five heroes for the first commander |

## Phase 6 — The Surge and the Challenge
The layer that takes the board apart, and the thing that ends the match. Three
times a game the shape changes twice over: a **siege-surge**, where waves become a
stream and nobody can touch the chest — the whole chest is dealt across the three bodies spawning each instant
instead — and then a **challenge**, where waves return but all three lanes funnel
into the wide center to fight a named monster. The Pillar Orc, the Field Dragon,
and finally the Eternal Golem, which cannot be killed and advances until a
library falls.

Ends with: a full-length match containing all three surges and all three
challenges, with a timeline showing where each team's frontlines were before and
after each one — and terminating, because the Golem arrived somewhere.

| Issue | |
| --- | --- |
| 601 | The phase table |
| 602 | The surge turns waves into a stream |
| 603 | The chest, dealt across the three |
| 605 | Boons, and the calm they are chosen in |
| 606 | What walks out of the middle |
| 607 | Every lane spawns into the center |
| 608 | The deadline is the walk |

## Phase 7 — Watching It Happen

The real viewer. Everything up to here has been readable through a terminal and a
report; this is where it becomes a thing you look at and touch.

Ends with: a human playing a full match against the phase-8 bot with a mouse.

| Issue | |
| --- | --- |
| 701 | The window and the two snapshots |
| 702 | The map draws itself |
| 703 | The chest panel and the drag |
| 704 | Locks, objections, and refusals are loud |
| 705 | The sign-posts are clickable in the world |
| 706 | The documentation becomes HTML |

## Phase 8 — Six Players

Everything that assumes more than one person. Networking, a lobby, an opponent
worth practising against, and the machinery for running the game ten thousand
times to find out whether any of it is balanced.

| Issue | |
| --- | --- |
| 801 | Reconciling across machines |
| 802 | The lobby and commander selection |
| 803 | A bot that places upgrades |
| 804 | Ten thousand matches overnight |
| 805 | A full match, end to end — **capstone** |

---

## What is deliberately not in any phase

- **A shop.** Personal resource buys bodies and rerolls. Nothing else is for sale.
- **A jungle.** Subtracted. The connectors between junctions are the ground it
  used to occupy, with everything that made it jungle removed.
- **Items.** Subtracted. Upgrades are the replacement and they belong to the team.
- **A hero you drive.** Subtracted, and its absence is the premise.
- **The no-repeat-lane rule.** The vision describes one: during a surge, a player
  may not place into the same lane twice running. **It was cut**, deliberately, as
  arbitrary. Nothing replaces it — the surge already deals every upgrade evenly
  across all three lanes, which does the same job without a rule to explain. It is
  noted here only so that nobody re-derives it from the vision and puts it back.
- **A fog-of-war system.** There is no such system. You see the enemy's upgrades on
  the enemy's soldiers and nothing else, and their board reads two or three waves
  late because a change has to transit, spawn, and walk. **The fog is made of
  walking.**

## Before any of this is finished

The [open questions](020-open-questions.md) page holds every unresolved decision
found while writing these documents. Several of them — team size, what triggers a
surge, who a wave wipe pays — sit underneath multiple phases at once. They are
not decoration at the end of a document; a phase whose questions have not been
worked through is a phase being built on a guess.

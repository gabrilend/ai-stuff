# 601 — The Phase Table

| | |
| --- | --- |
| Phase | 6 — The Surge and the Challenge |
| Blocked by | 104, 207, 307 |
| Blocks | 602, 603, 605, 606, 607 |
| Reads | [the siege-surge](../docs/014-the-siege-surge.md), [boons and the challenge](../docs/015-boons-and-the-challenge.md) |
| Open questions | none |

## Current behavior

Four phases and the transitions between them, as one table: normal, siege-surge,
challenge, calm. Three surges and three challenges a match, on a visible clock, and the
third challenge is the one that does not end.

The clock is what makes a match finish. Before it, two even sides ground until somebody
stopped watching.

## Intended behavior

**Five rows, read by the spawner, the placement validator, the stamping step, and
the challenge system**, rather than each holding its own conditionals. Adding a
phase later is adding a row.

| Phase | Spawn shape | Spawn target | Each body carries | Placement | Towers | Chest grows on |
| --- | --- | --- | --- | --- | --- | --- |
| 1 normal | batches, long interval | own lane | its lane's placed upgrades | lane, stone, library | shoot, can fall, spawn guards | wave wipes, tower kills |
| 2 siege-surge | **one body per lane on one shared timer**, very short interval | own lane | **the whole chest dealt across the three** | **none — refused** | **shoot at baseline, cannot fall, spawn nothing** | **nothing** |
| 3 challenge | batches, normal interval | **center lane, all three** | its **spawning** lane's upgrades | lane, stone, library | shoot, can fall, spawn guards | wave wipes, tower kills, the monster |
| 4 calm | **nothing; everyone walks home** | — | — | lane, stone, library | as normal | — |
| 5 over | nothing | — | — | none | — | frozen |

Each row's reasoning lives with the system it governs — the surge in
[the siege-surge](../docs/014-the-siege-surge.md), the challenge and the calm in
[boons and the challenge](../docs/015-boons-and-the-challenge.md). Two things
belong to this issue specifically because nothing else owns them:

**A challenge index — first, second, or third.** The third spawns a different
archetype and **never ends**, so the both-monsters-dead check must not run for it.

**A full recompute of push depths when the calm finishes.** It is the one moment
in a match where the frontline moves backwards for everybody at once, and the
incremental maintenance from issue 102 cannot follow it.

### When a surge happens

**A fixed match clock, with the countdown visible to both teams.** Three per
match, at known ticks.

Write the trigger as a **single predicate function**, with the rejected options —
a hidden clock, and a trigger tied to the state of the game — named in a comment
beside it. The decision is made; keeping it cheap to revisit costs nothing.

### What ends a match

**The third challenge is the Eternal Golem and it cannot be killed.** It advances
until a library falls. That is what bounds a match — not a clock, not a score.
There is no time limit and no surrender, and none is needed.

## Suggested implementation steps

1. Write the phase table as data, and make the spawner, the placement handler,
   the stamping step, and the command pass read it.
2. Write the phase system as the eighth entry in the tick's dispatch table.
3. Write the trigger predicate against the match clock, with the surge ticks
   derived from a match-length constant so changing match length moves all three
   together.
4. Put the countdown into the snapshot **from the first tick**, not from shortly
   before a surge. The whole value of a visible clock is that it is visible early.
5. Add the challenge index, and make the third challenge skip the end check.
6. Recompute push depths on leaving the calm.
7. Raise `phase_changed { from, to, tick }` so the viewer can announce it and the
   report can time it.
8. Write a test that walks a match through all five phases and asserts each
   system's behaviour changes on the right tick.
9. Write a test that a match containing a third challenge **always terminates**,
   across many seeds with bots. A match that does not terminate is the worst
   failure this design can have, because it is the failure the whole project
   exists to prevent, arriving at the very end.

## Related documents and tools

- [The siege-surge](../docs/014-the-siege-surge.md) — rows 2 and the four-phase
  overview
- [Boons and the challenge](../docs/015-boons-and-the-challenge.md) — rows 3 and 4
- [The simulation tick](../docs/003-the-simulation-tick.md) — where the phase
  system sits

## Still open

**A visible clock lets a team hold its upgrades.** If everybody can see the surge
coming, the optimal play beforehand is to stop placing and let upgrades sit in the
chest. Much less severe than it was — an upgrade caught by a surge is still dealt
onto the field, while one in the chest does nothing — so holding costs something
real. Recorded as C1b.

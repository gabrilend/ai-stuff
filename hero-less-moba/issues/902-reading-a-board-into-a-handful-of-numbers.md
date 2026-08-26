# 902 — Reading a Board Into a Handful of Numbers

| | |
| --- | --- |
| Phase | 9 — An Opponent Worth Playing |
| Blocked by | 901 |
| Blocks | 903, 904, 905, 906 |
| Reads | [the map and its milestones](../docs/002-the-map-and-its-milestones.md) · [the shared upgrade pool](../docs/009-the-shared-upgrade-pool.md) |
| Open questions | none |

## Current behavior

A viewer frame is a few thousand bodies, a chest, and a phase. Nothing turns that
into anything a decision can be made from.

## Intended behavior

**A small, named set of numbers that describe a board, computed once per decision
and shared by every bot behaviour.** Not a neural network and not a score — a
handful of readings a person could also take by looking, which is the point.

The set should stay small enough to print. If a bot is bad, the first question is
"what did it think the board was," and that question has to be answerable by
reading one line.

The readings that matter, and every one of them is already a concept in the game
rather than a bot invention:

| Reading | From |
| --- | --- |
| **push depth per lane, both teams** | the team record, already maintained |
| **which lane is in the most trouble** | the largest enemy push depth — the same rule a library hero spawn uses |
| **chest shape** | how many unplaced instances, and which stats they touch — since an upgrade has no audience tag, what a chest is *for* has to be read off its effects |
| **lane fit** | for each lane, how much of what is placed there matches what walks out of it — see F22 |
| **stone versus bodies** | the ratio of tower-slotted to lane-slotted instances |
| **wallet pressure** | how close each player is to the ceiling, since overflow is pure waste |
| **time to the next surge** | the visible clock, which every player can also see |

**Lane fit is the one that is new and the one that matters most.** Since a wave
carries melee bodies, ranged bodies, and a captain that is one or the other, an
upgrade placed into a lane lands on only the part of the wave it matches. A bot
that cannot see the mismatch will place perfectly reasonable upgrades into lanes
where they do a fraction of their work, which is exactly the mistake a new human
makes and exactly the one that has to be visible before it can be fixed.

**Everything here is derived, nothing is stored.** These are a view of the frame,
recomputed on demand, and no bot behaviour may cache one across a decision — a
stale board reading is a bot playing the game from thirty seconds ago.

## Suggested implementation steps

1. Write the reading functions as a separate file from any bot behaviour. They
   are a *view* of a frame and belong on the viewing side of the project's line,
   not the deciding side.
2. Give each one a name that is a sentence a person would say. `lane_fit` is a
   reading; `f3` is not.
3. Write the printer first — one function that dumps a board reading as a few
   readable lines — and use it in every test in this phase. It is how every
   later bug in phase 9 gets diagnosed.
4. Write a test per reading against a hand-built frame with a known answer.
5. Check that the readings are computable from a frame **alone**, with no access
   to the world. If one is not, either the frame is missing something a human can
   see, or the reading is a cheat.

## Related documents and tools

- [The map and its milestones](../docs/002-the-map-and-its-milestones.md) — push
  depth, and why it is milestones rather than distance
- [The shared upgrade pool](../docs/009-the-shared-upgrade-pool.md) — slots,
  shapes, and what a chest is

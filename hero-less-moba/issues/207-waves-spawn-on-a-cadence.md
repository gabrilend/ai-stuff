# 207 — Waves Spawn on a Cadence

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 201, 202 |
| Blocks | 208, 405, 505, 602, 607 |
| Reads | [waves, and when one is finished](../docs/005-waves-and-when-one-is-finished.md) |
| Open questions | B1, B6 |

## Current behavior

Waves spawn on a cadence, one per lane per team, and the whole wave appears at
once already in its ranks. The commanders take turns, so the captain and the mixture
that walk out are somebody's in particular.

During a surge the spawner is a stream instead; during a calm nothing spawns; during
a challenge the waves go to the middle carrying their own lane's upgrades.

## Intended behavior

During the ordinary phase, **all three lanes spawn simultaneously on a fixed
interval measured in ticks**. Both teams use the same interval and the same body
count, so an unmodified match is exactly symmetric, and any asymmetry visible on
screen is the players' doing and nothing else.

A wave is not a loose handful of soldiers. It is a **record**, and every soldier
it spawns carries that record's id for its whole life:

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | integer | Monotonic. Never reused within a match. |
| `team` | integer | The team that *spawned* it. |
| `lane` | integer | 1–3. |
| `spawn_tick` | integer | When it left the base. |
| `member_count` | integer | How many it started with. |
| `living_count` | integer | How many are still alive. |
| `killed_any` | integer | 1 once the enemy has killed at least one member. |
| `settled` | integer | 1 once accounted for and forgettable. |
| `upgrade_mask` | integer | The lane's upgrade set at the instant of spawn. |

Without the grouping, the game could never notice a wave being wiped, because
"wiped" is a statement about a group and a pile of unrelated bodies has no groups
in it. That is issue 208 and it is the reason this record exists.

Waves are **not freed when they empty.** A settled wave stays in the array until
the match ends, so the post-match report can say how many waves each team lost in
each lane — the single most useful number for judging whether the upgrade economy
is balanced.

The spawner reads its interval and count out of a **phase table** row rather than
holding its own conditionals, so that the siege-surge's continuous stream and the
challenge's center-lane funnel are the same function reading different rows.
Issue 601 adds the other rows; this issue writes row 1 and the lookup.

## Suggested implementation steps

1. Write the wave record store, preallocated to a generous match's worth.
2. Write the phase table with row 1 filled and rows 2 through 4 marked as
   belonging to issue 601.
3. Write the spawn pass: on the interval, for each team, for each lane, create a
   wave and spawn its bodies at the library node with `facing` set outward.
4. Stamp each body with its wave id and with the lane's upgrade mask — a zero
   mask until phase 4 exists, but stamped, so that issue 405 changes one line.
5. Write a test that runs a match with no commands and asserts the two teams'
   worlds are exact mirrors at every tick. This is the **symmetry test**, it
   belongs in the build, and it catches asymmetry the day it is introduced.

## Related documents and tools

- [Waves, and when one is finished](../docs/005-waves-and-when-one-is-finished.md)
- The symmetry test (this issue creates it)

## Still open

How often, and how many bodies per wave? And downstream of that: how long should
a full match take, and therefore how many waves fall before the first
siege-surge? These are catalogue values, but nothing works until they are chosen,
and the first entry in the balance ledger should be them with a note on where
they came from.

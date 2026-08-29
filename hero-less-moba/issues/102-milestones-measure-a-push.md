# 102 — Milestones Measure a Push

| | |
| --- | --- |
| Phase | 1 — The Ground and the Clock |
| Blocked by | 101 |
| Blocks | 507, 608, 804 |
| Reads | [the map and its milestones](../docs/002-the-map-and-its-milestones.md), [the base and the library](../docs/008-the-base-and-the-library.md) |
| Open questions | none |

## Current behavior

Milestones are placed at fractions along each lane and their path indices are
precomputed, so "how far has this lane been pushed" is an integer comparison. Push
depth is recomputed from the living every tick — never a high-water mark, so it
collapses when bodies die — and is ignored outright during a challenge, when every
lane's production is in the middle and the number would read a team's own stone back
at it.

**Push depth is no longer counted in milestones.** It counts **zones**, which are
four times finer — each milestone interval divides into four, so a lane has
thirty-two of them and every milestone still lands exactly on a boundary. Nine
values could not tell a lane that was badly lost from one that was merely losing.
Everything else in this issue is unchanged, including the collapse at each calm.

A body still records the deepest milestone it has got past as well, because that is
what the marks along a lane are drawn from. See
[211a](211a-the-lane-is-cut-into-zones.md).

## Intended behavior

Each lane carries an ordered list of **nine milestones**, indexed 0 through 8,
running from team 1's library to team 2's library. Index 0 and 8 are the two
libraries; 1 and 7 are the base guard towers; 2, 3, 5, 6 are the four lane
towers; 4 is the midpoint where an even game's waves meet.

Each team keeps a **push depth** per lane: one small integer per team per lane,
the deepest milestone index that team's soldiers have reached, counted from that
team's own end. Two numbers per lane, not one signed number, because both teams
push at once and a single value cannot describe a lane where each side has
soldiers past the other's outer tower.

A soldier updates its own `milestone` field when it passes a milestone node; the
team's push depth is the maximum across its living soldiers in that lane, kept
incrementally rather than rescanned.

Every question the game asks about lane state becomes a comparison of these
integers. The important one: which lane is in the most trouble. A lane where the
enemy is one pace past your first tower is in **less** trouble than a lane where
the enemy is inside your base, even though your base is physically nearer your
library. Milestone comparison gets this right; a distance check gets it exactly
backwards, and it gets it backwards precisely in the case where being wrong costs
the match.

## Suggested implementation steps

1. Add `milestone_node[0..8]` to the lane record, filled by the map builder.
2. Add `milestone` to the soldier record, set at spawn to the spawning team's own
   end and updated in the move pass when a milestone node is passed.
3. Add `push_depth[team][lane]` to the world. Update it in the move pass when a
   soldier's milestone exceeds it, and recompute it in the reap pass **only for
   the lane a death occurred in** — never a full rescan.
4. Write `worst_lane(world, team)`: returns the lane where the enemy's push depth
   is greatest, ties broken by lane number, low first. Deterministic, and
   deliberately not using a random stream, so that a player watching two equally
   pressed lanes can predict where their hero will go.
5. Write a test that builds a world, places soldiers at known milestones, and
   asserts `worst_lane` picks the deep one — including the case where the deep
   lane is physically further from the library than the shallow one. That case is
   the whole reason this issue exists and it must be in the test suite.

## Related documents and tools

- [The map and its milestones](../docs/002-the-map-and-its-milestones.md)
- [The base and the library](../docs/008-the-base-and-the-library.md) — where
  `worst_lane` is used

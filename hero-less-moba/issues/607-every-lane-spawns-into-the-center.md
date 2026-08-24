# 607 — Every Lane Spawns Into the Center

| | |
| --- | --- |
| Phase | 6 — The Surge and the Challenge |
| Blocked by | 207, 405, 601, 602, 606 |
| Blocks | 608 |
| Reads | [boons and the challenge](../docs/015-boons-and-the-challenge.md) |
| Open questions | what happens in the side lanes |

## Current behavior

Monsters walk the center lane while the top and bottom lanes carry on as though
nothing were happening.

## Intended behavior

While a challenge runs, **all three lanes spawn their units into the center
lane** — as **waves at the normal interval**, not the surge's stream. The spawner
reads row 3 of the phase table and redirects.

The side lanes empty out for the duration. Their towers hold nothing, and the
entire match compresses into one corridor. Without the funnel, a team would fight
a monster with one lane's worth of soldiers while two thirds of its production
walked away from the problem.

**Waves rather than a stream is the load-bearing half.** A stream would pin a
monster in place indefinitely, because there would always be another body
arriving. The lull between waves is what lets it **lurch** — walk while the lane
is empty, slow when the next wave lands. The endgame's pulse is slow, lurch,
slow, lurch, and it makes the ground a badly lost wave costs you something a
player can watch.

**The center lane is topographically wider** than the sides, permanently, so all
three lanes' production arriving at once is a battle rather than a queue waiting
its turn to die. See [the map](../docs/002-the-map-and-its-milestones.md) and
issue 206.

### The stamping detail players will be caught by

**A funnelled soldier carries the upgrades of the lane it was *spawned for*, not
the center's.** So placing into the top lane during a challenge still means
something — you are strengthening one of three groups converging on the middle,
and a team that invested heavily in one lane does not watch that investment
evaporate.

The cost is legibility: three soldiers walking side by side can have wildly
different strength. That is why issue 702 owes the body a marker showing which
lane paid for it.

## Suggested implementation steps

1. Fill in row 3 of the phase table with the center-lane redirect and the normal
   wave interval.
2. Spawn redirected soldiers at the library node and enter them into the **center
   lane's** path, keeping `lane` pointing at the center — they walk it and count
   toward the center lane's push depth.
3. **Stamp the mask from the spawning lane, not from `lane`.** This is the one
   place those two differ, and it needs a comment saying so, because it looks
   like a bug.
4. Write a test asserting the mask comes from the spawning lane.
5. Write a test asserting the side lanes are empty of new spawns during a
   challenge and repopulate when it ends.

## Related documents and tools

- [Boons and the challenge](../docs/015-boons-and-the-challenge.md)
- [A soldier is stamped at birth](405-a-soldier-is-stamped-at-birth.md)

## Still open

**What happens in the side lanes?** They are empty of new spawns for the whole of
a challenge, and during the third that is the rest of the match. Nothing stops a
team ignoring the Golem and pushing a side lane instead — except that they have
no soldiers to push with, since all production is funnelled. Whether heroes can
still be sent down a side lane, and whether that is a legitimate strategy or a
hole, is not settled.

# 608 — The Deadline Is the Walk

| | |
| --- | --- |
| Phase | 6 — The Surge and the Challenge |
| Blocked by | 102, 307, 606, 607 |
| Blocks | 805 |
| Reads | [boons and the challenge](../docs/015-boons-and-the-challenge.md) |
| Open questions | none |

## Current behavior

Monsters walk toward the bases and, if they get there, do damage like anything
else. Nothing about a challenge is urgent.

## Intended behavior

**There is no timer. The deadline is how long the monster takes to walk.** If it
reaches a library it destroys it, and the team whose library it destroyed loses —
by the ordinary win condition from issue 307, not a special rule. Not both teams.

**So there is no game-over code in this issue at all.** A monster fells a library
the way anything else would. If a special case appears during implementation,
something has gone wrong upstream.

Why distance-as-deadline beats a countdown — a player who has never read a rules
screen can look at the map and know how long is left — is in
[boons and the challenge](../docs/015-boons-and-the-challenge.md).

### Two different endings

| | First two challenges | The third |
| --- | --- | --- |
| Ends when | both monsters are dead | **a library falls** |
| Can be survived | yes — kill it, then the calm | **no. Only delayed.** |
| Phase afterwards | the calm, then normal | there is no afterwards |

If one of the first two is dead and the other is not, the phase continues, and
the team that already won its half **keeps spawning into the center** — their
soldiers walking up the middle are also soldiers walking at the enemy base, so
the reward for finishing first is a free push rather than an excusal.

## Suggested implementation steps

1. Let a monster fight a library through the ordinary structure damage path. No
   special case.
2. Write the challenge-end check for the first two: both dead, phase moves to the
   calm.
3. Write the challenge-index guard so the third **never** runs that check.
4. Write the one-dead-one-alive case explicitly, including the free-push
   consequence, and test it.
5. Have the viewer show each monster's remaining distance in milestones —
   **permanently** during the third challenge rather than as a transient banner.
   It is the match clock now.
6. Write a test: let a monster reach a library, assert the right team loses.
7. Write a test: kill one monster early, assert the phase continues and the
   winning team still spawns into the center.
8. Write a test that **a match containing a third challenge always terminates**,
   across many seeds with bots. A match that does not terminate is the worst
   failure this design can have — it is the failure the whole project exists to
   prevent, arriving at the very end.

## Related documents and tools

- [Boons and the challenge](../docs/015-boons-and-the-challenge.md)
- [The library ends the game](307-the-library-ends-the-game.md)

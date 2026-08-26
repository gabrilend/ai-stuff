# 036-the-frontline

The queue that makes a wave read as a wave rather than as a smear.

## What it is for

Soldiers do not overlap and do not push each other. When a body closing on a fight
would end its move inside the personal space of a friendly body ahead of it, it
**stops short instead**. The result is a queue: the front rank fights, the ranks
behind stack up along the lane and step forward as the front rank dies.

That is what makes a lane upgrade legible from across the map. A stronger front rank
visibly holds its ground while the enemy's queue backs up behind it, and a player
reads "I am winning that lane" off the shape of two crowds rather than off a number.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `blocked(world, id)` | | Whether this body must stop short this tick. |
| `for_each_candidate(world, id, spacing, visit)` | | — Every body within one personal space. |

## A rank is a melee thing

The rule above was written when every body wanted the same place — the front — and
everything behind it was waiting its turn to get there. **A ranged body does not want
the front and never did.**

| Reach | Behaviour |
| --- | --- |
| melee | Form the rank. Stop short behind whoever is ahead, step up as the front thins. |
| ranged | Hold at your own reach *behind* the rank and shoot over it. Not queueing for a place you will eventually take. |

Treating a ranged body as a rank-in-waiting pushes it into melee range and deletes
the distinction entirely. So a ranged body keeps a **smaller bubble** — it only needs
enough room not to stand inside a friend, and giving it a full rank's spacing would
push the back of a wave a long way down the lane for no reason.

The consequence for how a frontline reads: **a lane's depth is informative.** A wave
that has lost its melee rank but kept its ranged bodies is about to evaporate, and it
looks different from one that has lost everything. That is a thing a player can see
and act on from across the map, without a number anywhere.

## "Ahead" is a comparison, not a distance

`lane_position` is a body's path index plus how far it is across the current edge.
Comparing two of them is comparing progress down the same corridor. It is **not** a
distance — the steps are only roughly even — and it is never used as one.

Multiplying the difference by `facing` folds the two directions into one comparison,
so team 2's bodies walking backwards down the path array queue exactly like team 1's.

## What does not queue

Only friendly bodies block. An enemy in the way is not an obstacle, it is a target,
and [targeting](035-targeting.info.md) has already had its say by the time this is
asked.

A body with no lane — a guard on patrol — is in nobody's queue. Guards wander; they
are not going anywhere that queueing would help them reach.

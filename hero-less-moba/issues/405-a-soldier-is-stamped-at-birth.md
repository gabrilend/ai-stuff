# 405 — A Soldier Is Stamped at Birth

| | |
| --- | --- |
| Phase | 4 — The Shared Chest |
| Blocked by | 205, 207, 401, 404 |
| Blocks | 607, 804 |
| Reads | [a unit and what it carries](../docs/004-a-unit-and-what-it-carries.md), [the shared upgrade pool](../docs/009-the-shared-upgrade-pool.md) |
| Open questions | none |

## Current behavior

A body is stamped at birth from its lane's slot plus its team's boons, and the
modifiers are folded into its own fields rather than walked on every swing. It is
never corrected afterwards — moving an upgrade out of a lane does not weaken the
soldiers already walking in it.

A guard is the exception and is re-stamped when its tower changes, because it stands
at the thing it copied from for its whole life.

## Intended behavior

At spawn, a soldier's `upgrade_mask` is copied from its lane's `lane_mask`. On
every swing, the mask is walked and each set bit's modifier applied.

**The mask is stamped once and never recomputed.** This is the largest
performance decision in the unit system: the alternative is every soldier reading
back into team state on every swing, hundreds of times a tick, to get an answer
that changes a few times a minute.

It also has a design consequence that must be told to players in as many words:

> Moving an upgrade out of a lane does not weaken the soldiers already walking in
> it. They keep what they were born with until they die.

That delay is not a compromise, it is the mechanism. It turns every reassignment
into a bet placed one wave ahead, which is what makes a reassignment worth
arguing about, which is what the lock-and-objection system exists to mediate. Without
the delay, placement is instant and reversible and there is nothing to negotiate.

Towers are the opposite and it is deliberate: a tower stands for the whole match
and reads its mask **live**, so a tower upgrade takes effect immediately. Stone
is the fast option and soldiers are the slow one. That asymmetry is not an
inconsistency to be smoothed out; it is the reason a player under pressure
reaches for the stone. See issue 408.

The wave record also keeps a copy of the mask it spawned with, so the post-match
report can say what each wave was carrying when it died.

## Suggested implementation steps

1. Change the one line in the spawner that currently stamps a zero mask.
2. Wire the mask into the damage calculation in the attack pass, additive terms
   before multiplicative.
3. Wire it into the body fields — health, armour, speed, range, cooldown — at
   spawn rather than at use, since those are read far more often than damage.
4. Wire the behaviour dispatch entries in: a set behaviour bit means an extra
   call in the attack or death path.
5. Write the phase-4 demo around this: the same two waves as the phase-2 demo,
   but one lane's soldiers carrying three upgrades, and the frontline moving.
   **That demo is the proof the whole design rests on** — the stalemate broken by
   the thing that replaced heroes.
6. Write a test that spawns a soldier, moves the upgrade out of its lane, and
   asserts the soldier's damage is unchanged.

## Related documents and tools

- [A unit and what it carries](../docs/004-a-unit-and-what-it-carries.md)
- [The shared upgrade pool](../docs/009-the-shared-upgrade-pool.md)
- The phase-2 demo, which this is the answer to

## Still open

During a challenge, all three lanes spawn into the center lane. Are those
soldiers stamped with the lane they were **spawned for**, or with the center
lane's mask? The working ruling is the former, because restamping would make a
top-lane investment vanish for the duration and punish a strategy the vision
blesses. But it means three visually identical soldiers walking side by side can
have wildly different strength, which is hard to read on screen.

# 205 — Damage Is Buffered, Then Applied

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 104, 203 |
| Blocks | 208, 301, 306, 307, 405, 502, 504 |
| Reads | [combat and damage](../docs/006-combat-and-damage.md) |
| Open questions | none |

## Current behavior

Attacks write into a buffer and a separate pass applies it, so two bodies that
would kill each other on the same tick both do. Armour is subtracted and floored at a
small positive minimum — a blow never heals, and nothing is ever immune.

Nothing records who dealt the damage, because nothing needs to: the reap pass reads
the dead body's own team and pays the other one.

## Intended behavior

**Nothing writes to a health value during the attack pass.** Attacks write into
`pending_damage`, a flat array of doubles with one slot per soldier and one per
structure, cleared at the top of every tick. A separate resolve pass adds the
buffer into health and marks anything at or below zero as dying.

The reason is simultaneity, and it is not an optimisation. Two soldiers on their
last sliver of health, both off cooldown on the same tick, should **both die**.
If damage applied immediately, whichever the loop reached first would win — and
which one that is depends on slot ordering, which depends on which soldier died
four minutes ago and freed that slot. That is real, reproducible, and completely
unexplainable unfairness.

It also makes the attack pass safe to slice across the thread pool: every worker
writes into distinct slots of a preallocated array and reads nothing another
worker is writing.

One swing, start to finish:

1. Decrement `cooldown`. If above zero, done.
2. Straight-line distance to the target against `range`. **This is the only place
   in the game that uses as-the-crow-flies distance.** Everything about progress
   and lanes uses milestones. Say so in a comment, because the next person to
   need a distance will not know that.
3. Base `damage`, then the attacker's `upgrade_mask` walked — additive terms
   first, then multiplicative.
4. Subtract the defender's `armour`, floored at a small **positive** minimum. Not
   floored at zero. A defender that cannot be hurt at all is a permanent
   stalemate, and permanent stalemate is the failure this entire game is built to
   avoid.
5. Add into `pending_damage[target]`. Write the attacker's id into
   `last_hit_by[target]`, overwriting. Last hit, not most damage, decides who is
   paid.
6. Reset `cooldown`.

## Suggested implementation steps

1. Write the pending-damage buffer, preallocated, cleared with a fill rather than
   a loop.
2. Write the attack pass, sliced for the pool.
3. Write the resolve pass, single-threaded and short.
4. Write `last_hit_by` and leave the payout to issue 502 — but write the field
   now, because retrofitting attribution after combat exists means auditing every
   damage source.
5. Write a test: two soldiers, mutually lethal, same tick. Assert both die.
6. Write a test: armour far above damage. Assert the target still loses health.

## Related documents and tools

- [Combat and damage](../docs/006-combat-and-damage.md)
- [The simulation tick](../docs/003-the-simulation-tick.md) — where the two
  passes sit

## Settled

`last_hit_by` walks back to the killer's **team**, and every player on that team
is paid — it does not matter what did the killing. See
[combat and damage](../docs/006-combat-and-damage.md).

Write the field here rather than in phase 5 anyway: retrofitting attribution
after combat exists means auditing every damage source.


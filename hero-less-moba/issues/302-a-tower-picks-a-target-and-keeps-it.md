# 302 — A Tower Picks a Target and Keeps It

| | |
| --- | --- |
| Phase | 3 — Things That Stand and Hold |
| Blocked by | 204, 301 |
| Blocks | 306, 408, 409 |
| Reads | [guard towers and their guards](../docs/007-guard-towers-and-their-guards.md) |
| Open questions | none |

## Current behavior

A tower shoots the nearest enemy in range and keeps that target while it lives and
stays in range. Sticky rather than nearest-every-tick: one that re-picks spreads its
damage across a wave and kills nothing, which feels like weather rather than a
defence.

Nearest rather than lowest-health, unlike a body — a tower is defending a piece of
ground, and the thing about to walk past it is what matters.

## Intended behavior

A tower shoots the **nearest enemy soldier inside its range**, and it does not
change its mind while that target lives and stays in range.

Sticky targeting, not nearest-every-tick, and the reason is the whole feel of a
tower. A tower that re-picks constantly spreads its damage across a whole wave and
kills nothing — it becomes weather, an ambient drain that a wave walks through. A
tower that commits kills one soldier every few seconds, and a player can watch it
happen and count.

A tower's `range` is a **plain radius** around its position. It knows nothing
about lanes. This matters most in the base, where three towers stand near each
other: their radii overlap a little, cover their own lane's mouth well, and do not
reach the far side of the base. Bodies flow across a base freely; arrows do not.

A tower cannot attack a structure and has nothing to say about them.

Towers do not participate in the acquisition-range-wider-than-weapon-range rule
that soldiers use. A tower does not need to commit early, because it is not going
anywhere.

## Suggested implementation steps

1. Write the tower attack pass as part of the existing attack pass, reading the
   same milestone buckets built in issue 204.
2. Write the stickiness: only search for a new target when `target` is 0, when
   the stored generation no longer validates, or when the target has left range.
3. Write into `pending_damage` exactly as a soldier does. There is no second
   damage path. Comment this, because a tower is the most tempting place to add
   one.
4. Write a test: a wave of ten walking past one tower. Assert the tower kills a
   whole number of soldiers rather than leaving ten wounded ones, which is the
   observable difference between sticky and non-sticky targeting.
5. Write a test placing enemies just inside and just outside the radius and
   assert the boundary behaves as documented rather than as an off-by-one.

## Related documents and tools

- [Guard towers and their guards](../docs/007-guard-towers-and-their-guards.md)
- [Combat and damage](../docs/006-combat-and-damage.md)

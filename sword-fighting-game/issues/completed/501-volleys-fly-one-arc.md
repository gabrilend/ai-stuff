# 501 — Volleys Fly One Arc

| | |
| --- | --- |
| Phase | 5 — Command and the round |
| Blocked by | 303, 305 |
| Blocks | 502, 601 |
| Files | `src/013-ranged.lua` |
| Reads | `docs/datapath-volleys.md` |

## Current behavior

Built in `src/013-ranged.lua`. The enemy commander's mind leads its
throw: it fires when the gap between the fronts, less the closing during the
flight, puts its middle rank's darts on the enemy's middle rank (without
that, every volley fell short). About one dart in twelve hits. Tested in
tests/035-command-and-growth.lua.

## Intended behavior

**A volley** (left click in third person) is thrown by every standing soldier
of the player's contingent who is not engaged in melee. Each thrown weapon
flies the same arc, because everyone trained the same way and no one can see
how far the enemy is: it lands **three battalion lengths** ahead of the
thrower, along the contingent's facing, scattered by a small spread. The
commander's click chooses *when*, not *where* — the ring under the mouse
shows where the arc will land, and it is always at range 3. The trained-arc
perk unlocks ranges 1, 2 and 3 (keys 1, 2, 3).

A volley has a cooldown (configuration). Each dart is a record: start, end,
flight time, elapsed, damage, team. It lands at the end of its flight; a
soldier within the hit radius of the landing point takes the hit, through the
same resolution order as a melee hit (303) with the volley's damage, except
that the parry step uses the **shield** bonus: a soldier behind a raised
shield wall parries volleys much more often. Darts landing on empty ground
are counted as misses.

**The shield wall** (right click held in third person) raises shields on the
whole contingent: a parry bonus (larger against volleys), and a walking
penalty. The enemy commander's mind throws volleys and raises shields on its
own, with the same rules.

## Suggested implementation steps

1. Write volley launch, dart flight, landing and the shield flags.
2. Test: a volley always lands at three battalion lengths without the perk;
   raised shields reduce volley damage taken over many seeds.

# 039-waves

Where bodies come from, and how the game notices a group of them is gone.

## What it is for

Ordinary soldiers are not spawned as loose individuals. A **wave** is a record, and
every soldier it spawns carries that record's id for its whole life. Without this the
game could never notice a wave being wiped, because "wiped" is a statement about a
group and a pile of unrelated bodies has no groups in it.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `begin(world)` | | — Sets the cadence running. Called once at assembly. |
| `spawn_pass(world)` | | — Starts waves when due, then puts on the ground whatever is due. |
| `spawn_body(world, team, lane, archetype, wave_id)` | | The new body's id. |
| `member_died(world, wave_id)` | | — One member gone. Called once per death from the reap pass. |

## The wave record

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | integer | Monotonic, never reused. |
| `team` | integer | The team that **spawned** it. |
| `lane` | integer | 1–3. |
| `spawn_tick` | integer | When it left the base. |
| `member_count` | integer | How many bodies it started with. |
| `living_count` | integer | How many are still alive. |
| `killed_any` | integer | 1 once at least one member has been killed. |
| `settled` | integer | 1 once accounted for. |
| `upgrade_count` | integer[kinds] | The lane's counts at the instant of spawn, for the report. |

Waves **accumulate** and are not freed when they empty, so the post-match report can
say how many waves each team lost in each lane — the single most useful number for
judging whether the upgrade economy is balanced.

## A wave is three kinds of body

Melee, ranged, and a captain — **one captain per lane, every wave.** That rule is what
makes every lane worth contesting: each carries a body worth about three ordinary
ones, so a lane you never contest is a captain you never collect.

All three are stamped with the lane's upgrades, **including the captain**, which is
exactly what separates a captain from a hero. In a lane carrying a dozen upgrades the
captain walking out of it is enormous.

**The order they leave in is deliberate**: captain, then melee, then ranged — so that
by the time the column meets anything, the bodies that want the front are already in
front of the bodies that do not.

## "Fully defeated"

`living_count == 0` **and** `killed_any == 1`. Both halves matter:

- Zero alone is not enough: a wave can also empty by its members walking into an enemy
  library and ending the game, or by being removed at match end. Neither should pay
  anybody.
- `killed_any` is set the first time a member dies to enemy damage of any kind —
  soldiers, towers, or a monster. A wave that dies entirely to towers still counts.

The check runs in the reap pass, immediately after a death is applied, **on the one
wave the dead soldier pointed at**. It does not scan all waves every tick.

## Who gets paid

**The team that did *not* spawn the wave.** Team 1's chest fills up by killing team 2's
soldiers.

Which makes the upgrade economy a snowball by design: a team winning a lane is killing
more waves in it and therefore drawing more upgrades, which wins the lane harder. The
siege-surge is the only thing that brakes it, and it does so by destroying the
*arrangement* rather than by taking anything away.

## Where a body enters its lane

Team 1 at path index 1 walking forward; team 2 at the far end walking backward. One
path array, read in two directions.

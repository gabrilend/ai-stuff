# 007 — Guard Towers and Their Guards

**Datapath document.** Covers the stone: where towers stand, what they shoot,
the soldiers they put on the ground around them, and the three-upgrade prize for
knocking one down.

## Where they stand

Every guard tower is the same strength as every other guard tower. There are no
tiers, no inner-tower-is-tougher rule. Eight per team:

- **Two on each lane**, at milestone indices 2 and 3 counted from that team's own
  library — an inner and an outer.
- **Three inside the base**, at milestone index 1 of each lane. These are the
  base guard towers. They are ordinary towers in every respect except that they
  cannot be slotted with upgrades directly; see
  [upgrades slotted into stone](010-upgrades-slotted-into-stone.md).

Keeping all towers identical is what makes tower upgrades interesting. If towers
already differed, a slotted upgrade would be a small adjustment to an existing
hierarchy. Because they are flat, a slotted upgrade is the *only* thing that
distinguishes one lane's stone from another's, and that makes the slotting
decision visible from across the map.

## structure record

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | integer | Index in the structure array. |
| `team` | integer | 1 or 2. |
| `kind` | integer | 1 lane tower, 2 base tower, 3 library. |
| `lane` | integer | 1–3. Base towers keep the lane whose mouth they cover. |
| `milestone` | integer | 1, 2, or 3 from the owning team's end. 0 for a library. |
| `node` | integer | Where it stands on the path graph. |
| `health`, `health_max` | double | Current and full. |
| `damage` | double | Per arrow. |
| `range` | double | In paces. A plain radius — it does not know what a lane is. |
| `cooldown`, `cooldown_max` | integer | Ticks between arrows. |
| `target` | integer | Soldier id, or **0**. |
| `guard_slot` | integer[] | Soldier ids of its living guards. Zeros for empty slots. |
| `guard_timer` | integer | Ticks until the next guard is put on the ground. |
| `alive` | integer | 1 or 0. A felled tower stays in the array as rubble. |

## What a tower shoots

The nearest enemy soldier inside `range`, and it does not change its mind while
that target lives and stays in range. Sticky targeting is chosen over
nearest-every-tick because a tower that re-picks constantly spreads its damage
across a whole wave and kills nothing, which makes it feel like weather rather
than a defence. A tower that commits kills one soldier every few seconds, and a
player can watch it happen and count.

A tower cannot attack a structure and has nothing to say about them.

## Guards

Each tower keeps a small standing patrol. On a timer, if it has an empty guard
slot, it puts a soldier on the ground at its own node. That soldier is an
ordinary body — same record, same brain — with two differences:

- `leash_node` is set to the tower's node. The guard will engage anything that
  comes inside its acquisition range, but the moment its target dies or it drifts
  past the leash radius it enters the **leashing** state and walks home, refusing
  to acquire on the way.
- `facing` is 0 while patrolling. It wanders inside the leash radius using the
  `wander` random stream rather than advancing along the lane.

Guards do not advance with a wave and do not follow a retreating enemy down the
lane. They are area denial: the reason a lone hero cannot walk past a tower and
keep going, and the reason the ground *around* a tower is dangerous rather than
just the tower's tile.

### Guards carry their tower's upgrades

**A guard is stamped at spawn with the stone upgrades of the lane its tower
stands on** — `tower_mask[lane]` for a lane tower, and `base_tower_mask` for a
base tower, which is the union of all three lanes' stone plus the library.
*Settled; see [open questions](020-open-questions.md), A18.*

Stamped at spawn, like a wave unit, and for the same reason: a guard is a
short-lived body and the mask is read on every swing. Unlike the tower itself,
which stands for the whole match and reads its mask live.

This means **slotting an upgrade into a lane's stone buys bodies as well as
arrows.** It is a larger purchase than it looks, and it compounds with A5 — an
investment the enemy already cannot take away now also puts stronger soldiers on
the ground.

Which is exactly why the balance work has to be careful here. The running
instruction from A5 was that stone must be *worse at pushing a frontline* than
soldiers are, by enough to be obvious. This answer pushes in the opposite
direction, because guards are bodies and bodies fight. The reconciliation is that
guards are **leashed** — they hold ground and cannot take any. A stone upgrade
buys you a better wall; it still cannot buy you a step forward. That distinction
is the whole reason the two slots stay meaningfully different, and if leashing
were ever loosened, this would be the rule that broke first.

### The base is different

The three towers inside a base share one patrol area rather than three. Guards
spawned by any base tower will move to attack invaders **from any lane**, because
the interior of a base is one open space rather than three corridors. What stops
this from turning the base into an impenetrable ball is the towers themselves:
their `range` is a plain radius around each tower, so in practice a base tower's
arrows only reach the mouth of the one lane it sits at. Bodies flow across the
base freely; arrows do not.

The consequence to communicate to players: pushing into a base means fighting
every guard in it at once, but only under the arrows of the one tower you walked
past. Splitting a push across two lanes into the same base is therefore
meaningfully better than doubling up on one, which is another shove away from
tunnel vision.

Exactly which reading of the vision this is — "the guards" as soldiers versus as
towers — is an [open question](020-open-questions.md).

## Towers step back during a siege-surge

For the duration of a surge, and only then:

| | Normally | During a siege-surge |
| --- | --- | --- |
| Shoots | yes, with its stone upgrades | **yes, at baseline** — its upgrades are feeding the stream instead |
| Can be destroyed | yes | **no** |
| Spawns guards | yes, at its own node | **no** |
| Its guards | patrol the tower | **spawn from the base as ordinary stream bodies** |

*Settled; see [open questions](020-open-questions.md), A6c.*

**Invulnerability is what stops a surge being a siege window.** A team with the
stronger stream would otherwise use the phase to take stone cheaply while
everything was chaotic, and the surge would become a reward for already winning
rather than a disruption of it. It also means no tower falls during a surge, so
the three-upgrade tower reward never fires — which, with no wave wipes to detect
either, is why **the chest does not grow at all during a siege-surge.**

**Guard production moving to the base** is the detail worth telling players. Your
patrols do not stand around during a surge; they walk out and join the flood. The
defence goes to meet the fight instead of waiting at home for it, and the ground
around your towers — normally the most dangerous ground on the map — is briefly
empty.

Those guards spawn as ordinary stream bodies and are stamped like ordinary stream
bodies: a **share of the chest dealt across the three bodies spawning that instant**, not the stone upgrades they would
carry in any other phase. See [the siege-surge](014-the-siege-surge.md).

## Felling a tower pays three upgrades

When a tower's health reaches zero:

1. It is marked dead. Its node's `structure` field is cleared to 0, so soldiers
   stop treating it as an obstacle or a target.
2. Its living guards are killed immediately. They do not survive their tower.
3. **Three upgrades are drawn into the destroying team's chest**, one after
   another from that team's own index into the shared deck. Not one upgrade worth
   three times as much — three separate draws, three separate things to place.
   The vision says "three unit upgrades" and the plurality is the point: felling
   a tower should trigger a burst of placement decisions, which is a burst of
   teamwork.
4. **The lane's slotted upgrades are untouched.** An upgrade is slotted into a
   lane's stone as a whole, never into one specific tower, so there is nothing in
   a felled tower to return. The lane's other tower keeps the upgrade, and even
   when both of a lane's towers are gone the upgrade keeps firing — out of the
   three towers in the base, which inherit every lane's stone. *Settled; see
   [open questions](020-open-questions.md), A5.*
5. The rubble stays in the structure array so the renderer can draw it and the
   post-match report can find it.

Towers do not regenerate and do not come back.

## What A5 means for the value of stone

Stating this plainly because it is a large consequence of a small rule: **a tower
upgrade cannot be taken away from you by anything the enemy does.** Killing your
towers does not touch it. The only thing in the entire game that can dislodge an
upgrade from your stone is a siege-surge.

Two things follow.

**Stone and soldiers are not symmetric investments.** A lane upgrade makes every
wave unit you spawn into that lane stronger, and the enemy reduces its value by
killing those waves faster than you make them. A stone upgrade makes your towers
stronger, and there is no play the enemy can make that reduces its value at all.
That asymmetry is now a deliberate part of the design rather than an oversight,
and it is what the balance work has to price: stone should be *worse* than
soldiers at pushing a frontline, or nobody will ever put an upgrade in a lane.

**A last stand is viable in a way it would not otherwise be.** A team that
invested in stone and then lost all six lane towers still has three fully
upgraded base towers, because the base was inheriting those upgrades the whole
time. That is not a comeback mechanic — it does not reward losing — but it does
mean an investment made while winning is still working while losing, which is
what makes defending a base something other than a formality.

Related: [the map](002-the-map-and-its-milestones.md) ·
[the base and the library](008-the-base-and-the-library.md) ·
[upgrades slotted into stone](010-upgrades-slotted-into-stone.md) ·
[combat and damage](006-combat-and-damage.md)

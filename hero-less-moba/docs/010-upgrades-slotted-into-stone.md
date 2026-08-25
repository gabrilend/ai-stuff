# 010 — Upgrades Slotted Into Stone

**Datapath document.** Covers the second thing you can do with an upgrade: put it
into a lane's towers instead of a lane's soldiers, and the rule that quietly
makes every lane's stone contribute to the defence of the base.

## The two destinations

An upgrade instance placed at a lane sits in one of two different slots, and the
player picks which:

| Slot | Who receives it |
| --- | --- |
| **the lane** | Every wave unit this team spawns into that lane from now on. |
| **the lane's towers** | Both guard towers standing on that lane — *and* all three towers inside the base. |

An upgrade is in one slot or the other, never both. Slotting into stone is
therefore a real trade: soldiers that walk forward and die, or stone that stays
put and does not. A team with an early lead wants the former; a team that has
lost its outer towers wants the latter.

### The tower slot has two audiences

An upgrade slotted into a lane's towers is not delivered to one recipient. It is
delivered to two, and they are shaped differently. *Settled; see
[open questions](020-open-questions.md), F21.*

- **The guards are melee.** They walk, they close, they swing.
- **The tower is ranged.** It stands still and shoots.

So the upgrade applies according to what it is:

| The upgrade is | The guards get it | The tower gets it |
| --- | --- | --- |
| **melee** | **yes** | no |
| **ranged** | no | **yes** |
| **common** — health, armour, and the like | **yes** | **yes** |

That is why an upgrade in this slot applies to the guards and *possibly* the
tower. A melee damage upgrade slotted here is not wasted and is not refused; it
buys a harder patrol and does nothing for the arrows. A player who slots one is
buying bodies, and a player who slots a ranged one is buying arrows, out of the
same slot.

**An earlier version of this document had this wrong**, and the wrongness is
worth recording because the reasoning was plausible: it said "speed and health
upgrades on an immobile building are meaningless" and refused them here. That
holds only if the slot feeds a building. It feeds a patrol as well — so a
movement-speed upgrade slotted into a lane's towers makes its guards cover their
ground faster and answer a breach sooner, which is a real purchase and one of the
more interesting ones in the slot.

**So the refusal test is narrow: a placement into the tower slot is refused only
when the upgrade helps neither the guards nor the tower.** Given that guards are
ordinary soldiers with ordinary stats, that set is small and may well be empty.

Nothing is consumed by any of this. An upgrade sitting in a slot is a **standing
property of that slot**, not a resource spent into bodies — it applies for as long
as it sits there, and moving it away is the only thing that stops it.

## The base inherits everything

This is the rule worth reading twice.

> **An upgrade slotted into *any* lane's towers also applies to *all three* of
> your base guard towers.**

So the three towers inside a base receive the union of:

- upgrades slotted into the top lane's towers, plus
- upgrades slotted into the center lane's towers, plus
- upgrades slotted into the bottom lane's towers, plus
- upgrades slotted directly into the library.

The vision's own worked example: your left flank is falling apart and the enemy
is inside your base, but your tower upgrades are all sitting in the center and
right lanes. Those upgrades are nevertheless firing out of the base tower
covering the left. Your investment in two healthy lanes is what is holding the
third one's doorway.

Two things follow that are worth saying to players in as many words:

1. **Tower upgrades are never wasted.** A tower upgrade in a lane whose towers
   have already fallen is still doing work, because the base towers still exist.
   This is the opposite of how tower investment usually behaves in a lane-pusher,
   where losing the tower loses the investment.
2. **The base is strongest when the game is going well**, which is exactly
   backwards from a comeback mechanic and entirely on purpose. A team that is
   being ground down does not get a fortress handed to them. What they get is the
   library slot, below, which costs them something.

## The library slot

Upgrades cannot be slotted into base guard towers directly. The only way to give
the base something the lanes are not already giving it is to slot an upgrade into
the **library**, which applies it to the three base towers and nothing else.

The vision calls this rare and says it usually only comes up once all the lane
towers are destroyed. That is the shape it should have: the library slot is where
a losing team puts its upgrades, because the lanes it would rather be
strengthening have no stone left standing to hold them. Every upgrade a team
commits to the library is an upgrade not making its soldiers stronger, at a
moment when its soldiers are the only thing that can push the frontline back out
of its base.

There is no cap on library slots any more than there is on lane placements. A
last stand is allowed to be total.

## How a tower reads its upgrades

Towers, unlike soldiers, are **not** stamped once. A soldier is born, carries
what it was born with, and dies; a tower stands for the whole match, so it reads
its counts live:

- A lane tower on lane L reads `tower_count[L]`.
- A base tower reads the **sum** of every lane's `tower_count` row and
  `library_count`, precomputed into `base_tower_count` whenever any placement
  changes.

Note that it sums rather than unions. Under the old bit set the base towers
merged three lanes' stone and silently lost the duplicates; with counts, a team
that slotted the same kind into two different lanes' towers gets both copies in
the base. That follows directly from stacking, and it makes the base meaningfully
stronger than the old rule did.

**A tower's guards read through the tower**, so they carry whatever it currently
has — they are not stamped. See
[guard towers](007-guard-towers-and-their-guards.md), F1.

The consequence is that a tower upgrade takes effect **immediately** on
placement, while a lane upgrade takes effect on the **next wave**. That asymmetry
is not an inconsistency to be smoothed out; it is the reason a player under
pressure reaches for the stone. Stone is the fast option and soldiers are the
slow one.

One caveat on "immediately," and it is the one that touches guards: an upgrade
**queued to move** does not leave until the next wave spawns, so a tower and its
guards keep what they have until that instant and then change together. There is
exactly one moment in the match's rhythm when anything changes hands.

## When the stone falls

**Nothing happens.** *Settled; see [open questions](020-open-questions.md), A5.*

An upgrade is slotted into a lane's stone **as a whole**, never into one specific
tower, so a felled tower has nothing in it to lose. The lane's other tower keeps
the upgrade. And when both of a lane's towers are gone, the upgrade is still
working — through the three base towers, which have been inheriting every lane's
stone the whole time.

The consequence is worth being blunt about, because it is larger than the rule
looks: **a tower upgrade cannot be taken away from you by anything the enemy
does.** The only thing in the game that can dislodge one is a siege-surge.

That makes stone and soldiers asymmetric investments, and the asymmetry has to be
paid for in the numbers:

| | A lane upgrade | A stone upgrade |
| --- | --- | --- |
| Applies to | every wave unit you spawn into that lane, forever | that lane's towers and all three base towers, forever |
| Takes effect | on the next wave | immediately |
| Enemy can reduce its value by | killing your waves faster than you make them | **nothing** |
| Can be lost to | a siege-surge | a siege-surge |
| Pushes a frontline | yes | no — it only holds one |

Read that table as a design instruction rather than a description. Stone must be
**worse at pushing** than soldiers are, by enough to be obvious, or the
unlosability makes it the default and nobody puts an upgrade in a lane. The
balance validator should report the two side by side, and issue 804 should be
watching the ratio of stone placements to lane placements as a headline number:
if it drifts hard toward stone, this rule is why.

## What this does to a last stand

A team that invested in stone and then lost all six lane towers still has three
fully upgraded base towers. Its investment did not evaporate with the buildings.

That is **not** a comeback mechanic — it does not reward being behind, and a team
that never invested in stone gets nothing. But it does mean an investment made
while winning is still working while losing, which is the difference between
defending a base and merely being present while it falls.

Related: [the shared upgrade pool](009-the-shared-upgrade-pool.md) ·
[guard towers](007-guard-towers-and-their-guards.md) ·
[the base and the library](008-the-base-and-the-library.md)

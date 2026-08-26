# 408 — Slotting Upgrades Into Stone

| | |
| --- | --- |
| Phase | 4 — The Shared Chest |
| Blocked by | 301, 302, 306, 401, 404 |
| Blocks | 409, 410 |
| Reads | [upgrades slotted into stone](../docs/010-upgrades-slotted-into-stone.md) |
| Open questions | none |

## Current behavior

Upgrades go into lanes and affect soldiers. Towers are unaffected by anything a
player does.

## Intended behavior

An upgrade placed at a lane sits in one of **two** slots, and the player chooses
which:

| Slot | Who receives it |
| --- | --- |
| the lane | Every wave unit this team spawns into that lane from now on. |
| the lane's stone | Both guard towers on that lane — and, per issue 409, all three base towers. |

An instance is in one slot or the other, never both. That is a real trade:
soldiers that walk forward and die, or stone that stays put and does not. A team
with an early lead wants the former; a team that has lost its outer towers wants
the latter.

Upgrades are slotted into a **lane's stone as a whole**, not into a specific
tower. This is the ruling that decides what happens when a tower falls: a single
tower falling changes nothing, because the upgrade was never in that tower. It
was in that lane's stone, and the lane still has stone — and even when it does
not, the base towers inherit it.

**Every kind can go into stone and nothing is refused for being the wrong kind.**
*See F28.* The slot has two recipients — the guards, who walk and swing, and the
tower, which stands and shoots — and an upgrade reaches whichever of them has the
stats it touches. A movement upgrade here does nothing for the tower and makes
its patrol faster, which is a real purchase rather than a mistake.

A tower reads its counts **live**, unlike a soldier. Its **guards** each carry
their own copy, cleared and re-stamped whenever the slot changes (F23), so
nothing in the swing path follows a reference to a tower.

A tower upgrade therefore takes effect **immediately** while a lane upgrade takes
effect on the **next wave**. That asymmetry is deliberate and it is the reason a
player under pressure reaches for the stone: stone is the fast option, soldiers
are the slow one.

## Suggested implementation steps

1. Extend the placement handler to accept `slot_kind = 2`. There is no kind
   validation to do — see F28.
2. Extend `rebuild_masks` to fill `tower_mask[lane]`.
3. Wire tower damage and range to read `tower_mask[lane]` live in the tower
   attack pass.
4. Write a test: place a damage upgrade into a lane's stone and assert both of
   that lane's towers hit harder on the very next tick — not the next wave.
5. Write a test: fell one of a lane's towers and assert the other's upgrades are
   unchanged.

## Related documents and tools

- [Upgrades slotted into stone](../docs/010-upgrades-slotted-into-stone.md)
- [Guard towers and their guards](../docs/007-guard-towers-and-their-guards.md)

## Settled

**Stone upgrades survive the destruction of the stone.** An upgrade is slotted
into a lane's stone as a whole, so a felled tower loses nothing, and when both of
a lane's towers are gone it keeps working through the base towers.

Implementation consequence: **`tower_mask[lane]` is never cleared by a tower
dying.** There is no code path from the tower-felled handler into the mask
rebuild at all. If one appears, it is a bug.

Balance consequence, for the validator rather than the code: the two slots are
not symmetric investments and the numbers have to say so. The comparison table is
in [upgrades slotted into stone](../docs/010-upgrades-slotted-into-stone.md).

## Still open

Nothing. The one question that used to live here — whether slotting into stone
counted as placing into that lane — went away with the no-repeat-lane rule.

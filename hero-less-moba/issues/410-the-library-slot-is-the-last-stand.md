# 410 — The Library Slot Is the Last Stand

| | |
| --- | --- |
| Phase | 4 — The Shared Chest |
| Blocked by | 305, 402, 408, 409 |
| Blocks | 703 |
| Reads | [upgrades slotted into stone](../docs/010-upgrades-slotted-into-stone.md), [the base and the library](../docs/008-the-base-and-the-library.md) |
| Open questions | none |

## Current behavior

Upgrades cannot go into a base tower directly; they go into the library, which
applies to all three at once. Dropping one on a base tower is refused **by name**,
because a player who tries it is reaching for a real rule and deserves to be told
which one.

## Intended behavior

An upgrade can be slotted into the **library**, which applies it to the three base
guard towers and nothing else.

Base guard towers still cannot be slotted directly. The library is the only door
into them, and it is a narrow one.

The vision calls this rare and says it usually only comes up once all the lane
towers are already destroyed. That is exactly the shape it should have: **the
library slot is where a losing team puts its upgrades**, because the lanes it
would rather be strengthening have no stone left standing to hold them.

And it costs something real. Every upgrade committed to the library is an upgrade
not making the team's soldiers stronger — at the precise moment when soldiers are
the only thing that can push a frontline back out of a base. A last stand should
feel like a decision to stop trying to win the map and start trying to survive
the room, and this is the mechanism that makes it one.

There is no cap on library slots, any more than there is on lane placements. A
last stand is allowed to be total.

## Suggested implementation steps

1. Extend the placement handler to accept `slot_kind = 3`, with `slot_lane = 0`.
2. No kind validation — the library slot takes anything, like every other slot.
   See F28.
3. `library_mask` is already folded into `base_tower_mask` by issue 409; confirm
   the ordering in `rebuild_masks` so a library placement takes effect on the
   same tick.
4. Give the library a visible slot in the viewer, near the base, so a player
   under siege can find it without hunting.
5. Write a test: slot into the library, assert all three base towers gain it and
   no lane tower does.

## Related documents and tools

- [Upgrades slotted into stone](../docs/010-upgrades-slotted-into-stone.md)
- [The base and the library](../docs/008-the-base-and-the-library.md)


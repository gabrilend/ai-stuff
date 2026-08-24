# 409 — The Base Inherits Every Lane

| | |
| --- | --- |
| Phase | 4 — The Shared Chest |
| Blocked by | 302, 305, 408 |
| Blocks | 410 |
| Reads | [upgrades slotted into stone](../docs/010-upgrades-slotted-into-stone.md) |
| Open questions | none |

## Current behavior

Upgrades slotted into a lane's stone affect that lane's two towers and nothing
else. The three towers inside a base are permanently unmodified, and a team that
has invested heavily in stone gets nothing for it once the fighting reaches the
base.

## Intended behavior

> **An upgrade slotted into *any* lane's stone also applies to *all three* of your
> base guard towers.**

So a base tower fires with the union of:

- upgrades slotted into the top lane's stone, plus
- upgrades slotted into the center lane's stone, plus
- upgrades slotted into the bottom lane's stone, plus
- upgrades slotted directly into the library (issue 410).

The vision's own worked example: your left flank has collapsed and the enemy is
inside your base, but all your tower upgrades are in the center and right lanes.
Those upgrades are firing out of the base tower covering the left. **Your
investment in two healthy lanes is what is holding the third one's doorway.**

Two things follow, and both should be said to players plainly:

1. **Tower upgrades are never wasted.** An upgrade in a lane whose towers have
   already fallen is still working, because the base towers still exist. This is
   the opposite of how tower investment usually behaves in a lane-pusher, where
   losing the tower loses the investment.
2. **The base is strongest when the match is going well.** That is backwards from
   a comeback mechanic and entirely on purpose. A team being ground down does not
   get a fortress handed to them; what they get is the library slot, which costs
   them something.

Implementation is one cached integer: `base_tower_mask`, the union of the three
`tower_mask` entries and `library_mask`, recomputed in `rebuild_masks` and read
live by the three base towers.

## Suggested implementation steps

1. Add `base_tower_mask` to the team record and compute it in `rebuild_masks`.
2. Make base towers read it instead of `tower_mask[lane]`.
3. Put it in the snapshot, and give the viewer somewhere to show it — a player
   needs to be able to see what their base is carrying, or this rule is invisible
   and might as well not exist.
4. Write a test: slot an upgrade into the top lane's stone, assert all three base
   towers gain it, and assert the center and bottom **lane** towers do not.
5. Write a test: fell both of the top lane's towers, assert the base towers still
   carry the top lane's stone upgrades.

## Related documents and tools

- [Upgrades slotted into stone](../docs/010-upgrades-slotted-into-stone.md)
- [The base and the library](../docs/008-the-base-and-the-library.md)

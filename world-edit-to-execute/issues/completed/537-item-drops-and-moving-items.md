# Issue 537: Item Drops and Moving Items

**Phase:** 7 (gameplay)
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 532 (items)

---

## Current Behavior

- **Drop tables:** a map's drop tables never drop anything. The World Editor compiles them into the script: death and change-of-owner triggers on each unit that has one, using RandomDist*, and these triggers do run. But GetChangingUnit answers with the dying unit during a death, so the generated test takes the kill for a change of owner and drops nothing (DAoW: 0 items from its drop tables).
- **Random items:** ChooseRandomItem / ChooseRandomItemEx always return -1.
- **Death:** a carrier's items stay with its corpse.
- **Moving items:** an item can't be moved between slots, handed to another unit or dropped at a chosen point from the HUD. UnitDropItemTarget gives it at any distance.

## Intended Behavior

- **Drop tables:** a map's drop tables drop their items on death, a little way from the unit (as Blizzard.j scatters them). GetChangingUnit is null except in a change of owner.
- **Random items:** ChooseRandomItem(level) and ChooseRandomItemEx(type, level) pick among the items of that level (and class) that may be random choices (iprn), stock and the map's.
- **Death:** a unit's items fall where it dies. A hero keeps its own, except those dropped when the carrier dies (idrp).
- **Moving items:**
  - to another slot, swapping with what's there;
  - to one's own or an ally's unit that has room, walking to it first;
  - to a point on the ground, walking there first;
  - another order stops the walk and the unit keeps the item.
- **HUD:** right-click an item in the inventory to put it on the cursor (framed in gold). Then click a slot, a unit or the ground. A left click still uses it.
- **Natives:** UnitDropItemSlot and UnitDropItemTarget go through the same moves.

## Suggested Implementation Steps

1. `natives/core.lua`: GetChangingUnit only in CHANGE_OWNER.
2. `object_stock`: `S:ids()`; `items.lua`: `random_item`, `move_item`, `hand_item`, `drop_item_at`, the death listener, the handing step.
3. Natives: ChooseRandomItem(Ex), UnitDropItem / WidgetDropItem scatter, UnitDropItemSlot / Target.
4. HUD. Tests.

## Acceptance Criteria

- [x] DAoW: killing the unit with ItemTable WA's trigger drops its I001 beside it
- [x] Random items by level and class, never one that isn't a random choice; -1 when there's none
- [x] Slots swap; handing walks, then gives; not to enemies, units without inventories, full inventories; undroppable items stay; dropping at a point walks there
- [x] Carriers' items fall on death; heroes keep theirs but idrp items
- [x] HUD: right click to carry, then a slot, a unit or the ground
- [x] Tests: test_item_drops (30), test_wc3_interface (76), test_items still pass

## Notes

- **Maps without a script** (never the case for .w3x) would need the drop tables from war3mapUnits.doo, which `parsers/unitsdoo.lua` already reads. Units placed from the doo aren't used for drops yet.
- **Field codes from memory:** idrp (dropped when the carrier dies) and iprn (a random choice).

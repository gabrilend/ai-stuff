# Issue 532: Items and Inventories

**Phase:** 7 (gameplay)
**Type:** Implementation
**Priority:** High
**Dependencies:** 529 (abilities, buffs), 528 (heroes), 527 (object tables)

---

## Current Behavior

Items are records in the script VM only: CreateItem makes one, and
UnitAddItem puts it in one of six slots on any unit. Items do nothing:

- **No types:** nothing is read from the item tables.
- **Nothing on the ground:** no items are drawn, and none can be picked up.
- **No effects:** no bonuses and no use; UnitUseItem is false.
- **No events.**
- **HUD:** the inventory's slots are drawn empty.

## Intended Behavior

Items as in WC3:

- **Types:** from the item tables (the map's over the stock).
- **On the ground:** items lie there (drawn with their model), and units with an inventory pick them up by walking to them.
- **Carried items** give their abilities' bonuses.
- **Orders:** drop, give, use (charges, cooldowns, perishing); powerups are used on pickup, tomes giving attributes for good.
- **Spells:** usable items cast their spell through the ability system.
- **The script:** its item natives and PICKUP / DROP / USE events work.
- **HUD:** shows and uses the inventory.

## Suggested Implementation Steps

1. `demo/wc3map/items.lua`: types, ground items, inventories, bonuses, orders, use.
2. Bonuses into heroes (attributes, hit points, mana), buffs (speed, armour, regeneration), strikes (damage), abilities (item abilities cast like the unit's own).
3. The script's item natives through the game; events.
4. HUD inventory, pickup by right-click; ground items drawn.
5. Tests.

## Acceptance Criteria

- [x] Item types: name, class, level, charges, usable, perishable, powerup, droppable, pawnable, cost, model, stock fields, abilities (iabi)
- [x] Ground items; pick up by walking to them (items.REACH); inventory size from AInv (six for heroes, none for units without it); full inventories refuse
- [x] Carried items' ability data give strength, agility, intelligence, damage, armour, hit points, mana, regeneration, move and attack speed, and take them back when dropped
- [x] Drop (not undroppable ones), give, remove; PICKUP_ITEM, DROP_ITEM, USE_ITEM with GetManipulatingUnit / GetManipulatedItem
- [x] Use: a spell the game knows is cast (targets as the spell needs); else instant restores (Ihpg, Impg) with the ability's cooldown; charges spent; perishable items go at none; powerups used on pickup, their attributes (and Ixpg experience) a hero's for good
- [x] Natives through the game: CreateItem(Loc), RemoveItem, UnitAddItem(ById/ToSlotById), UnitItemInSlot, UnitRemoveItem(FromSlot), UnitHasItem, UnitInventorySize, UnitDropItemPoint/Slot/Target, UnitUseItem(Point/Target), item fields and flags, EnumItemsInRect, and the Blizzard.j helpers on the same inventory
- [x] HUD: items in the inventory's slots with charges, the unit's slot count, click to use (aiming when it needs a target); right-clicking an item on the ground fetches it; ground items drawn with their model (a gold ring where not found)
- [x] `test_items.lua`: 37 tests; related suites pass

## Implementation Notes

**Date:** 2026-09-30

- **`demo/wc3map/items.lua`:**
  - Types are cached from `g.data.items` (the map's changes over ItemData.slk and the item profiles).
  - An item is a table: id, place or owner and slot, charges, flags.
  - `u.inventory[0..5]` replaces the VM's old `u.items`.
  - `g.refresh_items(u)` sums its carried items' ability data into `u.item_stats` and lists their abilities in `u.item_abilities`. Heroes then refresh (attributes, hit points, mana); other units take the hit point and mana difference; buffs re-sum (speed, armour, regeneration).
  - The item ability data codes are FROM MEMORY: Istr, Iagi, Iint, Iatt, Idef, Ilif, Iman, Ihpr, Imrp, Imvb, Isx1, Ihpg, Impg, Ixpg.
- **Around it:**
  - `heroes.refresh` adds items' attributes, hit points and mana.
  - `buffs.sum` adds items' speed, armour and regeneration.
  - `g.modify_strike` adds items' damage.
  - The ability system casts item abilities (`g.ability_level` looks at `u.item_abilities` too), which aren't buttons of their own.
  - Other orders stop a unit fetching an item.
- **Natives:**
  - The item section of `world.lua` goes through the game when it has items (`W.create_item`), else keeps plain records.
  - Blizzard.j's own EnumItemsInRect and GetItemType (which read the VM's old list) are gone.
  - Its inventory helpers (GetItemOfTypeFromUnitBJ ...) read `u.inventory`; ReplaceUnitBJ moves the inventory to the new unit.

### Not yet

- **Item classes' rules** (charged items stacking, campaign / artifact classes).
- **Selling and pawning** (shops, issue 533).
- **Drops:** units' item drop tables on death (the map's item sets), and dropping items on a hero's death (kept, as WC3 does by default).
- **Moving items:** dragging items between slots and to other units in the HUD.
- **Item art** on the hero (attached weapons); the item's icon in the slot (a coloured square and its name stand in).
- **ChooseRandomItem(Ex)** (random items by level).

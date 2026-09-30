# Issue 534: Wisps and Picking Up Items

**Phase:** 7 (gameplay)
**Type:** Fix
**Priority:** High
**Dependencies:** 531 (construction), 532 (items)

---

## Current Behavior

- **Wisps:** a night elf wisp is used up by every building it starts, a moon well as much as an Ancient.
- **Items:** a right click anywhere within 100 units of an item on the ground sends the first selected unit that can carry it. That includes clicks on the minimap and clicks that only land near the item.

## Intended Behavior

- **Wisps:** only a living building takes its wisp in for good. That means an Ancient, as the building's spirit: classed "ancient" (utyp), or able to uproot (Aro1 / Aro2), or one of the stock Ancients by id when the tables don't say. For the rest (moon wells, hunter's halls, altars) the wisp starts the building and is free, and the building grows alone.
- **Items:** an item is picked up only when the player right-clicks the item's treasure icon on the map while a unit with an inventory is selected. The first such unit in the selection fetches it. Units never pick items up by walking over them, a click beside the item is a move, and the minimap never picks.

## Suggested Implementation Steps

1. `construction.lua`: `construction.living(g, id)`; night elves build the undead way unless the building is living.
2. `hud.lua`: `Hud:pick_item` (screen distance to the item, only where the player sees it: `g.shown_at`). The right-click uses it and asks `inventory_size`.
3. Tests.

## Acceptance Criteria

- [x] A wisp is consumed by an Ancient and freed by any other building, which then rises alone
- [x] Right-clicking an item's icon with a unit that has an inventory fetches it; a click beside it, or with only units without inventories, is a move
- [x] Items in fog aren't picked
- [x] Tests: test_construction (35), test_wc3_interface (71)

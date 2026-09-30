# Issue 535: Repair, Helping a Building Up, and Building Upgrades

**Phase:** 7 (gameplay)
**Type:** Implementation
**Priority:** High
**Dependencies:** 531 (construction), 527 (economy)

---

## Current Behavior

- **Repair:** the Repair button only says "not simulated".
- **Helping:** one worker builds each structure; no one can help.
- **Upgrades:** buildings don't upgrade (Town Hall to Keep, towers). There is no way to change a unit's type in place.

## Intended Behavior

- **Repair:** workers that repair (the Ahrp / Arep / Aren abilities, else human and orc workers and wisps) mend their own or an ally's damaged building or machine (classed "mechanical").
  - **Rate and cost:** the whole of its hit points over RepairTimeRatio (1.5) times its build time, at RepairCostRatio (0.35) of its cost, paid as it goes.
  - **Stopping:** repairers stack. They stop when the purse is empty, when it's whole, or on another order.
- **Helping:** more human workers can help a human building up. Each helper adds the repair rate and is paid as repair; the builder works at the full rate. Helpers keep it rising after the builder leaves.
- **Upgrades:** a building upgrades to a type in its uupt list.
  - **Starting:** the new type's cost, build time and requirements apply; it can't be training.
  - **Meanwhile:** no training, and the command card shows only Cancel. Cancelling refunds everything.
  - **When done:** the same unit becomes the new type (`g.morph`), its hit points and mana in proportion.
  - **The script:** UPGRADE_START / _CANCEL / _FINISH.
- **Orders:** worker right-click on one's own damaged building or machine, or on one going up, repairs or helps. The card offers "Upgrade to …". For the script: IssueTargetOrder "repair", IssueImmediateOrderById with a unit type (upgrade, else train), and "cancel".

## Suggested Implementation Steps

1. `game.lua`: `g.morph(u, id)` and `g.morph_listeners`; abilities re-read on morph.
2. `construction.lua`: `can_repair`, `repair`, `step_repair`, helpers in the building step; `upgrades`, `can_upgrade`, `upgrade`, `cancel_upgrade`, the upgrade step.
3. Constants RepairCostRatio / RepairTimeRatio; `names.UPGRADES` for the stock halls and towers.
4. Natives, HUD and card, animation (Stand Work Upgrade).
5. Tests.

## Acceptance Criteria

- [x] Who can repair what; rate and cost from the constants; stacking; stopping on an empty purse, when whole, or on another order
- [x] Helpers speed a human building at the repair rate and pay as repair; orcs can't help; helpers alone keep it rising
- [x] Upgrades: cost, time, no training, card shows only Cancel, full refund on cancel, the new type in proportion, events
- [x] Script orders: repair, upgrade by type id, cancel; OrderId("repair")
- [x] Tests: test_repair (42); test_construction, test_wc3_interface, test_anim still pass

## Notes

- **From memory, to check against the install:** RepairCostRatio 0.35 and RepairTimeRatio 1.5 (MiscGame can override them), the repair ability ids, the order ids for repair and cancel, and the stock upgrade lists.
- **Workers' animation** while repairing isn't chosen yet.
- **The upgrade** takes the whole of the new type's listed cost, as the stock data lists upgrade prices.

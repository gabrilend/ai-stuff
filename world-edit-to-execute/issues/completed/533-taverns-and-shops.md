# Issue 533: Taverns and Shops

**Phase:** 7 (gameplay)
**Type:** Implementation
**Priority:** High
**Dependencies:** 532 (items), 528 (heroes: limits, tokens), 527 (economy)

---

## Current Behavior

Nothing sells:

- **Buildings:** taverns, mercenary camps and shops are buildings like any other; their sold units and items (useu, usei) aren't read.
- **The script:** its stock natives (AddUnitToStock, AddItemToStock, the "all stock" forms, the removes) are no-ops, and SELL / SELL_ITEM / PAWN_ITEM never fire.
- **Selling back:** there's no pawning.

## Intended Behavior

Buildings sell, as in WC3:

- **Stock:** their units and items, each with a count that starts after a delay, has a maximum and comes back one at a time.
- **Buying:** a player buys with one of its units near the shop. Units appear as the buyer's; items go into the buyer's inventory. Costs, food, hero limits and hero tokens count.
- **Who may buy:** neutral shops sell to everyone; a player's shops to it and its allies.
- **Pawning:** items can be sold back.
- **The script:** its stock natives and events work.
- **HUD:** the command card lists what a shop sells, with stock.

## Suggested Implementation Steps

1. `demo/wc3map/shops.lua`: stock, buyers, buying, pawning, replenishing.
2. Natives and events; the card; the HUD for shops the player doesn't own.
3. Tests.

## Acceptance Criteria

- [x] Stock from useu (units) and usei (items) and the script's additions; per type count, maximum, replenish interval and start delay (units usma / usrg / usst; items isto / istr / isst; stand-ins 1 / 30 s / 0)
- [x] Buying needs a unit of the buyer within 600 of the shop (with an inventory for items); gold, lumber, food; hero limit, type limit; a hero token hires a hero for nothing
- [x] Units appear beside the shop as the buyer's ("trained" score); items go into the buyer's inventory, or beside it when full; stock falls and comes back one per interval
- [x] Neutral shops sell to all, players' shops to themselves and allies
- [x] Pawning: a pawnable item for PawnItemRate (0.5) of its cost, by charges left
- [x] Events: EVENT_PLAYER_UNIT_SELL (GetSoldUnit, GetBuyingUnit), SELL_ITEM (GetSoldItem), PAWN_ITEM, for the shop's owner (the pawning unit's owner for pawning)
- [x] Natives: Add/Remove Unit/Item To/From Stock, the "All Stock" forms, the BJ forms
- [x] Command card: "Hire …" / "Buy …" with stock counts (sold out darkened); the HUD shows a shop's card to any player it sells to; pressing buys
- [x] `test_shops.lua`: 30 tests; full suite passes

## Implementation Notes

**Date:** 2026-09-30

- **`demo/wc3map/shops.lua`:**
  - `g.stock(shop)` builds and caches a building's (or a neutral unit's) stock from its lists: the map's, else the stock tables' (issue 528's list fallback).
  - `g.add_stock` / `g.remove_stock` for the script.
  - `g.buyer_for` finds the player's nearest unit in range (with an inventory for items).
  - `g.buy(shop, player, id)`: the checks and payment, then:
    - units spawn beside the shop, facing the buyer, as the buyer's, with the made listener ("trained");
    - items go to the buyer's inventory (`g.give_item`), else the ground.
  - `g.pawn(unit, item[, shop])`: finds the nearest item shop in range if none is given, and pays PawnItemRate × cost × (charges left / charges).
  - `shops.update` replenishes every half second.
- **Natives:**
  - The stock natives go through the game.
  - The "all stock" forms reach every building that already sells that kind.
  - The stock and item-flag natives (SetItemDroppable, SetItemPawnable, SetItemInvulnerable) were still in a no-op list defined after them, which overrode them (issue 532's flags too); taken out.
- **Command card and HUD:**
  - The card lists a shop's stock before anything else.
  - `Hud:card` shows the card of a shop the player doesn't own when it sells to that player.
  - "buy" buys with the local player.

### Not yet

- **The buyer's pick:** WC3 lets a player pick which hero buys when several are near; here the nearest does.
- **Selling units back.**
- **Shop rules:** marketplaces' random stock by level, goblin merchants' per-hero rules.
- **Stock slots per shop** (SetItemTypeSlots, SetUnitTypeSlots) are kept as no-ops.
- **Computer players** don't buy.

### Follow-up (2026-09-30)

The shop listing in `commands.lua` named its list `stock`, shadowing the card's `stock()` helper: every non-shop unit's card failed (test_abilities, test_wc3_interface). Renamed to `sold`. The full suite passes: 122 files.

# Issue 539: Choosing Which Unit Buys at a Shop

**Phase:** 7 (gameplay)
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 533 (shops)

---

## Current Behavior

A shop sells to the buying player's unit nearest it within 600: its nearest hero or carrier for items, its nearest unit for units. The player can't choose which of its units in range buys.

## Intended Behavior

As WC3's Select Hero / Select Unit at shops: each player may have a chosen buyer (patron) at a shop.

- **Choosing a buyer:**
  - the shop's "Buyer: …" button (U) cycles through the player's units in range, nearest first (only carriers when the shop sells items);
  - selecting the shop straight after one of your units makes that unit the buyer;
  - right-clicking a shop with units selected sends them there, and the one that arrives becomes the buyer.
- **Who buys:** the chosen buyer, while it's alive, in range and able (an inventory for items). Otherwise the nearest able unit, as before.

## Suggested Implementation Steps

1. `shops.lua`: `shop_candidates`, `set_patron`, `patron`, `next_patron`, `visit_shop`; `buyer_for` asks the patron first; arrivals in `shops.update`; `db.shop_buyer`.
2. `commands.lua`: the buyer button on a shop's card. `hud.lua`: the button, selecting a shop after a unit, right-clicking a shop.
3. Tests.

## Acceptance Criteria

- [x] Nearest able unit by default; a chosen buyer buys into its own inventory
- [x] The button cycles through candidates; out of range falls back to the nearest; can't choose one out of range
- [x] A unit sent to the shop becomes its buyer on arrival
- [x] The card names the buyer; selecting the shop after a unit chooses it
- [x] Tests: test_shops (44); test_wc3_interface, test_items, test_item_drops still pass

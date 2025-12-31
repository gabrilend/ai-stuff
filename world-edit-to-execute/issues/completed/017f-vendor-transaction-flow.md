# Issue 017f: Vendor Transaction Flow

**Phase:** 0
**Type:** Implementation
**Priority:** High
**Parent:** 017-unified-currency-system.md
**Status:** Completed

---

## Current Behavior

Shop.lua uses a simple `hero.gold` abstraction for transactions. No integration with the new money_bag coin system.

## Intended Behavior

Bridge module that connects Shop transactions to the money_bag system:
- Buy items: deduct copper/silver/gold from money_bag
- Sell items: add coins to money_bag
- Support reputation-based discounts
- Support mode switching (WoW/WC3/hybrid)

## Suggested Implementation Steps

1. [x] Create `src/runtime/currency/vendor.lua`
2. [x] Implement mode switching (WOW/WC3/HYBRID)
3. [x] Implement get_entity_money_bag() helper
4. [x] Implement get_faction_discount() for rep-based discounts
5. [x] Implement get_buy_price() with copper conversion
6. [x] Implement get_sell_price() with sell modifier
7. [x] Implement can_afford() and spend_copper()
8. [x] Implement buy_item() with full transaction flow
9. [x] Implement sell_item() with coin return
10. [x] Implement preview functions
11. [x] Add comprehensive tests

## Acceptance Criteria

- [x] Buy transactions deduct correct copper amount
- [x] Sell transactions add correct copper amount
- [x] Reputation discounts apply correctly
- [x] Soulbound/quest items cannot be sold
- [x] Mode switching works between WoW and WC3
- [x] All tests pass

## Implementation Notes

Created `src/runtime/currency/vendor.lua` with:

- **Mode system**: WOW (money_bag), WC3 (resources.lua), HYBRID
- **Buy flow**: get_buy_price() → can_afford() → spend_copper() → update stock
- **Sell flow**: get_sell_price() → add_copper() → return receipt
- **Preview functions**: preview_buy(), preview_sell() for UI display
- **Reputation integration**: get_faction_discount() applies standing discounts
- **Price conversion**: Shop prices in gold units → copper for money_bag

Added 10 tests to test_currency.lua covering vendor operations with mock ECS.

## Related Files

- `src/runtime/currency/vendor.lua` - Main implementation
- `src/runtime/currency/money_bag.lua` - Coin operations
- `src/runtime/currency/reputation.lua` - Faction discounts
- `src/guild/shop.lua` - Original shop system (not modified)
- `src/tests/test_currency.lua` - Test suite

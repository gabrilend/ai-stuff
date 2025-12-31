# Issue 017g: WC3-WoW Conversion

**Phase:** 0
**Type:** Implementation
**Priority:** High
**Parent:** 017-unified-currency-system.md
**Status:** Completed

---

## Current Behavior

No mechanism exists to convert between WC3 player resources and WoW character currencies.

## Intended Behavior

Conversion module that enables cross-play between WC3 and WoW economies:
- Convert WC3 gold to WoW copper at 1:100 rate
- Convert WoW copper to WC3 gold (fractional remainder stays as copper)
- Preview functions for UI display
- Validation and error handling

## Suggested Implementation Steps

1. [x] Create `src/runtime/currency/conversion.lua`
2. [x] Define conversion rate constants
3. [x] Implement wc3_to_wow() conversion
4. [x] Implement wow_to_wc3() conversion with remainder handling
5. [x] Implement get_exchange_rate() for rate lookups
6. [x] Implement preview functions
7. [x] Implement can_convert validation functions
8. [x] Add tests

## Acceptance Criteria

- [x] 1 WC3 gold converts to exactly 100 WoW copper
- [x] WoW copper converts to WC3 gold with floor division
- [x] Fractional copper remains in money_bag
- [x] Validation prevents insufficient funds errors
- [x] All tests pass

## Implementation Notes

Created `src/runtime/currency/conversion.lua` with:

- **Constants**: WC3_GOLD_TO_COPPER = 100, MIN_WC3_GOLD = 1, MIN_COPPER = 100
- **wc3_to_wow()**: Deducts WC3 gold, adds copper to money_bag
- **wow_to_wc3()**: Deducts copper (only full conversions), adds WC3 gold
- **Remainder handling**: Only copper that converts to full WC3 gold is deducted
- **Exchange rates**: get_exchange_rate() returns rates for all currency pairs
- **Preview functions**: preview_wc3_to_wow(), preview_wow_to_wc3() for UI
- **Validation**: can_convert_wc3_to_wow(), can_convert_wow_to_wc3()

Added 5 tests to test_currency.lua covering conversion calculations.

## Related Files

- `src/runtime/currency/conversion.lua` - Main implementation
- `src/runtime/currency/money_bag.lua` - WoW coin operations
- `src/runtime/resources.lua` - WC3 resource operations
- `src/tests/test_currency.lua` - Test suite

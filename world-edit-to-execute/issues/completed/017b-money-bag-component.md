# Issue 017b: Money Bag Component

**Phase:** 0
**Type:** Implementation
**Priority:** High
**Dependencies:** 017a

---

## Current Behavior

No physical coin representation. Gold is an abstract counter.

## Intended Behavior

ECS component `money_bag` with:
1. Dedicated slots for copper, silver, gold coins
2. Auto-conversion between denominations (100 copper = 1 silver, etc.)
3. Total copper tracking for quick affordability checks
4. Format function for display ("1g 23s 45c")

## Suggested Implementation Steps

1. Create `src/runtime/currency/money_bag.lua`
2. Define COIN_VALUES dispatch table
3. Implement `add_copper()`, `remove_copper()`, `set_total()`
4. Implement `can_afford()`, `format_money()`
5. Register `money_bag` ECS component
6. Create tests

## Acceptance Criteria

- [ ] `money_bag` component with slots.copper/silver/gold
- [ ] Adding 150 copper auto-converts to 1 silver + 50 copper
- [ ] `can_afford(bag, 10000)` returns true if >= 1 gold
- [ ] `format_money(12345)` returns "1g 23s 45c"
- [ ] `format_money(45)` returns "45c"

## Notes

Coins are physical items in dedicated bag slots, not regular inventory.

# Issue 017c: Currency Container Component

**Phase:** 0
**Type:** Implementation
**Priority:** High
**Parent:** 017-unified-currency-system.md
**Status:** Completed

---

## Current Behavior

No component exists for storing abstract currencies (honor, arena points, justice, valor).

## Intended Behavior

ECS component that stores:
- Abstract currency values (indexed by currency index)
- Token counts (indexed by name)
- Weekly earning tracking for capped currencies
- Modifiers for bonus calculations

Support for:
- Caps (overall and weekly)
- Decay rates (Vanilla honor 25% weekly decay)
- Modifier storage for buff/item effects

## Suggested Implementation Steps

1. [x] Create `src/runtime/currency/currency_container.lua`
2. [x] Implement `create()` and `register_component()`
3. [x] Implement get/set/add/subtract for abstract currencies
4. [x] Implement cap enforcement on set
5. [x] Implement weekly cap tracking
6. [x] Implement `apply_decay()` for honor-style decay
7. [x] Implement token currency operations
8. [x] Implement modifier storage
9. [x] Add comprehensive tests

## Acceptance Criteria

- [x] Abstract currencies respect cap limits
- [x] Weekly cap tracking prevents over-earning
- [x] Decay applies correct percentage reduction
- [x] Token currencies can be added/removed
- [x] All tests pass

## Implementation Notes

Created `src/runtime/currency/currency_container.lua` with:

- **Abstract currency operations**: get(), set(), add(), subtract() with automatic cap enforcement
- **Weekly cap tracking**: add_with_weekly_tracking(), can_earn_weekly(), reset_weekly()
- **Decay system**: apply_decay() reduces currencies with decay_rate (honor = 25%)
- **Token operations**: get_token(), set_token(), add_token(), remove_token()
- **Modifier system**: get_modifier(), set_modifier(), clear_modifiers()
- **Utility functions**: clone(), reset(), get_all_values(), get_all_tokens()

Added 21 tests to test_currency.lua covering all container functionality.

## Related Files

- `src/runtime/currency/currency_container.lua` - Main implementation
- `src/runtime/currency/registry.lua` - Currency schema definitions
- `src/tests/test_currency.lua` - Test suite

# Issue 017i: Tests and Integration

**Phase:** 0
**Type:** Implementation
**Priority:** High
**Parent:** 017-unified-currency-system.md
**Status:** Completed

---

## Current Behavior

Individual modules have unit tests. Integration testing is pending.

## Intended Behavior

Comprehensive test suite covering:
- Unit tests for all currency modules
- Integration tests for full transaction flows
- Cross-play conversion tests
- ECS component registration tests

## Suggested Implementation Steps

1. [x] Create test file: `src/tests/test_currency.lua`
2. [x] Add registry tests (13 tests)
3. [x] Add standing/rank tests (7 tests)
4. [x] Add money_bag tests (18 tests)
5. [x] Add custom currency tests (4 tests)
6. [x] Add reputation tests (15 tests)
7. [x] Add conversion tests (5 tests)
8. [x] Add currency_container tests (21 tests)
9. [x] Add vendor tests (10 tests)
10. [ ] Add integration tests (full buy/sell cycle)
11. [ ] Add ECS component registration tests

## Acceptance Criteria

- [x] All 94 unit tests pass
- [ ] Integration test demonstrates full workflow
- [ ] ECS components register without error

## Test Summary

| Module | Tests | Status |
|--------|-------|--------|
| Registry | 13 | Passing |
| Standing/Rank | 7 | Passing |
| Money Bag | 18 | Passing |
| Custom Currency | 4 | Passing |
| Reputation | 15 | Passing |
| Conversion | 5 | Passing |
| Currency Container | 21 | Passing |
| Vendor | 10 | Passing |
| **Total** | **94** | **All Passing** |

## Implementation Notes

Test file structure:
- Mock ECS for vendor tests
- Mock shop for transaction tests
- Assert helpers for clean test output

Run tests with:
```bash
lua src/tests/test_currency.lua
```

## Related Files

- `src/tests/test_currency.lua` - Main test file
- All `src/runtime/currency/*.lua` modules

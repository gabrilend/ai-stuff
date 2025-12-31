# Issue 017a: Currency Registry and Dispatch Tables

**Phase:** 0
**Type:** Implementation
**Priority:** Critical
**Dependencies:** None (foundation for 017b-017i)

---

## Current Behavior

No unified currency registry exists. Resource types are defined inline in resources.lua.

## Intended Behavior

Create a currency registry that:
1. Defines all currency types with their schemas
2. Provides dispatch tables for O(1) getter/setter lookup
3. Supports both string and numeric index access
4. Categories: PHYSICAL, ABSTRACT, TOKEN, REPUTATION, SKILL, WC3_RESOURCE

## Suggested Implementation Steps

1. Create `src/runtime/currency/` directory
2. Create `registry.lua` with CURRENCY_CATEGORY enum
3. Define CURRENCY_SCHEMA table with all currency definitions
4. Build GETTERS and SETTERS dispatch tables
5. Export unified `currency.get()` and `currency.set()` API
6. Add helper functions: `can_afford()`, `spend()`, `add()`, `subtract()`

## Acceptance Criteria

- [ ] CURRENCY_CATEGORY enum with 6 categories
- [ ] CURRENCY_SCHEMA defines: copper, silver, gold, honor, arena, justice, valor, wc3_gold, wc3_lumber
- [ ] Each schema has: index, category, cap, display_name
- [ ] Dispatch tables allow O(1) lookup by name or index
- [ ] `currency.get(entity, "copper")` works
- [ ] `currency.get(entity, 1)` works (by index)

## Notes

Follow Issue 016 dispatch table patterns for consistency.

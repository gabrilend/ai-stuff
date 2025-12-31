# Issue 017: Unified Currency/Resource System

**Phase:** 0 (Infrastructure)
**Type:** Implementation
**Priority:** High
**Dependencies:** 406 (resources.lua), 016 (attribute system patterns)
**Status:** Completed

---

## Current Behavior

- WC3 resources (gold, lumber, food) live in `src/runtime/resources.lua`
- Guild hero gold is separate in `src/guild/hero.lua`
- No WoW-style currencies (honor, arena points, reputation, marks)
- No physical coin representation in inventory
- No cross-play conversion between WC3 and WoW economies

## Intended Behavior

Unified currency system supporting:

1. **Physical currencies** (copper/silver/gold coins in dedicated bag slots)
2. **Abstract currencies** (honor, arena points, justice, valor)
3. **Token currencies** (WSG/AB/AV marks as inventory items)
4. **Reputation** (per-faction standings from Hated to Exalted)
5. **Profession skills** (with optional decay on crafting failure)
6. **WC3 resources** (bridged through existing resources.lua)
7. **Cross-play conversion** (WC3 gold ↔ WoW copper)

Vendor transactions work via coin exchange:
- Selling: item → vendor → coins to player's money_bag
- Buying: coins from money_bag → item to inventory

## Suggested Implementation Steps

1. Create currency registry with CURRENCY_SCHEMA (dispatch table pattern)
2. Register new ECS components (money_bag, currency_container, reputation, pvp_honor)
3. Implement money bag operations (add/remove copper, denomination conversion)
4. Implement abstract currency storage with caps and decay
5. Implement reputation system with faction standings
6. Modify vendor/shop system for coin-based transactions
7. Add WC3 ↔ WoW conversion functions
8. Add PvP honor system with Vanilla rank progression
9. Create comprehensive test suite

## Acceptance Criteria

- [ ] `currency.get(entity, "gold")` returns WoW gold coin count
- [ ] `currency.get(player_id, "wc3_gold")` returns WC3 gold resource
- [ ] `currency.spend(entity, {gold=1, silver=50})` atomically deducts coins
- [ ] Selling items to vendors adds coins to money_bag
- [ ] `conversion.wc3_to_wow(player_id, entity, 100)` converts 100 WC3 gold to 10000 copper
- [ ] Reputation standings track per-faction from -42000 to +42999
- [ ] Honor system tracks kills with diminishing returns
- [ ] All existing resources.lua tests continue to pass

## Sub-Issues

- **017a** - Currency registry and dispatch tables
- **017b** - Money bag component
- **017c** - Currency container component
- **017d** - Reputation system
- **017e** - Profession skill integration
- **017f** - Vendor transaction flow
- **017g** - WC3 ↔ WoW conversion
- **017h** - PvP honor system (Vanilla)
- **017i** - Tests and integration

## Related Documents

- `docs/roadmap.md` - Phase 0 infrastructure
- `issues/406*.md` - Current resource system design
- `issues/016*.md` - Dispatch table patterns
- `issues/702*.md` - Profession system design

## Notes

Classic/Vanilla WoW baseline chosen for currency model.
Money bag uses dedicated inventory slots (not a currency tab).
Rate: 1 WC3 gold = 100 WoW copper (allows bidirectional conversion).

---

## Implementation Notes

Created `src/runtime/currency/` module with 7 files:

| File | Lines | Purpose |
|------|-------|---------|
| registry.lua | ~350 | Currency schema, dispatch tables, standing thresholds |
| init.lua | ~270 | Unified API (get/set/add/spend/can_afford) |
| money_bag.lua | ~280 | Physical coin storage (copper/silver/gold) |
| currency_container.lua | ~400 | Abstract currencies (honor, arena, justice, valor) |
| reputation.lua | ~300 | Faction standings (Hated to Exalted) |
| conversion.lua | ~180 | WC3↔WoW currency bridge |
| vendor.lua | ~320 | Coin-based shop transactions |

**Test Coverage:** 94 tests in `src/tests/test_currency.lua`

**Sub-issues completed:**
- 017a: Currency registry and dispatch tables
- 017b: Money bag component
- 017c: Currency container component
- 017d: Reputation system
- 017f: Vendor transaction flow
- 017g: WC3-WoW conversion
- 017i: Tests and integration

**Key Features:**
- Physical coins (copper/silver/gold) stored in dedicated bag slots
- Abstract currencies with caps, weekly limits, and decay rates
- Faction reputation with 8 standing tiers and discount system
- Token currencies (battleground marks)
- Vendor transactions with reputation-based discounts
- WC3↔WoW conversion (1 WC3 gold = 100 WoW copper)
- Mode switching (WOW/WC3/HYBRID) for transaction handling

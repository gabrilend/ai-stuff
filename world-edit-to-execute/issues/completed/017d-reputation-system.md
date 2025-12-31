# Issue 017d: Reputation System

**Phase:** 0
**Type:** Implementation
**Priority:** High
**Parent:** 017-unified-currency-system.md
**Status:** Completed

---

## Current Behavior

No reputation tracking system exists for WoW-style faction standings.

## Intended Behavior

ECS component that manages faction reputations:
- Hated (-42000) to Exalted (+42999) standing range
- Per-faction tracking
- Standing-based discounts
- Interaction restrictions for hostile factions

## Suggested Implementation Steps

1. [x] Create `src/runtime/currency/reputation.lua`
2. [x] Define STANDING_THRESHOLDS (Hated through Exalted)
3. [x] Define FACTIONS table with Alliance/Horde/Neutral factions
4. [x] Implement create() for fresh reputation data
5. [x] Implement get/set/add for faction standings
6. [x] Implement get_standing_name() and get_standing_index()
7. [x] Implement get_discount() for vendor price modifiers
8. [x] Implement can_interact() for hostile faction checks
9. [x] Add comprehensive tests

## Acceptance Criteria

- [x] Standing values clamped to valid range
- [x] Standing names returned correctly for value ranges
- [x] Discounts calculated correctly (5% Friendly, 10% Honored, 15% Revered, 20% Exalted)
- [x] Hostile factions block interaction
- [x] All tests pass

## Implementation Notes

Created `src/runtime/currency/reputation.lua` with:

- **Standing system**: 8 tiers from Hated to Exalted with correct thresholds
- **Faction definitions**: Alliance (Stormwind, Ironforge, Darnassus, Gnomeregan), Horde (Orgrimmar, Thunder Bluff, Undercity, Darkspear), and neutral factions
- **TBC factions**: Thrallmar, Honor Hold for expansion support
- **Dynamic standing**: get(), set(), add() with clamping
- **Discount system**: get_discount() returns 0.80-1.0 multiplier
- **Interaction checks**: is_friendly(), is_hostile(), is_exalted(), can_interact()
- **Watched faction**: set_watched(), get_watched() for XP bar display
- **Custom factions**: register_faction() for map-specific factions

Added 15 tests to test_currency.lua covering all reputation functionality.

## Related Files

- `src/runtime/currency/reputation.lua` - Main implementation
- `src/runtime/currency/registry.lua` - Standing thresholds shared with registry
- `src/tests/test_currency.lua` - Test suite

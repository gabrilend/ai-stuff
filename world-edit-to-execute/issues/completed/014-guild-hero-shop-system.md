# Issue 014: Guild Hero & Shop System

## Current Behavior

The quest/bounty template system exists but has no gameplay layer. Bug tracking documentation is gamified but there's no actual progression mechanics.

## Intended Behavior

A complete hero/shop/inventory system that:
- Tracks adventurer progress via Hero units
- Manages items and equipment in a 6-slot inventory
- Provides shops for purchasing gear and consumables
- Connects quest completion to XP, gold, and capability rewards
- Persists hero state to JSON files

## Implementation Steps

- [x] Create Hero class with stats, level, XP, inventory
- [x] Implement WC3-style inventory (6 slots)
- [x] Implement equipment system (weapon, armor, accessory)
- [x] Create Item class with types (equipment, consumable, material, tome)
- [x] Implement rarity system (common to legendary)
- [x] Create ItemRegistry for item definitions
- [x] Create Shop class with stock, pricing, discounts
- [x] Create ShopRegistry with predefined shops
- [x] Implement buy/sell transactions
- [x] Create guild init module with persistence
- [x] Build CLI for hero management (guild-cli.lua)
- [x] Test quest completion workflow
- [x] Test shop purchase workflow
- [x] Test item use workflow

## Related Documents

- `src/guild/hero.lua` - Hero class with stats, inventory, equipment
- `src/guild/items.lua` - Item system with registry and predefined items
- `src/guild/shop.lua` - Shop system with transactions
- `src/guild/init.lua` - Module exports and persistence
- `src/cli/guild-cli.lua` - Command-line interface
- `issues/Q00-adventurer-quest-log.md` - Quest definitions
- `issues/B01-B03` - Bounty definitions

## Acceptance Criteria

- [x] Hero can be created, saved, and loaded
- [x] Hero gains XP and gold from quests
- [x] Hero can buy items from shops
- [x] Hero can equip and use items
- [x] Capabilities unlock from quest completion
- [x] All operations persist to disk

## Implementation Notes

Created a complete guild system modeled after WC3 mechanics:

1. **Hero System** (`src/guild/hero.lua`):
   - 25-level progression with XP thresholds
   - 4 base stats: strength, agility, intelligence, endurance
   - 6-slot inventory (like WC3 hero)
   - 3 equipment slots: weapon, armor, accessory
   - Capability unlocks from quest completion
   - Title progression based on level

2. **Item System** (`src/guild/items.lua`):
   - 4 item types: equipment, consumable, material, tome
   - 5 rarity levels: common, uncommon, rare, epic, legendary
   - Stat modifiers for equipment
   - Effect system for consumables (heal, grant XP/gold, unlock)
   - 15+ predefined items with programming-themed names

3. **Shop System** (`src/guild/shop.lua`):
   - Stock management (limited or unlimited)
   - Price calculation with discounts
   - Buy/sell transactions
   - Level and capability requirements
   - 4 predefined shops: merchant, armory, arcane, guild hall

4. **CLI** (`src/cli/guild-cli.lua`):
   - Create/switch/list heroes
   - Complete quests and bounties
   - Browse shops and buy items
   - Manage inventory and equipment
   - Use consumable items

5. **Persistence**:
   - JSON serialization to `.guild/` directory
   - Automatic current hero tracking
   - Item reconstruction on load

**Future Enhancement:** WoW-style combat system (see Issue 015)

---

**Status:** Completed
**Completed:** 2025-12-29

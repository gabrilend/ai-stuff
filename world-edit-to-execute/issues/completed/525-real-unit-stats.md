# Issue 525: Units' Real Stats, From the Stock Tables

**Phase:** 7 (gameplay)
**Type:** Implementation
**Priority:** High
**Dependencies:** 519 (combat), 112c (stock rows through the game data chain), 112b (the chain)

---

## Current Behavior

A unit's stats come from the map's object data only: the fields the map
changed. Everything else (every stock unit, and every field a custom unit
kept from its parent) falls to combat's stand-ins by archetype: made-up
numbers that play plausibly, but aren't the game's. Attack point,
backswing, missile speed and weapon type are always stand-ins.

## Intended Behavior

Each value is found as WC3 finds it:

1. **The map's change**, if the map made one.
2. **Else the stock row** of the unit type (or of the stock type a custom one copies), read from the owner's install (`Units\UnitBalance.slk`, `UnitWeapons.slk`, `UnitData.slk` ...), at the column the field's metadata row names (`Units\UnitMetaData.slk`).
3. **Stand-ins** only for what neither gives.

## Suggested Implementation Steps

1. A resolver: field code → metadata row → stock table and column → the base type's row; the map's change on top.
2. `game.lua`'s unit stats through it; heroes' attributes applied.
3. Combat takes attack point, backswing, missile speed and weapon type from it.
4. The map viewer opens the install's tables and says where stats came from.
5. Tests on made-up tables (none of Blizzard's data in the repository).

## Acceptance Criteria

- [x] `gamedata/unit_stock.lua`: `value(id, code)` gives the map's change, else the stock value (with where it came from); custom types read their parent's row; comma-list fields by index; empty cells are no value
- [x] Without an install (or without the metadata table), only the map's changes are known, and it says why
- [x] Units' hit points, mana, armour, damage dice, cooldown, range, acquisition, sight (day and night), move speed and turn rate, food, and whether they attack all come through it
- [x] Heroes: hit points +25 per strength, mana +15 per intelligence, armour +0.3 per agility, damage + the primary attribute (1.21's gameplay constants)
- [x] Combat uses the stock attack point, backswing and missile speed; "normal" and "instant" weapons strike at once
- [x] The map viewer logs how many unit types took stock values, the map's, or only stand-ins
- [x] `test_stats.lua`: 25 tests; full suite passes

## Implementation Notes

**Date:** 2026-09-30

### The resolver (`gamedata/unit_stock.lua`)

- **Reading:** `unit_stock.new(chain, units)` reads `Units\UnitMetaData.slk` through the chain (issue 112b), and each stock table the first time a code needs it.
- **Looking up:** a code's metadata row gives the table (`slk`) and the column (`field`). An `index` of 0 or more picks one entry of a comma list.
- **Which row:** the stock row is the unit type's own, or for a custom type (`units.custom[id].parent_id`) its parent's.
- **Map changes win:** the map's changes (`get_modification`) come first.
- **Empty cells:** `-` and `_` are no value.
- **Cache:** values are cached per type and code.

This is the same metadata lookup as `stock_rows.lua` (issue 112c), for one value at a time. That module builds whole rows for the map's custom objects, which the converter wants; the game needs any type's value by code, stock types included.

### Where it's used

- **`demo/wc3map/game.lua`:** `unit_stats` asks the resolver (`opts.stock`) for every field it reads:
  - The fields it read before.
  - New: attack point (`udp1`), backswing (`ubs1`), missile speed (`ua1z`), weapon type (`ua1w`), sight (`usid`, `usin`) and primary attribute (`upra`).
  - It counts, per type, how many values came from the map and how many from the stock tables (`g.stats_report()`).
- **`demo/wc3map/combat.lua`:** the weapon takes attack point, backswing and missile speed from the unit when given. A "normal" or "instant" weapon strikes at once. The stand-ins stay for what's still missing.
- **`demo/wc3map/main.lua`:**
  - The asset source (the map, then the install) is now opened before the game, so its chain can feed the stats.
  - It logs a `[stats]` line: whether the stock tables were read, and how many unit types took values from each source.

### Checked

- **Tests:** the tests make their own small SYLK tables (made-up numbers) behind a stand-in chain. They check the lookup, and a DAoW 5.4b game whose every unit takes its stats from them: hit points, armour, weapon, attack point and backswing, sight, speed, and heroes' attribute bonuses.
- **Your install:** not run here, since the install isn't in this container. On the owner's machine, the `[stats]` line shows how many types found their stock rows.

### Not yet

- **Hero levels:** heroes' attribute growth per level (`STRplus` ...) isn't applied; a hero placed above level 1 has its base attributes.
- **Research and upgrades** that change stats, and abilities' bonuses (auras, items).
- **Second weapons:** `ua2*` (a second attack), e.g. against air.
- **Attack and armour types** (the damage table: pierce against heavy, and so on).
- **Buildings' stats** come through the same path; their stand-in sizes still set their footprints.

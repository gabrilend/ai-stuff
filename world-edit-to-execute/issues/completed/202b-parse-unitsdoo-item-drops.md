# Issue 202b: Parse unitsdoo Item Drops

**Phase:** 2 - Data Model
**Type:** Feature
**Priority:** Medium
**Dependencies:** 202a-parse-unitsdoo-header-and-basic-fields
**Parent Issue:** 202-parse-war3map-units-doo

---

## Current Behavior

After 202a, the parser skips item drop table data. Units that drop items on death
have this information lost.

---

## Intended Behavior

Parse the item drop table structure within unit entries. This defines what items
a unit drops when killed, with drop chances per item.

Returns structured data:
```lua
unit.item_drops = {
    table_pointer = 0,  -- -1 if none
    sets = {
        {
            items = {
                { id = "ratc", chance = 100 },  -- Claws of Attack +6
                { id = "rin1", chance = 50 },   -- Ring of Protection +1
            }
        },
        -- Additional sets (one random set is chosen on death)
    }
}
```

---

## Suggested Implementation Steps

1. **Locate item drop section in unit entry**
   - After HP/MP fields
   - Before modified abilities section

2. **Parse item table pointer**
   ```lua
   -- int32: Item table pointer
   -- -1 = no items dropped
   -- >= 0 = index into some external table (rarely used, usually inline)
   ```

3. **Parse item sets**
   ```lua
   -- int32: Number of item sets dropped
   -- For each item set:
   --   int32: Number of items in set
   --   For each item:
   --     char[4]: Item type ID (e.g., "ratc")
   --     int32:   Drop chance percentage (0-100)
   ```

4. **Handle edge cases**
   - 0 item sets = no drops
   - Multiple sets = one random set chosen on death
   - 0% chance items (placeholder entries)

5. **Add format output for item drops**

---

## Technical Notes

### Common Item IDs

```lua
-- Permanent items
ratc = "Claws of Attack",
rin1 = "Ring of Protection +1",
bspd = "Boots of Speed",
rwiz = "Sobi Mask",

-- Powerups
texp = "Tome of Experience",
tstr = "Tome of Strength",

-- Charged items
pman = "Mana Potion",
phea = "Healing Potion",
```

### Drop Mechanics

When a unit with item drops dies:
1. One item set is randomly selected (if multiple)
2. Each item in the set rolls against its drop chance
3. Dropped items appear on ground near death location

---

## Related Documents

- issues/202a-parse-unitsdoo-header-and-basic-fields.md
- issues/202-parse-war3map-units-doo.md (parent)

---

## Acceptance Criteria

- [x] Correctly parses item table pointer
- [x] Correctly parses number of item sets
- [x] Correctly parses items per set with IDs and chances
- [x] Handles units with no item drops
- [x] Handles units with multiple item sets
- [x] Unit tests for item drop parsing
- [x] Format output shows item drop info

---

## Notes

Item drops are important for RPG-style maps where loot is a core mechanic.
This data feeds into the game's item spawning system when units die.

---

## Implementation Notes

*Completed 2025-12-21*

### Changes Made

1. **Replaced `skip_item_drops` with `parse_item_drops`:**
   - Returns structured item_drops with table_pointer and sets array
   - Each set contains items array with id, chance, and optional name

2. **Added COMMON_ITEMS lookup table:**
   - Maps item type IDs to human-readable names
   - Used for display and debugging

3. **Updated unit entry structure:**
   - Changed `unit._item_sets_count` placeholder to `unit.item_drops` structure
   - Structure: `{ table_pointer, sets = [ { items = [...] } ] }`

4. **Updated tests:**
   - Expanded item drops test to verify full structure
   - Added assertions for set counts, item IDs, and drop chances

5. **Updated format function:**
   - Added item drop statistics (units with drops, total items)
   - Added per-unit drop listing in sample output with item names and chances

6. **Added UnitTable:with_drops() method:**
   - Query all units that have item drops configured
   - Exported COMMON_ITEMS for external use

### Test Results

94/94 tests pass - item drops parsing verified with synthetic test data and 5 real maps

# Issue 202d: Parse unitsdoo Hero Data

**Phase:** 2 - Data Model
**Type:** Feature
**Priority:** Medium
**Dependencies:** 202a-parse-unitsdoo-header-and-basic-fields
**Parent Issue:** 202-parse-war3map-units-doo

---

## Current Behavior

After 202a, the parser skips hero-specific data. Preplaced heroes lose their
level, stat bonuses, and inventory contents.

---

## Intended Behavior

Parse hero-specific data within unit entries. This section only exists for
hero units (those with capital first letter in type ID, like "Hpal").

Returns structured data:
```lua
unit.hero_data = {
    level = 5,
    str_bonus = 2,   -- Bonus from tomes
    agi_bonus = 0,
    int_bonus = 3,
    inventory = {
        [0] = "bspd",  -- Boots of Speed in slot 0
        [2] = "rin1",  -- Ring of Protection in slot 2
        -- Slots 1,3,4,5 empty (nil)
    },
}
```

---

## Suggested Implementation Steps

1. **Detect hero units**
   - Check if unit type ID starts with capital letter
   - Or check against known hero ID list
   ```lua
   local function is_hero(type_id)
       local first = type_id:sub(1, 1)
       return first:match("[A-Z]") ~= nil
   end
   ```

2. **Parse hero level and stats**
   ```lua
   -- Only present for hero units:
   -- int32: Hero level (1+)
   -- int32: Strength bonus (from tomes)
   -- int32: Agility bonus
   -- int32: Intelligence bonus
   ```

3. **Parse hero inventory**
   ```lua
   -- int32: Number of items in inventory
   -- For each item:
   --   int32:   Slot number (0-5)
   --   char[4]: Item type ID
   ```

4. **Handle non-hero units**
   - Skip hero data section entirely
   - Set hero_data = nil

5. **Add format output for hero data**

---

## Technical Notes

### Hero Type IDs

```lua
-- Human heroes
Hpal = "Paladin",
Hamg = "Archmage",
Hmkg = "Mountain King",
Hblm = "Blood Mage",

-- Orc heroes
Obla = "Blademaster",
Ofar = "Far Seer",
Otch = "Tauren Chieftain",
Oshd = "Shadow Hunter",

-- Undead heroes
Udea = "Death Knight",
Ulic = "Lich",
Udre = "Dreadlord",
Ucrl = "Crypt Lord",

-- Night Elf heroes
Edem = "Demon Hunter",
Ekee = "Keeper of the Grove",
Emoo = "Priestess of the Moon",
Ewar = "Warden",

-- Neutral heroes
Nbrn = "Dark Ranger",
Npbm = "Pandaren Brewmaster",
Nplh = "Pit Lord",
-- etc.
```

### Inventory Slots

```
Slot layout:
[0] [1]
[2] [3]
[4] [5]
```

Slots are 0-indexed. Empty slots are simply not listed in the file.

---

## Related Documents

- issues/202a-parse-unitsdoo-header-and-basic-fields.md
- issues/202-parse-war3map-units-doo.md (parent)

---

## Acceptance Criteria

- [x] Correctly detects hero vs non-hero units
- [x] Correctly parses hero level
- [x] Correctly parses stat bonuses (str/agi/int)
- [x] Correctly parses inventory item count
- [x] Correctly parses inventory slot assignments
- [x] Correctly parses inventory item IDs
- [x] Non-hero units have hero_data = nil
- [x] Unit tests for hero data parsing
- [x] Format output shows hero info

---

## Notes

Hero data is essential for RPG and hero arena maps where preplaced heroes
start with specific levels, items, and stat bonuses. Many campaign maps
also use preplaced leveled heroes.

---

## Implementation Notes

*Completed 2025-12-21*

### Changes Made

1. **Implemented `is_hero` function:**
   - Detects hero units by checking if type ID starts with capital letter
   - Located at line 200 in unitsdoo.lua

2. **Implemented `parse_hero_data` function:**
   - Parses hero level (int32)
   - Parses stat bonuses: str_bonus, agi_bonus, int_bonus (3x int32)
   - Parses inventory: count followed by slot/item_id pairs
   - Returns structured hero_data table

3. **Updated `parse_unit_entry`:**
   - Conditionally calls parse_hero_data for hero units
   - Sets hero_data = nil for non-hero units

4. **Updated format function:**
   - Shows hero statistics in summary (hero count, heroes with items)
   - Displays hero level, stat bonuses (+str/agi/int), and inventory count
   - Lists inventory items by slot with names from COMMON_ITEMS lookup

5. **Extended COMMON_ITEMS table:**
   - Used for both item drops and hero inventory display
   - Maps 4-char item IDs to human-readable names

### Test Results

117/117 tests pass - hero data parsing verified with synthetic test data including:
- Hero level and stat bonus parsing
- Inventory item slot/ID parsing
- Non-hero units correctly have nil hero_data
- Format output displays hero details section

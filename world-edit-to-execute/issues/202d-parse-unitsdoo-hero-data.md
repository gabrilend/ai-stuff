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

- [ ] Correctly detects hero vs non-hero units
- [ ] Correctly parses hero level
- [ ] Correctly parses stat bonuses (str/agi/int)
- [ ] Correctly parses inventory item count
- [ ] Correctly parses inventory slot assignments
- [ ] Correctly parses inventory item IDs
- [ ] Non-hero units have hero_data = nil
- [ ] Unit tests for hero data parsing
- [ ] Format output shows hero info

---

## Notes

Hero data is essential for RPG and hero arena maps where preplaced heroes
start with specific levels, items, and stat bonuses. Many campaign maps
also use preplaced leveled heroes.

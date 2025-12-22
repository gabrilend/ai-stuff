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

- [ ] Correctly parses item table pointer
- [ ] Correctly parses number of item sets
- [ ] Correctly parses items per set with IDs and chances
- [ ] Handles units with no item drops
- [ ] Handles units with multiple item sets
- [ ] Unit tests for item drop parsing
- [ ] Format output shows item drop info

---

## Notes

Item drops are important for RPG-style maps where loot is a core mechanic.
This data feeds into the game's item spawning system when units die.

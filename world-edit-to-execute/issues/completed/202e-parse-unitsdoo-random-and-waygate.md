# Issue 202e: Parse unitsdoo Random Unit and Waygate Data

**Phase:** 2 - Data Model
**Type:** Feature
**Priority:** Medium
**Dependencies:** 202a-parse-unitsdoo-header-and-basic-fields
**Parent Issue:** 202-parse-war3map-units-doo

---

## Current Behavior

After 202a, the parser skips random unit data and waygate destinations.
Random unit spawners and functional waygates are not properly initialized.

---

## Intended Behavior

Parse the final variable-length sections of unit entries:
1. Random unit/item configuration
2. Waygate destination region
3. Creation number (unique editor ID)

Returns structured data:
```lua
-- Random unit by level
unit.random_unit = {
    type = "level",
    level = 4,  -- Random level 4 unit
}

-- Random unit from group
unit.random_unit = {
    type = "group",
    group_index = 2,
    position = 0,  -- First unit in group
}

-- Random item
unit.random_item = {
    type = "level",
    level = 3,  -- Random level 3 item
}

-- Waygate destination
unit.waygate_dest = 42  -- Region creation number, or -1 if inactive

-- Unique editor ID
unit.creation_number = 1234
```

---

## Suggested Implementation Steps

1. **Parse random unit/item flag**
   ```lua
   -- int32: Random flag
   -- 0 = not random (normal unit)
   -- 1 = random from level
   -- 2 = random from group
   ```

2. **Parse random-from-level data**
   ```lua
   -- If flag == 1:
   --   char[3]: "YYU" for unit, "YYI" for item (only first char matters)
   --   byte:    Level character ('0'-'9', 'A'-'Z')

   -- Level encoding:
   -- '0' = level 0, '1' = level 1, ... '9' = level 9
   -- 'A' = level 10, 'B' = level 11, etc.
   ```

3. **Parse random-from-group data**
   ```lua
   -- If flag == 2:
   --   int32: Group index (references random group table)
   --   int32: Position within group
   ```

4. **Parse waygate destination**
   ```lua
   -- int32: Waygate region destination
   -- -1 = not a waygate / inactive
   -- >= 0 = region creation number (from war3map.w3r)
   ```

5. **Parse creation number**
   ```lua
   -- int32: Creation number
   -- Unique ID assigned by World Editor
   -- Used for trigger references
   ```

6. **Add format output for random/waygate data**

---

## Technical Notes

### Random Unit IDs

Special placeholder IDs:
```lua
-- "YYU" prefix = random unit
-- "YYI" prefix = random item
-- Actually stored as 4 bytes: "YYU" + level_char

-- Example: "YYU5" = random level 5 unit
-- The level character is the 4th byte
```

### Level Encoding

```lua
local function decode_level(char)
    local byte = string.byte(char)
    if byte >= 48 and byte <= 57 then  -- '0'-'9'
        return byte - 48
    elseif byte >= 65 and byte <= 90 then  -- 'A'-'Z'
        return byte - 65 + 10
    else
        return 0
    end
end
```

### Waygate Integration

Waygates teleport units to target regions:
1. Parse waygate_dest from this file
2. Look up region by creation_number in w3r data (issue 203)
3. Teleport destination = region center point

### Creation Number

Every preplaced object has a unique creation_number:
- Used by triggers to reference specific units
- Must be preserved for trigger compatibility
- Same concept as doodad creation_number

---

## Related Documents

- issues/202a-parse-unitsdoo-header-and-basic-fields.md
- issues/203-parse-war3map-w3r.md (region parser - waygate targets)
- issues/202-parse-war3map-units-doo.md (parent)

---

## Acceptance Criteria

- [x] Correctly parses random unit flag (0, 1, 2)
- [x] Correctly parses random-from-level data ("YYU"/"YYI" + level)
- [x] Correctly parses random-from-group data (group index, position)
- [x] Correctly parses waygate destination
- [x] Correctly parses creation number
- [x] Handles non-random units (flag = 0)
- [x] Handles inactive waygates (dest = -1)
- [x] Unit tests for random/waygate parsing
- [x] Format output shows random/waygate info

---

## Notes

Random units are used in melee maps for creep camps and in custom maps
for procedural content. Waygates are commonly used in RPG and dungeon
maps for teleportation.

The creation_number is critical for trigger compatibility - many map
scripts reference units by their creation number.

---

## Implementation Notes

*Completed 2025-12-21*

### Changes Made

1. **Added `decode_random_level` function:**
   - Decodes level character to numeric level
   - '0'-'9' = levels 0-9, 'A'-'Z' = levels 10-35
   - Exported as `unitsdoo.decode_random_level` for testing

2. **Replaced `skip_random_unit` with `parse_random_unit`:**
   - Returns structured random_unit table (or nil for non-random)
   - Structure varies by flag type:
     - flag=1: `{ flag=1, type="unit"/"item", level=N }`
     - flag=2: `{ flag=2, group_index=N, position=N }`
   - Distinguishes "YYU" (random unit) from "YYI" (random item) prefixes

3. **Updated unit entry structure:**
   - Changed `unit.random_flag` to `unit.random_unit` structure
   - Waygate destination and creation number were already parsed

4. **Updated format output:**
   - Shows random unit/item info: `random: unit level 5` or `random: group 3 pos 1`
   - Shows active waygates: `waygate -> region 42`

5. **Expanded test suite:**
   - 4 test units covering all random flag types
   - Tests for random unit from level, random from group, random item from level
   - Tests for active waygate destination
   - Separate test for `decode_random_level` edge cases

### Test Results

139/139 tests pass - random unit and waygate parsing verified with synthetic data and 5 real maps

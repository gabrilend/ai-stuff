# Issue 202: Parse war3mapUnits.doo (Units/Buildings)

**Phase:** 2 - Data Model
**Type:** Feature
**Priority:** High
**Dependencies:** 102-implement-mpq-archive-parser, 201-parse-war3map-doo

---

## Current Behavior

Cannot read unit/building placement data. Preplaced units, buildings, heroes,
and items are inaccessible for game initialization.

---

## Intended Behavior

A parser that extracts all unit/building/item placement from war3mapUnits.doo:
- Unit type IDs (referencing UnitData.slk)
- Position (X, Y, Z coordinates)
- Rotation and scale
- Player ownership
- Hit points and mana
- Item drops on death
- Modified abilities
- Waygate destinations
- Hero levels and stats
- Random unit/item tables

---

## Suggested Implementation Steps

1. **Create parser module**
   ```
   src/parsers/
   └── unitsdoo.lua     (this issue)
   ```

2. **Implement header parsing**
   ```lua
   -- war3mapUnits.doo header structure:
   -- Offset  Type      Description
   -- 0x00    char[4]   File ID = "W3do"
   -- 0x04    int32     File version (8 for TFT)
   -- 0x08    int32     Subversion
   -- 0x0C    int32     Number of units
   ```

3. **Implement unit entry parsing**
   ```lua
   -- Each unit entry (variable size):
   -- char[4]: Unit type ID (from UnitData.slk)
   -- int32:   Variation
   -- float:   X coordinate
   -- float:   Y coordinate
   -- float:   Z coordinate
   -- float:   Angle (radians)
   -- float:   X scale
   -- float:   Y scale
   -- float:   Z scale
   -- byte:    Flags
   -- int32:   Player number (0-15, or neutral)
   -- byte:    Unknown (usually 0)
   -- byte:    Unknown (usually 0)
   -- int32:   Hit points (-1 = default)
   -- int32:   Mana points (-1 = default)
   ```

4. **Parse item drop tables**
   ```lua
   -- int32: Item table pointer (-1 = none, >= 0 = table index)
   -- int32: Number of item sets dropped
   -- For each item set:
   --   int32: Number of items
   --   For each item:
   --     char[4]: Item ID
   --     int32:   Drop chance (%)
   ```

5. **Parse modified abilities**
   ```lua
   -- int32: Number "k" of modified abilities
   -- For each ability:
   --   char[4]: Ability ID
   --   int32:   Autocast enabled (0/1)
   --   int32:   Ability level
   ```

6. **Parse hero-specific data**
   ```lua
   -- int32: Hero level (for hero units)
   -- int32: Strength bonus
   -- int32: Agility bonus
   -- int32: Intelligence bonus
   -- int32: Number of items in inventory
   -- For each inventory slot:
   --   int32: Slot number (0-5)
   --   char[4]: Item type ID
   ```

7. **Parse random unit data**
   ```lua
   -- int32: Random unit flag
   -- if flag == 1 (random from level):
   --   char[3]: "YYU"
   --   byte:    Level character
   -- if flag == 2 (random from group):
   --   int32:   Group index
   --   int32:   Position in group
   ```

8. **Parse waygate destination**
   ```lua
   -- int32: Waygate destination (-1 = inactive, else region creation number)
   ```

9. **Parse creation number**
   ```lua
   -- int32: Creation number (unique editor ID)
   ```

10. **Return structured data**
    ```lua
    return {
        version = 8,
        units = {
            {
                id = "hfoo",           -- Footman
                variation = 0,
                position = { x = 1024.0, y = 2048.0, z = 0.0 },
                angle = 3.14,
                scale = { x = 1.0, y = 1.0, z = 1.0 },
                player = 0,
                hp = -1,               -- Default
                mp = -1,               -- Default
                item_drops = { ... },
                abilities = { ... },
                hero_data = nil,       -- Only for heroes
                random_unit = nil,
                waygate_dest = -1,
                creation_number = 1,
            },
            -- ...
        },
    }
    ```

---

## Technical Notes

### Unit Type Categories

Unit IDs indicate type by first character:
- `h` - Human units (hfoo = Footman, hkni = Knight)
- `o` - Orc units (ogru = Grunt, okod = Kodo)
- `u` - Undead units (ugho = Ghoul, uabo = Abomination)
- `e` - Night Elf units (earc = Archer, edry = Dryad)
- `n` - Neutral units

Building IDs:
- `htow` - Human Town Hall
- `ogre` - Orc Great Hall
- `unpl` - Undead Necropolis
- `etol` - Night Elf Tree of Life

### Random Unit IDs

Special IDs for random placement:
- `YYU` + level char: Random unit of that level
- First letter `Y`, third `I`: Random item

### Player Numbers

```lua
local PLAYERS = {
    [0]  = "Player 1 (Red)",
    [1]  = "Player 2 (Blue)",
    -- ... up to 15
    [24] = "Neutral Hostile",
    [25] = "Neutral Passive",
    [27] = "Neutral Victim",
}
```

### Reforged Compatibility

Version 1.32+ adds `skinId` field after unit type ID:
```lua
-- char[4]: Unit type ID
-- char[4]: Skin ID (1.32+, check w3i version)
```

---

## Related Documents

- docs/formats/unitsdoo.md (to be created)
- issues/201-parse-war3map-doo.md (similar structure)
- issues/206-design-game-object-types.md (defines Unit type)

---

## Acceptance Criteria

- [ ] Can parse war3mapUnits.doo from all test archives
- [ ] Correctly extracts unit type IDs
- [ ] Correctly extracts positions and rotations
- [ ] Correctly extracts player ownership
- [ ] Correctly extracts HP/MP values
- [ ] Correctly parses item drop tables
- [ ] Correctly parses modified abilities
- [ ] Correctly parses hero-specific data
- [ ] Handles random unit placeholders
- [ ] Handles waygate destinations
- [ ] Returns structured Lua table
- [ ] Unit tests for parser

---

## Notes

This is the most complex placement file. It handles units, buildings, items,
and heroes with their various attributes. The structure is similar to
war3map.doo but with many additional fields.

Reference: [WC3MapSpecification](https://github.com/ChiefOfGxBxL/WC3MapSpecification)
Reference: [SimonMossmyr/w3x-spec](https://github.com/SimonMossmyr/w3x-spec)

---

## Sub-Issue Analysis

*Generated by Claude Code on 2025-12-16 05:35*

## Sub-Issue Analysis

This issue is a good candidate for splitting. The war3mapUnits.doo parser handles multiple distinct data structures that can be implemented and tested incrementally. The file format has a clear header followed by variable-length unit entries with optional sub-structures.

### Recommended Sub-Issues

#### 202a-parse-unitsdoo-header-and-basic-fields

**Description:** Parse the file header and basic unit entry fields (type ID, position, rotation, scale, player, HP/MP). This establishes the parser skeleton and handles the fixed-size portion of each entry.

**Covers:**
- File ID validation ("W3do")
- Version and subversion parsing
- Unit count extraction
- Basic unit fields through HP/MP
- Reforged skinId field detection (based on version)

**Dependencies:** 102-implement-mpq-archive-parser, 201-parse-war3map-doo (for pattern reference)

---

#### 202b-parse-unitsdoo-item-drops

**Description:** Parse the item drop table structure within unit entries. This is an optional variable-length section that defines what items a unit drops on death.

**Covers:**
- Item table pointer handling (-1 = none)
- Item set iteration
- Item ID and drop chance extraction

**Dependencies:** 202a (requires basic parser structure)

---

#### 202c-parse-unitsdoo-abilities

**Description:** Parse the modified abilities section. Units can have abilities with custom autocast settings and levels.

**Covers:**
- Ability count parsing
- Ability ID extraction
- Autocast flag and level values

**Dependencies:** 202a (requires basic parser structure)

---

#### 202d-parse-unitsdoo-hero-data

**Description:** Parse hero-specific data including level, stat bonuses, and inventory items. This section only exists for hero units.

**Covers:**
- Hero level extraction
- Strength/Agility/Intelligence bonuses
- Inventory slot parsing (0-5 slots with item IDs)
- Conditional parsing (only for hero unit types)

**Dependencies:** 202a (requires basic parser structure)

---

#### 202e-parse-unitsdoo-random-and-waygate

**Description:** Parse random unit data and waygate destination fields. These are the final variable sections before the creation number.

**Covers:**
- Random unit flag handling (0, 1, or 2)
- "YYU" + level character parsing
- Group index and position parsing
- Waygate destination extraction
- Creation number (unique editor ID)

**Dependencies:** 202a (requires basic parser structure)

---

### Dependency Graph

```
202a (header + basic) ─────┬──▶ 202b (item drops)
                           ├──▶ 202c (abilities)
                           ├──▶ 202d (hero data)
                           └──▶ 202e (random/waygate)
```

Sub-issues 202b through 202e can be implemented in parallel after 202a is complete, as they handle independent sections of the unit entry structure.

### Implementation Order Recommendation

1. **202a** - Establishes parser skeleton, enables basic unit extraction
2. **202b, 202c, 202d, 202e** - Can be done in any order or parallel
3. Integration testing after all sub-issues complete

This split allows incremental progress with testable milestones. Even with just 202a complete, the parser would return useful unit placement data (positions, types, players) that could be used by downstream consumers.

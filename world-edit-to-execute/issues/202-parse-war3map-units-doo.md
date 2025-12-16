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

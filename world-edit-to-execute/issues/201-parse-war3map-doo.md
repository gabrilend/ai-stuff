# Issue 201: Parse war3map.doo (Doodads/Trees)

**Phase:** 2 - Data Model
**Type:** Feature
**Priority:** High
**Dependencies:** 102-implement-mpq-archive-parser

---

## Current Behavior

Cannot read doodad/destructible placement data. Trees, rocks, and other map
decorations are inaccessible for rendering or gameplay interaction.

---

## Intended Behavior

A parser that extracts all doodad/destructible placement from war3map.doo:
- Doodad type IDs (referencing DestructableData.slk)
- Position (X, Y, Z coordinates)
- Rotation and scale
- Variation index
- Life percentage
- Visibility/solidity flags
- Unique editor IDs

---

## Suggested Implementation Steps

1. **Create parser module**
   ```
   src/parsers/
   └── doo.lua          (this issue)
   ```

2. **Implement header parsing**
   ```lua
   -- war3map.doo header structure:
   -- Offset  Type      Description
   -- 0x00    char[4]   File ID = "W3do"
   -- 0x04    int32     File version (7 for TFT)
   -- 0x08    int32     Subversion (usually 0x09)
   -- 0x0C    int32     Number of doodads
   ```

3. **Implement doodad entry parsing**
   ```lua
   -- Each doodad entry (42 bytes):
   -- char[4]: Doodad type ID (from DestructableData.slk)
   -- int32:   Variation
   -- float:   X coordinate
   -- float:   Y coordinate
   -- float:   Z coordinate
   -- float:   Angle (radians)
   -- float:   X scale
   -- float:   Y scale
   -- float:   Z scale
   -- byte:    Flags (0=invisible/non-solid, 1=visible/non-solid, 2=normal)
   -- byte:    Life percentage (100% = 0x64)
   -- int32:   Creation number (unique editor ID)
   ```

4. **Parse optional item drop table reference**
   ```lua
   -- After all doodad entries:
   -- int32: Special doodads version (usually 0)
   -- int32: Number of special doodads (trees with item drops)
   -- For each special doodad:
   --   char[4]: Doodad ID
   --   int32:   Number of item sets
   --   For each item set:
   --     int32: Number of items
   --     For each item:
   --       char[4]: Item ID
   --       int32:   Drop chance (%)
   ```

5. **Return structured data**
   ```lua
   return {
       version = 7,
       subversion = 9,
       doodads = {
           {
               id = "LTlt",           -- Tree type
               variation = 0,
               position = { x = 1024.0, y = 2048.0, z = 0.0 },
               angle = 1.57,          -- Radians
               scale = { x = 1.0, y = 1.0, z = 1.0 },
               flags = 2,             -- Normal (visible + solid)
               life = 100,
               creation_number = 1,
           },
           -- ...
       },
       special_doodads = {
           -- Trees with item drop tables
       },
   }
   ```

---

## Technical Notes

### Doodad IDs

Doodad type IDs are 4-character codes that reference entries in:
- `Units\DestructableData.slk` - destructible objects
- `Units\AbilityData.slk` - ability-related doodads

Common codes:
- `LTlt` - Lordaeron Summer Tree
- `ATtr` - Ashenvale Tree
- `BTtw` - Barrens Twig

### Flags Interpretation

```lua
local FLAGS = {
    [0] = "invisible_non_solid",  -- Not rendered, no collision
    [1] = "visible_non_solid",    -- Rendered but no collision
    [2] = "normal",               -- Rendered with collision
}
```

### Coordinate System

Doodad coordinates use WC3's world coordinate system:
- Origin at map center
- 1 unit = 1/128 of a terrain tile
- Z is height above terrain

### Reforged Compatibility

Version 1.32+ may include additional `skinId` field per doodad.
Check war3map.w3i game version to determine parsing behavior.

---

## Related Documents

- docs/formats/doo-doodads.md (to be created)
- issues/102-implement-mpq-archive-parser.md (provides file access)
- issues/206-design-game-object-types.md (defines Doodad type)

---

## Acceptance Criteria

- [ ] Can parse war3map.doo from all test archives
- [ ] Correctly extracts doodad type IDs
- [ ] Correctly extracts positions and rotations
- [ ] Correctly extracts scale values
- [ ] Correctly extracts flags and life
- [ ] Handles special doodad item drops
- [ ] Returns structured Lua table
- [ ] Unit tests for parser

---

## Notes

This is the first "placement" parser - it deals with where objects are placed
on the map rather than their definitions. Patterns established here will be
reused for the similar war3mapUnits.doo parser.

Reference: [WC3MapSpecification](https://github.com/ChiefOfGxBxL/WC3MapSpecification)

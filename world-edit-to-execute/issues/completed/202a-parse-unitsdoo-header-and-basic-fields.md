# Issue 202a: Parse unitsdoo Header and Basic Fields

**Phase:** 2 - Data Model
**Type:** Feature
**Priority:** High
**Dependencies:** 102-implement-mpq-archive-parser, 201-parse-war3map-doo
**Parent Issue:** 202-parse-war3map-units-doo

---

## Current Behavior

No parser exists for war3mapUnits.doo. Cannot extract preplaced units, buildings,
or items from map files.

---

## Intended Behavior

Parse the file header and basic unit entry fields, establishing the parser skeleton
that handles the fixed-size portion of each entry. Returns structured data for:

- File ID validation ("W3do")
- Version and subversion
- Unit count
- Per-unit: type ID, position, rotation, scale, player, HP/MP
- Reforged skinId field detection (based on version)

---

## Suggested Implementation Steps

1. **Create parser module skeleton**
   ```
   src/parsers/unitsdoo.lua
   ```

2. **Implement header parsing**
   ```lua
   -- war3mapUnits.doo header structure:
   -- Offset  Type      Description
   -- 0x00    char[4]   File ID = "W3do"
   -- 0x04    int32     File version (7=RoC, 8=TFT)
   -- 0x08    int32     Subversion
   -- 0x0C    int32     Number of units
   ```

3. **Implement basic unit entry fields**
   ```lua
   -- Each unit entry starts with (fixed portion):
   -- char[4]: Unit type ID (e.g., "hfoo" = Footman)
   -- int32:   Variation
   -- float:   X coordinate
   -- float:   Y coordinate
   -- float:   Z coordinate
   -- float:   Angle (radians)
   -- float:   X scale
   -- float:   Y scale
   -- float:   Z scale
   -- byte:    Flags
   -- int32:   Player number (0-15, or neutral 24/25/27)
   -- byte:    Unknown1 (usually 0)
   -- byte:    Unknown2 (usually 0)
   -- int32:   Hit points (-1 = default)
   -- int32:   Mana points (-1 = default)
   ```

4. **Handle Reforged compatibility**
   ```lua
   -- Version 1.32+ adds skinId after unit type ID:
   -- char[4]: Unit type ID
   -- char[4]: Skin ID (only if version >= 32 in w3i)
   ```
   Note: May need to pass w3i version info or detect via file version.

5. **Create UnitTable class** (similar to DoodadTable)
   - Index by creation_number
   - Index by type_id
   - Index by player
   - Spatial query methods (in_bounds)

6. **Placeholder for variable-length sections**
   - Item drops (202b)
   - Modified abilities (202c)
   - Hero data (202d)
   - Random unit/waygate (202e)

   For now, skip these sections by reading their counts and advancing position.

---

## Technical Notes

### Unit Type ID Categories

```lua
-- First character indicates faction:
-- h = Human (hfoo=Footman, hkni=Knight, Hpal=Paladin)
-- o = Orc (ogru=Grunt, okod=Kodo, Obla=Blademaster)
-- u = Undead (ugho=Ghoul, uabo=Abomination, Udea=Death Knight)
-- e = Night Elf (earc=Archer, edry=Dryad, Edem=Demon Hunter)
-- n = Neutral (various)

-- Capital first letter = hero unit
```

### Player Numbers

```lua
local PLAYERS = {
    [0]  = "Player 1 (Red)",
    [1]  = "Player 2 (Blue)",
    [2]  = "Player 3 (Teal)",
    [3]  = "Player 4 (Purple)",
    [4]  = "Player 5 (Yellow)",
    [5]  = "Player 6 (Orange)",
    [6]  = "Player 7 (Green)",
    [7]  = "Player 8 (Pink)",
    [8]  = "Player 9 (Gray)",
    [9]  = "Player 10 (Light Blue)",
    [10] = "Player 11 (Dark Green)",
    [11] = "Player 12 (Brown)",
    [24] = "Neutral Hostile",
    [25] = "Neutral Passive",
    [27] = "Neutral Victim",
}
```

### File Version Differences

- Version 7 (RoC): Base format
- Version 8 (TFT): Extended format, most common
- Version 11+: Reforged, adds skin IDs

---

## Related Documents

- docs/formats/unitsdoo.md (to be created with this issue)
- src/parsers/doo.lua (reference implementation for doodads)
- issues/202-parse-war3map-units-doo.md (parent issue)

---

## Acceptance Criteria

- [x] Can parse war3mapUnits.doo header from all test archives
- [x] Correctly extracts unit type IDs
- [x] Correctly extracts positions (X, Y, Z)
- [x] Correctly extracts rotation angle
- [x] Correctly extracts scale factors
- [x] Correctly extracts player ownership
- [x] Correctly extracts HP/MP values (-1 for default)
- [x] Handles version 7 and version 8 files
- [x] UnitTable class with lookup indices
- [x] Unit tests for parser (test_unitsdoo.lua)
- [x] Skips variable-length sections safely (for 202b-e to implement)

---

## Notes

This establishes the parser skeleton. Even with just basic fields parsed, the
output is useful - positions and types allow map visualization, player ownership
enables force setup, etc.

Variable-length sections (items, abilities, hero data, random units) will be
implemented in sub-issues 202b through 202e.

---

## Implementation Notes

*Completed 2025-12-21*

### Files Created/Modified

- `src/parsers/unitsdoo.lua` - Main parser module (609 lines)
- `src/tests/test_unitsdoo.lua` - Test suite (662 lines)

### Implementation Details

1. **Parser Structure:**
   - Header parsing: file ID "W3do", version, subversion, unit count
   - Unit entry parsing with skip functions for variable-length sections
   - is_hero() detection via capital first letter

2. **Skip Functions:**
   - `skip_item_drops()` - Reads item table pointer and set counts, advances position
   - `skip_abilities()` - Reads ability count, skips 12 bytes per ability
   - `skip_hero_data()` - Skips hero level, stats, and inventory for hero units
   - `skip_random_unit()` - Handles random flags 0, 1, and 2

3. **UnitTable Class:**
   - Indices: by_creation_number, by_type, by_player
   - Methods: get(), get_by_type(), get_by_player(), heroes()
   - Spatial query: in_bounds(min_x, min_y, max_x, max_y)

4. **Test Results:**
   - 10 synthetic tests covering all parser functionality
   - 5/16 test maps contain war3mapUnits.doo (rest have no preplaced units)
   - Total: 79/79 tests pass

5. **Hero Detection Fix:**
   - Initial implementation treated "YYU*" and "YYI*" (random unit/item placeholders) as heroes
   - Fixed is_hero() to exclude type IDs starting with "YY" prefix
   - Prevents incorrect hero data parsing for random unit placeholders

### Test Map Statistics

| Map | Units | Heroes | Version |
|-----|-------|--------|---------|
| DaoW-(HvA)-7.5.w3x | 1 | 0 | 7 |
| Daow4.7.3.w3x | 1 | 0 | 7 |
| DaoW-6.93-(HvA).w3x | 1 | 0 | 7 |
| Daow4.4.w3x | 1 | 0 | 7 |
| DaoW-6.8-(HvA).w3x | 1 | 0 | 7 |

Note: Most test maps are "HvA" (Hero vs Army) style with minimal preplaced units.
The parser correctly handles version 7 format used by these maps.

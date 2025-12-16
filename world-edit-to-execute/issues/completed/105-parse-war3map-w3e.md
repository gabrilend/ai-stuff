# Issue 105: Parse war3map.w3e (Terrain Data)

**Phase:** 1 - Foundation
**Type:** Feature
**Priority:** High
**Dependencies:** 102-implement-mpq-archive-parser, 103-parse-war3map-w3i

---

## Current Behavior

Cannot read terrain information. Map topology, ground textures, water,
and cliffs are inaccessible. Without terrain, no visual representation
of maps is possible.

---

## Intended Behavior

A parser that extracts complete terrain data from war3map.w3e:
- Terrain tile grid (texture indices)
- Height map (elevation data)
- Water levels
- Cliff information
- Doodad pathing/placement data

---

## Suggested Implementation Steps

1. **Create parser module**
   ```
   src/parsers/
   ├── w3i.lua
   ├── wts.lua
   └── w3e.lua          (this issue)
   ```

2. **Parse w3e header**
   ```lua
   -- w3e header structure:
   -- Offset  Type      Description
   -- 0x00    char[4]   Magic "W3E!"
   -- 0x04    int32     Version (11)
   -- 0x08    char      Main tileset
   -- 0x09    int32     Custom tileset flag
   -- 0x0D    int32     Number of ground tilesets
   -- 0x11    char[4][] Ground tileset IDs (4 chars each)
   -- ...     int32     Number of cliff tilesets
   -- ...     char[4][] Cliff tileset IDs
   -- ...     int32     Map width + 1
   -- ...     int32     Map height + 1
   -- ...     float     Center offset X
   -- ...     float     Center offset Y
   ```

3. **Parse tile data**
   ```lua
   -- Each tile is 7 bytes:
   -- Bytes 0-1: int16   Ground height
   -- Bytes 2-3: int16   Water level + flags
   -- Byte 4:    flags   Ground texture + cliff info
   -- Byte 5:    flags   Texture variation + cliff
   -- Byte 6:    flags   Layer info

   -- Bit breakdown for byte 4:
   -- Bits 0-3: Ground texture index (0-15)
   -- Bit 4:    Ramp flag
   -- Bit 5:    Blight flag
   -- Bit 6:    Water flag
   -- Bit 7:    Boundary flag
   ```

4. **Implement height calculation**
   ```lua
   -- Height formula:
   -- actual_height = (raw_height - 8192) / 4

   function decode_height(raw)
       return (raw - 8192) / 4.0
   end
   ```

5. **Implement water level decoding**
   ```lua
   -- Water is encoded similarly to height
   -- Bits 14-15 of water field contain flags

   function decode_water(raw)
       local level = raw & 0x3FFF  -- Lower 14 bits
       local flags = (raw >> 14) & 0x03
       return {
           level = (level - 8192) / 4.0,
           flags = flags
       }
   end
   ```

6. **Build terrain grid**
   ```lua
   function parse_terrain(data)
       -- ... parse header ...

       local tiles = {}
       for y = 0, height do
           tiles[y] = {}
           for x = 0, width do
               local offset = header_size + (y * (width + 1) + x) * 7
               tiles[y][x] = {
                   height = decode_height(read_int16(data, offset)),
                   water = decode_water(read_int16(data, offset + 2)),
                   ground_texture = data:byte(offset + 4) & 0x0F,
                   is_ramp = (data:byte(offset + 4) & 0x10) ~= 0,
                   is_blight = (data:byte(offset + 4) & 0x20) ~= 0,
                   has_water = (data:byte(offset + 4) & 0x40) ~= 0,
                   is_boundary = (data:byte(offset + 4) & 0x80) ~= 0,
                   variation = data:byte(offset + 5) & 0x1F,
                   cliff_type = (data:byte(offset + 5) >> 5) & 0x07,
                   layer = data:byte(offset + 6),
               }
           end
       end

       return {
           width = width,
           height = height,
           tileset = tileset,
           ground_tilesets = ground_tilesets,
           cliff_tilesets = cliff_tilesets,
           center = { x = center_x, y = center_y },
           tiles = tiles,
       }
   end
   ```

7. **Add accessor methods**
   ```lua
   function Terrain:get_height(x, y)
   function Terrain:get_texture(x, y)
   function Terrain:is_walkable(x, y)
   function Terrain:is_water(x, y)
   ```

---

## Technical Notes

### Coordinate System

- Origin (0,0) is bottom-left corner
- X increases to the right
- Y increases upward
- Each tile is 128 game units

### Tileset IDs

Tilesets are identified by 4-character codes:
```lua
-- Example ground tilesets for Lordaeron Summer:
-- "Ldrt" - Lordaeron dirt
-- "Lgrs" - Lordaeron grass
-- "Lrok" - Lordaeron rock
-- etc.
```

### Cliff Levels

Cliffs have multiple levels. The layer byte determines cliff height:
- 0 = No cliff
- 1 = Level 1 cliff (1 cliff high)
- 2 = Level 2 cliff (2 cliffs high)
- etc.

### Memory Considerations

Terrain data can be large:
- 256x256 map = 65,536 tiles * 7 bytes = 458,752 bytes raw
- Parsed structure will be larger due to Lua table overhead
- Consider lazy loading or chunked access for very large maps

---

## Related Documents

- docs/formats/w3e-terrain.md (to be created in 101)
- issues/103-parse-war3map-w3i.md (provides map dimensions)
- issues/102-implement-mpq-archive-parser.md (provides file access)

---

## Acceptance Criteria

- [x] Can parse war3map.w3e from test archives
- [x] Correctly extracts height map
- [x] Correctly identifies ground textures
- [x] Correctly identifies water areas
- [x] Correctly identifies cliffs and ramps
- [x] Grid dimensions match w3i map dimensions
- [x] Unit tests for parser and decoders

---

## Notes

This is the most complex Phase 1 parser. Take time to understand the
bit-level encoding before implementing.

The terrain data is essential for Phase 5 (rendering) - it defines the
3D mesh that forms the game world. Accuracy here is critical.

Consider creating a debug visualization (even ASCII art) to verify
terrain parsing is correct.

---

## Sub-Issue Analysis

*Generated by Claude Code on 2025-12-16 00:22*

## Analysis

This issue is a good candidate for splitting. It's described as "the most complex Phase 1 parser" and involves several distinct components with clear boundaries:

1. **Header parsing** - Variable-length structure with tilesets
2. **Tile data parsing** - 7-byte per-tile binary format with complex bit-level encoding
3. **Terrain grid construction** - Building the full data structure
4. **Accessor API** - Query methods for consumers

Here's my recommended split:

---

## Suggested Sub-Issues

### 105a-parse-w3e-header
**Description:** Parse the war3map.w3e header structure including magic number validation, version check, tileset information (main tileset, ground tilesets, cliff tilesets), and map dimensions with center offset.

**Scope:**
- Magic "W3E!" validation
- Version parsing (expect 11)
- Main tileset character
- Ground tileset count and 4-char ID array
- Cliff tileset count and 4-char ID array
- Map width/height extraction
- Center offset X/Y floats
- Return header size for tile data offset calculation

**Dependencies:** None (within 105 family)

---

### 105b-decode-tile-data
**Description:** Implement the 7-byte tile decoder including height calculation, water level decoding with flags, ground texture extraction, and all per-tile flags (ramp, blight, water, boundary, variation, cliff type, layer).

**Scope:**
- `decode_height(raw)` - (raw - 8192) / 4.0 formula
- `decode_water(raw)` - 14-bit level + 2-bit flags extraction
- `decode_tile(data, offset)` - Full 7-byte tile parsing
  - Ground texture index (bits 0-3 of byte 4)
  - Ramp/blight/water/boundary flags (bits 4-7 of byte 4)
  - Texture variation (bits 0-4 of byte 5)
  - Cliff type (bits 5-7 of byte 5)
  - Layer byte
- Unit tests for each decoder function with known values

**Dependencies:** None (within 105 family)

---

### 105c-build-terrain-grid
**Description:** Construct the complete terrain grid by iterating over all tiles, assembling the parsed data into an accessible structure, and validating dimensions against w3i map info.

**Scope:**
- Main `parse_terrain(data)` function
- Grid iteration (width+1 × height+1 tiles)
- Offset calculation: `header_size + (y * (width + 1) + x) * 7`
- Assemble final terrain structure with metadata
- Dimension validation against w3i
- Integration test with real w3e files

**Dependencies:** 105a, 105b

---

### 105d-terrain-accessor-api
**Description:** Implement the Terrain object with accessor methods for querying terrain properties at specific coordinates, including walkability determination.

**Scope:**
- `Terrain:get_height(x, y)` - Return decoded height
- `Terrain:get_texture(x, y)` - Return ground texture index
- `Terrain:is_walkable(x, y)` - Combine cliff/water/boundary checks
- `Terrain:is_water(x, y)` - Water presence check
- `Terrain:get_tile(x, y)` - Raw tile data access
- Bounds checking with appropriate errors
- Coordinate system documentation (bottom-left origin)

**Dependencies:** 105c

---

## Dependency Graph

```
105a (header)     105b (tile decoder)
      \                /
       \              /
        v            v
         105c (grid)
              |
              v
         105d (API)
```

---

## Implementation Order

1. **105a** and **105b** can be developed in parallel - they have no interdependencies
2. **105c** requires both 105a and 105b
3. **105d** requires 105c

This split allows for:
- Parallel development of header and tile parsing
- Isolated unit testing of decoders
- Clear integration point at grid construction
- Clean API layer separation

---

## Implementation Notes

*Completed 2025-12-16*

### What Was Built

Created `src/parsers/w3e.lua` - a full parser for war3map.w3e terrain files:

```lua
local w3e = require("parsers.w3e")
local terrain = w3e.parse(data)

-- Properties:
terrain.width, terrain.height    -- Tilepoint grid size
terrain.tileset, terrain.tileset_code  -- e.g., "cityscape", "Y"
terrain.ground_tilesets         -- Array of 4-char texture IDs
terrain.cliff_tilesets          -- Array of 4-char cliff IDs
terrain.offset_x, terrain.offset_y  -- World coordinate offsets

-- Methods:
terrain:get_tile(x, y)          -- Full tilepoint data
terrain:get_height(x, y)        -- World height
terrain:get_texture(x, y)       -- Ground texture index
terrain:is_walkable(x, y)       -- Pathability check
terrain:is_water(x, y)          -- Water presence
terrain:get_layer(x, y)         -- Cliff layer height
terrain:tile_to_world(x, y)     -- Coordinate conversion
terrain:world_to_tile(wx, wy)   -- Inverse conversion
terrain:stats()                 -- Statistics summary

-- Formatting:
print(w3e.format(terrain))
```

### Tilepoint Data

Each tilepoint contains:
- `height` / `height_raw` - Ground elevation
- `water_level` / `water_raw` - Water surface
- `ground_texture` - Index into ground_tilesets
- `is_ramp`, `is_blight`, `has_water`, `is_boundary` - Flags
- `texture_details`, `cliff_variation` - Visual details
- `cliff_texture`, `layer_height` - Cliff data

### Test Results

- **15/16 test maps** parse successfully
- 1 map (Daow6.2.w3x) fails due to PKWARE DCL compression in MPQ
- Map sizes range from 257x257 to 481x481 tilepoints
- Height ranges properly decoded (e.g., -384 to +1529 world units)
- Water, blight, and ramp detection working

### Files Created

- `src/parsers/w3e.lua` - Main terrain parser
- `src/tests/test_w3e.lua` - Test suite

# war3map.w3e - Terrain Format Specification

The war3map.w3e file contains terrain data including height maps, ground textures,
cliff information, and water levels. This is the most complex Phase 1 binary format.

---

## Overview

WC3 terrain is based on a tilepoint grid:
- Map is divided into square "tiles" (128 world units each)
- Each tile has 4 corners called "tilepoints"
- A 256x256 tile map has 257x257 tilepoints
- Each tilepoint stores: height, texture, water level, flags

---

## Data Types

| Type | Size | Description |
|------|------|-------------|
| char(n) | n bytes | Fixed-length ASCII string |
| int32 | 4 bytes | Little-endian signed integer |
| uint32 | 4 bytes | Little-endian unsigned integer |
| int16 | 2 bytes | Little-endian signed short |
| uint16 | 2 bytes | Little-endian unsigned short |
| uint8 | 1 byte | Unsigned byte |

---

## File Structure

```
┌─────────────────────────────────────┐
│            Header                   │  Variable size
├─────────────────────────────────────┤
│       Ground Tileset IDs            │  4 bytes each
├─────────────────────────────────────┤
│        Cliff Tileset IDs            │  4 bytes each
├─────────────────────────────────────┤
│                                     │
│         Tilepoint Array             │  7 bytes each
│        (Width+1) × (Height+1)       │
│                                     │
└─────────────────────────────────────┘
```

---

## Header

| Offset | Type | Field | Description |
|--------|------|-------|-------------|
| 0x00 | char(4) | Magic | `"W3E!"` (57 33 45 21) |
| 0x04 | int32 | Version | Format version (11 for TFT) |
| 0x08 | char | MainTileset | Primary tileset character |
| 0x09 | int32 | CustomTileset | 1 = custom combination, 0 = standard |
| 0x0D | int32 | GroundTilesetCount | Number of ground textures |
| var | char(4)[] | GroundTilesets | Array of 4-char texture IDs |
| var | int32 | CliffTilesetCount | Number of cliff types |
| var | char(4)[] | CliffTilesets | Array of 4-char cliff IDs |
| var | int32 | MapWidth | Width + 1 (tilepoint count) |
| var | int32 | MapHeight | Height + 1 (tilepoint count) |
| var | float32 | CenterOffsetX | World coordinate X offset |
| var | float32 | CenterOffsetY | World coordinate Y offset |

### Tileset Characters

| Char | Tileset |
|------|---------|
| A | Ashenvale |
| B | Barrens |
| C | Felwood |
| D | Dungeon |
| F | Lordaeron Fall |
| G | Underground |
| I | Icecrown |
| J | Dalaran Ruins |
| K | Black Citadel |
| L | Lordaeron Summer |
| N | Northrend |
| O | Outland |
| Q | Village Fall |
| V | Village |
| W | Lordaeron Winter |
| X | Dalaran |
| Y | Cityscape |
| Z | Sunken Ruins |

### Ground Tileset IDs

4-character codes identifying ground textures. Examples:

| ID | Description |
|----|-------------|
| Ldrt | Lordaeron Summer Dirt |
| Lgrs | Lordaeron Summer Grass |
| Lgrd | Lordaeron Summer Grass Dark |
| Lrok | Lordaeron Summer Rock |
| Adrt | Ashenvale Dirt |
| Agrs | Ashenvale Grass |

Reference: `TerrainArt\Terrain.slk` in WC3 data files.

### Cliff Tileset IDs

4-character codes for cliff models. Examples:

| ID | Description |
|----|-------------|
| CLdi | Lordaeron Cliff Dirt |
| CLgr | Lordaeron Cliff Grass |
| ADdi | Ashenvale Cliff Dirt |

Reference: `TerrainArt\CliffTypes.slk` in WC3 data files.

---

## Tilepoint Data

Each tilepoint is 7 bytes, packed with bit fields.

### Tilepoint Structure (7 bytes)

| Bytes | Bits | Field | Description |
|-------|------|-------|-------------|
| 0-1 | 16 | GroundHeight | Terrain elevation (int16) |
| 2-3 | 14 | WaterLevel | Water surface height |
| 2-3 | 1 | BoundaryFlag1 | Part of boundary flags |
| 2-3 | 1 | BoundaryFlag2 | Part of boundary flags |
| 4 | 4 (low) | Flags | Terrain flags |
| 4 | 4 (high) | GroundTexture | Index into ground tileset |
| 5 | 5 (low) | TextureDetails | Variation/details |
| 5 | 3 (high) | CliffVariation | Cliff model variation (0-7) |
| 6 | 4 (low) | CliffTexture | Index into cliff tileset |
| 6 | 4 (high) | LayerHeight | Cliff layer height (0-15) |

### Bit Layout Diagram

```
Byte 0-1: GroundHeight (int16, little-endian)
┌─────────────────────────────────┐
│  Height value (-8192 to +8191) │
└─────────────────────────────────┘

Byte 2-3: Water + Boundary (int16, little-endian)
┌──┬──┬───────────────────────────┐
│B2│B1│     Water Level (14 bits) │
└──┴──┴───────────────────────────┘
 15 14   13                      0

Byte 4: Flags + Ground Texture
┌───────────┬───────────┐
│  GroundTx │   Flags   │
│  (4 bits) │  (4 bits) │
└───────────┴───────────┘
   7      4   3       0

Byte 5: Details + Cliff Variation
┌───────┬─────────────┐
│CliffV │  Details    │
│(3 bit)│  (5 bits)   │
└───────┴─────────────┘
  7   5   4         0

Byte 6: Cliff Texture + Layer Height
┌───────────┬───────────┐
│LayerHeight│ CliffTex  │
│ (4 bits)  │ (4 bits)  │
└───────────┴───────────┘
   7      4   3       0
```

---

## Height Calculation

### Ground Height

Raw height values are 16-bit signed integers.

To convert to world coordinates:
```lua
world_height = (raw_height - 8192 + offset_from_water) / 4
```

The base offset (8192 = 0x2000) represents approximately middle of the valid range.

### Water Level

14-bit value with similar scaling to ground height.
Water is rendered where `water_level > ground_height`.

### Layer Height

Used for cliff levels. Each increment represents one "cliff layer":
- Layer 0 = base terrain
- Layer 1 = one cliff up
- Layer 2 = two cliffs up
- etc.

Cliff models are placed between adjacent tilepoints with different layer heights.

---

## Terrain Flags

| Flag | Value | Description |
|------|-------|-------------|
| RAMP | 0x0010 | Tilepoint is part of a ramp |
| BLIGHT | 0x0020 | Undead blight overlay |
| WATER | 0x0040 | Water is present |
| BOUNDARY | 0x4000 | Map boundary (unplayable area) |

Note: Boundary flag is stored in water level bytes (bit 14-15).

---

## Coordinate Systems

### Tile Coordinates

Integer grid positions:
- (0, 0) at bottom-left corner of map
- (width-1, height-1) at top-right

### World Coordinates

Floating-point positions used in game:
- Each tile = 128 world units
- Origin (0, 0) at map center

Conversion:
```lua
world_x = (tile_x - width/2) * 128 + center_offset_x
world_y = (tile_y - height/2) * 128 + center_offset_y
```

Or using the stored offsets:
```lua
world_x = tile_x * 128 + center_offset_x
world_y = tile_y * 128 + center_offset_y
```

Where `center_offset_x = -(width-1) * 128 / 2`

---

## Cliff Model Selection

Cliff models are generated based on relative layer heights of adjacent tilepoints.

### Model Naming

Format: `Cliffs<ABCD><variation>.mdx`

Where A, B, C, D are characters representing height differences:
- Calculate height diff between adjacent tilepoints
- Convert to character: `'A' + diff`

### Example

Tilepoints with layer heights:
```
[1] [1]
[0] [0]
```

Bottom-left tilepoint sees:
- Above: diff = 1 → 'B'
- Right: diff = 0 → 'A'
- etc.

Result might be: `CliffsBAAAx.mdx`

---

## Texture Variations

### Ground Texture Details

5-bit texture detail field controls tile appearance:

| Range | Usage |
|-------|-------|
| 0-15 | Standard variation index |
| 16-31 | Extended variation (for full tiles) |

Extended textures have additional variations to reduce visual repetition
in large areas of the same texture.

### Cliff Variation

3-bit field (0-7) selects between cliff model variants.
Only values 0, 1, 2 typically have models defined.

---

## Parsing Code

```lua
-- {{{ parse_w3e
local function parse_w3e(data)
    local pos = 1
    local terrain = {}

    -- Header
    local magic = data:sub(pos, pos + 3); pos = pos + 4
    assert(magic == "W3E!", "Invalid w3e magic")

    terrain.version = string.unpack("<i4", data, pos); pos = pos + 4
    terrain.tileset = data:sub(pos, pos); pos = pos + 1
    terrain.custom_tileset = string.unpack("<i4", data, pos); pos = pos + 4

    -- Ground tilesets
    local ground_count = string.unpack("<i4", data, pos); pos = pos + 4
    terrain.ground_tilesets = {}
    for i = 1, ground_count do
        terrain.ground_tilesets[i] = data:sub(pos, pos + 3); pos = pos + 4
    end

    -- Cliff tilesets
    local cliff_count = string.unpack("<i4", data, pos); pos = pos + 4
    terrain.cliff_tilesets = {}
    for i = 1, cliff_count do
        terrain.cliff_tilesets[i] = data:sub(pos, pos + 3); pos = pos + 4
    end

    -- Dimensions
    terrain.width = string.unpack("<i4", data, pos); pos = pos + 4
    terrain.height = string.unpack("<i4", data, pos); pos = pos + 4
    terrain.offset_x = string.unpack("<f", data, pos); pos = pos + 4
    terrain.offset_y = string.unpack("<f", data, pos); pos = pos + 4

    -- Tilepoints
    terrain.tilepoints = {}
    for y = 0, terrain.height - 1 do
        terrain.tilepoints[y] = {}
        for x = 0, terrain.width - 1 do
            terrain.tilepoints[y][x] = parse_tilepoint(data, pos)
            pos = pos + 7
        end
    end

    return terrain
end
-- }}}

-- {{{ parse_tilepoint
local function parse_tilepoint(data, pos)
    local tp = {}

    -- Bytes 0-1: Ground height
    tp.ground_height = string.unpack("<i2", data, pos)

    -- Bytes 2-3: Water level + boundary
    local water_raw = string.unpack("<I2", data, pos + 2)
    tp.water_level = water_raw & 0x3FFF
    tp.boundary = (water_raw & 0xC000) ~= 0

    -- Byte 4: Flags + ground texture
    local byte4 = data:byte(pos + 4)
    tp.flags = byte4 & 0x0F
    tp.ground_texture = (byte4 >> 4) & 0x0F

    -- Byte 5: Details + cliff variation
    local byte5 = data:byte(pos + 5)
    tp.texture_details = byte5 & 0x1F
    tp.cliff_variation = (byte5 >> 5) & 0x07

    -- Byte 6: Cliff texture + layer height
    local byte6 = data:byte(pos + 6)
    tp.cliff_texture = byte6 & 0x0F
    tp.layer_height = (byte6 >> 4) & 0x0F

    return tp
end
-- }}}
```

---

## Memory/Performance Notes

### Size Calculation

For a 256×256 map:
- Tilepoints: 257 × 257 = 66,049
- Size: 66,049 × 7 = 462,343 bytes (~452 KB)

### Access Patterns

Terrain data is typically accessed:
1. Linearly during initial load
2. Randomly during gameplay (position lookups)
3. In local clusters for rendering

Consider storing as flat array with index calculation for cache efficiency.

---

## References

- [war3map.w3e Terrain - HiveWE Wiki](https://github.com/stijnherfst/HiveWE/wiki/war3map.w3e-Terrain)
- [WC3MapSpecification - GitHub](https://github.com/ChiefOfGxBxL/WC3MapSpecification)
- [W3X Files Format - 867380699.github.io](https://867380699.github.io/blog/2019/05/09/W3X_Files_Format)
- [WC3MapTranslator - GitHub](https://github.com/ChiefOfGxBxL/WC3MapTranslator)

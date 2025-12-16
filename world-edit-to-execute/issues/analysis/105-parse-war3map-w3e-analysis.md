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

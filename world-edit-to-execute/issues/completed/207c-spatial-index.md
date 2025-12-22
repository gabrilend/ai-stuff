# Issue 207c: Spatial Index

**Phase:** 2 - Data Model
**Type:** Feature
**Priority:** Medium
**Dependencies:** None (standalone module)
**Parent Issue:** 207-build-object-registry-system

---

## Current Behavior

No spatial indexing for game objects. Finding objects near a position
requires iterating all objects and checking distances.

---

## Intended Behavior

Implement a grid-based SpatialIndex class for efficient spatial queries.
This is a standalone module that can be used by the registry (207d).

```lua
local SpatialIndex = require("registry.spatial")

local spatial = SpatialIndex.new(512)  -- 512 unit cell size

-- Insert objects
spatial:insert(unit1)
spatial:insert(unit2)
spatial:insert(doodad1)

-- Query radius (circular area)
local nearby = spatial:query_radius(1000, 1000, 500)

-- Query rectangle (bounding box)
local in_box = spatial:query_rect(0, 0, 2048, 2048)
```

---

## Suggested Implementation Steps

1. **Create spatial module**
   ```
   src/registry/
   └── spatial.lua   (SpatialIndex class)
   ```

2. **Implement SpatialIndex.new(cell_size)**
   - cell_size: size of each grid cell (default 512)
   - cells: hash table mapping "cx,cy" to object lists
   - Return metatable-enabled object

3. **Implement cell key calculation**
   ```lua
   function SpatialIndex:_cell_key(x, y)
       local cx = math.floor(x / self.cell_size)
       local cy = math.floor(y / self.cell_size)
       return cx .. "," .. cy
   end
   ```

4. **Implement insert(object)**
   - Expects object.position.x and object.position.y
   - Calculate cell key
   - Create cell if doesn't exist
   - Append object to cell

5. **Implement query_radius(x, y, radius)**
   - Calculate bounding cells that might contain objects
   - Iterate all objects in those cells
   - Check actual distance (squared comparison for performance)
   - Return matching objects

6. **Implement query_rect(left, bottom, right, top)**
   - Calculate covered cells
   - Iterate all objects in those cells
   - Check if object position is within rect bounds
   - Return matching objects

7. **Add unit tests**
   - Test insertion
   - Test radius query accuracy
   - Test rectangle query accuracy
   - Test edge cases (empty index, object at origin, large radius)

---

## Technical Notes

### Grid-Based vs Quadtree

A simple grid is chosen for initial implementation:
- O(1) insertion
- O(k) query where k = objects in checked cells
- Simple to implement and debug
- Sufficient for maps up to ~100k objects

Quadtree or R-tree can be added later if performance becomes an issue.

### Cell Size Choice

Default 512 game units balances:
- Query efficiency (fewer cells to check)
- Memory usage (fewer empty cells)
- WC3 map typical density

WC3 maps typically range from 64x64 to 480x480 tiles, where each tile is
128 game units. So maps range ~8k to ~60k units across.

### Object Interface

Objects must have `position.x` and `position.y` fields. This matches the
structure from all our parsers (doodad, unit, etc.).

---

## Related Documents

- issues/207d-spatial-integration.md (uses this module)
- issues/207-build-object-registry-system.md (parent)

---

## Acceptance Criteria

- [x] SpatialIndex.new() creates empty index
- [x] insert() adds objects to correct cells
- [x] query_radius returns objects within radius
- [x] query_radius excludes objects outside radius
- [x] query_rect returns objects within bounds
- [x] query_rect excludes objects outside bounds
- [x] Works with objects at negative coordinates
- [x] Works with objects at (0, 0)
- [x] Empty queries return empty tables
- [x] Unit tests with known positions and distances

---

## Notes

This module is intentionally standalone with no registry dependencies.
It can be tested and used independently. The registry integration comes
in 207d.

---

## Implementation Notes

*Completed 2025-12-21*

### Changes Made

1. **Created src/registry/spatial.lua:**
   - SpatialIndex class with configurable cell_size (default 512)
   - Grid-based storage using "cx,cy" string keys
   - Object count tracking

2. **Core methods:**
   - `new(cell_size)` - create index with specified cell size
   - `insert(object)` - add object to appropriate cell
   - `remove(object)` - remove object from index
   - `query_radius(x, y, radius)` - circular area query
   - `query_rect(left, bottom, right, top)` - rectangular area query
   - `query_point(x, y)` - get all objects in same cell
   - `clear()` - remove all objects

3. **Utility methods:**
   - `get_count()` - total indexed objects
   - `get_cell_count()` - number of non-empty cells
   - `debug_info()` - statistics (avg/min/max per cell)

4. **Error handling:**
   - Validates object.position.x and object.position.y on insert

5. **Created src/tests/test_spatial.lua:**
   - 18 test groups covering all functionality
   - Tests for origin, negative coords, cell boundaries
   - Tests for diagonal distance calculations
   - Tests for empty queries and error handling

### Test Results

75/75 tests pass

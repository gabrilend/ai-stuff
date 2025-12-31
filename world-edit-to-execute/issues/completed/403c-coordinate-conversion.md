# Issue 403c: Coordinate Conversion

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** Medium
**Parent:** 403-implement-basic-pathfinding.md
**Dependencies:** 403a-build-pathing-grid

---

## Current Behavior

No coordinate conversion exists between world space (game units used by units, triggers, and effects) and grid space (tile indices used by pathfinding). Units have world positions but pathfinding operates on discrete grid cells.

---

## Intended Behavior

Coordinate conversion functions that:
- Convert world coordinates to grid tile indices
- Convert grid tile indices back to world coordinates (tile center)
- Handle terrain offset and tile size
- Clamp or reject out-of-bounds coordinates appropriately

**API:**
```lua
-- World to grid (returns integer tile indices)
local grid_x, grid_y = pathfinding.world_to_grid(world_x, world_y)

-- Grid to world (returns tile center in world units)
local world_x, world_y = pathfinding.grid_to_world(grid_x, grid_y)

-- Check if world position is within grid bounds
local in_bounds = pathfinding.is_in_bounds(world_x, world_y)
```

**WC3 coordinate system:**
- World origin (0, 0) is typically at map center
- Terrain grid origin is at bottom-left corner
- Standard tile size is 128 world units
- Standard map sizes: 64x64, 96x96, 128x128, 160x160, etc.

---

## Suggested Implementation Steps

1. **Add coordinate conversion to pathfinding module**
   ```lua
   -- src/runtime/pathfinding/init.lua (or coords.lua)
   local coords = {}
   ```

2. **Store grid metadata for conversions**
   ```lua
   -- {{{ Grid reference
   -- The pathfinding module needs to know grid dimensions
   local active_grid = nil

   function coords.set_grid(grid)
       active_grid = grid
   end

   function coords.get_grid()
       return active_grid
   end
   -- }}}
   ```

3. **Implement world-to-grid conversion**
   ```lua
   -- {{{ coords.world_to_grid
   -- Converts world coordinates to grid tile indices.
   -- Returns integer tile indices, or nil if out of bounds.
   function coords.world_to_grid(world_x, world_y, grid)
       grid = grid or active_grid
       if not grid then
           error("No grid set for coordinate conversion")
       end

       -- Calculate tile indices
       -- World position relative to grid origin, divided by tile size
       local tile_x = math.floor((world_x - grid.offset_x) / grid.tile_size)
       local tile_y = math.floor((world_y - grid.offset_y) / grid.tile_size)

       -- Bounds check
       if tile_x < 0 or tile_x >= grid.width then
           return nil, nil, "X coordinate out of bounds"
       end
       if tile_y < 0 or tile_y >= grid.height then
           return nil, nil, "Y coordinate out of bounds"
       end

       return tile_x, tile_y
   end
   -- }}}
   ```

4. **Implement grid-to-world conversion**
   ```lua
   -- {{{ coords.grid_to_world
   -- Converts grid tile indices to world coordinates.
   -- Returns the center of the tile in world units.
   function coords.grid_to_world(grid_x, grid_y, grid)
       grid = grid or active_grid
       if not grid then
           error("No grid set for coordinate conversion")
       end

       -- Calculate world position at tile center
       local half_tile = grid.tile_size / 2
       local world_x = grid.offset_x + (grid_x * grid.tile_size) + half_tile
       local world_y = grid.offset_y + (grid_y * grid.tile_size) + half_tile

       return world_x, world_y
   end
   -- }}}
   ```

5. **Implement bounds checking**
   ```lua
   -- {{{ coords.is_in_bounds
   -- Checks if a world position is within the grid bounds.
   function coords.is_in_bounds(world_x, world_y, grid)
       grid = grid or active_grid
       if not grid then
           return false
       end

       local min_x = grid.offset_x
       local max_x = grid.offset_x + (grid.width * grid.tile_size)
       local min_y = grid.offset_y
       local max_y = grid.offset_y + (grid.height * grid.tile_size)

       return world_x >= min_x and world_x < max_x and
              world_y >= min_y and world_y < max_y
   end
   -- }}}
   ```

6. **Implement clamped conversion**
   ```lua
   -- {{{ coords.world_to_grid_clamped
   -- Like world_to_grid but clamps to grid edges instead of returning nil.
   function coords.world_to_grid_clamped(world_x, world_y, grid)
       grid = grid or active_grid
       if not grid then
           error("No grid set for coordinate conversion")
       end

       local tile_x = math.floor((world_x - grid.offset_x) / grid.tile_size)
       local tile_y = math.floor((world_y - grid.offset_y) / grid.tile_size)

       -- Clamp to valid range
       tile_x = math.max(0, math.min(grid.width - 1, tile_x))
       tile_y = math.max(0, math.min(grid.height - 1, tile_y))

       return tile_x, tile_y
   end
   -- }}}
   ```

7. **Add path conversion helper**
   ```lua
   -- {{{ coords.path_to_world
   -- Converts a path of grid coordinates to world coordinates.
   function coords.path_to_world(path, grid)
       grid = grid or active_grid
       if not path then return nil end

       local world_path = {}
       for i, point in ipairs(path) do
           local wx, wy = coords.grid_to_world(point.x, point.y, grid)
           world_path[i] = { x = wx, y = wy }
       end

       return world_path
   end
   -- }}}
   ```

8. **Add distance calculation helper**
   ```lua
   -- {{{ coords.world_distance
   -- Calculates distance between two world positions.
   function coords.world_distance(x1, y1, x2, y2)
       local dx = x2 - x1
       local dy = y2 - y1
       return math.sqrt(dx * dx + dy * dy)
   end
   -- }}}

   -- {{{ coords.grid_distance
   -- Calculates Manhattan distance between two grid positions.
   function coords.grid_distance(x1, y1, x2, y2)
       return math.abs(x2 - x1) + math.abs(y2 - y1)
   end
   -- }}}
   ```

9. **Export from main pathfinding module**
   ```lua
   -- In src/runtime/pathfinding/init.lua
   local coords = require("runtime.pathfinding.coords")

   -- Re-export coordinate functions
   pathfinding.world_to_grid = coords.world_to_grid
   pathfinding.grid_to_world = coords.grid_to_world
   pathfinding.is_in_bounds = coords.is_in_bounds
   pathfinding.world_to_grid_clamped = coords.world_to_grid_clamped
   pathfinding.path_to_world = coords.path_to_world
   pathfinding.set_grid = coords.set_grid
   ```

10. **Create unit tests**
    ```
    src/tests/test_pathing_coords.lua
    ```

11. **Test scenarios**
    - Round-trip conversion (world -> grid -> world) preserves tile center
    - Out-of-bounds detection works correctly
    - Clamped conversion returns edge tiles
    - Negative world coordinates handled correctly
    - Path conversion works for multi-point paths

---

## Related Documents

- issues/403-implement-basic-pathfinding.md (parent issue)
- issues/403a-build-pathing-grid.md (provides grid with dimensions)
- issues/403d-movement-type-support.md (uses coordinate conversion)
- issues/404-create-unit-movement-system.md (uses world coordinates)

---

## Acceptance Criteria

- [x] `coords.world_to_grid()` correctly converts world to tile indices
- [x] `coords.grid_to_world()` returns tile center in world units
- [x] `coords.is_in_bounds()` correctly validates positions
- [x] `coords.world_to_grid_clamped()` clamps to valid tile range
- [x] Handles negative world coordinates (typical for centered maps)
- [x] Respects grid offset and tile_size properties
- [x] Round-trip conversion preserves tile (world -> grid -> world returns tile center)
- [x] `coords.path_to_world()` converts path arrays
- [x] Unit tests cover edge cases and typical scenarios

---

## Notes

WC3 maps are typically centered at world origin (0, 0), meaning:
- A 128x128 tile map with 128-unit tiles spans -8192 to +8192 in both X and Y
- The grid offset would be (-8192, -8192)

The conversion functions use `math.floor()` for world-to-grid, meaning a world position at the exact boundary between tiles belongs to the lower-indexed tile. This is consistent with typical tile-based systems.

When converting paths back to world coordinates, returning the tile center is the standard approach. This gives units a natural "stepping" movement through tile centers rather than hugging edges.

---

## Implementation Notes

### Files Created
- `src/runtime/pathfinding/coords.lua` (~270 lines) - Coordinate conversion module
- `src/tests/test_pathing_coords.lua` (~300 lines) - 99 tests

### Key Implementation Details

1. **Active Grid Pattern**: Module maintains an active grid reference that can be set once
   and used for all subsequent conversions, or a grid can be passed explicitly to each function.

2. **World-to-Grid Conversion**: Uses `math.floor((world - offset) / tile_size)` to convert
   world coordinates to tile indices. Returns nil with error message for out-of-bounds.

3. **Grid-to-World Conversion**: Returns tile center by adding `half_tile` to corner position.
   Also provides `grid_to_world_corner()` for tile boundary placement.

4. **Clamped Conversion**: `world_to_grid_clamped()` clamps to valid range [0, size-1] instead
   of returning nil, useful for finding nearest valid tile to out-of-bounds positions.

5. **Path Conversion**: `path_to_world()` and `path_to_grid()` convert entire waypoint arrays.
   `path_to_grid()` fails fast with error message if any waypoint is out of bounds.

6. **Distance Functions**:
   - `world_distance()` / `world_distance_squared()` for Euclidean distance
   - `grid_distance_manhattan()` / `grid_distance_chebyshev()` for tile-based distance
   - `tiles_to_world_distance()` / `world_to_tiles_distance()` for unit conversion

### Test Coverage
- 99 tests covering: active grid management, world-to-grid conversion, grid-to-world conversion,
  round-trip preservation, centered grids with negative offsets, clamped conversion, bounds checking,
  path conversion, distance calculations, error handling, pathfinding module integration

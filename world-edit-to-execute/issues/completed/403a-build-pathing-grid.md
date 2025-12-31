# Issue 403a: Build Pathing Grid

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** High
**Parent:** 403-implement-basic-pathfinding.md
**Dependencies:** 105-parse-war3map-w3e

---

## Current Behavior

No pathing grid exists. The w3e terrain parser extracts tile data (ground height, cliff levels, water, terrain types), but this data is not converted into a format suitable for pathfinding algorithms.

---

## Intended Behavior

A module that converts parsed w3e terrain data into a pathing grid data structure. Each cell in the grid contains pathability information:

**Grid cell properties:**
- `walkable` - Ground units can traverse this tile
- `flyable` - Air units can traverse (always true for normal tiles)
- `buildable` - Buildings can be placed on this tile
- `water` - Tile contains water
- `water_depth` - Depth of water (affects wading vs swimming)
- `cliff_level` - Cliff height level for ramp detection

**Output structure:**
```lua
{
    width = 128,
    height = 128,
    tile_size = 128,          -- World units per tile
    offset_x = -8192,         -- World coordinate of grid origin
    offset_y = -8192,
    cells = {
        [0] = {
            [0] = { walkable = true, flyable = true, buildable = true, cliff_level = 0 },
            [1] = { walkable = false, flyable = true, buildable = false, cliff_level = 1, water = true },
            -- ...
        },
        -- ...
    },
}
```

---

## Suggested Implementation Steps

1. **Create the pathfinding module structure**
   ```
   src/runtime/pathfinding/
   ├── init.lua       (main API, exports)
   └── grid.lua       (this issue - grid construction)
   ```

2. **Define grid cell structure**
   ```lua
   -- src/runtime/pathfinding/grid.lua
   local grid = {}

   -- {{{ Cell defaults
   local function make_cell()
       return {
           walkable = true,
           flyable = true,
           buildable = true,
           water = false,
           water_depth = 0,
           cliff_level = 0,
       }
   end
   -- }}}
   ```

3. **Implement terrain-to-walkability logic**
   ```lua
   -- {{{ is_walkable
   -- Determines if a tile is walkable based on w3e tile data
   local WADE_DEPTH = 64  -- Water depth units can wade through

   local function is_walkable(tile, adjacent_tiles)
       -- Deep water blocks ground units
       if tile.water and tile.water_level > WADE_DEPTH then
           return false
       end

       -- Cliff edges are impassable (different cliff levels)
       -- Check if any adjacent tile has a different cliff level without a ramp
       for _, adj in ipairs(adjacent_tiles) do
           if adj.cliff_level ~= tile.cliff_level then
               -- Check for ramp flag - if no ramp, it's a cliff edge
               if not tile.is_ramp and not adj.is_ramp then
                   return false
               end
           end
       end

       -- Check terrain flags (blighted ground is still walkable)
       if tile.flags and tile.flags.unbuildable then
           -- Unbuildable doesn't mean unwalkable in WC3
       end

       return true
   end
   -- }}}
   ```

4. **Implement buildability check**
   ```lua
   -- {{{ is_buildable
   local function is_buildable(tile)
       -- Water is not buildable
       if tile.water then
           return false
       end

       -- Check terrain flags
       if tile.flags and tile.flags.unbuildable then
           return false
       end

       -- Blighted terrain may have restrictions
       if tile.flags and tile.flags.blighted then
           -- Undead can build, others cannot - handle in game logic
       end

       return true
   end
   -- }}}
   ```

5. **Build the complete grid from terrain**
   ```lua
   -- {{{ grid.build_from_terrain
   function grid.build_from_terrain(terrain)
       local result = {
           width = terrain.width,
           height = terrain.height,
           tile_size = terrain.tile_size or 128,
           offset_x = terrain.offset_x or -(terrain.width * 64),
           offset_y = terrain.offset_y or -(terrain.height * 64),
           cells = {},
       }

       -- First pass: create all cells with basic properties
       for y = 0, terrain.height - 1 do
           result.cells[y] = {}
           for x = 0, terrain.width - 1 do
               local tile = terrain:get_tile(x, y)
               local cell = make_cell()

               cell.cliff_level = tile.cliff_level or 0
               cell.water = tile.water or false
               cell.water_depth = tile.water_level or 0
               cell.flyable = true  -- Air units can go anywhere

               result.cells[y][x] = cell
           end
       end

       -- Second pass: determine walkability (needs adjacent tiles)
       for y = 0, terrain.height - 1 do
           for x = 0, terrain.width - 1 do
               local tile = terrain:get_tile(x, y)
               local adjacent = get_adjacent_tiles(terrain, x, y)

               result.cells[y][x].walkable = is_walkable(tile, adjacent)
               result.cells[y][x].buildable = is_buildable(tile)
           end
       end

       return result
   end
   -- }}}
   ```

6. **Implement adjacent tile helper**
   ```lua
   -- {{{ get_adjacent_tiles
   local function get_adjacent_tiles(terrain, x, y)
       local adjacent = {}
       local dirs = { {0, -1}, {0, 1}, {-1, 0}, {1, 0} }  -- N, S, W, E

       for _, dir in ipairs(dirs) do
           local nx, ny = x + dir[1], y + dir[2]
           if nx >= 0 and nx < terrain.width and ny >= 0 and ny < terrain.height then
               adjacent[#adjacent + 1] = terrain:get_tile(nx, ny)
           end
       end

       return adjacent
   end
   -- }}}
   ```

7. **Add grid cell accessor**
   ```lua
   -- {{{ grid.get_cell
   function grid.get_cell(pathing_grid, x, y)
       if x < 0 or x >= pathing_grid.width then return nil end
       if y < 0 or y >= pathing_grid.height then return nil end
       return pathing_grid.cells[y] and pathing_grid.cells[y][x]
   end
   -- }}}
   ```

8. **Add grid caching support**
   ```lua
   -- {{{ grid.cache
   -- Cache for rebuilt grids (terrain rarely changes)
   local cached_grid = nil
   local cached_terrain_hash = nil

   function grid.build_cached(terrain)
       local hash = terrain:get_hash()  -- Terrain should provide a hash
       if cached_grid and cached_terrain_hash == hash then
           return cached_grid
       end

       cached_grid = grid.build_from_terrain(terrain)
       cached_terrain_hash = hash
       return cached_grid
   end

   function grid.invalidate_cache()
       cached_grid = nil
       cached_terrain_hash = nil
   end
   -- }}}
   ```

9. **Create unit tests**
   ```
   src/tests/test_pathing_grid.lua
   ```

10. **Test with mock terrain data**
    - Create synthetic terrain with cliffs, water, and flat areas
    - Verify walkability is correctly determined
    - Verify cliff edges are marked impassable
    - Verify deep water is marked impassable

---

## Related Documents

- issues/403-implement-basic-pathfinding.md (parent issue)
- issues/403b-implement-astar-algorithm.md (uses this grid)
- issues/403c-coordinate-conversion.md (uses grid dimensions)
- issues/105-parse-war3map-w3e.md (terrain parser)
- src/parsers/w3e.lua (terrain data source)

---

## Acceptance Criteria

- [x] `src/runtime/pathfinding/grid.lua` exists
- [x] `grid.build_from_terrain()` creates pathing grid from w3e data
- [x] Each cell has walkable, flyable, buildable, water, cliff_level properties
- [x] Deep water marked as not walkable
- [x] Cliff edges (different cliff levels) marked as not walkable
- [x] Grid dimensions and offset correctly extracted from terrain
- [x] `grid.get_cell()` provides safe accessor for grid cells
- [x] Grid caching implemented for performance
- [x] Unit tests pass with synthetic terrain data

---

## Notes

The grid construction happens once when the map loads and is cached. Only terrain-modifying abilities (like Raise/Lower Terrain in editor, or very rare in-game effects) would require rebuilding.

The walkability determination is simplified compared to WC3's actual system, which has separate pathing maps baked into the map file. For initial implementation, deriving from terrain data is sufficient.

Ramp detection may need refinement based on how the w3e parser exposes cliff transition data. WC3 uses specific tile configurations to indicate ramps.

---

## Implementation Notes

### Files Created
- `src/runtime/pathfinding/grid.lua` (~300 lines) - Pathing grid construction from terrain
- `src/runtime/pathfinding/init.lua` (~50 lines) - Module exports
- `src/tests/test_pathing_grid.lua` (~330 lines) - 93 tests

### Key Implementation Details

1. **Two-pass grid construction**: First pass extracts basic tile properties, second pass
   determines walkability using neighbor data (needed for cliff edge detection).

2. **Walkability rules**:
   - Deep water (> WADE_DEPTH = 64) blocks ground movement
   - Boundary tiles block all ground movement
   - Cliff edges block unless one side has a ramp (is_ramp flag)

3. **Cell properties per tile**:
   - walkable, flyable, buildable (booleans)
   - water, water_depth (water presence and depth)
   - cliff_level, is_ramp, is_blight (terrain flags)

4. **Grid caching**: `build_cached()` returns same grid for same terrain object,
   avoiding rebuilding on every pathfinding query.

### Test Coverage
- 93 tests covering: construction, cell properties, accessors, water blocking,
  boundary blocking, cliff edges, ramps, blight, caching, statistics, errors


# Issue 405b: Spatial Hash Grid

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** Medium
**Parent:** 405-implement-basic-collision-detection.md
**Dependencies:** 405a-collision-primitives-and-shapes

---

## Current Behavior

After 405a, collision primitives exist but there is no spatial optimization. Checking all entity pairs for collision is O(n^2), which becomes slow with many entities.

---

## Intended Behavior

Implement a spatial hash grid for efficient broad-phase collision detection:
- Partition world space into fixed-size cells
- Store entity references in cells based on position
- Enable O(1) average-case lookup of nearby entities
- Handle entities near cell boundaries correctly

**API:**
```lua
-- Rebuild entire hash from scratch (simple approach)
spatial.update_all()

-- Update single entity's position in hash (optimization)
spatial.update_entity(entity, old_x, old_y, new_x, new_y)

-- Get all entities in a cell
spatial.get_cell(cell_x, cell_y) -> {entity, ...}

-- Get all entities potentially near a point
spatial.get_nearby(x, y, radius) -> {entity, ...}
```

---

## Suggested Implementation Steps

1. **Create spatial.lua module**
   ```
   src/runtime/collision/
   ├── init.lua
   ├── shapes.lua     (from 405a)
   └── spatial.lua    (this issue)
   ```

2. **Define spatial hash constants**
   ```lua
   -- src/runtime/collision/spatial.lua
   local spatial = {}

   -- Cell size in world units
   -- Larger = fewer cells, more entities per cell
   -- Smaller = more cells, fewer entities per cell
   -- Good default: 2-4x largest entity radius
   local CELL_SIZE = 256

   -- The spatial hash table
   -- Key: "cell_x,cell_y" string
   -- Value: array of entity IDs
   local hash = {}
   ```

3. **Implement cell coordinate conversion**
   ```lua
   -- {{{ world_to_cell
   -- Convert world coordinates to cell coordinates
   function spatial.world_to_cell(x, y)
       return math.floor(x / CELL_SIZE), math.floor(y / CELL_SIZE)
   end
   -- }}}

   -- {{{ cell_key
   -- Generate unique string key for a cell
   local function cell_key(cx, cy)
       return cx .. "," .. cy
   end
   -- }}}
   ```

4. **Implement cell operations**
   ```lua
   -- {{{ get_cell
   -- Get entities in a specific cell (returns empty table if none)
   function spatial.get_cell(cx, cy)
       return hash[cell_key(cx, cy)] or {}
   end
   -- }}}

   -- {{{ insert_into_cell
   -- Add entity to a cell
   local function insert_into_cell(cx, cy, entity)
       local key = cell_key(cx, cy)
       if not hash[key] then
           hash[key] = {}
       end
       hash[key][#hash[key] + 1] = entity
   end
   -- }}}

   -- {{{ remove_from_cell
   -- Remove entity from a cell
   local function remove_from_cell(cx, cy, entity)
       local key = cell_key(cx, cy)
       local cell = hash[key]
       if cell then
           for i, e in ipairs(cell) do
               if e == entity then
                   table.remove(cell, i)
                   return
               end
           end
       end
   end
   -- }}}
   ```

5. **Handle entities overlapping multiple cells**
   ```lua
   -- {{{ get_occupied_cells
   -- Get all cells an entity occupies based on its collision bounds
   -- Entities near cell boundaries may occupy 2-4 cells
   function spatial.get_occupied_cells(x, y, radius)
       local cells = {}

       -- Calculate bounds
       local min_cx = math.floor((x - radius) / CELL_SIZE)
       local max_cx = math.floor((x + radius) / CELL_SIZE)
       local min_cy = math.floor((y - radius) / CELL_SIZE)
       local max_cy = math.floor((y + radius) / CELL_SIZE)

       -- Collect all cells the entity touches
       for cx = min_cx, max_cx do
           for cy = min_cy, max_cy do
               cells[#cells + 1] = {cx, cy}
           end
       end

       return cells
   end
   -- }}}
   ```

6. **Implement full hash rebuild**
   ```lua
   -- {{{ update_all
   -- Rebuild entire spatial hash from scratch
   -- Simple approach: clear and re-insert all entities
   -- Called once per frame before collision queries
   function spatial.update_all(ecs)
       -- Clear existing hash
       hash = {}

       -- Insert all entities with collision components
       for entity in ecs.query_single("collision") do
           local pos = ecs.get_component(entity, "position")
           local col = ecs.get_component(entity, "collision")

           if pos and col then
               -- Get radius (use max of radius, width/2, height/2)
               local radius = col.radius
               if col.shape == "rect" then
                   radius = math.max(col.width, col.height) / 2
               end

               -- Insert into all occupied cells
               local cells = spatial.get_occupied_cells(pos.x, pos.y, radius)
               for _, cell in ipairs(cells) do
                   insert_into_cell(cell[1], cell[2], entity)
               end
           end
       end
   end
   -- }}}
   ```

7. **Implement nearby entity query**
   ```lua
   -- {{{ get_nearby
   -- Get all entities potentially within radius of a point
   -- Returns candidates only - caller must do precise collision check
   function spatial.get_nearby(x, y, radius)
       local results = {}
       local seen = {}  -- Avoid duplicates from multi-cell entities

       -- Calculate cell range to check
       local min_cx = math.floor((x - radius) / CELL_SIZE)
       local max_cx = math.floor((x + radius) / CELL_SIZE)
       local min_cy = math.floor((y - radius) / CELL_SIZE)
       local max_cy = math.floor((y + radius) / CELL_SIZE)

       -- Collect entities from all relevant cells
       for cx = min_cx, max_cx do
           for cy = min_cy, max_cy do
               local cell = spatial.get_cell(cx, cy)
               for _, entity in ipairs(cell) do
                   if not seen[entity] then
                       seen[entity] = true
                       results[#results + 1] = entity
                   end
               end
           end
       end

       return results
   end
   -- }}}
   ```

8. **Expose cell size configuration**
   ```lua
   -- {{{ set_cell_size
   -- Configure cell size (call before update_all)
   function spatial.set_cell_size(size)
       CELL_SIZE = size
   end
   -- }}}

   function spatial.get_cell_size()
       return CELL_SIZE
   end
   ```

9. **Create unit tests**
   ```lua
   -- src/tests/test_spatial_hash.lua
   -- Test world_to_cell conversion
   -- Test entity insertion and retrieval
   -- Test get_nearby with various radii
   -- Test entities spanning multiple cells
   -- Test duplicate prevention in get_nearby
   ```

---

## Related Documents

- issues/405-implement-basic-collision-detection.md (parent issue)
- issues/405a-collision-primitives-and-shapes.md (prerequisite)
- issues/405c-collision-queries.md (next - uses spatial hash)
- src/runtime/collision/shapes.lua (collision bounds)

---

## Acceptance Criteria

- [x] `src/runtime/collision/spatial.lua` exists
- [x] `world_to_cell()` correctly converts coordinates
- [x] `get_cell()` returns entities in a cell
- [x] `insert_into_cell()` adds entities correctly
- [x] `get_occupied_cells()` handles entities spanning multiple cells
- [x] `update_all()` rebuilds hash from ECS query
- [x] `get_nearby()` returns nearby candidates without duplicates
- [x] Cell size is configurable
- [x] Unit tests pass for all spatial operations
- [x] Performance is O(1) average for nearby queries

---

## Notes

**Cell size tuning:**
- Too small: Many cells, overhead from checking multiple cells
- Too large: Many entities per cell, defeating the purpose
- Rule of thumb: 2-4x the largest entity collision radius

**Memory usage:**
- Hash only stores entity IDs, not copies of data
- Empty cells don't consume memory (sparse representation)
- Cells are garbage collected when cleared

**Thread safety:**
- Not a concern for single-threaded Lua
- If parallelizing, would need locks per cell

**Full rebuild vs incremental:**
- Full rebuild is simpler and sufficient for <1000 entities
- Incremental update would track old/new cell assignments
- Implement incremental only if profiling shows it's needed

**Coordinate system:**
- Works with any coordinate range (positive and negative)
- Cell keys use comma-separated string for simplicity
- Could optimize with integer packing if needed

---

## Implementation Notes

*Completed 2025-12-29*

### Files Created

- `src/runtime/collision/spatial.lua` (~230 lines) - Spatial hash grid
- `src/tests/test_spatial_hash.lua` (~380 lines) - Comprehensive test suite

### API Implemented

- `spatial.world_to_cell(x, y)` - Convert world coords to cell coords
- `spatial.cell_to_world(cx, cy)` - Convert cell coords to world center
- `spatial.get_cell(cx, cy)` - Get entities in a specific cell
- `spatial.get_occupied_cells(x, y, radius)` - Get all cells an entity spans
- `spatial.update_all(ecs)` - Rebuild hash from ECS entities
- `spatial.get_nearby(x, y, radius)` - Get candidates near a point
- `spatial.get_in_rect(x, y, w, h)` - Get candidates in a rectangle
- `spatial.get_at_point(x, y)` - Get entities in cell at point
- `spatial.set_cell_size(size)` / `get_cell_size()` - Configure cell size
- `spatial.clear()` - Clear all data
- `spatial.get_stats()` - Get debugging statistics
- `spatial.debug_dump()` - Dump hash contents for debugging

### Test Coverage

61 tests covering:
- Cell coordinate conversion (11 tests)
- Cell size configuration (6 tests)
- Get occupied cells (6 tests)
- ECS integration (4 tests)
- Get nearby queries (4 tests)
- Get in rect queries (4 tests)
- Get at point queries (3 tests)
- Edge cases (5 tests)
- Clear and stats (7 tests)
- Negative coordinates (3 tests)
- Multi-cell entities (5 tests)
- Debug dump (3 tests)

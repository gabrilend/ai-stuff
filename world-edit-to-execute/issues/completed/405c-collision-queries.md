# Issue 405c: Collision Queries

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** Medium
**Parent:** 405-implement-basic-collision-detection.md
**Dependencies:** 405a-collision-primitives-and-shapes, 405b-spatial-hash-grid

---

## Current Behavior

After 405a and 405b, collision primitives and spatial hash exist, but there is no unified query API. Game systems cannot easily find entities by spatial criteria with layer filtering.

---

## Intended Behavior

Implement a query API that combines spatial hash broad-phase with primitive narrow-phase collision detection:

```lua
-- Find all entities within radius, filtered by layer mask
collision.query_radius(x, y, radius, layer_mask) -> {entity, ...}

-- Find all entities within rectangle, filtered by layer mask
collision.query_rect(x, y, width, height, layer_mask) -> {entity, ...}

-- Find entity at exact point (for picking), filtered by layer mask
collision.query_point(x, y, layer_mask) -> entity or nil

-- Find all entities colliding with a given entity
collision.query_colliding(entity, layer_mask) -> {entity, ...}
```

All queries return entities sorted by distance (nearest first) when relevant.

---

## Suggested Implementation Steps

1. **Add query functions to collision init.lua**
   ```lua
   -- src/runtime/collision/init.lua
   local shapes = require("runtime.collision.shapes")
   local spatial = require("runtime.collision.spatial")
   local ecs = require("runtime.ecs")

   local collision = {}
   ```

2. **Implement query_radius**
   ```lua
   -- {{{ query_radius
   -- Find all entities whose collision shape overlaps a circle
   -- x, y: center of query circle
   -- radius: query radius
   -- layer_mask: optional table of layer strings to match (nil = all)
   -- Returns: array of entities, sorted by distance (nearest first)
   function collision.query_radius(x, y, radius, layer_mask)
       local results = {}

       -- Broad phase: get candidates from spatial hash
       local candidates = spatial.get_nearby(x, y, radius)

       for _, entity in ipairs(candidates) do
           local pos = ecs.get_component(entity, "position")
           local col = ecs.get_component(entity, "collision")

           if pos and col then
               -- Check layer filter
               if not layer_mask or collision.layer_matches_mask(col.layer, layer_mask) then
                   -- Narrow phase: precise collision check
                   local collides = false

                   if col.shape == "circle" then
                       collides = shapes.circles_collide(x, y, radius, pos.x, pos.y, col.radius)
                   elseif col.shape == "rect" then
                       collides = shapes.circle_rect_collide(x, y, radius, pos.x, pos.y, col.width, col.height)
                   elseif col.shape == "point" then
                       collides = shapes.point_in_circle(pos.x, pos.y, x, y, radius)
                   end

                   if collides then
                       local dx = pos.x - x
                       local dy = pos.y - y
                       local dist_sq = dx * dx + dy * dy
                       results[#results + 1] = {entity = entity, dist_sq = dist_sq}
                   end
               end
           end
       end

       -- Sort by distance
       table.sort(results, function(a, b) return a.dist_sq < b.dist_sq end)

       -- Extract just entities
       local entities = {}
       for i, r in ipairs(results) do
           entities[i] = r.entity
       end

       return entities
   end
   -- }}}
   ```

3. **Implement query_rect**
   ```lua
   -- {{{ query_rect
   -- Find all entities whose collision shape overlaps a rectangle
   -- x, y: center of query rectangle
   -- width, height: dimensions of query rectangle
   -- layer_mask: optional table of layer strings to match
   -- Returns: array of entities
   function collision.query_rect(x, y, width, height, layer_mask)
       local results = {}

       -- Calculate radius that encompasses the rectangle for spatial hash query
       local query_radius = math.sqrt(width * width + height * height) / 2

       -- Broad phase
       local candidates = spatial.get_nearby(x, y, query_radius)

       for _, entity in ipairs(candidates) do
           local pos = ecs.get_component(entity, "position")
           local col = ecs.get_component(entity, "collision")

           if pos and col then
               if not layer_mask or collision.layer_matches_mask(col.layer, layer_mask) then
                   local collides = false

                   if col.shape == "circle" then
                       collides = shapes.circle_rect_collide(pos.x, pos.y, col.radius, x, y, width, height)
                   elseif col.shape == "rect" then
                       collides = shapes.rects_collide(x, y, width, height, pos.x, pos.y, col.width, col.height)
                   elseif col.shape == "point" then
                       collides = shapes.point_in_rect(pos.x, pos.y, x, y, width, height)
                   end

                   if collides then
                       results[#results + 1] = entity
                   end
               end
           end
       end

       return results
   end
   -- }}}
   ```

4. **Implement query_point**
   ```lua
   -- {{{ query_point
   -- Find entity at an exact point (for mouse picking)
   -- Returns the topmost entity at the point, or nil
   -- Priority: units > buildings > triggers (configurable)
   function collision.query_point(x, y, layer_mask)
       local results = {}

       -- Use small radius for spatial hash query
       local candidates = spatial.get_nearby(x, y, 64)

       for _, entity in ipairs(candidates) do
           local pos = ecs.get_component(entity, "position")
           local col = ecs.get_component(entity, "collision")

           if pos and col then
               if not layer_mask or collision.layer_matches_mask(col.layer, layer_mask) then
                   local contains = false

                   if col.shape == "circle" then
                       contains = shapes.point_in_circle(x, y, pos.x, pos.y, col.radius)
                   elseif col.shape == "rect" then
                       contains = shapes.point_in_rect(x, y, pos.x, pos.y, col.width, col.height)
                   elseif col.shape == "point" then
                       -- Point-point: exact match only (or within small epsilon)
                       contains = (math.abs(pos.x - x) < 1 and math.abs(pos.y - y) < 1)
                   end

                   if contains then
                       results[#results + 1] = {entity = entity, layer = col.layer}
                   end
               end
           end
       end

       if #results == 0 then
           return nil
       end

       -- Sort by selection priority
       table.sort(results, function(a, b)
           return collision.get_layer_priority(a.layer) > collision.get_layer_priority(b.layer)
       end)

       return results[1].entity
   end
   -- }}}

   -- {{{ get_layer_priority
   -- Higher priority = selected first
   local LAYER_PRIORITY = {
       unit = 100,
       building = 50,
       trigger = 10,
       projectile = 5,
   }

   function collision.get_layer_priority(layer)
       return LAYER_PRIORITY[layer] or 0
   end
   -- }}}
   ```

5. **Implement query_colliding**
   ```lua
   -- {{{ query_colliding
   -- Find all entities colliding with a specific entity
   function collision.query_colliding(entity, layer_mask)
       local pos = ecs.get_component(entity, "position")
       local col = ecs.get_component(entity, "collision")

       if not pos or not col then
           return {}
       end

       local results = {}

       -- Determine query radius based on shape
       local radius = col.radius
       if col.shape == "rect" then
           radius = math.sqrt(col.width * col.width + col.height * col.height) / 2
       end

       local candidates = spatial.get_nearby(pos.x, pos.y, radius * 2)

       for _, other in ipairs(candidates) do
           if other ~= entity then
               local other_pos = ecs.get_component(other, "position")
               local other_col = ecs.get_component(other, "collision")

               if other_pos and other_col then
                   if not layer_mask or collision.layer_matches_mask(other_col.layer, layer_mask) then
                       if collision.shapes_collide(pos, col, other_pos, other_col) then
                           results[#results + 1] = other
                       end
                   end
               end
           end
       end

       return results
   end
   -- }}}
   ```

6. **Add update function to integrate with game loop**
   ```lua
   -- {{{ update
   -- Call once per frame before any queries
   function collision.update()
       spatial.update_all(ecs)
   end
   -- }}}
   ```

7. **Create unit tests**
   ```lua
   -- src/tests/test_collision_queries.lua
   -- Create test entities with known positions
   -- Test query_radius finds correct entities
   -- Test query_rect finds correct entities
   -- Test query_point returns topmost by priority
   -- Test query_colliding finds overlapping entities
   -- Test layer_mask filtering works correctly
   -- Test empty results when no matches
   ```

---

## Related Documents

- issues/405-implement-basic-collision-detection.md (parent issue)
- issues/405a-collision-primitives-and-shapes.md (primitives used)
- issues/405b-spatial-hash-grid.md (broad phase)
- issues/405d-movement-collision-integration.md (next - uses queries)
- issues/405e-projectile-and-picking.md (uses queries)

---

## Acceptance Criteria

- [x] `query_radius()` finds entities within circular area
- [x] `query_rect()` finds entities within rectangular area
- [x] `query_point()` finds entity at exact point
- [x] `query_colliding()` finds entities overlapping a given entity
- [x] All queries respect layer_mask filtering
- [x] `query_radius()` returns results sorted by distance
- [x] `query_point()` returns highest priority entity
- [x] `collision.update()` refreshes spatial hash
- [x] Queries handle all shape combinations correctly
- [x] Unit tests pass for all query types

---

## Notes

**Query performance:**
- Broad phase (spatial hash): O(1) average case
- Narrow phase (collision check): O(k) where k = candidates
- Overall: O(k) instead of O(n) for n total entities

**Layer mask format:**
```lua
-- Match specific layers
query_radius(x, y, r, {"unit", "building"})

-- Match all layers
query_radius(x, y, r, nil)
query_radius(x, y, r, {"*"})
```

**Distance sorting:**
- Only query_radius sorts by distance
- query_rect returns unsorted (selection order doesn't matter)
- query_point uses priority sorting instead

**Selection priority:**
- Units are selected over buildings
- Buildings over trigger regions
- Configurable via LAYER_PRIORITY table
- Can be extended for specific unit types later

---

## Implementation Notes

*Completed 2025-12-29*

### Files Modified

- `src/runtime/collision/init.lua` - Added ~290 lines of query functions

### Files Created

- `src/tests/test_collision_queries.lua` (~430 lines) - Comprehensive test suite

### API Implemented

- `collision.update()` - Rebuild spatial hash (call once per frame)
- `collision.query_radius(x, y, radius, layer_mask)` - Find entities in circle, sorted by distance
- `collision.query_rect(x, y, width, height, layer_mask)` - Find entities in rectangle
- `collision.query_point(x, y, layer_mask)` - Find topmost entity at point
- `collision.query_all_at_point(x, y, layer_mask)` - Find all entities at point, sorted by priority
- `collision.query_colliding(entity, layer_mask)` - Find entities overlapping an entity
- `collision.set_cell_size(size)` / `get_cell_size()` - Configure spatial hash
- `collision.get_stats()` - Get collision system statistics
- `collision.clear_spatial()` - Clear spatial hash

### Test Coverage

50 tests covering:
- Query radius (6 tests)
- Layer mask filtering (5 tests)
- Query rect (4 tests)
- Query point (5 tests)
- Query all at point (4 tests)
- Query colliding (4 tests)
- Shape-specific queries (6 tests)
- Update and clear (4 tests)
- Stats and configuration (4 tests)
- Edge cases (6 tests)
- Multiple entities same position (2 tests)

### Total Collision Tests

- 405a (shapes): 99 tests
- 405b (spatial): 61 tests
- 405c (queries): 50 tests
- **Total: 210 tests**

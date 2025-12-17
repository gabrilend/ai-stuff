# Issue 403: Implement Basic Pathfinding

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** High
**Dependencies:** 401, 402, 105-parse-war3map-w3e (terrain data)

---

## Current Behavior

No pathfinding exists. Units cannot navigate terrain or avoid obstacles.

---

## Intended Behavior

A terrain-aware pathfinding system that:
- Finds paths on the parsed terrain grid
- Respects pathing types (walkable, flyable, buildable, etc.)
- Handles different unit movement types (foot, horse, fly, float)
- Avoids static obstacles (cliffs, deep water, doodads)
- Provides paths as waypoint lists

---

## Suggested Implementation Steps

1. **Create pathfinding module**
   ```
   src/runtime/
   └── pathfinding/
       ├── init.lua       (main API)
       ├── grid.lua       (pathing grid from terrain)
       └── astar.lua      (A* implementation)
   ```

2. **Build pathing grid from terrain**
   ```lua
   -- Convert w3e terrain data to pathing grid
   function pathfinding.build_grid(terrain)
       local grid = {}
       for y = 0, terrain.height - 1 do
           grid[y] = {}
           for x = 0, terrain.width - 1 do
               local tile = terrain:get_tile(x, y)
               grid[y][x] = {
                   walkable = is_walkable(tile),
                   flyable = true,  -- air units can go anywhere
                   buildable = is_buildable(tile),
                   water = is_water(tile),
                   cliff_level = tile.cliff_level,
               }
           end
       end
       return grid
   end
   ```

3. **Determine pathing from tile data**
   ```lua
   -- Tile pathing based on w3e flags and terrain type
   local function is_walkable(tile)
       -- Check cliff transitions, water depth, etc.
       if tile.water and tile.water_level > WADE_DEPTH then
           return false
       end
       if tile.cliff_level ~= adjacent_cliff_level then
           return false  -- Cliff edge
       end
       -- Check terrain type (blighted, unbuildable, etc.)
       return not tile.flags.unbuildable
   end
   ```

4. **Implement A* algorithm**
   ```lua
   function astar.find_path(grid, start_x, start_y, goal_x, goal_y, options)
       local open_set = priority_queue.new()
       local came_from = {}
       local g_score = {}
       local f_score = {}

       -- Standard A* implementation
       -- Use Manhattan or Euclidean heuristic
       -- Return list of {x, y} waypoints
   end
   ```

5. **Support different movement types**
   ```lua
   local MOVEMENT_TYPES = {
       foot = { can_walk = true, can_fly = false, can_swim = false },
       horse = { can_walk = true, can_fly = false, can_swim = false },
       fly = { can_walk = true, can_fly = true, can_swim = true },
       float = { can_walk = false, can_fly = false, can_swim = true },
       amphibious = { can_walk = true, can_fly = false, can_swim = true },
   }

   function pathfinding.find_path(start, goal, movement_type)
       local can_pass = function(x, y)
           local cell = grid[y][x]
           local mt = MOVEMENT_TYPES[movement_type]

           if mt.can_fly then return true end
           if cell.water and not mt.can_swim then return false end
           if not cell.walkable and not mt.can_swim then return false end
           return true
       end

       return astar.find_path(grid, start.x, start.y, goal.x, goal.y, {
           can_pass = can_pass
       })
   end
   ```

6. **Path smoothing (optional)**
   ```lua
   -- Remove redundant waypoints on straight lines
   function pathfinding.smooth_path(path)
       -- Line-of-sight checks to skip intermediate points
   end
   ```

7. **Coordinate conversion**
   ```lua
   -- Convert world coordinates to grid coordinates
   function pathfinding.world_to_grid(world_x, world_y)
       -- Account for terrain offset and tile size
   end

   function pathfinding.grid_to_world(grid_x, grid_y)
       -- Return center of tile in world coordinates
   end
   ```

---

## Technical Notes

### WC3 Terrain Grid

WC3 uses a 128x128 (or similar) tile grid. Each tile is typically 128 world units.
The w3e parser provides:
- Ground height at each vertex
- Cliff levels
- Water presence and depth
- Tile texture/type

### Pathing Types

WC3 has several pathing maps:
- Walk: Ground units
- Fly: Air units (mostly unrestricted)
- Build: Building placement
- Amphibious: Naga, ships

### Cliff Handling

Cliffs create impassable boundaries. A unit cannot walk between tiles with
different cliff levels unless there's a ramp.

### Performance Considerations

- Cache the pathing grid (rebuild only when terrain changes)
- Consider hierarchical pathfinding for large maps
- Limit path length or use incremental pathfinding for distant goals
- A* with a good heuristic is usually sufficient for RTS scales

### Dynamic Obstacles

This issue covers static terrain. Dynamic obstacle avoidance (other units,
buildings placed during game) is handled by the movement system (404) and
potentially local avoidance/steering behaviors.

---

## Related Documents

- docs/formats/w3e-terrain.md (terrain data format)
- issues/105-parse-war3map-w3e.md (terrain parser)
- issues/404-create-unit-movement-system.md (uses pathfinding)

---

## Acceptance Criteria

- [ ] Build pathing grid from w3e terrain data
- [ ] A* pathfinding implementation
- [ ] Respects walkable/unwalkable tiles
- [ ] Handles cliff level transitions
- [ ] Handles water (walkable vs deep)
- [ ] Support for movement types (foot, fly, float, amphibious)
- [ ] World-to-grid coordinate conversion
- [ ] Returns waypoint list
- [ ] Unit tests with sample terrain
- [ ] Performance acceptable for typical map sizes

---

## Notes

Start with basic A* on the tile grid. Optimizations like Jump Point Search
or hierarchical pathfinding can be added later if performance is an issue.

Consider caching recent paths or using flow fields for groups of units
moving to the same destination, but this is likely premature optimization
for Phase 4.

WC3's actual pathfinding has quirks (units getting stuck, inefficient paths
around obstacles) - we don't need to replicate bugs, but understanding
WC3's behavior helps set expectations.

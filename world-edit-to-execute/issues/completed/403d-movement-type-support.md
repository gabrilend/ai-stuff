# Issue 403d: Movement Type Support

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** High
**Parent:** 403-implement-basic-pathfinding.md
**Dependencies:** 403a-build-pathing-grid, 403b-implement-astar-algorithm

---

## Current Behavior

The A* implementation (403b) accepts a generic `can_pass` function but has no built-in understanding of different unit movement types. All pathfinding treats terrain the same way regardless of whether the unit walks, flies, or swims.

---

## Intended Behavior

Movement type support that:
- Defines standard WC3 movement types (foot, fly, float, horse, hover, amphibious)
- Provides per-type passability rules
- Integrates with A* via the `can_pass` callback
- Allows flying units to bypass all terrain obstacles
- Handles water depth for swimming/wading units

**Movement Types:**
| Type | Can Walk | Can Fly | Can Swim | Notes |
|------|----------|---------|----------|-------|
| foot | Yes | No | No | Default ground unit |
| horse | Yes | No | No | Same as foot, different animation |
| fly | Yes | Yes | Yes | Air units, bypass terrain |
| float | No | No | Yes | Water-only (ships) |
| hover | Yes | No | Shallow | Hovers over shallow water |
| amphibious | Yes | No | Yes | Naga, can walk and swim |

**API:**
```lua
-- Find path for a specific movement type
local path = pathfinding.find_path(start, goal, "foot")
local path = pathfinding.find_path(start, goal, "fly")
local path = pathfinding.find_path(start, goal, "amphibious")

-- Check if a position is passable for a movement type
local passable = pathfinding.is_passable(x, y, "float")
```

---

## Suggested Implementation Steps

1. **Define movement type constants**
   ```lua
   -- src/runtime/pathfinding/movement.lua
   local movement = {}

   -- {{{ Movement type definitions
   local MOVEMENT_TYPES = {
       foot = {
           can_walk = true,
           can_fly = false,
           can_swim = false,
           can_hover = false,
           max_wade_depth = 64,  -- Can wade through shallow water
       },
       horse = {
           can_walk = true,
           can_fly = false,
           can_swim = false,
           can_hover = false,
           max_wade_depth = 64,
       },
       fly = {
           can_walk = true,
           can_fly = true,
           can_swim = true,  -- Can pass over water
           can_hover = true,
           max_wade_depth = math.huge,  -- Ignores water
       },
       float = {
           can_walk = false,
           can_fly = false,
           can_swim = true,
           can_hover = false,
           max_wade_depth = 0,
           min_swim_depth = 128,  -- Needs deep water
       },
       hover = {
           can_walk = true,
           can_fly = false,
           can_swim = false,
           can_hover = true,
           max_wade_depth = 256,  -- Can hover over shallow water
       },
       amphibious = {
           can_walk = true,
           can_fly = false,
           can_swim = true,
           can_hover = false,
           max_wade_depth = math.huge,  -- Can swim in any depth
       },
   }
   -- }}}
   ```

2. **Implement passability checker**
   ```lua
   -- {{{ movement.can_pass
   -- Checks if a movement type can pass through a grid cell.
   -- Returns true if passable, false otherwise.
   function movement.can_pass(grid, x, y, move_type)
       local cell = grid.cells[y] and grid.cells[y][x]
       if not cell then
           return false  -- Out of bounds
       end

       local mt = MOVEMENT_TYPES[move_type]
       if not mt then
           -- Unknown movement type, default to foot behavior
           mt = MOVEMENT_TYPES.foot
       end

       -- Flying units can pass anywhere (within grid bounds)
       if mt.can_fly then
           return true
       end

       -- Water handling
       if cell.water then
           local depth = cell.water_depth or 0

           -- Floating units need minimum water depth
           if mt.min_swim_depth and depth < mt.min_swim_depth then
               return false
           end

           -- Swimming units can pass any water
           if mt.can_swim then
               return true
           end

           -- Non-swimming units can only wade through shallow water
           if depth <= mt.max_wade_depth then
               return true  -- Shallow enough to wade
           else
               return false  -- Too deep
           end
       end

       -- Land handling
       if not cell.water then
           -- Floating units cannot traverse land
           if not mt.can_walk then
               return false
           end

           -- Check if ground is walkable (cliffs, etc.)
           if not cell.walkable then
               return false
           end
       end

       return true
   end
   -- }}}
   ```

3. **Create passability function factory**
   ```lua
   -- {{{ movement.make_can_pass
   -- Creates a can_pass function for use with A* algorithm.
   function movement.make_can_pass(grid, move_type)
       return function(x, y)
           return movement.can_pass(grid, x, y, move_type)
       end
   end
   -- }}}
   ```

4. **Integrate with main pathfinding API**
   ```lua
   -- In src/runtime/pathfinding/init.lua
   local movement = require("runtime.pathfinding.movement")
   local astar = require("runtime.pathfinding.astar")
   local coords = require("runtime.pathfinding.coords")

   -- {{{ pathfinding.find_path
   -- Main pathfinding API with movement type support.
   -- start, goal: world coordinates {x, y}
   -- move_type: movement type string (default: "foot")
   function pathfinding.find_path(start, goal, move_type, options)
       move_type = move_type or "foot"
       options = options or {}

       local grid = coords.get_grid()
       if not grid then
           return nil, "No pathing grid set"
       end

       -- Convert world to grid coordinates
       local start_gx, start_gy, start_err = coords.world_to_grid(start.x, start.y, grid)
       if not start_gx then
           return nil, "Start position out of bounds: " .. (start_err or "unknown")
       end

       local goal_gx, goal_gy, goal_err = coords.world_to_grid(goal.x, goal.y, grid)
       if not goal_gx then
           return nil, "Goal position out of bounds: " .. (goal_err or "unknown")
       end

       -- Create movement-specific passability function
       local can_pass = movement.make_can_pass(grid, move_type)

       -- Run A* with movement-aware passability
       local path, cost, err = astar.find_path(
           grid,
           start_gx, start_gy,
           goal_gx, goal_gy,
           {
               can_pass = can_pass,
               heuristic = options.heuristic,
               max_iterations = options.max_iterations,
               diagonal = options.diagonal,
           }
       )

       if not path then
           return nil, err or "No path found"
       end

       -- Convert path back to world coordinates
       local world_path = coords.path_to_world(path, grid)

       return world_path, cost
   end
   -- }}}
   ```

5. **Add passability query function**
   ```lua
   -- {{{ pathfinding.is_passable
   -- Checks if a world position is passable for a movement type.
   function pathfinding.is_passable(world_x, world_y, move_type)
       local grid = coords.get_grid()
       if not grid then
           return false
       end

       local gx, gy = coords.world_to_grid(world_x, world_y, grid)
       if not gx then
           return false
       end

       return movement.can_pass(grid, gx, gy, move_type or "foot")
   end
   -- }}}
   ```

6. **Add movement type query functions**
   ```lua
   -- {{{ movement.get_type
   function movement.get_type(name)
       return MOVEMENT_TYPES[name]
   end

   function movement.list_types()
       local names = {}
       for name, _ in pairs(MOVEMENT_TYPES) do
           names[#names + 1] = name
       end
       table.sort(names)
       return names
   end

   function movement.is_valid_type(name)
       return MOVEMENT_TYPES[name] ~= nil
   end
   -- }}}
   ```

7. **Add custom movement type registration**
   ```lua
   -- {{{ movement.register
   -- Allows registering custom movement types.
   function movement.register(name, definition)
       if MOVEMENT_TYPES[name] then
           return false, "Movement type already exists: " .. name
       end

       -- Apply defaults
       definition.can_walk = definition.can_walk or false
       definition.can_fly = definition.can_fly or false
       definition.can_swim = definition.can_swim or false
       definition.can_hover = definition.can_hover or false
       definition.max_wade_depth = definition.max_wade_depth or 0

       MOVEMENT_TYPES[name] = definition
       return true
   end
   -- }}}
   ```

8. **Export movement module**
   ```lua
   -- {{{ Exports
   movement.TYPES = MOVEMENT_TYPES

   pathfinding.movement = movement
   pathfinding.is_passable = is_passable  -- Convenience re-export
   -- }}}

   return movement
   ```

9. **Create unit tests**
   ```
   src/tests/test_movement_types.lua
   ```

10. **Test scenarios**
    - Foot unit blocked by deep water
    - Fly unit passes over water and cliffs
    - Float unit blocked by land, passes water
    - Amphibious unit passes both land and water
    - Hover unit passes shallow water but not deep
    - Path through mixed terrain for different types

---

## Related Documents

- issues/403-implement-basic-pathfinding.md (parent issue)
- issues/403a-build-pathing-grid.md (provides grid with water/walkable data)
- issues/403b-implement-astar-algorithm.md (uses can_pass callback)
- issues/404-create-unit-movement-system.md (assigns movement types to units)

---

## Acceptance Criteria

- [x] All standard WC3 movement types defined (foot, horse, fly, float, hover, amphibious)
- [x] `movement.can_pass()` correctly evaluates passability per type
- [x] Flying units bypass all terrain obstacles
- [x] Floating units blocked by land, require deep water
- [x] Amphibious units pass both land and water
- [x] Water depth thresholds work correctly
- [x] `pathfinding.find_path_for_type()` accepts movement_type parameter
- [x] `pathfinding.is_passable()` checks passability at a point
- [x] Custom movement type registration works
- [x] Unit tests cover all movement types and terrain combinations

---

## Notes

The movement type definitions are simplified compared to WC3's full system, which has additional complexity around cliff climbing (mountain giants), burrowing, and building pathing. This implementation covers the core movement categories.

Water depth thresholds (64, 128, 256) are approximate and may need tuning based on actual w3e water level values. The w3e parser should document what units water_level is stored in.

Flying units returning `true` for all passability means A* will find the straight-line path. This could be optimized to skip A* entirely for fly movement, but keeping the unified interface is cleaner.

The `min_swim_depth` for float units prevents ships from traversing puddles or very shallow coastal water.

---

## Implementation Notes

### Files Created
- `src/runtime/pathfinding/movement.lua` (~300 lines) - Movement type definitions and passability logic
- `src/tests/test_movement_types.lua` (~420 lines) - 106 comprehensive tests

### Key Implementation Details

1. **Movement Type Definitions**: Six types defined with capability flags:
   - `can_walk`, `can_fly`, `can_swim`, `can_hover`
   - `max_wade_depth` (64 for foot, 256 for hover, math.huge for swimmers)
   - `min_swim_depth` (128 for float units - ships need deep water)

2. **Passability Logic** (`movement.can_pass`):
   - Flying units bypass all terrain (return true if in bounds)
   - Floating units require deep water (`depth >= min_swim_depth`)
   - Swimming units pass any water
   - Hovering units check `max_wade_depth` for water crossing
   - Walking units check `cell.walkable` for land traversal

3. **Factory Function**: `movement.make_can_pass(grid, move_type)` creates closure
   for A* algorithm integration, capturing grid and movement type.

4. **Pathfinding Integration**:
   - `pathfinding.is_passable(world_x, world_y, move_type)` - world-space query
   - `pathfinding.find_path_for_type(start, goal, move_type, options)` - full path
   - Coordinates convert world → grid → A* → grid → world automatically

5. **Custom Type Registration**: `movement.register()` and `movement.unregister()`
   allow runtime extension. Built-in types cannot be unregistered.

6. **Convenience Functions**:
   - `can_traverse_water(type, depth)` - check water passability
   - `can_traverse_land(type)` - check land passability
   - `is_flying(type)` - check if type bypasses terrain
   - `describe_type(type)` - human-readable description

### Test Coverage (106 tests)
- Movement type definitions and properties
- Foot unit passability (land, shallow water, deep water, cliffs)
- Flying unit passability (bypasses all terrain)
- Floating unit passability (deep water only, blocked by land)
- Amphibious unit passability (land and water)
- Hover unit passability (land and shallow water)
- Horse unit passability (same as foot)
- make_can_pass factory function
- Custom movement type registration/unregistration
- Convenience functions (can_traverse_water, can_traverse_land, is_flying)
- Default movement type fallback for unknown types
- Edge cases (nil grid, empty grid, nil row, zero-depth water)
- Pathfinding module integration (is_passable, find_path_for_type)

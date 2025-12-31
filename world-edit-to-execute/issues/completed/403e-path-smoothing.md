# Issue 403e: Path Smoothing

**Phase:** 4 - Runtime
**Type:** Feature (Optional Enhancement)
**Priority:** Low
**Parent:** 403-implement-basic-pathfinding.md
**Dependencies:** 403b-implement-astar-algorithm

---

## Current Behavior

The A* algorithm returns paths that follow tile centers, creating stair-step patterns when moving diagonally. Every tile the path crosses becomes a waypoint, resulting in many unnecessary intermediate points.

**Example A* output (before smoothing):**
```
Path: (0,0) → (1,0) → (2,0) → (3,0) → (4,0)  -- 5 waypoints for straight line
```

---

## Intended Behavior

Path smoothing that:
- Removes redundant waypoints on straight-line segments
- Uses line-of-sight checks to skip intermediate points
- Produces smoother, more natural-looking movement
- Preserves path validity (no shortcuts through obstacles)

**Example after smoothing:**
```
Path: (0,0) → (4,0)  -- 2 waypoints for straight line
```

**API:**
```lua
-- Smooth an existing path
local smoothed = pathfinding.smooth_path(path, grid, can_pass)

-- Or integrated into find_path
local path = pathfinding.find_path(start, goal, "foot", { smooth = true })
```

---

## Suggested Implementation Steps

1. **Create smoothing module**
   ```lua
   -- src/runtime/pathfinding/smooth.lua
   local smooth = {}
   ```

2. **Implement line-of-sight check**
   ```lua
   -- {{{ has_line_of_sight
   -- Checks if there's a clear line between two grid points.
   -- Uses Bresenham's line algorithm to check all tiles along the line.
   local function has_line_of_sight(grid, x1, y1, x2, y2, can_pass)
       -- Bresenham's line algorithm
       local dx = math.abs(x2 - x1)
       local dy = math.abs(y2 - y1)
       local sx = x1 < x2 and 1 or -1
       local sy = y1 < y2 and 1 or -1
       local err = dx - dy

       local x, y = x1, y1

       while true do
           -- Check current cell
           if not can_pass(x, y) then
               return false
           end

           -- Reached destination
           if x == x2 and y == y2 then
               return true
           end

           local e2 = 2 * err

           if e2 > -dy then
               err = err - dy
               x = x + sx
           end

           if e2 < dx then
               err = err + dx
               y = y + sy
           end
       end
   end
   -- }}}
   ```

3. **Implement basic path smoothing**
   ```lua
   -- {{{ smooth.smooth_path
   -- Removes redundant waypoints from a path.
   -- Keeps only waypoints where direction changes or line-of-sight is broken.
   function smooth.smooth_path(path, grid, can_pass)
       if not path or #path <= 2 then
           return path  -- Nothing to smooth
       end

       can_pass = can_pass or function(x, y)
           local cell = grid.cells[y] and grid.cells[y][x]
           return cell and cell.walkable
       end

       local smoothed = { path[1] }  -- Always keep start
       local current_idx = 1

       while current_idx < #path do
           -- Try to skip as many waypoints as possible
           local farthest_visible = current_idx + 1

           for i = current_idx + 2, #path do
               local from = path[current_idx]
               local to = path[i]

               if has_line_of_sight(grid, from.x, from.y, to.x, to.y, can_pass) then
                   farthest_visible = i
               else
                   break  -- Can't see past this point, stop looking
               end
           end

           -- Add the farthest visible point
           smoothed[#smoothed + 1] = path[farthest_visible]
           current_idx = farthest_visible
       end

       return smoothed
   end
   -- }}}
   ```

4. **Implement greedy path smoothing**
   ```lua
   -- {{{ smooth.smooth_greedy
   -- More aggressive smoothing: always try to skip to goal first.
   -- Falls back to binary search for best skip point.
   function smooth.smooth_greedy(path, grid, can_pass)
       if not path or #path <= 2 then
           return path
       end

       can_pass = can_pass or function(x, y)
           local cell = grid.cells[y] and grid.cells[y][x]
           return cell and cell.walkable
       end

       local smoothed = { path[1] }
       local current_idx = 1

       while current_idx < #path do
           local from = path[current_idx]

           -- Try direct line to goal first
           if has_line_of_sight(grid, from.x, from.y, path[#path].x, path[#path].y, can_pass) then
               smoothed[#smoothed + 1] = path[#path]
               break
           end

           -- Binary search for farthest visible point
           local lo, hi = current_idx + 1, #path
           local best = current_idx + 1

           while lo <= hi do
               local mid = math.floor((lo + hi) / 2)
               local to = path[mid]

               if has_line_of_sight(grid, from.x, from.y, to.x, to.y, can_pass) then
                   best = mid
                   lo = mid + 1
               else
                   hi = mid - 1
               end
           end

           smoothed[#smoothed + 1] = path[best]
           current_idx = best
       end

       return smoothed
   end
   -- }}}
   ```

5. **Add collinearity-based smoothing**
   ```lua
   -- {{{ smooth.remove_collinear
   -- Removes waypoints that are collinear with their neighbors.
   -- Faster than line-of-sight but less aggressive.
   function smooth.remove_collinear(path)
       if not path or #path <= 2 then
           return path
       end

       local function are_collinear(p1, p2, p3)
           -- Cross product should be zero for collinear points
           local cross = (p2.x - p1.x) * (p3.y - p1.y) - (p2.y - p1.y) * (p3.x - p1.x)
           return cross == 0
       end

       local smoothed = { path[1] }

       for i = 2, #path - 1 do
           local prev = smoothed[#smoothed]
           local curr = path[i]
           local next = path[i + 1]

           -- Keep point only if it changes direction
           if not are_collinear(prev, curr, next) then
               smoothed[#smoothed + 1] = curr
           end
       end

       -- Always keep the goal
       smoothed[#smoothed + 1] = path[#path]

       return smoothed
   end
   -- }}}
   ```

6. **Integrate with main pathfinding API**
   ```lua
   -- In src/runtime/pathfinding/init.lua
   local smooth_module = require("runtime.pathfinding.smooth")

   -- Modify find_path to accept smooth option
   function pathfinding.find_path(start, goal, move_type, options)
       -- ... existing path finding ...

       if path and options.smooth then
           local can_pass = movement.make_can_pass(grid, move_type)
           path = smooth_module.smooth_path(path, grid, can_pass)
       end

       -- Convert to world coordinates...
   end

   -- Expose smoothing functions
   pathfinding.smooth_path = smooth_module.smooth_path
   pathfinding.smooth_greedy = smooth_module.smooth_greedy
   pathfinding.remove_collinear = smooth_module.remove_collinear
   ```

7. **Export the module**
   ```lua
   -- {{{ Exports
   smooth.has_line_of_sight = has_line_of_sight
   -- }}}

   return smooth
   ```

8. **Create unit tests**
   ```
   src/tests/test_path_smoothing.lua
   ```

9. **Test scenarios**
   - Straight line path reduced to 2 points
   - Diagonal path through open area reduced
   - Path around obstacle maintains necessary waypoints
   - Complex path with multiple direction changes
   - Performance with long paths

---

## Related Documents

- issues/403-implement-basic-pathfinding.md (parent issue)
- issues/403b-implement-astar-algorithm.md (provides raw paths)
- issues/404-create-unit-movement-system.md (uses smoothed paths)

---

## Acceptance Criteria

- [x] `smooth.smooth_path()` removes redundant waypoints
- [x] Line-of-sight check correctly handles obstacles
- [x] Straight-line paths reduced to start and end only
- [x] Paths around obstacles maintain necessary waypoints
- [x] Smoothing preserves path validity (no shortcuts through walls)
- [x] `remove_collinear()` provides fast collinearity-based smoothing
- [x] Integration with `find_path_for_type()` via `smooth` option
- [x] Unit tests verify smoothing correctness

---

## Notes

This issue is marked as optional/low priority. Basic A* paths are functional without smoothing - units will just take slightly more waypoints. Smoothing is primarily a visual/aesthetic improvement.

The line-of-sight check uses Bresenham's algorithm, which is exact for grid-based movement. For sub-tile precision, a raycast would be more appropriate but more complex.

There's a tradeoff between smoothing aggressiveness and computation cost:
- `remove_collinear()`: O(n), very fast, removes only direction-preserving points
- `smooth_path()`: O(n * k) where k is average segment length, more aggressive
- `smooth_greedy()`: O(n log n) with binary search, most aggressive

For typical RTS paths (10-50 waypoints), all methods are fast enough. The choice depends on how visually smooth the movement needs to be.

WC3's actual unit movement has a "sliding" behavior along obstacles that this smoothing doesn't replicate. That's part of the movement system (404), not pathfinding.

---

## Implementation Notes

### Files Created
- `src/runtime/pathfinding/smooth.lua` (~280 lines) - Path smoothing algorithms
- `src/tests/test_path_smoothing.lua` (~320 lines) - 64 tests

### Key Implementation Details

1. **Line-of-Sight (Bresenham's Algorithm)**: `has_line_of_sight()` traces a line between
   two grid points, checking passability at each tile. Used to determine if intermediate
   waypoints can be skipped.

2. **Smoothing Methods**:
   - `remove_collinear()` - O(n), removes points on same line, fast but doesn't check obstacles
   - `smooth_path()` - O(n*k), iteratively finds farthest visible point
   - `smooth_greedy()` - O(n log n), binary search for farthest visible, most aggressive
   - `smooth_path_for_movement()` - Combined: collinear removal + LOS smoothing

3. **Integration**: `find_path_for_type()` now accepts `smooth` and `smooth_method` options:
   ```lua
   local path = pathfinding.find_path_for_type(start, goal, "foot", { smooth = true })
   ```

4. **Utility Functions**:
   - `path_stats()` - Returns reduction percentage for debugging
   - `get_line_tiles()` - Returns all tiles along a line (for visualization)

### Test Coverage (64 tests)
- Line-of-sight: horizontal, vertical, diagonal, blocked, steep angles
- Get line tiles: tile counts and positions
- Collinearity detection: straight lines, corners, turns
- Remove collinear: straight paths, L-shapes, edge cases
- Smooth path: open grid, obstacles, path validity verification
- Smooth greedy: binary search correctness
- Combined smoothing: integration of both methods
- Edge cases: empty paths, single points, nil handling
- Performance: 128-point paths processed in under 1 second

### Total Pathfinding Tests: 452
- Grid: 93, A*: 90, Coords: 99, Movement: 106, Smoothing: 64

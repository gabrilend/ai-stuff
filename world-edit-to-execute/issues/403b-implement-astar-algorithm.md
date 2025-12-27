# Issue 403b: Implement A* Algorithm

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** High
**Parent:** 403-implement-basic-pathfinding.md
**Dependencies:** None (can be developed with mock grid)

---

## Current Behavior

No pathfinding algorithm exists. The project cannot compute paths between two points on a grid.

---

## Intended Behavior

A generic A* pathfinding implementation that:
- Operates on any 2D grid with a passability function
- Uses configurable heuristics (Manhattan or Euclidean)
- Returns an ordered list of waypoints from start to goal
- Handles unreachable destinations gracefully
- Is efficient enough for typical RTS map sizes (128x128 or larger)

**API:**
```lua
local path, cost = astar.find_path(grid, start_x, start_y, goal_x, goal_y, options)

-- path: array of {x, y} waypoints, or nil if no path exists
-- cost: total path cost, or nil if no path

-- options:
--   can_pass: function(x, y) -> boolean
--   heuristic: "manhattan" or "euclidean" (default: "manhattan")
--   max_iterations: limit search iterations (default: 10000)
--   diagonal: allow diagonal movement (default: false)
```

---

## Suggested Implementation Steps

1. **Create the A* module**
   ```
   src/runtime/pathfinding/
   └── astar.lua       (this issue)
   ```

2. **Implement priority queue**
   ```lua
   -- src/runtime/pathfinding/astar.lua
   local astar = {}

   -- {{{ Priority Queue (min-heap)
   -- Simple binary heap implementation for A* open set
   local PriorityQueue = {}
   PriorityQueue.__index = PriorityQueue

   function PriorityQueue.new()
       return setmetatable({ heap = {}, positions = {} }, PriorityQueue)
   end

   function PriorityQueue:push(item, priority)
       local heap = self.heap
       heap[#heap + 1] = { item = item, priority = priority }
       self:_sift_up(#heap)
   end

   function PriorityQueue:pop()
       local heap = self.heap
       if #heap == 0 then return nil end

       local top = heap[1]
       heap[1] = heap[#heap]
       heap[#heap] = nil

       if #heap > 0 then
           self:_sift_down(1)
       end

       return top.item, top.priority
   end

   function PriorityQueue:is_empty()
       return #self.heap == 0
   end

   function PriorityQueue:_sift_up(idx)
       local heap = self.heap
       while idx > 1 do
           local parent = math.floor(idx / 2)
           if heap[idx].priority < heap[parent].priority then
               heap[idx], heap[parent] = heap[parent], heap[idx]
               idx = parent
           else
               break
           end
       end
   end

   function PriorityQueue:_sift_down(idx)
       local heap = self.heap
       local size = #heap
       while true do
           local left = idx * 2
           local right = idx * 2 + 1
           local smallest = idx

           if left <= size and heap[left].priority < heap[smallest].priority then
               smallest = left
           end
           if right <= size and heap[right].priority < heap[smallest].priority then
               smallest = right
           end

           if smallest ~= idx then
               heap[idx], heap[smallest] = heap[smallest], heap[idx]
               idx = smallest
           else
               break
           end
       end
   end
   -- }}}
   ```

3. **Implement heuristic functions**
   ```lua
   -- {{{ Heuristics
   local function manhattan_distance(x1, y1, x2, y2)
       return math.abs(x2 - x1) + math.abs(y2 - y1)
   end

   local function euclidean_distance(x1, y1, x2, y2)
       local dx = x2 - x1
       local dy = y2 - y1
       return math.sqrt(dx * dx + dy * dy)
   end

   local HEURISTICS = {
       manhattan = manhattan_distance,
       euclidean = euclidean_distance,
   }
   -- }}}
   ```

4. **Implement neighbor generation**
   ```lua
   -- {{{ Neighbors
   local CARDINAL_DIRS = {
       { 0, -1, 1 },   -- North
       { 0,  1, 1 },   -- South
       { -1, 0, 1 },   -- West
       {  1, 0, 1 },   -- East
   }

   local DIAGONAL_DIRS = {
       { -1, -1, 1.414 },  -- NW
       {  1, -1, 1.414 },  -- NE
       { -1,  1, 1.414 },  -- SW
       {  1,  1, 1.414 },  -- SE
   }

   local function get_neighbors(x, y, options)
       local neighbors = {}
       local dirs = CARDINAL_DIRS

       if options.diagonal then
           -- Combine cardinal and diagonal
           dirs = {}
           for _, d in ipairs(CARDINAL_DIRS) do dirs[#dirs + 1] = d end
           for _, d in ipairs(DIAGONAL_DIRS) do dirs[#dirs + 1] = d end
       end

       for _, dir in ipairs(dirs) do
           local nx, ny = x + dir[1], y + dir[2]
           local cost = dir[3]
           neighbors[#neighbors + 1] = { x = nx, y = ny, cost = cost }
       end

       return neighbors
   end
   -- }}}
   ```

5. **Implement path reconstruction**
   ```lua
   -- {{{ Path reconstruction
   local function reconstruct_path(came_from, current)
       local path = { current }

       while came_from[current.y] and came_from[current.y][current.x] do
           current = came_from[current.y][current.x]
           table.insert(path, 1, current)
       end

       return path
   end

   local function make_key(x, y)
       -- Fast unique key for coordinate pair
       return y * 100000 + x
   end
   -- }}}
   ```

6. **Implement main A* algorithm**
   ```lua
   -- {{{ astar.find_path
   function astar.find_path(grid, start_x, start_y, goal_x, goal_y, options)
       options = options or {}

       local can_pass = options.can_pass or function(x, y)
           local cell = grid.cells[y] and grid.cells[y][x]
           return cell and cell.walkable
       end

       local heuristic = HEURISTICS[options.heuristic or "manhattan"]
       local max_iterations = options.max_iterations or 10000

       -- Check start and goal are passable
       if not can_pass(start_x, start_y) then
           return nil, nil, "Start position is not passable"
       end
       if not can_pass(goal_x, goal_y) then
           return nil, nil, "Goal position is not passable"
       end

       -- Check start equals goal
       if start_x == goal_x and start_y == goal_y then
           return {{ x = start_x, y = start_y }}, 0
       end

       local open_set = PriorityQueue.new()
       local came_from = {}
       local g_score = {}
       local in_open = {}  -- Track what's in open set

       -- Initialize
       g_score[start_y] = {}
       g_score[start_y][start_x] = 0

       local start_f = heuristic(start_x, start_y, goal_x, goal_y)
       open_set:push({ x = start_x, y = start_y }, start_f)
       in_open[make_key(start_x, start_y)] = true

       local iterations = 0

       while not open_set:is_empty() do
           iterations = iterations + 1
           if iterations > max_iterations then
               return nil, nil, "Max iterations exceeded"
           end

           local current = open_set:pop()
           local cx, cy = current.x, current.y
           in_open[make_key(cx, cy)] = nil

           -- Goal reached
           if cx == goal_x and cy == goal_y then
               local path = reconstruct_path(came_from, current)
               local cost = g_score[cy] and g_score[cy][cx] or 0
               return path, cost
           end

           -- Explore neighbors
           local neighbors = get_neighbors(cx, cy, options)
           for _, neighbor in ipairs(neighbors) do
               local nx, ny = neighbor.x, neighbor.y

               if can_pass(nx, ny) then
                   local current_g = (g_score[cy] and g_score[cy][cx]) or math.huge
                   local tentative_g = current_g + neighbor.cost

                   local neighbor_g = (g_score[ny] and g_score[ny][nx]) or math.huge

                   if tentative_g < neighbor_g then
                       -- Better path found
                       came_from[ny] = came_from[ny] or {}
                       came_from[ny][nx] = { x = cx, y = cy }

                       g_score[ny] = g_score[ny] or {}
                       g_score[ny][nx] = tentative_g

                       local f_score = tentative_g + heuristic(nx, ny, goal_x, goal_y)

                       if not in_open[make_key(nx, ny)] then
                           open_set:push({ x = nx, y = ny }, f_score)
                           in_open[make_key(nx, ny)] = true
                       end
                   end
               end
           end
       end

       -- No path found
       return nil, nil, "No path exists"
   end
   -- }}}
   ```

7. **Add convenience functions**
   ```lua
   -- {{{ Convenience functions
   function astar.find_path_simple(grid, start, goal, movement_type)
       -- Simplified API using point tables
       return astar.find_path(grid, start.x, start.y, goal.x, goal.y)
   end

   function astar.path_length(path)
       if not path or #path < 2 then return 0 end

       local total = 0
       for i = 2, #path do
           local dx = path[i].x - path[i-1].x
           local dy = path[i].y - path[i-1].y
           total = total + math.sqrt(dx*dx + dy*dy)
       end
       return total
   end
   -- }}}
   ```

8. **Export the module**
   ```lua
   -- {{{ Exports
   astar.PriorityQueue = PriorityQueue
   astar.manhattan_distance = manhattan_distance
   astar.euclidean_distance = euclidean_distance
   -- }}}

   return astar
   ```

9. **Create unit tests**
   ```
   src/tests/test_astar.lua
   ```

10. **Test scenarios**
    - Simple straight-line path
    - Path around a wall
    - No path exists (blocked)
    - Start equals goal
    - Large grid performance test
    - Diagonal movement option

---

## Related Documents

- issues/403-implement-basic-pathfinding.md (parent issue)
- issues/403a-build-pathing-grid.md (provides grid data)
- issues/403d-movement-type-support.md (uses A* with custom can_pass)
- issues/403e-path-smoothing.md (post-processes paths)

---

## Acceptance Criteria

- [x] `src/runtime/pathfinding/astar.lua` exists
- [x] Priority queue implementation works correctly
- [x] Manhattan and Euclidean heuristics implemented
- [x] `astar.find_path()` finds optimal paths on test grids
- [x] Returns nil with error message when no path exists
- [x] Handles start == goal case
- [x] Respects max_iterations limit
- [x] Diagonal movement option works
- [x] Path cost is calculated correctly
- [x] Unit tests pass for various scenarios
- [x] Performance acceptable on 128x128 grid

---

## Notes

The A* implementation is intentionally generic - it doesn't know about WC3 terrain specifics. The `can_pass` function callback allows the pathfinding system (403d) to inject movement-type-specific logic.

The priority queue is a simple binary heap. For very large maps or frequent pathfinding, a more optimized data structure (pairing heap, Fibonacci heap) could be used, but binary heap is sufficient for typical RTS scales.

The coordinate key function `make_key()` assumes grids smaller than 100,000 tiles per dimension, which is far larger than any WC3 map.

Consider adding early termination if the path becomes too long, or implementing partial paths that get the unit closer to the goal even if the full path is blocked.

---

## Implementation Notes

### Files Created
- `src/runtime/pathfinding/astar.lua` (~300 lines) - A* algorithm implementation
- `src/tests/test_astar.lua` (~400 lines) - 90 tests

### Key Implementation Details

1. **Priority Queue**: Binary min-heap implementation with O(log n) push/pop operations.
   Stores items with priorities, returns lowest priority first. Includes peek() and size().

2. **Heuristics**: Three distance functions available:
   - Manhattan: Sum of absolute differences (optimal for 4-way movement)
   - Euclidean: Straight-line distance (better for 8-way movement)
   - Chebyshev: Maximum of absolute differences (alternative for 8-way)

3. **Neighbor Generation**: Configurable 4-way (cardinal) or 8-way (with diagonal) movement.
   Diagonal moves cost sqrt(2) ≈ 1.414 instead of 1.

4. **Custom Passability**: Optional `can_pass(x, y)` callback allows movement-type-specific
   logic to be injected without the algorithm knowing about terrain specifics.

5. **Path Reconstruction**: Walks back through came_from table to build path from start to goal.

6. **API Surface**:
   - `find_path(grid, start_x, start_y, goal_x, goal_y, options)` - Main pathfinding
   - `find_path_simple(grid, start, goal, options)` - Point-based API
   - `path_length(path)` - Calculate Euclidean path length
   - `path_to_string(path)` - Debug string representation

### Performance
- 128x128 grid with obstacles: < 100ms per path
- 10 paths on 128x128: < 500ms total
- Uses identity-based coordinate keys (y * 100000 + x) for fast lookups

### Test Coverage
- 90 tests covering: priority queue, heuristics, simple paths, obstacles, no-path cases,
  edge cases, iteration limits, heuristic options, custom can_pass, diagonal movement,
  path utilities, integration with pathfinding module

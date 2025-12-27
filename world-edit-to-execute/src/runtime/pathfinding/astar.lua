--[[
A* Pathfinding Algorithm

Generic A* implementation for 2D grids. Operates on any grid structure with a
passability function callback. Supports Manhattan and Euclidean heuristics,
optional diagonal movement, and configurable iteration limits.

The algorithm doesn't know about WC3 terrain specifics - the can_pass callback
allows movement-type-specific logic to be injected (ground vs fly vs float).
]]

local astar = {}

-- {{{ Priority Queue (min-heap)
-- Simple binary heap for the A* open set. Items with lowest priority are
-- returned first, making this suitable for f-score ordering.
local PriorityQueue = {}
PriorityQueue.__index = PriorityQueue

-- {{{ PriorityQueue.new
function PriorityQueue.new()
    return setmetatable({ heap = {} }, PriorityQueue)
end
-- }}}

-- {{{ PriorityQueue:push
function PriorityQueue:push(item, priority)
    local heap = self.heap
    heap[#heap + 1] = { item = item, priority = priority }
    self:_sift_up(#heap)
end
-- }}}

-- {{{ PriorityQueue:pop
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
-- }}}

-- {{{ PriorityQueue:peek
function PriorityQueue:peek()
    local top = self.heap[1]
    if top then
        return top.item, top.priority
    end
    return nil
end
-- }}}

-- {{{ PriorityQueue:is_empty
function PriorityQueue:is_empty()
    return #self.heap == 0
end
-- }}}

-- {{{ PriorityQueue:size
function PriorityQueue:size()
    return #self.heap
end
-- }}}

-- {{{ PriorityQueue:_sift_up
-- Move an item up the heap until heap property is restored
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
-- }}}

-- {{{ PriorityQueue:_sift_down
-- Move an item down the heap until heap property is restored
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
-- }}}

-- {{{ Heuristics
-- Distance estimation functions for A* pathfinding

-- {{{ manhattan_distance
-- Sum of absolute differences - optimal for 4-directional movement
local function manhattan_distance(x1, y1, x2, y2)
    return math.abs(x2 - x1) + math.abs(y2 - y1)
end
-- }}}

-- {{{ euclidean_distance
-- Straight-line distance - better for 8-directional movement
local function euclidean_distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end
-- }}}

-- {{{ chebyshev_distance
-- Maximum of absolute differences - alternative for 8-directional
local function chebyshev_distance(x1, y1, x2, y2)
    return math.max(math.abs(x2 - x1), math.abs(y2 - y1))
end
-- }}}

-- Heuristic lookup table
local HEURISTICS = {
    manhattan = manhattan_distance,
    euclidean = euclidean_distance,
    chebyshev = chebyshev_distance,
}
-- }}}

-- {{{ Neighbors
-- Direction vectors for neighbor generation

-- Cardinal directions (4-way movement): dx, dy, cost
local CARDINAL_DIRS = {
    { 0, -1, 1 },   -- South
    { 0,  1, 1 },   -- North
    { -1, 0, 1 },   -- West
    {  1, 0, 1 },   -- East
}

-- Diagonal directions: dx, dy, cost (sqrt(2) ≈ 1.414)
local DIAGONAL_DIRS = {
    { -1, -1, 1.41421356 },  -- SW
    {  1, -1, 1.41421356 },  -- SE
    { -1,  1, 1.41421356 },  -- NW
    {  1,  1, 1.41421356 },  -- NE
}

-- {{{ get_neighbors
-- Generate valid neighbor positions for a given coordinate
-- @param x Grid X coordinate
-- @param y Grid Y coordinate
-- @param diagonal Allow diagonal movement
-- @return Array of {x, y, cost} neighbor info
local function get_neighbors(x, y, diagonal)
    local neighbors = {}

    -- Always include cardinal directions
    for _, dir in ipairs(CARDINAL_DIRS) do
        neighbors[#neighbors + 1] = {
            x = x + dir[1],
            y = y + dir[2],
            cost = dir[3],
        }
    end

    -- Include diagonals if enabled
    if diagonal then
        for _, dir in ipairs(DIAGONAL_DIRS) do
            neighbors[#neighbors + 1] = {
                x = x + dir[1],
                y = y + dir[2],
                cost = dir[3],
            }
        end
    end

    return neighbors
end
-- }}}
-- }}}

-- {{{ Path reconstruction
-- Utilities for building the final path from A* results

-- {{{ make_key
-- Create unique key for coordinate pair. Assumes grids < 100000 in each
-- dimension (far larger than any WC3 map).
local function make_key(x, y)
    return y * 100000 + x
end
-- }}}

-- {{{ reconstruct_path
-- Build path from came_from map by walking backwards from goal to start
-- @param came_from 2D table of predecessor coordinates
-- @param current Goal position {x, y}
-- @return Array of {x, y} waypoints from start to goal
local function reconstruct_path(came_from, current)
    local path = { { x = current.x, y = current.y } }

    while came_from[current.y] and came_from[current.y][current.x] do
        current = came_from[current.y][current.x]
        -- Insert at beginning to build path from start to goal
        table.insert(path, 1, { x = current.x, y = current.y })
    end

    return path
end
-- }}}
-- }}}

-- {{{ astar.find_path
-- Find shortest path between two points on a grid using A* algorithm.
--
-- @param grid Pathing grid with cells table
-- @param start_x Starting X coordinate
-- @param start_y Starting Y coordinate
-- @param goal_x Goal X coordinate
-- @param goal_y Goal Y coordinate
-- @param options Configuration table:
--   can_pass: function(x, y) -> boolean (default: check grid.cells[y][x].walkable)
--   heuristic: "manhattan" | "euclidean" | "chebyshev" (default: "manhattan")
--   max_iterations: search iteration limit (default: 10000)
--   diagonal: allow diagonal movement (default: false)
-- @return path Array of {x, y} waypoints, or nil if no path
-- @return cost Total path cost, or nil if no path
-- @return error Error message if no path (optional)
function astar.find_path(grid, start_x, start_y, goal_x, goal_y, options)
    options = options or {}

    -- Default passability function checks grid walkability
    local can_pass = options.can_pass or function(x, y)
        if not grid or not grid.cells then return false end
        local row = grid.cells[y]
        if not row then return false end
        local cell = row[x]
        return cell and cell.walkable
    end

    local heuristic = HEURISTICS[options.heuristic or "manhattan"]
    if not heuristic then
        return nil, nil, "Unknown heuristic: " .. tostring(options.heuristic)
    end

    local max_iterations = options.max_iterations or 10000
    local diagonal = options.diagonal or false

    -- Validate start position
    if not can_pass(start_x, start_y) then
        return nil, nil, "Start position is not passable"
    end

    -- Validate goal position
    if not can_pass(goal_x, goal_y) then
        return nil, nil, "Goal position is not passable"
    end

    -- Handle trivial case: start equals goal
    if start_x == goal_x and start_y == goal_y then
        return { { x = start_x, y = start_y } }, 0
    end

    -- Initialize data structures
    local open_set = PriorityQueue.new()
    local came_from = {}   -- 2D table: came_from[y][x] = predecessor
    local g_score = {}     -- 2D table: g_score[y][x] = cost from start
    local in_open = {}     -- Set: track what's currently in open set

    -- Initialize start node
    g_score[start_y] = {}
    g_score[start_y][start_x] = 0

    local start_h = heuristic(start_x, start_y, goal_x, goal_y)
    open_set:push({ x = start_x, y = start_y }, start_h)
    in_open[make_key(start_x, start_y)] = true

    local iterations = 0

    -- Main A* loop
    while not open_set:is_empty() do
        iterations = iterations + 1
        if iterations > max_iterations then
            return nil, nil, "Max iterations exceeded"
        end

        -- Get node with lowest f-score
        local current = open_set:pop()
        local cx, cy = current.x, current.y
        local current_key = make_key(cx, cy)
        in_open[current_key] = nil

        -- Goal reached - reconstruct and return path
        if cx == goal_x and cy == goal_y then
            local path = reconstruct_path(came_from, current)
            local cost = g_score[cy] and g_score[cy][cx] or 0
            return path, cost
        end

        -- Get g-score for current node
        local current_g = g_score[cy] and g_score[cy][cx]
        if not current_g then
            -- Shouldn't happen, but guard against it
            current_g = 0
        end

        -- Explore neighbors
        local neighbors = get_neighbors(cx, cy, diagonal)
        for _, neighbor in ipairs(neighbors) do
            local nx, ny = neighbor.x, neighbor.y

            if can_pass(nx, ny) then
                local tentative_g = current_g + neighbor.cost
                local neighbor_g = (g_score[ny] and g_score[ny][nx]) or math.huge

                -- Found a better path to this neighbor
                if tentative_g < neighbor_g then
                    -- Record predecessor
                    came_from[ny] = came_from[ny] or {}
                    came_from[ny][nx] = { x = cx, y = cy }

                    -- Update g-score
                    g_score[ny] = g_score[ny] or {}
                    g_score[ny][nx] = tentative_g

                    -- Calculate f-score and add to open set
                    local f_score = tentative_g + heuristic(nx, ny, goal_x, goal_y)
                    local neighbor_key = make_key(nx, ny)

                    if not in_open[neighbor_key] then
                        open_set:push({ x = nx, y = ny }, f_score)
                        in_open[neighbor_key] = true
                    end
                    -- Note: We don't update priority if already in open set.
                    -- This means we may process a node multiple times, but
                    -- the g_score check ensures we only use the best path.
                    -- A more optimized version would update the priority.
                end
            end
        end
    end

    -- Open set exhausted without finding goal
    return nil, nil, "No path exists"
end
-- }}}

-- {{{ Convenience functions

-- {{{ astar.find_path_simple
-- Simplified API using point tables instead of separate coordinates
-- @param grid Pathing grid
-- @param start Table with x, y fields
-- @param goal Table with x, y fields
-- @param options Optional configuration
-- @return path, cost (see find_path)
function astar.find_path_simple(grid, start, goal, options)
    return astar.find_path(grid, start.x, start.y, goal.x, goal.y, options)
end
-- }}}

-- {{{ astar.path_length
-- Calculate Euclidean length of a path
-- @param path Array of {x, y} waypoints
-- @return Total path length
function astar.path_length(path)
    if not path or #path < 2 then
        return 0
    end

    local total = 0
    for i = 2, #path do
        local dx = path[i].x - path[i-1].x
        local dy = path[i].y - path[i-1].y
        total = total + math.sqrt(dx * dx + dy * dy)
    end

    return total
end
-- }}}

-- {{{ astar.path_to_string
-- Convert path to readable string for debugging
-- @param path Array of {x, y} waypoints
-- @return String representation
function astar.path_to_string(path)
    if not path then
        return "nil"
    end
    if #path == 0 then
        return "(empty)"
    end

    local parts = {}
    for _, p in ipairs(path) do
        parts[#parts + 1] = string.format("(%d,%d)", p.x, p.y)
    end
    return table.concat(parts, " -> ")
end
-- }}}
-- }}}

-- {{{ Exports
-- Export internal components for testing and advanced usage
astar.PriorityQueue = PriorityQueue
astar.manhattan_distance = manhattan_distance
astar.euclidean_distance = euclidean_distance
astar.chebyshev_distance = chebyshev_distance
astar.HEURISTICS = HEURISTICS
-- }}}

return astar

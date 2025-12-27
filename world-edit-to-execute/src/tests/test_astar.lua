--[[
Test suite for A* Pathfinding Algorithm
Tests priority queue, heuristics, path finding, and edge cases.
]]

-- {{{ Setup paths
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local astar = require("runtime.pathfinding.astar")
local pathfinding = require("runtime.pathfinding")
-- }}}

-- {{{ Test infrastructure
local test_count = 0
local pass_count = 0

local function test(name, condition, msg)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name .. (msg and ": " .. msg or ""))
    end
end

local function test_section(name)
    print("\n=== " .. name .. " ===")
end

local function approx_equal(a, b, tolerance)
    tolerance = tolerance or 0.001
    return math.abs(a - b) < tolerance
end
-- }}}

-- {{{ Mock grid creation
-- Creates a mock pathing grid for testing
-- Default: all cells walkable
-- walls: array of {x, y} positions that are not walkable
local function create_mock_grid(width, height, walls)
    local grid = {
        width = width,
        height = height,
        cells = {},
    }

    -- Initialize all cells as walkable
    for y = 0, height - 1 do
        grid.cells[y] = {}
        for x = 0, width - 1 do
            grid.cells[y][x] = { walkable = true }
        end
    end

    -- Apply walls
    if walls then
        for _, w in ipairs(walls) do
            if w.x >= 0 and w.x < width and w.y >= 0 and w.y < height then
                grid.cells[w.y][w.x].walkable = false
            end
        end
    end

    return grid
end
-- }}}

-- {{{ Priority Queue Tests
test_section("Priority Queue")

local PQ = astar.PriorityQueue

local pq = PQ.new()
test("new queue is empty", pq:is_empty() == true)
test("new queue has size 0", pq:size() == 0)

pq:push("a", 3)
pq:push("b", 1)
pq:push("c", 2)

test("after push size is 3", pq:size() == 3)
test("queue not empty after push", pq:is_empty() == false)

local item, priority = pq:peek()
test("peek returns lowest priority item", item == "b" and priority == 1)
test("peek doesn't remove item", pq:size() == 3)

item, priority = pq:pop()
test("pop returns lowest priority (1)", item == "b" and priority == 1)
test("after pop size is 2", pq:size() == 2)

item, priority = pq:pop()
test("second pop returns priority 2", item == "c" and priority == 2)

item, priority = pq:pop()
test("third pop returns priority 3", item == "a" and priority == 3)

test("queue empty after all pops", pq:is_empty() == true)

item = pq:pop()
test("pop from empty returns nil", item == nil)

-- Test with many items
pq = PQ.new()
for i = 100, 1, -1 do
    pq:push(i, i)
end
test("push 100 items", pq:size() == 100)

local last = 0
local in_order = true
for _ = 1, 100 do
    item, priority = pq:pop()
    if priority < last then
        in_order = false
        break
    end
    last = priority
end
test("pop 100 items in order", in_order)
-- }}}

-- {{{ Heuristic Tests
test_section("Heuristics")

-- Manhattan distance
test("manhattan (0,0) to (3,4) = 7", astar.manhattan_distance(0, 0, 3, 4) == 7)
test("manhattan (5,5) to (5,5) = 0", astar.manhattan_distance(5, 5, 5, 5) == 0)
test("manhattan (0,0) to (-3,-4) = 7", astar.manhattan_distance(0, 0, -3, -4) == 7)
test("manhattan symmetric", astar.manhattan_distance(1, 2, 5, 8) == astar.manhattan_distance(5, 8, 1, 2))

-- Euclidean distance
test("euclidean (0,0) to (3,4) = 5", approx_equal(astar.euclidean_distance(0, 0, 3, 4), 5))
test("euclidean (0,0) to (0,0) = 0", astar.euclidean_distance(0, 0, 0, 0) == 0)
test("euclidean (0,0) to (1,1) ≈ 1.414", approx_equal(astar.euclidean_distance(0, 0, 1, 1), 1.41421356))

-- Chebyshev distance
test("chebyshev (0,0) to (3,4) = 4", astar.chebyshev_distance(0, 0, 3, 4) == 4)
test("chebyshev (0,0) to (3,3) = 3", astar.chebyshev_distance(0, 0, 3, 3) == 3)
test("chebyshev (0,0) to (0,5) = 5", astar.chebyshev_distance(0, 0, 0, 5) == 5)
-- }}}

-- {{{ Simple Path Tests
test_section("Simple Paths")

-- Straight line path
local grid = create_mock_grid(10, 10)
local path, cost, err = astar.find_path(grid, 0, 0, 5, 0)

test("straight line path found", path ~= nil)
test("straight line cost = 5", cost == 5)
test("straight line path length = 6", path and #path == 6)
test("path starts at (0,0)", path and path[1].x == 0 and path[1].y == 0)
test("path ends at (5,0)", path and path[#path].x == 5 and path[#path].y == 0)

-- Vertical path
path, cost = astar.find_path(grid, 0, 0, 0, 5)
test("vertical path found", path ~= nil)
test("vertical path cost = 5", cost == 5)

-- Diagonal path (no diagonal movement)
path, cost = astar.find_path(grid, 0, 0, 3, 4)
test("diagonal (manhattan) path found", path ~= nil)
test("diagonal (manhattan) cost = 7", cost == 7)

-- Diagonal path with diagonal movement
path, cost = astar.find_path(grid, 0, 0, 3, 3, { diagonal = true })
test("diagonal movement path found", path ~= nil)
-- 3 diagonal moves at ~1.414 each ≈ 4.24
test("diagonal movement cost ≈ 4.24", cost and approx_equal(cost, 4.2426, 0.01))
-- }}}

-- {{{ Path Around Wall Tests
test_section("Path Around Obstacles")

-- Create a wall blocking direct path
-- Grid:  S # # # G
--        . . . . .
--        . . . . .
-- Wall blocks y=0, forcing path to go down around
local walls = {
    { x = 1, y = 0 },
    { x = 2, y = 0 },
    { x = 3, y = 0 },
}
grid = create_mock_grid(5, 3, walls)

path, cost = astar.find_path(grid, 0, 0, 4, 0)
test("path around wall found", path ~= nil)
-- Must go down, around, and up - longer than straight line of 4
test("path around wall cost > 4", cost and cost > 4)

-- Verify path doesn't go through walls
local through_wall = false
if path then
    for _, p in ipairs(path) do
        if not grid.cells[p.y][p.x].walkable then
            through_wall = true
            break
        end
    end
end
test("path doesn't go through wall", not through_wall)

-- Corridor path
-- Grid:  S # G
--        . # .
--        . . .
walls = {
    { x = 1, y = 0 },
    { x = 1, y = 1 },
}
grid = create_mock_grid(3, 3, walls)
path, cost = astar.find_path(grid, 0, 0, 2, 0)
test("corridor path found", path ~= nil)
test("corridor path cost = 6", cost == 6)  -- Down, right, right, up
-- }}}

-- {{{ No Path Tests
test_section("No Path Exists")

-- Completely blocked
-- Grid:  S # G
--        # # #
walls = {
    { x = 1, y = 0 },
    { x = 0, y = 1 },
    { x = 1, y = 1 },
    { x = 2, y = 1 },
}
grid = create_mock_grid(3, 2, walls)
path, cost, err = astar.find_path(grid, 0, 0, 2, 0)
test("blocked path returns nil", path == nil)
test("blocked path has error message", err ~= nil)
test("blocked path error says no path", err and err:find("No path"))

-- Start blocked
grid = create_mock_grid(5, 5)
grid.cells[0][0].walkable = false
path, cost, err = astar.find_path(grid, 0, 0, 4, 4)
test("blocked start returns nil", path == nil)
test("blocked start error message", err and err:find("Start"))

-- Goal blocked
grid = create_mock_grid(5, 5)
grid.cells[4][4].walkable = false
path, cost, err = astar.find_path(grid, 0, 0, 4, 4)
test("blocked goal returns nil", path == nil)
test("blocked goal error message", err and err:find("Goal"))
-- }}}

-- {{{ Edge Cases Tests
test_section("Edge Cases")

-- Start equals goal
grid = create_mock_grid(5, 5)
path, cost = astar.find_path(grid, 2, 2, 2, 2)
test("start == goal returns path", path ~= nil)
test("start == goal path has 1 waypoint", path and #path == 1)
test("start == goal cost = 0", cost == 0)

-- Adjacent cells
path, cost = astar.find_path(grid, 2, 2, 3, 2)
test("adjacent path found", path ~= nil)
test("adjacent path cost = 1", cost == 1)
test("adjacent path has 2 waypoints", path and #path == 2)

-- 1x1 grid
grid = create_mock_grid(1, 1)
path, cost = astar.find_path(grid, 0, 0, 0, 0)
test("1x1 grid start=goal works", path ~= nil and #path == 1)

-- Corner to corner
grid = create_mock_grid(3, 3)
path, cost = astar.find_path(grid, 0, 0, 2, 2)
test("corner to corner path found", path ~= nil)
test("corner to corner cost = 4", cost == 4)  -- Manhattan: right, right, up, up
-- }}}

-- {{{ Max Iterations Tests
test_section("Max Iterations Limit")

-- Normal search should complete quickly
grid = create_mock_grid(10, 10)
path, cost, err = astar.find_path(grid, 0, 0, 9, 9, { max_iterations = 1000 })
test("normal search within limit", path ~= nil)

-- Very low limit should fail
path, cost, err = astar.find_path(grid, 0, 0, 9, 9, { max_iterations = 5 })
test("low iteration limit returns nil", path == nil)
test("low iteration limit error message", err and err:find("iterations"))
-- }}}

-- {{{ Heuristic Options Tests
test_section("Heuristic Options")

grid = create_mock_grid(10, 10)

-- Manhattan heuristic
path, cost = astar.find_path(grid, 0, 0, 5, 5, { heuristic = "manhattan" })
test("manhattan heuristic works", path ~= nil)

-- Euclidean heuristic
path, cost = astar.find_path(grid, 0, 0, 5, 5, { heuristic = "euclidean" })
test("euclidean heuristic works", path ~= nil)

-- Chebyshev heuristic
path, cost = astar.find_path(grid, 0, 0, 5, 5, { heuristic = "chebyshev" })
test("chebyshev heuristic works", path ~= nil)

-- Invalid heuristic
path, cost, err = astar.find_path(grid, 0, 0, 5, 5, { heuristic = "invalid" })
test("invalid heuristic returns nil", path == nil)
test("invalid heuristic error message", err and err:find("Unknown heuristic"))
-- }}}

-- {{{ Custom can_pass Tests
test_section("Custom can_pass Function")

grid = create_mock_grid(10, 10)

-- Custom function that blocks a horizontal wall at x=5, y=0 to y=4
-- Path must go around by going up past y=4, then crossing, then back down
local function avoid_wall(x, y)
    -- Block x=5 only for y=0..4
    if x == 5 and y <= 4 then
        return false
    end
    return true
end

path, cost = astar.find_path(grid, 0, 0, 9, 0, { can_pass = avoid_wall })
test("custom can_pass path found", path ~= nil)
-- Path should avoid the blocked cells (x=5, y<=4)
local avoids_wall = true
if path then
    for _, p in ipairs(path) do
        if p.x == 5 and p.y <= 4 then
            avoids_wall = false
            break
        end
    end
end
test("custom can_pass avoids blocked cells", avoids_wall)

-- Custom function blocking start
path, cost, err = astar.find_path(grid, 0, 0, 4, 4, {
    can_pass = function() return false end
})
test("blocking can_pass returns nil", path == nil)
-- }}}

-- {{{ Diagonal Movement Tests
test_section("Diagonal Movement")

grid = create_mock_grid(10, 10)

-- Path with diagonal movement
local path_diag, cost_diag = astar.find_path(grid, 0, 0, 5, 5, { diagonal = true })
test("diagonal path found", path_diag ~= nil)

-- Path without diagonal movement
local path_card, cost_card = astar.find_path(grid, 0, 0, 5, 5, { diagonal = false })
test("cardinal path found", path_card ~= nil)

-- Diagonal should be shorter in cost
test("diagonal cost < cardinal cost", cost_diag < cost_card)

-- Diagonal should have fewer waypoints
test("diagonal fewer waypoints", #path_diag < #path_card)

-- Verify diagonal path uses diagonals
local has_diagonal = false
if path_diag and #path_diag >= 2 then
    for i = 2, #path_diag do
        local dx = math.abs(path_diag[i].x - path_diag[i-1].x)
        local dy = math.abs(path_diag[i].y - path_diag[i-1].y)
        if dx == 1 and dy == 1 then
            has_diagonal = true
            break
        end
    end
end
test("diagonal path uses diagonal moves", has_diagonal)
-- }}}

-- {{{ Path Length Calculation Tests
test_section("Path Length Calculation")

-- No path
test("path_length(nil) = 0", astar.path_length(nil) == 0)
test("path_length({}) = 0", astar.path_length({}) == 0)
test("path_length single point = 0", astar.path_length({{x=0, y=0}}) == 0)

-- Straight horizontal path
local h_path = {{x=0, y=0}, {x=1, y=0}, {x=2, y=0}, {x=3, y=0}}
test("horizontal path length = 3", astar.path_length(h_path) == 3)

-- Diagonal path
local d_path = {{x=0, y=0}, {x=1, y=1}, {x=2, y=2}}
test("diagonal path length ≈ 2.83", approx_equal(astar.path_length(d_path), 2.828, 0.01))
-- }}}

-- {{{ Path to String Tests
test_section("Path to String")

test("path_to_string(nil) = 'nil'", astar.path_to_string(nil) == "nil")
test("path_to_string({}) = '(empty)'", astar.path_to_string({}) == "(empty)")

local simple_path = {{x=0, y=0}, {x=1, y=0}, {x=2, y=0}}
local str = astar.path_to_string(simple_path)
test("path_to_string format", str == "(0,0) -> (1,0) -> (2,0)")
-- }}}

-- {{{ find_path_simple Tests
test_section("find_path_simple API")

grid = create_mock_grid(10, 10)

local start = { x = 0, y = 0 }
local goal = { x = 5, y = 5 }

path, cost = astar.find_path_simple(grid, start, goal)
test("find_path_simple works", path ~= nil)
test("find_path_simple correct cost", cost == 10)

path, cost = astar.find_path_simple(grid, start, goal, { diagonal = true })
test("find_path_simple with options", path ~= nil)
-- }}}

-- {{{ Performance Test
test_section("Performance")

-- 128x128 grid - typical WC3 map size
local large_grid = create_mock_grid(128, 128)

-- Add some random walls for realism
math.randomseed(42)  -- Fixed seed for reproducibility
for _ = 1, 500 do
    local wx = math.random(1, 126)
    local wy = math.random(1, 126)
    large_grid.cells[wy][wx].walkable = false
end

local start_time = os.clock()
path, cost = astar.find_path(large_grid, 0, 0, 127, 127)
local elapsed = os.clock() - start_time

test("128x128 grid finds path", path ~= nil)
test("128x128 grid < 100ms", elapsed < 0.1)

-- Multiple pathfinding calls
start_time = os.clock()
for _ = 1, 10 do
    astar.find_path(large_grid, 0, 0, 127, 127)
end
elapsed = os.clock() - start_time
test("10 paths on 128x128 < 500ms", elapsed < 0.5)
-- }}}

-- {{{ Pathfinding Module Integration Tests
test_section("Pathfinding Module Integration")

test("pathfinding.find_path exists", type(pathfinding.find_path) == "function")
test("pathfinding.find_path_simple exists", type(pathfinding.find_path_simple) == "function")
test("pathfinding.path_length exists", type(pathfinding.path_length) == "function")

grid = create_mock_grid(10, 10)
path, cost = pathfinding.find_path(grid, 0, 0, 5, 5)
test("pathfinding.find_path works", path ~= nil and cost == 10)
-- }}}

-- {{{ Summary
print("\n" .. string.rep("=", 50))
print(string.format("Tests: %d passed, %d failed", pass_count, test_count - pass_count))
if pass_count == test_count then
    print("ALL TESTS PASSED")
else
    print("SOME TESTS FAILED")
    os.exit(1)
end
-- }}}

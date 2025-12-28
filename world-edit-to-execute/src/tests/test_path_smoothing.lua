--[[
Test suite for Path Smoothing
Tests line-of-sight, collinearity, and path simplification algorithms.
]]

-- {{{ Setup paths
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local smooth = require("runtime.pathfinding.smooth")
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
-- }}}

-- {{{ Mock grid creation
local function create_mock_grid(width, height)
    local grid = {
        width = width,
        height = height,
        tile_size = 128,
        offset_x = 0,
        offset_y = 0,
        cells = {},
    }

    for y = 0, height - 1 do
        grid.cells[y] = {}
        for x = 0, width - 1 do
            grid.cells[y][x] = {
                walkable = true,
                flyable = true,
                buildable = true,
                water = false,
                water_depth = 0,
                cliff_level = 0,
            }
        end
    end

    return grid
end

local function set_blocked(grid, x, y)
    if grid.cells[y] and grid.cells[y][x] then
        grid.cells[y][x].walkable = false
    end
end

local function make_can_pass(grid)
    return function(x, y)
        local row = grid.cells[y]
        local cell = row and row[x]
        return cell and cell.walkable
    end
end
-- }}}

-- {{{ Line-of-Sight Tests
test_section("Line-of-Sight (Bresenham)")

local grid = create_mock_grid(10, 10)
local can_pass = make_can_pass(grid)

-- Horizontal line
test("horizontal LOS clear", smooth.has_line_of_sight(grid, 0, 0, 5, 0, can_pass))

-- Vertical line
test("vertical LOS clear", smooth.has_line_of_sight(grid, 0, 0, 0, 5, can_pass))

-- Diagonal line
test("diagonal LOS clear", smooth.has_line_of_sight(grid, 0, 0, 5, 5, can_pass))

-- Same point
test("same point LOS", smooth.has_line_of_sight(grid, 3, 3, 3, 3, can_pass))

-- Blocked horizontal
set_blocked(grid, 2, 0)
test("horizontal LOS blocked", not smooth.has_line_of_sight(grid, 0, 0, 5, 0, can_pass))

-- Blocked vertical
grid = create_mock_grid(10, 10)
can_pass = make_can_pass(grid)
set_blocked(grid, 0, 3)
test("vertical LOS blocked", not smooth.has_line_of_sight(grid, 0, 0, 0, 5, can_pass))

-- Blocked diagonal
grid = create_mock_grid(10, 10)
can_pass = make_can_pass(grid)
set_blocked(grid, 2, 2)
test("diagonal LOS blocked", not smooth.has_line_of_sight(grid, 0, 0, 5, 5, can_pass))

-- Steep diagonal
grid = create_mock_grid(10, 10)
can_pass = make_can_pass(grid)
test("steep diagonal LOS clear", smooth.has_line_of_sight(grid, 0, 0, 2, 5, can_pass))

-- Negative direction
test("reverse direction LOS", smooth.has_line_of_sight(grid, 5, 5, 0, 0, can_pass))

-- Just misses obstacle
grid = create_mock_grid(10, 10)
can_pass = make_can_pass(grid)
set_blocked(grid, 3, 3)
-- Line from (0,0) to (5,4) should not touch (3,3)
test("LOS that misses obstacle", smooth.has_line_of_sight(grid, 0, 0, 5, 4, can_pass))
-- }}}

-- {{{ Get Line Tiles Tests
test_section("Get Line Tiles")

local tiles = smooth.get_line_tiles(0, 0, 3, 0)
test("horizontal line has 4 tiles", #tiles == 4)
test("horizontal line starts at 0,0", tiles[1].x == 0 and tiles[1].y == 0)
test("horizontal line ends at 3,0", tiles[4].x == 3 and tiles[4].y == 0)

tiles = smooth.get_line_tiles(0, 0, 0, 3)
test("vertical line has 4 tiles", #tiles == 4)
test("vertical line ends at 0,3", tiles[4].x == 0 and tiles[4].y == 3)

tiles = smooth.get_line_tiles(0, 0, 3, 3)
test("diagonal line has 4 tiles", #tiles == 4)
test("diagonal line ends at 3,3", tiles[4].x == 3 and tiles[4].y == 3)

tiles = smooth.get_line_tiles(2, 2, 2, 2)
test("single point has 1 tile", #tiles == 1)
-- }}}

-- {{{ Collinearity Tests
test_section("Collinearity Detection")

local p1, p2, p3

-- Horizontal collinear
p1, p2, p3 = {x=0, y=0}, {x=1, y=0}, {x=2, y=0}
test("horizontal points are collinear", smooth.are_collinear(p1, p2, p3))

-- Vertical collinear
p1, p2, p3 = {x=0, y=0}, {x=0, y=1}, {x=0, y=2}
test("vertical points are collinear", smooth.are_collinear(p1, p2, p3))

-- Diagonal collinear
p1, p2, p3 = {x=0, y=0}, {x=1, y=1}, {x=2, y=2}
test("diagonal points are collinear", smooth.are_collinear(p1, p2, p3))

-- Non-collinear (L-shape)
p1, p2, p3 = {x=0, y=0}, {x=1, y=0}, {x=1, y=1}
test("L-shape is not collinear", not smooth.are_collinear(p1, p2, p3))

-- Non-collinear (diagonal turn)
p1, p2, p3 = {x=0, y=0}, {x=1, y=1}, {x=2, y=1}
test("diagonal turn is not collinear", not smooth.are_collinear(p1, p2, p3))
-- }}}

-- {{{ Remove Collinear Tests
test_section("Remove Collinear Points")

-- Straight horizontal line
local path = {{x=0, y=0}, {x=1, y=0}, {x=2, y=0}, {x=3, y=0}, {x=4, y=0}}
local smoothed = smooth.remove_collinear(path)
test("horizontal line reduces to 2 points", #smoothed == 2)
test("horizontal keeps start", smoothed[1].x == 0 and smoothed[1].y == 0)
test("horizontal keeps end", smoothed[2].x == 4 and smoothed[2].y == 0)

-- Straight diagonal line
path = {{x=0, y=0}, {x=1, y=1}, {x=2, y=2}, {x=3, y=3}}
smoothed = smooth.remove_collinear(path)
test("diagonal line reduces to 2 points", #smoothed == 2)

-- L-shaped path
path = {{x=0, y=0}, {x=1, y=0}, {x=2, y=0}, {x=2, y=1}, {x=2, y=2}}
smoothed = smooth.remove_collinear(path)
test("L-shape keeps corner", #smoothed == 3)
test("L-shape corner at (2,0)", smoothed[2].x == 2 and smoothed[2].y == 0)

-- Already minimal path
path = {{x=0, y=0}, {x=5, y=0}}
smoothed = smooth.remove_collinear(path)
test("2-point path unchanged", #smoothed == 2)

-- Single point
path = {{x=0, y=0}}
smoothed = smooth.remove_collinear(path)
test("1-point path unchanged", #smoothed == 1)

-- Nil/empty paths
test("nil path returns nil", smooth.remove_collinear(nil) == nil)
-- }}}

-- {{{ Smooth Path Tests (LOS-based)
test_section("Smooth Path (Line-of-Sight)")

grid = create_mock_grid(10, 10)
can_pass = make_can_pass(grid)

-- Straight horizontal line in open grid
path = {{x=0, y=0}, {x=1, y=0}, {x=2, y=0}, {x=3, y=0}, {x=4, y=0}}
smoothed = smooth.smooth_path(path, grid, can_pass)
test("open horizontal reduces to 2", #smoothed == 2)

-- Straight diagonal
path = {{x=0, y=0}, {x=1, y=1}, {x=2, y=2}, {x=3, y=3}, {x=4, y=4}}
smoothed = smooth.smooth_path(path, grid, can_pass)
test("open diagonal reduces to 2", #smoothed == 2)

-- Path around obstacle
grid = create_mock_grid(10, 10)
set_blocked(grid, 2, 0)
set_blocked(grid, 2, 1)
can_pass = make_can_pass(grid)
-- Path goes: (0,0) -> (1,0) -> (1,1) -> (2,2) -> (3,1) -> (3,0) -> (4,0)
path = {
    {x=0, y=0}, {x=1, y=0}, {x=1, y=1}, {x=1, y=2},
    {x=2, y=2}, {x=3, y=2}, {x=3, y=1}, {x=3, y=0}, {x=4, y=0}
}
smoothed = smooth.smooth_path(path, grid, can_pass)
test("obstacle path keeps necessary points", #smoothed >= 2)
test("obstacle path keeps start", smoothed[1].x == 0 and smoothed[1].y == 0)
test("obstacle path keeps end", smoothed[#smoothed].x == 4 and smoothed[#smoothed].y == 0)

-- Verify smoothed path doesn't shortcut through obstacle
local valid = true
for i = 1, #smoothed - 1 do
    local from, to = smoothed[i], smoothed[i + 1]
    if not smooth.has_line_of_sight(grid, from.x, from.y, to.x, to.y, can_pass) then
        valid = false
        break
    end
end
test("smoothed path segments are all valid", valid)

-- Empty/small paths
test("nil path returns nil", smooth.smooth_path(nil, grid, can_pass) == nil)
path = {{x=0, y=0}}
test("1-point path unchanged", #smooth.smooth_path(path, grid, can_pass) == 1)
path = {{x=0, y=0}, {x=1, y=0}}
test("2-point path unchanged", #smooth.smooth_path(path, grid, can_pass) == 2)
-- }}}

-- {{{ Smooth Greedy Tests
test_section("Smooth Greedy (Binary Search)")

grid = create_mock_grid(10, 10)
can_pass = make_can_pass(grid)

-- Open grid direct to goal
path = {{x=0, y=0}, {x=1, y=0}, {x=2, y=0}, {x=3, y=0}, {x=4, y=0}, {x=5, y=0}}
smoothed = smooth.smooth_greedy(path, grid, can_pass)
test("greedy open path to 2", #smoothed == 2)

-- Large diagonal
path = {}
for i = 0, 9 do
    path[i + 1] = {x = i, y = i}
end
smoothed = smooth.smooth_greedy(path, grid, can_pass)
test("greedy diagonal to 2", #smoothed == 2)

-- Path with obstacle blocks direct route
grid = create_mock_grid(10, 10)
set_blocked(grid, 5, 5)
can_pass = make_can_pass(grid)
path = {}
for i = 0, 4 do
    path[i + 1] = {x = i, y = i}
end
path[6] = {x = 4, y = 5}
path[7] = {x = 4, y = 6}
for i = 5, 9 do
    path[i + 3] = {x = i, y = i}
end
smoothed = smooth.smooth_greedy(path, grid, can_pass)
test("greedy with obstacle keeps some points", #smoothed >= 2 and #smoothed < #path)
-- }}}

-- {{{ Smooth Path for Movement Tests
test_section("Combined Smoothing (smooth_path_for_movement)")

grid = create_mock_grid(10, 10)
can_pass = make_can_pass(grid)

-- Long straight path
path = {}
for i = 0, 9 do
    path[i + 1] = {x = i, y = 0}
end
smoothed = smooth.smooth_path_for_movement(path, grid, can_pass)
test("movement smooth long line to 2", #smoothed == 2)

-- Empty path handling
test("movement smooth nil", smooth.smooth_path_for_movement(nil, grid, can_pass) == nil)
path = {{x=0, y=0}}
test("movement smooth 1 point", #smooth.smooth_path_for_movement(path, grid, can_pass) == 1)
-- }}}

-- {{{ Path Stats Tests
test_section("Path Statistics")

local original = {{x=0, y=0}, {x=1, y=0}, {x=2, y=0}, {x=3, y=0}, {x=4, y=0}}
local simplified = {{x=0, y=0}, {x=4, y=0}}

local stats = smooth.path_stats(original, simplified)
test("stats original count", stats.original_count == 5)
test("stats smoothed count", stats.smoothed_count == 2)
test("stats reduction 60%", stats.reduction_percent == 60)

stats = smooth.path_stats(nil, nil)
test("stats nil paths", stats.original_count == 0 and stats.smoothed_count == 0)

stats = smooth.path_stats(original, original)
test("stats no reduction", stats.reduction_percent == 0)
-- }}}

-- {{{ Edge Cases
test_section("Edge Cases")

grid = create_mock_grid(10, 10)
can_pass = make_can_pass(grid)

-- Very short paths
path = {}
smoothed = smooth.smooth_path(path, grid, can_pass)
test("empty path returns empty", smoothed == path or #smoothed == 0 or smoothed == nil)

-- Default can_pass (nil)
grid = create_mock_grid(5, 5)
path = {{x=0, y=0}, {x=1, y=0}, {x=2, y=0}}
smoothed = smooth.smooth_path(path, grid, nil)
test("default can_pass works", #smoothed == 2)

-- Path along grid edge
grid = create_mock_grid(10, 10)
can_pass = make_can_pass(grid)
path = {{x=0, y=0}, {x=1, y=0}, {x=2, y=0}, {x=3, y=0}}
smoothed = smooth.smooth_path(path, grid, can_pass)
test("edge path smooths correctly", #smoothed == 2)

-- Zig-zag path
path = {
    {x=0, y=0}, {x=1, y=1}, {x=2, y=0}, {x=3, y=1}, {x=4, y=0}
}
smoothed = smooth.remove_collinear(path)
test("zig-zag keeps all direction changes", #smoothed == 5)
-- }}}

-- {{{ Integration with Pathfinding Module
test_section("Pathfinding Module Integration")

-- Check exports
test("pathfinding.smooth_path exists", type(pathfinding.smooth_path) == "function")
test("pathfinding.smooth_greedy exists", type(pathfinding.smooth_greedy) == "function")
test("pathfinding.remove_collinear exists", type(pathfinding.remove_collinear) == "function")
test("pathfinding.has_line_of_sight exists", type(pathfinding.has_line_of_sight) == "function")
test("pathfinding.path_stats exists", type(pathfinding.path_stats) == "function")
-- }}}

-- {{{ Performance Test
test_section("Performance")

grid = create_mock_grid(128, 128)
can_pass = make_can_pass(grid)

-- Create long path (simulating worst-case A* output)
path = {}
for i = 0, 127 do
    path[i + 1] = {x = i, y = 0}
end

local start_time = os.clock()
for _ = 1, 100 do
    smooth.smooth_path(path, grid, can_pass)
end
local elapsed = os.clock() - start_time

test("smooth 128-point path x100 < 1s", elapsed < 1.0,
    string.format("took %.3fs", elapsed))

-- Greedy should be faster
start_time = os.clock()
for _ = 1, 100 do
    smooth.smooth_greedy(path, grid, can_pass)
end
elapsed = os.clock() - start_time
test("greedy 128-point path x100 < 1s", elapsed < 1.0,
    string.format("took %.3fs", elapsed))

-- Collinear is very fast
start_time = os.clock()
for _ = 1, 1000 do
    smooth.remove_collinear(path)
end
elapsed = os.clock() - start_time
test("collinear 128-point path x1000 < 1s", elapsed < 1.0,
    string.format("took %.3fs", elapsed))
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

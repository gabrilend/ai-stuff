--[[
Test suite for Pathfinding Coordinate Conversion
Tests world-grid conversion, bounds checking, and path conversion.
]]

-- {{{ Setup paths
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local coords = require("runtime.pathfinding.coords")
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
-- Creates a mock grid for testing coordinate conversion
-- Standard WC3 map: 128 tiles, 128 world units per tile, centered at origin
local function create_centered_grid(tile_count)
    tile_count = tile_count or 128
    local world_size = tile_count * 128  -- 128 tiles * 128 units = 16384 units
    return {
        width = tile_count,
        height = tile_count,
        tile_size = 128,
        offset_x = -world_size / 2,  -- e.g., -8192 for 128x128
        offset_y = -world_size / 2,
    }
end

-- Small test grid for easier verification
local function create_simple_grid(width, height, tile_size)
    width = width or 10
    height = height or 10
    tile_size = tile_size or 128
    return {
        width = width,
        height = height,
        tile_size = tile_size,
        offset_x = 0,
        offset_y = 0,
    }
end
-- }}}

-- {{{ Active Grid Tests
test_section("Active Grid Management")

test("get_grid returns nil initially", coords.get_grid() == nil)

local grid = create_simple_grid(10, 10)
coords.set_grid(grid)
test("set_grid stores grid", coords.get_grid() == grid)

coords.clear_grid()
test("clear_grid removes grid", coords.get_grid() == nil)

-- Restore for subsequent tests
coords.set_grid(grid)
-- }}}

-- {{{ World to Grid Tests
test_section("World to Grid Conversion")

-- Simple 10x10 grid with offset 0,0, tile size 128
-- Tile 0 covers world [0, 128), tile 1 covers [128, 256), etc.

local gx, gy, err = coords.world_to_grid(0, 0, grid)
test("origin (0,0) maps to tile (0,0)", gx == 0 and gy == 0)

gx, gy = coords.world_to_grid(64, 64, grid)
test("center of tile 0 (64,64) maps to (0,0)", gx == 0 and gy == 0)

gx, gy = coords.world_to_grid(127, 127, grid)
test("edge of tile 0 (127,127) maps to (0,0)", gx == 0 and gy == 0)

gx, gy = coords.world_to_grid(128, 128, grid)
test("start of tile 1 (128,128) maps to (1,1)", gx == 1 and gy == 1)

gx, gy = coords.world_to_grid(640, 384, grid)
test("(640,384) maps to (5,3)", gx == 5 and gy == 3)

-- Last valid tile
gx, gy = coords.world_to_grid(1279, 1279, grid)  -- 10*128 - 1 = 1279
test("last valid position (1279,1279) maps to (9,9)", gx == 9 and gy == 9)

-- Out of bounds
gx, gy, err = coords.world_to_grid(-1, 0, grid)
test("negative X returns nil", gx == nil)
test("negative X error mentions bounds", err and err:find("bounds"))

gx, gy, err = coords.world_to_grid(0, -1, grid)
test("negative Y returns nil", gx == nil)

gx, gy, err = coords.world_to_grid(1280, 0, grid)  -- 10*128 = 1280, out of bounds
test("X at grid edge returns nil", gx == nil)

gx, gy, err = coords.world_to_grid(0, 1280, grid)
test("Y at grid edge returns nil", gx == nil)
-- }}}

-- {{{ Grid to World Tests
test_section("Grid to World Conversion")

-- Should return tile centers
local wx, wy = coords.grid_to_world(0, 0, grid)
test("tile (0,0) center at (64,64)", wx == 64 and wy == 64)

wx, wy = coords.grid_to_world(1, 1, grid)
test("tile (1,1) center at (192,192)", wx == 192 and wy == 192)

wx, wy = coords.grid_to_world(5, 3, grid)
test("tile (5,3) center at (704,448)", wx == 704 and wy == 448)

wx, wy = coords.grid_to_world(9, 9, grid)
test("tile (9,9) center at (1216,1216)", wx == 1216 and wy == 1216)

-- Test corner conversion
wx, wy = coords.grid_to_world_corner(0, 0, grid)
test("tile (0,0) corner at (0,0)", wx == 0 and wy == 0)

wx, wy = coords.grid_to_world_corner(1, 1, grid)
test("tile (1,1) corner at (128,128)", wx == 128 and wy == 128)
-- }}}

-- {{{ Round Trip Tests
test_section("Round Trip Conversion")

-- World -> Grid -> World should return tile center
local test_points = {
    {0, 0},
    {64, 64},
    {100, 200},
    {500, 700},
    {1000, 1000},
}

for _, pt in ipairs(test_points) do
    gx, gy = coords.world_to_grid(pt[1], pt[2], grid)
    wx, wy = coords.grid_to_world(gx, gy, grid)
    -- Result should be tile center
    local expected_x = math.floor(pt[1] / 128) * 128 + 64
    local expected_y = math.floor(pt[2] / 128) * 128 + 64
    test(string.format("round trip (%d,%d) -> tile center", pt[1], pt[2]),
         wx == expected_x and wy == expected_y)
end
-- }}}

-- {{{ Centered Grid Tests
test_section("Centered Grid (Negative Offsets)")

-- Typical WC3 map: 128x128 centered at origin
local centered = create_centered_grid(128)
-- offset_x = offset_y = -8192
-- World range: [-8192, 8192)
-- Tile 0 at [-8192, -8064), tile 64 at [0, 128), tile 127 at [8064, 8192)

gx, gy = coords.world_to_grid(-8192, -8192, centered)
test("centered: (-8192,-8192) maps to (0,0)", gx == 0 and gy == 0)

gx, gy = coords.world_to_grid(0, 0, centered)
test("centered: (0,0) maps to (64,64)", gx == 64 and gy == 64)

gx, gy = coords.world_to_grid(8191, 8191, centered)
test("centered: (8191,8191) maps to (127,127)", gx == 127 and gy == 127)

wx, wy = coords.grid_to_world(0, 0, centered)
test("centered: tile (0,0) center at (-8128,-8128)", wx == -8128 and wy == -8128)

wx, wy = coords.grid_to_world(64, 64, centered)
test("centered: tile (64,64) center at (64,64)", wx == 64 and wy == 64)

-- Out of bounds for centered grid
gx, gy, err = coords.world_to_grid(-8193, 0, centered)
test("centered: -8193 X out of bounds", gx == nil)

gx, gy, err = coords.world_to_grid(8192, 0, centered)
test("centered: 8192 X out of bounds", gx == nil)
-- }}}

-- {{{ Clamped Conversion Tests
test_section("Clamped Conversion")

gx, gy = coords.world_to_grid_clamped(-100, -100, grid)
test("clamped: negative clamps to (0,0)", gx == 0 and gy == 0)

gx, gy = coords.world_to_grid_clamped(2000, 3000, grid)
test("clamped: large positive clamps to (9,9)", gx == 9 and gy == 9)

gx, gy = coords.world_to_grid_clamped(-100, 500, grid)
test("clamped: mixed clamps X only", gx == 0 and gy == 3)

gx, gy = coords.world_to_grid_clamped(500, 5000, grid)
test("clamped: mixed clamps Y only", gx == 3 and gy == 9)

-- Valid position should return normally
gx, gy = coords.world_to_grid_clamped(500, 600, grid)
test("clamped: valid position unchanged", gx == 3 and gy == 4)
-- }}}

-- {{{ Bounds Check Tests
test_section("Bounds Checking")

test("is_in_bounds (0,0) true", coords.is_in_bounds(0, 0, grid) == true)
test("is_in_bounds (640,640) true", coords.is_in_bounds(640, 640, grid) == true)
test("is_in_bounds (1279,1279) true", coords.is_in_bounds(1279, 1279, grid) == true)
test("is_in_bounds (-1,0) false", coords.is_in_bounds(-1, 0, grid) == false)
test("is_in_bounds (0,-1) false", coords.is_in_bounds(0, -1, grid) == false)
test("is_in_bounds (1280,0) false", coords.is_in_bounds(1280, 0, grid) == false)
test("is_in_bounds (0,1280) false", coords.is_in_bounds(0, 1280, grid) == false)

test("is_tile_in_bounds (0,0) true", coords.is_tile_in_bounds(0, 0, grid) == true)
test("is_tile_in_bounds (9,9) true", coords.is_tile_in_bounds(9, 9, grid) == true)
test("is_tile_in_bounds (-1,0) false", coords.is_tile_in_bounds(-1, 0, grid) == false)
test("is_tile_in_bounds (10,0) false", coords.is_tile_in_bounds(10, 0, grid) == false)

local min_x, min_y, max_x, max_y = coords.get_grid_bounds(grid)
test("get_grid_bounds min_x", min_x == 0)
test("get_grid_bounds min_y", min_y == 0)
test("get_grid_bounds max_x", max_x == 1280)
test("get_grid_bounds max_y", max_y == 1280)

-- Centered grid bounds
min_x, min_y, max_x, max_y = coords.get_grid_bounds(centered)
test("centered bounds min_x", min_x == -8192)
test("centered bounds max_x", max_x == 8192)
-- }}}

-- {{{ Path Conversion Tests
test_section("Path Conversion")

local grid_path = {
    {x = 0, y = 0},
    {x = 1, y = 0},
    {x = 2, y = 1},
    {x = 3, y = 2},
}

local world_path = coords.path_to_world(grid_path, grid)
test("path_to_world returns table", type(world_path) == "table")
test("path_to_world preserves length", #world_path == 4)
test("path_to_world first point (64,64)", world_path[1].x == 64 and world_path[1].y == 64)
test("path_to_world second point (192,64)", world_path[2].x == 192 and world_path[2].y == 64)
test("path_to_world third point (320,192)", world_path[3].x == 320 and world_path[3].y == 192)

test("path_to_world nil input", coords.path_to_world(nil, grid) == nil)
test("path_to_world empty table", #coords.path_to_world({}, grid) == 0)

-- Path to grid
local world_path_input = {
    {x = 50, y = 50},
    {x = 200, y = 100},
    {x = 400, y = 300},
}

local converted_grid_path = coords.path_to_grid(world_path_input, grid)
test("path_to_grid returns table", type(converted_grid_path) == "table")
test("path_to_grid first (0,0)", converted_grid_path[1].x == 0 and converted_grid_path[1].y == 0)
test("path_to_grid second (1,0)", converted_grid_path[2].x == 1 and converted_grid_path[2].y == 0)
test("path_to_grid third (3,2)", converted_grid_path[3].x == 3 and converted_grid_path[3].y == 2)

-- Out of bounds in path
local bad_path = {
    {x = 50, y = 50},
    {x = 5000, y = 5000},  -- Out of bounds
}
local result, err = coords.path_to_grid(bad_path, grid)
test("path_to_grid with OOB returns nil", result == nil)
test("path_to_grid with OOB has error", err and err:find("Waypoint 2"))
-- }}}

-- {{{ Distance Calculation Tests
test_section("Distance Calculations")

test("world_distance (0,0)-(3,4) = 5", coords.world_distance(0, 0, 3, 4) == 5)
test("world_distance (0,0)-(0,0) = 0", coords.world_distance(0, 0, 0, 0) == 0)
test("world_distance negative", approx_equal(coords.world_distance(-5, -5, 5, 5), 14.142, 0.01))

test("world_distance_squared (0,0)-(3,4) = 25", coords.world_distance_squared(0, 0, 3, 4) == 25)

test("grid_distance_manhattan (0,0)-(3,4) = 7", coords.grid_distance_manhattan(0, 0, 3, 4) == 7)
test("grid_distance_manhattan same point = 0", coords.grid_distance_manhattan(5, 5, 5, 5) == 0)

test("grid_distance_chebyshev (0,0)-(3,4) = 4", coords.grid_distance_chebyshev(0, 0, 3, 4) == 4)
test("grid_distance_chebyshev (0,0)-(5,5) = 5", coords.grid_distance_chebyshev(0, 0, 5, 5) == 5)

test("tiles_to_world_distance 1 tile = 128", coords.tiles_to_world_distance(1, grid) == 128)
test("tiles_to_world_distance 5 tiles = 640", coords.tiles_to_world_distance(5, grid) == 640)

test("world_to_tiles_distance 128 = 1", coords.world_to_tiles_distance(128, grid) == 1)
test("world_to_tiles_distance 256 = 2", coords.world_to_tiles_distance(256, grid) == 2)
test("world_to_tiles_distance 64 = 0.5", coords.world_to_tiles_distance(64, grid) == 0.5)
-- }}}

-- {{{ Active Grid Auto-Use Tests
test_section("Active Grid Usage")

coords.set_grid(grid)

-- These should work without explicit grid parameter
gx, gy = coords.world_to_grid(64, 64)
test("world_to_grid uses active grid", gx == 0 and gy == 0)

wx, wy = coords.grid_to_world(0, 0)
test("grid_to_world uses active grid", wx == 64 and wy == 64)

test("is_in_bounds uses active grid", coords.is_in_bounds(500, 500) == true)

gx, gy = coords.world_to_grid_clamped(-100, -100)
test("clamped uses active grid", gx == 0 and gy == 0)

local wp = coords.path_to_world({{x=0, y=0}})
test("path_to_world uses active grid", wp[1].x == 64)
-- }}}

-- {{{ Error Handling Tests
test_section("Error Handling")

coords.clear_grid()

local ok, err = pcall(function()
    coords.grid_to_world(0, 0)
end)
test("grid_to_world errors without grid", not ok)

gx, gy, err = coords.world_to_grid(100, 100)
test("world_to_grid returns nil without grid", gx == nil)
test("world_to_grid returns error without grid", err and err:find("No grid"))

test("is_in_bounds returns false without grid", coords.is_in_bounds(100, 100) == false)
test("is_tile_in_bounds returns false without grid", coords.is_tile_in_bounds(0, 0) == false)
test("get_grid_bounds returns nil without grid", coords.get_grid_bounds() == nil)

-- path_to_grid without grid
result, err = coords.path_to_grid({{x=0, y=0}})
test("path_to_grid returns nil without grid", result == nil)
-- }}}

-- {{{ Pathfinding Module Integration Tests
test_section("Pathfinding Module Integration")

test("pathfinding.world_to_grid exists", type(pathfinding.world_to_grid) == "function")
test("pathfinding.grid_to_world exists", type(pathfinding.grid_to_world) == "function")
test("pathfinding.is_in_bounds exists", type(pathfinding.is_in_bounds) == "function")
test("pathfinding.world_to_grid_clamped exists", type(pathfinding.world_to_grid_clamped) == "function")
test("pathfinding.path_to_world exists", type(pathfinding.path_to_world) == "function")
test("pathfinding.set_grid exists", type(pathfinding.set_grid) == "function")

-- Test via pathfinding module
pathfinding.set_grid(grid)
gx, gy = pathfinding.world_to_grid(64, 64)
test("pathfinding.world_to_grid works", gx == 0 and gy == 0)
-- }}}

-- {{{ Summary
coords.clear_grid()  -- Cleanup
print("\n" .. string.rep("=", 50))
print(string.format("Tests: %d passed, %d failed", pass_count, test_count - pass_count))
if pass_count == test_count then
    print("ALL TESTS PASSED")
else
    print("SOME TESTS FAILED")
    os.exit(1)
end
-- }}}

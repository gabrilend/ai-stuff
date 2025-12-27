--[[
Test suite for Pathing Grid module
Tests grid construction from terrain data, walkability, and caching.
]]

-- {{{ Setup paths
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local grid = require("runtime.pathfinding.grid")
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

-- {{{ Mock terrain creation
-- Creates a mock terrain object that mimics w3e parser output
local function create_mock_terrain(width, height, tiles)
    local terrain = {
        width = width,
        height = height,
        offset_x = -(width * 64),  -- Centered at origin
        offset_y = -(height * 64),
        tilepoints = {},
    }

    -- Initialize with default tiles
    for y = 0, height - 1 do
        terrain.tilepoints[y] = {}
        for x = 0, width - 1 do
            terrain.tilepoints[y][x] = {
                height = 0,
                water_level = 0,
                has_water = false,
                is_boundary = false,
                boundary = false,
                is_ramp = false,
                is_blight = false,
                layer_height = 0,
            }
        end
    end

    -- Apply custom tile overrides
    if tiles then
        for _, t in ipairs(tiles) do
            local x, y = t.x, t.y
            if x >= 0 and x < width and y >= 0 and y < height then
                for k, v in pairs(t) do
                    if k ~= "x" and k ~= "y" then
                        terrain.tilepoints[y][x][k] = v
                    end
                end
            end
        end
    end

    -- Add get_tile method
    function terrain:get_tile(x, y)
        if x < 0 or x >= self.width or y < 0 or y >= self.height then
            return nil
        end
        return self.tilepoints[y] and self.tilepoints[y][x]
    end

    return terrain
end
-- }}}

-- {{{ Constants Tests
test_section("Constants")

test("TILE_SIZE is 128", grid.TILE_SIZE == 128)
test("WADE_DEPTH is 64", grid.WADE_DEPTH == 64)
test("CLIFF_BLOCK_THRESHOLD is 1", grid.CLIFF_BLOCK_THRESHOLD == 1)

test("pathfinding exports TILE_SIZE", pathfinding.TILE_SIZE == 128)
test("pathfinding exports WADE_DEPTH", pathfinding.WADE_DEPTH == 64)
-- }}}

-- {{{ Basic Grid Construction Tests
test_section("Basic Grid Construction")

local terrain = create_mock_terrain(10, 10)
local pg = grid.build_from_terrain(terrain)

test("grid has correct width", pg.width == 10)
test("grid has correct height", pg.height == 10)
test("grid has tile_size", pg.tile_size == 128)
test("grid has offset_x", pg.offset_x == -640)
test("grid has offset_y", pg.offset_y == -640)
test("grid has cells table", pg.cells ~= nil)
test("cell (0,0) exists", pg.cells[0] and pg.cells[0][0] ~= nil)
test("cell (9,9) exists", pg.cells[9] and pg.cells[9][9] ~= nil)
-- }}}

-- {{{ Cell Properties Tests
test_section("Cell Properties")

local cell = grid.get_cell(pg, 5, 5)
test("cell has walkable property", cell.walkable ~= nil)
test("cell has flyable property", cell.flyable ~= nil)
test("cell has buildable property", cell.buildable ~= nil)
test("cell has water property", cell.water ~= nil)
test("cell has water_depth property", cell.water_depth ~= nil)
test("cell has cliff_level property", cell.cliff_level ~= nil)
test("cell has is_ramp property", cell.is_ramp ~= nil)
test("cell has is_blight property", cell.is_blight ~= nil)

-- Default terrain should be fully walkable
test("default cell is walkable", cell.walkable == true)
test("default cell is flyable", cell.flyable == true)
test("default cell is buildable", cell.buildable == true)
test("default cell has no water", cell.water == false)
test("default cell cliff_level is 0", cell.cliff_level == 0)
-- }}}

-- {{{ Accessor Functions Tests
test_section("Accessor Functions")

test("is_walkable returns true for valid cell", grid.is_walkable(pg, 5, 5) == true)
test("is_flyable returns true for valid cell", grid.is_flyable(pg, 5, 5) == true)
test("is_buildable returns true for valid cell", grid.is_buildable(pg, 5, 5) == true)
test("has_water returns false for default cell", grid.has_water(pg, 5, 5) == false)
test("get_cliff_level returns 0 for default cell", grid.get_cliff_level(pg, 5, 5) == 0)

-- Out of bounds
test("get_cell returns nil for negative x", grid.get_cell(pg, -1, 5) == nil)
test("get_cell returns nil for negative y", grid.get_cell(pg, 5, -1) == nil)
test("get_cell returns nil for x >= width", grid.get_cell(pg, 10, 5) == nil)
test("get_cell returns nil for y >= height", grid.get_cell(pg, 5, 10) == nil)
test("is_walkable returns false for out of bounds", grid.is_walkable(pg, -1, 5) == false)
test("is_flyable returns false for out of bounds", grid.is_flyable(pg, 100, 5) == false)
-- }}}

-- {{{ Water Blocking Tests
test_section("Water Blocking")

terrain = create_mock_terrain(10, 10, {
    {x = 2, y = 2, has_water = true, water_level = 100},  -- Deep water
    {x = 3, y = 3, has_water = true, water_level = 30},   -- Shallow water (wadeable)
    {x = 4, y = 4, has_water = true, water_level = 64},   -- Exactly at wade depth
    {x = 5, y = 5, has_water = true, water_level = 65},   -- Just over wade depth
})
pg = grid.build_from_terrain(terrain)

test("deep water not walkable", grid.is_walkable(pg, 2, 2) == false)
test("deep water is flyable", grid.is_flyable(pg, 2, 2) == true)
test("deep water has water flag", grid.has_water(pg, 2, 2) == true)
test("deep water not buildable", grid.is_buildable(pg, 2, 2) == false)

test("shallow water is walkable", grid.is_walkable(pg, 3, 3) == true)
test("shallow water has water flag", grid.has_water(pg, 3, 3) == true)
test("shallow water not buildable", grid.is_buildable(pg, 3, 3) == false)

test("water at wade depth is walkable", grid.is_walkable(pg, 4, 4) == true)
test("water just over wade depth not walkable", grid.is_walkable(pg, 5, 5) == false)
-- }}}

-- {{{ Boundary Blocking Tests
test_section("Boundary Blocking")

terrain = create_mock_terrain(10, 10, {
    {x = 1, y = 1, is_boundary = true},
    {x = 2, y = 2, boundary = true},  -- Alternative flag
})
pg = grid.build_from_terrain(terrain)

test("is_boundary tile not walkable", grid.is_walkable(pg, 1, 1) == false)
test("is_boundary tile is flyable", grid.is_flyable(pg, 1, 1) == true)
test("boundary tile not walkable", grid.is_walkable(pg, 2, 2) == false)
test("boundary tile not buildable", grid.is_buildable(pg, 1, 1) == false)
-- }}}

-- {{{ Cliff Edge Tests
test_section("Cliff Edge Blocking")

-- Create terrain with cliff levels
-- Cliff at level 1 next to ground at level 0 should block
terrain = create_mock_terrain(10, 10, {
    -- Ground level 0
    {x = 3, y = 5, layer_height = 0},
    -- Cliff level 1 adjacent
    {x = 4, y = 5, layer_height = 1},
    {x = 5, y = 5, layer_height = 1},
    -- Back to level 0
    {x = 6, y = 5, layer_height = 0},
})
pg = grid.build_from_terrain(terrain)

-- The tile AT the cliff edge should be blocked (has neighbor with different level)
test("tile at cliff edge (3,5) not walkable", grid.is_walkable(pg, 3, 5) == false)
test("tile at cliff edge (4,5) not walkable", grid.is_walkable(pg, 4, 5) == false)
test("tile at cliff edge (5,5) not walkable", grid.is_walkable(pg, 5, 5) == false)
test("tile at cliff edge (6,5) not walkable", grid.is_walkable(pg, 6, 5) == false)

-- Tiles away from edges should be walkable
test("tile away from edge (2,5) walkable", grid.is_walkable(pg, 2, 5) == true)
test("tile away from edge (7,5) walkable", grid.is_walkable(pg, 7, 5) == true)

-- Cliff level should be stored
test("cliff level at (4,5) is 1", grid.get_cliff_level(pg, 4, 5) == 1)
test("cliff level at (3,5) is 0", grid.get_cliff_level(pg, 3, 5) == 0)
-- }}}

-- {{{ Ramp Tests
test_section("Ramp Handling")

-- Ramps should allow movement between cliff levels
terrain = create_mock_terrain(10, 10, {
    -- Ground level 0
    {x = 3, y = 5, layer_height = 0},
    -- Ramp connecting levels
    {x = 4, y = 5, layer_height = 0, is_ramp = true},
    -- Cliff level 1 (entire plateau)
    {x = 5, y = 5, layer_height = 1},
    {x = 6, y = 5, layer_height = 1},  -- Same level, no cliff edge
    {x = 5, y = 4, layer_height = 1},  -- Same level below
    {x = 5, y = 6, layer_height = 1},  -- Same level above
})
pg = grid.build_from_terrain(terrain)

-- Ramp tiles should be walkable even with adjacent cliff
test("ramp tile is walkable", grid.is_walkable(pg, 4, 5) == true)
test("tile adjacent to ramp (3,5) is walkable", grid.is_walkable(pg, 3, 5) == true)
-- Interior of cliff plateau should be walkable (all neighbors same level or ramp)
test("cliff tile on plateau (5,5) walkable", grid.is_walkable(pg, 5, 5) == true)

-- Ramps should not be buildable
test("ramp tile not buildable", grid.is_buildable(pg, 4, 5) == false)
-- }}}

-- {{{ Blight Tests
test_section("Blight Handling")

terrain = create_mock_terrain(10, 10, {
    {x = 5, y = 5, is_blight = true},
})
pg = grid.build_from_terrain(terrain)

test("blighted tile is walkable", grid.is_walkable(pg, 5, 5) == true)
test("blighted tile is buildable", grid.is_buildable(pg, 5, 5) == true)
test("blighted tile has blight flag", pg.cells[5][5].is_blight == true)
-- }}}

-- {{{ Grid Caching Tests
test_section("Grid Caching")

terrain = create_mock_terrain(5, 5)
local pg1 = grid.build_cached(terrain)
local pg2 = grid.build_cached(terrain)

test("cached returns same grid", pg1 == pg2)

grid.invalidate_cache()
local pg3 = grid.build_cached(terrain)
test("after invalidate returns new grid", pg1 ~= pg3)

-- Different terrain should return different grid
local terrain2 = create_mock_terrain(6, 6)
local pg4 = grid.build_cached(terrain2)
test("different terrain returns different grid", pg3 ~= pg4)

grid.invalidate_cache()  -- Clean up
-- }}}

-- {{{ Statistics Tests
test_section("Statistics")

terrain = create_mock_terrain(5, 5, {
    {x = 0, y = 0, has_water = true, water_level = 100},  -- Deep water
    {x = 1, y = 0, has_water = true, water_level = 100},
    {x = 2, y = 0, is_blight = true},
    {x = 3, y = 0, layer_height = 1},
    {x = 4, y = 0, layer_height = 1},
    {x = 0, y = 1, is_ramp = true},
})
pg = grid.build_from_terrain(terrain)
local stats = grid.stats(pg)

test("stats has total_cells", stats.total_cells == 25)
test("stats has walkable_cells", stats.walkable_cells ~= nil)
test("stats has water_cells (2)", stats.water_cells == 2)
test("stats has blight_cells (1)", stats.blight_cells == 1)
test("stats has ramp_cells (1)", stats.ramp_cells == 1)
test("stats has cliff_levels table", type(stats.cliff_levels) == "table")
test("stats cliff_levels[0] exists", stats.cliff_levels[0] ~= nil)
test("stats cliff_levels[1] = 2", stats.cliff_levels[1] == 2)
-- }}}

-- {{{ Pathfinding Module Integration Tests
test_section("Pathfinding Module Integration")

terrain = create_mock_terrain(10, 10)

test("pathfinding.build_grid exists", type(pathfinding.build_grid) == "function")
test("pathfinding.is_walkable exists", type(pathfinding.is_walkable) == "function")
test("pathfinding.grid_stats exists", type(pathfinding.grid_stats) == "function")

pg = pathfinding.build_grid(terrain)
test("pathfinding.build_grid works", pg ~= nil and pg.width == 10)
test("pathfinding.is_walkable works", pathfinding.is_walkable(pg, 5, 5) == true)
test("pathfinding.is_flyable works", pathfinding.is_flyable(pg, 5, 5) == true)
test("pathfinding.is_buildable works", pathfinding.is_buildable(pg, 5, 5) == true)
test("pathfinding.has_water works", pathfinding.has_water(pg, 5, 5) == false)
test("pathfinding.get_cliff_level works", pathfinding.get_cliff_level(pg, 5, 5) == 0)
test("pathfinding.get_cell works", pathfinding.get_cell(pg, 5, 5) ~= nil)
-- }}}

-- {{{ Error Handling Tests
test_section("Error Handling")

local ok, err = pcall(function()
    grid.build_from_terrain(nil)
end)
test("build_from_terrain errors on nil terrain", not ok)
test("error message mentions terrain", err and err:find("terrain"))

-- get_cell should handle nil grid gracefully
test("get_cell returns nil for nil grid", grid.get_cell(nil, 0, 0) == nil)
-- }}}

-- {{{ Edge Cases Tests
test_section("Edge Cases")

-- Empty terrain
terrain = create_mock_terrain(1, 1)
pg = grid.build_from_terrain(terrain)
test("1x1 terrain works", pg.width == 1 and pg.height == 1)
test("1x1 cell exists", grid.get_cell(pg, 0, 0) ~= nil)

-- Large terrain dimensions
terrain = create_mock_terrain(256, 256)
pg = grid.build_from_terrain(terrain)
test("256x256 terrain works", pg.width == 256 and pg.height == 256)
test("256x256 corner cell exists", grid.get_cell(pg, 255, 255) ~= nil)
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

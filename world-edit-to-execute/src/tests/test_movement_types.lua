--[[
Test suite for Movement Type Support
Tests passability rules for different WC3 movement types.
]]

-- {{{ Setup paths
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local movement = require("runtime.pathfinding.movement")
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
-- Creates a mock pathing grid with configurable terrain
local function create_mock_grid(width, height)
    local grid = {
        width = width,
        height = height,
        tile_size = 128,
        offset_x = 0,
        offset_y = 0,
        cells = {},
    }

    -- Initialize all cells as walkable land
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

-- Set a cell to be deep water
local function set_deep_water(grid, x, y, depth)
    depth = depth or 200
    if grid.cells[y] and grid.cells[y][x] then
        grid.cells[y][x].water = true
        grid.cells[y][x].water_depth = depth
        grid.cells[y][x].walkable = false
    end
end

-- Set a cell to be shallow water
local function set_shallow_water(grid, x, y, depth)
    depth = depth or 32
    if grid.cells[y] and grid.cells[y][x] then
        grid.cells[y][x].water = true
        grid.cells[y][x].water_depth = depth
        grid.cells[y][x].walkable = true
    end
end

-- Set a cell to be impassable (cliff, boundary)
local function set_impassable(grid, x, y)
    if grid.cells[y] and grid.cells[y][x] then
        grid.cells[y][x].walkable = false
    end
end
-- }}}

-- {{{ Movement Type Definitions Tests
test_section("Movement Type Definitions")

test("foot type exists", movement.is_valid_type("foot"))
test("horse type exists", movement.is_valid_type("horse"))
test("fly type exists", movement.is_valid_type("fly"))
test("float type exists", movement.is_valid_type("float"))
test("hover type exists", movement.is_valid_type("hover"))
test("amphibious type exists", movement.is_valid_type("amphibious"))
test("invalid type rejected", not movement.is_valid_type("teleport"))

local foot = movement.get_type("foot")
test("foot can walk", foot.can_walk == true)
test("foot cannot fly", foot.can_fly == false)
test("foot cannot swim", foot.can_swim == false)
test("foot max wade = 64", foot.max_wade_depth == 64)

local fly = movement.get_type("fly")
test("fly can walk", fly.can_walk == true)
test("fly can fly", fly.can_fly == true)
test("fly can swim", fly.can_swim == true)

local float = movement.get_type("float")
test("float cannot walk", float.can_walk == false)
test("float can swim", float.can_swim == true)
test("float has min_swim_depth", float.min_swim_depth == 128)

local amphibious = movement.get_type("amphibious")
test("amphibious can walk", amphibious.can_walk == true)
test("amphibious can swim", amphibious.can_swim == true)

local hover = movement.get_type("hover")
test("hover can walk", hover.can_walk == true)
test("hover can hover", hover.can_hover == true)
test("hover max wade > foot", hover.max_wade_depth > foot.max_wade_depth)

-- List types
local types = movement.list_types()
test("list_types returns 6 types", #types == 6)
test("list_types sorted", types[1] == "amphibious" and types[2] == "float")
-- }}}

-- {{{ Foot Unit Passability Tests
test_section("Foot Unit Passability")

local grid = create_mock_grid(10, 10)

-- Normal land
test("foot passes walkable land", movement.can_pass(grid, 5, 5, "foot"))

-- Shallow water (wadeable)
set_shallow_water(grid, 3, 3, 32)  -- Below 64 threshold
test("foot passes shallow water (32)", movement.can_pass(grid, 3, 3, "foot"))

set_shallow_water(grid, 3, 4, 64)  -- At threshold
test("foot passes water at wade depth (64)", movement.can_pass(grid, 3, 4, "foot"))

-- Deep water
set_deep_water(grid, 4, 4, 100)
test("foot blocked by deep water (100)", not movement.can_pass(grid, 4, 4, "foot"))

set_deep_water(grid, 4, 5, 65)  -- Just over threshold
test("foot blocked by water just over wade (65)", not movement.can_pass(grid, 4, 5, "foot"))

-- Impassable land
set_impassable(grid, 6, 6)
test("foot blocked by impassable land", not movement.can_pass(grid, 6, 6, "foot"))

-- Out of bounds
test("foot blocked by out of bounds", not movement.can_pass(grid, -1, 0, "foot"))
test("foot blocked by out of bounds y", not movement.can_pass(grid, 0, 100, "foot"))
-- }}}

-- {{{ Flying Unit Passability Tests
test_section("Flying Unit Passability")

grid = create_mock_grid(10, 10)

-- Normal land
test("fly passes walkable land", movement.can_pass(grid, 5, 5, "fly"))

-- Deep water
set_deep_water(grid, 4, 4, 500)
test("fly passes deep water", movement.can_pass(grid, 4, 4, "fly"))

-- Impassable land (cliffs)
set_impassable(grid, 6, 6)
test("fly passes impassable land", movement.can_pass(grid, 6, 6, "fly"))

-- Out of bounds still blocked
test("fly blocked by out of bounds", not movement.can_pass(grid, -1, 0, "fly"))
-- }}}

-- {{{ Floating Unit Passability Tests
test_section("Floating Unit (Ship) Passability")

grid = create_mock_grid(10, 10)

-- Normal land - blocked
test("float blocked by land", not movement.can_pass(grid, 5, 5, "float"))

-- Deep water - passable
set_deep_water(grid, 4, 4, 200)
test("float passes deep water (200)", movement.can_pass(grid, 4, 4, "float"))

set_deep_water(grid, 4, 5, 128)  -- At minimum
test("float passes water at min depth (128)", movement.can_pass(grid, 4, 5, "float"))

-- Shallow water - blocked (ship needs deep water)
set_shallow_water(grid, 3, 3, 64)
test("float blocked by shallow water (64)", not movement.can_pass(grid, 3, 3, "float"))

set_deep_water(grid, 3, 4, 100)  -- Below minimum
test("float blocked by water below min (100)", not movement.can_pass(grid, 3, 4, "float"))

-- Impassable land - still blocked (cliff on shore)
set_impassable(grid, 6, 6)
test("float blocked by impassable land", not movement.can_pass(grid, 6, 6, "float"))
-- }}}

-- {{{ Amphibious Unit Passability Tests
test_section("Amphibious Unit Passability")

grid = create_mock_grid(10, 10)

-- Normal land
test("amphibious passes land", movement.can_pass(grid, 5, 5, "amphibious"))

-- Shallow water
set_shallow_water(grid, 3, 3, 50)
test("amphibious passes shallow water", movement.can_pass(grid, 3, 3, "amphibious"))

-- Deep water
set_deep_water(grid, 4, 4, 500)
test("amphibious passes deep water", movement.can_pass(grid, 4, 4, "amphibious"))

-- Impassable land (cliff)
set_impassable(grid, 6, 6)
test("amphibious blocked by cliff", not movement.can_pass(grid, 6, 6, "amphibious"))
-- }}}

-- {{{ Hover Unit Passability Tests
test_section("Hover Unit Passability")

grid = create_mock_grid(10, 10)

-- Normal land
test("hover passes land", movement.can_pass(grid, 5, 5, "hover"))

-- Shallow water (below hover threshold)
set_shallow_water(grid, 3, 3, 100)
test("hover passes shallow water (100)", movement.can_pass(grid, 3, 3, "hover"))

set_shallow_water(grid, 3, 4, 256)  -- At threshold
test("hover passes water at threshold (256)", movement.can_pass(grid, 3, 4, "hover"))

-- Deep water (above hover threshold)
set_deep_water(grid, 4, 4, 300)
test("hover blocked by deep water (300)", not movement.can_pass(grid, 4, 4, "hover"))

-- Impassable land
set_impassable(grid, 6, 6)
test("hover blocked by cliff", not movement.can_pass(grid, 6, 6, "hover"))
-- }}}

-- {{{ Horse Unit Passability Tests
test_section("Horse Unit Passability")

grid = create_mock_grid(10, 10)

-- Horse should behave exactly like foot
test("horse passes land", movement.can_pass(grid, 5, 5, "horse"))

set_shallow_water(grid, 3, 3, 32)
test("horse passes shallow water", movement.can_pass(grid, 3, 3, "horse"))

set_deep_water(grid, 4, 4, 100)
test("horse blocked by deep water", not movement.can_pass(grid, 4, 4, "horse"))

set_impassable(grid, 6, 6)
test("horse blocked by cliff", not movement.can_pass(grid, 6, 6, "horse"))
-- }}}

-- {{{ make_can_pass Factory Tests
test_section("make_can_pass Factory")

grid = create_mock_grid(10, 10)
set_deep_water(grid, 4, 4, 200)
set_impassable(grid, 6, 6)

local foot_pass = movement.make_can_pass(grid, "foot")
test("factory returns function", type(foot_pass) == "function")
test("factory foot passes land", foot_pass(5, 5) == true)
test("factory foot blocked by water", foot_pass(4, 4) == false)
test("factory foot blocked by cliff", foot_pass(6, 6) == false)

local fly_pass = movement.make_can_pass(grid, "fly")
test("factory fly passes land", fly_pass(5, 5) == true)
test("factory fly passes water", fly_pass(4, 4) == true)
test("factory fly passes cliff", fly_pass(6, 6) == true)
-- }}}

-- {{{ Custom Movement Type Registration Tests
test_section("Custom Movement Type Registration")

-- Register new type
local ok, err = movement.register("burrower", {
    can_walk = true,
    can_fly = false,
    can_swim = false,
    max_wade_depth = 0,
})
test("register custom type", ok == true)
test("custom type exists", movement.is_valid_type("burrower"))

local burrower = movement.get_type("burrower")
test("custom type has properties", burrower.can_walk == true)
test("custom type default can_hover", burrower.can_hover == false)

-- Cannot register duplicate
ok, err = movement.register("burrower", {})
test("duplicate registration fails", ok == false)
test("duplicate has error message", err and err:find("already exists"))

-- Cannot register with non-table
ok, err = movement.register("bad", "not a table")
test("non-table registration fails", ok == false)

-- Unregister custom type
ok = movement.unregister("burrower")
test("unregister custom type", ok == true)
test("unregistered type gone", not movement.is_valid_type("burrower"))

-- Cannot unregister built-in
ok, err = movement.unregister("foot")
test("cannot unregister built-in", ok == false)
test("foot still exists", movement.is_valid_type("foot"))
-- }}}

-- {{{ Convenience Function Tests
test_section("Convenience Functions")

-- can_traverse_water
test("foot can traverse water 32", movement.can_traverse_water("foot", 32))
test("foot can traverse water 64", movement.can_traverse_water("foot", 64))
test("foot cannot traverse water 100", not movement.can_traverse_water("foot", 100))
test("fly can traverse any water", movement.can_traverse_water("fly", 1000))
test("float cannot traverse shallow", not movement.can_traverse_water("float", 64))
test("float can traverse deep", movement.can_traverse_water("float", 200))
test("amphibious can traverse any", movement.can_traverse_water("amphibious", 500))

-- can_traverse_land
test("foot can traverse land", movement.can_traverse_land("foot"))
test("fly can traverse land", movement.can_traverse_land("fly"))
test("float cannot traverse land", not movement.can_traverse_land("float"))
test("amphibious can traverse land", movement.can_traverse_land("amphibious"))

-- is_flying
test("foot not flying", not movement.is_flying("foot"))
test("fly is flying", movement.is_flying("fly"))
test("hover not flying", not movement.is_flying("hover"))

-- describe_type
local desc = movement.describe_type("foot")
test("describe returns string", type(desc) == "string")
test("describe includes name", desc:find("foot"))
test("describe includes walk", desc:find("walk"))
test("describe includes wade depth", desc:find("wade"))

desc = movement.describe_type("unknown")
test("describe unknown type", desc:find("Unknown"))
-- }}}

-- {{{ Default Movement Type Tests
test_section("Default Movement Type")

grid = create_mock_grid(10, 10)
set_deep_water(grid, 4, 4, 200)

-- Unknown type should default to foot behavior
test("unknown defaults to foot on land", movement.can_pass(grid, 5, 5, "unknown_type"))
test("unknown defaults to foot on water", not movement.can_pass(grid, 4, 4, "unknown_type"))
test("nil type defaults to foot on land", movement.can_pass(grid, 5, 5, nil))
-- }}}

-- {{{ Edge Cases Tests
test_section("Edge Cases")

-- Nil grid
test("nil grid returns false", not movement.can_pass(nil, 0, 0, "foot"))

-- Grid without cells
test("empty grid returns false", not movement.can_pass({}, 0, 0, "foot"))

-- Grid with nil row
grid = create_mock_grid(10, 10)
grid.cells[5] = nil
test("nil row returns false", not movement.can_pass(grid, 5, 5, "foot"))

-- Water with 0 depth (edge case)
grid = create_mock_grid(10, 10)
grid.cells[3][3].water = true
grid.cells[3][3].water_depth = 0
test("zero depth water passable for foot", movement.can_pass(grid, 3, 3, "foot"))
test("zero depth water not passable for float", not movement.can_pass(grid, 3, 3, "float"))
-- }}}

-- {{{ Pathfinding Module Integration Tests
test_section("Pathfinding Module Integration")

test("pathfinding.movement exists", pathfinding.movement ~= nil)
test("pathfinding.is_passable exists", type(pathfinding.is_passable) == "function")
test("pathfinding.find_path_for_type exists", type(pathfinding.find_path_for_type) == "function")

-- Set up grid for pathfinding integration
grid = create_mock_grid(10, 10)
pathfinding.set_grid(grid)

test("is_passable foot on land", pathfinding.is_passable(500, 500, "foot"))
test("is_passable default type", pathfinding.is_passable(500, 500))  -- Should default to foot

-- Clear grid
pathfinding.clear_grid()
test("is_passable without grid", not pathfinding.is_passable(500, 500, "foot"))
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

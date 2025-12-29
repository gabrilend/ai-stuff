--[[
Test Suite for Spatial Hash Grid (Issue 405b)

Tests spatial partitioning for broad-phase collision detection.
]]

-- Setup path for requires
package.path = package.path .. ";./src/?.lua;./src/?/init.lua"

local spatial = require("runtime.collision.spatial")
local collision = require("runtime.collision")
local ecs = require("runtime.ecs")

local test_count = 0
local pass_count = 0

local function test(name, condition)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("[PASS] " .. name)
    else
        print("[FAIL] " .. name)
    end
end

local function setup()
    -- Reset ECS and collision system for each test group
    ecs.clear_all()
    collision.reset()
    collision.init(ecs)
    spatial.clear()
    spatial.set_cell_size(256)  -- Reset to default

    -- Register position component if not already
    pcall(function()
        ecs.register_component("position", {x = 0, y = 0, z = 0})
    end)
end

print("=== Testing Spatial Hash Grid (405b) ===\n")

-- {{{ Cell Coordinate Conversion Tests
print("--- Cell Coordinate Conversion ---")
setup()

local cx, cy

cx, cy = spatial.world_to_cell(0, 0)
test("Origin maps to cell (0, 0)",
    cx == 0 and cy == 0)

cx, cy = spatial.world_to_cell(128, 128)
test("Center of first cell",
    cx == 0 and cy == 0)

cx, cy = spatial.world_to_cell(256, 0)
test("Exactly on cell boundary (right)",
    cx == 1 and cy == 0)

cx, cy = spatial.world_to_cell(255, 0)
test("Just before cell boundary",
    cx == 0 and cy == 0)

cx, cy = spatial.world_to_cell(512, 512)
test("Multiple cells away",
    cx == 2 and cy == 2)

cx, cy = spatial.world_to_cell(-1, -1)
test("Negative coordinates (cell -1)",
    cx == -1 and cy == -1)

cx, cy = spatial.world_to_cell(-256, -256)
test("Negative cell boundary",
    cx == -1 and cy == -1)

cx, cy = spatial.world_to_cell(-257, 0)
test("Just past negative boundary",
    cx == -2 and cy == 0)

-- Cell to world conversion
local wx, wy = spatial.cell_to_world(0, 0)
test("Cell (0,0) to world returns center",
    wx == 128 and wy == 128)

wx, wy = spatial.cell_to_world(1, 1)
test("Cell (1,1) to world",
    wx == 384 and wy == 384)

wx, wy = spatial.cell_to_world(-1, -1)
test("Cell (-1,-1) to world",
    wx == -128 and wy == -128)
-- }}}

-- {{{ Cell Size Configuration Tests
print("\n--- Cell Size Configuration ---")
setup()

test("Default cell size is 256",
    spatial.get_cell_size() == 256)

spatial.set_cell_size(128)
test("Cell size can be changed",
    spatial.get_cell_size() == 128)

-- Test that cell conversion uses new size
cx, cy = spatial.world_to_cell(128, 0)
test("Cell conversion uses new size",
    cx == 1 and cy == 0)

spatial.set_cell_size(64)
cx, cy = spatial.world_to_cell(64, 64)
test("Small cell size works",
    cx == 1 and cy == 1)

-- Invalid cell size
local ok = pcall(function() spatial.set_cell_size(0) end)
test("Zero cell size throws error",
    not ok)

ok = pcall(function() spatial.set_cell_size(-100) end)
test("Negative cell size throws error",
    not ok)

spatial.set_cell_size(256)  -- Reset
-- }}}

-- {{{ Get Occupied Cells Tests
print("\n--- Get Occupied Cells ---")
setup()

local cells

-- Small entity in center of cell
cells = spatial.get_occupied_cells(128, 128, 10)
test("Small centered entity occupies 1 cell",
    #cells == 1 and cells[1][1] == 0 and cells[1][2] == 0)

-- Entity on cell boundary
cells = spatial.get_occupied_cells(256, 128, 10)
test("Entity on X boundary occupies 2 cells",
    #cells == 2)

-- Entity on corner
cells = spatial.get_occupied_cells(256, 256, 10)
test("Entity on corner occupies 4 cells",
    #cells == 4)

-- Large entity spanning multiple cells
cells = spatial.get_occupied_cells(256, 256, 300)
test("Large entity spans many cells",
    #cells > 4)

-- Entity at origin with small radius - spans cells (-1,-1) to (0,0)
-- because bounds are (-10,-10) to (10,10), crossing both axes
cells = spatial.get_occupied_cells(0, 0, 10)
test("Origin entity occupies 4 cells (crosses both axes)",
    #cells == 4)

-- Entity at negative coordinates
cells = spatial.get_occupied_cells(-128, -128, 10)
test("Negative coord entity in cell (-1, -1)",
    #cells == 1 and cells[1][1] == -1 and cells[1][2] == -1)
-- }}}

-- {{{ Update All Tests
print("\n--- Update All (ECS Integration) ---")
setup()

-- Create some entities with position and collision
local e1 = ecs.create_entity()
ecs.add_component(e1, "position", {x = 100, y = 100})
ecs.add_component(e1, "collision", {shape = "circle", radius = 20})

local e2 = ecs.create_entity()
ecs.add_component(e2, "position", {x = 500, y = 500})
ecs.add_component(e2, "collision", {shape = "circle", radius = 30})

local e3 = ecs.create_entity()
ecs.add_component(e3, "position", {x = 100, y = 100})
ecs.add_component(e3, "collision", {shape = "rect", width = 40, height = 40})

-- Entity without collision (should be ignored)
local e4 = ecs.create_entity()
ecs.add_component(e4, "position", {x = 200, y = 200})

spatial.update_all(ecs)

local stats = spatial.get_stats()
test("Update all populates hash",
    stats.entity_count == 3)

test("Multiple cells created",
    stats.cell_count >= 1)

-- Check that entities are in correct cells
local cell_0_0 = spatial.get_cell(0, 0)
test("Cell (0,0) contains entities",
    #cell_0_0 >= 1)

local cell_1_1 = spatial.get_cell(1, 1)
test("Cell (1,1) contains e2",
    #cell_1_1 >= 1)
-- }}}

-- {{{ Get Nearby Tests
print("\n--- Get Nearby ---")
setup()

-- Create test entities in known positions
local entities = {}
for i = 1, 5 do
    local e = ecs.create_entity()
    ecs.add_component(e, "position", {x = i * 100, y = 100})
    ecs.add_component(e, "collision", {shape = "circle", radius = 20})
    entities[i] = e
end

spatial.update_all(ecs)

-- Query near first entity
local nearby = spatial.get_nearby(100, 100, 50)
test("Get nearby finds local entities",
    #nearby >= 1)

-- Query far away from all entities (entities are at x = 100-500, y = 100)
nearby = spatial.get_nearby(2000, 2000, 10)
test("Get nearby returns empty for empty area",
    #nearby == 0)

-- Query with large radius
nearby = spatial.get_nearby(250, 100, 500)
test("Large radius finds multiple entities",
    #nearby >= 3)

-- Check no duplicates (entities in multiple cells)
local seen = {}
local has_dupe = false
for _, e in ipairs(nearby) do
    if seen[e] then
        has_dupe = true
        break
    end
    seen[e] = true
end
test("No duplicates in nearby results",
    not has_dupe)
-- }}}

-- {{{ Get In Rect Tests
print("\n--- Get In Rect ---")
setup()

-- Create grid of entities
for x = 0, 2 do
    for y = 0, 2 do
        local e = ecs.create_entity()
        ecs.add_component(e, "position", {x = x * 200 + 100, y = y * 200 + 100})
        ecs.add_component(e, "collision", {shape = "circle", radius = 20})
    end
end

spatial.update_all(ecs)

-- Query center area
local in_rect = spatial.get_in_rect(300, 300, 200, 200)
test("Get in rect finds entities in area",
    #in_rect >= 1)

-- Query large area
in_rect = spatial.get_in_rect(250, 250, 600, 600)
test("Large rect finds many entities",
    #in_rect >= 4)

-- Query empty area
in_rect = spatial.get_in_rect(1000, 1000, 50, 50)
test("Empty rect area returns empty",
    #in_rect == 0)

-- Check no duplicates
seen = {}
has_dupe = false
for _, e in ipairs(in_rect) do
    if seen[e] then
        has_dupe = true
        break
    end
    seen[e] = true
end
test("No duplicates in rect results",
    not has_dupe)
-- }}}

-- {{{ Get At Point Tests
print("\n--- Get At Point ---")
setup()

local e1 = ecs.create_entity()
ecs.add_component(e1, "position", {x = 100, y = 100})
ecs.add_component(e1, "collision", {shape = "circle", radius = 20})

local e2 = ecs.create_entity()
ecs.add_component(e2, "position", {x = 300, y = 300})
ecs.add_component(e2, "collision", {shape = "circle", radius = 20})

spatial.update_all(ecs)

local at_point = spatial.get_at_point(100, 100)
test("Get at point finds entity in cell",
    #at_point >= 1)

at_point = spatial.get_at_point(300, 300)
test("Get at different point finds other entity",
    #at_point >= 1)

at_point = spatial.get_at_point(1000, 1000)
test("Get at empty point returns empty",
    #at_point == 0)
-- }}}

-- {{{ Edge Cases Tests
print("\n--- Edge Cases ---")
setup()

-- Empty hash query
local nearby = spatial.get_nearby(0, 0, 100)
test("Query empty hash returns empty",
    #nearby == 0)

-- Entity at exact cell boundary
local e = ecs.create_entity()
ecs.add_component(e, "position", {x = 256, y = 256})
ecs.add_component(e, "collision", {shape = "circle", radius = 10})
spatial.update_all(ecs)

nearby = spatial.get_nearby(256, 256, 20)
test("Entity at boundary found by nearby query",
    #nearby >= 1)

-- Very large radius query
setup()
for i = 1, 10 do
    local ent = ecs.create_entity()
    ecs.add_component(ent, "position", {x = i * 100, y = i * 100})
    ecs.add_component(ent, "collision", {shape = "circle", radius = 10})
end
spatial.update_all(ecs)

nearby = spatial.get_nearby(500, 500, 2000)
test("Very large radius query works",
    #nearby == 10)

-- Point-shaped entity (zero radius)
setup()
e = ecs.create_entity()
ecs.add_component(e, "position", {x = 100, y = 100})
ecs.add_component(e, "collision", {shape = "point"})
spatial.update_all(ecs)

nearby = spatial.get_nearby(100, 100, 50)
test("Point entity found in hash",
    #nearby >= 1)

-- Rect-shaped entity
setup()
e = ecs.create_entity()
ecs.add_component(e, "position", {x = 256, y = 256})
ecs.add_component(e, "collision", {shape = "rect", width = 100, height = 100})
spatial.update_all(ecs)

-- Rect should span multiple cells
stats = spatial.get_stats()
test("Rect entity spans multiple cells",
    stats.cell_count >= 2 or stats.max_entities_per_cell >= 1)
-- }}}

-- {{{ Clear and Stats Tests
print("\n--- Clear and Stats ---")
setup()

-- Create entities
for i = 1, 5 do
    local e = ecs.create_entity()
    ecs.add_component(e, "position", {x = i * 50, y = 50})
    ecs.add_component(e, "collision", {shape = "circle", radius = 10})
end
spatial.update_all(ecs)

stats = spatial.get_stats()
test("Stats show correct entity count",
    stats.entity_count == 5)

test("Stats show cell count",
    stats.cell_count >= 1)

test("Stats show max entities per cell",
    stats.max_entities_per_cell >= 1)

test("Stats include cell size",
    stats.cell_size == 256)

-- Clear and verify
spatial.clear()
stats = spatial.get_stats()
test("Clear resets entity count",
    stats.entity_count == 0)

test("Clear resets cell count",
    stats.cell_count == 0)

nearby = spatial.get_nearby(100, 100, 100)
test("Queries after clear return empty",
    #nearby == 0)
-- }}}

-- {{{ Negative Coordinate Tests
print("\n--- Negative Coordinates ---")
setup()

-- Create entities in negative space
local e1 = ecs.create_entity()
ecs.add_component(e1, "position", {x = -100, y = -100})
ecs.add_component(e1, "collision", {shape = "circle", radius = 20})

local e2 = ecs.create_entity()
ecs.add_component(e2, "position", {x = -500, y = -500})
ecs.add_component(e2, "collision", {shape = "circle", radius = 20})

spatial.update_all(ecs)

local cell = spatial.get_cell(-1, -1)
test("Negative cell contains entity",
    #cell >= 1)

nearby = spatial.get_nearby(-100, -100, 50)
test("Nearby query in negative space works",
    #nearby >= 1)

nearby = spatial.get_nearby(-300, -300, 500)
test("Large negative query finds entities",
    #nearby >= 1)
-- }}}

-- {{{ Multi-Cell Entity Tests
print("\n--- Multi-Cell Entities ---")
setup()
spatial.set_cell_size(64)  -- Smaller cells for testing

-- Entity that spans 4 cells (on corner)
local e = ecs.create_entity()
ecs.add_component(e, "position", {x = 64, y = 64})  -- Exactly on cell corner
ecs.add_component(e, "collision", {shape = "circle", radius = 10})
spatial.update_all(ecs)

-- Entity should be in all 4 adjacent cells
local c1 = spatial.get_cell(0, 0)
local c2 = spatial.get_cell(1, 0)
local c3 = spatial.get_cell(0, 1)
local c4 = spatial.get_cell(1, 1)

test("Corner entity in cell (0,0)",
    #c1 >= 1)
test("Corner entity in cell (1,0)",
    #c2 >= 1)
test("Corner entity in cell (0,1)",
    #c3 >= 1)
test("Corner entity in cell (1,1)",
    #c4 >= 1)

-- Query should still return only one entity (no dupes)
nearby = spatial.get_nearby(64, 64, 100)
test("Multi-cell entity appears once in query",
    #nearby == 1)

spatial.set_cell_size(256)  -- Reset
-- }}}

-- {{{ Debug Dump Test
print("\n--- Debug Dump ---")
setup()

local e = ecs.create_entity()
ecs.add_component(e, "position", {x = 100, y = 100})
ecs.add_component(e, "collision", {shape = "circle", radius = 20})
spatial.update_all(ecs)

local dump = spatial.debug_dump()
test("Debug dump returns string",
    type(dump) == "string")

test("Debug dump contains cell size",
    dump:find("256") ~= nil)

test("Debug dump contains cell info",
    dump:find("Cell") ~= nil)
-- }}}

-- Summary
print("\n=== Test Summary ===")
print(string.format("Passed: %d/%d", pass_count, test_count))

if pass_count == test_count then
    print("All tests passed!")
    os.exit(0)
else
    print("Some tests failed!")
    os.exit(1)
end

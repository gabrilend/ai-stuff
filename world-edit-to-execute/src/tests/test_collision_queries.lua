--[[
Test Suite for Collision Queries (Issue 405c)

Tests query API that combines spatial hash broad-phase with
shape collision narrow-phase testing.
]]

-- Setup path for requires
package.path = package.path .. ";./src/?.lua;./src/?/init.lua"

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
    collision.clear_spatial()

    -- Register position component
    pcall(function()
        ecs.register_component("position", {x = 0, y = 0, z = 0})
    end)
end

local function create_entity_at(x, y, shape, size, layer)
    local e = ecs.create_entity()
    ecs.add_component(e, "position", {x = x, y = y})

    local col_data = {
        shape = shape or "circle",
        layer = layer or "unit",
    }

    if shape == "circle" or shape == nil then
        col_data.radius = size or 20
    elseif shape == "rect" then
        col_data.width = size or 40
        col_data.height = size or 40
    end

    ecs.add_component(e, "collision", col_data)
    return e
end

print("=== Testing Collision Queries (405c) ===\n")

-- {{{ Query Radius Tests
print("--- Query Radius ---")
setup()

-- Create entities at known positions
local e1 = create_entity_at(100, 100, "circle", 20, "unit")
local e2 = create_entity_at(150, 100, "circle", 20, "unit")
local e3 = create_entity_at(500, 500, "circle", 20, "unit")

collision.update()

-- Query at e1's position
local results = collision.query_radius(100, 100, 30)
test("Query radius finds overlapping entity",
    #results >= 1)

-- Query with larger radius to catch e2
results = collision.query_radius(100, 100, 100)
test("Larger radius finds more entities",
    #results >= 2)

-- Query at empty area
results = collision.query_radius(1000, 1000, 50)
test("Query at empty area returns empty",
    #results == 0)

-- Verify distance sorting (e1 should be first as it's at query center)
results = collision.query_radius(100, 100, 200)
test("Results sorted by distance (nearest first)",
    #results >= 2 and results[1] == e1)

-- Query with zero radius
results = collision.query_radius(100, 100, 0)
test("Zero radius query works",
    #results == 0 or #results == 1)  -- May or may not catch point-like query

-- Negative coordinates
setup()
local e_neg = create_entity_at(-100, -100, "circle", 20, "unit")
collision.update()

results = collision.query_radius(-100, -100, 50)
test("Query in negative coordinate space works",
    #results >= 1)
-- }}}

-- {{{ Query Radius with Layer Mask Tests
print("\n--- Query Radius with Layer Mask ---")
setup()

local unit1 = create_entity_at(100, 100, "circle", 20, "unit")
local building1 = create_entity_at(120, 100, "circle", 30, "building")
local projectile1 = create_entity_at(140, 100, "circle", 10, "projectile")

collision.update()

-- Query all layers
results = collision.query_radius(120, 100, 100, nil)
test("Nil layer_mask matches all",
    #results == 3)

-- Query only units
results = collision.query_radius(120, 100, 100, {"unit"})
test("Layer mask filters to units only",
    #results == 1)

-- Query units and buildings
results = collision.query_radius(120, 100, 100, {"unit", "building"})
test("Layer mask with multiple layers",
    #results == 2)

-- Query with wildcard
results = collision.query_radius(120, 100, 100, {"*"})
test("Wildcard layer mask matches all",
    #results == 3)

-- Query non-existent layer
results = collision.query_radius(120, 100, 100, {"nonexistent"})
test("Non-matching layer mask returns empty",
    #results == 0)
-- }}}

-- {{{ Query Rect Tests
print("\n--- Query Rect ---")
setup()

-- Create grid of entities
for x = 0, 2 do
    for y = 0, 2 do
        create_entity_at(x * 100 + 50, y * 100 + 50, "circle", 20, "unit")
    end
end

collision.update()

-- Query center area
results = collision.query_rect(150, 150, 200, 200)
test("Query rect finds entities in area",
    #results >= 1)

-- Query large area
results = collision.query_rect(150, 150, 400, 400)
test("Large rect finds many entities",
    #results >= 4)

-- Query empty area
results = collision.query_rect(1000, 1000, 50, 50)
test("Query empty rect returns empty",
    #results == 0)

-- Query with layer mask
setup()
create_entity_at(100, 100, "circle", 20, "unit")
create_entity_at(100, 100, "circle", 20, "building")
collision.update()

results = collision.query_rect(100, 100, 100, 100, {"unit"})
test("Query rect respects layer mask",
    #results == 1)
-- }}}

-- {{{ Query Point Tests
print("\n--- Query Point ---")
setup()

local e1 = create_entity_at(100, 100, "circle", 30, "unit")

collision.update()

-- Query at entity center
local found = collision.query_point(100, 100)
test("Query point finds entity at center",
    found == e1)

-- Query inside entity but not at center
found = collision.query_point(110, 100)
test("Query point finds entity when inside",
    found == e1)

-- Query outside entity
found = collision.query_point(200, 200)
test("Query point returns nil when outside",
    found == nil)

-- Query with overlapping entities (priority test)
setup()
local unit = create_entity_at(100, 100, "circle", 30, "unit")
local building = create_entity_at(100, 100, "circle", 30, "building")
collision.update()

found = collision.query_point(100, 100)
test("Query point returns highest priority (unit over building)",
    found == unit)

-- Query with layer mask
found = collision.query_point(100, 100, {"building"})
test("Query point respects layer mask",
    found == building)
-- }}}

-- {{{ Query All At Point Tests
print("\n--- Query All At Point ---")
setup()

local e1 = create_entity_at(100, 100, "circle", 30, "unit")
local e2 = create_entity_at(100, 100, "circle", 30, "building")
local e3 = create_entity_at(100, 100, "circle", 30, "projectile")

collision.update()

results = collision.query_all_at_point(100, 100)
test("Query all at point finds all overlapping entities",
    #results == 3)

test("Results sorted by priority (unit first)",
    results[1] == e1)

test("Building second",
    results[2] == e2)

-- With layer mask
results = collision.query_all_at_point(100, 100, {"building", "projectile"})
test("Query all at point respects layer mask",
    #results == 2)
-- }}}

-- {{{ Query Colliding Tests
print("\n--- Query Colliding ---")
setup()

local center = create_entity_at(100, 100, "circle", 30, "unit")
local nearby = create_entity_at(130, 100, "circle", 20, "unit")  -- Overlaps
local far = create_entity_at(300, 300, "circle", 20, "unit")      -- No overlap

collision.update()

results = collision.query_colliding(center)
test("Query colliding finds overlapping entity",
    #results == 1 and results[1] == nearby)

results = collision.query_colliding(far)
test("Query colliding returns empty when no overlaps",
    #results == 0)

-- With layer mask
setup()
center = create_entity_at(100, 100, "circle", 30, "unit")
local building_near = create_entity_at(120, 100, "circle", 30, "building")
collision.update()

results = collision.query_colliding(center, {"building"})
test("Query colliding respects layer mask",
    #results == 1 and results[1] == building_near)

results = collision.query_colliding(center, {"projectile"})
test("Query colliding with non-matching mask returns empty",
    #results == 0)
-- }}}

-- {{{ Shape-Specific Query Tests
print("\n--- Shape-Specific Queries ---")

-- Circle entities
setup()
local circle1 = create_entity_at(100, 100, "circle", 30, "unit")
collision.update()

results = collision.query_radius(100, 100, 50)
test("Query radius finds circle entity",
    #results == 1)

-- Rect entities
setup()
local rect1 = create_entity_at(100, 100, "rect", 50, "unit")
collision.update()

results = collision.query_radius(100, 100, 50)
test("Query radius finds rect entity",
    #results == 1)

results = collision.query_rect(100, 100, 100, 100)
test("Query rect finds rect entity",
    #results == 1)

-- Point entities
setup()
local point1 = create_entity_at(100, 100, "point", nil, "unit")
collision.update()

results = collision.query_radius(100, 100, 50)
test("Query radius finds point entity",
    #results == 1)

local found = collision.query_point(100, 100)
test("Query point finds point entity (exact match)",
    found == point1)

-- Mixed shapes
setup()
local c = create_entity_at(100, 100, "circle", 20, "unit")
local r = create_entity_at(140, 100, "rect", 40, "building")
collision.update()

results = collision.query_radius(120, 100, 50)
test("Query finds mixed shape entities",
    #results == 2)
-- }}}

-- {{{ Update and Clear Tests
print("\n--- Update and Clear ---")
setup()

create_entity_at(100, 100, "circle", 20, "unit")

-- Query before update should return empty
results = collision.query_radius(100, 100, 50)
test("Query before update returns empty (hash not populated)",
    #results == 0)

collision.update()

results = collision.query_radius(100, 100, 50)
test("Query after update finds entity",
    #results == 1)

collision.clear_spatial()

results = collision.query_radius(100, 100, 50)
test("Query after clear returns empty",
    #results == 0)

collision.update()

results = collision.query_radius(100, 100, 50)
test("Query after re-update finds entity again",
    #results == 1)
-- }}}

-- {{{ Stats and Configuration Tests
print("\n--- Stats and Configuration ---")
setup()

for i = 1, 10 do
    create_entity_at(i * 50, 50, "circle", 20, "unit")
end
collision.update()

local stats = collision.get_stats()
test("Stats show entity count",
    stats.entity_count == 10)

test("Stats show cell count",
    stats.cell_count >= 1)

test("Cell size getter works",
    collision.get_cell_size() == 256)

collision.set_cell_size(128)
test("Cell size setter works",
    collision.get_cell_size() == 128)

-- Reset cell size
collision.set_cell_size(256)
-- }}}

-- {{{ Edge Cases Tests
print("\n--- Edge Cases ---")

-- Uninitialized query
collision.reset()
results = collision.query_radius(0, 0, 100)
test("Query when uninitialized returns empty",
    #results == 0)

local found = collision.query_point(0, 0)
test("Point query when uninitialized returns nil",
    found == nil)

-- Re-initialize
collision.init(ecs)

-- Entity without position
setup()
local e_no_pos = ecs.create_entity()
ecs.add_component(e_no_pos, "collision", {shape = "circle", radius = 20})
collision.update()

results = collision.query_radius(0, 0, 100)
test("Entity without position de-selected from queries",
    #results == 0)

-- Entity without collision
setup()
local e_no_col = ecs.create_entity()
ecs.add_component(e_no_col, "position", {x = 100, y = 100})
collision.update()

results = collision.query_radius(100, 100, 50)
test("Entity without collision de-selected from queries",
    #results == 0)

-- Very large query
setup()
for i = 1, 20 do
    create_entity_at(i * 100, i * 100, "circle", 20, "unit")
end
collision.update()

results = collision.query_radius(1000, 1000, 5000)
test("Very large radius query works",
    #results == 20)

-- Zero-sized entity
setup()
local zero_e = create_entity_at(100, 100, "circle", 0, "unit")
collision.update()

results = collision.query_radius(100, 100, 10)
test("Zero-radius entity can be found",
    #results >= 1)
-- }}}

-- {{{ Multiple Entities Same Position Tests
print("\n--- Multiple Entities Same Position ---")
setup()

local entities = {}
for i = 1, 5 do
    entities[i] = create_entity_at(100, 100, "circle", 20, "unit")
end
collision.update()

results = collision.query_radius(100, 100, 30)
test("Query finds all entities at same position",
    #results == 5)

results = collision.query_all_at_point(100, 100)
test("Query all at point finds all stacked entities",
    #results == 5)
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

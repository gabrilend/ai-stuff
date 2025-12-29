--[[
Test Suite for Collision Shapes (Issue 405a)

Tests collision primitives, layer/mask filtering, and shape dispatch.
]]

-- Setup path for requires
package.path = package.path .. ";./src/?.lua;./src/?/init.lua"

local shapes = require("runtime.collision.shapes")
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

local function approx_eq(a, b, epsilon)
    epsilon = epsilon or 0.001
    return math.abs(a - b) < epsilon
end

print("=== Testing Collision Shapes (405a) ===\n")

-- {{{ Circle-Circle Collision Tests
print("--- Circle-Circle Collision ---")

test("Overlapping circles (touching)",
    shapes.circles_collide(0, 0, 10, 20, 0, 10) == true)

test("Overlapping circles (partial)",
    shapes.circles_collide(0, 0, 10, 15, 0, 10) == true)

test("Overlapping circles (fully)",
    shapes.circles_collide(0, 0, 20, 5, 0, 10) == true)

test("Non-overlapping circles",
    shapes.circles_collide(0, 0, 10, 30, 0, 10) == false)

test("Same position circles",
    shapes.circles_collide(5, 5, 10, 5, 5, 10) == true)

test("Negative coordinates",
    shapes.circles_collide(-10, -10, 5, -5, -5, 5) == true)

-- Zero radius circle at origin is inside a radius-10 circle centered at (5,0)
-- Distance 5 <= sum of radii (0+10), so they collide
test("Zero radius circle (point inside larger circle)",
    shapes.circles_collide(0, 0, 0, 5, 0, 10) == true)

test("Zero radius circle (point outside)",
    shapes.circles_collide(0, 0, 0, 20, 0, 10) == false)

test("Diagonal overlapping circles",
    shapes.circles_collide(0, 0, 10, 7, 7, 10) == true)

test("Diagonal non-overlapping circles",
    shapes.circles_collide(0, 0, 5, 10, 10, 5) == false)
-- }}}

-- {{{ Point-in-Circle Tests
print("\n--- Point in Circle ---")

test("Point at circle center",
    shapes.point_in_circle(5, 5, 5, 5, 10) == true)

test("Point on circle edge",
    shapes.point_in_circle(15, 5, 5, 5, 10) == true)

test("Point inside circle",
    shapes.point_in_circle(8, 5, 5, 5, 10) == true)

test("Point outside circle",
    shapes.point_in_circle(20, 5, 5, 5, 10) == false)

test("Point at origin, circle at origin",
    shapes.point_in_circle(0, 0, 0, 0, 5) == true)

test("Point negative coords inside",
    shapes.point_in_circle(-3, -4, 0, 0, 10) == true)

test("Point exactly on radius boundary",
    shapes.point_in_circle(3, 4, 0, 0, 5) == true)  -- 3^2 + 4^2 = 25 = 5^2
-- }}}

-- {{{ Point-in-Rect Tests
print("\n--- Point in Rectangle ---")

test("Point at rect center",
    shapes.point_in_rect(50, 50, 50, 50, 20, 20) == true)

test("Point on rect edge",
    shapes.point_in_rect(60, 50, 50, 50, 20, 20) == true)

test("Point on rect corner",
    shapes.point_in_rect(60, 60, 50, 50, 20, 20) == true)

test("Point inside rect",
    shapes.point_in_rect(55, 45, 50, 50, 20, 20) == true)

test("Point outside rect (right)",
    shapes.point_in_rect(65, 50, 50, 50, 20, 20) == false)

test("Point outside rect (top)",
    shapes.point_in_rect(50, 65, 50, 50, 20, 20) == false)

test("Point outside rect (left)",
    shapes.point_in_rect(35, 50, 50, 50, 20, 20) == false)

test("Point outside rect (bottom)",
    shapes.point_in_rect(50, 35, 50, 50, 20, 20) == false)

test("Rect at origin",
    shapes.point_in_rect(5, 5, 0, 0, 20, 20) == true)

test("Negative coordinate rect",
    shapes.point_in_rect(-5, -5, -10, -10, 20, 20) == true)
-- }}}

-- {{{ Rect-Rect Collision Tests
print("\n--- Rectangle-Rectangle Collision ---")

test("Overlapping rects (partial)",
    shapes.rects_collide(0, 0, 20, 20, 15, 0, 20, 20) == true)

test("Overlapping rects (fully)",
    shapes.rects_collide(0, 0, 40, 40, 5, 5, 10, 10) == true)

test("Touching rects (edge)",
    shapes.rects_collide(0, 0, 20, 20, 20, 0, 20, 20) == true)

test("Non-overlapping rects (horizontal)",
    shapes.rects_collide(0, 0, 20, 20, 30, 0, 20, 20) == false)

test("Non-overlapping rects (vertical)",
    shapes.rects_collide(0, 0, 20, 20, 0, 30, 20, 20) == false)

test("Same position rects",
    shapes.rects_collide(10, 10, 20, 20, 10, 10, 20, 20) == true)

test("Rects touching at corner",
    shapes.rects_collide(0, 0, 20, 20, 20, 20, 20, 20) == true)

test("Rects diagonal gap",
    shapes.rects_collide(0, 0, 10, 10, 20, 20, 10, 10) == false)
-- }}}

-- {{{ Circle-Rect Collision Tests
print("\n--- Circle-Rectangle Collision ---")

test("Circle inside rect",
    shapes.circle_rect_collide(50, 50, 5, 50, 50, 40, 40) == true)

test("Circle overlapping rect edge",
    shapes.circle_rect_collide(70, 50, 15, 50, 50, 40, 40) == true)

test("Circle touching rect edge",
    shapes.circle_rect_collide(80, 50, 10, 50, 50, 40, 40) == true)

test("Circle outside rect",
    shapes.circle_rect_collide(100, 50, 10, 50, 50, 40, 40) == false)

test("Circle at rect corner (overlapping)",
    shapes.circle_rect_collide(75, 75, 10, 50, 50, 40, 40) == true)

test("Circle at rect corner (not overlapping)",
    shapes.circle_rect_collide(85, 85, 5, 50, 50, 40, 40) == false)

test("Large circle containing rect",
    shapes.circle_rect_collide(50, 50, 100, 50, 50, 20, 20) == true)

test("Circle center on rect edge",
    shapes.circle_rect_collide(70, 50, 5, 50, 50, 40, 40) == true)
-- }}}

-- {{{ Distance Functions Tests
print("\n--- Distance Functions ---")

test("Distance squared basic",
    shapes.distance_squared(0, 0, 3, 4) == 25)

test("Distance squared same point",
    shapes.distance_squared(5, 5, 5, 5) == 0)

test("Distance squared negative coords",
    shapes.distance_squared(-3, -4, 0, 0) == 25)

test("Distance basic",
    approx_eq(shapes.distance(0, 0, 3, 4), 5))

test("Distance same point",
    shapes.distance(10, 10, 10, 10) == 0)

test("Distance horizontal",
    shapes.distance(0, 0, 10, 0) == 10)

test("Distance vertical",
    shapes.distance(0, 0, 0, 10) == 10)
-- }}}

-- {{{ Separation Vector Tests
print("\n--- Separation Vector ---")

local nx, ny, overlap

nx, ny, overlap = shapes.get_separation_vector(0, 0, 10, 20, 0, 10)
test("Separation vector direction (horizontal)",
    approx_eq(nx, 1) and approx_eq(ny, 0))

test("Separation vector overlap (touching)",
    approx_eq(overlap, 0))

nx, ny, overlap = shapes.get_separation_vector(0, 0, 10, 15, 0, 10)
test("Separation vector overlap (overlapping)",
    approx_eq(overlap, 5))

nx, ny, overlap = shapes.get_separation_vector(0, 0, 10, 30, 0, 10)
test("Separation vector overlap (not overlapping)",
    overlap < 0)

nx, ny, overlap = shapes.get_separation_vector(0, 0, 10, 0, 20, 10)
test("Separation vector direction (vertical)",
    approx_eq(nx, 0) and approx_eq(ny, 1))

nx, ny, overlap = shapes.get_separation_vector(5, 5, 10, 5, 5, 10)
test("Separation vector same position (arbitrary direction)",
    (nx ~= 0 or ny ~= 0) and approx_eq(overlap, 20))
-- }}}

-- {{{ Layer/Mask Filtering Tests
print("\n--- Layer/Mask Filtering ---")

test("Layer matches single mask",
    collision.layer_matches_mask("unit", {"unit"}) == true)

test("Layer matches one of multiple masks",
    collision.layer_matches_mask("building", {"unit", "building"}) == true)

test("Layer doesn't match mask",
    collision.layer_matches_mask("projectile", {"unit", "building"}) == false)

test("Nil mask matches all",
    collision.layer_matches_mask("anything", nil) == true)

test("Wildcard mask matches all",
    collision.layer_matches_mask("projectile", {"*"}) == true)

test("Empty mask matches nothing",
    collision.layer_matches_mask("unit", {}) == false)

test("Wildcard in mixed mask",
    collision.layer_matches_mask("debris", {"unit", "*"}) == true)
-- }}}

-- {{{ Layer Priority Tests
print("\n--- Layer Priority ---")

test("Unit priority is highest",
    collision.get_layer_priority("unit") == 100)

test("Building priority is medium",
    collision.get_layer_priority("building") == 50)

test("Unknown layer has zero priority",
    collision.get_layer_priority("unknown") == 0)

collision.set_layer_priority("custom", 75)
test("Custom layer priority can be set",
    collision.get_layer_priority("custom") == 75)
-- }}}

-- {{{ Collision Init Tests
print("\n--- Collision Init ---")

-- Reset for clean test
ecs.clear_all()
collision.reset()

test("Collision not initialized initially",
    collision.is_initialized() == false)

collision.init(ecs)

test("Collision initialized after init",
    collision.is_initialized() == true)

test("ECS reference stored",
    collision.get_ecs() == ecs)

-- Check component is registered
local defaults = ecs.get_component_defaults("collision")
test("Collision component registered",
    defaults ~= nil)

test("Default shape is circle",
    defaults.shape == "circle")

test("Default radius is 32",
    defaults.radius == 32)

test("Default layer is unit",
    defaults.layer == "unit")

test("Default solid is true",
    defaults.solid == true)

test("Default trigger is false",
    defaults.trigger == false)
-- }}}

-- {{{ shapes_collide Dispatch Tests
print("\n--- shapes_collide Dispatch ---")

-- Create mock position and collision data
local pos1, col1, pos2, col2

-- Circle-Circle dispatch
pos1 = {x = 0, y = 0}
col1 = {shape = "circle", radius = 10}
pos2 = {x = 15, y = 0}
col2 = {shape = "circle", radius = 10}

test("shapes_collide circle-circle (overlap)",
    collision.shapes_collide(pos1, col1, pos2, col2) == true)

pos2.x = 30
test("shapes_collide circle-circle (no overlap)",
    collision.shapes_collide(pos1, col1, pos2, col2) == false)

-- Circle-Rect dispatch
pos2 = {x = 15, y = 0}
col2 = {shape = "rect", width = 20, height = 20}

test("shapes_collide circle-rect (overlap)",
    collision.shapes_collide(pos1, col1, pos2, col2) == true)

pos2.x = 30
test("shapes_collide circle-rect (no overlap)",
    collision.shapes_collide(pos1, col1, pos2, col2) == false)

-- Rect-Circle dispatch (reversed order)
pos1 = {x = 0, y = 0}
col1 = {shape = "rect", width = 20, height = 20}
pos2 = {x = 15, y = 0}
col2 = {shape = "circle", radius = 10}

test("shapes_collide rect-circle (overlap)",
    collision.shapes_collide(pos1, col1, pos2, col2) == true)

-- Rect-Rect dispatch
col2 = {shape = "rect", width = 20, height = 20}

test("shapes_collide rect-rect (overlap)",
    collision.shapes_collide(pos1, col1, pos2, col2) == true)

pos2.x = 30
test("shapes_collide rect-rect (no overlap)",
    collision.shapes_collide(pos1, col1, pos2, col2) == false)

-- Point-Circle dispatch
pos1 = {x = 5, y = 0}
col1 = {shape = "point"}
pos2 = {x = 0, y = 0}
col2 = {shape = "circle", radius = 10}

test("shapes_collide point-circle (inside)",
    collision.shapes_collide(pos1, col1, pos2, col2) == true)

pos1.x = 20
test("shapes_collide point-circle (outside)",
    collision.shapes_collide(pos1, col1, pos2, col2) == false)

-- Point-Rect dispatch
pos1 = {x = 5, y = 5}
col2 = {shape = "rect", width = 20, height = 20}

test("shapes_collide point-rect (inside)",
    collision.shapes_collide(pos1, col1, pos2, col2) == true)

pos1.x = 50
test("shapes_collide point-rect (outside)",
    collision.shapes_collide(pos1, col1, pos2, col2) == false)

-- Point-Point dispatch
pos1 = {x = 5, y = 5}
col1 = {shape = "point"}
pos2 = {x = 5.5, y = 5}
col2 = {shape = "point"}

test("shapes_collide point-point (close enough)",
    collision.shapes_collide(pos1, col1, pos2, col2) == true)

pos2.x = 10
test("shapes_collide point-point (too far)",
    collision.shapes_collide(pos1, col1, pos2, col2) == false)
-- }}}

-- {{{ get_entity_radius Tests
print("\n--- get_entity_radius ---")

test("Circle radius returned directly",
    collision.get_entity_radius({shape = "circle", radius = 32}) == 32)

local rect_radius = collision.get_entity_radius({shape = "rect", width = 60, height = 80})
test("Rect returns half-diagonal",
    approx_eq(rect_radius, 50))  -- sqrt(60^2 + 80^2) / 2 = 100/2 = 50

test("Point has zero radius",
    collision.get_entity_radius({shape = "point"}) == 0)
-- }}}

-- {{{ Constants Tests
print("\n--- Constants ---")

test("SHAPE.CIRCLE defined",
    collision.SHAPE.CIRCLE == "circle")

test("SHAPE.RECT defined",
    collision.SHAPE.RECT == "rect")

test("SHAPE.POINT defined",
    collision.SHAPE.POINT == "point")

test("LAYER.UNIT defined",
    collision.LAYER.UNIT == "unit")

test("LAYER.BUILDING defined",
    collision.LAYER.BUILDING == "building")

test("LAYER.PROJECTILE defined",
    collision.LAYER.PROJECTILE == "projectile")

test("LAYER.TRIGGER defined",
    collision.LAYER.TRIGGER == "trigger")
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

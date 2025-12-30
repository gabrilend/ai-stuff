#!/usr/bin/env luajit
-- test_advanced_movement.lua
-- Unit tests for advanced movement behaviors (Issue 404d)
--
-- Tests local avoidance, formation movement, and movement prediction.
-- These are optional polish features for a more authentic WC3 experience.
--
-- Run from project root: luajit src/tests/test_advanced_movement.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local ecs = require("runtime.ecs")

-- {{{ Register required components
-- Register components needed for tests (normally done by wc3_components)
local position_registered = ecs.get_component_defaults("position")
if not position_registered then
    ecs.register_component("position", {
        x = 0.0,
        y = 0.0,
        z = 0.0,
        facing = 0.0,
    })
end
-- }}}

local movement = require("runtime.systems.movement")
local avoidance = require("runtime.systems.avoidance")
local formation = require("runtime.systems.formation")
local prediction = require("runtime.systems.prediction")

-- {{{ Test utilities
local tests_run = 0
local tests_passed = 0
local tests_failed = 0

-- {{{ test
local function test(name, condition, msg)
    tests_run = tests_run + 1
    if condition then
        tests_passed = tests_passed + 1
        print("  [PASS] " .. name)
        return true
    else
        tests_failed = tests_failed + 1
        print("  [FAIL] " .. name .. (msg and ": " .. msg or ""))
        return false
    end
end
-- }}}

-- {{{ test_section
local function test_section(name)
    print("\n=== " .. name .. " ===")
end
-- }}}

-- {{{ approx_eq
local function approx_eq(a, b, epsilon)
    epsilon = epsilon or 0.001
    return math.abs(a - b) < epsilon
end
-- }}}

-- {{{ setup
local function setup()
    ecs.reset()
end
-- }}}

-- {{{ create_test_entity
-- Creates an entity with position and movement components.
local function create_test_entity(x, y, options)
    options = options or {}
    local entity = ecs.create_entity()
    ecs.add_component(entity, "position", {
        x = x or 0,
        y = y or 0,
        facing = options.facing or 0,
    })
    ecs.add_component(entity, "movement", {
        speed = options.speed or 270,
        speed_modifier = options.speed_modifier or 1.0,
        turn_rate = options.turn_rate or 10.0,
        pathing_type = options.pathing_type or "foot",
        collision_radius = options.collision_radius or 32,
    })
    return entity
end
-- }}}
-- }}}

-- ============================================================================
-- AVOIDANCE MODULE TESTS
-- ============================================================================

-- {{{ Avoidance Module Constants Tests
test_section("Avoidance Module Constants")

test("DEFAULT_RADIUS defined",
    avoidance.DEFAULT_RADIUS ~= nil)

test("DEFAULT_RADIUS is positive",
    avoidance.DEFAULT_RADIUS > 0)

test("AVOIDANCE_STRENGTH defined",
    avoidance.AVOIDANCE_STRENGTH ~= nil)

test("MAX_STEERING defined",
    avoidance.MAX_STEERING ~= nil)
-- }}}

-- {{{ Calculate Steering Tests
test_section("Calculate Steering")

setup()

-- Two entities overlapping
local entity1 = create_test_entity(0, 0)
local entity2 = create_test_entity(10, 0)  -- Very close (within combined radii)

local steer_x, steer_y = avoidance.calculate_steering(entity1, {entity1, entity2})

test("Steering returns two values",
    steer_x ~= nil and steer_y ~= nil)

test("Steering pushes away from nearby entity",
    steer_x < 0)  -- Should push left (away from entity2 at +x)

test("Steering y is near zero for horizontal pair",
    approx_eq(steer_y, 0, 0.1))

-- Test with entity far away (no steering needed)
setup()
entity1 = create_test_entity(0, 0)
entity2 = create_test_entity(1000, 0)  -- Far away

steer_x, steer_y = avoidance.calculate_steering(entity1, {entity1, entity2})

test("No steering when far apart",
    approx_eq(steer_x, 0, 0.001) and approx_eq(steer_y, 0, 0.001))

-- Test steering with multiple nearby entities
setup()
entity1 = create_test_entity(0, 0)
entity2 = create_test_entity(20, 0)   -- Close on right
local entity3 = create_test_entity(0, 20)   -- Close above

steer_x, steer_y = avoidance.calculate_steering(entity1, {entity1, entity2, entity3})

test("Steering from multiple entities",
    steer_x < 0 or steer_y < 0)  -- Should push away from both
-- }}}

-- {{{ Apply Steering Tests
test_section("Apply Steering")

setup()

local entity = create_test_entity(100, 100)
local pos_before = ecs.get_component(entity, "position")
local x_before, y_before = pos_before.x, pos_before.y

avoidance.apply_steering(entity, -1, 0, 0.016)

local pos_after = ecs.get_component(entity, "position")

test("Apply steering moves entity",
    pos_after.x ~= x_before or pos_after.y ~= y_before)

test("Entity moved in steering direction",
    pos_after.x < x_before)

-- Test steering magnitude limit
setup()
entity = create_test_entity(0, 0, {speed = 100})

avoidance.apply_steering(entity, 100, 100, 0.016)  -- Large steering

pos_after = ecs.get_component(entity, "position")
local move_dist = math.sqrt(pos_after.x^2 + pos_after.y^2)

test("Steering magnitude is limited",
    move_dist < 10)  -- Should be much smaller than raw 100,100 vector
-- }}}

-- {{{ Avoidance System Integration Tests
test_section("Avoidance System Integration")

setup()

-- Create two entities moving toward same point
-- Use slower speed so avoidance has time to take effect
entity1 = create_test_entity(0, 0, {speed = 100, turn_rate = 100, collision_radius = 32})
entity2 = create_test_entity(50, 0, {speed = 100, turn_rate = 100, collision_radius = 32})

-- Move them toward a shared destination
movement.set_path(entity1, {{x = 25, y = 0}})
movement.set_path(entity2, {{x = 25, y = 0}})

-- Run several ticks while they're still moving
-- At 100 u/s, entity1 reaches 25,0 in 0.25s (16 ticks at 16ms)
-- Check mid-movement to see avoidance effect
for i = 1, 10 do
    ecs.update_systems(0.016)
end

local pos1 = ecs.get_component(entity1, "position")
local pos2 = ecs.get_component(entity2, "position")

local dist = math.sqrt((pos2.x - pos1.x)^2 + (pos2.y - pos1.y)^2)

-- During movement, avoidance should prevent complete overlap
-- Even if they end up close, they shouldn't be at exactly same position
test("Entities have some separation during movement",
    dist > 1)

-- Test avoidance system registered
local sys = ecs.get_system("avoidance")
test("Avoidance system registered",
    sys ~= nil)

test("Avoidance system is enabled",
    sys.enabled == true)
-- }}}

-- {{{ Invalid Entity Handling Tests
test_section("Avoidance Invalid Entity Handling")

setup()

local steer_x, steer_y = avoidance.calculate_steering(999999, {})

test("calculate_steering returns 0,0 for invalid entity",
    steer_x == 0 and steer_y == 0)

local result = avoidance.apply_steering(999999, 1, 1, 0.016)

test("apply_steering returns false for invalid entity",
    result == false)

-- Entity without movement component
local no_mov = ecs.create_entity()
ecs.add_component(no_mov, "position", {x = 0, y = 0})

steer_x, steer_y = avoidance.calculate_steering(no_mov, {no_mov})

test("calculate_steering returns 0,0 without movement",
    steer_x == 0 and steer_y == 0)
-- }}}

-- ============================================================================
-- FORMATION MODULE TESTS
-- ============================================================================

-- {{{ Formation Type Constants Tests
test_section("Formation Type Constants")

test("TYPE.LINE defined",
    formation.TYPE.LINE == "line")

test("TYPE.BOX defined",
    formation.TYPE.BOX == "box")

test("TYPE.WEDGE defined",
    formation.TYPE.WEDGE == "wedge")

test("TYPE.COLUMN defined",
    formation.TYPE.COLUMN == "column")

test("DEFAULT_SPACING defined",
    formation.DEFAULT_SPACING ~= nil and formation.DEFAULT_SPACING > 0)
-- }}}

-- {{{ Line Formation Tests
test_section("Line Formation")

setup()

local entities = {}
for i = 1, 5 do
    entities[i] = create_test_entity(0, 0)
end

local target = {x = 100, y = 100}
local positions = formation.calculate_positions(entities, target, formation.TYPE.LINE)

test("Line formation returns positions for all entities",
    #positions == 5)

-- Check that positions are horizontally spaced
test("Line formation positions are on same y",
    positions[1].y == positions[3].y and positions[3].y == positions[5].y)

test("Line formation is centered on target",
    approx_eq(positions[3].x, target.x, 1))  -- Middle unit near center

test("Line formation has correct spacing",
    math.abs(positions[2].x - positions[1].x) == formation.DEFAULT_SPACING)

-- Check all positions are unique
local unique = true
for i = 1, #positions - 1 do
    for j = i + 1, #positions do
        if positions[i].x == positions[j].x and positions[i].y == positions[j].y then
            unique = false
            break
        end
    end
end
test("Line formation positions are unique", unique)
-- }}}

-- {{{ Box Formation Tests
test_section("Box Formation")

setup()

entities = {}
for i = 1, 9 do
    entities[i] = create_test_entity(0, 0)
end

target = {x = 200, y = 200}
positions = formation.calculate_positions(entities, target, formation.TYPE.BOX)

test("Box formation returns positions for all entities",
    #positions == 9)

-- 9 units should form a 3x3 box
local rows = {}
for i, pos in ipairs(positions) do
    rows[pos.y] = (rows[pos.y] or 0) + 1
end
local row_count = 0
for _ in pairs(rows) do row_count = row_count + 1 end

test("Box formation has multiple rows",
    row_count == 3)

test("Box formation is centered on target y",
    approx_eq(positions[5].y, target.y, formation.DEFAULT_SPACING))
-- }}}

-- {{{ Wedge Formation Tests
test_section("Wedge Formation")

setup()

entities = {}
for i = 1, 7 do
    entities[i] = create_test_entity(0, 0)
end

target = {x = 300, y = 300}
positions = formation.calculate_positions(entities, target, formation.TYPE.WEDGE)

test("Wedge formation returns positions for all entities",
    #positions == 7)

-- First entity (leader) should be at the point
test("Wedge leader is at front",
    positions[1].y >= positions[3].y)

-- Wedge should be V-shaped
test("Wedge left/right entities are behind leader",
    positions[2].y < positions[1].y and positions[3].y < positions[1].y)
-- }}}

-- {{{ Column Formation Tests
test_section("Column Formation")

setup()

entities = {}
for i = 1, 4 do
    entities[i] = create_test_entity(0, 0)
end

target = {x = 400, y = 400}
positions = formation.calculate_positions(entities, target, formation.TYPE.COLUMN)

test("Column formation returns positions for all entities",
    #positions == 4)

-- All on same x
test("Column formation all on same x",
    positions[1].x == positions[2].x and
    positions[2].x == positions[3].x and
    positions[3].x == positions[4].x)

-- Spaced vertically
test("Column formation spaced vertically",
    positions[1].y > positions[2].y and
    positions[2].y > positions[3].y)
-- }}}

-- {{{ Formation Edge Cases Tests
test_section("Formation Edge Cases")

setup()

-- Empty entity list
local empty_positions = formation.calculate_positions({}, {x = 0, y = 0}, formation.TYPE.LINE)
test("Empty entities returns empty positions",
    #empty_positions == 0)

-- Single entity
local single = create_test_entity(0, 0)
local single_positions = formation.calculate_positions({single}, {x = 50, y = 50}, formation.TYPE.LINE)
test("Single entity gets target position",
    #single_positions == 1 and single_positions[1].x == 50)

-- Two entities
entities = {create_test_entity(0, 0), create_test_entity(0, 0)}
positions = formation.calculate_positions(entities, {x = 100, y = 100}, formation.TYPE.BOX)
test("Two entities form minimal box",
    #positions == 2)
-- }}}

-- {{{ Move Group Tests
test_section("Move Group")

setup()

-- Need orders module for move_group
local orders_ok, orders = pcall(require, "runtime.orders")
if not orders_ok then
    print("  [SKIP] Orders module not available")
else
    entities = {}
    for i = 1, 3 do
        local e = create_test_entity(i * 100, 0)
        ecs.add_component(e, "orders", {})
        entities[i] = e
    end

    target = {x = 500, y = 500}
    local success = formation.move_group(entities, target, formation.TYPE.LINE)

    test("move_group returns true",
        success == true)

    -- Check that orders were issued
    local has_orders = true
    for _, e in ipairs(entities) do
        if not orders.has_orders(e) then
            has_orders = false
            break
        end
    end
    test("move_group issues orders to all entities",
        has_orders)
end
-- }}}

-- ============================================================================
-- PREDICTION MODULE TESTS
-- ============================================================================

-- {{{ Prediction Module Tests
test_section("Movement Prediction")

setup()

local entity = create_test_entity(0, 0, {speed = 100, turn_rate = 100})

-- Not moving - should return current position
local pred = prediction.predict_position(entity, 1.0)

test("predict_position returns table",
    type(pred) == "table")

test("predict_position when idle returns current pos",
    pred.x == 0 and pred.y == 0)

-- Set a path
movement.set_path(entity, {{x = 100, y = 0}})

-- Predict 0.5 seconds ahead at 100 units/sec = 50 units
pred = prediction.predict_position(entity, 0.5)

test("predict_position with path returns future pos",
    approx_eq(pred.x, 50, 1))

test("predict_position y unchanged for horizontal path",
    approx_eq(pred.y, 0, 0.1))

-- Predict beyond path end
pred = prediction.predict_position(entity, 10.0)

test("predict_position beyond path returns destination",
    approx_eq(pred.x, 100, 1) and approx_eq(pred.y, 0, 0.1))
-- }}}

-- {{{ Multi-Waypoint Prediction Tests
test_section("Multi-Waypoint Prediction")

setup()

local entity = create_test_entity(0, 0, {speed = 100, turn_rate = 100})

-- L-shaped path: 100 right, then 100 up
movement.set_path(entity, {{x = 100, y = 0}, {x = 100, y = 100}})

-- 0.5 sec at 100 speed = 50 units, still on first segment
local pred = prediction.predict_position(entity, 0.5)
test("Prediction on first segment",
    approx_eq(pred.x, 50, 1) and approx_eq(pred.y, 0, 1))

-- 1.5 sec = 150 units, should be 50 units up second segment
pred = prediction.predict_position(entity, 1.5)
test("Prediction on second segment",
    approx_eq(pred.x, 100, 1) and approx_eq(pred.y, 50, 1))

-- Test with speed modifier
setup()
entity = create_test_entity(0, 0, {speed = 100, speed_modifier = 2.0, turn_rate = 100})
movement.set_path(entity, {{x = 100, y = 0}})

pred = prediction.predict_position(entity, 0.25)  -- 0.25 sec * 200 speed = 50 units
test("Prediction respects speed modifier",
    approx_eq(pred.x, 50, 1))
-- }}}

-- {{{ Prediction Invalid Entity Tests
test_section("Prediction Invalid Entity Handling")

setup()

local pred = prediction.predict_position(999999, 1.0)
test("predict_position returns nil for invalid entity",
    pred == nil)

-- Entity without movement
local no_mov = ecs.create_entity()
ecs.add_component(no_mov, "position", {x = 50, y = 50})

pred = prediction.predict_position(no_mov, 1.0)
test("predict_position returns nil without movement",
    pred == nil)

-- Negative time
setup()
local entity = create_test_entity(0, 0, {speed = 100})
movement.set_path(entity, {{x = 100, y = 0}})

pred = prediction.predict_position(entity, -1.0)
test("predict_position handles negative time",
    pred ~= nil and pred.x == 0)  -- Should return current position
-- }}}

-- {{{ Time To Arrival Tests
test_section("Time To Arrival Prediction")

setup()

local entity = create_test_entity(0, 0, {speed = 100, turn_rate = 100})
movement.set_path(entity, {{x = 100, y = 0}})

local time = prediction.time_to_arrival(entity)

test("time_to_arrival returns number",
    type(time) == "number")

test("time_to_arrival calculation correct",
    approx_eq(time, 1.0, 0.01))  -- 100 units at 100 speed = 1 second

-- Multi-waypoint path
setup()
entity = create_test_entity(0, 0, {speed = 100, turn_rate = 100})
movement.set_path(entity, {{x = 100, y = 0}, {x = 100, y = 100}})

time = prediction.time_to_arrival(entity)
test("time_to_arrival sums path segments",
    approx_eq(time, 2.0, 0.01))  -- 200 total units
-- }}}

-- {{{ Summary
print("\n" .. string.rep("=", 50))
print(string.format("Tests: %d passed, %d failed, %d total",
                    tests_passed, tests_failed, tests_run))

if tests_failed > 0 then
    print("SOME TESTS FAILED")
    os.exit(1)
else
    print("ALL TESTS PASSED")
    os.exit(0)
end
-- }}}

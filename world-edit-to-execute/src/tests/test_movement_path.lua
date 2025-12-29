#!/usr/bin/env luajit
-- test_movement_path.lua
-- Unit tests for path following logic (Issue 404b)
--
-- Tests path setting, waypoint progression, distance calculations,
-- movement execution, and facing updates.
--
-- Run from project root: luajit src/tests/test_movement_path.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local ecs = require("runtime.ecs")

-- {{{ Register position component
-- Register position component for tests (normally done by wc3_components)
-- This keeps the test self-contained without requiring all WC3 components.
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
-- }}}

-- {{{ Set Path Tests
test_section("Set Path")

setup()

local entity = ecs.create_entity()
ecs.add_component(entity, "position", {x = 0, y = 0, facing = 0})
ecs.add_component(entity, "movement", {})

-- Test successful set_path
local path = {{x = 100, y = 100}, {x = 200, y = 200}}
test("set_path returns true",
    movement.set_path(entity, path) == true)

local mov = ecs.get_component(entity, "movement")
test("path is set",
    mov.path ~= nil)
test("path_index starts at 1",
    mov.path_index == 1)
test("target set to final waypoint",
    mov.target ~= nil and mov.target.x == 200 and mov.target.y == 200)
test("is_moving returns true after set_path",
    movement.is_moving(entity) == true)

-- Test empty path rejected
test("set_path rejects empty path",
    movement.set_path(entity, {}) == false)

-- Test nil path rejected
test("set_path rejects nil path",
    movement.set_path(entity, nil) == false)

-- Test path overwrite
local new_path = {{x = 50, y = 50}}
movement.set_path(entity, new_path)
mov = ecs.get_component(entity, "movement")
test("set_path overwrites existing path",
    #mov.path == 1 and mov.path[1].x == 50)
test("path_index reset on overwrite",
    mov.path_index == 1)

-- Test invalid entity
test("set_path returns false for invalid entity",
    movement.set_path(999999, {{x = 1, y = 1}}) == false)
-- }}}

-- {{{ Distance Helper Tests
test_section("Distance Helpers")

setup()

local entity = ecs.create_entity()
ecs.add_component(entity, "position", {x = 0, y = 0, facing = 0})
ecs.add_component(entity, "movement", {})

-- Test distance_to_point
test("distance_to_point horizontal",
    approx_eq(movement.distance_to_point(entity, 100, 0), 100))

test("distance_to_point vertical",
    approx_eq(movement.distance_to_point(entity, 0, 100), 100))

test("distance_to_point diagonal",
    approx_eq(movement.distance_to_point(entity, 100, 100), 141.421, 0.01))

test("distance_to_point at origin",
    movement.distance_to_point(entity, 0, 0) == 0)

test("distance_to_point invalid entity",
    movement.distance_to_point(999999, 100, 100) == nil)

-- Test distance_to_next_waypoint
test("distance_to_next_waypoint nil when no path",
    movement.distance_to_next_waypoint(entity) == nil)

movement.set_path(entity, {{x = 100, y = 0}, {x = 200, y = 0}})
test("distance_to_next_waypoint returns correct value",
    approx_eq(movement.distance_to_next_waypoint(entity), 100))

-- Test distance_to_target
test("distance_to_target returns distance to final",
    approx_eq(movement.distance_to_target(entity), 200))

-- Clear path and test
movement.clear_path(entity)
test("distance_to_next_waypoint nil after clear",
    movement.distance_to_next_waypoint(entity) == nil)
test("distance_to_target nil after clear",
    movement.distance_to_target(entity) == nil)
-- }}}

-- {{{ Time to Destination Tests
test_section("Time to Destination")

setup()

local entity = ecs.create_entity()
ecs.add_component(entity, "position", {x = 0, y = 0, facing = 0})
ecs.add_component(entity, "movement", {speed = 270, speed_modifier = 1.0})

-- No path - should return nil
test("time_to_destination nil when no path",
    movement.time_to_destination(entity) == nil)

-- Set path 270 units away at speed 270 = 1 second
movement.set_path(entity, {{x = 270, y = 0}})
test("time_to_destination at normal speed",
    approx_eq(movement.time_to_destination(entity), 1.0))

-- Speed modifier 1.5 = 270 * 1.5 = 405 (under cap)
-- Time = 270 / 405 = 0.667
local mov = ecs.get_component(entity, "movement")
mov.speed_modifier = 1.5
test("time_to_destination with speed modifier",
    approx_eq(movement.time_to_destination(entity), 270 / 405, 0.01))
-- }}}

-- {{{ Movement Execution Tests
test_section("Movement Execution")

setup()

local entity = ecs.create_entity()
ecs.add_component(entity, "position", {x = 0, y = 0, facing = 0})
ecs.add_component(entity, "movement", {
    speed = 100,  -- 100 units per second
    speed_modifier = 1.0,
    turn_rate = 10.0,  -- Fast turn for testing
})

-- Set simple path
movement.set_path(entity, {{x = 100, y = 0}})

-- Run one tick at 62.5 Hz (0.016 seconds)
-- Should move 100 * 0.016 = 1.6 units
ecs.update_systems(0.016)

local pos = ecs.get_component(entity, "position")
test("Entity moves along path",
    pos.x > 0)
test("Movement distance correct for dt",
    approx_eq(pos.x, 1.6, 0.1))
test("Y position unchanged",
    pos.y == 0)

-- Run more ticks to reach waypoint
for i = 1, 100 do
    ecs.update_systems(0.016)
end

pos = ecs.get_component(entity, "position")
local mov = ecs.get_component(entity, "movement")
test("Entity reaches waypoint",
    pos.x >= 96)  -- Should be at or near 100 (within ARRIVAL_THRESHOLD)
test("Path cleared after reaching end",
    mov.path == nil or mov.path_index > #(mov.path or {}))
test("is_moving false after path complete",
    movement.is_moving(entity) == false)
-- }}}

-- {{{ Multi-Waypoint Path Tests
test_section("Multi-Waypoint Path")

setup()

local entity = ecs.create_entity()
ecs.add_component(entity, "position", {x = 0, y = 0, facing = 0})
ecs.add_component(entity, "movement", {
    speed = 1000,  -- Fast speed to traverse quickly
    speed_modifier = 1.0,
    turn_rate = 100.0,  -- Very fast turn
})

-- L-shaped path: right then up
movement.set_path(entity, {
    {x = 10, y = 0},
    {x = 10, y = 10},
    {x = 20, y = 10},
})

test("Initial waypoint count is 3",
    movement.get_remaining_waypoints(entity) == 3)

-- Run enough ticks to reach first waypoint
for i = 1, 20 do
    ecs.update_systems(0.016)
end

local mov = ecs.get_component(entity, "movement")
test("Waypoint progression happens",
    mov.path_index > 1 or mov.path == nil)

-- Run more to complete path
for i = 1, 100 do
    ecs.update_systems(0.016)
end

local pos = ecs.get_component(entity, "position")
test("Entity reaches final destination x",
    approx_eq(pos.x, 20, movement.ARRIVAL_THRESHOLD))
test("Entity reaches final destination y",
    approx_eq(pos.y, 10, movement.ARRIVAL_THRESHOLD))
test("Path complete",
    movement.is_moving(entity) == false)
-- }}}

-- {{{ Facing Update Tests
test_section("Facing Update")

setup()

local entity = ecs.create_entity()
ecs.add_component(entity, "position", {x = 0, y = 0, facing = 0})
ecs.add_component(entity, "movement", {
    speed = 10,  -- Slow speed
    speed_modifier = 1.0,
    turn_rate = 1.0,  -- Slow turn for testing rotation
})

-- Path to the right (facing should be 0)
movement.set_path(entity, {{x = 100, y = 0}})
ecs.update_systems(0.016)

local pos = ecs.get_component(entity, "position")
test("Facing toward right is ~0",
    approx_eq(pos.facing, 0, 0.1))

-- New path upward (facing should rotate toward pi/2)
setup()
entity = ecs.create_entity()
ecs.add_component(entity, "position", {x = 0, y = 0, facing = 0})
ecs.add_component(entity, "movement", {
    speed = 10,
    speed_modifier = 1.0,
    turn_rate = 100.0,  -- Fast turn
})

movement.set_path(entity, {{x = 0, y = 100}})
ecs.update_systems(0.016)

pos = ecs.get_component(entity, "position")
test("Facing toward up is ~pi/2",
    approx_eq(pos.facing, math.pi / 2, 0.1))

-- Test turn rate limiting
setup()
entity = ecs.create_entity()
ecs.add_component(entity, "position", {x = 0, y = 0, facing = 0})
ecs.add_component(entity, "movement", {
    speed = 10,
    speed_modifier = 1.0,
    turn_rate = 0.5,  -- Slow turn - 0.5 rad/sec
})

movement.set_path(entity, {{x = 0, y = 100}})  -- Target facing is pi/2 (1.57 rad)
ecs.update_systems(0.016)  -- Turn rate allows 0.5 * 0.016 = 0.008 rad

pos = ecs.get_component(entity, "position")
test("Turn rate limits rotation per tick",
    pos.facing > 0 and pos.facing < math.pi / 4)  -- Should have turned partially
-- }}}

-- {{{ Arrival Threshold Tests
test_section("Arrival Threshold")

test("ARRIVAL_THRESHOLD constant defined",
    movement.ARRIVAL_THRESHOLD ~= nil)

test("ARRIVAL_THRESHOLD is reasonable value",
    movement.ARRIVAL_THRESHOLD > 0 and movement.ARRIVAL_THRESHOLD < 100)

setup()

local entity = ecs.create_entity()
ecs.add_component(entity, "position", {x = 0, y = 0, facing = 0})
ecs.add_component(entity, "movement", {
    speed = 10000,  -- Very fast
    speed_modifier = 1.0,
    turn_rate = 100.0,
})

-- Path to a point very close
movement.set_path(entity, {{x = movement.ARRIVAL_THRESHOLD - 1, y = 0}})

-- Should immediately consider arrived
ecs.update_systems(0.001)

local mov = ecs.get_component(entity, "movement")
test("Immediate arrival when within threshold",
    mov.path == nil)
-- }}}

-- {{{ Speed Modifier Impact Tests
test_section("Speed Modifier Impact on Movement")

setup()

local entity = ecs.create_entity()
ecs.add_component(entity, "position", {x = 0, y = 0, facing = 0})
ecs.add_component(entity, "movement", {
    speed = 100,
    speed_modifier = 2.0,  -- Double speed
    turn_rate = 100.0,
})

movement.set_path(entity, {{x = 100, y = 0}})
ecs.update_systems(0.016)

local pos = ecs.get_component(entity, "position")
-- At 2x speed: 100 * 2.0 * 0.016 = 3.2 units
test("Speed modifier affects movement",
    approx_eq(pos.x, 3.2, 0.1))

-- Test slow modifier
setup()
entity = ecs.create_entity()
ecs.add_component(entity, "position", {x = 0, y = 0, facing = 0})
ecs.add_component(entity, "movement", {
    speed = 100,
    speed_modifier = 0.5,  -- Half speed
    turn_rate = 100.0,
})

movement.set_path(entity, {{x = 100, y = 0}})
ecs.update_systems(0.016)

pos = ecs.get_component(entity, "position")
-- At 0.5x speed: 100 * 0.5 * 0.016 = 0.8 units
test("Slow modifier reduces movement",
    approx_eq(pos.x, 0.8, 0.1))
-- }}}

-- {{{ Max Speed Cap Tests
test_section("Max Speed Cap")

setup()

local entity = ecs.create_entity()
ecs.add_component(entity, "position", {x = 0, y = 0, facing = 0})
ecs.add_component(entity, "movement", {
    speed = 500,
    speed_modifier = 2.0,  -- Would be 1000, but capped at 522
    turn_rate = 100.0,
})

movement.set_path(entity, {{x = 1000, y = 0}})
ecs.update_systems(0.016)

local pos = ecs.get_component(entity, "position")
-- Capped at 522: 522 * 0.016 = 8.352 units
test("Speed capped at MAX",
    pos.x < 9)  -- Should be around 8.35, not 16
test("Speed not zero (still moving)",
    pos.x > 5)
-- }}}

-- {{{ Interpolation During Movement Tests
test_section("Interpolation During Movement")

setup()

local entity = ecs.create_entity()
ecs.add_component(entity, "position", {x = 0, y = 0, facing = 0})
ecs.add_component(entity, "movement", {
    speed = 100,
    speed_modifier = 1.0,
    turn_rate = 100.0,
    last_x = 0,
    last_y = 0,
})

movement.set_path(entity, {{x = 100, y = 0}})

-- Before first update, interpolation should work
local x, y = movement.get_interpolated_position(entity, 0.5)
test("Interpolation before movement",
    x == 0 and y == 0)  -- No movement yet, last = current = 0

-- Run one tick
ecs.update_systems(0.016)

-- Now last_x should be 0 (before tick), current should be ~1.6
local mov = ecs.get_component(entity, "movement")
local pos = ecs.get_component(entity, "position")

test("last_x preserved from before tick",
    mov.last_x == 0)

x, y = movement.get_interpolated_position(entity, 0)
test("Interpolation alpha=0 returns last position",
    x == 0)

x, y = movement.get_interpolated_position(entity, 1)
test("Interpolation alpha=1 returns current position",
    approx_eq(x, pos.x, 0.01))

x, y = movement.get_interpolated_position(entity, 0.5)
test("Interpolation alpha=0.5 returns midpoint",
    approx_eq(x, pos.x / 2, 0.01))
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

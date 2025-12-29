#!/usr/bin/env luajit
-- test_movement_core.lua
-- Unit tests for the core movement system (Issue 404a)
--
-- Tests movement component creation, system registration, interpolation,
-- and state query functions.
--
-- Run from project root: luajit src/tests/test_movement_core.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local ecs = require("runtime.ecs")

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

-- {{{ Speed Constants Tests
test_section("Speed Constants")

test("SPEED.VERY_SLOW defined",
    movement.SPEED.VERY_SLOW == 150)

test("SPEED.SLOW defined",
    movement.SPEED.SLOW == 220)

test("SPEED.NORMAL defined",
    movement.SPEED.NORMAL == 270)

test("SPEED.FAST defined",
    movement.SPEED.FAST == 320)

test("SPEED.VERY_FAST defined",
    movement.SPEED.VERY_FAST == 400)

test("SPEED.MAX defined (WC3 cap)",
    movement.SPEED.MAX == 522)

test("MIN_SPEED_MODIFIER defined",
    movement.MIN_SPEED_MODIFIER == 0.1)

test("MAX_SPEED_MODIFIER defined",
    movement.MAX_SPEED_MODIFIER == 4.0)
-- }}}

-- {{{ Pathing Type Constants Tests
test_section("Pathing Type Constants")

test("PATHING_TYPE.FOOT defined",
    movement.PATHING_TYPE.FOOT == "foot")

test("PATHING_TYPE.HORSE defined",
    movement.PATHING_TYPE.HORSE == "horse")

test("PATHING_TYPE.FLY defined",
    movement.PATHING_TYPE.FLY == "fly")

test("PATHING_TYPE.FLOAT defined",
    movement.PATHING_TYPE.FLOAT == "float")

test("PATHING_TYPE.HOVER defined",
    movement.PATHING_TYPE.HOVER == "hover")

test("PATHING_TYPE.AMPHIBIOUS defined",
    movement.PATHING_TYPE.AMPHIBIOUS == "amphibious")
-- }}}

-- {{{ Component Defaults Tests
test_section("Component Defaults")

test("DEFAULTS.speed is 270",
    movement.DEFAULTS.speed == 270)

test("DEFAULTS.speed_modifier is 1.0",
    movement.DEFAULTS.speed_modifier == 1.0)

test("DEFAULTS.target is nil",
    movement.DEFAULTS.target == nil)

test("DEFAULTS.path is nil",
    movement.DEFAULTS.path == nil)

test("DEFAULTS.path_index is 1",
    movement.DEFAULTS.path_index == 1)

test("DEFAULTS.pathing_type is foot",
    movement.DEFAULTS.pathing_type == "foot")

test("DEFAULTS.turn_rate is 0.6",
    movement.DEFAULTS.turn_rate == 0.6)

test("DEFAULTS.last_x is 0",
    movement.DEFAULTS.last_x == 0)

test("DEFAULTS.last_y is 0",
    movement.DEFAULTS.last_y == 0)
-- }}}

-- {{{ Component Creation Tests
test_section("Component Creation")

local comp1 = movement.create_component()
test("create_component returns table",
    type(comp1) == "table")

test("Default speed applied",
    comp1.speed == 270)

test("Default pathing_type applied",
    comp1.pathing_type == "foot")

local comp2 = movement.create_component({
    speed = 400,
    pathing_type = "fly",
})
test("Override speed applied",
    comp2.speed == 400)

test("Override pathing_type applied",
    comp2.pathing_type == "fly")

test("Non-overridden values use defaults",
    comp2.speed_modifier == 1.0)

-- Verify independence (changes to one don't affect another)
comp1.speed = 100
test("Components are independent",
    comp2.speed == 400)
-- }}}

-- {{{ ECS Integration Tests
test_section("ECS Integration")

setup()

-- Check component registration
test("Movement component registered",
    ecs.get_component_defaults("movement") ~= nil)

-- Check defaults match
local defaults = ecs.get_component_defaults("movement")
test("ECS defaults match module defaults",
    defaults.speed == movement.DEFAULTS.speed)

-- Create entity with position and movement
local entity = ecs.create_entity()
ecs.add_component(entity, "position", {x = 100, y = 200, facing = 0})
ecs.add_component(entity, "movement", {speed = 300})

test("Entity has movement component",
    ecs.has_component(entity, "movement"))

local mov = ecs.get_component(entity, "movement")
test("Movement component has correct speed",
    mov.speed == 300)

test("Movement component has default pathing_type",
    mov.pathing_type == "foot")
-- }}}

-- {{{ System Registration Tests
test_section("System Registration")

setup()

local sys = ecs.get_system("movement")
test("Movement system registered",
    sys ~= nil)

test("Movement system has correct name",
    sys.name == "movement")

test("Movement system requires position",
    sys.components[1] == "position" or sys.components[2] == "position")

test("Movement system requires movement",
    sys.components[1] == "movement" or sys.components[2] == "movement")

test("Movement system has priority 10",
    sys.priority == 10)

test("Movement system is enabled by default",
    sys.enabled == true)
-- }}}

-- {{{ Interpolation Tests
test_section("Interpolation")

setup()

local entity = ecs.create_entity()
ecs.add_component(entity, "position", {x = 100, y = 200, facing = 0})
ecs.add_component(entity, "movement", {
    last_x = 0,
    last_y = 0,
})

-- Test interpolation at alpha = 0 (start of tick)
local x, y = movement.get_interpolated_position(entity, 0)
test("Interpolation alpha=0 returns last position x",
    x == 0)
test("Interpolation alpha=0 returns last position y",
    y == 0)

-- Test interpolation at alpha = 1 (end of tick)
x, y = movement.get_interpolated_position(entity, 1)
test("Interpolation alpha=1 returns current position x",
    x == 100)
test("Interpolation alpha=1 returns current position y",
    y == 200)

-- Test interpolation at alpha = 0.5 (midpoint)
x, y = movement.get_interpolated_position(entity, 0.5)
test("Interpolation alpha=0.5 returns midpoint x",
    approx_eq(x, 50))
test("Interpolation alpha=0.5 returns midpoint y",
    approx_eq(y, 100))

-- Test alpha clamping
x, y = movement.get_interpolated_position(entity, -0.5)
test("Negative alpha clamped to 0",
    x == 0 and y == 0)

x, y = movement.get_interpolated_position(entity, 1.5)
test("Alpha > 1 clamped to 1",
    x == 100 and y == 200)

-- Test nil return for invalid entity
x, y = movement.get_interpolated_position(999999, 0.5)
test("Invalid entity returns nil",
    x == nil and y == nil)

-- Test entity without movement component
local pos_only = ecs.create_entity()
ecs.add_component(pos_only, "position", {x = 50, y = 50, facing = 0})
x, y = movement.get_interpolated_position(pos_only, 0.5)
test("Entity without movement returns nil",
    x == nil and y == nil)
-- }}}

-- {{{ State Query Tests
test_section("State Queries")

setup()

-- Test is_moving
local entity = ecs.create_entity()
ecs.add_component(entity, "position", {x = 0, y = 0, facing = 0})
ecs.add_component(entity, "movement", {
    path = nil,
    path_index = 1,
})

test("is_moving false when path is nil",
    movement.is_moving(entity) == false)

local mov = ecs.get_component(entity, "movement")
mov.path = {{x = 100, y = 100}, {x = 200, y = 200}}
mov.path_index = 1

test("is_moving true when path exists and index valid",
    movement.is_moving(entity) == true)

mov.path_index = 3  -- Past end of path
test("is_moving false when path_index exceeds path length",
    movement.is_moving(entity) == false)

-- Test get_target
mov.target = {x = 500, y = 600}
local target = movement.get_target(entity)
test("get_target returns target table",
    target ~= nil)
test("get_target returns correct x",
    target.x == 500)
test("get_target returns correct y",
    target.y == 600)

mov.target = nil
test("get_target returns nil when no target",
    movement.get_target(entity) == nil)

-- Test invalid entity
test("is_moving false for invalid entity",
    movement.is_moving(999999) == false)
test("get_target nil for invalid entity",
    movement.get_target(999999) == nil)
-- }}}

-- {{{ Effective Speed Tests
test_section("Effective Speed")

setup()

local entity = ecs.create_entity()
ecs.add_component(entity, "position", {x = 0, y = 0, facing = 0})
ecs.add_component(entity, "movement", {
    speed = 270,
    speed_modifier = 1.0,
})

test("Effective speed with modifier 1.0",
    movement.get_effective_speed(entity) == 270)

local mov = ecs.get_component(entity, "movement")
mov.speed_modifier = 1.5
test("Effective speed with modifier 1.5",
    movement.get_effective_speed(entity) == 405)

mov.speed_modifier = 0.5
test("Effective speed with modifier 0.5",
    movement.get_effective_speed(entity) == 135)

-- Test MAX speed cap
mov.speed = 400
mov.speed_modifier = 2.0  -- Would be 800, but cap is 522
test("Effective speed capped at MAX",
    movement.get_effective_speed(entity) == 522)

-- Test MIN modifier enforcement
mov.speed = 270
mov.speed_modifier = 0.01  -- Below MIN of 0.1
test("Effective speed uses MIN modifier",
    movement.get_effective_speed(entity) == 27)  -- 270 * 0.1

-- Test MAX modifier enforcement
mov.speed_modifier = 10.0  -- Above MAX of 4.0
test("Effective speed uses MAX modifier",
    movement.get_effective_speed(entity) == 522)  -- 270 * 4.0 = 1080, but capped at 522

-- Test invalid entity
test("Effective speed 0 for invalid entity",
    movement.get_effective_speed(999999) == 0)
-- }}}

-- {{{ Waypoint Query Tests
test_section("Waypoint Queries")

setup()

local entity = ecs.create_entity()
ecs.add_component(entity, "position", {x = 0, y = 0, facing = 0})
ecs.add_component(entity, "movement", {
    path = {{x = 100, y = 100}, {x = 200, y = 200}, {x = 300, y = 300}},
    path_index = 1,
})

-- Test get_current_waypoint
local wp = movement.get_current_waypoint(entity)
test("get_current_waypoint returns first waypoint",
    wp ~= nil and wp.x == 100 and wp.y == 100)

local mov = ecs.get_component(entity, "movement")
mov.path_index = 2
wp = movement.get_current_waypoint(entity)
test("get_current_waypoint returns second waypoint",
    wp ~= nil and wp.x == 200 and wp.y == 200)

mov.path_index = 4  -- Past end
wp = movement.get_current_waypoint(entity)
test("get_current_waypoint returns nil when past end",
    wp == nil)

-- Test get_remaining_waypoints
mov.path_index = 1
test("get_remaining_waypoints from start",
    movement.get_remaining_waypoints(entity) == 3)

mov.path_index = 2
test("get_remaining_waypoints from middle",
    movement.get_remaining_waypoints(entity) == 2)

mov.path_index = 3
test("get_remaining_waypoints at last",
    movement.get_remaining_waypoints(entity) == 1)

mov.path_index = 4
test("get_remaining_waypoints past end",
    movement.get_remaining_waypoints(entity) == 0)

-- Test with no path
mov.path = nil
test("get_current_waypoint nil when no path",
    movement.get_current_waypoint(entity) == nil)
test("get_remaining_waypoints 0 when no path",
    movement.get_remaining_waypoints(entity) == 0)
-- }}}

-- {{{ Speed Modifier Setter Tests
test_section("Speed Modifier Setter")

setup()

local entity = ecs.create_entity()
ecs.add_component(entity, "position", {x = 0, y = 0, facing = 0})
ecs.add_component(entity, "movement", {speed_modifier = 1.0})

test("set_speed_modifier returns true",
    movement.set_speed_modifier(entity, 1.5) == true)

local mov = ecs.get_component(entity, "movement")
test("speed_modifier updated",
    mov.speed_modifier == 1.5)

-- Test clamping to MIN
movement.set_speed_modifier(entity, 0.01)
test("speed_modifier clamped to MIN",
    mov.speed_modifier == movement.MIN_SPEED_MODIFIER)

-- Test clamping to MAX
movement.set_speed_modifier(entity, 10.0)
test("speed_modifier clamped to MAX",
    mov.speed_modifier == movement.MAX_SPEED_MODIFIER)

-- Test invalid entity
test("set_speed_modifier returns false for invalid entity",
    movement.set_speed_modifier(999999, 1.0) == false)
-- }}}

-- {{{ Clear Path Tests
test_section("Clear Path")

setup()

local entity = ecs.create_entity()
ecs.add_component(entity, "position", {x = 0, y = 0, facing = 0})
ecs.add_component(entity, "movement", {
    path = {{x = 100, y = 100}},
    path_index = 1,
    target = {x = 100, y = 100},
    speed = 300,  -- Should not be affected
})

test("clear_path returns true",
    movement.clear_path(entity) == true)

local mov = ecs.get_component(entity, "movement")
test("path cleared",
    mov.path == nil)
test("target cleared",
    mov.target == nil)
test("path_index reset to 1",
    mov.path_index == 1)
test("speed preserved",
    mov.speed == 300)

test("is_moving false after clear",
    movement.is_moving(entity) == false)

-- Test invalid entity
test("clear_path returns false for invalid entity",
    movement.clear_path(999999) == false)
-- }}}

-- {{{ System Update Tests
test_section("System Update (Interpolation)")

setup()

-- Create entity with position and movement
local entity = ecs.create_entity()
ecs.add_component(entity, "position", {x = 100, y = 200, facing = 0})
ecs.add_component(entity, "movement", {
    last_x = 50,
    last_y = 100,
})

-- Run system update
ecs.update_systems(0.016)  -- One tick at 62.5 Hz

-- Verify last_x/last_y updated to position before tick
local mov = ecs.get_component(entity, "movement")
test("System updates last_x to current position",
    mov.last_x == 100)
test("System updates last_y to current position",
    mov.last_y == 200)
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

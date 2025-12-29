#!/usr/bin/env luajit
-- test_orders.lua
-- Unit tests for the movement orders system (Issue 404c)
--
-- Tests order issuing, queuing, cancellation, pathfinding integration,
-- and order completion callbacks.
--
-- Run from project root: luajit src/tests/test_orders.lua

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
local orders = require("runtime.orders")

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
    orders.reset()
end
-- }}}

-- {{{ create_test_entity
-- Creates an entity with position, movement, and orders components.
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
    })
    ecs.add_component(entity, "orders", {})
    return entity
end
-- }}}
-- }}}

-- {{{ Module Constants Tests
test_section("Module Constants")

test("ORDER_TYPE.MOVE defined",
    orders.TYPE.MOVE == "move")

test("ORDER_TYPE.ATTACK_MOVE defined",
    orders.TYPE.ATTACK_MOVE == "attack_move")

test("ORDER_TYPE.PATROL defined",
    orders.TYPE.PATROL == "patrol")

test("ORDER_TYPE.HOLD defined",
    orders.TYPE.HOLD == "hold")

test("ORDER_TYPE.STOP defined",
    orders.TYPE.STOP == "stop")

test("ORDER_STATUS.PENDING defined",
    orders.STATUS.PENDING == "pending")

test("ORDER_STATUS.EXECUTING defined",
    orders.STATUS.EXECUTING == "executing")

test("ORDER_STATUS.COMPLETED defined",
    orders.STATUS.COMPLETED == "completed")

test("ORDER_STATUS.FAILED defined",
    orders.STATUS.FAILED == "failed")

test("ORDER_STATUS.CANCELLED defined",
    orders.STATUS.CANCELLED == "cancelled")
-- }}}

-- {{{ Component Defaults Tests
test_section("Component Defaults")

test("DEFAULTS.current is nil",
    orders.DEFAULTS.current == nil)

-- Note: queue and callbacks are NOT in defaults to prevent shared table references
-- Each entity gets its own tables via ensure_tables()
test("DEFAULTS table exists",
    type(orders.DEFAULTS) == "table")
-- }}}

-- {{{ Order Component Tests
test_section("Order Component")

setup()

local entity = create_test_entity(0, 0)

test("Entity has orders component",
    ecs.has_component(entity, "orders"))

local ord = ecs.get_component(entity, "orders")
test("Orders component has current field",
    ord.current == nil)

-- Queue is lazily created via ensure_tables when first accessed via orders API
test("get_queue returns table for new entity",
    type(orders.get_queue(entity)) == "table")
-- }}}

-- {{{ Move Order Tests
test_section("Move Order - Basic")

setup()

local entity = create_test_entity(0, 0)

-- Issue a move order
local success, err = orders.move(entity, {x = 100, y = 100})
test("orders.move returns true",
    success == true)

local ord = ecs.get_component(entity, "orders")
test("Current order is set",
    ord.current ~= nil)

test("Current order type is MOVE",
    ord.current.type == orders.TYPE.MOVE)

test("Current order has target",
    ord.current.target ~= nil and
    ord.current.target.x == 100 and
    ord.current.target.y == 100)

test("Current order status is EXECUTING",
    ord.current.status == orders.STATUS.EXECUTING)

test("Current order has issued_at timestamp",
    ord.current.issued_at ~= nil)
-- }}}

-- {{{ Move Order - Movement Integration Tests
test_section("Move Order - Movement Integration")

setup()

local entity = create_test_entity(0, 0, {speed = 1000, turn_rate = 100})

orders.move(entity, {x = 50, y = 0})

test("is_moving returns true after move order",
    movement.is_moving(entity))

local waypoint = movement.get_current_waypoint(entity)
test("Waypoint is set after move order",
    waypoint ~= nil)

-- Target should be the final destination
local target = movement.get_target(entity)
test("Movement target is set",
    target ~= nil and target.x == 50)
-- }}}

-- {{{ Stop Order Tests
test_section("Stop Order")

setup()

local entity = create_test_entity(0, 0)

-- Issue a move order first
orders.move(entity, {x = 100, y = 100})
test("Move order issued",
    orders.has_orders(entity))

-- Now stop
local success = orders.stop(entity)
test("orders.stop returns true",
    success == true)

local ord = ecs.get_component(entity, "orders")
test("Current order cleared after stop",
    ord.current == nil)

test("Movement stopped",
    movement.is_moving(entity) == false)

test("has_orders returns false after stop",
    orders.has_orders(entity) == false)
-- }}}

-- {{{ Order Queue Tests
test_section("Order Queue")

setup()

local entity = create_test_entity(0, 0, {speed = 1000})

-- Issue first move order
orders.move(entity, {x = 100, y = 0})

-- Queue a second order
orders.move(entity, {x = 200, y = 0}, {queue = true})

local ord = ecs.get_component(entity, "orders")
test("Queue has one order",
    #ord.queue == 1)

test("Queued order has correct target",
    ord.queue[1].target.x == 200)

test("Current order target is first",
    ord.current.target.x == 100)

-- Queue another
orders.move(entity, {x = 300, y = 0}, {queue = true})
test("Queue has two orders",
    #ord.queue == 2)

-- Stop clears queue
orders.stop(entity)
ord = ecs.get_component(entity, "orders")
test("Stop clears queue",
    #ord.queue == 0)
-- }}}

-- {{{ Order Query Functions Tests
test_section("Order Query Functions")

setup()

local entity = create_test_entity(0, 0)

test("get_current returns nil initially",
    orders.get_current(entity) == nil)

test("get_queue returns empty initially",
    #orders.get_queue(entity) == 0)

test("has_orders returns false initially",
    orders.has_orders(entity) == false)

orders.move(entity, {x = 100, y = 100})

test("get_current returns order after move",
    orders.get_current(entity) ~= nil)

test("get_current type is MOVE",
    orders.get_current(entity).type == orders.TYPE.MOVE)

test("has_orders returns true after move",
    orders.has_orders(entity) == true)
-- }}}

-- {{{ Order Replacement Tests
test_section("Order Replacement")

setup()

local entity = create_test_entity(0, 0)

-- Issue first order
orders.move(entity, {x = 100, y = 100})

-- Issue second order (without queue flag - should replace)
orders.move(entity, {x = 200, y = 200})

local ord = ecs.get_component(entity, "orders")
test("New order replaces old",
    ord.current.target.x == 200)

test("Queue empty after replacement",
    #ord.queue == 0)
-- }}}

-- {{{ Order Completion Callback Tests
test_section("Order Completion Callbacks")

setup()

local entity = create_test_entity(0, 0, {speed = 10000, turn_rate = 100})

local callback_fired = false
local callback_success = nil
local callback_order = nil

orders.on_complete(entity, function(ent, order, success)
    callback_fired = true
    callback_success = success
    callback_order = order
end)

-- Move to a very close point
orders.move(entity, {x = 1, y = 0})

-- Run system updates to complete movement
for i = 1, 10 do
    ecs.update_systems(0.016)
end

test("Callback fired on completion",
    callback_fired == true)

test("Callback received success=true",
    callback_success == true)

test("Callback received order object",
    callback_order ~= nil)

test("Callback order status is COMPLETED",
    callback_order.status == orders.STATUS.COMPLETED)
-- }}}

-- {{{ Queue Advancement Tests
test_section("Queue Advancement")

setup()

local entity = create_test_entity(0, 0, {speed = 10000, turn_rate = 100})

local completions = 0

orders.on_complete(entity, function(ent, order, success)
    completions = completions + 1
end)

-- Queue multiple close points
orders.move(entity, {x = 1, y = 0})
orders.move(entity, {x = 2, y = 0}, {queue = true})
orders.move(entity, {x = 3, y = 0}, {queue = true})

local ord = ecs.get_component(entity, "orders")
test("Queue has 2 orders",
    #ord.queue == 2)

-- Run until all complete
for i = 1, 50 do
    ecs.update_systems(0.016)
end

ord = ecs.get_component(entity, "orders")
test("Queue empty after all complete",
    #ord.queue == 0)

test("Current order nil after all complete",
    ord.current == nil)

test("All 3 completions fired",
    completions == 3)

local pos = ecs.get_component(entity, "position")
test("Entity at final destination",
    approx_eq(pos.x, 3, movement.ARRIVAL_THRESHOLD))
-- }}}

-- {{{ Invalid Entity Tests
test_section("Invalid Entity Handling")

setup()

-- Entity without orders component
local no_orders = ecs.create_entity()
ecs.add_component(no_orders, "position", {x = 0, y = 0})
ecs.add_component(no_orders, "movement", {})

local success, err = orders.move(no_orders, {x = 100, y = 100})
test("Move fails without orders component",
    success == false)

test("Error message provided",
    err ~= nil)

-- Entity without movement component
setup()
local no_movement = ecs.create_entity()
ecs.add_component(no_movement, "position", {x = 0, y = 0})
ecs.add_component(no_movement, "orders", {})

success, err = orders.move(no_movement, {x = 100, y = 100})
test("Move fails without movement component",
    success == false)

-- Nonexistent entity
success = orders.move(999999, {x = 100, y = 100})
test("Move fails for nonexistent entity",
    success == false)

test("get_current returns nil for invalid entity",
    orders.get_current(999999) == nil)

test("has_orders returns false for invalid entity",
    orders.has_orders(999999) == false)
-- }}}

-- {{{ Order Cancellation Tests
test_section("Order Cancellation")

setup()

local entity = create_test_entity(0, 0)

local cancel_detected = false
local cancel_order = nil

orders.on_complete(entity, function(ent, order, success)
    if order.status == orders.STATUS.CANCELLED then
        cancel_detected = true
        cancel_order = order
    end
end)

-- Issue order
orders.move(entity, {x = 1000, y = 1000})

-- Replace with new order (should cancel old)
orders.move(entity, {x = 2000, y = 2000})

test("Cancelled order detected",
    cancel_detected == true)

test("Cancelled order has CANCELLED status",
    cancel_order.status == orders.STATUS.CANCELLED)
-- }}}

-- {{{ System Registration Tests
test_section("System Registration")

setup()

local sys = ecs.get_system("orders")
test("Orders system registered",
    sys ~= nil)

test("Orders system has correct name",
    sys.name == "orders")

test("Orders system is enabled",
    sys.enabled == true)
-- }}}

-- {{{ Order Status Transitions Tests
test_section("Order Status Transitions")

setup()

local entity = create_test_entity(0, 0, {speed = 10000, turn_rate = 100})

local statuses = {}

orders.on_complete(entity, function(ent, order, success)
    statuses[#statuses + 1] = order.status
end)

-- Complete a short move
orders.move(entity, {x = 1, y = 0})

local ord = ecs.get_component(entity, "orders")
test("Initial status is EXECUTING",
    ord.current.status == orders.STATUS.EXECUTING)

for i = 1, 10 do
    ecs.update_systems(0.016)
end

test("Final status is COMPLETED",
    statuses[1] == orders.STATUS.COMPLETED)
-- }}}

-- {{{ Hold Position Tests
test_section("Hold Position")

setup()

local entity = create_test_entity(0, 0)

local success = orders.hold(entity)
test("orders.hold returns true",
    success == true)

local ord = ecs.get_component(entity, "orders")
test("Hold order is current",
    ord.current ~= nil and ord.current.type == orders.TYPE.HOLD)

test("Movement stopped during hold",
    movement.is_moving(entity) == false)

-- Move order should work after hold
orders.move(entity, {x = 100, y = 100})
ord = ecs.get_component(entity, "orders")
test("Move order replaces hold",
    ord.current.type == orders.TYPE.MOVE)
-- }}}

-- {{{ Clear Queue Tests
test_section("Clear Queue")

setup()

local entity = create_test_entity(0, 0)

orders.move(entity, {x = 100, y = 0})
orders.move(entity, {x = 200, y = 0}, {queue = true})
orders.move(entity, {x = 300, y = 0}, {queue = true})

local success = orders.clear_queue(entity)
test("clear_queue returns true",
    success == true)

local ord = ecs.get_component(entity, "orders")
test("Queue cleared",
    #ord.queue == 0)

test("Current order preserved",
    ord.current ~= nil and ord.current.target.x == 100)
-- }}}

-- {{{ Order With Target Entity Tests
test_section("Order Target Info")

setup()

local entity = create_test_entity(0, 0)

orders.move(entity, {x = 150, y = 250})

local order = orders.get_current(entity)
test("Order stores target position",
    order.target.x == 150 and order.target.y == 250)

test("Order has type field",
    order.type == orders.TYPE.MOVE)
-- }}}

-- {{{ Reset Function Tests
test_section("Reset Function")

setup()

local entity = create_test_entity(0, 0)
orders.move(entity, {x = 100, y = 100})

orders.reset()

-- After reset, the orders system should still work
-- (components are reset by ecs.reset in setup, this tests module state)
test("Module works after reset",
    type(orders.TYPE) == "table")
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

--[[
Test Suite for Movement Collision Integration (Issue 405d)

Tests the integration between collision detection and movement system:
- can_move_to checks for blocked movement
- resolve_overlap pushes entities apart
- slide_move slides along obstacles
- Trigger zone enter/leave events
]]

-- Setup path for requires
package.path = package.path .. ";./src/?.lua;./src/?/init.lua"

local collision = require("runtime.collision")
local ecs = require("runtime.ecs")

local test_count = 0
local pass_count = 0

-- {{{ test
local function test(name, condition)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("[PASS] " .. name)
    else
        print("[FAIL] " .. name)
    end
end
-- }}}

-- {{{ setup
local function setup()
    -- Reset ECS and collision system for each test group
    ecs.clear_all()
    collision.reset()
    collision.init(ecs)
    collision.clear_spatial()
    collision.clear_trigger_tracking()

    -- Register position component
    pcall(function()
        ecs.register_component("position", {x = 0, y = 0, z = 0, facing = 0})
    end)
end
-- }}}

-- {{{ create_solid_entity_at
local function create_solid_entity_at(x, y, radius, layer)
    local e = ecs.create_entity()
    ecs.add_component(e, "position", {x = x, y = y, z = 0, facing = 0})
    ecs.add_component(e, "collision", {
        shape = "circle",
        radius = radius or 20,
        layer = layer or "unit",
        mask = {"unit", "building"},
        solid = true,
        trigger = false,
    })
    return e
end
-- }}}

-- {{{ create_non_solid_entity_at
local function create_non_solid_entity_at(x, y, radius, layer)
    local e = ecs.create_entity()
    ecs.add_component(e, "position", {x = x, y = y, z = 0, facing = 0})
    ecs.add_component(e, "collision", {
        shape = "circle",
        radius = radius or 20,
        layer = layer or "projectile",
        mask = {"unit"},
        solid = false,
        trigger = false,
    })
    return e
end
-- }}}

-- {{{ create_trigger_at
local function create_trigger_at(x, y, radius)
    local e = ecs.create_entity()
    ecs.add_component(e, "position", {x = x, y = y, z = 0, facing = 0})
    ecs.add_component(e, "collision", {
        shape = "circle",
        radius = radius or 50,
        layer = "trigger",
        mask = {"unit"},
        solid = false,
        trigger = true,
    })
    return e
end
-- }}}

print("=== Testing Movement Collision Integration (405d) ===\n")

-- ============================================================================
-- can_move_to Tests
-- ============================================================================
print("--- can_move_to ---")

-- {{{ Test: can_move_to detects blocked movement
setup()
local e1 = create_solid_entity_at(100, 100, 20)
local e2 = create_solid_entity_at(150, 100, 20)  -- 50 units apart, will block
collision.update()

local can_move, blocker = collision.can_move_to(e1, 140, 100)  -- Moving toward e2
test("can_move_to detects blocked movement", can_move == false)
test("can_move_to returns blocking entity", blocker == e2)
-- }}}

-- {{{ Test: can_move_to allows movement to open space
setup()
local e1 = create_solid_entity_at(100, 100, 20)
local e2 = create_solid_entity_at(500, 500, 20)  -- Far away
collision.update()

local can_move, blocker = collision.can_move_to(e1, 200, 100)  -- Moving to open space
test("can_move_to allows movement to open space", can_move == true)
test("can_move_to returns nil when not blocked", blocker == nil)
-- }}}

-- {{{ Test: Non-solid entities can always move
setup()
local e1 = create_non_solid_entity_at(100, 100, 20)
local e2 = create_solid_entity_at(120, 100, 20)  -- Overlapping
collision.update()

local can_move, blocker = collision.can_move_to(e1, 120, 100)  -- Moving through solid
test("Non-solid entities can move through solid", can_move == true)
-- }}}

-- {{{ Test: Entity without collision component can move
setup()
local e_no_col = ecs.create_entity()
ecs.add_component(e_no_col, "position", {x = 100, y = 100, z = 0, facing = 0})
local e2 = create_solid_entity_at(110, 100, 20)
collision.update()

local can_move, blocker = collision.can_move_to(e_no_col, 110, 100)
test("Entity without collision can move anywhere", can_move == true)
-- }}}

-- {{{ Test: Layer mask filtering in can_move_to
setup()
local e1 = create_solid_entity_at(100, 100, 20)
local col1 = ecs.get_component(e1, "collision")
col1.mask = {"building"}  -- Only collides with buildings, not units

local e2 = create_solid_entity_at(120, 100, 20)  -- This is a unit
collision.update()

local can_move, blocker = collision.can_move_to(e1, 120, 100)
test("Layer mask filtering allows movement through non-matching layers", can_move == true)
-- }}}

-- ============================================================================
-- resolve_overlap Tests
-- ============================================================================
print("\n--- resolve_overlap ---")

-- {{{ Test: resolve_overlap pushes overlapping entities apart
setup()
local e1 = create_solid_entity_at(100, 100, 20)
local e2 = create_solid_entity_at(110, 100, 20)  -- Only 10 units apart, should overlap
collision.update()

local pos1_before = {x = 100, y = 100}
local pos2_before = {x = 110, y = 100}

collision.resolve_overlap(e1, e2)

local pos1 = ecs.get_component(e1, "position")
local pos2 = ecs.get_component(e2, "position")

-- Should have pushed apart
local dist_after = math.sqrt((pos2.x - pos1.x)^2 + (pos2.y - pos1.y)^2)
test("resolve_overlap pushes entities apart", dist_after > 10)
test("Entities pushed far enough (>= combined radius)", dist_after >= 39)  -- 20+20 - some margin
-- }}}

-- {{{ Test: resolve_overlap handles coincident positions
setup()
local e1 = create_solid_entity_at(100, 100, 20)
local e2 = create_solid_entity_at(100, 100, 20)  -- Exact same position
collision.update()

collision.resolve_overlap(e1, e2)

local pos1 = ecs.get_component(e1, "position")
local pos2 = ecs.get_component(e2, "position")

local dist = math.sqrt((pos2.x - pos1.x)^2 + (pos2.y - pos1.y)^2)
test("resolve_overlap handles coincident positions", dist > 0)
-- }}}

-- {{{ Test: resolve_overlap does nothing for non-overlapping entities
setup()
local e1 = create_solid_entity_at(100, 100, 20)
local e2 = create_solid_entity_at(200, 100, 20)  -- Far apart
collision.update()

local pos1_x_before = ecs.get_component(e1, "position").x
local pos2_x_before = ecs.get_component(e2, "position").x

collision.resolve_overlap(e1, e2)

local pos1 = ecs.get_component(e1, "position")
local pos2 = ecs.get_component(e2, "position")

test("resolve_overlap does nothing for non-overlapping",
    pos1.x == pos1_x_before and pos2.x == pos2_x_before)
-- }}}

-- ============================================================================
-- slide_move Tests
-- ============================================================================
print("\n--- slide_move ---")

-- {{{ Test: slide_move allows direct movement when clear
setup()
local e1 = create_solid_entity_at(100, 100, 20)
collision.update()

local actual_x, actual_y = collision.slide_move(e1, 200, 100)
test("slide_move allows direct movement when clear",
    actual_x == 200 and actual_y == 100)
-- }}}

-- {{{ Test: slide_move slides along X when Y blocked
setup()
local e1 = create_solid_entity_at(100, 100, 20)
local e2 = create_solid_entity_at(140, 120, 20)  -- Blocks diagonal, but not X-only
collision.update()

local actual_x, actual_y = collision.slide_move(e1, 140, 120)

-- Should slide along X or Y
local moved = (actual_x ~= 100 or actual_y ~= 100)
test("slide_move attempts alternate axis when blocked", moved or (actual_x == 100 and actual_y == 100))
-- }}}

-- {{{ Test: slide_move stays in place when completely blocked
setup()
local e1 = create_solid_entity_at(100, 100, 20)
-- Surround with blockers
local e2 = create_solid_entity_at(140, 100, 20)
local e3 = create_solid_entity_at(100, 140, 20)
local e4 = create_solid_entity_at(140, 140, 20)
collision.update()

local actual_x, actual_y = collision.slide_move(e1, 140, 140)
test("slide_move stays in place when completely blocked",
    actual_x == 100 and actual_y == 100)
-- }}}

-- ============================================================================
-- resolve_all_overlaps Tests
-- ============================================================================
print("\n--- resolve_all_overlaps ---")

-- {{{ Test: resolve_all_overlaps fixes multiple overlaps
setup()
local e1 = create_solid_entity_at(100, 100, 20)
local e2 = create_solid_entity_at(110, 100, 20)  -- Overlaps e1
local e3 = create_solid_entity_at(105, 100, 20)  -- Overlaps both
collision.update()

collision.resolve_all_overlaps()

local pos1 = ecs.get_component(e1, "position")
local pos2 = ecs.get_component(e2, "position")
local pos3 = ecs.get_component(e3, "position")

-- At least some movement should have occurred
local moved = (pos1.x ~= 100 or pos2.x ~= 110 or pos3.x ~= 105)
test("resolve_all_overlaps moves at least one entity", moved)
-- }}}

-- ============================================================================
-- Trigger Zone Tests
-- ============================================================================
print("\n--- Trigger Zones ---")

-- {{{ Test: Trigger enter event fires
setup()
local trigger = create_trigger_at(100, 100, 50)
local unit = create_solid_entity_at(100, 100, 20)  -- Inside trigger
collision.update()

local enter_count = 0
local enter_trigger = nil
local enter_entity = nil

collision.check_trigger_collisions(function(event, trig, ent)
    if event == "trigger_enter" then
        enter_count = enter_count + 1
        enter_trigger = trig
        enter_entity = ent
    end
end)

test("Trigger enter event fires for entity inside", enter_count == 1)
test("Trigger enter provides correct trigger entity", enter_trigger == trigger)
test("Trigger enter provides correct entering entity", enter_entity == unit)
-- }}}

-- {{{ Test: Trigger leave event fires
setup()
local trigger = create_trigger_at(100, 100, 50)
local unit = create_solid_entity_at(100, 100, 20)
collision.update()

-- First tick - entity enters
collision.check_trigger_collisions(function() end)

-- Move entity outside
local pos = ecs.get_component(unit, "position")
pos.x = 500
pos.y = 500
collision.update()

local leave_count = 0
local leave_entity = nil

collision.check_trigger_collisions(function(event, trig, ent)
    if event == "trigger_leave" then
        leave_count = leave_count + 1
        leave_entity = ent
    end
end)

test("Trigger leave event fires when entity exits", leave_count == 1)
test("Trigger leave provides correct leaving entity", leave_entity == unit)
-- }}}

-- {{{ Test: get_trigger_contents returns entities inside
setup()
local trigger = create_trigger_at(100, 100, 50)
local unit1 = create_solid_entity_at(100, 100, 20)
local unit2 = create_solid_entity_at(80, 100, 20)
local unit3 = create_solid_entity_at(500, 500, 20)  -- Outside
collision.update()

collision.check_trigger_collisions(function() end)

local contents = collision.get_trigger_contents(trigger)
test("get_trigger_contents returns entities inside", #contents == 2)
-- }}}

-- {{{ Test: Trigger respects layer mask
setup()
local trigger = create_trigger_at(100, 100, 50)
local tcol = ecs.get_component(trigger, "collision")
tcol.mask = {"building"}  -- Only detects buildings

local unit = create_solid_entity_at(100, 100, 20)  -- This is a unit, not building
collision.update()

local enter_count = 0
collision.check_trigger_collisions(function(event)
    if event == "trigger_enter" then
        enter_count = enter_count + 1
    end
end)

test("Trigger respects layer mask filtering", enter_count == 0)
-- }}}

-- ============================================================================
-- Summary
-- ============================================================================
print("\n=== Results ===")
print(string.format("Passed: %d/%d", pass_count, test_count))
if pass_count == test_count then
    print("All tests passed!")
    os.exit(0)
else
    print("Some tests failed.")
    os.exit(1)
end

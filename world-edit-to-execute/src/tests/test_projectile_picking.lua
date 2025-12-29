--[[
Test Suite for Projectile Hit Detection and Picking (Issue 405e)

Tests projectile collision, hit tracking, and entity selection.
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
    ecs.clear_all()
    collision.reset()
    collision.init(ecs)
    collision.clear_spatial()

    -- Register needed components
    pcall(function()
        ecs.register_component("position", {x = 0, y = 0, z = 0})
    end)
    pcall(function()
        ecs.register_component("stats", {hp = 100, max_hp = 100})
    end)
    pcall(function()
        ecs.register_component("owner", {player_id = 0})
    end)
    pcall(function()
        ecs.register_component("selectable", {can_select = true})
    end)
end

local function create_unit(x, y, radius, layer)
    local e = ecs.create_entity()
    ecs.add_component(e, "position", {x = x, y = y})
    ecs.add_component(e, "collision", {
        shape = "circle",
        radius = radius or 20,
        layer = layer or "unit",
    })
    return e
end

local function create_projectile(x, y, radius)
    local e = ecs.create_entity()
    ecs.add_component(e, "position", {x = x, y = y})
    ecs.add_component(e, "collision", {
        shape = "circle",
        radius = radius or 8,
        layer = "projectile",
    })
    return e
end

print("=== Testing Projectile Hit Detection and Picking (405e) ===\n")

-- {{{ Projectile Hit Tracking Tests
print("--- Projectile Hit Tracking ---")
setup()

local proj = create_projectile(100, 100, 10)
local target1 = create_unit(100, 100, 20, "unit")
local target2 = create_unit(150, 100, 20, "unit")

test("was_hit_by returns false initially",
    collision.was_hit_by(proj, target1) == false)

collision.register_projectile_hit(proj, target1)

test("was_hit_by returns true after registration",
    collision.was_hit_by(proj, target1) == true)

test("was_hit_by returns false for de-selected target",
    collision.was_hit_by(proj, target2) == false)

test("get_projectile_hit_count returns 1",
    collision.get_projectile_hit_count(proj) == 1)

collision.register_projectile_hit(proj, target2)

test("get_projectile_hit_count returns 2 after second hit",
    collision.get_projectile_hit_count(proj) == 2)

collision.clear_projectile_hits(proj)

test("was_hit_by returns false after clear",
    collision.was_hit_by(proj, target1) == false)

test("get_projectile_hit_count returns 0 after clear",
    collision.get_projectile_hit_count(proj) == 0)
-- }}}

-- {{{ is_valid_target Tests
print("\n--- is_valid_target ---")
setup()

local proj = create_projectile(100, 100, 10)
local target = create_unit(100, 100, 20, "unit")

test("Valid target initially",
    collision.is_valid_target(proj, target) == true)

-- After registering hit, should be invalid
collision.register_projectile_hit(proj, target)
test("Invalid target after already hit",
    collision.is_valid_target(proj, target) == false)

-- Test dead unit detection
setup()
proj = create_projectile(100, 100, 10)
target = create_unit(100, 100, 20, "unit")
ecs.add_component(target, "stats", {hp = 0, max_hp = 100})

test("Dead unit is de-selected as target",
    collision.is_valid_target(proj, target) == false)

-- Test living unit
setup()
proj = create_projectile(100, 100, 10)
target = create_unit(100, 100, 20, "unit")
ecs.add_component(target, "stats", {hp = 50, max_hp = 100})

test("Living unit is valid target",
    collision.is_valid_target(proj, target) == true)
-- }}}

-- {{{ Team Filtering Tests
print("\n--- Team Filtering ---")
setup()

local proj = create_projectile(100, 100, 10)
local ally = create_unit(100, 100, 20, "unit")
local enemy = create_unit(110, 100, 20, "unit")

ecs.add_component(proj, "owner", {player_id = 1})
ecs.add_component(ally, "owner", {player_id = 1})
ecs.add_component(enemy, "owner", {player_id = 2})

-- Default: target enemies only
test("Ally de-selected by default",
    collision.is_valid_target(proj, ally) == false)

test("Enemy is valid target by default",
    collision.is_valid_target(proj, enemy) == true)

-- Target allies only
test("Ally valid with target_allies option",
    collision.is_valid_target(proj, ally, {target_allies = true}) == true)

test("Enemy de-selected with target_enemies=false",
    collision.is_valid_target(proj, enemy, {target_enemies = false}) == false)

-- Target both
test("Both valid with both options",
    collision.is_valid_target(proj, ally, {target_allies = true, target_enemies = true}) == true and
    collision.is_valid_target(proj, enemy, {target_allies = true, target_enemies = true}) == true)
-- }}}

-- {{{ check_projectile_hit Tests
print("\n--- check_projectile_hit ---")
setup()

local proj = create_projectile(100, 100, 30)
local target1 = create_unit(110, 100, 20, "unit")
local target2 = create_unit(150, 100, 20, "unit")  -- Farther

collision.update()

local hit = collision.check_projectile_hit(proj)
test("check_projectile_hit finds nearby target",
    hit == target1)

-- Second call should not hit same target
hit = collision.check_projectile_hit(proj)
test("Same target de-selected on second check",
    hit ~= target1)

-- Clear and retry
collision.clear_projectile_hits(proj)
hit = collision.check_projectile_hit(proj)
test("Target valid again after clearing hits",
    hit == target1)

-- No targets in range
setup()
proj = create_projectile(100, 100, 10)
create_unit(500, 500, 20, "unit")
collision.update()

hit = collision.check_projectile_hit(proj)
test("No hit when no targets in range",
    hit == nil)
-- }}}

-- {{{ check_projectile_hits_all Tests
print("\n--- check_projectile_hits_all ---")
setup()

local proj = create_projectile(100, 100, 50)  -- Large radius
local t1 = create_unit(110, 100, 20, "unit")
local t2 = create_unit(120, 100, 20, "unit")
local t3 = create_unit(130, 100, 20, "unit")

collision.update()

local hits = collision.check_projectile_hits_all(proj)
test("check_projectile_hits_all finds multiple targets",
    #hits == 3)

-- Verify all registered
test("All targets registered as hit",
    collision.was_hit_by(proj, t1) and
    collision.was_hit_by(proj, t2) and
    collision.was_hit_by(proj, t3))

-- Second call should find none
hits = collision.check_projectile_hits_all(proj)
test("No hits on second call (all already hit)",
    #hits == 0)
-- }}}

-- {{{ is_selectable Tests
print("\n--- is_selectable ---")
setup()

local unit = create_unit(100, 100, 20, "unit")
test("Unit is selectable",
    collision.is_selectable(unit) == true)

local building = create_unit(200, 100, 30, "building")
test("Building is selectable",
    collision.is_selectable(building) == true)

local item = create_unit(300, 100, 10, "item")
test("Item is selectable",
    collision.is_selectable(item) == true)

local projectile = create_projectile(400, 100, 8)
test("Projectile is de-selected",
    collision.is_selectable(projectile) == false)

-- Trigger region not selectable
local trigger = ecs.create_entity()
ecs.add_component(trigger, "position", {x = 500, y = 100})
ecs.add_component(trigger, "collision", {shape = "rect", width = 100, height = 100, layer = "trigger"})
test("Trigger is de-selected",
    collision.is_selectable(trigger) == false)

-- Entity with selectable component set to false
local hidden = create_unit(600, 100, 20, "unit")
ecs.add_component(hidden, "selectable", {can_select = false})
test("Unit with can_select=false is de-selected",
    collision.is_selectable(hidden) == false)

-- Entity without collision component
local no_col = ecs.create_entity()
ecs.add_component(no_col, "position", {x = 700, y = 100})
test("Entity without collision is de-selected",
    collision.is_selectable(no_col) == false)
-- }}}

-- {{{ pick_at_point Tests
print("\n--- pick_at_point ---")
setup()

local unit = create_unit(100, 100, 30, "unit")
collision.update()

local picked = collision.pick_at_point(100, 100)
test("pick_at_point finds unit at center",
    picked == unit)

picked = collision.pick_at_point(110, 100)
test("pick_at_point finds unit inside bounds",
    picked == unit)

picked = collision.pick_at_point(200, 200)
test("pick_at_point returns nil for empty area",
    picked == nil)

-- Non-selectable entity
setup()
local proj = create_projectile(100, 100, 30)
collision.update()

picked = collision.pick_at_point(100, 100)
test("pick_at_point ignores non-selectable entities",
    picked == nil)
-- }}}

-- {{{ pick_in_rect Tests
print("\n--- pick_in_rect ---")
setup()

-- Create grid of units
for i = 1, 5 do
    create_unit(i * 50, 100, 15, "unit")
end
collision.update()

local picked = collision.pick_in_rect(0, 50, 300, 150)
test("pick_in_rect finds multiple units",
    #picked == 5)

-- Test max selection limit
setup()
for i = 1, 20 do
    create_unit(i * 20, 100, 10, "unit")
end
collision.update()

picked = collision.pick_in_rect(0, 50, 500, 150)
test("pick_in_rect respects default limit of 12",
    #picked == 12)

picked = collision.pick_in_rect(0, 50, 500, 150, 5)
test("pick_in_rect respects custom limit",
    #picked == 5)

-- Test corner order normalization
setup()
local u = create_unit(100, 100, 20, "unit")
collision.update()

picked = collision.pick_in_rect(150, 150, 50, 50)  -- Reversed order
test("pick_in_rect works with reversed corner order",
    #picked == 1 and picked[1] == u)
-- }}}

-- {{{ pick_all_at_point Tests
print("\n--- pick_all_at_point ---")
setup()

local u1 = create_unit(100, 100, 30, "unit")
local u2 = create_unit(100, 100, 25, "unit")
local u3 = create_unit(100, 100, 20, "unit")
collision.update()

local picked = collision.pick_all_at_point(100, 100)
test("pick_all_at_point finds all overlapping units",
    #picked == 3)

-- Mixed with non-selectable
setup()
u1 = create_unit(100, 100, 30, "unit")
local proj = create_projectile(100, 100, 20)
collision.update()

picked = collision.pick_all_at_point(100, 100)
test("pick_all_at_point filters non-selectable",
    #picked == 1 and picked[1] == u1)
-- }}}

-- {{{ Edge Cases Tests
print("\n--- Edge Cases ---")

-- Uninitialized
collision.reset()

test("check_projectile_hit returns nil when uninitialized",
    collision.check_projectile_hit({}) == nil)

test("pick_at_point returns nil when uninitialized",
    collision.pick_at_point(0, 0) == nil)

test("pick_in_rect returns empty when uninitialized",
    #collision.pick_in_rect(0, 0, 100, 100) == 0)

-- Re-initialize
collision.init(ecs)

-- Zero-size projectile
setup()
local tiny_proj = ecs.create_entity()
ecs.add_component(tiny_proj, "position", {x = 100, y = 100})
-- No collision component
local target = create_unit(100, 100, 30, "unit")
collision.update()

local hit = collision.check_projectile_hit(tiny_proj)
test("Projectile without collision uses default radius",
    hit == target)

-- Empty rect selection
setup()
collision.update()

picked = collision.pick_in_rect(0, 0, 10, 10)
test("pick_in_rect handles empty selection",
    #picked == 0)
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

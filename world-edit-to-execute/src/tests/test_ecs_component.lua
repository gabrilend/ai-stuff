-- ECS Component Registry Unit Tests (402b)
-- Tests for component type registration and entity attachment.
-- Run with: luajit src/tests/test_ecs_component.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local entity = require("runtime.ecs.entity")
local component = require("runtime.ecs.component")
local ecs = require("runtime.ecs")

-- {{{ Test utilities
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

local function reset_all()
    entity.reset()
    entity.clear_hooks()
    component.clear_all()
    -- Re-initialize component to register destroy hook (force=true)
    component.init(true)
end
-- }}}

-- {{{ Component Registration Tests
test_section("Component Registration")
reset_all()

component.register("position", {x = 0, y = 0, z = 0, facing = 0})
component.register("stats", {hp = 100, hp_max = 100, mp = 0, mp_max = 0})

local types = component.get_registered_types()
test("Two types registered", #types == 2)

local pos_defaults = component.get_defaults("position")
test("Position defaults exist", pos_defaults ~= nil)
test("Position default x", pos_defaults.x == 0)
test("Position default facing", pos_defaults.facing == 0)

local stats_defaults = component.get_defaults("stats")
test("Stats defaults exist", stats_defaults ~= nil)
test("Stats default hp", stats_defaults.hp == 100)

-- Unregistered component returns nil
local nil_defaults = component.get_defaults("nonexistent")
test("Nonexistent returns nil", nil_defaults == nil)

-- Double registration should error
local ok = pcall(function()
    component.register("position", {x = 1})
end)
test("Double registration errors", not ok)

-- Invalid name type
ok = pcall(function()
    component.register(123, {})
end)
test("Non-string name errors", not ok)

-- Invalid defaults type
ok = pcall(function()
    component.register("bad", "not a table")
end)
test("Non-table defaults errors", not ok)
-- }}}

-- {{{ Component Addition Tests
test_section("Component Addition")
reset_all()

component.register("position", {x = 0, y = 0, z = 0})
component.register("stats", {hp = 100})

local e1 = entity.create()
local pos = component.add(e1, "position", {x = 100, y = 200})

test("Add returns component", pos ~= nil)
test("Component has x value", pos.x == 100)
test("Component has y value", pos.y == 200)
test("Component inherits z default", pos.z == 0)

-- Add without initial data
local stats = component.add(e1, "stats")
test("Add without data works", stats ~= nil)
test("Inherits all defaults", stats.hp == 100)

-- Double add should error
ok = pcall(function()
    component.add(e1, "position", {x = 50})
end)
test("Double add errors", not ok)

-- Add to non-existent entity should error
ok = pcall(function()
    component.add(999, "position", {x = 0})
end)
test("Add to non-existent entity errors", not ok)

-- Add unregistered component should error
local e2 = entity.create()
ok = pcall(function()
    component.add(e2, "nonexistent", {})
end)
test("Add unregistered component errors", not ok)
-- }}}

-- {{{ Component Retrieval Tests
test_section("Component Retrieval")
reset_all()

component.register("position", {x = 0, y = 0})
component.register("stats", {hp = 100})

local e1 = entity.create()
local pos = component.add(e1, "position", {x = 100, y = 200})
local stats = component.add(e1, "stats", {hp = 50})

local got_pos = component.get(e1, "position")
test("Get returns same instance", got_pos == pos)
test("Get returns correct data", got_pos.x == 100)

local got_stats = component.get(e1, "stats")
test("Get stats", got_stats == stats)
test("Stats value correct", got_stats.hp == 50)

local got_missing = component.get(e1, "nonexistent")
test("Get missing returns nil", got_missing == nil)

local e2 = entity.create()
local got_wrong_entity = component.get(e2, "position")
test("Get wrong entity returns nil", got_wrong_entity == nil)

-- Get on unregistered component type
local got_unregistered = component.get(e1, "unregistered")
test("Get unregistered returns nil", got_unregistered == nil)
-- }}}

-- {{{ Component Has Check Tests
test_section("Component Has Check")
reset_all()

component.register("position", {x = 0})
component.register("stats", {hp = 100})

local e1 = entity.create()
local e2 = entity.create()

component.add(e1, "position")
component.add(e1, "stats")

test("Has position true", component.has(e1, "position"))
test("Has stats true", component.has(e1, "stats"))
test("Has nonexistent false", not component.has(e1, "nonexistent"))
test("Has on wrong entity false", not component.has(e2, "position"))
test("Has unregistered type false", not component.has(e1, "unregistered"))
-- }}}

-- {{{ Component Modification Tests
test_section("Component Modification")
reset_all()

component.register("position", {x = 0, y = 0, z = 0})

local e1 = entity.create()
local pos = component.add(e1, "position", {x = 100})

pos.x = 150
pos.custom_field = "test"

local updated = component.get(e1, "position")
test("Modification persists", updated.x == 150)
test("Custom fields work", updated.custom_field == "test")
test("Defaults still work", updated.z == 0)

-- Setting to default doesn't break inheritance
pos.y = 50
test("Explicit set works", pos.y == 50)
-- }}}

-- {{{ Component Removal Tests
test_section("Component Removal")
reset_all()

component.register("position", {x = 0})
component.register("stats", {hp = 100})

local e1 = entity.create()
component.add(e1, "position", {x = 100})
component.add(e1, "stats", {hp = 50})

local removed = component.remove(e1, "position")
test("Remove returns true", removed == true)
test("Has returns false after remove", not component.has(e1, "position"))
test("Get returns nil after remove", component.get(e1, "position") == nil)

-- Double remove
removed = component.remove(e1, "position")
test("Double remove returns false", removed == false)

-- Remove nonexistent
removed = component.remove(e1, "nonexistent")
test("Remove nonexistent returns false", removed == false)

-- Stats should still exist
test("Other components unaffected", component.has(e1, "stats"))
test("Stats value preserved", component.get(e1, "stats").hp == 50)
-- }}}

-- {{{ Get All Components Tests
test_section("Get All Components")
reset_all()

component.register("a", {val = 1})
component.register("b", {val = 2})
component.register("c", {val = 3})

local e = entity.create()
component.add(e, "a")
component.add(e, "b")

local all = component.get_all_for_entity(e)
test("Get all returns a", all.a ~= nil)
test("Get all returns b", all.b ~= nil)
test("Get all excludes c", all.c == nil)

local names = component.get_component_names(e)
test("Get names returns 2", #names == 2)

-- Check names contain a and b
local has_a, has_b = false, false
for _, name in ipairs(names) do
    if name == "a" then has_a = true end
    if name == "b" then has_b = true end
end
test("Names include a", has_a)
test("Names include b", has_b)

-- Empty entity
local e2 = entity.create()
local all2 = component.get_all_for_entity(e2)
local count = 0
for _ in pairs(all2) do count = count + 1 end
test("Empty entity returns empty table", count == 0)

local names2 = component.get_component_names(e2)
test("Empty entity has no names", #names2 == 0)
-- }}}

-- {{{ Entity Destruction Cleanup Tests
test_section("Entity Destruction Cleanup")
reset_all()

component.register("data", {value = 0})

local e1 = entity.create()
local e2 = entity.create()
component.add(e1, "data", {value = 1})
component.add(e2, "data", {value = 2})

test("Before destroy: e1 has data", component.has(e1, "data"))
test("Before destroy: e2 has data", component.has(e2, "data"))

entity.destroy(e1)

test("After destroy: e1 data gone", not component.has(e1, "data"))
test("After destroy: e2 data remains", component.has(e2, "data"))

local e2_data = component.get(e2, "data")
test("E2 data correct", e2_data.value == 2)

-- Create new entity (recycled ID)
local e3 = entity.create()
test("Recycled ID has no components", not component.has(e3, "data"))
-- }}}

-- {{{ Metatable Inheritance Tests
test_section("Metatable Inheritance")
reset_all()

component.register("test", {a = 1, b = 2, c = 3})

local e = entity.create()
local comp = component.add(e, "test", {b = 20})

test("Override value", comp.b == 20)
test("Inherited a", comp.a == 1)
test("Inherited c", comp.c == 3)

-- rawget should not see inherited values
test("rawget override", rawget(comp, "b") == 20)
test("rawget inherited nil", rawget(comp, "a") == nil)
test("rawget inherited c nil", rawget(comp, "c") == nil)

-- Can override inherited value later
comp.a = 10
test("Override inherited value", comp.a == 10)
test("rawget now sees it", rawget(comp, "a") == 10)

-- Setting nil doesn't break inheritance
comp.a = nil
test("After nil, inherits again", comp.a == 1)
-- }}}

-- {{{ Component Storage Tests
test_section("Component Storage")
reset_all()

component.register("position", {x = 0, y = 0})

local e1 = entity.create()
local e2 = entity.create()
component.add(e1, "position", {x = 100})
component.add(e2, "position", {x = 200})

local storage = component.get_storage("position")
test("Storage exists", storage ~= nil)
test("Storage has e1", storage[e1] ~= nil)
test("Storage has e2", storage[e2] ~= nil)
test("Storage e1 correct", storage[e1].x == 100)
test("Storage e2 correct", storage[e2].x == 200)

-- Unregistered storage
local nil_storage = component.get_storage("nonexistent")
test("Unregistered storage nil", nil_storage == nil)
-- }}}

-- {{{ Component Stats Tests
test_section("Component Stats")
reset_all()

component.register("x", {})
component.register("y", {})

local e1 = entity.create()
local e2 = entity.create()
local e3 = entity.create()

component.add(e1, "x")
component.add(e2, "x")
component.add(e3, "x")
component.add(e1, "y")

local stats = component.get_stats()
test("Registered types count", stats.registered_types == 2)
test("X instances count", stats.instances_by_type.x == 3)
test("Y instances count", stats.instances_by_type.y == 1)

-- After removal
component.remove(e2, "x")
stats = component.get_stats()
test("X count after removal", stats.instances_by_type.x == 2)
-- }}}

-- {{{ Reset Tests
test_section("Reset")
reset_all()

component.register("a", {val = 1})
component.register("b", {val = 2})

local e = entity.create()
component.add(e, "a")
component.add(e, "b")

-- reset() keeps type registrations
component.reset()

local types = component.get_registered_types()
test("Types preserved after reset", #types == 2)
test("Instances cleared after reset", not component.has(e, "a"))

-- Can add after reset
local e2 = entity.create()
local comp = component.add(e2, "a", {val = 10})
test("Can add after reset", comp ~= nil)

-- clear_all removes type registrations too
component.clear_all()
types = component.get_registered_types()
test("Types cleared after clear_all", #types == 0)

ok = pcall(function()
    component.add(e2, "a")
end)
test("Cannot add after clear_all", not ok)
-- }}}

-- {{{ ECS Main Module Integration Tests
test_section("ECS Main Module Integration")
reset_all()

ecs.register_component("pos", {x = 0, y = 0})

local e = ecs.create_entity()
local pos = ecs.add_component(e, "pos", {x = 100})

test("ECS add_component works", pos ~= nil)
test("ECS get_component works", ecs.get_component(e, "pos") == pos)
test("ECS has_component works", ecs.has_component(e, "pos"))

local removed = ecs.remove_component(e, "pos")
test("ECS remove_component works", removed)
test("ECS component gone", not ecs.has_component(e, "pos"))

-- Get all
ecs.register_component("stats", {hp = 100})
ecs.add_component(e, "pos", {x = 50})
ecs.add_component(e, "stats")

local all = ecs.get_all_components(e)
test("ECS get_all_components works", all.pos ~= nil and all.stats ~= nil)

local names = ecs.get_component_names(e)
test("ECS get_component_names works", #names == 2)

-- Stats via ECS
local stats = ecs.get_component_stats()
test("ECS get_component_stats works", stats.registered_types == 2)

-- Storage via ECS
local storage = ecs.get_component_storage("pos")
test("ECS get_component_storage works", storage ~= nil)

-- Defaults via ECS
local defaults = ecs.get_component_defaults("pos")
test("ECS get_component_defaults works", defaults.x == 0)

-- Types via ECS
local types = ecs.get_registered_component_types()
test("ECS get_registered_component_types works", #types == 2)
-- }}}

-- {{{ B03 Hivemind Bug Regression Test
-- Ensures nested table defaults are independent per entity.
-- B03: Without deep copy, modifying one entity's nested table affects all entities.
test_section("B03: Hivemind Bug Regression")
reset_all()

component.register("position", {
    x = 0,
    y = 0,
    velocity = { vx = 0, vy = 0 }  -- Nested table default
})

local e1 = entity.create()
local e2 = entity.create()
component.add(e1, "position")
component.add(e2, "position")

-- Modify e1's nested table
local pos1 = component.get(e1, "position")
pos1.velocity.vx = 10
pos1.velocity.vy = 20

-- e2 should be unaffected
local pos2 = component.get(e2, "position")
test("Nested table independent (vx)", pos2.velocity.vx == 0)
test("Nested table independent (vy)", pos2.velocity.vy == 0)
test("e1 modification persists (vx)", pos1.velocity.vx == 10)
test("e1 modification persists (vy)", pos1.velocity.vy == 20)

-- Test deeply nested tables
component.register("nested_test", {
    level1 = {
        level2 = {
            level3 = { value = 42 }
        }
    }
})

local e3 = entity.create()
local e4 = entity.create()
component.add(e3, "nested_test")
component.add(e4, "nested_test")

-- Modify deep value on e3
component.get(e3, "nested_test").level1.level2.level3.value = 999

-- e4 should still have original value
test("Deep nested independent", component.get(e4, "nested_test").level1.level2.level3.value == 42)
test("Deep nested e3 modified", component.get(e3, "nested_test").level1.level2.level3.value == 999)

-- Test with initial data containing tables
component.register("init_data_test", { a = 0 })
local shared_data = { nested = { x = 100 } }
local e5 = entity.create()
local e6 = entity.create()
component.add(e5, "init_data_test", shared_data)
component.add(e6, "init_data_test", shared_data)

-- Modify e5's data
component.get(e5, "init_data_test").nested.x = 500

-- e6 should be unaffected (shared_data was deep-copied for each entity)
test("Initial data deep copied", component.get(e6, "init_data_test").nested.x == 100)
-- }}}

-- {{{ Multiple Entities Stress Test
test_section("Stress Test")
reset_all()

component.register("pos", {x = 0, y = 0})
component.register("vel", {vx = 0, vy = 0})
component.register("hp", {current = 100, max = 100})

-- Create 1000 entities with various components
for i = 1, 1000 do
    local e = entity.create()
    component.add(e, "pos", {x = i, y = i * 2})
    if i % 2 == 0 then
        component.add(e, "vel", {vx = i / 10})
    end
    if i % 3 == 0 then
        component.add(e, "hp", {current = i})
    end
end

local stats = component.get_stats()
test("1000 entities with pos", stats.instances_by_type.pos == 1000)
test("500 entities with vel", stats.instances_by_type.vel == 500)
test("333 entities with hp", stats.instances_by_type.hp == 333)

-- Verify data integrity
local pos_500 = component.get(500, "pos")
test("Entity 500 pos.x correct", pos_500.x == 500)
test("Entity 500 pos.y correct", pos_500.y == 1000)

-- Destroy half the entities
for i = 1, 500 do
    entity.destroy(i)
end

stats = component.get_stats()
test("500 entities with pos after destroy", stats.instances_by_type.pos == 500)

-- Verify remaining entity
local pos_750 = component.get(750, "pos")
test("Entity 750 still has pos", pos_750 ~= nil)
test("Entity 750 pos.x correct", pos_750.x == 750)
-- }}}

-- {{{ Summary
print("\n" .. string.rep("=", 50))
print(string.format("Tests: %d passed, %d failed", pass_count, test_count - pass_count))

if pass_count == test_count then
    print("ALL TESTS PASSED")
    os.exit(0)
else
    print("SOME TESTS FAILED")
    os.exit(1)
end
-- }}}

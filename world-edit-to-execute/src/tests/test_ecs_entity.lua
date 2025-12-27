-- ECS Entity Manager Unit Tests (402a)
-- Tests for entity creation, destruction, ID recycling, and lifecycle hooks.
-- Run with: luajit src/tests/test_ecs_entity.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local entity = require("runtime.ecs.entity")
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
end
-- }}}

-- {{{ Entity Creation Tests
test_section("Entity Creation")
reset_all()

local e1 = entity.create()
test("First entity is 1", e1 == 1)

local e2 = entity.create()
test("Second entity is 2", e2 == 2)

local e3 = entity.create()
test("Third entity is 3", e3 == 3)

test("Count is 3", entity.get_count() == 3)
-- }}}

-- {{{ Entity Existence Tests
test_section("Entity Existence")
reset_all()

local e1 = entity.create()  -- 1
local e2 = entity.create()  -- 2

test("Entity 1 exists", entity.exists(e1))
test("Entity 2 exists", entity.exists(e2))
test("Entity 99 doesn't exist", not entity.exists(99))
test("Entity 0 doesn't exist", not entity.exists(0))
test("Entity -1 doesn't exist", not entity.exists(-1))
test("Entity nil doesn't exist", not entity.exists(nil))
-- }}}

-- {{{ Entity Destruction Tests
test_section("Entity Destruction")
reset_all()

local e1 = entity.create()  -- 1
local e2 = entity.create()  -- 2
local e3 = entity.create()  -- 3

local destroyed = entity.destroy(e2)
test("Destroy returns true", destroyed == true)
test("Entity 2 no longer exists", not entity.exists(e2))
test("Count is 2", entity.get_count() == 2)
test("Entity 1 still exists", entity.exists(e1))
test("Entity 3 still exists", entity.exists(e3))

-- Destroy non-existent entities
destroyed = entity.destroy(e2)
test("Double destroy returns false", destroyed == false)
destroyed = entity.destroy(99)
test("Destroy non-existent returns false", destroyed == false)
destroyed = entity.destroy(0)
test("Destroy entity 0 returns false", destroyed == false)
-- }}}

-- {{{ ID Recycling Tests
test_section("ID Recycling")
reset_all()

local e1 = entity.create()  -- 1
local e2 = entity.create()  -- 2
local e3 = entity.create()  -- 3

entity.destroy(e2)

local e4 = entity.create()
test("New entity recycles ID 2", e4 == 2)
test("Count is 3", entity.get_count() == 3)

-- Destroy multiple and check recycling order (LIFO)
entity.destroy(e1)
entity.destroy(e3)

local e5 = entity.create()
test("Recycles most recent first (ID 3)", e5 == 3)

local e6 = entity.create()
test("Then older recycled ID (ID 1)", e6 == 1)

local e7 = entity.create()
test("Then allocates new ID (ID 4)", e7 == 4)
-- }}}

-- {{{ Entity Iteration Tests
test_section("Entity Iteration")
reset_all()

entity.create()  -- 1
entity.create()  -- 2
entity.create()  -- 3
entity.destroy(2)

local iterated = {}
for id in entity.iterate() do
    iterated[#iterated + 1] = id
end

test("Iteration returns 2 entities", #iterated == 2)
test("Iteration includes 1", iterated[1] == 1 or iterated[2] == 1)
test("Iteration includes 3", iterated[1] == 3 or iterated[2] == 3)
test("Iteration excludes 2", iterated[1] ~= 2 and iterated[2] ~= 2)

-- Iteration order test (should be ascending)
test("Iteration in order (1 before 3)", iterated[1] == 1 and iterated[2] == 3)

-- Empty iteration
reset_all()
local empty_count = 0
for id in entity.iterate() do
    empty_count = empty_count + 1
end
test("Empty iteration yields nothing", empty_count == 0)
-- }}}

-- {{{ Lifecycle Hooks Tests
test_section("Lifecycle Hooks")
reset_all()

local created_ids = {}
local destroyed_ids = {}

entity.on_create(function(id)
    created_ids[#created_ids + 1] = id
end)
entity.on_destroy(function(id)
    destroyed_ids[#destroyed_ids + 1] = id
end)

local h1 = entity.create()
local h2 = entity.create()
test("Create hook called twice", #created_ids == 2)
test("Create hook received correct IDs", created_ids[1] == h1 and created_ids[2] == h2)

entity.destroy(h1)
test("Destroy hook called", #destroyed_ids == 1)
test("Destroy hook received correct ID", destroyed_ids[1] == h1)

-- Multiple hooks
reset_all()
local hook1_calls = 0
local hook2_calls = 0

entity.on_create(function(id) hook1_calls = hook1_calls + 1 end)
entity.on_create(function(id) hook2_calls = hook2_calls + 1 end)

entity.create()
test("Multiple create hooks both called", hook1_calls == 1 and hook2_calls == 1)

-- Destroy hook still has entity data
reset_all()
local entity_existed_in_hook = false

entity.on_destroy(function(id)
    entity_existed_in_hook = entity.exists(id)
end)

local hd = entity.create()
entity.destroy(hd)
test("Entity exists during destroy hook", entity_existed_in_hook)
-- }}}

-- {{{ Hook Error Handling Tests
test_section("Hook Error Handling")
reset_all()

entity.on_create(function(id)
    if type(id) ~= "number" then
        error("invalid id")
    end
end)

-- Should not error
local ok = pcall(function()
    entity.create()
end)
test("Valid create doesn't error", ok)

-- Invalid callback registration
local err_ok = pcall(function()
    entity.on_create("not a function")
end)
test("on_create rejects non-function", not err_ok)

err_ok = pcall(function()
    entity.on_destroy(nil)
end)
test("on_destroy rejects nil", not err_ok)
-- }}}

-- {{{ Reset Tests
test_section("Reset")
reset_all()

entity.create()  -- 1
entity.create()  -- 2
entity.create()  -- 3

entity.reset()
test("Count is 0 after reset", entity.get_count() == 0)
test("Entity 1 doesn't exist after reset", not entity.exists(1))
test("Entity 2 doesn't exist after reset", not entity.exists(2))

local after_reset = entity.create()
test("First entity after reset is 1", after_reset == 1)

-- Reset calls destroy hooks
reset_all()
local reset_destroyed = {}

entity.on_destroy(function(id)
    reset_destroyed[#reset_destroyed + 1] = id
end)

entity.create()  -- 1
entity.create()  -- 2
entity.reset()

test("Reset called destroy hooks", #reset_destroyed == 2)
-- }}}

-- {{{ Debug Stats Tests
test_section("Debug Stats")
reset_all()

entity.create()  -- 1
entity.create()  -- 2
entity.create()  -- 3
entity.destroy(2)

local stats = entity.get_stats()
test("Stats active_count", stats.active_count == 2)
test("Stats next_id", stats.next_id == 4)
test("Stats free_pool_size", stats.free_pool_size == 1)
test("Stats peak_id", stats.peak_id == 3)

local all_ids = entity.get_all_ids()
test("get_all_ids count", #all_ids == 2)

-- Check actual IDs
local has_1 = false
local has_3 = false
for _, id in ipairs(all_ids) do
    if id == 1 then has_1 = true end
    if id == 3 then has_3 = true end
end
test("get_all_ids contains 1", has_1)
test("get_all_ids contains 3", has_3)
-- }}}

-- {{{ ECS Main Module Tests
test_section("ECS Main Module")
reset_all()

local e = ecs.create_entity()
test("ECS create_entity works", e == 1)
test("ECS entity_exists works", ecs.entity_exists(e))
test("ECS get_entity_count works", ecs.get_entity_count() == 1)

local destroyed = ecs.destroy_entity(e)
test("ECS destroy_entity works", destroyed == true)
test("ECS entity gone after destroy", not ecs.entity_exists(e))

-- Test iteration via ECS
ecs.create_entity()  -- 1 (recycled)
ecs.create_entity()  -- 2

local ecs_iterated = {}
for id in ecs.iterate_entities() do
    ecs_iterated[#ecs_iterated + 1] = id
end
test("ECS iterate_entities works", #ecs_iterated == 2)

-- Test hooks via ECS
ecs.clear_hooks()
local ecs_hook_called = false
ecs.on_entity_create(function(id)
    ecs_hook_called = true
end)
ecs.create_entity()
test("ECS on_entity_create works", ecs_hook_called)

-- Test reset via ECS
ecs.reset()
test("ECS reset works", ecs.get_entity_count() == 0)

-- Test stats via ECS
ecs.create_entity()
local ecs_stats = ecs.get_entity_stats()
test("ECS get_entity_stats works", ecs_stats.active_count == 1)
-- }}}

-- {{{ Stress Test
test_section("Stress Test")
reset_all()

-- Create many entities
local stress_count = 1000
for i = 1, stress_count do
    entity.create()
end
test("Created 1000 entities", entity.get_count() == stress_count)

-- Destroy half
for i = 1, stress_count, 2 do
    entity.destroy(i)
end
test("Destroyed 500 entities", entity.get_count() == 500)

-- Create more (should recycle)
local recycled = entity.create()
test("Recycled ID is <= 1000", recycled <= stress_count)

-- Verify count after cycling
for i = 1, 250 do
    entity.create()
end
test("Count after recycling", entity.get_count() == 751)

-- Full reset
entity.reset()
test("Reset clears all", entity.get_count() == 0)
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

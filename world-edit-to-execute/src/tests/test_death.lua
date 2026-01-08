--[[
Death System Tests (Issue 701a)

Tests for death state management, death events, and query functions.
]]

-- {{{ Configuration
local DIR = arg and arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path
-- }}}

local ecs = require("runtime.ecs")
local events = require("runtime.events")
-- Load WC3 components to register position, stats, etc.
local wc3 = require("runtime.ecs.wc3_components")
local death = require("runtime.systems.death")

-- {{{ Test tracking
local tests_run = 0
local tests_passed = 0
local tests_failed = 0
local current_test = ""

local function test(name, fn)
    tests_run = tests_run + 1
    current_test = name
    local ok, err = pcall(fn)
    if ok then
        tests_passed = tests_passed + 1
        print("  [PASS] " .. name)
    else
        tests_failed = tests_failed + 1
        print("  [FAIL] " .. name)
        print("         " .. tostring(err))
    end
end

local function assert_eq(a, b, msg)
    if a ~= b then
        error((msg or "Assertion failed") .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
    end
end

local function assert_true(v, msg)
    if not v then
        error((msg or "Assertion failed") .. ": expected true, got " .. tostring(v))
    end
end

local function assert_false(v, msg)
    if v then
        error((msg or "Assertion failed") .. ": expected false, got " .. tostring(v))
    end
end

local function assert_nil(v, msg)
    if v ~= nil then
        error((msg or "Assertion failed") .. ": expected nil, got " .. tostring(v))
    end
end

local function assert_not_nil(v, msg)
    if v == nil then
        error((msg or "Assertion failed") .. ": expected non-nil value")
    end
end
-- }}}

-- {{{ Setup and teardown
local function setup()
    ecs.reset()
    events.reset()
end

local function create_test_unit(hp)
    local entity = ecs.create_entity()
    ecs.add_component(entity, "position", {x = 100, y = 200})
    ecs.add_component(entity, "stats", {hp = hp or 100, hp_max = 100})
    return entity
end

local function create_test_hero(hp)
    local entity = create_test_unit(hp)
    ecs.add_component(entity, "unit_type", {type_id = "Hpal", is_hero = true})
    ecs.add_component(entity, "hero", {level = 5})
    return entity
end
-- }}}

-- ============================================================================
-- Component Registration Tests
-- ============================================================================

print("\n=== Component Registration ===")

test("dead component is registered", function()
    setup()
    local defaults = ecs.get_component_defaults("dead")
    assert_not_nil(defaults, "dead component not registered")
    assert_eq(defaults.death_time, 0, "death_time default")
    assert_nil(defaults.killer, "killer default")
    assert_eq(defaults.cause, "damage", "cause default")
end)

test("world_layer component is registered", function()
    setup()
    local defaults = ecs.get_component_defaults("world_layer")
    assert_not_nil(defaults, "world_layer component not registered")
    assert_eq(defaults.layer, "mortal", "layer default")
end)

-- ============================================================================
-- Death State Query Tests
-- ============================================================================

print("\n=== Death State Queries ===")

test("is_dead returns false for living entity", function()
    setup()
    local entity = create_test_unit()
    assert_false(death.is_dead(entity), "living entity should not be dead")
end)

test("is_dead returns true after kill", function()
    setup()
    local entity = create_test_unit()
    death.kill(entity)
    assert_true(death.is_dead(entity), "killed entity should be dead")
end)

test("is_alive returns true for living entity", function()
    setup()
    local entity = create_test_unit()
    assert_true(death.is_alive(entity), "entity with stats should be alive")
end)

test("is_alive returns false after kill", function()
    setup()
    local entity = create_test_unit()
    death.kill(entity)
    assert_false(death.is_alive(entity), "killed entity should not be alive")
end)

test("is_alive returns false for entity without stats", function()
    setup()
    local entity = ecs.create_entity()
    ecs.add_component(entity, "position", {x = 0, y = 0})
    assert_false(death.is_alive(entity), "entity without stats is not alive")
end)

test("is_alive returns false for non-existent entity", function()
    setup()
    assert_false(death.is_alive(99999), "non-existent entity should not be alive")
end)

-- ============================================================================
-- Kill Tests
-- ============================================================================

print("\n=== Kill Function ===")

test("kill adds dead component", function()
    setup()
    local entity = create_test_unit()
    death.kill(entity)
    assert_true(ecs.has_component(entity, "dead"), "should have dead component")
end)

test("kill returns true on success", function()
    setup()
    local entity = create_test_unit()
    local result = death.kill(entity)
    assert_true(result, "kill should return true")
end)

test("kill returns false for non-existent entity", function()
    setup()
    local result = death.kill(99999)
    assert_false(result, "kill should return false for invalid entity")
end)

test("kill returns false if already dead", function()
    setup()
    local entity = create_test_unit()
    death.kill(entity)
    local result = death.kill(entity)
    assert_false(result, "kill should return false if already dead")
end)

test("kill returns false for entity without stats", function()
    setup()
    local entity = ecs.create_entity()
    ecs.add_component(entity, "position", {x = 0, y = 0})
    local result = death.kill(entity)
    assert_false(result, "kill should return false for entity without stats")
end)

test("kill stores killer entity", function()
    setup()
    local victim = create_test_unit()
    local killer = create_test_unit()
    death.kill(victim, killer)
    assert_eq(death.get_killer(victim), killer, "killer should be stored")
end)

test("kill stores cause", function()
    setup()
    local entity = create_test_unit()
    death.kill(entity, nil, death.CAUSE.SPELL)
    assert_eq(death.get_cause(entity), "spell", "cause should be stored")
end)

test("kill defaults cause to damage", function()
    setup()
    local entity = create_test_unit()
    death.kill(entity)
    assert_eq(death.get_cause(entity), "damage", "default cause should be damage")
end)

-- ============================================================================
-- Death Event Tests
-- ============================================================================

print("\n=== Death Events ===")

test("UNIT_DEATH event fires on kill", function()
    setup()
    local entity = create_test_unit()
    local event_fired = false
    local event_ctx = nil

    -- Create mock trigger
    local trigger = {
        events = {},
        fire = function(self, ctx)
            event_fired = true
            event_ctx = ctx
        end
    }
    events.register(events.EVENT.UNIT_DEATH, trigger)

    death.kill(entity)

    assert_true(event_fired, "UNIT_DEATH event should fire")
    assert_eq(event_ctx.dying_unit, entity, "dying_unit should match")
end)

test("HERO_DEATH event fires for heroes", function()
    setup()
    local hero = create_test_hero()
    local unit_death_fired = false
    local hero_death_fired = false

    local unit_trigger = {
        events = {},
        fire = function() unit_death_fired = true end
    }
    local hero_trigger = {
        events = {},
        fire = function() hero_death_fired = true end
    }

    events.register(events.EVENT.UNIT_DEATH, unit_trigger)
    events.register(events.EVENT.HERO_DEATH, hero_trigger)

    death.kill(hero)

    assert_true(unit_death_fired, "UNIT_DEATH should fire for hero")
    assert_true(hero_death_fired, "HERO_DEATH should fire for hero")
end)

test("HERO_DEATH does not fire for non-heroes", function()
    setup()
    local unit = create_test_unit()
    local hero_death_fired = false

    local trigger = {
        events = {},
        fire = function() hero_death_fired = true end
    }
    events.register(events.EVENT.HERO_DEATH, trigger)

    death.kill(unit)

    assert_false(hero_death_fired, "HERO_DEATH should not fire for non-hero")
end)

test("no events fire for REMOVE cause", function()
    setup()
    local entity = create_test_unit()
    local event_fired = false

    local trigger = {
        events = {},
        fire = function() event_fired = true end
    }
    events.register(events.EVENT.UNIT_DEATH, trigger)

    death.kill(entity, nil, death.CAUSE.REMOVE)

    assert_false(event_fired, "no events should fire for REMOVE cause")
end)

-- ============================================================================
-- Layer Tests
-- ============================================================================

print("\n=== Layer Functions ===")

test("get_layer returns mortal by default", function()
    setup()
    local entity = create_test_unit()
    assert_eq(death.get_layer(entity), "mortal", "default layer should be mortal")
end)

test("send_to_spirit_world changes layer", function()
    setup()
    local entity = create_test_unit()
    death.send_to_spirit_world(entity)
    assert_eq(death.get_layer(entity), "spirit", "layer should be spirit")
end)

test("return_to_mortal_world changes layer back", function()
    setup()
    local entity = create_test_unit()
    death.send_to_spirit_world(entity)
    death.return_to_mortal_world(entity)
    assert_eq(death.get_layer(entity), "mortal", "layer should be mortal")
end)

test("is_in_spirit_world works correctly", function()
    setup()
    local entity = create_test_unit()
    assert_false(death.is_in_spirit_world(entity), "should not be in spirit world")
    death.send_to_spirit_world(entity)
    assert_true(death.is_in_spirit_world(entity), "should be in spirit world")
end)

test("is_in_mortal_world works correctly", function()
    setup()
    local entity = create_test_unit()
    assert_true(death.is_in_mortal_world(entity), "should be in mortal world")
    death.send_to_spirit_world(entity)
    assert_false(death.is_in_mortal_world(entity), "should not be in mortal world")
end)

-- ============================================================================
-- Revive Tests
-- ============================================================================

print("\n=== Revive Function ===")

test("revive removes dead component", function()
    setup()
    local entity = create_test_unit()
    death.kill(entity)
    death.revive(entity)
    assert_false(death.is_dead(entity), "revived entity should not be dead")
end)

test("revive returns false for living entity", function()
    setup()
    local entity = create_test_unit()
    local result = death.revive(entity)
    assert_false(result, "cannot revive living entity")
end)

test("revive restores HP", function()
    setup()
    local entity = create_test_unit()
    death.kill(entity)
    death.revive(entity, nil, nil, 0.5)
    local stats = ecs.get_component(entity, "stats")
    assert_eq(stats.hp, 50, "HP should be 50% of max")
end)

test("revive defaults to full HP", function()
    setup()
    local entity = create_test_unit()
    death.kill(entity)
    death.revive(entity)
    local stats = ecs.get_component(entity, "stats")
    assert_eq(stats.hp, 100, "HP should be full")
end)

test("revive updates position if provided", function()
    setup()
    local entity = create_test_unit()
    death.kill(entity)
    death.revive(entity, 500, 600)
    local pos = ecs.get_component(entity, "position")
    assert_eq(pos.x, 500, "X should be updated")
    assert_eq(pos.y, 600, "Y should be updated")
end)

test("revive returns to mortal world", function()
    setup()
    local entity = create_test_unit()
    death.kill(entity)
    death.send_to_spirit_world(entity)
    death.revive(entity)
    assert_true(death.is_in_mortal_world(entity), "should be in mortal world")
end)

-- ============================================================================
-- Remove Tests
-- ============================================================================

print("\n=== Remove Function ===")

test("remove destroys entity", function()
    setup()
    local entity = create_test_unit()
    death.remove(entity)
    assert_false(ecs.entity_exists(entity), "entity should be destroyed")
end)

test("remove returns true on success", function()
    setup()
    local entity = create_test_unit()
    local result = death.remove(entity)
    assert_true(result, "remove should return true")
end)

test("remove returns false for invalid entity", function()
    setup()
    local result = death.remove(99999)
    assert_false(result, "remove should return false for invalid entity")
end)

-- ============================================================================
-- Count Functions
-- ============================================================================

print("\n=== Count Functions ===")

test("count_dead returns correct count", function()
    setup()
    local e1 = create_test_unit()
    local e2 = create_test_unit()
    local e3 = create_test_unit()

    death.kill(e1)
    death.kill(e2)

    assert_eq(death.count_dead(), 2, "should count 2 dead entities")
end)

test("count_living excludes dead entities", function()
    setup()
    local e1 = create_test_unit()
    local e2 = create_test_unit()
    local e3 = create_test_unit()

    death.kill(e1)

    -- The count should be 2 (e2 and e3 are alive)
    -- Note: This test depends on query_living implementation
    local count = 0
    for _ in death.query_living()() do
        count = count + 1
    end
    assert_eq(count, 2, "should count 2 living entities")
end)

-- ============================================================================
-- Summary
-- ============================================================================

print("\n=== Test Summary ===")
print(string.format("  Total:  %d", tests_run))
print(string.format("  Passed: %d", tests_passed))
print(string.format("  Failed: %d", tests_failed))

if tests_failed > 0 then
    print("\n[FAILED] Some tests failed!")
    os.exit(1)
else
    print("\n[SUCCESS] All tests passed!")
    os.exit(0)
end

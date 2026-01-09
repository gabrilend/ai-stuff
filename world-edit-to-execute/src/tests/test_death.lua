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
    death.reset_tracking()  -- Clear corpse tracking tables
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
-- Corpse System Tests (701e)
-- ============================================================================

print("\n=== Corpse Component ===")

test("corpse component is registered", function()
    setup()
    local defaults = ecs.get_component_defaults("corpse")
    assert_not_nil(defaults, "corpse component not registered")
    assert_eq(defaults.decay_timer, 88.0, "decay_timer default")
    assert_eq(defaults.raiseable, true, "raiseable default")
    assert_eq(defaults.flesh_remaining, true, "flesh_remaining default")
end)

print("\n=== Corpse Creation ===")

test("create_corpse returns corpse entity for dead unit", function()
    setup()
    local unit = create_test_unit()
    death.kill(unit)
    local corpse = death.create_corpse(unit)
    assert_not_nil(corpse, "corpse should be created")
    assert_true(death.is_corpse(corpse), "should be identified as corpse")
end)

test("create_corpse returns nil for living unit", function()
    setup()
    local unit = create_test_unit()
    local corpse = death.create_corpse(unit)
    assert_nil(corpse, "living unit should not create corpse")
end)

test("create_corpse uses unit position", function()
    setup()
    local unit = create_test_unit()
    local pos = ecs.get_component(unit, "position")
    pos.x = 500
    pos.y = 600
    death.kill(unit)
    local corpse = death.create_corpse(unit)
    local corpse_pos = ecs.get_component(corpse, "position")
    assert_eq(corpse_pos.x, 500, "corpse X should match")
    assert_eq(corpse_pos.y, 600, "corpse Y should match")
end)

test("create_corpse returns existing corpse if called twice", function()
    setup()
    local unit = create_test_unit()
    death.kill(unit)
    local corpse1 = death.create_corpse(unit)
    local corpse2 = death.create_corpse(unit)
    assert_eq(corpse1, corpse2, "should return same corpse")
end)

test("create_corpse uses hero decay time for heroes", function()
    setup()
    local hero = create_test_hero()
    death.kill(hero)
    local corpse = death.create_corpse(hero)
    local corpse_comp = ecs.get_component(corpse, "corpse")
    assert_eq(corpse_comp.decay_max, death.DECAY_TIME.HERO, "hero should have 88s decay")
end)

test("create_corpse_at creates corpse at position", function()
    setup()
    local corpse = death.create_corpse_at(300, 400, "hfoo")
    assert_not_nil(corpse, "corpse should be created")
    local pos = ecs.get_component(corpse, "position")
    assert_eq(pos.x, 300, "X should be 300")
    assert_eq(pos.y, 400, "Y should be 400")
end)

test("should_create_corpse returns false for summoned units", function()
    setup()
    local unit = create_test_unit()
    local unit_type = ecs.get_component(unit, "unit_type")
    if not unit_type then
        ecs.add_component(unit, "unit_type", {is_summoned = true})
    else
        unit_type.is_summoned = true
    end
    assert_false(death.should_create_corpse(unit), "summoned units shouldn't leave corpses")
end)

print("\n=== Corpse Queries ===")

test("get_corpse returns corpse for dead unit", function()
    setup()
    local unit = create_test_unit()
    death.kill(unit)
    local created = death.create_corpse(unit)
    local found = death.get_corpse(unit)
    assert_eq(created, found, "should return same corpse")
end)

test("get_corpse_unit returns original unit", function()
    setup()
    local unit = create_test_unit()
    death.kill(unit)
    local corpse = death.create_corpse(unit)
    local found = death.get_corpse_unit(corpse)
    assert_eq(found, unit, "should return original unit")
end)

test("is_corpse returns true for corpse entity", function()
    setup()
    local corpse = death.create_corpse_at(0, 0)
    assert_true(death.is_corpse(corpse), "should identify as corpse")
end)

test("is_corpse returns false for unit", function()
    setup()
    local unit = create_test_unit()
    assert_false(death.is_corpse(unit), "unit should not be corpse")
end)

test("is_raiseable returns true for fresh corpse", function()
    setup()
    local corpse = death.create_corpse_at(0, 0)
    assert_true(death.is_raiseable(corpse), "fresh corpse should be raiseable")
end)

test("is_raiseable returns false after raise_corpse", function()
    setup()
    local corpse = death.create_corpse_at(0, 0)
    death.raise_corpse(corpse)
    assert_false(death.is_raiseable(corpse), "raised corpse should not be raiseable")
end)

test("is_fresh returns true for new corpse", function()
    setup()
    local corpse = death.create_corpse_at(0, 0)
    assert_true(death.is_fresh(corpse), "new corpse should be fresh")
end)

print("\n=== Corpse Decay ===")

test("get_decay_remaining returns initial value", function()
    setup()
    local corpse = death.create_corpse_at(0, 0, nil, 60)
    local remaining = death.get_decay_remaining(corpse)
    assert_eq(remaining, 60, "should be 60 seconds")
end)

test("get_decay_progress returns 0 for new corpse", function()
    setup()
    local corpse = death.create_corpse_at(0, 0, nil, 60)
    local progress = death.get_decay_progress(corpse)
    assert_eq(progress, 0, "progress should be 0")
end)

test("count_corpses returns correct count", function()
    setup()
    death.create_corpse_at(0, 0)
    death.create_corpse_at(100, 100)
    death.create_corpse_at(200, 200)
    assert_eq(death.count_corpses(), 3, "should count 3 corpses")
end)

print("\n=== Corpse Modification ===")

test("raise_corpse marks corpse as raised", function()
    setup()
    local corpse = death.create_corpse_at(0, 0)
    local result = death.raise_corpse(corpse)
    assert_true(result, "raise should succeed")
    local corpse_comp = ecs.get_component(corpse, "corpse")
    assert_true(corpse_comp.raised, "raised flag should be true")
end)

test("raise_corpse returns false for already raised", function()
    setup()
    local corpse = death.create_corpse_at(0, 0)
    death.raise_corpse(corpse)
    local result = death.raise_corpse(corpse)
    assert_false(result, "cannot raise twice")
end)

test("consume_corpse removes corpse", function()
    setup()
    local corpse = death.create_corpse_at(0, 0)
    death.consume_corpse(corpse)
    assert_false(ecs.entity_exists(corpse), "corpse should be destroyed")
end)

test("consume_corpse clears tracking", function()
    setup()
    local unit = create_test_unit()
    death.kill(unit)
    local corpse = death.create_corpse(unit)
    death.consume_corpse(corpse)
    assert_nil(death.get_corpse(unit), "tracking should be cleared")
end)

print("\n=== Corpse Spatial Query ===")

test("find_corpses_in_range finds nearby corpses", function()
    setup()
    death.create_corpse_at(100, 100)
    death.create_corpse_at(150, 150)
    death.create_corpse_at(1000, 1000)  -- Far away
    local found = death.find_corpses_in_range(100, 100, 200)
    assert_eq(#found, 2, "should find 2 nearby corpses")
end)

test("find_corpses_in_range respects filter", function()
    setup()
    local c1 = death.create_corpse_at(100, 100, "hfoo")
    death.create_corpse_at(150, 150, "ogru")
    -- Filter for only "hfoo" type
    local found = death.find_corpses_in_range(100, 100, 200, function(corpse)
        local cc = ecs.get_component(corpse, "corpse")
        return cc and cc.unit_type_id == "hfoo"
    end)
    assert_eq(#found, 1, "should find 1 matching corpse")
    assert_eq(found[1], c1, "should be the hfoo corpse")
end)

print("\n=== Corpse-Ghost Link ===")

test("link_corpse_to_ghost sets linked_ghost", function()
    setup()
    local corpse = death.create_corpse_at(0, 0)
    local ghost_id = 999  -- Fake ghost ID
    death.link_corpse_to_ghost(corpse, ghost_id)
    local corpse_comp = ecs.get_component(corpse, "corpse")
    assert_eq(corpse_comp.linked_ghost, ghost_id, "linked_ghost should be set")
end)

-- ============================================================================
-- Ghost System Tests (701c)
-- ============================================================================

print("\n=== Ghost Component ===")

test("ghost component is registered", function()
    setup()
    local defaults = ecs.get_component_defaults("ghost")
    assert_not_nil(defaults, "ghost component not registered")
    assert_eq(defaults.movement_speed, 400, "movement_speed default")
    assert_eq(defaults.visible_to_owner, true, "visible_to_owner default")
    assert_eq(defaults.visible_to_allies, false, "visible_to_allies default")
end)

print("\n=== Ghost Creation ===")

test("create_ghost returns ghost entity for dead hero", function()
    setup()
    local hero = create_test_hero()
    death.kill(hero)
    local ghost = death.create_ghost(hero)
    assert_not_nil(ghost, "ghost should be created")
    assert_true(death.is_ghost(ghost), "should be identified as ghost")
end)

test("create_ghost returns nil for non-hero", function()
    setup()
    local unit = create_test_unit()
    death.kill(unit)
    local ghost = death.create_ghost(unit)
    assert_nil(ghost, "non-hero should not create ghost")
end)

test("create_ghost returns nil for living hero", function()
    setup()
    local hero = create_test_hero()
    local ghost = death.create_ghost(hero)
    assert_nil(ghost, "living hero should not create ghost")
end)

test("create_ghost uses hero position", function()
    setup()
    local hero = create_test_hero()
    local pos = ecs.get_component(hero, "position")
    pos.x = 500
    pos.y = 600
    death.kill(hero)
    local ghost = death.create_ghost(hero)
    local ghost_pos = ecs.get_component(ghost, "position")
    assert_eq(ghost_pos.x, 500, "ghost X should match")
    assert_eq(ghost_pos.y, 600, "ghost Y should match")
end)

test("create_ghost returns existing ghost if called twice", function()
    setup()
    local hero = create_test_hero()
    death.kill(hero)
    local ghost1 = death.create_ghost(hero)
    local ghost2 = death.create_ghost(hero)
    assert_eq(ghost1, ghost2, "should return same ghost")
end)

test("create_ghost puts ghost in spirit world", function()
    setup()
    local hero = create_test_hero()
    death.kill(hero)
    local ghost = death.create_ghost(hero)
    assert_true(death.is_in_spirit_world(ghost), "ghost should be in spirit world")
end)

test("create_ghost links to corpse", function()
    setup()
    local hero = create_test_hero()
    death.kill(hero)
    local corpse = death.create_corpse(hero)
    local ghost = death.create_ghost(hero, corpse)
    assert_eq(death.get_linked_corpse(ghost), corpse, "ghost should link to corpse")
end)

print("\n=== Ghost Data Preservation ===")

test("preserve_hero_data captures position", function()
    setup()
    local hero = create_test_hero()
    local pos = ecs.get_component(hero, "position")
    pos.x = 123
    pos.y = 456
    local data = death.preserve_hero_data(hero)
    assert_eq(data.death_x, 123, "death_x should be preserved")
    assert_eq(data.death_y, 456, "death_y should be preserved")
end)

test("preserve_hero_data captures hero stats", function()
    setup()
    local hero = create_test_hero()
    local hero_comp = ecs.get_component(hero, "hero")
    hero_comp.level = 7
    hero_comp.experience = 5000
    local data = death.preserve_hero_data(hero)
    assert_eq(data.level, 7, "level should be preserved")
    assert_eq(data.experience, 5000, "experience should be preserved")
end)

test("get_original_data returns preserved data", function()
    setup()
    local hero = create_test_hero()
    local hero_comp = ecs.get_component(hero, "hero")
    hero_comp.level = 3
    death.kill(hero)
    local ghost = death.create_ghost(hero)
    local data = death.get_original_data(ghost)
    assert_eq(data.level, 3, "level should be in original data")
end)

print("\n=== Ghost Queries ===")

test("get_ghost returns ghost for dead hero", function()
    setup()
    local hero = create_test_hero()
    death.kill(hero)
    local created = death.create_ghost(hero)
    local found = death.get_ghost(hero)
    assert_eq(created, found, "should return same ghost")
end)

test("get_ghost_unit returns original hero", function()
    setup()
    local hero = create_test_hero()
    death.kill(hero)
    local ghost = death.create_ghost(hero)
    local found = death.get_ghost_unit(ghost)
    assert_eq(found, hero, "should return original hero")
end)

test("is_ghost returns true for ghost entity", function()
    setup()
    local hero = create_test_hero()
    death.kill(hero)
    local ghost = death.create_ghost(hero)
    assert_true(death.is_ghost(ghost), "should identify as ghost")
end)

test("is_ghost returns false for hero", function()
    setup()
    local hero = create_test_hero()
    assert_false(death.is_ghost(hero), "hero should not be ghost")
end)

test("count_ghosts returns correct count", function()
    setup()
    local h1 = create_test_hero()
    local h2 = create_test_hero()
    death.kill(h1)
    death.kill(h2)
    death.create_ghost(h1)
    death.create_ghost(h2)
    assert_eq(death.count_ghosts(), 2, "should count 2 ghosts")
end)

print("\n=== Ghost Visibility ===")

test("can_see_ghost returns true for owner by default", function()
    setup()
    local hero = create_test_hero()
    -- Add owner component (create_test_hero doesn't add one)
    ecs.add_component(hero, "owner", {player_id = 1})
    death.kill(hero)
    local ghost = death.create_ghost(hero)
    assert_true(death.can_see_ghost(1, ghost), "owner should see ghost")
end)

test("can_see_ghost returns false for non-owner by default", function()
    setup()
    local hero = create_test_hero()
    -- Add owner component (create_test_hero doesn't add one)
    ecs.add_component(hero, "owner", {player_id = 1})
    death.kill(hero)
    local ghost = death.create_ghost(hero)
    assert_false(death.can_see_ghost(2, ghost), "non-owner should not see ghost")
end)

test("set_ghost_visibility changes visibility rules", function()
    setup()
    local hero = create_test_hero()
    death.kill(hero)
    local ghost = death.create_ghost(hero)
    death.set_ghost_visibility(ghost, true, true, true)
    local ghost_comp = ecs.get_component(ghost, "ghost")
    assert_true(ghost_comp.visible_to_allies, "allies should see")
    assert_true(ghost_comp.visible_to_enemies, "enemies should see")
end)

print("\n=== Ghost Altar State ===")

test("ghost_at_altar marks ghost", function()
    setup()
    local hero = create_test_hero()
    death.kill(hero)
    local ghost = death.create_ghost(hero)
    death.ghost_at_altar(ghost)
    assert_true(death.is_at_altar(ghost), "ghost should be at altar")
end)

test("is_at_altar returns false for new ghost", function()
    setup()
    local hero = create_test_hero()
    death.kill(hero)
    local ghost = death.create_ghost(hero)
    assert_false(death.is_at_altar(ghost), "new ghost should not be at altar")
end)

print("\n=== Ghost Cleanup ===")

test("destroy_ghost removes ghost entity", function()
    setup()
    local hero = create_test_hero()
    death.kill(hero)
    local ghost = death.create_ghost(hero)
    death.destroy_ghost(ghost)
    assert_false(ecs.entity_exists(ghost), "ghost should be destroyed")
end)

test("destroy_ghost clears tracking", function()
    setup()
    local hero = create_test_hero()
    death.kill(hero)
    local ghost = death.create_ghost(hero)
    death.destroy_ghost(ghost)
    assert_nil(death.get_ghost(hero), "tracking should be cleared")
end)

test("destroy_ghost unlinks from corpse", function()
    setup()
    local hero = create_test_hero()
    death.kill(hero)
    local corpse = death.create_corpse(hero)
    local ghost = death.create_ghost(hero, corpse)
    death.destroy_ghost(ghost)
    local corpse_comp = ecs.get_component(corpse, "corpse")
    assert_nil(corpse_comp.linked_ghost, "corpse should be unlinked")
end)

-- ============================================================================
-- Resurrection Mechanics Tests (701d)
-- ============================================================================

print("\n=== Reviving Component ===")

test("reviving component is registered", function()
    setup()
    local defaults = ecs.get_component_defaults("reviving")
    assert_not_nil(defaults, "reviving component not registered")
    assert_eq(defaults.time_remaining, 0, "time_remaining default")
    assert_eq(defaults.time_total, 0, "time_total default")
    assert_eq(defaults.gold_cost, 0, "gold_cost default")
end)

print("\n=== Revival Formulas ===")

test("get_revival_time returns correct time for level 1", function()
    setup()
    local time = death.get_revival_time(1)
    assert_eq(time, 55, "level 1 should be 55 seconds")
end)

test("get_revival_time returns correct time for level 5", function()
    setup()
    local time = death.get_revival_time(5)
    assert_eq(time, 75, "level 5 should be 75 seconds")
end)

test("get_revival_time returns correct time for level 10", function()
    setup()
    local time = death.get_revival_time(10)
    assert_eq(time, 100, "level 10 should be 100 seconds")
end)

test("get_revival_cost returns correct cost for level 1", function()
    setup()
    local cost = death.get_revival_cost(1)
    assert_eq(cost, 100, "level 1 should cost 100 gold")
end)

test("get_revival_cost returns correct cost for level 5", function()
    setup()
    local cost = death.get_revival_cost(5)
    assert_eq(cost, 500, "level 5 should cost 500 gold")
end)

test("get_revival_cost returns correct cost for level 10", function()
    setup()
    local cost = death.get_revival_cost(10)
    assert_eq(cost, 1000, "level 10 should cost 1000 gold")
end)

print("\n=== Altar Functions ===")

local function create_test_altar(player_id)
    local altar = ecs.create_entity()
    ecs.add_component(altar, "position", {x = 500, y = 500})
    ecs.add_component(altar, "stats", {hp = 1500, hp_max = 1500})
    ecs.add_component(altar, "unit_type", {type_id = "halt", is_altar = true})
    ecs.add_component(altar, "owner", {player_id = player_id or 1})
    return altar
end

test("is_altar returns true for altar entity", function()
    setup()
    local altar = create_test_altar()
    assert_true(death.is_altar(altar), "should identify as altar")
end)

test("is_altar returns false for non-altar", function()
    setup()
    local unit = create_test_unit()
    assert_false(death.is_altar(unit), "unit should not be altar")
end)

test("can_revive_at returns true for valid altar/ghost pair", function()
    setup()
    local hero = create_test_hero()
    ecs.add_component(hero, "owner", {player_id = 1})
    local altar = create_test_altar(1)
    death.kill(hero)
    local ghost = death.create_ghost(hero)
    local can_revive, err = death.can_revive_at(altar, ghost)
    assert_true(can_revive, "should be able to revive")
    assert_nil(err, "should have no error")
end)

test("can_revive_at returns false for dead altar", function()
    setup()
    local hero = create_test_hero()
    ecs.add_component(hero, "owner", {player_id = 1})
    local altar = create_test_altar(1)
    death.kill(altar)  -- Kill the altar
    death.kill(hero)
    local ghost = death.create_ghost(hero)
    local can_revive, err = death.can_revive_at(altar, ghost)
    assert_false(can_revive, "should not revive at dead altar")
    assert_eq(err, "altar is dead", "error message should match")
end)

test("can_revive_at returns false for different owner", function()
    setup()
    local hero = create_test_hero()
    ecs.add_component(hero, "owner", {player_id = 1})
    local altar = create_test_altar(2)  -- Different owner
    death.kill(hero)
    local ghost = death.create_ghost(hero)
    local can_revive, err = death.can_revive_at(altar, ghost)
    assert_false(can_revive, "should not revive at enemy altar")
    assert_eq(err, "altar belongs to different player", "error message should match")
end)

print("\n=== Begin Altar Revival ===")

test("begin_altar_revival starts revival process", function()
    setup()
    local hero = create_test_hero()
    ecs.add_component(hero, "owner", {player_id = 1})
    local altar = create_test_altar(1)
    death.kill(hero)
    local ghost = death.create_ghost(hero)
    local success, err = death.begin_altar_revival(altar, ghost)
    assert_true(success, "revival should start")
    assert_nil(err, "should have no error")
    assert_true(death.is_reviving(ghost), "ghost should be reviving")
end)

test("begin_altar_revival adds reviving component", function()
    setup()
    local hero = create_test_hero()
    ecs.add_component(hero, "owner", {player_id = 1})
    local altar = create_test_altar(1)
    death.kill(hero)
    local ghost = death.create_ghost(hero)
    death.begin_altar_revival(altar, ghost)
    assert_true(ecs.has_component(ghost, "reviving"), "should have reviving component")
end)

test("begin_altar_revival sets correct time based on hero level", function()
    setup()
    local hero = create_test_hero()
    local hero_comp = ecs.get_component(hero, "hero")
    hero_comp.level = 5
    ecs.add_component(hero, "owner", {player_id = 1})
    local altar = create_test_altar(1)
    death.kill(hero)
    local ghost = death.create_ghost(hero)
    death.begin_altar_revival(altar, ghost)
    local remaining = death.get_revival_time_remaining(ghost)
    assert_eq(remaining, 75, "level 5 hero should take 75 seconds")
end)

test("begin_altar_revival fires HERO_REVIVE_START event", function()
    setup()
    local hero = create_test_hero()
    ecs.add_component(hero, "owner", {player_id = 1})
    local altar = create_test_altar(1)
    local event_fired = false
    local event_ctx = nil
    local trigger = {
        events = {},
        fire = function(self, ctx)
            event_fired = true
            event_ctx = ctx
        end
    }
    events.register(events.EVENT.HERO_REVIVE_START, trigger)
    death.kill(hero)
    local ghost = death.create_ghost(hero)
    death.begin_altar_revival(altar, ghost)
    assert_true(event_fired, "HERO_REVIVE_START event should fire")
    assert_eq(event_ctx.altar, altar, "altar should match in event")
    assert_eq(event_ctx.ghost, ghost, "ghost should match in event")
end)

test("begin_altar_revival adds ghost to altar queue", function()
    setup()
    local hero = create_test_hero()
    ecs.add_component(hero, "owner", {player_id = 1})
    local altar = create_test_altar(1)
    death.kill(hero)
    local ghost = death.create_ghost(hero)
    death.begin_altar_revival(altar, ghost)
    local queue = death.get_altar_queue(altar)
    assert_eq(#queue, 1, "queue should have 1 ghost")
    assert_eq(queue[1], ghost, "ghost should be in queue")
end)

test("begin_altar_revival fails for already reviving ghost", function()
    setup()
    local hero = create_test_hero()
    ecs.add_component(hero, "owner", {player_id = 1})
    local altar = create_test_altar(1)
    death.kill(hero)
    local ghost = death.create_ghost(hero)
    death.begin_altar_revival(altar, ghost)
    local success, err = death.begin_altar_revival(altar, ghost)
    assert_false(success, "should not start second revival")
    assert_eq(err, "already reviving", "error message should match")
end)

print("\n=== Cancel Altar Revival ===")

test("cancel_altar_revival stops revival", function()
    setup()
    local hero = create_test_hero()
    ecs.add_component(hero, "owner", {player_id = 1})
    local altar = create_test_altar(1)
    death.kill(hero)
    local ghost = death.create_ghost(hero)
    death.begin_altar_revival(altar, ghost, 500)
    local success, refund = death.cancel_altar_revival(ghost)
    assert_true(success, "cancel should succeed")
    assert_eq(refund, 500, "should refund gold")
    assert_false(death.is_reviving(ghost), "ghost should not be reviving")
end)

test("cancel_altar_revival removes from altar queue", function()
    setup()
    local hero = create_test_hero()
    ecs.add_component(hero, "owner", {player_id = 1})
    local altar = create_test_altar(1)
    death.kill(hero)
    local ghost = death.create_ghost(hero)
    death.begin_altar_revival(altar, ghost)
    death.cancel_altar_revival(ghost)
    local queue = death.get_altar_queue(altar)
    assert_eq(#queue, 0, "queue should be empty")
end)

test("cancel_altar_revival returns false for non-reviving ghost", function()
    setup()
    local hero = create_test_hero()
    death.kill(hero)
    local ghost = death.create_ghost(hero)
    local success, refund = death.cancel_altar_revival(ghost)
    assert_false(success, "cancel should fail")
    assert_eq(refund, 0, "should not refund anything")
end)

print("\n=== Revival Progress ===")

test("get_revival_progress returns 0 when just started", function()
    setup()
    local hero = create_test_hero()
    ecs.add_component(hero, "owner", {player_id = 1})
    local altar = create_test_altar(1)
    death.kill(hero)
    local ghost = death.create_ghost(hero)
    death.begin_altar_revival(altar, ghost)
    local progress = death.get_revival_progress(ghost)
    assert_eq(progress, 0, "progress should be 0 at start")
end)

test("get_revival_progress returns nil for non-reviving ghost", function()
    setup()
    local hero = create_test_hero()
    death.kill(hero)
    local ghost = death.create_ghost(hero)
    local progress = death.get_revival_progress(ghost)
    assert_nil(progress, "progress should be nil")
end)

test("get_reviving_altar returns correct altar", function()
    setup()
    local hero = create_test_hero()
    ecs.add_component(hero, "owner", {player_id = 1})
    local altar = create_test_altar(1)
    death.kill(hero)
    local ghost = death.create_ghost(hero)
    death.begin_altar_revival(altar, ghost)
    local found = death.get_reviving_altar(ghost)
    assert_eq(found, altar, "should return correct altar")
end)

print("\n=== Hero Revival ===")

test("revive_hero revives dead hero", function()
    setup()
    local hero = create_test_hero()
    death.kill(hero)
    local success = death.revive_hero(hero, 300, 400)
    assert_true(success, "revive should succeed")
    assert_false(death.is_dead(hero), "hero should not be dead")
end)

test("revive_hero updates position", function()
    setup()
    local hero = create_test_hero()
    death.kill(hero)
    death.revive_hero(hero, 300, 400)
    local pos = ecs.get_component(hero, "position")
    assert_eq(pos.x, 300, "X should be 300")
    assert_eq(pos.y, 400, "Y should be 400")
end)

test("revive_hero restores HP", function()
    setup()
    local hero = create_test_hero()
    death.kill(hero)
    death.revive_hero(hero, nil, nil, 0.5)
    local stats = ecs.get_component(hero, "stats")
    assert_eq(stats.hp, 50, "HP should be 50% of max")
end)

test("revive_hero destroys ghost", function()
    setup()
    local hero = create_test_hero()
    death.kill(hero)
    local ghost = death.create_ghost(hero)
    death.revive_hero(hero)
    assert_false(ecs.entity_exists(ghost), "ghost should be destroyed")
end)

test("revive_hero destroys corpse", function()
    setup()
    local hero = create_test_hero()
    death.kill(hero)
    local corpse = death.create_corpse(hero)
    local ghost = death.create_ghost(hero, corpse)
    death.revive_hero(hero)
    assert_false(ecs.entity_exists(corpse), "corpse should be destroyed")
end)

test("revive_hero cancels altar revival", function()
    setup()
    local hero = create_test_hero()
    ecs.add_component(hero, "owner", {player_id = 1})
    local altar = create_test_altar(1)
    death.kill(hero)
    local ghost = death.create_ghost(hero)
    death.begin_altar_revival(altar, ghost)
    death.revive_hero(hero)
    -- Ghost destroyed, so is_reviving would error - check queue instead
    local queue = death.get_altar_queue(altar)
    assert_eq(#queue, 0, "altar queue should be empty")
end)

print("\n=== Revive At Corpse ===")

test("revive_at_corpse uses corpse position", function()
    setup()
    local hero = create_test_hero()
    death.kill(hero)
    local corpse = death.create_corpse(hero)
    local corpse_pos = ecs.get_component(corpse, "position")
    corpse_pos.x = 777
    corpse_pos.y = 888
    death.revive_at_corpse(hero)
    local pos = ecs.get_component(hero, "position")
    assert_eq(pos.x, 777, "X should match corpse")
    assert_eq(pos.y, 888, "Y should match corpse")
end)

test("revive_at_corpse returns false for living hero", function()
    setup()
    local hero = create_test_hero()
    local success = death.revive_at_corpse(hero)
    assert_false(success, "cannot revive living hero")
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

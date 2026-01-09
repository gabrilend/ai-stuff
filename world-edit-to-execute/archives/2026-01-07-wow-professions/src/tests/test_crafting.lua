--[[
Unit tests for the Crafting System (Issue 702c)

Tests cover:
- Station management (use, leave, availability)
- Craft flow (start, cancel, complete)
- Quality system
- Integration with recipes and professions
]]

-- {{{ Configuration
local DIR = arg and arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path
-- }}}

local ecs = require("runtime.ecs")
local events = require("runtime.events")
local professions = require("runtime.systems.professions")
local recipes = require("runtime.systems.recipes")
local crafting = require("runtime.systems.crafting")

-- ============================================================================
-- Test Harness
-- ============================================================================

-- {{{ Test state
local tests_run = 0
local tests_passed = 0
local current_test = ""
-- }}}

-- {{{ assert_eq
local function assert_eq(actual, expected, msg)
    if actual ~= expected then
        print("  FAIL: " .. (msg or current_test))
        print("    Expected: " .. tostring(expected))
        print("    Actual: " .. tostring(actual))
        return false
    end
    return true
end
-- }}}

-- {{{ assert_true
local function assert_true(value, msg)
    if not value then
        print("  FAIL: " .. (msg or current_test))
        print("    Expected truthy value, got: " .. tostring(value))
        return false
    end
    return true
end
-- }}}

-- {{{ assert_false
local function assert_false(value, msg)
    if value then
        print("  FAIL: " .. (msg or current_test))
        print("    Expected falsy value, got: " .. tostring(value))
        return false
    end
    return true
end
-- }}}

-- {{{ assert_nil
local function assert_nil(value, msg)
    if value ~= nil then
        print("  FAIL: " .. (msg or current_test))
        print("    Expected nil, got: " .. tostring(value))
        return false
    end
    return true
end
-- }}}

-- {{{ Initialize systems once
professions.init()
recipes.init()
crafting.init()
-- }}}

-- {{{ run_test
local function run_test(name, fn)
    current_test = name
    tests_run = tests_run + 1

    -- Reset state before each test (keeps component registrations)
    ecs.reset()
    events.reset()
    professions.reset()
    recipes.reset()
    crafting.reset()

    local ok, err = pcall(fn)
    if ok then
        tests_passed = tests_passed + 1
        print("  PASS: " .. name)
    else
        print("  FAIL: " .. name)
        print("    Error: " .. tostring(err))
    end
end
-- }}}

-- ============================================================================
-- Test Helpers
-- ============================================================================

-- {{{ create_test_entity
local function create_test_entity()
    local entity = ecs.create_entity()
    ecs.add_component(entity, "professions")
    ecs.add_component(entity, "crafting_state")
    ecs.add_component(entity, "known_recipes")
    return entity
end
-- }}}

-- {{{ create_test_station
local function create_test_station(station_type, professions_list)
    local entity = ecs.create_entity()
    ecs.add_component(entity, "crafting_station")
    local station = ecs.get_component(entity, "crafting_station")
    rawset(station, "_initialized", true)
    rawset(station, "station_type", station_type or "forge")
    rawset(station, "professions_supported", professions_list or {"blacksmithing"})
    rawset(station, "skill_bonus", 0)
    rawset(station, "speed_bonus", 0)
    rawset(station, "requires_fuel", false)
    rawset(station, "fuel_remaining", 0)
    rawset(station, "in_use_by", nil)
    rawset(station, "queue", {})
    return entity
end
-- }}}

-- {{{ register_test_recipe
local function register_test_recipe(id, profession, skill_required)
    recipes.register({
        id = id or "test_recipe",
        profession = profession or "blacksmithing",
        skill_required = skill_required or 1,
        output = { item = "test_item", count = 1 },
        reagents = {{ item = "test_material", count = 1 }},
        cast_time = 0,  -- Instant for testing
    })
end
-- }}}

-- ============================================================================
-- Station Tests
-- ============================================================================

print("\n=== Station Tests ===")

-- {{{ test: station is available by default
run_test("station is available by default", function()
    local station = create_test_station()
    local available, err = crafting.is_station_available(station)
    assert_true(available, "Station should be available")
end)
-- }}}

-- {{{ test: station not available when in use
run_test("station not available when in use", function()
    local station = create_test_station()
    local comp = ecs.get_component(station, "crafting_station")
    rawset(comp, "in_use_by", 999)

    local available, err = crafting.is_station_available(station)
    assert_false(available, "Station should not be available")
    assert_eq(err, "Station in use")
end)
-- }}}

-- {{{ test: station needs fuel when fuel required
run_test("station needs fuel when fuel required", function()
    local station = create_test_station()
    local comp = ecs.get_component(station, "crafting_station")
    rawset(comp, "requires_fuel", true)
    rawset(comp, "fuel_remaining", 0)

    local available, err = crafting.is_station_available(station)
    assert_false(available, "Station should need fuel")
    assert_eq(err, "Station needs fuel")
end)
-- }}}

-- {{{ test: entity can use station
run_test("entity can use station", function()
    local entity = create_test_entity()
    local station = create_test_station()

    local ok = crafting.use_station(entity, station)
    assert_true(ok, "Should be able to use station")

    local state = crafting.get_craft_state(entity)
    assert_eq(state.station, station, "Station should be recorded")

    local station_comp = ecs.get_component(station, "crafting_station")
    assert_eq(station_comp.in_use_by, entity, "Station should track user")
end)
-- }}}

-- {{{ test: entity can leave station
run_test("entity can leave station", function()
    local entity = create_test_entity()
    local station = create_test_station()

    crafting.use_station(entity, station)
    local ok = crafting.leave_station(entity)
    assert_true(ok, "Should be able to leave station")

    local state = crafting.get_craft_state(entity)
    assert_nil(state.station, "Station should be cleared")

    local station_comp = ecs.get_component(station, "crafting_station")
    assert_nil(station_comp.in_use_by, "Station should be available")
end)
-- }}}

-- {{{ test: get station info
run_test("get station info", function()
    local station = create_test_station("forge", {"blacksmithing", "engineering"})

    local info = crafting.get_station_info(station)
    assert_eq(info.station_type, "forge")
    assert_eq(#info.professions, 2)
    assert_false(info.in_use)
end)
-- }}}

-- {{{ test: supports_profession works
run_test("supports_profession works", function()
    local station = create_test_station("forge", {"blacksmithing"})

    assert_true(crafting.supports_profession(station, "blacksmithing"))
    assert_false(crafting.supports_profession(station, "alchemy"))
end)
-- }}}

-- {{{ test: add fuel to station
run_test("add fuel to station", function()
    local station = create_test_station()
    local comp = ecs.get_component(station, "crafting_station")
    rawset(comp, "requires_fuel", true)
    rawset(comp, "fuel_remaining", 0)

    local new_fuel = crafting.add_fuel(station, 10)
    assert_eq(new_fuel, 10)
    assert_eq(comp.fuel_remaining, 10)
end)
-- }}}

-- ============================================================================
-- Crafting Flow Tests
-- ============================================================================

print("\n=== Crafting Flow Tests ===")

-- {{{ test: can_craft checks recipe knowledge
run_test("can_craft checks recipe knowledge", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "blacksmithing")
    register_test_recipe("iron_sword", "blacksmithing", 1)

    -- Don't know the recipe yet
    local can, err = crafting.can_craft(entity, "iron_sword")
    assert_false(can, "Should not be able to craft unknown recipe")
    assert_eq(err, "Recipe not known")

    -- Learn it
    recipes.learn(entity, "iron_sword")
    can, err = crafting.can_craft(entity, "iron_sword")
    assert_true(can, "Should be able to craft known recipe")
end)
-- }}}

-- {{{ test: can_craft checks profession
run_test("can_craft checks profession", function()
    local entity = create_test_entity()
    register_test_recipe("iron_sword", "blacksmithing", 1)
    recipes.learn(entity, "iron_sword")

    -- Don't have the profession
    local can, err = crafting.can_craft(entity, "iron_sword")
    assert_false(can, "Should not be able to craft without profession")
    assert_eq(err, "Profession not learned")
end)
-- }}}

-- {{{ test: can_craft checks skill level
run_test("can_craft checks skill level", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "blacksmithing")
    register_test_recipe("advanced_sword", "blacksmithing", 100)
    recipes.learn(entity, "advanced_sword")

    -- Skill too low (starts at 1)
    local can, err = crafting.can_craft(entity, "advanced_sword")
    assert_false(can, "Should not be able to craft with low skill")
    assert_eq(err, "Skill too low")

    -- Raise skill
    professions.add_skill(entity, "blacksmithing", 100)
    can, err = crafting.can_craft(entity, "advanced_sword")
    assert_true(can, "Should be able to craft with sufficient skill")
end)
-- }}}

-- {{{ test: start_craft with instant recipe
run_test("start_craft with instant recipe", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "blacksmithing")
    register_test_recipe("iron_sword", "blacksmithing", 1)
    recipes.learn(entity, "iron_sword")

    local ok, result = crafting.start_craft(entity, "iron_sword", 1)
    assert_true(ok, "Craft should start (and complete instantly)")

    -- For instant crafts, result is returned immediately
    if result then
        assert_eq(result.recipe, "iron_sword")
        assert_eq(result.quantity, 1)
    end
end)
-- }}}

-- {{{ test: cancel_craft works
run_test("cancel_craft works", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "blacksmithing")

    -- Register a recipe with cast time
    recipes.register({
        id = "slow_sword",
        profession = "blacksmithing",
        skill_required = 1,
        output = { item = "slow_sword", count = 1 },
        cast_time = 100,  -- Long cast time
    })
    recipes.learn(entity, "slow_sword")

    crafting.start_craft(entity, "slow_sword")
    local state = crafting.get_craft_state(entity)
    assert_eq(state.state, crafting.STATE.CRAFTING)

    local cancelled = crafting.cancel_craft(entity)
    assert_true(cancelled, "Should be able to cancel")

    state = crafting.get_craft_state(entity)
    assert_eq(state.state, crafting.STATE.IDLE)
    assert_nil(state.recipe)
end)
-- }}}

-- {{{ test: cannot start craft while already crafting
run_test("cannot start craft while already crafting", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "blacksmithing")

    recipes.register({
        id = "slow_sword",
        profession = "blacksmithing",
        skill_required = 1,
        output = { item = "slow_sword", count = 1 },
        cast_time = 100,
    })
    recipes.learn(entity, "slow_sword")

    crafting.start_craft(entity, "slow_sword")
    local ok, err = crafting.start_craft(entity, "slow_sword")
    assert_false(ok, "Should not be able to start another craft")
    assert_eq(err, "Already crafting")
end)
-- }}}

-- {{{ test: craft fires events
run_test("craft fires events", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "blacksmithing")
    register_test_recipe("iron_sword", "blacksmithing", 1)
    recipes.learn(entity, "iron_sword")

    local started = false
    local succeeded = false

    -- Create trigger objects (events system expects objects with fire method)
    local start_trigger = {
        events = {},
        fire = function(self, data)
            started = true
            assert_eq(data.entity, entity)
            assert_eq(data.recipe, "iron_sword")
        end,
    }

    local success_trigger = {
        events = {},
        fire = function(self, data)
            succeeded = true
            assert_eq(data.entity, entity)
            assert_eq(data.recipe, "iron_sword")
        end,
    }

    events.register(crafting.EVENT.CRAFT_START, start_trigger)
    events.register(crafting.EVENT.CRAFT_SUCCESS, success_trigger)

    crafting.start_craft(entity, "iron_sword")
    assert_true(started, "CRAFT_START should fire")
    assert_true(succeeded, "CRAFT_SUCCESS should fire")
end)
-- }}}

-- {{{ test: get_craft_state returns correct info
run_test("get_craft_state returns correct info", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "blacksmithing")

    recipes.register({
        id = "slow_sword",
        profession = "blacksmithing",
        skill_required = 1,
        output = { item = "slow_sword", count = 1 },
        cast_time = 100,
    })
    recipes.learn(entity, "slow_sword")

    local state = crafting.get_craft_state(entity)
    assert_eq(state.state, crafting.STATE.IDLE)

    crafting.start_craft(entity, "slow_sword", 5)
    state = crafting.get_craft_state(entity)
    assert_eq(state.state, crafting.STATE.CRAFTING)
    assert_eq(state.recipe, "slow_sword")
    assert_eq(state.quantity, 5)
end)
-- }}}

-- ============================================================================
-- Quality System Tests
-- ============================================================================

print("\n=== Quality System Tests ===")

-- {{{ test: quality disabled by default
run_test("quality disabled by default", function()
    assert_false(crafting.is_quality_enabled())
    local quality = crafting.calculate_quality(100, 50)
    assert_eq(quality, crafting.QUALITY.COMMON, "Quality should be common when disabled")
end)
-- }}}

-- {{{ test: quality can be enabled
run_test("quality can be enabled", function()
    crafting.set_quality_enabled(true)
    assert_true(crafting.is_quality_enabled())
end)
-- }}}

-- {{{ test: quality varies with skill
run_test("quality varies with skill", function()
    crafting.set_quality_enabled(true)

    -- With very low excess skill, should usually get common
    local common_count = 0
    for i = 1, 100 do
        local quality = crafting.calculate_quality(50, 50)  -- 0 excess
        if quality == crafting.QUALITY.COMMON then
            common_count = common_count + 1
        end
    end
    assert_true(common_count > 30, "Should get mostly common with no excess skill")

    -- With very high excess skill and luck, should get higher quality
    local high_quality_count = 0
    for i = 1, 100 do
        local quality = crafting.calculate_quality(200, 50, 0.5)  -- 150 excess + luck
        if quality > crafting.QUALITY.COMMON then
            high_quality_count = high_quality_count + 1
        end
    end
    assert_true(high_quality_count > 50, "Should get more high quality with excess skill")
end)
-- }}}

-- {{{ test: quality names exist
run_test("quality names exist", function()
    assert_eq(crafting.QUALITY_NAMES[0], "Poor")
    assert_eq(crafting.QUALITY_NAMES[1], "Common")
    assert_eq(crafting.QUALITY_NAMES[2], "Uncommon")
    assert_eq(crafting.QUALITY_NAMES[3], "Rare")
    assert_eq(crafting.QUALITY_NAMES[4], "Epic")
end)
-- }}}

-- ============================================================================
-- Integration Tests
-- ============================================================================

print("\n=== Integration Tests ===")

-- {{{ test: craft records statistics
run_test("craft records statistics", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "blacksmithing")
    register_test_recipe("iron_sword", "blacksmithing", 1)
    recipes.learn(entity, "iron_sword")

    assert_eq(recipes.get_craft_count(entity, "iron_sword"), 0)

    crafting.start_craft(entity, "iron_sword")
    assert_eq(recipes.get_craft_count(entity, "iron_sword"), 1)

    crafting.start_craft(entity, "iron_sword")
    assert_eq(recipes.get_craft_count(entity, "iron_sword"), 2)
end)
-- }}}

-- {{{ test: craft attempts skill up
run_test("craft attempts skill up", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "blacksmithing")
    register_test_recipe("iron_sword", "blacksmithing", 1)
    recipes.learn(entity, "iron_sword")

    local initial_skill = professions.get_skill(entity, "blacksmithing")

    -- Craft many times - orange recipe should always skill up
    for i = 1, 10 do
        crafting.start_craft(entity, "iron_sword")
    end

    local final_skill = professions.get_skill(entity, "blacksmithing")
    assert_true(final_skill > initial_skill, "Skill should increase from crafting")
end)
-- }}}

-- {{{ test: get_craftable_recipes filters correctly
run_test("get_craftable_recipes filters correctly", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "blacksmithing")

    -- Register multiple recipes
    register_test_recipe("iron_sword", "blacksmithing", 1)
    register_test_recipe("steel_sword", "blacksmithing", 100)

    recipes.register({
        id = "health_potion",
        profession = "alchemy",
        skill_required = 1,
        output = { item = "health_potion", count = 1 },
    })

    -- Learn them all
    recipes.learn(entity, "iron_sword")
    recipes.learn(entity, "steel_sword")

    -- Can only craft iron_sword (skill 1, steel_sword needs 100)
    local craftable = crafting.get_craftable_recipes(entity, "blacksmithing")
    assert_eq(#craftable, 1)
    assert_eq(craftable[1], "iron_sword")

    -- After raising skill, can craft both
    professions.add_skill(entity, "blacksmithing", 100)
    craftable = crafting.get_craftable_recipes(entity, "blacksmithing")
    assert_eq(#craftable, 2)
end)
-- }}}

-- {{{ test: crafting at station with bonuses
run_test("crafting at station with speed bonus", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "blacksmithing")

    local station = create_test_station()
    local station_comp = ecs.get_component(station, "crafting_station")
    rawset(station_comp, "speed_bonus", 50)  -- 50% faster

    recipes.register({
        id = "slow_sword",
        profession = "blacksmithing",
        skill_required = 1,
        output = { item = "slow_sword", count = 1 },
        cast_time = 10,
    })
    recipes.learn(entity, "slow_sword")

    crafting.use_station(entity, station)
    crafting.start_craft(entity, "slow_sword")

    local state = crafting.get_craft_state(entity)
    -- With 50% speed bonus, 10s cast becomes 5s
    assert_eq(state.time_total, 5, "Cast time should be reduced by station bonus")
end)
-- }}}

-- {{{ test: station requirement enforced
run_test("station requirement enforced", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "blacksmithing")

    recipes.register({
        id = "forged_sword",
        profession = "blacksmithing",
        skill_required = 1,
        output = { item = "forged_sword", count = 1 },
        station = "forge",
    })
    recipes.learn(entity, "forged_sword")

    -- Can't craft without station
    local can, err = crafting.can_craft(entity, "forged_sword")
    assert_false(can)
    assert_true(err:find("Requires crafting station"))

    -- Use a forge
    local station = create_test_station("forge")
    crafting.use_station(entity, station)

    can, err = crafting.can_craft(entity, "forged_sword", station)
    assert_true(can, "Should be able to craft with correct station")
end)
-- }}}

-- {{{ test: wrong station type rejected
run_test("wrong station type rejected", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "blacksmithing")

    recipes.register({
        id = "forged_sword",
        profession = "blacksmithing",
        skill_required = 1,
        output = { item = "forged_sword", count = 1 },
        station = "forge",
    })
    recipes.learn(entity, "forged_sword")

    -- Use an alchemy lab instead of forge
    local station = create_test_station("alchemy_lab")
    crafting.use_station(entity, station)

    local can, err = crafting.can_craft(entity, "forged_sword", station)
    assert_false(can)
    assert_eq(err, "Wrong station type")
end)
-- }}}

-- ============================================================================
-- Profession Definition Tests
-- ============================================================================

print("\n=== Profession Definition Tests ===")

-- {{{ test: profession definitions exist
run_test("profession definitions exist", function()
    assert_true(crafting.PROFESSION_DEFS.blacksmithing ~= nil)
    assert_true(crafting.PROFESSION_DEFS.alchemy ~= nil)
    assert_true(crafting.PROFESSION_DEFS.engineering ~= nil)
    assert_true(crafting.PROFESSION_DEFS.cooking ~= nil)
end)
-- }}}

-- {{{ test: get_profession_def returns correct data
run_test("get_profession_def returns correct data", function()
    local bs = crafting.get_profession_def("blacksmithing")
    assert_eq(bs.id, "blacksmithing")
    assert_eq(bs.name, "Blacksmithing")
    assert_eq(bs.type, "crafting")
    assert_eq(#bs.stations, 2)  -- forge and anvil
end)
-- }}}

-- {{{ test: profession has specializations
run_test("profession has specializations", function()
    local bs = crafting.get_profession_def("blacksmithing")
    assert_true(#bs.specializations >= 2)
    assert_eq(bs.specializations[1].id, "armorsmith")
    assert_eq(bs.specializations[2].id, "weaponsmith")
end)
-- }}}

-- ============================================================================
-- Summary
-- ============================================================================

print("\n=== Test Summary ===")
print(string.format("Passed: %d / %d", tests_passed, tests_run))

if tests_passed == tests_run then
    print("All tests passed!")
    os.exit(0)
else
    print("Some tests failed.")
    os.exit(1)
end

#!/usr/bin/env lua
-- Profession System Unit Tests (Issue 702a)
-- Tests for profession component, skill tracking, and configuration modes.
-- Run with: lua src/tests/test_professions.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local entity = require("runtime.ecs.entity")
local component = require("runtime.ecs.component")
local ecs = require("runtime.ecs")
local professions = require("runtime.systems.professions")

-- {{{ Test utilities
local test_count = 0
local pass_count = 0

local function test(name, fn)
    test_count = test_count + 1
    local ok, err = pcall(fn)
    if ok then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name)
        print("         " .. tostring(err))
    end
end

local function assert_eq(actual, expected, msg)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s",
            msg or "Assertion failed",
            tostring(expected),
            tostring(actual)))
    end
end

local function assert_true(value, msg)
    if not value then
        error(msg or "Expected true")
    end
end

local function assert_false(value, msg)
    if value then
        error(msg or "Expected false")
    end
end

local function assert_nil(value, msg)
    if value ~= nil then
        error(string.format("%s: expected nil, got %s",
            msg or "Assertion failed", tostring(value)))
    end
end

local function assert_not_nil(value, msg)
    if value == nil then
        error(msg or "Expected non-nil")
    end
end

local function test_section(name)
    print("\n=== " .. name .. " ===")
end

local function reset_all()
    -- Reset ECS state
    entity.reset()
    if entity.clear_hooks then entity.clear_hooks() end
    component.clear_all()
    component.init(true)

    -- Reset professions state
    professions.reset()
    professions.init()
end
-- }}}

-- {{{ Configuration Tests
test_section("Configuration Modes")

test("default mode is WoW", function()
    reset_all()
    assert_eq(professions.get_mode(), "wow")
end)

test("can switch to WC3 mode", function()
    reset_all()
    professions.set_mode(professions.MODE.WC3)
    assert_eq(professions.get_mode(), "wc3")
end)

test("can switch to custom mode", function()
    reset_all()
    professions.set_config({max_primary_slots = 5})
    professions.set_mode(professions.MODE.CUSTOM)
    assert_eq(professions.get_mode(), "custom")
    assert_eq(professions.get_config().max_primary_slots, 5)
end)

test("WoW config has 2 primary slots", function()
    reset_all()
    professions.set_mode(professions.MODE.WOW)
    assert_eq(professions.get_config().max_primary_slots, 2)
end)

test("WC3 config has unlimited primary slots", function()
    reset_all()
    professions.set_mode(professions.MODE.WC3)
    assert_eq(professions.get_config().max_primary_slots, 0)
end)
-- }}}

-- {{{ Learn/Forget Profession Tests
test_section("Learn/Forget Professions")

test("can learn primary profession", function()
    reset_all()
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    local ok, err = professions.learn_profession(ent, "mining", professions.TYPE.PRIMARY)
    assert_true(ok, err)
    assert_true(professions.has_profession(ent, "mining"))
end)

test("can learn secondary profession", function()
    reset_all()
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    local ok = professions.learn_profession(ent, "cooking", professions.TYPE.SECONDARY)
    assert_true(ok)
    assert_true(professions.has_profession(ent, "cooking"))
end)

test("cannot learn same profession twice", function()
    reset_all()
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    professions.learn_profession(ent, "mining")
    local ok, err = professions.learn_profession(ent, "mining")
    assert_false(ok)
    assert_eq(err, "Already knows this profession")
end)

test("WoW mode limits primary professions to 2", function()
    reset_all()
    professions.set_mode(professions.MODE.WOW)

    local ent = entity.create()
    ecs.add_component(ent, "professions")

    local ok1 = professions.learn_profession(ent, "mining", professions.TYPE.PRIMARY)
    assert_true(ok1, "First profession should succeed")

    local ok2 = professions.learn_profession(ent, "blacksmithing", professions.TYPE.PRIMARY)
    assert_true(ok2, "Second profession should succeed")

    local ok3, err = professions.learn_profession(ent, "herbalism", professions.TYPE.PRIMARY)
    assert_false(ok3, "Third profession should fail")
    assert_eq(err, "No available primary profession slots")
end)

test("WC3 mode allows unlimited primary professions", function()
    reset_all()
    professions.set_mode(professions.MODE.WC3)
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    for i = 1, 5 do
        local ok = professions.learn_profession(ent, "prof_" .. i, professions.TYPE.PRIMARY)
        assert_true(ok, "Failed to learn profession " .. i)
    end
end)

test("can forget a profession", function()
    reset_all()
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    professions.learn_profession(ent, "mining")
    assert_true(professions.has_profession(ent, "mining"))

    local ok = professions.forget_profession(ent, "mining")
    assert_true(ok)
    assert_false(professions.has_profession(ent, "mining"))
end)

test("forgetting profession frees slot", function()
    reset_all()
    professions.set_mode(professions.MODE.WOW)
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    professions.learn_profession(ent, "mining", professions.TYPE.PRIMARY)
    professions.learn_profession(ent, "blacksmithing", professions.TYPE.PRIMARY)

    -- Both slots used
    local ok_before, err_before = professions.learn_profession(ent, "herbalism", professions.TYPE.PRIMARY)
    assert_false(ok_before, "Should not be able to learn 3rd profession")

    -- Forget one
    professions.forget_profession(ent, "mining")

    -- Now we should be able to learn a new one
    local ok_after = professions.learn_profession(ent, "herbalism", professions.TYPE.PRIMARY)
    assert_true(ok_after, "Should be able to learn after forgetting one")
end)
-- }}}

-- {{{ Skill Level Tests
test_section("Skill Levels")

test("new profession starts at skill 1", function()
    reset_all()
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    professions.learn_profession(ent, "mining")
    assert_eq(professions.get_skill(ent, "mining"), 1)
end)

test("new profession has initial skill cap", function()
    reset_all()
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    professions.learn_profession(ent, "mining")
    assert_eq(professions.get_max_skill(ent, "mining"), 75)  -- WoW first cap
end)

test("can add skill points", function()
    reset_all()
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    professions.learn_profession(ent, "mining")
    professions.add_skill(ent, "mining", 10)
    assert_eq(professions.get_skill(ent, "mining"), 11)  -- 1 + 10
end)

test("skill clamped to cap", function()
    reset_all()
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    professions.learn_profession(ent, "mining")
    professions.add_skill(ent, "mining", 100)  -- Try to go above cap
    assert_eq(professions.get_skill(ent, "mining"), 75)  -- Capped at 75
end)

test("skill clamped to minimum", function()
    reset_all()
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    professions.learn_profession(ent, "mining")
    professions.add_skill(ent, "mining", 10)
    professions.add_skill(ent, "mining", -100)  -- Try to go negative
    assert_eq(professions.get_skill(ent, "mining"), 1)  -- Clamped to min
end)

test("can raise skill cap", function()
    reset_all()
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    professions.learn_profession(ent, "mining")
    professions.set_skill_cap(ent, "mining", 150)
    assert_eq(professions.get_max_skill(ent, "mining"), 150)

    -- Now can skill past 75
    professions.add_skill(ent, "mining", 100)
    assert_eq(professions.get_skill(ent, "mining"), 101)
end)
-- }}}

-- {{{ Skillup Chance Tests
test_section("Skillup Chance (WoW Mode)")

test("orange difficulty: 100% chance", function()
    reset_all()
    professions.set_mode(professions.MODE.WOW)
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    professions.learn_profession(ent, "mining")
    -- Skill 1, recipe requires 1 → diff = 0 → orange
    local chance = professions.get_skillup_chance(ent, "mining", 1)
    assert_eq(chance, 1.0)
end)

test("yellow difficulty: 75% chance", function()
    reset_all()
    professions.set_mode(professions.MODE.WOW)
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    professions.learn_profession(ent, "mining")
    professions.add_skill(ent, "mining", 14)  -- Now at skill 15
    -- Skill 15, recipe requires 1 → diff = 14 → yellow (10-24)
    local chance = professions.get_skillup_chance(ent, "mining", 1)
    assert_eq(chance, 0.75)
end)

test("green difficulty: 25% chance", function()
    reset_all()
    professions.set_mode(professions.MODE.WOW)
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    professions.learn_profession(ent, "mining")
    professions.add_skill(ent, "mining", 29)  -- Now at skill 30
    -- Skill 30, recipe requires 1 → diff = 29 → green (25-49)
    local chance = professions.get_skillup_chance(ent, "mining", 1)
    assert_eq(chance, 0.25)
end)

test("gray difficulty: 0% chance", function()
    reset_all()
    professions.set_mode(professions.MODE.WOW)
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    professions.learn_profession(ent, "mining")
    professions.add_skill(ent, "mining", 74)  -- Now at skill 75 (cap)
    -- Skill 75, recipe requires 1 → diff = 74 → gray (50+)
    local chance = professions.get_skillup_chance(ent, "mining", 1)
    assert_eq(chance, 0.0)
end)

test("WC3 mode: always 100% chance", function()
    reset_all()
    professions.set_mode(professions.MODE.WC3)
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    professions.learn_profession(ent, "mining")
    -- Even at any skill, WC3 mode always returns 100%
    local chance = professions.get_skillup_chance(ent, "mining", 1)
    assert_eq(chance, 1.0)
end)
-- }}}

-- {{{ try_skillup Tests
test_section("try_skillup")

test("try_skillup can increase skill", function()
    reset_all()
    professions.set_mode(professions.MODE.WOW)
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    professions.learn_profession(ent, "mining")
    -- Orange difficulty = 100% chance
    local skilled = professions.try_skillup(ent, "mining", 1)
    assert_true(skilled)
    assert_eq(professions.get_skill(ent, "mining"), 2)
end)

test("try_skillup respects skill cap", function()
    reset_all()
    professions.set_mode(professions.MODE.WOW)
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    professions.learn_profession(ent, "mining")
    professions.add_skill(ent, "mining", 74)  -- At cap (75)

    local skilled = professions.try_skillup(ent, "mining", 75)
    assert_false(skilled)  -- Already at cap
    assert_eq(professions.get_skill(ent, "mining"), 75)
end)

test("try_skillup fails for unknown profession", function()
    reset_all()
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    local skilled = professions.try_skillup(ent, "unknown", 1)
    assert_false(skilled)
end)
-- }}}

-- {{{ Recipe Tests
test_section("Recipes")

test("can learn recipe", function()
    reset_all()
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    professions.learn_profession(ent, "blacksmithing")
    professions.learn_recipe(ent, "blacksmithing", "copper_sword")

    assert_true(professions.knows_recipe(ent, "blacksmithing", "copper_sword"))
end)

test("get_known_recipes returns all recipes", function()
    reset_all()
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    professions.learn_profession(ent, "blacksmithing")
    professions.learn_recipe(ent, "blacksmithing", "copper_sword")
    professions.learn_recipe(ent, "blacksmithing", "bronze_axe")

    local recipes = professions.get_known_recipes(ent, "blacksmithing")
    assert_eq(#recipes, 2)
end)

test("learning same recipe twice is idempotent", function()
    reset_all()
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    professions.learn_profession(ent, "blacksmithing")
    professions.learn_recipe(ent, "blacksmithing", "copper_sword")
    professions.learn_recipe(ent, "blacksmithing", "copper_sword")

    local recipes = professions.get_known_recipes(ent, "blacksmithing")
    assert_eq(#recipes, 1)
end)
-- }}}

-- {{{ Specialization Tests
test_section("Specializations")

test("can set specialization", function()
    reset_all()
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    professions.learn_profession(ent, "blacksmithing")
    professions.set_specialization(ent, "blacksmithing", "armorsmith")

    assert_eq(professions.get_specialization(ent, "blacksmithing"), "armorsmith")
end)

test("specialization starts as nil", function()
    reset_all()
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    professions.learn_profession(ent, "blacksmithing")
    assert_nil(professions.get_specialization(ent, "blacksmithing"))
end)
-- }}}

-- {{{ Experience System Tests (WC3 Mode)
test_section("Experience System (WC3 Mode)")

test("can add experience", function()
    reset_all()
    professions.set_mode(professions.MODE.WC3)
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    professions.learn_profession(ent, "mining")
    professions.add_experience(ent, "mining", 50)

    assert_eq(professions.get_experience(ent, "mining"), 50)
end)

test("experience causes level up at threshold", function()
    reset_all()
    professions.set_mode(professions.MODE.WC3)
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    professions.learn_profession(ent, "mining")
    local xp, levels = professions.add_experience(ent, "mining", 100)  -- XP per level = 100

    assert_eq(levels, 1)
    assert_eq(professions.get_skill(ent, "mining"), 2)
    assert_eq(xp, 0)  -- XP reset after level
end)

test("excess experience carries over", function()
    reset_all()
    professions.set_mode(professions.MODE.WC3)
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    professions.learn_profession(ent, "mining")
    local xp, levels = professions.add_experience(ent, "mining", 150)

    assert_eq(levels, 1)
    assert_eq(xp, 50)  -- 150 - 100 = 50 leftover
end)

test("multiple level ups from large XP gain", function()
    reset_all()
    professions.set_mode(professions.MODE.WC3)
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    professions.learn_profession(ent, "mining")
    local xp, levels = professions.add_experience(ent, "mining", 350)

    assert_eq(levels, 3)
    assert_eq(professions.get_skill(ent, "mining"), 4)
    assert_eq(xp, 50)  -- 350 - 300 = 50
end)
-- }}}

-- {{{ Active Profession Tests
test_section("Active Profession")

test("can set active profession", function()
    reset_all()
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    professions.learn_profession(ent, "mining")
    professions.set_active(ent, "mining")

    assert_eq(professions.get_active(ent), "mining")
end)

test("cannot set active to unknown profession", function()
    reset_all()
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    local ok = professions.set_active(ent, "unknown")
    assert_false(ok)
end)

test("can clear active profession", function()
    reset_all()
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    professions.learn_profession(ent, "mining")
    professions.set_active(ent, "mining")
    professions.set_active(ent, nil)

    assert_nil(professions.get_active(ent))
end)
-- }}}

-- {{{ Query Tests
test_section("Query Functions")

test("get_all_professions returns both types", function()
    reset_all()
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    professions.learn_profession(ent, "mining", professions.TYPE.PRIMARY)
    professions.learn_profession(ent, "cooking", professions.TYPE.SECONDARY)

    local all = professions.get_all_professions(ent)
    assert_eq(#all.primary, 1)
    assert_eq(#all.secondary, 1)
end)

test("get_skill returns nil for unknown profession", function()
    reset_all()
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    assert_nil(professions.get_skill(ent, "unknown"))
end)

test("has_profession returns false for unknown", function()
    reset_all()
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    assert_false(professions.has_profession(ent, "unknown"))
end)

test("get_difficulty returns correct colors", function()
    reset_all()
    professions.set_mode(professions.MODE.WOW)
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    professions.learn_profession(ent, "mining")

    -- Skill 1, recipe 1 → diff 0 → orange
    assert_eq(professions.get_difficulty(ent, "mining", 1), professions.DIFFICULTY.ORANGE)

    professions.add_skill(ent, "mining", 14)  -- Skill 15
    -- Skill 15, recipe 1 → diff 14 → yellow
    assert_eq(professions.get_difficulty(ent, "mining", 1), professions.DIFFICULTY.YELLOW)

    professions.add_skill(ent, "mining", 15)  -- Skill 30
    -- Skill 30, recipe 1 → diff 29 → green
    assert_eq(professions.get_difficulty(ent, "mining", 1), professions.DIFFICULTY.GREEN)

    professions.add_skill(ent, "mining", 45)  -- Skill 75 (cap)
    -- Skill 75, recipe 1 → diff 74 → gray
    assert_eq(professions.get_difficulty(ent, "mining", 1), professions.DIFFICULTY.GRAY)
end)
-- }}}

-- {{{ Registry Tests
test_section("Profession Type Registry")

test("default professions are registered on init", function()
    reset_all()
    assert_true(professions.is_type_registered("mining"))
    assert_true(professions.is_type_registered("blacksmithing"))
    assert_true(professions.is_type_registered("cooking"))
end)

test("can get profession type definition", function()
    reset_all()
    local mining_def = professions.get_type("mining")
    assert_not_nil(mining_def)
    assert_eq(mining_def.id, "mining")
    assert_eq(mining_def.name, "Mining")
    assert_eq(mining_def.type, "primary")
end)

test("can register custom profession type", function()
    reset_all()
    professions.register_type({
        id = "custom_craft",
        name = "Custom Craft",
        type = "primary",
        description = "A custom profession",
    })
    assert_true(professions.is_type_registered("custom_craft"))
    local def = professions.get_type("custom_craft")
    assert_eq(def.description, "A custom profession")
end)

test("get_all_types returns all registered professions", function()
    reset_all()
    local all_types = professions.get_all_types()
    -- Should have at least the default professions
    local count = 0
    for _ in pairs(all_types) do count = count + 1 end
    assert_true(count >= 10, "Should have at least 10 default professions")
end)

test("get_types_by_category filters correctly", function()
    reset_all()
    local primary = professions.get_types_by_category("primary")
    local secondary = professions.get_types_by_category("secondary")

    -- All returned professions should match the category
    for _, def in ipairs(primary) do
        assert_eq(def.type, "primary")
    end
    for _, def in ipairs(secondary) do
        assert_eq(def.type, "secondary")
    end
end)

test("clear_registry removes all types", function()
    reset_all()
    professions.clear_registry()
    assert_false(professions.is_type_registered("mining"))
    local all = professions.get_all_types()
    local count = 0
    for _ in pairs(all) do count = count + 1 end
    assert_eq(count, 0)
end)

test("reset re-registers default professions", function()
    reset_all()
    professions.clear_registry()
    assert_false(professions.is_type_registered("mining"))
    professions.reset()
    assert_true(professions.is_type_registered("mining"))
end)
-- }}}

-- {{{ Cooldown Tests
test_section("Cooldown System")

test("cooldown starts at 0 for new profession", function()
    reset_all()
    local ent = entity.create()
    ecs.add_component(ent, "professions")
    professions.learn_profession(ent, "alchemy")

    assert_eq(professions.get_cooldown_remaining(ent, "alchemy", "transmute"), 0)
    assert_true(professions.is_cooldown_ready(ent, "alchemy", "transmute"))
end)

test("can set cooldown", function()
    reset_all()
    local ent = entity.create()
    ecs.add_component(ent, "professions")
    professions.learn_profession(ent, "alchemy")

    local ok = professions.set_cooldown(ent, "alchemy", "transmute", 3600)  -- 1 hour
    assert_true(ok)
    assert_false(professions.is_cooldown_ready(ent, "alchemy", "transmute"))
end)

test("get_cooldown_remaining returns correct time", function()
    reset_all()
    local ent = entity.create()
    ecs.add_component(ent, "professions")
    professions.learn_profession(ent, "alchemy")

    professions.set_cooldown(ent, "alchemy", "transmute", 3600)
    local remaining = professions.get_cooldown_remaining(ent, "alchemy", "transmute")
    -- Should be roughly 3600 (may be slightly less due to os.time() resolution)
    assert_true(remaining >= 3599 and remaining <= 3600, "Remaining should be ~3600")
end)

test("can clear cooldown", function()
    reset_all()
    local ent = entity.create()
    ecs.add_component(ent, "professions")
    professions.learn_profession(ent, "alchemy")

    professions.set_cooldown(ent, "alchemy", "transmute", 3600)
    assert_false(professions.is_cooldown_ready(ent, "alchemy", "transmute"))

    professions.clear_cooldown(ent, "alchemy", "transmute")
    assert_true(professions.is_cooldown_ready(ent, "alchemy", "transmute"))
end)

test("get_all_cooldowns returns active cooldowns", function()
    reset_all()
    local ent = entity.create()
    ecs.add_component(ent, "professions")
    professions.learn_profession(ent, "alchemy")

    professions.set_cooldown(ent, "alchemy", "transmute", 3600)
    professions.set_cooldown(ent, "alchemy", "daily_craft", 86400)

    local cooldowns = professions.get_all_cooldowns(ent, "alchemy")
    assert_not_nil(cooldowns.transmute)
    assert_not_nil(cooldowns.daily_craft)
end)

test("cooldown returns 0 for unknown profession", function()
    reset_all()
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    assert_eq(professions.get_cooldown_remaining(ent, "unknown", "test"), 0)
    assert_true(professions.is_cooldown_ready(ent, "unknown", "test"))
end)

test("set_cooldown fails for unknown profession", function()
    reset_all()
    local ent = entity.create()
    ecs.add_component(ent, "professions")

    local ok = professions.set_cooldown(ent, "unknown", "test", 100)
    assert_false(ok)
end)

test("multiple professions have independent cooldowns", function()
    reset_all()
    local ent = entity.create()
    ecs.add_component(ent, "professions")
    professions.learn_profession(ent, "alchemy")
    professions.learn_profession(ent, "blacksmithing")

    professions.set_cooldown(ent, "alchemy", "transmute", 3600)
    -- Blacksmithing should not have this cooldown
    assert_true(professions.is_cooldown_ready(ent, "blacksmithing", "transmute"))
    assert_false(professions.is_cooldown_ready(ent, "alchemy", "transmute"))
end)
-- }}}

-- {{{ Test Summary
print("\n=== Test Summary ===")
print(string.format("Passed: %d", pass_count))
print(string.format("Failed: %d", test_count - pass_count))
print(string.format("Total: %d", test_count))

if pass_count == test_count then
    print("All tests PASSED!")
    os.exit(0)
else
    print("Some tests FAILED!")
    os.exit(1)
end
-- }}}

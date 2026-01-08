#!/usr/bin/env lua
-- Recipe System Unit Tests (Issue 702d)
-- Tests for recipe registration, learning, difficulty, and queries.
-- Run with: lua src/tests/test_recipes.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local entity = require("runtime.ecs.entity")
local component = require("runtime.ecs.component")
local ecs = require("runtime.ecs")
local recipes = require("runtime.systems.recipes")
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

    -- Reset systems
    professions.reset()
    professions.init()
    recipes.reset()
    recipes.init()
end
-- }}}

-- {{{ Sample recipes for testing
local function register_test_recipes()
    recipes.register({
        id = "copper_bar",
        name = "Copper Bar",
        profession = "mining",
        category = recipes.CATEGORY.SMELT,
        skill_required = 1,
        reagents = {{ item = "copper_ore", count = 2 }},
        output = { item = "copper_bar", count = 1 },
    })

    recipes.register({
        id = "copper_sword",
        name = "Copper Sword",
        profession = "blacksmithing",
        category = recipes.CATEGORY.WEAPON,
        skill_required = 25,
        skill_difficulty = { orange = 25, yellow = 40, green = 55, gray = 70 },
        reagents = {
            { item = "copper_bar", count = 6 },
            { item = "weak_flux", count = 1 },
        },
        output = { item = "copper_sword", count = 1 },
    })

    recipes.register({
        id = "iron_sword",
        name = "Iron Sword",
        profession = "blacksmithing",
        category = recipes.CATEGORY.WEAPON,
        skill_required = 100,
        reagents = {
            { item = "iron_bar", count = 4 },
            { item = "coal", count = 2 },
        },
        output = { item = "iron_sword", count = 1 },
    })

    recipes.register({
        id = "health_potion",
        name = "Minor Health Potion",
        profession = "alchemy",
        category = recipes.CATEGORY.CONSUMABLE,
        skill_required = 1,
        reagents = {
            { item = "peacebloom", count = 1 },
            { item = "silverleaf", count = 1 },
        },
        output = { item = "minor_health_potion", count = 1 },
    })
end
-- }}}

-- {{{ Registration Tests
test_section("Recipe Registration")

test("can register a recipe", function()
    reset_all()
    local ok = recipes.register({
        id = "test_recipe",
        profession = "blacksmithing",
        output = { item = "test_item" },
    })
    assert_true(ok)
    assert_not_nil(recipes.get("test_recipe"))
end)

test("register applies defaults", function()
    reset_all()
    recipes.register({
        id = "test_recipe",
        profession = "blacksmithing",
        output = { item = "test_item" },
    })
    local r = recipes.get("test_recipe")
    assert_eq(r.name, "test_recipe")  -- Defaults to ID
    assert_eq(r.skill_required, 1)
    assert_not_nil(r.skill_difficulty)
    assert_eq(r.output.count, 1)
end)

test("register fails without id", function()
    reset_all()
    local ok, err = recipes.register({
        profession = "blacksmithing",
        output = { item = "test_item" },
    })
    assert_false(ok)
    assert_true(err:find("id"))
end)

test("register fails without profession", function()
    reset_all()
    local ok, err = recipes.register({
        id = "test",
        output = { item = "test_item" },
    })
    assert_false(ok)
    assert_true(err:find("profession"))
end)

test("register fails without output", function()
    reset_all()
    local ok, err = recipes.register({
        id = "test",
        profession = "blacksmithing",
    })
    assert_false(ok)
    assert_true(err:find("output"))
end)

test("can unregister a recipe", function()
    reset_all()
    recipes.register({
        id = "test",
        profession = "blacksmithing",
        output = { item = "test" },
    })
    assert_not_nil(recipes.get("test"))
    local ok = recipes.unregister("test")
    assert_true(ok)
    assert_nil(recipes.get("test"))
end)

test("register_bulk registers multiple recipes", function()
    reset_all()
    local registered, failed = recipes.register_bulk({
        { id = "r1", profession = "blacksmithing", output = { item = "i1" } },
        { id = "r2", profession = "blacksmithing", output = { item = "i2" } },
        { id = "r3", profession = "blacksmithing", output = { item = "i3" } },
    })
    assert_eq(registered, 3)
    assert_eq(failed, 0)
end)
-- }}}

-- {{{ Query Tests
test_section("Recipe Queries")

test("get returns recipe by ID", function()
    reset_all()
    register_test_recipes()
    local r = recipes.get("copper_sword")
    assert_not_nil(r)
    assert_eq(r.id, "copper_sword")
    assert_eq(r.profession, "blacksmithing")
end)

test("get returns nil for unknown recipe", function()
    reset_all()
    assert_nil(recipes.get("nonexistent"))
end)

test("get_all returns all recipes", function()
    reset_all()
    register_test_recipes()
    local all = recipes.get_all()
    local count = 0
    for _ in pairs(all) do count = count + 1 end
    assert_eq(count, 4)
end)

test("get_all_for_profession filters correctly", function()
    reset_all()
    register_test_recipes()
    local bs_recipes = recipes.get_all_for_profession("blacksmithing")
    assert_eq(#bs_recipes, 2)
    for _, r in ipairs(bs_recipes) do
        assert_eq(r.profession, "blacksmithing")
    end
end)

test("get_learnable_at_skill filters by skill", function()
    reset_all()
    register_test_recipes()
    -- At skill 50, can learn copper_sword (25) but not iron_sword (100)
    local learnable = recipes.get_learnable_at_skill("blacksmithing", 50)
    assert_eq(#learnable, 1)
    assert_eq(learnable[1].id, "copper_sword")
end)

test("get_by_output finds recipes by item", function()
    reset_all()
    register_test_recipes()
    local r = recipes.get_by_output("copper_bar")
    assert_eq(#r, 1)
    assert_eq(r[1].id, "copper_bar")
end)

test("get_by_category filters correctly", function()
    reset_all()
    register_test_recipes()
    local weapons = recipes.get_by_category(recipes.CATEGORY.WEAPON)
    assert_eq(#weapons, 2)
end)

test("search with custom filter", function()
    reset_all()
    register_test_recipes()
    local results = recipes.search(function(r)
        return r.skill_required >= 25
    end)
    assert_eq(#results, 2)  -- copper_sword (25) and iron_sword (100)
end)
-- }}}

-- {{{ Difficulty Tests
test_section("Skill Difficulty")

test("red when skill below requirement", function()
    reset_all()
    register_test_recipes()
    -- copper_sword requires 25
    local color = recipes.get_difficulty_color(10, "copper_sword")
    assert_eq(color, recipes.DIFFICULTY.RED)
end)

test("orange when at requirement", function()
    reset_all()
    register_test_recipes()
    -- copper_sword: orange at 25
    local color = recipes.get_difficulty_color(25, "copper_sword")
    assert_eq(color, recipes.DIFFICULTY.ORANGE)
end)

test("yellow in middle range", function()
    reset_all()
    register_test_recipes()
    -- copper_sword: yellow 40-54
    local color = recipes.get_difficulty_color(45, "copper_sword")
    assert_eq(color, recipes.DIFFICULTY.YELLOW)
end)

test("green approaching gray", function()
    reset_all()
    register_test_recipes()
    -- copper_sword: green 55-69
    local color = recipes.get_difficulty_color(60, "copper_sword")
    assert_eq(color, recipes.DIFFICULTY.GREEN)
end)

test("gray when skill high", function()
    reset_all()
    register_test_recipes()
    -- copper_sword: gray at 70+
    local color = recipes.get_difficulty_color(100, "copper_sword")
    assert_eq(color, recipes.DIFFICULTY.GRAY)
end)

test("skillup chance matches difficulty", function()
    reset_all()
    register_test_recipes()
    assert_eq(recipes.get_skillup_chance(10, "copper_sword"), 0)      -- red
    assert_eq(recipes.get_skillup_chance(25, "copper_sword"), 1.0)    -- orange
    assert_eq(recipes.get_skillup_chance(45, "copper_sword"), 0.75)   -- yellow
    assert_eq(recipes.get_skillup_chance(60, "copper_sword"), 0.25)   -- green
    assert_eq(recipes.get_skillup_chance(100, "copper_sword"), 0)     -- gray
end)

test("difficulty returns nil for unknown recipe", function()
    reset_all()
    assert_nil(recipes.get_difficulty_color(50, "nonexistent"))
end)
-- }}}

-- {{{ Entity Recipe Tests
test_section("Entity Recipe Learning")

test("can learn a recipe", function()
    reset_all()
    register_test_recipes()
    local ent = entity.create()
    ecs.add_component(ent, "known_recipes")
    ecs.add_component(ent, "professions")
    professions.learn_profession(ent, "blacksmithing")

    local ok = recipes.learn(ent, "copper_sword")
    assert_true(ok)
    assert_true(recipes.knows(ent, "copper_sword"))
end)

test("cannot learn same recipe twice", function()
    reset_all()
    register_test_recipes()
    local ent = entity.create()
    ecs.add_component(ent, "known_recipes")
    ecs.add_component(ent, "professions")
    professions.learn_profession(ent, "blacksmithing")

    recipes.learn(ent, "copper_sword")
    local ok, err = recipes.learn(ent, "copper_sword")
    assert_false(ok)
    assert_true(err:find("already known"))
end)

test("cannot learn nonexistent recipe", function()
    reset_all()
    local ent = entity.create()
    ecs.add_component(ent, "known_recipes")

    local ok, err = recipes.learn(ent, "nonexistent")
    assert_false(ok)
    assert_true(err:find("not found"))
end)

test("can unlearn a recipe", function()
    reset_all()
    register_test_recipes()
    local ent = entity.create()
    ecs.add_component(ent, "known_recipes")
    ecs.add_component(ent, "professions")
    professions.learn_profession(ent, "blacksmithing")

    recipes.learn(ent, "copper_sword")
    assert_true(recipes.knows(ent, "copper_sword"))

    local ok = recipes.unlearn(ent, "copper_sword")
    assert_true(ok)
    assert_false(recipes.knows(ent, "copper_sword"))
end)

test("knows returns false for unlearned recipe", function()
    reset_all()
    register_test_recipes()
    local ent = entity.create()
    ecs.add_component(ent, "known_recipes")

    assert_false(recipes.knows(ent, "copper_sword"))
end)

test("get_known returns learned recipes", function()
    reset_all()
    register_test_recipes()
    local ent = entity.create()
    ecs.add_component(ent, "known_recipes")
    ecs.add_component(ent, "professions")
    professions.learn_profession(ent, "blacksmithing")

    recipes.learn(ent, "copper_sword")
    recipes.learn(ent, "iron_sword")

    local known = recipes.get_known(ent, "blacksmithing")
    assert_eq(#known, 2)
end)

test("get_all_known groups by profession", function()
    reset_all()
    register_test_recipes()
    local ent = entity.create()
    ecs.add_component(ent, "known_recipes")
    ecs.add_component(ent, "professions")
    professions.learn_profession(ent, "blacksmithing")
    professions.learn_profession(ent, "alchemy", professions.TYPE.SECONDARY)

    recipes.learn(ent, "copper_sword")
    recipes.learn(ent, "health_potion")

    local all = recipes.get_all_known(ent)
    assert_eq(#all.blacksmithing, 1)
    assert_eq(#all.alchemy, 1)
end)
-- }}}

-- {{{ Can Craft Tests
test_section("Crafting Preparation")

test("can_craft returns true when requirements met", function()
    reset_all()
    register_test_recipes()
    local ent = entity.create()
    ecs.add_component(ent, "known_recipes")
    ecs.add_component(ent, "professions")
    professions.learn_profession(ent, "blacksmithing")
    professions.add_skill(ent, "blacksmithing", 24)  -- Now at 25

    recipes.learn(ent, "copper_sword")

    local can, err = recipes.can_craft(ent, "copper_sword")
    assert_true(can, err)
end)

test("can_craft fails if recipe not known", function()
    reset_all()
    register_test_recipes()
    local ent = entity.create()
    ecs.add_component(ent, "known_recipes")
    ecs.add_component(ent, "professions")
    professions.learn_profession(ent, "blacksmithing")
    professions.add_skill(ent, "blacksmithing", 100)

    local can, err = recipes.can_craft(ent, "copper_sword")
    assert_false(can)
    assert_true(err:find("not known"))
end)

test("can_craft fails if skill too low", function()
    reset_all()
    register_test_recipes()
    local ent = entity.create()
    ecs.add_component(ent, "known_recipes")
    ecs.add_component(ent, "professions")
    professions.learn_profession(ent, "blacksmithing")
    -- Skill is 1, copper_sword needs 25

    recipes.learn(ent, "copper_sword")

    local can, err = recipes.can_craft(ent, "copper_sword")
    assert_false(can)
    assert_true(err:find("too low"))
end)

test("can_craft fails if profession not learned", function()
    reset_all()
    register_test_recipes()
    local ent = entity.create()
    ecs.add_component(ent, "known_recipes")
    ecs.add_component(ent, "professions")
    -- Don't learn blacksmithing

    -- Directly add to known_recipes to bypass profession check in learn()
    -- Must set _initialized to prevent ensure_fresh_tables from clearing
    local comp = ecs.get_component(ent, "known_recipes")
    rawset(comp, "_initialized", true)
    rawset(comp, "recipes", { blacksmithing = { copper_sword = true } })
    rawset(comp, "discovery_progress", {})
    rawset(comp, "craft_counts", {})
    rawset(comp, "first_craft_times", {})

    local can, err = recipes.can_craft(ent, "copper_sword")
    assert_false(can)
    assert_true(err:find("not learned"), "Expected 'not learned' in error: " .. tostring(err))
end)
-- }}}

-- {{{ Statistics Tests
test_section("Craft Statistics")

test("record_craft increments count", function()
    reset_all()
    register_test_recipes()
    local ent = entity.create()
    ecs.add_component(ent, "known_recipes")

    recipes.record_craft(ent, "copper_sword")
    assert_eq(recipes.get_craft_count(ent, "copper_sword"), 1)

    recipes.record_craft(ent, "copper_sword")
    assert_eq(recipes.get_craft_count(ent, "copper_sword"), 2)
end)

test("get_craft_count returns 0 for uncrafted", function()
    reset_all()
    local ent = entity.create()
    ecs.add_component(ent, "known_recipes")

    assert_eq(recipes.get_craft_count(ent, "copper_sword"), 0)
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

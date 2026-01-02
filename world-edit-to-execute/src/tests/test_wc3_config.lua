-- test_wc3_config.lua
-- Unit tests for WC3 attribute configuration module.
--
-- Tests the complete WC3 attribute system including primary stats,
-- derived attributes with formulas, hero classes, and XP tables.

package.path = package.path .. ";./src/?.lua;./src/?/init.lua"

local attributes = require("libs.attributes")
local wc3 = require("libs.attributes.configs.wc3")

-- {{{ Test infrastructure
local tests_run = 0
local tests_passed = 0
local current_test = ""

-- {{{ assert_eq
local function assert_eq(expected, actual, msg)
    if expected ~= actual then
        error(string.format("%s: expected %s, got %s",
            msg or "Assertion failed",
            tostring(expected),
            tostring(actual)))
    end
end
-- }}}

-- {{{ assert_near
local function assert_near(expected, actual, tolerance, msg)
    tolerance = tolerance or 0.001
    if math.abs(expected - actual) > tolerance then
        error(string.format("%s: expected %.4f, got %.4f (tolerance %.4f)",
            msg or "Assertion failed",
            expected, actual, tolerance))
    end
end
-- }}}

-- {{{ assert_true
local function assert_true(value, msg)
    if not value then
        error(msg or "Expected true, got false")
    end
end
-- }}}

-- {{{ assert_false
local function assert_false(value, msg)
    if value then
        error(msg or "Expected false, got true")
    end
end
-- }}}

-- {{{ assert_nil
local function assert_nil(value, msg)
    if value ~= nil then
        error(string.format("%s: expected nil, got %s",
            msg or "Assertion failed",
            tostring(value)))
    end
end
-- }}}

-- {{{ assert_contains
local function assert_contains(tbl, value, msg)
    for i = 1, #tbl do
        if tbl[i] == value then
            return true
        end
    end
    error(string.format("%s: table does not contain %s",
        msg or "Assertion failed", tostring(value)))
end
-- }}}

-- {{{ run_test
local function run_test(name, fn)
    tests_run = tests_run + 1
    current_test = name
    local success, err = pcall(fn)
    if success then
        tests_passed = tests_passed + 1
        print(string.format("  [PASS] %s", name))
    else
        print(string.format("  [FAIL] %s", name))
        print(string.format("    Error: %s", err))
    end
end
-- }}}

-- {{{ setup
-- Reset and register WC3 attributes for each test section
local function setup()
    attributes.reset()
    wc3.reset()
    wc3.register_all()
    attributes.rebuild_getters()
    attributes.rebuild_setters()
end
-- }}}

-- }}}

-- {{{ Test: Registration

print("\n=== Registration ===")

-- {{{ test: register_all registers all attributes
run_test("register_all registers all attributes", function()
    attributes.reset()
    wc3.reset()

    assert_false(wc3.is_registered(), "should not be registered initially")

    local ok = wc3.register_all()
    assert_true(ok, "registration should succeed")
    assert_true(wc3.is_registered(), "should be registered after")
end)
-- }}}

-- {{{ test: register_all fails on double registration
run_test("register_all fails on double registration", function()
    attributes.reset()
    wc3.reset()

    wc3.register_all()
    local ok, err = wc3.register_all()
    assert_false(ok, "should fail on second registration")
    assert_true(err:find("already registered"), "should have error message")
end)
-- }}}

-- {{{ test: all primary stats registered
run_test("all primary stats registered", function()
    setup()

    assert_true(attributes.has("strength"), "strength registered")
    assert_true(attributes.has("agility"), "agility registered")
    assert_true(attributes.has("intelligence"), "intelligence registered")
    assert_true(attributes.has("primary_stat"), "primary_stat registered")
end)
-- }}}

-- {{{ test: all resource stats registered
run_test("all resource stats registered", function()
    setup()

    assert_true(attributes.has("base_health"), "base_health registered")
    assert_true(attributes.has("base_mana"), "base_mana registered")
    assert_true(attributes.has("health"), "health registered")
    assert_true(attributes.has("mana"), "mana registered")
    assert_true(attributes.has("base_health_regen"), "base_health_regen registered")
    assert_true(attributes.has("base_mana_regen"), "base_mana_regen registered")
end)
-- }}}

-- {{{ test: all combat stats registered
run_test("all combat stats registered", function()
    setup()

    assert_true(attributes.has("base_damage_min"), "base_damage_min registered")
    assert_true(attributes.has("base_damage_max"), "base_damage_max registered")
    assert_true(attributes.has("base_attack_cooldown"), "base_attack_cooldown registered")
    assert_true(attributes.has("base_armor"), "base_armor registered")
    assert_true(attributes.has("movement_speed"), "movement_speed registered")
end)
-- }}}

-- {{{ test: all derived stats registered
run_test("all derived stats registered", function()
    setup()

    assert_true(attributes.has("max_health"), "max_health registered")
    assert_true(attributes.has("max_mana"), "max_mana registered")
    assert_true(attributes.has("health_regen"), "health_regen registered")
    assert_true(attributes.has("mana_regen"), "mana_regen registered")
    assert_true(attributes.has("armor"), "armor registered")
    assert_true(attributes.has("armor_reduction"), "armor_reduction registered")
    assert_true(attributes.has("attack_damage_bonus"), "attack_damage_bonus registered")
    assert_true(attributes.has("damage_min"), "damage_min registered")
    assert_true(attributes.has("damage_max"), "damage_max registered")
    assert_true(attributes.has("attack_speed_bonus"), "attack_speed_bonus registered")
    assert_true(attributes.has("attack_cooldown"), "attack_cooldown registered")
    assert_true(attributes.has("dps"), "dps registered")
end)
-- }}}

-- }}}

-- {{{ Test: Derived Attribute Formulas

print("\n=== Derived Attribute Formulas ===")

-- {{{ test: max_health formula (base + str * 25)
run_test("max_health formula (base + str * 25)", function()
    setup()
    local container = attributes.create_container()

    attributes.set_value(container, "base_health", 100)
    attributes.set_value(container, "strength", 20)

    -- max_health = 100 + (20 * 25) = 100 + 500 = 600
    local max_health = attributes.get_value(container, "max_health")
    assert_eq(600, max_health, "max_health should be 600")
end)
-- }}}

-- {{{ test: max_mana formula (base + int * 15)
run_test("max_mana formula (base + int * 15)", function()
    setup()
    local container = attributes.create_container()

    attributes.set_value(container, "base_mana", 200)
    attributes.set_value(container, "intelligence", 30)

    -- max_mana = 200 + (30 * 15) = 200 + 450 = 650
    local max_mana = attributes.get_value(container, "max_mana")
    assert_eq(650, max_mana, "max_mana should be 650")
end)
-- }}}

-- {{{ test: health_regen formula (base + str * 0.05)
run_test("health_regen formula (base + str * 0.05)", function()
    setup()
    local container = attributes.create_container()

    attributes.set_value(container, "base_health_regen", 0.25)
    attributes.set_value(container, "strength", 40)

    -- health_regen = 0.25 + (40 * 0.05) = 0.25 + 2.0 = 2.25
    local regen = attributes.get_value(container, "health_regen")
    assert_near(2.25, regen, 0.001, "health_regen should be 2.25")
end)
-- }}}

-- {{{ test: mana_regen formula (base + int * 0.05)
run_test("mana_regen formula (base + int * 0.05)", function()
    setup()
    local container = attributes.create_container()

    attributes.set_value(container, "base_mana_regen", 0.5)
    attributes.set_value(container, "intelligence", 20)

    -- mana_regen = 0.5 + (20 * 0.05) = 0.5 + 1.0 = 1.5
    local regen = attributes.get_value(container, "mana_regen")
    assert_near(1.5, regen, 0.001, "mana_regen should be 1.5")
end)
-- }}}

-- {{{ test: armor formula (base + agi / 3)
run_test("armor formula (base + agi / 3)", function()
    setup()
    local container = attributes.create_container()

    attributes.set_value(container, "base_armor", 2)
    attributes.set_value(container, "agility", 30)

    -- armor = 2 + (30 / 3) = 2 + 10 = 12
    local armor = attributes.get_value(container, "armor")
    assert_near(12, armor, 0.001, "armor should be 12")
end)
-- }}}

-- {{{ test: armor_reduction formula
run_test("armor_reduction formula", function()
    setup()
    local container = attributes.create_container()

    attributes.set_value(container, "base_armor", 10)
    attributes.set_value(container, "agility", 0)

    -- armor = 10
    -- reduction = (10 * 0.06 / (1 + 0.06 * 10)) * 100
    --           = (0.6 / 1.6) * 100 = 37.5%
    local reduction = attributes.get_value(container, "armor_reduction")
    assert_near(37.5, reduction, 0.1, "armor_reduction should be 37.5%")
end)
-- }}}

-- {{{ test: armor_reduction zero armor
run_test("armor_reduction zero armor", function()
    setup()
    local container = attributes.create_container()

    attributes.set_value(container, "base_armor", 0)
    attributes.set_value(container, "agility", 0)

    local reduction = attributes.get_value(container, "armor_reduction")
    assert_eq(0, reduction, "zero armor should give 0 reduction")
end)
-- }}}

-- {{{ test: attack_damage_bonus from primary stat (strength)
run_test("attack_damage_bonus from primary stat (strength)", function()
    setup()
    local container = attributes.create_container()

    attributes.set_value(container, "primary_stat", "strength")
    attributes.set_value(container, "strength", 25)
    attributes.set_value(container, "agility", 15)
    attributes.set_value(container, "intelligence", 10)

    local bonus = attributes.get_value(container, "attack_damage_bonus")
    assert_eq(25, bonus, "bonus should equal strength")
end)
-- }}}

-- {{{ test: attack_damage_bonus from primary stat (agility)
run_test("attack_damage_bonus from primary stat (agility)", function()
    setup()
    local container = attributes.create_container()

    attributes.set_value(container, "primary_stat", "agility")
    attributes.set_value(container, "strength", 15)
    attributes.set_value(container, "agility", 30)
    attributes.set_value(container, "intelligence", 10)

    local bonus = attributes.get_value(container, "attack_damage_bonus")
    assert_eq(30, bonus, "bonus should equal agility")
end)
-- }}}

-- {{{ test: attack_damage_bonus from primary stat (intelligence)
run_test("attack_damage_bonus from primary stat (intelligence)", function()
    setup()
    local container = attributes.create_container()

    attributes.set_value(container, "primary_stat", "intelligence")
    attributes.set_value(container, "strength", 15)
    attributes.set_value(container, "agility", 10)
    attributes.set_value(container, "intelligence", 35)

    local bonus = attributes.get_value(container, "attack_damage_bonus")
    assert_eq(35, bonus, "bonus should equal intelligence")
end)
-- }}}

-- {{{ test: damage_min includes bonus
run_test("damage_min includes bonus", function()
    setup()
    local container = attributes.create_container()

    attributes.set_value(container, "base_damage_min", 10)
    attributes.set_value(container, "primary_stat", "strength")
    attributes.set_value(container, "strength", 20)

    -- damage_min = 10 + 20 = 30
    local damage = attributes.get_value(container, "damage_min")
    assert_eq(30, damage, "damage_min should be 30")
end)
-- }}}

-- {{{ test: attack_speed_bonus equals agility
run_test("attack_speed_bonus equals agility", function()
    setup()
    local container = attributes.create_container()

    attributes.set_value(container, "agility", 50)

    -- 1% IAS per agility
    local bonus = attributes.get_value(container, "attack_speed_bonus")
    assert_eq(50, bonus, "attack_speed_bonus should be 50%")
end)
-- }}}

-- {{{ test: attack_cooldown formula
run_test("attack_cooldown formula", function()
    setup()
    local container = attributes.create_container()

    attributes.set_value(container, "base_attack_cooldown", 1.5)
    attributes.set_value(container, "agility", 100)

    -- attack_cooldown = 1.5 / (1 + 100/100) = 1.5 / 2 = 0.75
    local cooldown = attributes.get_value(container, "attack_cooldown")
    assert_near(0.75, cooldown, 0.001, "attack_cooldown should be 0.75")
end)
-- }}}

-- {{{ test: dps calculation
run_test("dps calculation", function()
    setup()
    local container = attributes.create_container()

    attributes.set_value(container, "base_damage_min", 10)
    attributes.set_value(container, "base_damage_max", 20)
    attributes.set_value(container, "base_attack_cooldown", 1.0)
    attributes.set_value(container, "primary_stat", "strength")
    attributes.set_value(container, "strength", 10)
    attributes.set_value(container, "agility", 0)

    -- damage_min = 10 + 10 = 20, damage_max = 20 + 10 = 30
    -- avg_damage = 25
    -- attack_cooldown = 1.0 / (1 + 0/100) = 1.0
    -- dps = 25 / 1.0 = 25
    local dps = attributes.get_value(container, "dps")
    assert_near(25, dps, 0.001, "dps should be 25")
end)
-- }}}

-- }}}

-- {{{ Test: Hero Classes

print("\n=== Hero Classes ===")

-- {{{ test: list_hero_classes returns all classes
run_test("list_hero_classes returns all classes", function()
    local classes = wc3.list_hero_classes()

    assert_true(#classes > 0, "should have hero classes")
    assert_contains(classes, "paladin", "should have paladin")
    assert_contains(classes, "archmage", "should have archmage")
    assert_contains(classes, "blademaster", "should have blademaster")
end)
-- }}}

-- {{{ test: get_hero_class returns class data
run_test("get_hero_class returns class data", function()
    local paladin = wc3.get_hero_class("paladin")

    assert_true(paladin ~= nil, "paladin should exist")
    assert_eq("strength", paladin.primary_stat, "paladin is strength-based")
    assert_eq(24, paladin.base_strength, "paladin base strength")
    assert_near(2.7, paladin.strength_per_level, 0.01, "paladin str per level")
end)
-- }}}

-- {{{ test: get_hero_class returns nil for unknown
run_test("get_hero_class returns nil for unknown", function()
    local result = wc3.get_hero_class("nonexistent")
    assert_nil(result, "should return nil for unknown class")
end)
-- }}}

-- {{{ test: get_hero_classes_by_primary groups correctly
run_test("get_hero_classes_by_primary groups correctly", function()
    local grouped = wc3.get_hero_classes_by_primary()

    assert_true(#grouped.strength > 0, "should have strength heroes")
    assert_true(#grouped.agility > 0, "should have agility heroes")
    assert_true(#grouped.intelligence > 0, "should have intelligence heroes")

    -- Verify a few specific heroes
    assert_contains(grouped.strength, "paladin", "paladin should be strength")
    assert_contains(grouped.agility, "blademaster", "blademaster should be agility")
    assert_contains(grouped.intelligence, "archmage", "archmage should be intelligence")
end)
-- }}}

-- {{{ test: apply_hero_class sets stats
run_test("apply_hero_class sets stats", function()
    setup()
    local container = attributes.create_container()

    local ok = wc3.apply_hero_class(container, "paladin", 1)
    assert_true(ok, "apply should succeed")

    local level = attributes.get_value(container, "level")
    local primary = attributes.get_value(container, "primary_stat")
    local str = attributes.get_value(container, "strength")

    assert_eq(1, level, "level should be 1")
    assert_eq("strength", primary, "primary should be strength")
    assert_eq(24, str, "strength should be paladin base (24)")
end)
-- }}}

-- {{{ test: apply_hero_class at level 5
run_test("apply_hero_class at level 5", function()
    setup()
    local container = attributes.create_container()

    wc3.apply_hero_class(container, "paladin", 5)

    local level = attributes.get_value(container, "level")
    local str = attributes.get_value(container, "strength")

    assert_eq(5, level, "level should be 5")

    -- Paladin: base 24, +2.7 per level, 4 levels gained
    -- str = floor(24 + 2.7 * 4) = floor(34.8) = 34
    assert_eq(34, str, "strength at level 5 should be 34")
end)
-- }}}

-- {{{ test: apply_hero_class fails for unknown
run_test("apply_hero_class fails for unknown", function()
    setup()
    local container = attributes.create_container()

    local ok, err = wc3.apply_hero_class(container, "nonexistent", 1)
    assert_false(ok, "should fail for unknown class")
    assert_true(err:find("Unknown hero class"), "should have error message")
end)
-- }}}

-- {{{ test: apply_hero_class clamps level
run_test("apply_hero_class clamps level", function()
    setup()
    local container = attributes.create_container()

    wc3.apply_hero_class(container, "paladin", 100)  -- Over max

    local level = attributes.get_value(container, "level")
    assert_eq(25, level, "level should be clamped to 25")
end)
-- }}}

-- {{{ test: calculate_stats_at_level
run_test("calculate_stats_at_level", function()
    local stats = wc3.calculate_stats_at_level("archmage", 10)

    assert_eq(10, stats.level, "level should be 10")
    assert_eq("intelligence", stats.primary_stat, "primary should be intelligence")

    -- Archmage: base 24 int, +3.2 per level, 9 levels gained
    -- int = floor(24 + 3.2 * 9) = floor(52.8) = 52
    assert_eq(52, stats.intelligence, "intelligence at level 10")
end)
-- }}}

-- {{{ test: calculate_stats_at_level fails for unknown
run_test("calculate_stats_at_level fails for unknown", function()
    local stats, err = wc3.calculate_stats_at_level("nonexistent", 5)
    assert_nil(stats, "should return nil")
    assert_true(err:find("Unknown hero class"), "should have error")
end)
-- }}}

-- }}}

-- {{{ Test: Experience Table

print("\n=== Experience Table ===")

-- {{{ test: get_xp_for_level returns correct values
run_test("get_xp_for_level returns correct values", function()
    assert_eq(0, wc3.get_xp_for_level(1), "level 1 requires 0 XP")
    assert_eq(200, wc3.get_xp_for_level(2), "level 2 requires 200 XP")
    assert_eq(500, wc3.get_xp_for_level(3), "level 3 requires 500 XP")
    assert_eq(5400, wc3.get_xp_for_level(10), "level 10 requires 5400 XP")
    assert_eq(32400, wc3.get_xp_for_level(25), "level 25 requires 32400 XP")
end)
-- }}}

-- {{{ test: get_xp_for_level handles edge cases
run_test("get_xp_for_level handles edge cases", function()
    assert_eq(0, wc3.get_xp_for_level(0), "level 0 returns 0")
    assert_eq(0, wc3.get_xp_for_level(-5), "negative level returns 0")
    assert_eq(32400, wc3.get_xp_for_level(30), "over max returns max XP")
end)
-- }}}

-- {{{ test: get_level_for_xp returns correct level
run_test("get_level_for_xp returns correct level", function()
    assert_eq(1, wc3.get_level_for_xp(0), "0 XP is level 1")
    assert_eq(1, wc3.get_level_for_xp(100), "100 XP is still level 1")
    assert_eq(2, wc3.get_level_for_xp(200), "200 XP is level 2")
    assert_eq(2, wc3.get_level_for_xp(499), "499 XP is still level 2")
    assert_eq(3, wc3.get_level_for_xp(500), "500 XP is level 3")
    assert_eq(10, wc3.get_level_for_xp(5400), "5400 XP is level 10")
    assert_eq(25, wc3.get_level_for_xp(32400), "32400 XP is level 25")
    assert_eq(25, wc3.get_level_for_xp(100000), "100000 XP is level 25")
end)
-- }}}

-- {{{ test: get_xp_to_next_level
run_test("get_xp_to_next_level", function()
    -- At level 1 (0 XP), need 200 for level 2
    assert_eq(200, wc3.get_xp_to_next_level(0), "0 XP needs 200 more")

    -- At 100 XP (still level 1), need 100 for level 2
    assert_eq(100, wc3.get_xp_to_next_level(100), "100 XP needs 100 more")

    -- At level 25, need 0 (max level)
    assert_eq(0, wc3.get_xp_to_next_level(32400), "max level needs 0")
end)
-- }}}

-- {{{ test: get_xp_progress
run_test("get_xp_progress", function()
    -- At 0 XP, 0% toward level 2
    assert_near(0, wc3.get_xp_progress(0), 0.1, "0 XP is 0% progress")

    -- At 100 XP, 50% toward level 2 (0-200 range)
    assert_near(50, wc3.get_xp_progress(100), 0.1, "100 XP is 50% progress")

    -- At max level, 100% progress
    assert_eq(100, wc3.get_xp_progress(32400), "max level is 100%")
end)
-- }}}

-- }}}

-- {{{ Test: Level Up

print("\n=== Level Up ===")

-- {{{ test: level_up increases stats
run_test("level_up increases stats", function()
    setup()
    local container = attributes.create_container()

    wc3.apply_hero_class(container, "paladin", 1)

    local str_before = attributes.get_value(container, "strength")

    local ok, info = wc3.level_up(container, "paladin")
    assert_true(ok, "level_up should succeed")

    local level = attributes.get_value(container, "level")
    local str_after = attributes.get_value(container, "strength")

    assert_eq(2, level, "level should be 2")
    assert_eq(2, info.strength_gained, "should gain 2 strength (floor of 2.7)")
    assert_eq(str_before + 2, str_after, "strength should increase by 2")
end)
-- }}}

-- {{{ test: level_up fails at max level
run_test("level_up fails at max level", function()
    setup()
    local container = attributes.create_container()

    wc3.apply_hero_class(container, "paladin", 25)

    local ok, err = wc3.level_up(container, "paladin")
    assert_false(ok, "should fail at max level")
    assert_true(err:find("max level"), "should have error message")
end)
-- }}}

-- {{{ test: level_up fails for unknown class
run_test("level_up fails for unknown class", function()
    setup()
    local container = attributes.create_container()

    wc3.apply_hero_class(container, "paladin", 1)

    local ok, err = wc3.level_up(container, "nonexistent")
    assert_false(ok, "should fail for unknown class")
end)
-- }}}

-- }}}

-- {{{ Test: Integration

print("\n=== Integration ===")

-- {{{ test: full hero lifecycle
run_test("full hero lifecycle", function()
    setup()
    local container = attributes.create_container()

    -- Create a level 1 archmage
    wc3.apply_hero_class(container, "archmage", 1)

    -- Check initial derived stats
    local max_health = attributes.get_value(container, "max_health")
    local max_mana = attributes.get_value(container, "max_mana")

    -- Archmage at level 1: str 14, agi 17, int 24
    -- max_health = 100 + (14 * 25) = 450
    -- max_mana = 285 + (24 * 15) = 645
    assert_eq(450, max_health, "archmage max_health at level 1")
    assert_eq(645, max_mana, "archmage max_mana at level 1")

    -- Level up
    wc3.level_up(container, "archmage")

    -- Check updated stats
    local new_max_health = attributes.get_value(container, "max_health")
    local new_max_mana = attributes.get_value(container, "max_mana")

    -- After level up: str +1 (floor of 1.8), int +3 (floor of 3.2)
    -- max_health = 100 + (15 * 25) = 475
    -- max_mana = 285 + (27 * 15) = 690
    assert_eq(475, new_max_health, "archmage max_health at level 2")
    assert_eq(690, new_max_mana, "archmage max_mana at level 2")
end)
-- }}}

-- {{{ test: modifiers affect derived stats
run_test("modifiers affect derived stats", function()
    setup()
    local container = attributes.create_container()

    wc3.apply_hero_class(container, "paladin", 1)

    local base_max_health = attributes.get_value(container, "max_health")

    -- Add a +10 strength modifier
    attributes.add_modifier(container, "strength", {
        source = "test_item",
        type = "flat",
        value = 10,
    })

    -- max_health should increase by 10 * 25 = 250
    local new_max_health = attributes.get_value(container, "max_health")
    assert_eq(base_max_health + 250, new_max_health, "max_health should increase")

    -- Remove modifier
    attributes.remove_modifier(container, "strength", "test_item")

    local final_max_health = attributes.get_value(container, "max_health")
    assert_eq(base_max_health, final_max_health, "max_health should return to base")
end)
-- }}}

-- {{{ test: all hero classes can be applied
run_test("all hero classes can be applied", function()
    setup()

    local classes = wc3.list_hero_classes()
    for i = 1, #classes do
        local class_name = classes[i]
        local container = attributes.create_container()

        local ok = wc3.apply_hero_class(container, class_name, 1)
        assert_true(ok, "should apply " .. class_name)

        local level = attributes.get_value(container, "level")
        assert_eq(1, level, class_name .. " should be level 1")
    end
end)
-- }}}

-- {{{ test: XP table is monotonically increasing
run_test("XP table is monotonically increasing", function()
    local prev = -1
    for lvl = 1, 25 do
        local xp = wc3.get_xp_for_level(lvl)
        assert_true(xp > prev, "XP should increase at level " .. lvl)
        prev = xp
    end
end)
-- }}}

-- }}}

-- {{{ Summary
print("\n" .. string.rep("=", 50))
print(string.format("Tests: %d/%d passed", tests_passed, tests_run))

if tests_passed == tests_run then
    print("All tests passed!")
    os.exit(0)
else
    print(string.format("%d tests failed", tests_run - tests_passed))
    os.exit(1)
end
-- }}}

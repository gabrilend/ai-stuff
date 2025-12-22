#!/usr/bin/env luajit
-- src/tests/test_unit.lua
-- Comprehensive tests for Unit class (206c)
--
-- Run with: luajit src/tests/test_unit.lua

-- {{{ Test setup
local DIR = debug.getinfo(1, "S").source:match("@(.*/)") or "./"
DIR = DIR:match("(.-)/src/tests/$") or DIR:match("(.-)/src/tests/") or "."
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local Unit = require("gameobjects.unit")

local tests_passed = 0
local tests_total = 0

local function assert_eq(actual, expected, msg)
    tests_total = tests_total + 1
    if actual == expected then
        tests_passed = tests_passed + 1
        return true
    else
        print(string.format("  FAILED: %s", msg or "assertion failed"))
        print(string.format("    expected: %s", tostring(expected)))
        print(string.format("    actual:   %s", tostring(actual)))
        return false
    end
end

local function assert_true(condition, msg)
    tests_total = tests_total + 1
    if condition then  -- truthy check, not strict == true
        tests_passed = tests_passed + 1
        return true
    else
        print(string.format("  FAILED: %s (expected truthy)", msg or "assertion failed"))
        return false
    end
end

local function assert_false(condition, msg)
    tests_total = tests_total + 1
    if condition == false or condition == nil then
        tests_passed = tests_passed + 1
        return true
    else
        print(string.format("  FAILED: %s (expected false)", msg or "assertion failed"))
        return false
    end
end

local function assert_nil(value, msg)
    tests_total = tests_total + 1
    if value == nil then
        tests_passed = tests_passed + 1
        return true
    else
        print(string.format("  FAILED: %s (expected nil, got %s)", msg or "assertion failed", tostring(value)))
        return false
    end
end

local function assert_not_nil(value, msg)
    tests_total = tests_total + 1
    if value ~= nil then
        tests_passed = tests_passed + 1
        return true
    else
        print(string.format("  FAILED: %s (expected non-nil)", msg or "assertion failed"))
        return false
    end
end
-- }}}

print("=== Unit Class Tests (206c) ===")
print("")

-- {{{ Test: constructor copies all fields
print("Test: constructor copies all fields")
do
    local unit = Unit.new({
        id = "hfoo",
        variation = 2,
        position = { x = 100, y = 200, z = 50 },
        angle = 1.57,
        scale = { x = 1.5, y = 1.5, z = 1.0 },
        player = 1,
        hp = 500,
        mp = 100,
        creation_number = 42,
    })

    assert_eq(unit.type_id, "hfoo", "type_id")
    assert_eq(unit.id, "hfoo", "id alias")
    assert_eq(unit.variation, 2, "variation")
    assert_eq(unit.position.x, 100, "position.x")
    assert_eq(unit.position.y, 200, "position.y")
    assert_eq(unit.position.z, 50, "position.z")
    assert_eq(unit.angle, 1.57, "angle")
    assert_eq(unit.scale.x, 1.5, "scale.x")
    assert_eq(unit.player, 1, "player")
    assert_eq(unit.base_hp, 500, "base_hp")
    assert_eq(unit.base_mp, 100, "base_mp")
    assert_eq(unit.creation_id, 42, "creation_id")
end
print("  PASSED")
-- }}}

-- {{{ Test: default values when fields missing
print("Test: default values when fields missing")
do
    local unit = Unit.new({ id = "hfoo" })

    assert_eq(unit.variation, 0, "default variation")
    assert_eq(unit.position.x, 0, "default position.x")
    assert_eq(unit.player, 0, "default player")
    assert_eq(unit.base_hp, -1, "default base_hp (-1)")
    assert_eq(unit.base_mp, -1, "default base_mp (-1)")
    assert_eq(unit.scale.x, 1, "default scale.x")
    assert_eq(unit.waygate_dest, -1, "default waygate_dest")
end
print("  PASSED")
-- }}}

-- {{{ Test: is_hero with hero_data
print("Test: is_hero with hero_data")
do
    local hero = Unit.new({
        id = "Hpal",
        hero_data = { level = 5, str_bonus = 2, agi_bonus = 0, int_bonus = 3 },
    })
    local non_hero = Unit.new({ id = "hfoo" })

    assert_true(hero:is_hero(), "hero with hero_data should be hero")
    assert_false(non_hero:is_hero(), "unit without hero_data should not be hero")
end
print("  PASSED")
-- }}}

-- {{{ Test: is_hero fallback to capital letter
print("Test: is_hero fallback to capital letter")
do
    -- Capital first letter without hero_data (fallback detection)
    local hero = Unit.new({ id = "Obla" })  -- Blademaster
    local non_hero = Unit.new({ id = "ogru" })  -- Grunt

    assert_true(hero:is_hero(), "capital first letter should indicate hero")
    assert_false(non_hero:is_hero(), "lowercase should not be hero")
end
print("  PASSED")
-- }}}

-- {{{ Test: is_hero excludes random units
print("Test: is_hero excludes random units")
do
    -- Random unit placeholder starts with Y but should not be detected as hero
    local random = Unit.new({
        id = "YYU5",  -- Capital Y but it's random
        random_unit = { type = "level", level = 5 },
    })

    assert_false(random:is_hero(), "random unit should not be hero")
    assert_true(random:is_random(), "should be detected as random")
end
print("  PASSED")
-- }}}

-- {{{ Test: is_building detection
print("Test: is_building detection")
do
    local hall = Unit.new({ id = "htow" })  -- Town Hall (h=human, t=town)
    local barracks = Unit.new({ id = "hbar" })  -- Barracks (h=human, b=barracks)
    local altar = Unit.new({ id = "halt" })  -- Altar (h=human, a=altar)
    local farm = Unit.new({ id = "hhou" })  -- Farm/house... actually 'h' not 'f'
    local grunt = Unit.new({ id = "ogru" })  -- Grunt (not a building)
    local hero = Unit.new({ id = "Hpal" })  -- Hero (capital letter)

    assert_true(hall:is_building(), "htow should be building")
    assert_true(barracks:is_building(), "hbar should be building")
    assert_true(altar:is_building(), "halt should be building")
    assert_false(grunt:is_building(), "ogru should not be building")
    assert_false(hero:is_building(), "Hpal should not be building (capital)")
end
print("  PASSED")
-- }}}

-- {{{ Test: is_item detection
print("Test: is_item detection")
do
    local custom_item = Unit.new({ id = "I000" })  -- Custom item
    local unit = Unit.new({ id = "hfoo" })

    assert_true(custom_item:is_item(), "I000 should be item")
    assert_false(unit:is_item(), "hfoo should not be item")
end
print("  PASSED")
-- }}}

-- {{{ Test: is_random detection
print("Test: is_random detection")
do
    local random_level = Unit.new({
        id = "YYU5",
        random_unit = { type = "level", level = 5 },
    })
    local random_y_prefix = Unit.new({ id = "YYI3" })  -- Random item
    local normal = Unit.new({ id = "hfoo" })

    assert_true(random_level:is_random(), "unit with random_unit data")
    assert_true(random_y_prefix:is_random(), "unit with Y prefix")
    assert_false(normal:is_random(), "normal unit")
end
print("  PASSED")
-- }}}

-- {{{ Test: is_waygate detection
print("Test: is_waygate detection")
do
    local waygate = Unit.new({
        id = "hwat",  -- Waygate
        waygate_dest = 123,
    })
    local inactive_waygate = Unit.new({
        id = "hwat",
        waygate_dest = -1,
    })
    local normal = Unit.new({ id = "hfoo" })

    assert_true(waygate:is_waygate(), "unit with waygate_dest >= 0")
    assert_false(inactive_waygate:is_waygate(), "waygate_dest = -1 is inactive")
    assert_false(normal:is_waygate(), "normal unit")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_hero_level
print("Test: get_hero_level")
do
    local hero = Unit.new({
        id = "Hpal",
        hero_data = { level = 7 },
    })
    local hero_default = Unit.new({
        id = "Hamg",
        hero_data = {},  -- No level specified
    })
    local non_hero = Unit.new({ id = "hfoo" })

    assert_eq(hero:get_hero_level(), 7, "hero level 7")
    assert_eq(hero_default:get_hero_level(), 1, "default level 1")
    assert_nil(non_hero:get_hero_level(), "non-hero returns nil")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_hero_stats
print("Test: get_hero_stats")
do
    local hero = Unit.new({
        id = "Hpal",
        hero_data = { str_bonus = 5, agi_bonus = 3, int_bonus = 2 },
    })
    local hero_default = Unit.new({
        id = "Hamg",
        hero_data = {},
    })
    local non_hero = Unit.new({ id = "hfoo" })

    local stats = hero:get_hero_stats()
    assert_not_nil(stats, "hero should have stats")
    assert_eq(stats.str_bonus, 5, "str_bonus")
    assert_eq(stats.agi_bonus, 3, "agi_bonus")
    assert_eq(stats.int_bonus, 2, "int_bonus")

    local default_stats = hero_default:get_hero_stats()
    assert_eq(default_stats.str_bonus, 0, "default str_bonus")
    assert_eq(default_stats.agi_bonus, 0, "default agi_bonus")

    assert_nil(non_hero:get_hero_stats(), "non-hero returns nil")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_inventory
print("Test: get_inventory")
do
    local hero = Unit.new({
        id = "Hpal",
        hero_data = {
            inventory = {
                [0] = "bspd",
                [2] = "rin1",
            },
        },
    })
    local hero_empty = Unit.new({
        id = "Hamg",
        hero_data = {},
    })
    local non_hero = Unit.new({ id = "hfoo" })

    local inv = hero:get_inventory()
    assert_eq(inv[0], "bspd", "slot 0")
    assert_eq(inv[2], "rin1", "slot 2")
    assert_nil(inv[1], "slot 1 empty")

    local empty_inv = hero_empty:get_inventory()
    assert_eq(next(empty_inv), nil, "empty inventory")

    local non_hero_inv = non_hero:get_inventory()
    assert_eq(next(non_hero_inv), nil, "non-hero empty inventory")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_waygate_destination
print("Test: get_waygate_destination")
do
    local waygate = Unit.new({
        id = "hwat",
        waygate_dest = 456,
    })
    local non_waygate = Unit.new({ id = "hfoo" })

    assert_eq(waygate:get_waygate_destination(), 456, "waygate destination")
    assert_nil(non_waygate:get_waygate_destination(), "non-waygate returns nil")
end
print("  PASSED")
-- }}}

-- {{{ Test: has_item_drops
print("Test: has_item_drops")
do
    local with_drops = Unit.new({
        id = "ncre",
        item_drops = {
            sets = {
                { items = { { id = "ratc", chance = 100 } } },
            },
        },
    })
    local without_drops = Unit.new({ id = "hfoo" })
    local empty_sets = Unit.new({
        id = "ogru",
        item_drops = { sets = {} },
    })

    assert_true(with_drops:has_item_drops(), "unit with drops")
    assert_false(without_drops:has_item_drops(), "unit without drops")
    assert_false(empty_sets:has_item_drops(), "unit with empty sets")
end
print("  PASSED")
-- }}}

-- {{{ Test: has_modified_abilities
print("Test: has_modified_abilities")
do
    local with_abilities = Unit.new({
        id = "Hpal",
        abilities = {
            { id = "AHds", level = 2, autocast = false },
        },
    })
    local without_abilities = Unit.new({ id = "hfoo" })

    assert_true(with_abilities:has_modified_abilities(), "unit with abilities")
    assert_false(without_abilities:has_modified_abilities(), "unit without abilities")
end
print("  PASSED")
-- }}}

-- {{{ Test: __tostring
print("Test: __tostring shows type info")
do
    local hero = Unit.new({
        id = "Hpal",
        player = 0,
        position = { x = 100, y = 200 },
        hero_data = { level = 5 },
    })
    local waygate = Unit.new({
        id = "hwat",
        player = 1,
        position = { x = 300, y = 400 },
        waygate_dest = 10,
    })
    local random = Unit.new({
        id = "YYU5",
        player = 2,
        position = { x = 500, y = 600 },
        random_unit = { type = "level" },
    })

    local hero_str = tostring(hero)
    assert_true(hero_str:find("Hpal"), "should contain type_id")
    assert_true(hero_str:find("L5"), "should contain level")
    assert_true(hero_str:find("HERO"), "should have HERO marker")

    local waygate_str = tostring(waygate)
    assert_true(waygate_str:find("WAYGATE"), "should have WAYGATE marker")

    local random_str = tostring(random)
    assert_true(random_str:find("RANDOM"), "should have RANDOM marker")
end
print("  PASSED")
-- }}}

-- {{{ Test: runtime state initialization
print("Test: runtime state initialization")
do
    local unit = Unit.new({ id = "hfoo" })

    assert_nil(unit.current_hp, "current_hp nil before game")
    assert_nil(unit.current_mp, "current_mp nil before game")
    assert_true(unit.is_alive, "is_alive default true")
end
print("  PASSED")
-- }}}

-- {{{ Summary
print("")
print("========================================")
print(string.format("Tests passed: %d / %d", tests_passed, tests_total))
if tests_passed == tests_total then
    print("All tests PASSED!")
else
    print("Some tests FAILED!")
    os.exit(1)
end
-- }}}

#!/usr/bin/env lua
-- Test suite for war3mapUnits.doo parser (Issue 202a)
-- Tests header parsing, basic fields, the variable sections (in the order
-- the World Editor writes them, issue 202f) and damaged files.
-- Run from project root: luajit src/tests/test_unitsdoo.lua

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local unitsdoo = require("parsers.unitsdoo")

local tests_run = 0
local tests_passed = 0

-- {{{ Test utilities
-- {{{ assert_eq
local function assert_eq(actual, expected, message)
    tests_run = tests_run + 1
    if actual == expected then
        tests_passed = tests_passed + 1
        return true
    else
        print(string.format("FAIL: %s", message or "assertion failed"))
        print(string.format("  expected: %s", tostring(expected)))
        print(string.format("  actual:   %s", tostring(actual)))
        return false
    end
end
-- }}}

-- {{{ assert_near
local function assert_near(actual, expected, epsilon, message)
    tests_run = tests_run + 1
    epsilon = epsilon or 0.001
    if math.abs(actual - expected) < epsilon then
        tests_passed = tests_passed + 1
        return true
    else
        print(string.format("FAIL: %s", message or "assertion failed"))
        print(string.format("  expected: %s (within %s)", tostring(expected), tostring(epsilon)))
        print(string.format("  actual:   %s", tostring(actual)))
        return false
    end
end
-- }}}

-- {{{ assert_true
local function assert_true(value, message)
    tests_run = tests_run + 1
    if value then
        tests_passed = tests_passed + 1
        return true
    else
        print(string.format("FAIL: %s", message or "expected true"))
        return false
    end
end
-- }}}

-- {{{ assert_nil
local function assert_nil(value, message)
    tests_run = tests_run + 1
    if value == nil then
        tests_passed = tests_passed + 1
        return true
    else
        print(string.format("FAIL: %s", message or "expected nil"))
        print(string.format("  actual: %s", tostring(value)))
        return false
    end
end
-- }}}

-- {{{ make_int32
-- Create a little-endian int32 byte string
local function make_int32(n)
    local b1 = n % 256
    local b2 = math.floor(n / 256) % 256
    local b3 = math.floor(n / 65536) % 256
    local b4 = math.floor(n / 16777216) % 256
    -- Handle negative numbers (two's complement)
    if n < 0 then
        n = n + 4294967296
        b1 = n % 256
        b2 = math.floor(n / 256) % 256
        b3 = math.floor(n / 65536) % 256
        b4 = math.floor(n / 16777216) % 256
    end
    return string.char(b1, b2, b3, b4)
end
-- }}}

-- {{{ make_float32
-- Create a little-endian float32 byte string
local function make_float32(f)
    -- Simple float encoding for common values
    if f == 0.0 then
        return string.char(0, 0, 0, 0)
    elseif f == 1.0 then
        return string.char(0, 0, 128, 63)
    elseif f == -1.0 then
        return string.char(0, 0, 128, 191)
    elseif f == 100.0 then
        return string.char(0, 0, 200, 66)
    elseif f == 200.0 then
        return string.char(0, 0, 72, 67)
    elseif f == 1024.0 then
        return string.char(0, 0, 128, 68)
    elseif f == 2048.0 then
        return string.char(0, 0, 0, 69)
    elseif f == 3.14159 then
        -- pi
        return string.char(208, 15, 73, 64)
    else
        -- For other values, use a rough approximation
        -- This is not a full float encoder, just for test data
        error("make_float32: unsupported value " .. tostring(f))
    end
end
-- }}}

-- {{{ make_entry
-- One unit entry in the layout the World Editor writes (issue 202f):
-- head; item drops (the table pointer from subversion 11 on); gold and
-- target acquisition; the hero section, which every entry has (level, the
-- three stat bonuses from version 8 on, the inventory); abilities; the
-- random section; custom color; waygate; creation number.
-- t: id, x, y, z, angle, player, hp, mp, table_pointer, sets ({ {id, chance}, ... }
-- per set), gold, level, str, agi, int, inventory ({ {slot, id}, ... }),
-- abilities ({ {id, autocast, level}, ... }), random_flag, random_level,
-- item_class, group, position, choices ({ {id, chance}, ... }), waygate,
-- creation, version (8, or 7 for RoC: no table pointer, no stat bonuses)
local function make_entry(t)
    local v8 = (t.version or 8) >= 8
    local p = {}
    local function add(s) p[#p + 1] = s end
    add(t.id or "hfoo"); add(make_int32(0))
    add(make_float32(t.x or 0.0)); add(make_float32(t.y or 0.0)); add(make_float32(t.z or 0.0))
    add(make_float32(t.angle or 0.0))
    add(make_float32(1.0)); add(make_float32(1.0)); add(make_float32(1.0))
    add(string.char(0)); add(make_int32(t.player or 0)); add(string.char(0, 0))
    add(make_int32(t.hp or -1)); add(make_int32(t.mp or -1))
    -- item drops
    if v8 then add(make_int32(t.table_pointer or -1)) end
    add(make_int32(#(t.sets or {})))
    for _, set in ipairs(t.sets or {}) do
        add(make_int32(#set))
        for _, it in ipairs(set) do add(it[1]); add(make_int32(it[2])) end
    end
    -- gold, target acquisition
    add(make_int32(t.gold or 12500)); add(make_float32(-1.0))
    -- hero section
    add(make_int32(t.level or 1))
    if v8 then add(make_int32(t.str or 0)); add(make_int32(t.agi or 0)); add(make_int32(t.int or 0)) end
    add(make_int32(#(t.inventory or {})))
    for _, it in ipairs(t.inventory or {}) do add(make_int32(it[1])); add(it[2]) end
    -- abilities
    add(make_int32(#(t.abilities or {})))
    for _, a in ipairs(t.abilities or {}) do add(a[1]); add(make_int32(a[2])); add(make_int32(a[3])) end
    -- random section
    local flag = t.random_flag or 0
    add(make_int32(flag))
    if flag == 0 then
        add(make_int32(t.random_level or -1):sub(1, 3)); add(string.char(t.item_class or 0))
    elseif flag == 1 then
        add(make_int32(t.group or 0)); add(make_int32(t.position or 0))
    elseif flag == 2 then
        add(make_int32(#t.choices))
        for _, c in ipairs(t.choices) do add(c[1]); add(make_int32(c[2])) end
    end
    -- custom color, waygate, creation number
    add(make_int32(-1)); add(make_int32(t.waygate or -1)); add(make_int32(t.creation or 0))
    return table.concat(p)
end
-- }}}

-- {{{ make_file
local function make_file(entries, version)
    version = version or 8
    return "W3do" .. make_int32(version) .. make_int32(version >= 8 and 11 or 9)
        .. make_int32(#entries) .. table.concat(entries)
end
-- }}}
-- }}}

-- {{{ Test: is_hero function
print("Test: is_hero function")
do
    -- Heroes have capital first letter
    assert_true(unitsdoo.is_hero("Hpal"), "Hpal should be hero")
    assert_true(unitsdoo.is_hero("Obla"), "Obla should be hero")
    assert_true(unitsdoo.is_hero("Udea"), "Udea should be hero")
    assert_true(unitsdoo.is_hero("Edem"), "Edem should be hero")

    -- Regular units have lowercase first letter
    assert_true(not unitsdoo.is_hero("hfoo"), "hfoo should not be hero")
    assert_true(not unitsdoo.is_hero("ogru"), "ogru should not be hero")
    assert_true(not unitsdoo.is_hero("ugho"), "ugho should not be hero")
    assert_true(not unitsdoo.is_hero("earc"), "earc should not be hero")

    -- Edge cases
    assert_true(not unitsdoo.is_hero(""), "empty string should not be hero")
    assert_true(not unitsdoo.is_hero(nil), "nil should not be hero")

    -- Random unit/item placeholders start with Y but aren't heroes
    assert_true(not unitsdoo.is_hero("YYU5"), "YYU5 (random unit) should not be hero")
    assert_true(not unitsdoo.is_hero("YYI3"), "YYI3 (random item) should not be hero")
end
print("  PASSED")
-- }}}

-- {{{ Test: invalid data handling
print("Test: invalid data handling")
do
    local result, err = unitsdoo.parse(nil)
    assert_nil(result, "nil data should return nil")
    assert_true(err ~= nil, "nil data should return error")

    result, err = unitsdoo.parse("")
    assert_nil(result, "empty data should return nil")

    result, err = unitsdoo.parse("short")
    assert_nil(result, "short data should return nil")

    result, err = unitsdoo.parse("XXXX" .. string.rep("\0", 12))
    assert_nil(result, "invalid file ID should return nil")
    assert_true(err:find("Invalid file ID"), "error should mention file ID")
end
print("  PASSED")
-- }}}

-- {{{ Test: empty file (header only)
print("Test: empty file (header only)")
do
    local data = "W3do"              -- File ID
        .. make_int32(8)             -- Version
        .. make_int32(11)            -- Subversion
        .. make_int32(0)             -- Unit count = 0

    local result, err = unitsdoo.parse(data)
    assert_true(result ~= nil, "empty file should parse: " .. tostring(err))
    assert_eq(result.version, 8, "version should be 8")
    assert_eq(result.subversion, 11, "subversion should be 11")
    assert_eq(#result.units, 0, "should have 0 units")
end
print("  PASSED")
-- }}}

-- {{{ Test: single unit entry (no hero, no items, no abilities)
print("Test: single unit entry (basic)")
do
    local data = make_file({ make_entry({
        id = "hfoo", x = 1024.0, y = 2048.0, z = 0.0, angle = 3.14159,
        player = 0, hp = -1, mp = -1, creation = 1 }) })

    local result, err = unitsdoo.parse(data)
    assert_true(result ~= nil, "single unit should parse: " .. tostring(err))
    assert_eq(#result.units, 1, "should have 1 unit")

    local u = result.units[1]
    assert_eq(u.id, "hfoo", "type ID should be hfoo")
    assert_true(not u.is_hero, "hfoo should not be hero")
    assert_eq(u.variation, 0, "variation should be 0")
    assert_near(u.position.x, 1024.0, 0.1, "x position")
    assert_near(u.position.y, 2048.0, 0.1, "y position")
    assert_near(u.position.z, 0.0, 0.1, "z position")
    assert_near(u.angle, 3.14159, 0.001, "angle")
    assert_near(u.scale.x, 1.0, 0.01, "x scale")
    assert_near(u.scale.y, 1.0, 0.01, "y scale")
    assert_near(u.scale.z, 1.0, 0.01, "z scale")
    assert_eq(u.player, 0, "player should be 0")
    assert_eq(u.hp, -1, "hp should be -1 (default)")
    assert_eq(u.mp, -1, "mp should be -1 (default)")
    assert_eq(u.gold, 12500, "gold should be 12500 (default)")
    assert_near(u.target_acquisition, -1.0, 0.001, "target acquisition should be -1 (normal)")
    assert_eq(u.custom_color, -1, "custom color should be -1 (the player's)")
    assert_eq(u.waygate_dest, -1, "waygate should be -1")
    assert_eq(u.creation_number, 1, "creation number should be 1")
    assert_eq(result.tail_raw, "", "every byte read")
end
print("  PASSED")
-- }}}

-- {{{ Test: hero unit entry
print("Test: hero unit entry")
do
    local data = make_file({ make_entry({
        id = "Hpal", x = 100.0, y = 200.0, hp = 100, mp = 50, level = 1, creation = 2 }) })

    local result, err = unitsdoo.parse(data)
    assert_true(result ~= nil, "hero unit should parse: " .. tostring(err))
    assert_eq(#result.units, 1, "should have 1 unit")

    local u = result.units[1]
    assert_eq(u.id, "Hpal", "type ID should be Hpal")
    assert_true(u.is_hero, "Hpal should be hero")
    assert_eq(u.hp, 100, "hp should be 100")
    assert_eq(u.mp, 50, "mp should be 50")
    assert_eq(u.creation_number, 2, "creation number should be 2")
end
print("  PASSED")
-- }}}

-- {{{ Test: unit with item drops
print("Test: unit with item drops")
do
    local data = make_file({ make_entry({
        id = "hfoo", table_pointer = 0,
        sets = {
            { { "rat6", 50 }, { "rat9", 25 } },   -- set 1: 2 items
            { { "afac", 100 } },                  -- set 2: 1 item
        },
        creation = 3 }) })

    local result, err = unitsdoo.parse(data)
    assert_true(result ~= nil, "unit with items should parse: " .. tostring(err))

    local u = result.units[1]
    assert_eq(u.id, "hfoo", "type ID should be hfoo")
    assert_eq(u.item_drops.table_pointer, 0, "table pointer should be 0")
    assert_eq(#u.item_drops.sets, 2, "should have 2 item sets")
    assert_eq(u.creation_number, 3, "creation number should be 3")

    -- Verify first set has 2 items
    assert_eq(#u.item_drops.sets[1].items, 2, "set 1 should have 2 items")
    assert_eq(u.item_drops.sets[1].items[1].id, "rat6", "set 1 item 1 should be rat6")
    assert_eq(u.item_drops.sets[1].items[1].chance, 50, "set 1 item 1 should have 50% chance")

    -- Verify second set has 1 item
    assert_eq(#u.item_drops.sets[2].items, 1, "set 2 should have 1 item")
    assert_eq(u.item_drops.sets[2].items[1].id, "afac", "set 2 item 1 should be afac")
    assert_eq(u.item_drops.sets[2].items[1].chance, 100, "set 2 item 1 should have 100% chance")
end
print("  PASSED")
-- }}}

-- {{{ Test: unit with abilities
print("Test: unit with abilities")
do
    local data = make_file({ make_entry({
        id = "hfoo",
        abilities = {
            { "AHhb", 1, 1 },  -- Holy Light, autocast, level 1
            { "AHds", 0, 2 },  -- Divine Shield, no autocast, level 2
            { "AHad", 1, 3 },  -- Devotion Aura, autocast, level 3
        },
        creation = 4 }) })

    local result, err = unitsdoo.parse(data)
    assert_true(result ~= nil, "unit with abilities should parse: " .. tostring(err))

    local u = result.units[1]
    assert_eq(#u.abilities, 3, "should have 3 abilities")
    assert_eq(u.creation_number, 4, "creation number should be 4")

    -- Verify first ability (Holy Light, autocast, level 1)
    assert_eq(u.abilities[1].id, "AHhb", "ability 1 id should be AHhb")
    assert_true(u.abilities[1].autocast, "ability 1 should have autocast")
    assert_eq(u.abilities[1].level, 1, "ability 1 level should be 1")

    -- Verify second ability (Divine Shield, no autocast, level 2)
    assert_eq(u.abilities[2].id, "AHds", "ability 2 id should be AHds")
    assert_true(not u.abilities[2].autocast, "ability 2 should not have autocast")
    assert_eq(u.abilities[2].level, 2, "ability 2 level should be 2")

    -- Verify third ability (Devotion Aura, autocast, level 3)
    assert_eq(u.abilities[3].id, "AHad", "ability 3 id should be AHad")
    assert_true(u.abilities[3].autocast, "ability 3 should have autocast")
    assert_eq(u.abilities[3].level, 3, "ability 3 level should be 3")
end
print("  PASSED")
-- }}}

-- {{{ Test: random unit types (202e; flags as the editor writes them, 202f)
print("Test: random unit types")
do
    local data = make_file({
        -- flag 0 on a random unit: a unit of level 5
        make_entry({ id = "uDNR", random_flag = 0, random_level = 5, creation = 100 }),
        -- flag 1: from random group 3, its column 1
        make_entry({ id = "hfoo", random_flag = 1, group = 3, position = 1, creation = 101 }),
        -- flag 0 on a random item: an item of level 3, class 1
        make_entry({ id = "iDNR", random_flag = 0, random_level = 3, item_class = 1, creation = 102 }),
        -- a waygate, not random (flag 0, level -1)
        make_entry({ id = "nwgt", waygate = 42, creation = 103 }),
        -- flag 2: from a table of its own
        make_entry({ id = "uDNR", random_flag = 2,
            choices = { { "hfoo", 60 }, { "hkni", 40 } }, creation = 104 }),
    })

    local result, err = unitsdoo.parse(data)
    assert_true(result ~= nil, "random units should parse: " .. tostring(err))
    assert_eq(#result.units, 5, "should have 5 units")

    -- Unit 1: Random unit of level 5
    local u1 = result.units[1]
    assert_true(u1.random_unit ~= nil, "unit 1 should have random_unit")
    assert_eq(u1.random_unit.flag, 0, "unit 1 random flag should be 0")
    assert_eq(u1.random_unit.type, "unit", "unit 1 should be random unit type")
    assert_eq(u1.random_unit.level, 5, "unit 1 should be level 5")
    assert_eq(u1.waygate_dest, -1, "unit 1 waygate should be inactive")
    assert_eq(u1.creation_number, 100, "unit 1 creation number")

    -- Unit 2: Random from group
    local u2 = result.units[2]
    assert_true(u2.random_unit ~= nil, "unit 2 should have random_unit")
    assert_eq(u2.random_unit.flag, 1, "unit 2 random flag should be 1")
    assert_eq(u2.random_unit.group_index, 3, "unit 2 group index should be 3")
    assert_eq(u2.random_unit.position, 1, "unit 2 position should be 1")
    assert_eq(u2.creation_number, 101, "unit 2 creation number")

    -- Unit 3: Random item of level 3
    local u3 = result.units[3]
    assert_true(u3.random_unit ~= nil, "unit 3 should have random_unit")
    assert_eq(u3.random_unit.flag, 0, "unit 3 random flag should be 0")
    assert_eq(u3.random_unit.type, "item", "unit 3 should be random item type")
    assert_eq(u3.random_unit.level, 3, "unit 3 should be level 3")
    assert_eq(u3.random_unit.item_class, 1, "unit 3 item class should be 1")
    assert_eq(u3.creation_number, 102, "unit 3 creation number")

    -- Unit 4: Waygate with active destination
    local u4 = result.units[4]
    assert_nil(u4.random_unit, "unit 4 should not have random_unit")
    assert_eq(u4.waygate_dest, 42, "unit 4 waygate should be region 42")
    assert_eq(u4.creation_number, 103, "unit 4 creation number")

    -- Unit 5: from its own table
    local u5 = result.units[5]
    assert_eq(u5.random_unit and u5.random_unit.flag, 2, "unit 5 random flag should be 2")
    assert_eq(u5.random_unit and #u5.random_unit.choices, 2, "unit 5 should have 2 choices")
    assert_eq(u5.random_unit and u5.random_unit.choices[2].id, "hkni", "unit 5 choice 2 id")
    assert_eq(u5.random_unit and u5.random_unit.choices[2].chance, 40, "unit 5 choice 2 chance")
    assert_eq(u5.creation_number, 104, "unit 5 creation number")
end
print("  PASSED")
-- }}}

-- {{{ Test: decode_random_level
print("Test: decode_random_level")
do
    -- Test digit levels
    assert_eq(unitsdoo.decode_random_level("0"), 0, "level 0")
    assert_eq(unitsdoo.decode_random_level("5"), 5, "level 5")
    assert_eq(unitsdoo.decode_random_level("9"), 9, "level 9")

    -- Test letter levels
    assert_eq(unitsdoo.decode_random_level("A"), 10, "level A=10")
    assert_eq(unitsdoo.decode_random_level("B"), 11, "level B=11")
    assert_eq(unitsdoo.decode_random_level("Z"), 35, "level Z=35")

    -- Test edge cases
    assert_eq(unitsdoo.decode_random_level(" "), 0, "invalid char returns 0")
end
print("  PASSED")
-- }}}

-- {{{ Test: UnitTable class
print("Test: UnitTable class")
do
    local data = make_file({
        make_entry({ id = "hfoo", x = 100.0, y = 100.0, player = 0, creation = 10 }),
        make_entry({ id = "ogru", x = 200.0, y = 200.0, player = 1, creation = 11 }),
    })

    local ut = unitsdoo.new(data)

    assert_eq(ut:count(), 2, "should have 2 units")

    -- Test get by creation number
    local u1 = ut:get(10)
    assert_true(u1 ~= nil, "should find unit 10")
    assert_eq(u1.id, "hfoo", "unit 10 should be hfoo")

    local u2 = ut:get(11)
    assert_true(u2 ~= nil, "should find unit 11")
    assert_eq(u2.id, "ogru", "unit 11 should be ogru")

    -- Test get by type
    local footmen = ut:get_by_type("hfoo")
    assert_eq(#footmen, 1, "should have 1 footman")

    -- Test get by player
    local p0_units = ut:get_by_player(0)
    assert_eq(#p0_units, 1, "player 0 should have 1 unit")

    local p1_units = ut:get_by_player(1)
    assert_eq(#p1_units, 1, "player 1 should have 1 unit")

    -- Test types()
    local types = ut:types()
    assert_eq(#types, 2, "should have 2 types")

    -- Test in_bounds
    local in_box = ut:in_bounds(50, 50, 150, 150)
    assert_eq(#in_box, 1, "should find 1 unit in box")
    assert_eq(in_box[1].id, "hfoo", "unit in box should be hfoo")
end
print("  PASSED")
-- }}}

-- {{{ Test: format output
print("Test: format output")
do
    local data = make_file({ make_entry({ id = "Hpal", x = 100.0, y = 200.0, level = 1, creation = 1 }) })

    local result = unitsdoo.parse(data)
    local output = unitsdoo.format(result)

    assert_true(output:find("Units"), "format should contain 'Units'")
    assert_true(output:find("Hpal"), "format should contain 'Hpal'")
    assert_true(output:find("HERO"), "format should contain 'HERO'")
    assert_true(output:find("Heroes: 1"), "format should show 1 hero")
end
print("  PASSED")
-- }}}

-- {{{ Test: hero data parsing (202d)
print("Test: hero data parsing (202d)")
do
    -- A hero with level, stats, and inventory; abilities follow the
    -- hero section, so one is given to check the order
    local data = make_file({ make_entry({
        id = "Hpal", x = 100.0, y = 200.0,
        level = 5, str = 2, agi = 0, int = 3,
        inventory = { { 0, "bspd" }, { 2, "rin1" } },
        abilities = { { "AHhb", 0, 2 } },
        creation = 100 }) })

    local result, err = unitsdoo.parse(data)
    assert_true(result ~= nil, "hero with data should parse: " .. tostring(err))
    assert_eq(#result.units, 1, "should have 1 unit")

    local u = result.units[1]
    assert_true(u.is_hero, "should be hero")
    assert_true(u.hero_data ~= nil, "hero should have hero_data")

    -- Check hero level and stats
    local h = u.hero_data
    assert_eq(h.level, 5, "hero level should be 5")
    assert_eq(h.str_bonus, 2, "str bonus should be 2")
    assert_eq(h.agi_bonus, 0, "agi bonus should be 0")
    assert_eq(h.int_bonus, 3, "int bonus should be 3")

    -- Check inventory
    assert_eq(h.inventory[0], "bspd", "slot 0 should have bspd (Boots of Speed)")
    assert_eq(h.inventory[2], "rin1", "slot 2 should have rin1 (Ring of Protection)")
    assert_nil(h.inventory[1], "slot 1 should be empty")
    assert_nil(h.inventory[3], "slot 3 should be empty")
    assert_nil(h.inventory[4], "slot 4 should be empty")
    assert_nil(h.inventory[5], "slot 5 should be empty")

    assert_eq(u.abilities[1] and u.abilities[1].id, "AHhb", "ability after the hero section")
    assert_eq(u.abilities[1] and u.abilities[1].level, 2, "ability level")
    assert_eq(u.creation_number, 100, "creation number")
end
print("  PASSED")
-- }}}

-- {{{ Test: non-hero has nil hero_data
print("Test: non-hero has nil hero_data")
do
    -- every entry has the hero section; a non-hero's isn't kept as hero_data
    local data = make_file({ make_entry({ id = "hfoo", level = 1, creation = 101 }) })

    local result, err = unitsdoo.parse(data)
    assert_true(result ~= nil, "non-hero should parse: " .. tostring(err))

    local u = result.units[1]
    assert_true(not u.is_hero, "should not be hero")
    assert_nil(u.hero_data, "non-hero should have nil hero_data")
    assert_eq(u.creation_number, 101, "creation number")
end
print("  PASSED")
-- }}}

-- {{{ Test: a non-hero's inventory (202f)
print("Test: a non-hero's inventory (202f)")
do
    local data = make_file({ make_entry({ id = "h00U", inventory = { { 0, "I01M" } }, creation = 50 }) })

    local result, err = unitsdoo.parse(data)
    assert_true(result ~= nil, "non-hero with items should parse: " .. tostring(err))
    local u = result.units[1]
    assert_nil(u.hero_data, "still no hero_data")
    assert_eq(u.inventory[0], "I01M", "its item in slot 0")
    assert_eq(u.creation_number, 50, "creation number")
end
print("  PASSED")
-- }}}

-- {{{ Test: a Reign of Chaos file (version 7, 202f)
print("Test: a Reign of Chaos file (version 7, 202f)")
do
    -- no item table pointer, no stat bonuses
    local data = make_file({
        make_entry({ id = "sloc", version = 7, creation = 0 }),
        make_entry({ id = "Hpal", version = 7, level = 3, inventory = { { 1, "bspd" } },
            sets = { { { "ratc", 100 } } }, creation = 1 }),
    }, 7)

    local result, err = unitsdoo.parse(data)
    assert_true(result ~= nil, "a version 7 file should parse: " .. tostring(err))
    assert_eq(result and #result.units, 2, "2 units")
    local h = result and result.units[2]
    assert_eq(h and h.item_drops.table_pointer, -1, "no table pointer reads as -1")
    assert_eq(h and h.item_drops.sets[1].items[1].id, "ratc", "its drop")
    assert_eq(h and h.hero_data.level, 3, "hero level")
    assert_eq(h and h.hero_data.inventory[1], "bspd", "inventory")
    assert_eq(h and h.creation_number, 1, "creation number")
    assert_eq(result and result.tail_raw, "", "every byte read")
end
print("  PASSED")
-- }}}

-- {{{ Test: damaged files fail with a message (202f)
print("Test: damaged files fail with a message (202f)")
do
    local whole = make_file({ make_entry({ id = "hfoo", creation = 1 }), make_entry({ id = "hkni", creation = 2 }) })

    -- cut inside the second unit
    local result, err = unitsdoo.parse(whole:sub(1, #whole - 10))
    assert_nil(result, "a cut file should not parse")
    assert_true(err and err:find("unit 2/2") and err:find("past the end"), "the message names the unit: " .. tostring(err))

    -- a count that can't fit
    local bad = make_file({ make_entry({ id = "hfoo", abilities = { { "AHhb", 0, 1 } } }) })
    local at = bad:find(make_int32(1) .. "AHhb", 1, true)
    bad = bad:sub(1, at - 1) .. make_int32(100000) .. bad:sub(at + 4)
    result, err = unitsdoo.parse(bad)
    assert_nil(result, "an impossible ability count should not parse")
    assert_true(err and err:find("ability count"), "the message names the count: " .. tostring(err))

    -- an unknown random flag
    result, err = unitsdoo.parse(make_file({ make_entry({ id = "hfoo", random_flag = 7 }) }))
    assert_nil(result, "an unknown random flag should not parse")
    assert_true(err and err:find("random flag 7"), "the message names the flag: " .. tostring(err))
end
print("  PASSED")
-- }}}

-- {{{ Test: hero format output includes hero details
print("Test: hero format output includes hero details")
do
    local data = make_file({ make_entry({
        id = "Hamg", level = 10, str = 5, agi = 3, int = 7,
        inventory = { { 0, "phea" } }, creation = 200 }) })

    local result = unitsdoo.parse(data)
    local output = unitsdoo.format(result)

    -- Check format output includes hero details
    assert_true(output:find("Hero details"), "format should have 'Hero details' section")
    assert_true(output:find("Lv%.10"), "format should show level 10")
    assert_true(output:find("STR%+5"), "format should show STR+5")
    assert_true(output:find("AGI%+3"), "format should show AGI+3")
    assert_true(output:find("INT%+7"), "format should show INT+7")
    assert_true(output:find("Inventory"), "format should show inventory")
end
print("  PASSED")
-- }}}

-- {{{ Test: real map files
print("")
print("=== Testing real map files ===")

local mpq = require("mpq")

-- Test map directories
local TEST_MAP_DIR = os.getenv("TEST_MAP_DIR") or DIR .. "/assets"

-- Get list of map files
local handle = io.popen('find "' .. TEST_MAP_DIR .. '" -name "*.w3x" -o -name "*.w3m" 2>/dev/null')
local map_list = {}
if handle then
    for line in handle:lines() do
        map_list[#map_list + 1] = line
    end
    handle:close()
end

if #map_list == 0 then
    print("No test maps found in " .. TEST_MAP_DIR)
    print("Set TEST_MAP_DIR environment variable to test with real maps")
else
    local total_units = 0
    local total_heroes = 0
    local maps_with_units = 0

    for _, map_path in ipairs(map_list) do
        local map_name = map_path:match("([^/]+)$")

        local ok, archive = pcall(mpq.open, map_path)
        if not ok then
            print(string.format("  [SKIP] %s: %s", map_name, tostring(archive)))
        else
            -- Try to extract war3mapUnits.doo
            local has_file = archive:has("war3mapUnits.doo")
            if has_file then
                local data, extract_err = archive:extract("war3mapUnits.doo")
                if data then
                    local result, parse_err = unitsdoo.parse(data)
                    tests_run = tests_run + 1
                    -- the entries take every byte of the file (202f): a
                    -- layout that reads wrong ends early or runs past
                    if result and result.tail_raw ~= "" then
                        result, parse_err = nil, string.format("%d bytes left after the last unit",
                            #result.tail_raw)
                    end
                    if result then
                        tests_passed = tests_passed + 1
                        local hero_count = 0
                        for _, u in ipairs(result.units) do
                            if u.is_hero then hero_count = hero_count + 1 end
                        end
                        total_units = total_units + #result.units
                        total_heroes = total_heroes + hero_count
                        if #result.units > 0 then
                            maps_with_units = maps_with_units + 1
                        end
                        print(string.format("  [OK] %s: %d units (%d heroes), v%d",
                            map_name, #result.units, hero_count, result.version))
                    else
                        print(string.format("  [FAIL] %s: %s", map_name, tostring(parse_err)))
                    end
                else
                    tests_run = tests_run + 1
                    print(string.format("  [SKIP] %s: extract failed - %s",
                        map_name, tostring(extract_err)))
                end
            else
                -- File doesn't exist in map (might be protected or no preplaced units)
                print(string.format("  [SKIP] %s: no war3mapUnits.doo", map_name))
            end
            archive:close()
        end
    end

    print("")
    print(string.format("Maps tested: %d", #map_list))
    print(string.format("Maps with units: %d", maps_with_units))
    print(string.format("Total units parsed: %d", total_units))
    print(string.format("Total heroes: %d", total_heroes))
end
-- }}}

-- {{{ Summary
print("")
print("========================================")
print(string.format("Tests passed: %d / %d", tests_passed, tests_run))
if tests_passed == tests_run then
    print("All tests PASSED!")
    os.exit(0)
else
    print("Some tests FAILED!")
    os.exit(1)
end
-- }}}

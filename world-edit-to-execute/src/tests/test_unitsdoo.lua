#!/usr/bin/env lua
-- Test suite for war3mapUnits.doo parser (Issue 202a)
-- Tests header parsing, basic fields, and skip logic for variable sections.
-- Run from project root: luajit src/tests/test_unitsdoo.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
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
    -- Build a minimal unit entry
    local unit_entry = "hfoo"          -- Type ID (Footman)
        .. make_int32(0)               -- Variation
        .. make_float32(1024.0)        -- X position
        .. make_float32(2048.0)        -- Y position
        .. make_float32(0.0)           -- Z position
        .. make_float32(3.14159)       -- Angle (pi radians)
        .. make_float32(1.0)           -- X scale
        .. make_float32(1.0)           -- Y scale
        .. make_float32(1.0)           -- Z scale
        .. string.char(0)              -- Flags
        .. make_int32(0)               -- Player 0 (Red)
        .. string.char(0, 0)           -- Unknown bytes
        .. make_int32(-1)              -- HP (default)
        .. make_int32(-1)              -- MP (default)
        -- Item drops section (empty)
        .. make_int32(-1)              -- Item table pointer
        .. make_int32(0)               -- Num item sets
        -- Abilities section (empty)
        .. make_int32(0)               -- Num abilities
        -- No hero data (not a hero)
        -- Random unit section
        .. make_int32(0)               -- Not random
        -- Waygate and creation number
        .. make_int32(-1)              -- Waygate dest (inactive)
        .. make_int32(1)               -- Creation number

    local data = "W3do"
        .. make_int32(8)
        .. make_int32(11)
        .. make_int32(1)               -- 1 unit
        .. unit_entry

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
    assert_eq(u.waygate_dest, -1, "waygate should be -1")
    assert_eq(u.creation_number, 1, "creation number should be 1")
end
print("  PASSED")
-- }}}

-- {{{ Test: hero unit entry
print("Test: hero unit entry")
do
    -- Build a hero unit entry
    local unit_entry = "Hpal"          -- Type ID (Paladin - hero)
        .. make_int32(0)               -- Variation
        .. make_float32(100.0)         -- X position
        .. make_float32(200.0)         -- Y position
        .. make_float32(0.0)           -- Z position
        .. make_float32(0.0)           -- Angle
        .. make_float32(1.0)           -- X scale
        .. make_float32(1.0)           -- Y scale
        .. make_float32(1.0)           -- Z scale
        .. string.char(0)              -- Flags
        .. make_int32(0)               -- Player 0
        .. string.char(0, 0)           -- Unknown bytes
        .. make_int32(100)             -- HP = 100
        .. make_int32(50)              -- MP = 50
        -- Item drops section (empty)
        .. make_int32(-1)              -- Item table pointer
        .. make_int32(0)               -- Num item sets
        -- Abilities section (empty)
        .. make_int32(0)               -- Num abilities
        -- Hero data section (required for heroes)
        .. make_int32(1)               -- Hero level = 1
        .. make_int32(0)               -- Strength bonus
        .. make_int32(0)               -- Agility bonus
        .. make_int32(0)               -- Intelligence bonus
        .. make_int32(0)               -- No inventory items
        -- Random unit section
        .. make_int32(0)               -- Not random
        -- Waygate and creation number
        .. make_int32(-1)              -- Waygate dest
        .. make_int32(2)               -- Creation number

    local data = "W3do"
        .. make_int32(8)
        .. make_int32(11)
        .. make_int32(1)               -- 1 unit
        .. unit_entry

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
    -- Build a unit with item drops
    local unit_entry = "hfoo"          -- Type ID
        .. make_int32(0)               -- Variation
        .. make_float32(0.0)           -- X position
        .. make_float32(0.0)           -- Y position
        .. make_float32(0.0)           -- Z position
        .. make_float32(0.0)           -- Angle
        .. make_float32(1.0)           -- X scale
        .. make_float32(1.0)           -- Y scale
        .. make_float32(1.0)           -- Z scale
        .. string.char(0)              -- Flags
        .. make_int32(0)               -- Player 0
        .. string.char(0, 0)           -- Unknown bytes
        .. make_int32(-1)              -- HP (default)
        .. make_int32(-1)              -- MP (default)
        -- Item drops section (2 sets, items in each)
        .. make_int32(0)               -- Item table pointer
        .. make_int32(2)               -- 2 item sets
        -- Set 1: 2 items
        .. make_int32(2)               -- 2 items in set
        .. "rat6" .. make_int32(50)    -- Item 1: 50% chance
        .. "rat9" .. make_int32(25)    -- Item 2: 25% chance
        -- Set 2: 1 item
        .. make_int32(1)               -- 1 item in set
        .. "afac" .. make_int32(100)   -- Item: 100% chance
        -- Abilities section (empty)
        .. make_int32(0)               -- Num abilities
        -- No hero data
        -- Random unit section
        .. make_int32(0)               -- Not random
        -- Waygate and creation number
        .. make_int32(-1)
        .. make_int32(3)

    local data = "W3do"
        .. make_int32(8)
        .. make_int32(11)
        .. make_int32(1)
        .. unit_entry

    local result, err = unitsdoo.parse(data)
    assert_true(result ~= nil, "unit with items should parse: " .. tostring(err))

    local u = result.units[1]
    assert_eq(u.id, "hfoo", "type ID should be hfoo")
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
    -- Build a unit with modified abilities
    local unit_entry = "hfoo"          -- Type ID
        .. make_int32(0)               -- Variation
        .. make_float32(0.0)           -- X position
        .. make_float32(0.0)           -- Y position
        .. make_float32(0.0)           -- Z position
        .. make_float32(0.0)           -- Angle
        .. make_float32(1.0)           -- X scale
        .. make_float32(1.0)           -- Y scale
        .. make_float32(1.0)           -- Z scale
        .. string.char(0)              -- Flags
        .. make_int32(0)               -- Player 0
        .. string.char(0, 0)           -- Unknown bytes
        .. make_int32(-1)              -- HP
        .. make_int32(-1)              -- MP
        -- Item drops section (empty)
        .. make_int32(-1)
        .. make_int32(0)
        -- Abilities section (3 abilities)
        .. make_int32(3)               -- 3 abilities
        .. "AHhb" .. make_int32(1) .. make_int32(1)  -- Holy Light, autocast, level 1
        .. "AHds" .. make_int32(0) .. make_int32(2)  -- Divine Shield, no autocast, level 2
        .. "AHad" .. make_int32(1) .. make_int32(3)  -- Devotion Aura, autocast, level 3
        -- No hero data
        -- Random unit section
        .. make_int32(0)
        -- Waygate and creation number
        .. make_int32(-1)
        .. make_int32(4)

    local data = "W3do"
        .. make_int32(8)
        .. make_int32(11)
        .. make_int32(1)
        .. unit_entry

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

-- {{{ Test: random unit types
print("Test: random unit types")
do
    -- Unit with random flag = 1 (random from level)
    local unit_entry1 = "YYU5"         -- Random unit level 5
        .. make_int32(0)               -- Variation
        .. make_float32(0.0) .. make_float32(0.0) .. make_float32(0.0)
        .. make_float32(0.0)
        .. make_float32(1.0) .. make_float32(1.0) .. make_float32(1.0)
        .. string.char(0)
        .. make_int32(0)
        .. string.char(0, 0)
        .. make_int32(-1) .. make_int32(-1)
        .. make_int32(-1) .. make_int32(0)  -- No items
        .. make_int32(0)                    -- No abilities
        -- Random unit section (flag = 1)
        .. make_int32(1)               -- Random from level
        .. "YYU5"                      -- Level data (4 bytes)
        .. make_int32(-1)
        .. make_int32(5)

    -- Unit with random flag = 2 (random from group)
    local unit_entry2 = "hfoo"
        .. make_int32(0)
        .. make_float32(0.0) .. make_float32(0.0) .. make_float32(0.0)
        .. make_float32(0.0)
        .. make_float32(1.0) .. make_float32(1.0) .. make_float32(1.0)
        .. string.char(0)
        .. make_int32(0)
        .. string.char(0, 0)
        .. make_int32(-1) .. make_int32(-1)
        .. make_int32(-1) .. make_int32(0)  -- No items
        .. make_int32(0)                    -- No abilities
        -- Random unit section (flag = 2)
        .. make_int32(2)               -- Random from group
        .. make_int32(3)               -- Group index
        .. make_int32(1)               -- Position in group
        .. make_int32(-1)
        .. make_int32(6)

    local data = "W3do"
        .. make_int32(8)
        .. make_int32(11)
        .. make_int32(2)
        .. unit_entry1
        .. unit_entry2

    local result, err = unitsdoo.parse(data)
    assert_true(result ~= nil, "random units should parse: " .. tostring(err))
    assert_eq(#result.units, 2, "should have 2 units")

    assert_eq(result.units[1].random_flag, 1, "unit 1 random flag should be 1")
    assert_eq(result.units[1].creation_number, 5, "unit 1 creation number")

    assert_eq(result.units[2].random_flag, 2, "unit 2 random flag should be 2")
    assert_eq(result.units[2].creation_number, 6, "unit 2 creation number")
end
print("  PASSED")
-- }}}

-- {{{ Test: UnitTable class
print("Test: UnitTable class")
do
    -- Create two units for different players
    local unit1 = "hfoo"
        .. make_int32(0)
        .. make_float32(100.0) .. make_float32(100.0) .. make_float32(0.0)
        .. make_float32(0.0)
        .. make_float32(1.0) .. make_float32(1.0) .. make_float32(1.0)
        .. string.char(0)
        .. make_int32(0)               -- Player 0
        .. string.char(0, 0)
        .. make_int32(-1) .. make_int32(-1)
        .. make_int32(-1) .. make_int32(0)
        .. make_int32(0)
        .. make_int32(0)
        .. make_int32(-1)
        .. make_int32(10)

    local unit2 = "ogru"
        .. make_int32(0)
        .. make_float32(200.0) .. make_float32(200.0) .. make_float32(0.0)
        .. make_float32(0.0)
        .. make_float32(1.0) .. make_float32(1.0) .. make_float32(1.0)
        .. string.char(0)
        .. make_int32(1)               -- Player 1
        .. string.char(0, 0)
        .. make_int32(-1) .. make_int32(-1)
        .. make_int32(-1) .. make_int32(0)
        .. make_int32(0)
        .. make_int32(0)
        .. make_int32(-1)
        .. make_int32(11)

    local data = "W3do"
        .. make_int32(8)
        .. make_int32(11)
        .. make_int32(2)
        .. unit1
        .. unit2

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
    local unit1 = "Hpal"
        .. make_int32(0)
        .. make_float32(100.0) .. make_float32(200.0) .. make_float32(0.0)
        .. make_float32(0.0)
        .. make_float32(1.0) .. make_float32(1.0) .. make_float32(1.0)
        .. string.char(0)
        .. make_int32(0)
        .. string.char(0, 0)
        .. make_int32(-1) .. make_int32(-1)
        .. make_int32(-1) .. make_int32(0)
        .. make_int32(0)
        -- Hero data
        .. make_int32(1) .. make_int32(0) .. make_int32(0) .. make_int32(0)
        .. make_int32(0)
        .. make_int32(0)
        .. make_int32(-1)
        .. make_int32(1)

    local data = "W3do"
        .. make_int32(8)
        .. make_int32(11)
        .. make_int32(1)
        .. unit1

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
    -- Build a hero with level, stats, and inventory
    local unit_entry = "Hpal"          -- Paladin (hero)
        .. make_int32(0)               -- Variation
        .. make_float32(100.0) .. make_float32(200.0) .. make_float32(0.0)
        .. make_float32(0.0)           -- Angle
        .. make_float32(1.0) .. make_float32(1.0) .. make_float32(1.0)
        .. string.char(0)              -- Flags
        .. make_int32(0)               -- Player 0
        .. string.char(0, 0)           -- Unknown bytes
        .. make_int32(-1) .. make_int32(-1)  -- HP/MP (default)
        -- Item drops section (empty)
        .. make_int32(-1)              -- Item table pointer
        .. make_int32(0)               -- Num item sets
        -- Abilities section (empty)
        .. make_int32(0)               -- Num abilities
        -- Hero data section
        .. make_int32(5)               -- Hero level = 5
        .. make_int32(2)               -- Strength bonus = 2 (from tomes)
        .. make_int32(0)               -- Agility bonus = 0
        .. make_int32(3)               -- Intelligence bonus = 3
        .. make_int32(2)               -- 2 inventory items
        -- Inventory item 1: Boots of Speed in slot 0
        .. make_int32(0)               -- Slot 0
        .. "bspd"                      -- Item ID (Boots of Speed)
        -- Inventory item 2: Ring of Protection in slot 2
        .. make_int32(2)               -- Slot 2
        .. "rin1"                      -- Item ID (Ring of Protection +1)
        -- Random unit section
        .. make_int32(0)               -- Not random
        -- Waygate and creation number
        .. make_int32(-1)
        .. make_int32(100)

    local data = "W3do"
        .. make_int32(8)
        .. make_int32(11)
        .. make_int32(1)
        .. unit_entry

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
end
print("  PASSED")
-- }}}

-- {{{ Test: non-hero has nil hero_data
print("Test: non-hero has nil hero_data")
do
    -- Build a regular unit (not a hero)
    local unit_entry = "hfoo"          -- Footman (not hero)
        .. make_int32(0)               -- Variation
        .. make_float32(0.0) .. make_float32(0.0) .. make_float32(0.0)
        .. make_float32(0.0)
        .. make_float32(1.0) .. make_float32(1.0) .. make_float32(1.0)
        .. string.char(0)
        .. make_int32(0)
        .. string.char(0, 0)
        .. make_int32(-1) .. make_int32(-1)
        -- Item drops section (empty)
        .. make_int32(-1) .. make_int32(0)
        -- Abilities section (empty)
        .. make_int32(0)
        -- NO hero data section (not a hero)
        -- Random unit section
        .. make_int32(0)
        -- Waygate and creation number
        .. make_int32(-1)
        .. make_int32(101)

    local data = "W3do"
        .. make_int32(8)
        .. make_int32(11)
        .. make_int32(1)
        .. unit_entry

    local result, err = unitsdoo.parse(data)
    assert_true(result ~= nil, "non-hero should parse: " .. tostring(err))

    local u = result.units[1]
    assert_true(not u.is_hero, "should not be hero")
    assert_nil(u.hero_data, "non-hero should have nil hero_data")
end
print("  PASSED")
-- }}}

-- {{{ Test: hero format output includes hero details
print("Test: hero format output includes hero details")
do
    -- Build a hero with stats
    local unit_entry = "Hamg"          -- Archmage
        .. make_int32(0)
        .. make_float32(0.0) .. make_float32(0.0) .. make_float32(0.0)
        .. make_float32(0.0)
        .. make_float32(1.0) .. make_float32(1.0) .. make_float32(1.0)
        .. string.char(0)
        .. make_int32(0)
        .. string.char(0, 0)
        .. make_int32(-1) .. make_int32(-1)
        -- Item drops (empty)
        .. make_int32(-1) .. make_int32(0)
        -- Abilities (empty)
        .. make_int32(0)
        -- Hero data
        .. make_int32(10)              -- Level 10
        .. make_int32(5)               -- STR+5
        .. make_int32(3)               -- AGI+3
        .. make_int32(7)               -- INT+7
        .. make_int32(1)               -- 1 inventory item
        .. make_int32(0) .. "phea"     -- Healing Potion in slot 0
        -- Random
        .. make_int32(0)
        -- Waygate and creation
        .. make_int32(-1)
        .. make_int32(200)

    local data = "W3do"
        .. make_int32(8)
        .. make_int32(11)
        .. make_int32(1)
        .. unit_entry

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

#!/usr/bin/env lua
--[[
Tests for ObjectDatabase

Tests the unified object database that aggregates all object data parsers.
]]

-- Setup path
package.path = "src/?.lua;src/?/init.lua;" .. package.path

local objectdb = require("parsers.objectdb")

-- {{{ Test infrastructure
local tests_run = 0
local tests_passed = 0
local current_section = ""

local function section(name)
    current_section = name
    print("\n=== " .. name .. " ===")
end

local function test(name, fn)
    tests_run = tests_run + 1
    local ok, err = pcall(fn)
    if ok then
        tests_passed = tests_passed + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name)
        print("         " .. tostring(err))
    end
end

local function assert_eq(expected, actual, msg)
    if expected ~= actual then
        error(string.format("%s: expected %s, got %s",
            msg or "Assertion failed",
            tostring(expected),
            tostring(actual)), 2)
    end
end

local function assert_true(value, msg)
    if not value then
        error(msg or "Expected true", 2)
    end
end

local function assert_false(value, msg)
    if value then
        error(msg or "Expected false", 2)
    end
end

local function assert_nil(value, msg)
    if value ~= nil then
        error(msg or "Expected nil, got " .. tostring(value), 2)
    end
end

local function assert_table(value, msg)
    if type(value) ~= "table" then
        error(msg or "Expected table, got " .. type(value), 2)
    end
end
-- }}}

-- {{{ Binary data helpers
local function int32_le(n)
    if n < 0 then
        n = 0x100000000 + n
    end
    return string.char(
        n % 256,
        math.floor(n / 256) % 256,
        math.floor(n / 65536) % 256,
        math.floor(n / 16777216) % 256
    )
end

local function char4(s)
    if #s < 4 then
        s = s .. string.rep("\0", 4 - #s)
    end
    return s:sub(1, 4)
end

local function nullstr(s)
    return s .. "\0"
end

local function null_id()
    return "\0\0\0\0"
end
-- }}}

-- {{{ Build test data
-- Simple w3u data
local function build_w3u_data()
    return int32_le(2) ..
           int32_le(1) ..      -- 1 original
           char4("hfoo") ..
           null_id() ..
           int32_le(2) ..      -- 2 mods
           char4("unam") ..
           int32_le(3) ..
           nullstr("Test Footman") ..
           null_id() ..
           char4("uhpm") ..
           int32_le(0) ..
           int32_le(500) ..
           null_id() ..
           int32_le(0)         -- 0 custom
end

-- Simple w3a data (with level/column)
local function build_w3a_data()
    return int32_le(2) ..
           int32_le(1) ..      -- 1 original
           char4("AHhb") ..
           null_id() ..
           int32_le(2) ..      -- 2 mods
           char4("amcs") ..    -- mana cost
           int32_le(0) ..
           int32_le(1) ..      -- level 1
           int32_le(0) ..
           int32_le(75) ..
           null_id() ..
           char4("amcs") ..
           int32_le(0) ..
           int32_le(2) ..      -- level 2
           int32_le(0) ..
           int32_le(65) ..
           null_id() ..
           int32_le(0)         -- 0 custom
end

-- Simple w3t data
local function build_w3t_data()
    return int32_le(2) ..
           int32_le(1) ..      -- 1 original
           char4("phea") ..
           null_id() ..
           int32_le(1) ..      -- 1 mod
           char4("igol") ..    -- gold cost
           int32_le(0) ..
           int32_le(150) ..
           null_id() ..
           int32_le(1) ..      -- 1 custom
           char4("phea") ..    -- parent
           char4("I001") ..    -- new id
           int32_le(1) ..
           char4("unam") ..
           int32_le(3) ..
           nullstr("Super Potion") ..
           char4("I001")
end

-- Simple w3q data (with level/column)
local function build_w3q_data()
    return int32_le(2) ..
           int32_le(1) ..      -- 1 original
           char4("Rhme") ..
           null_id() ..
           int32_le(1) ..      -- 1 mod
           char4("gglb") ..    -- gold base
           int32_le(0) ..
           int32_le(1) ..
           int32_le(0) ..
           int32_le(100) ..
           null_id() ..
           int32_le(0)         -- 0 custom
end
-- }}}

-- {{{ Basic Tests
section("Basic Creation")

test("create empty database", function()
    local db = objectdb.new()
    assert_true(db)
    assert_eq(0, db:count())
end)

test("load units", function()
    local db = objectdb.new()
    local ok, err = db:load_units(build_w3u_data())
    assert_true(ok, "Load failed: " .. tostring(err))
    assert_eq(1, db.counts.units)
end)

test("load abilities", function()
    local db = objectdb.new()
    local ok, err = db:load_abilities(build_w3a_data())
    assert_true(ok, "Load failed: " .. tostring(err))
    assert_eq(1, db.counts.abilities)
end)

test("load items", function()
    local db = objectdb.new()
    local ok, err = db:load_items(build_w3t_data())
    assert_true(ok, "Load failed: " .. tostring(err))
    assert_eq(2, db.counts.items)  -- 1 original + 1 custom
end)

test("load upgrades", function()
    local db = objectdb.new()
    local ok, err = db:load_upgrades(build_w3q_data())
    assert_true(ok, "Load failed: " .. tostring(err))
    assert_eq(1, db.counts.upgrades)
end)

test("load multiple types", function()
    local db = objectdb.new()
    db:load_units(build_w3u_data())
    db:load_abilities(build_w3a_data())
    db:load_items(build_w3t_data())
    db:load_upgrades(build_w3q_data())

    assert_eq(5, db:count())  -- 1 unit + 1 ability + 2 items + 1 upgrade
end)
-- }}}

-- {{{ Lookup Tests
section("Lookup")

test("get returns object", function()
    local db = objectdb.new()
    db:load_units(build_w3u_data())

    local obj = db:get("hfoo")
    assert_true(obj)
    assert_eq("hfoo", obj.id)
end)

test("get returns nil for unknown", function()
    local db = objectdb.new()
    db:load_units(build_w3u_data())

    local obj = db:get("xxxx")
    assert_nil(obj)
end)

test("has returns true for existing", function()
    local db = objectdb.new()
    db:load_units(build_w3u_data())

    assert_true(db:has("hfoo"))
end)

test("has returns false for unknown", function()
    local db = objectdb.new()
    db:load_units(build_w3u_data())

    assert_false(db:has("xxxx"))
end)

test("get_type returns correct type", function()
    local db = objectdb.new()
    db:load_units(build_w3u_data())
    db:load_abilities(build_w3a_data())
    db:load_items(build_w3t_data())

    assert_eq("unit", db:get_type("hfoo"))
    assert_eq("ability", db:get_type("AHhb"))
    assert_eq("item", db:get_type("phea"))
    assert_eq("item", db:get_type("I001"))
end)

test("get_type returns nil for unknown", function()
    local db = objectdb.new()
    assert_nil(db:get_type("xxxx"))
end)

test("get_table returns type-specific table", function()
    local db = objectdb.new()
    db:load_units(build_w3u_data())

    local tbl = db:get_table("hfoo")
    assert_true(tbl)
    -- Should be a UnitDataTable with get_stat method
    assert_true(tbl.get_stat)
end)
-- }}}

-- {{{ Stat Access Tests
section("Stat Access")

test("get_stat for unit", function()
    local db = objectdb.new()
    db:load_units(build_w3u_data())

    local hp = db:get_stat("hfoo", "hp")
    assert_eq(500, hp)

    local name = db:get_stat("hfoo", "name")
    assert_eq("Test Footman", name)
end)

test("get_stat for ability with level", function()
    local db = objectdb.new()
    db:load_abilities(build_w3a_data())

    local mana1 = db:get_stat("AHhb", "mana_cost", 1)
    local mana2 = db:get_stat("AHhb", "mana_cost", 2)

    assert_eq(75, mana1)
    assert_eq(65, mana2)
end)

test("get_stat for item", function()
    local db = objectdb.new()
    db:load_items(build_w3t_data())

    local gold = db:get_stat("phea", "gold_cost")
    assert_eq(150, gold)
end)

test("get_stat returns nil for unknown object", function()
    local db = objectdb.new()
    local result = db:get_stat("xxxx", "hp")
    assert_nil(result)
end)

test("get_all_stats returns table", function()
    local db = objectdb.new()
    db:load_units(build_w3u_data())

    local stats = db:get_all_stats("hfoo")
    assert_table(stats)
    assert_eq("Test Footman", stats.name)
    assert_eq(500, stats.hp)
end)
-- }}}

-- {{{ Custom Object Tests
section("Custom Objects")

test("is_custom returns true for custom", function()
    local db = objectdb.new()
    db:load_items(build_w3t_data())

    assert_true(db:is_custom("I001"))
end)

test("is_custom returns false for original", function()
    local db = objectdb.new()
    db:load_items(build_w3t_data())

    assert_false(db:is_custom("phea"))
end)

test("get_parent_id returns parent", function()
    local db = objectdb.new()
    db:load_items(build_w3t_data())

    local parent = db:get_parent_id("I001")
    assert_eq("phea", parent)
end)

test("get_parent_id returns nil for original", function()
    local db = objectdb.new()
    db:load_items(build_w3t_data())

    local parent = db:get_parent_id("phea")
    assert_nil(parent)
end)
-- }}}

-- {{{ Query Tests
section("Queries")

test("count returns total", function()
    local db = objectdb.new()
    db:load_units(build_w3u_data())
    db:load_items(build_w3t_data())

    assert_eq(3, db:count())  -- 1 unit + 2 items
end)

test("count with type filter", function()
    local db = objectdb.new()
    db:load_units(build_w3u_data())
    db:load_items(build_w3t_data())

    assert_eq(1, db:count("unit"))
    assert_eq(2, db:count("item"))
    assert_eq(0, db:count("ability"))
end)

test("all_ids returns sorted IDs", function()
    local db = objectdb.new()
    db:load_units(build_w3u_data())
    db:load_items(build_w3t_data())

    local ids = db:all_ids()
    assert_eq(3, #ids)
    -- Should be sorted
    assert_eq("I001", ids[1])
    assert_eq("hfoo", ids[2])
    assert_eq("phea", ids[3])
end)

test("all_ids with type filter", function()
    local db = objectdb.new()
    db:load_units(build_w3u_data())
    db:load_items(build_w3t_data())

    local unit_ids = db:all_ids("unit")
    assert_eq(1, #unit_ids)
    assert_eq("hfoo", unit_ids[1])

    local item_ids = db:all_ids("item")
    assert_eq(2, #item_ids)
end)
-- }}}

-- {{{ Format Tests
section("Format")

test("format produces output", function()
    local db = objectdb.new()
    db:load_units(build_w3u_data())
    db:load_items(build_w3t_data())

    local output = db:format()
    assert_true(output:find("ObjectDatabase"))
    assert_true(output:find("Total objects: 3"))
    assert_true(output:find("Units: 1"))
    assert_true(output:find("Items: 2"))
end)
-- }}}

-- {{{ Type Constants Tests
section("Type Constants")

test("TYPE constants exist", function()
    assert_eq("unit", objectdb.TYPE.UNIT)
    assert_eq("ability", objectdb.TYPE.ABILITY)
    assert_eq("item", objectdb.TYPE.ITEM)
    assert_eq("destructible", objectdb.TYPE.DESTRUCTIBLE)
    assert_eq("doodad", objectdb.TYPE.DOODAD)
    assert_eq("buff", objectdb.TYPE.BUFF)
    assert_eq("upgrade", objectdb.TYPE.UPGRADE)
end)

test("FILE_TO_TYPE mappings exist", function()
    assert_eq("unit", objectdb.FILE_TO_TYPE["war3map.w3u"])
    assert_eq("ability", objectdb.FILE_TO_TYPE["war3map.w3a"])
    assert_eq("item", objectdb.FILE_TO_TYPE["war3map.w3t"])
end)
-- }}}

-- {{{ Error Handling Tests
section("Error Handling")

test("load_units rejects invalid data", function()
    local db = objectdb.new()
    local ok, err = db:load_units("invalid")
    assert_nil(ok)
    assert_true(err and err:find("Failed"))
end)

test("load_abilities rejects invalid data", function()
    local db = objectdb.new()
    local ok, err = db:load_abilities("")
    assert_nil(ok)
    assert_true(err and err:find("Failed"))
end)
-- }}}

-- {{{ Summary
print("\n" .. string.rep("=", 60))
print(string.format("Tests: %d passed / %d total", tests_passed, tests_run))
if tests_passed == tests_run then
    print("All tests passed!")
else
    print("SOME TESTS FAILED")
    os.exit(1)
end
-- }}}

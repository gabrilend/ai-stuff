#!/usr/bin/env lua
--[[
Tests for Object Data Type-Specific Parsers

Tests all object data parsers that wrap the core objectdata.lua module:
- w3u (units)
- w3a (abilities)
- w3t (items)
- w3b (destructibles)
- w3d (doodads)
- w3h (buffs)
- w3q (upgrades)
]]

-- Setup path
package.path = "src/?.lua;src/?/init.lua;" .. package.path

local w3u = require("parsers.w3u")
local w3a = require("parsers.w3a")
local w3t = require("parsers.w3t")
local w3b = require("parsers.w3b")
local w3d = require("parsers.w3d")
local w3h = require("parsers.w3h")
local w3q = require("parsers.w3q")

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

local function assert_near(expected, actual, tolerance, msg)
    tolerance = tolerance or 0.0001
    if math.abs(expected - actual) > tolerance then
        error(string.format("%s: expected %f, got %f (tolerance %f)",
            msg or "Assertion failed",
            expected, actual, tolerance), 2)
    end
end

local function assert_true(value, msg)
    if not value then
        error(msg or "Expected true", 2)
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

local function float32_le(f)
    if f == 0 then
        return "\0\0\0\0"
    end

    local sign = 0
    if f < 0 then
        sign = 1
        f = -f
    end

    local mantissa, exponent = math.frexp(f)
    exponent = exponent + 126

    if exponent <= 0 then
        return "\0\0\0\0"
    elseif exponent >= 255 then
        return string.char(0, 0, 128, sign * 128 + 127)
    end

    mantissa = (mantissa * 2 - 1) * 8388608
    mantissa = math.floor(mantissa + 0.5)

    local b1 = mantissa % 256
    local b2 = math.floor(mantissa / 256) % 256
    local b3 = math.floor(mantissa / 65536) % 128 + (exponent % 2) * 128
    local b4 = sign * 128 + math.floor(exponent / 2)

    return string.char(b1, b2, b3, b4)
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

-- {{{ Build test data for w3u (units)
local function build_w3u_data()
    return int32_le(2) ..      -- version
           int32_le(1) ..      -- original table: 1 object
           -- Footman with modified stats
           char4("hfoo") ..    -- original_id
           null_id() ..        -- new_id (original)
           int32_le(5) ..      -- 5 modifications
           -- name (string)
           char4("unam") ..
           int32_le(3) ..
           nullstr("Veteran Footman") ..
           null_id() ..
           -- hp (int)
           char4("uhpm") ..
           int32_le(0) ..
           int32_le(600) ..
           null_id() ..
           -- move speed (real)
           char4("umvs") ..
           int32_le(1) ..
           float32_le(300.0) ..
           null_id() ..
           -- gold cost (int)
           char4("ugol") ..
           int32_le(0) ..
           int32_le(150) ..
           null_id() ..
           -- abilities (string)
           char4("uabi") ..
           int32_le(3) ..
           nullstr("Adef,Amdf") ..
           null_id() ..
           -- Custom table: 1 custom unit
           int32_le(1) ..
           char4("hfoo") ..    -- parent (footman)
           char4("h000") ..    -- custom ID
           int32_le(2) ..
           -- name
           char4("unam") ..
           int32_le(3) ..
           nullstr("Elite Guard") ..
           char4("h000") ..
           -- armor (int)
           char4("udef") ..
           int32_le(0) ..
           int32_le(5) ..
           char4("h000")
end
-- }}}

-- {{{ Build test data for w3a (abilities)
local function build_w3a_data()
    return int32_le(2) ..      -- version
           int32_le(1) ..      -- original table: 1 object
           -- Holy Bolt with level data
           char4("AHhb") ..    -- original_id
           null_id() ..        -- new_id (original)
           int32_le(5) ..      -- 5 modifications
           -- name (no level)
           char4("anam") ..
           int32_le(3) ..
           int32_le(0) ..      -- level 0 (base)
           int32_le(0) ..      -- column 0
           nullstr("Super Heal") ..
           null_id() ..
           -- mana cost level 1
           char4("amcs") ..
           int32_le(0) ..
           int32_le(1) ..      -- level 1
           int32_le(0) ..
           int32_le(60) ..
           null_id() ..
           -- mana cost level 2
           char4("amcs") ..
           int32_le(0) ..
           int32_le(2) ..      -- level 2
           int32_le(0) ..
           int32_le(70) ..
           null_id() ..
           -- mana cost level 3
           char4("amcs") ..
           int32_le(0) ..
           int32_le(3) ..      -- level 3
           int32_le(0) ..
           int32_le(80) ..
           null_id() ..
           -- cooldown level 1
           char4("acdn") ..
           int32_le(1) ..      -- real
           int32_le(1) ..
           int32_le(0) ..
           float32_le(5.0) ..
           null_id() ..
           -- Custom table empty
           int32_le(0)
end
-- }}}

-- {{{ Build test data for w3t (items)
local function build_w3t_data()
    return int32_le(2) ..      -- version
           int32_le(1) ..      -- original table: 1 object
           -- Potion of Healing
           char4("phea") ..    -- original_id
           null_id() ..        -- new_id (original)
           int32_le(6) ..      -- 6 modifications
           -- name
           char4("unam") ..
           int32_le(3) ..
           nullstr("Greater Healing Potion") ..
           null_id() ..
           -- gold cost
           char4("igol") ..
           int32_le(0) ..
           int32_le(200) ..
           null_id() ..
           -- level
           char4("ilev") ..
           int32_le(0) ..
           int32_le(5) ..
           null_id() ..
           -- hp bonus
           char4("ihtp") ..
           int32_le(0) ..
           int32_le(500) ..
           null_id() ..
           -- is_sellable
           char4("isel") ..
           int32_le(0) ..
           int32_le(1) ..
           null_id() ..
           -- uses
           char4("iuse") ..
           int32_le(0) ..
           int32_le(3) ..
           null_id() ..
           -- Custom table: 1 custom item
           int32_le(1) ..
           char4("phea") ..    -- parent
           char4("I001") ..    -- custom ID
           int32_le(3) ..
           -- name
           char4("unam") ..
           int32_le(3) ..
           nullstr("Mega Potion") ..
           char4("I001") ..
           -- hp bonus
           char4("ihtp") ..
           int32_le(0) ..
           int32_le(1000) ..
           char4("I001") ..
           -- abilities
           char4("iabi") ..
           int32_le(3) ..
           nullstr("AIhm,AIlf") ..
           char4("I001")
end
-- }}}

-- {{{ W3U Tests (Unit Parser)
section("W3U Parser (Units)")

test("parse unit data", function()
    local data = build_w3u_data()
    local result, err = w3u.parse(data)
    assert_true(result, "Parse failed: " .. tostring(err))

    local orig, cust = result:count()
    assert_eq(1, orig)
    assert_eq(1, cust)
end)

test("get_stat returns unit stat", function()
    local data = build_w3u_data()
    local result = w3u.parse(data)

    local hp = result:get_stat("hfoo", "hp")
    assert_eq(600, hp)

    local name = result:get_stat("hfoo", "name")
    assert_eq("Veteran Footman", name)
end)

test("get_stat with raw field ID", function()
    local data = build_w3u_data()
    local result = w3u.parse(data)

    local hp = result:get_stat("hfoo", "uhpm")
    assert_eq(600, hp)
end)

test("get_all_stats returns all modifications", function()
    local data = build_w3u_data()
    local result = w3u.parse(data)

    local stats = result:get_all_stats("hfoo")
    assert_table(stats)
    assert_eq("Veteran Footman", stats.name)
    assert_eq(600, stats.hp)
    assert_eq(150, stats.gold_cost)
end)

test("get_combat_stats returns combat info", function()
    local data = build_w3u_data()
    local result = w3u.parse(data)

    local combat = result:get_combat_stats("hfoo")
    assert_table(combat)
    assert_eq(600, combat.hp)
    assert_near(300.0, combat.move_speed, 0.1)
end)

test("get_costs returns resource costs", function()
    local data = build_w3u_data()
    local result = w3u.parse(data)

    local costs = result:get_costs("hfoo")
    assert_table(costs)
    assert_eq(150, costs.gold)
end)

test("get_abilities parses ability list", function()
    local data = build_w3u_data()
    local result = w3u.parse(data)

    local abilities = result:get_abilities("hfoo")
    assert_table(abilities)
    assert_eq(2, #abilities)
    assert_eq("Adef", abilities[1])
    assert_eq("Amdf", abilities[2])
end)

test("custom unit inherits from parent", function()
    local data = build_w3u_data()
    local result = w3u.parse(data)

    local custom = result:get("h000")
    assert_true(custom)
    assert_eq("hfoo", custom.parent_id)
    assert_eq("Elite Guard", result:get_stat("h000", "name"))
    assert_eq(5, result:get_stat("h000", "armor"))
end)
-- }}}

-- {{{ W3A Tests (Ability Parser)
section("W3A Parser (Abilities)")

test("parse ability data", function()
    local data = build_w3a_data()
    local result, err = w3a.parse(data)
    assert_true(result, "Parse failed: " .. tostring(err))

    local orig, cust = result:count()
    assert_eq(1, orig)
    assert_eq(0, cust)
end)

test("get_stat with level", function()
    local data = build_w3a_data()
    local result = w3a.parse(data)

    local mana1 = result:get_stat("AHhb", "mana_cost", 1)
    local mana2 = result:get_stat("AHhb", "mana_cost", 2)
    local mana3 = result:get_stat("AHhb", "mana_cost", 3)

    assert_eq(60, mana1)
    assert_eq(70, mana2)
    assert_eq(80, mana3)
end)

test("get_level_data returns all levels", function()
    local data = build_w3a_data()
    local result = w3a.parse(data)

    local levels = result:get_level_data("AHhb", "mana_cost")
    assert_table(levels)
    assert_eq(60, levels[1])
    assert_eq(70, levels[2])
    assert_eq(80, levels[3])
end)

test("get_all_stats groups by level", function()
    local data = build_w3a_data()
    local result = w3a.parse(data)

    local stats = result:get_all_stats("AHhb")
    assert_table(stats)
    assert_table(stats._levels)
    assert_table(stats._levels.mana_cost)
    assert_eq(60, stats._levels.mana_cost[1])
end)

test("get_max_level infers from modifications", function()
    local data = build_w3a_data()
    local result = w3a.parse(data)

    local max = result:get_max_level("AHhb")
    assert_eq(3, max)
end)

test("get_costs with level", function()
    local data = build_w3a_data()
    local result = w3a.parse(data)

    local costs = result:get_costs("AHhb", 1)
    assert_table(costs)
    assert_eq(60, costs.mana)
    assert_near(5.0, costs.cooldown, 0.1)
end)
-- }}}

-- {{{ W3T Tests (Item Parser)
section("W3T Parser (Items)")

test("parse item data", function()
    local data = build_w3t_data()
    local result, err = w3t.parse(data)
    assert_true(result, "Parse failed: " .. tostring(err))

    local orig, cust = result:count()
    assert_eq(1, orig)
    assert_eq(1, cust)
end)

test("get_stat returns item stat", function()
    local data = build_w3t_data()
    local result = w3t.parse(data)

    local name = result:get_stat("phea", "name")
    assert_eq("Greater Healing Potion", name)

    local gold = result:get_stat("phea", "gold_cost")
    assert_eq(200, gold)
end)

test("get_costs returns item costs", function()
    local data = build_w3t_data()
    local result = w3t.parse(data)

    local costs = result:get_costs("phea")
    assert_table(costs)
    assert_eq(200, costs.gold)
    assert_eq(5, costs.level)
end)

test("get_bonuses returns stat bonuses", function()
    local data = build_w3t_data()
    local result = w3t.parse(data)

    local bonuses = result:get_bonuses("phea")
    assert_table(bonuses)
    assert_eq(500, bonuses.hp)
end)

test("is_sellable returns correct value", function()
    local data = build_w3t_data()
    local result = w3t.parse(data)

    assert_true(result:is_sellable("phea"))
end)

test("get_uses returns charges", function()
    local data = build_w3t_data()
    local result = w3t.parse(data)

    local uses = result:get_uses("phea")
    assert_eq(3, uses)
end)

test("get_abilities parses item abilities", function()
    local data = build_w3t_data()
    local result = w3t.parse(data)

    local abilities = result:get_abilities("I001")
    assert_table(abilities)
    assert_eq(2, #abilities)
    assert_eq("AIhm", abilities[1])
    assert_eq("AIlf", abilities[2])
end)

test("custom item has correct stats", function()
    local data = build_w3t_data()
    local result = w3t.parse(data)

    local custom = result:get("I001")
    assert_true(custom)
    assert_eq("phea", custom.parent_id)

    local bonuses = result:get_bonuses("I001")
    assert_eq(1000, bonuses.hp)
end)
-- }}}

-- {{{ Build test data for w3b (destructibles)
local function build_w3b_data()
    return int32_le(2) ..      -- version
           int32_le(1) ..      -- original table: 1 object
           -- Tree
           char4("ATtr") ..    -- original_id
           null_id() ..        -- new_id (original)
           int32_le(4) ..      -- 4 modifications
           -- name (string)
           char4("bnam") ..
           int32_le(3) ..
           nullstr("Ancient Tree") ..
           null_id() ..
           -- hp (int)
           char4("bhps") ..
           int32_le(0) ..
           int32_le(250) ..
           null_id() ..
           -- walkable (int)
           char4("bwal") ..
           int32_le(0) ..
           int32_le(0) ..      -- not walkable
           null_id() ..
           -- selectable (int)
           char4("bgse") ..
           int32_le(0) ..
           int32_le(1) ..
           null_id() ..
           -- Custom table empty
           int32_le(0)
end
-- }}}

-- {{{ Build test data for w3d (doodads)
local function build_w3d_data()
    return int32_le(2) ..      -- version
           int32_le(1) ..      -- original table: 1 object
           -- Doodad with variations
           char4("DTfr") ..    -- original_id
           null_id() ..        -- new_id (original)
           int32_le(4) ..      -- 4 modifications
           -- name (base stat, no level)
           char4("dnam") ..
           int32_le(3) ..
           int32_le(0) ..      -- level 0 (base)
           int32_le(0) ..
           nullstr("Forest Tree") ..
           null_id() ..
           -- scale variation 1
           char4("dscl") ..
           int32_le(1) ..      -- real
           int32_le(1) ..      -- variation 1
           int32_le(0) ..
           float32_le(1.0) ..
           null_id() ..
           -- scale variation 2
           char4("dscl") ..
           int32_le(1) ..
           int32_le(2) ..      -- variation 2
           int32_le(0) ..
           float32_le(1.2) ..
           null_id() ..
           -- min scale (base)
           char4("dins") ..
           int32_le(1) ..
           int32_le(0) ..
           int32_le(0) ..
           float32_le(0.8) ..
           null_id() ..
           -- Custom table empty
           int32_le(0)
end
-- }}}

-- {{{ Build test data for w3h (buffs)
local function build_w3h_data()
    return int32_le(2) ..      -- version
           int32_le(1) ..      -- original table: 1 object
           -- Slow buff
           char4("Bslo") ..    -- original_id
           null_id() ..        -- new_id (original)
           int32_le(3) ..      -- 3 modifications
           -- name
           char4("fnam") ..
           int32_le(3) ..
           nullstr("Super Slow") ..
           null_id() ..
           -- tooltip
           char4("ftip") ..
           int32_le(3) ..
           nullstr("This unit is slowed.") ..
           null_id() ..
           -- icon
           char4("fart") ..
           int32_le(3) ..
           nullstr("ReplaceableTextures\\CommandButtons\\BTNSlow.blp") ..
           null_id() ..
           -- Custom table empty
           int32_le(0)
end
-- }}}

-- {{{ Build test data for w3q (upgrades)
local function build_w3q_data()
    return int32_le(2) ..      -- version
           int32_le(1) ..      -- original table: 1 object
           -- Human melee attack upgrade
           char4("Rhme") ..    -- original_id
           null_id() ..        -- new_id (original)
           int32_le(5) ..      -- 5 modifications
           -- name
           char4("gnam") ..
           int32_le(3) ..
           int32_le(0) ..      -- level 0 (base)
           int32_le(0) ..
           nullstr("Iron Forged Swords") ..
           null_id() ..
           -- gold cost level 1
           char4("gglb") ..
           int32_le(0) ..
           int32_le(1) ..
           int32_le(0) ..
           int32_le(100) ..
           null_id() ..
           -- gold cost level 2
           char4("gglb") ..
           int32_le(0) ..
           int32_le(2) ..
           int32_le(0) ..
           int32_le(150) ..
           null_id() ..
           -- gold cost level 3
           char4("gglb") ..
           int32_le(0) ..
           int32_le(3) ..
           int32_le(0) ..
           int32_le(200) ..
           null_id() ..
           -- max levels
           char4("glvl") ..
           int32_le(0) ..
           int32_le(0) ..
           int32_le(0) ..
           int32_le(3) ..
           null_id() ..
           -- Custom table empty
           int32_le(0)
end
-- }}}

-- {{{ W3B Tests (Destructible Parser)
section("W3B Parser (Destructibles)")

test("parse destructible data", function()
    local data = build_w3b_data()
    local result, err = w3b.parse(data)
    assert_true(result, "Parse failed: " .. tostring(err))

    local orig, cust = result:count()
    assert_eq(1, orig)
    assert_eq(0, cust)
end)

test("get_stat returns destructible stat", function()
    local data = build_w3b_data()
    local result = w3b.parse(data)

    local name = result:get_stat("ATtr", "name")
    assert_eq("Ancient Tree", name)

    local hp = result:get_stat("ATtr", "hp")
    assert_eq(250, hp)
end)

test("is_walkable returns correct value", function()
    local data = build_w3b_data()
    local result = w3b.parse(data)

    -- walkable was set to 0
    assert_true(not result:is_walkable("ATtr"))
end)

test("is_selectable returns correct value", function()
    local data = build_w3b_data()
    local result = w3b.parse(data)

    assert_true(result:is_selectable("ATtr"))
end)

test("get_pathing returns pathing info", function()
    local data = build_w3b_data()
    local result = w3b.parse(data)

    local pathing = result:get_pathing("ATtr")
    assert_table(pathing)
    assert_eq(0, pathing.walkable)
end)
-- }}}

-- {{{ W3D Tests (Doodad Parser)
section("W3D Parser (Doodads)")

test("parse doodad data", function()
    local data = build_w3d_data()
    local result, err = w3d.parse(data)
    assert_true(result, "Parse failed: " .. tostring(err))

    local orig, cust = result:count()
    assert_eq(1, orig)
    assert_eq(0, cust)
end)

test("get_stat with variation", function()
    local data = build_w3d_data()
    local result = w3d.parse(data)

    local scale1 = result:get_stat("DTfr", "scale", 1)
    local scale2 = result:get_stat("DTfr", "scale", 2)

    assert_near(1.0, scale1, 0.1)
    assert_near(1.2, scale2, 0.1)
end)

test("get_variation_data returns all variations", function()
    local data = build_w3d_data()
    local result = w3d.parse(data)

    local scales = result:get_variation_data("DTfr", "scale")
    assert_table(scales)
    assert_near(1.0, scales[1], 0.1)
    assert_near(1.2, scales[2], 0.1)
end)

test("get_all_stats groups by variation", function()
    local data = build_w3d_data()
    local result = w3d.parse(data)

    local stats = result:get_all_stats("DTfr")
    assert_table(stats)
    assert_table(stats._variations)
    assert_table(stats._variations.scale)
end)

test("get_scale_range returns scale info", function()
    local data = build_w3d_data()
    local result = w3d.parse(data)

    local scale = result:get_scale_range("DTfr")
    assert_table(scale)
    assert_near(0.8, scale.min, 0.1)
end)
-- }}}

-- {{{ W3H Tests (Buff Parser)
section("W3H Parser (Buffs)")

test("parse buff data", function()
    local data = build_w3h_data()
    local result, err = w3h.parse(data)
    assert_true(result, "Parse failed: " .. tostring(err))

    local orig, cust = result:count()
    assert_eq(1, orig)
    assert_eq(0, cust)
end)

test("get_stat returns buff stat", function()
    local data = build_w3h_data()
    local result = w3h.parse(data)

    local name = result:get_stat("Bslo", "name")
    assert_eq("Super Slow", name)

    local tooltip = result:get_stat("Bslo", "tooltip")
    assert_eq("This unit is slowed.", tooltip)
end)

test("get_visual returns visual info", function()
    local data = build_w3h_data()
    local result = w3h.parse(data)

    local visual = result:get_visual("Bslo")
    assert_table(visual)
    assert_true(visual.icon:find("BTNSlow"))
end)

test("get_all_stats returns all modifications", function()
    local data = build_w3h_data()
    local result = w3h.parse(data)

    local stats = result:get_all_stats("Bslo")
    assert_table(stats)
    assert_eq("Super Slow", stats.name)
end)
-- }}}

-- {{{ W3Q Tests (Upgrade Parser)
section("W3Q Parser (Upgrades)")

test("parse upgrade data", function()
    local data = build_w3q_data()
    local result, err = w3q.parse(data)
    assert_true(result, "Parse failed: " .. tostring(err))

    local orig, cust = result:count()
    assert_eq(1, orig)
    assert_eq(0, cust)
end)

test("get_stat with level", function()
    local data = build_w3q_data()
    local result = w3q.parse(data)

    local cost1 = result:get_stat("Rhme", "gold_cost", 1)
    local cost2 = result:get_stat("Rhme", "gold_cost", 2)
    local cost3 = result:get_stat("Rhme", "gold_cost", 3)

    assert_eq(100, cost1)
    assert_eq(150, cost2)
    assert_eq(200, cost3)
end)

test("get_level_data returns all levels", function()
    local data = build_w3q_data()
    local result = w3q.parse(data)

    local costs = result:get_level_data("Rhme", "gold_cost")
    assert_table(costs)
    assert_eq(100, costs[1])
    assert_eq(150, costs[2])
    assert_eq(200, costs[3])
end)

test("get_max_level returns correct value", function()
    local data = build_w3q_data()
    local result = w3q.parse(data)

    local max = result:get_max_level("Rhme")
    assert_eq(3, max)
end)

test("get_costs returns cost at level", function()
    local data = build_w3q_data()
    local result = w3q.parse(data)

    local costs = result:get_costs("Rhme", 2)
    assert_table(costs)
    assert_eq(150, costs.gold)
end)

test("get_all_stats groups by level", function()
    local data = build_w3q_data()
    local result = w3q.parse(data)

    local stats = result:get_all_stats("Rhme")
    assert_table(stats)
    assert_table(stats._levels)
    assert_table(stats._levels.gold_cost)
    assert_eq(100, stats._levels.gold_cost[1])
end)
-- }}}

-- {{{ Field Mappings Tests
section("Field Mappings")

test("w3u has correct field mappings", function()
    assert_eq("uhpm", w3u.FIELDS.hp)
    assert_eq("unam", w3u.FIELDS.name)
    assert_eq("umvs", w3u.FIELDS.move_speed)
    assert_eq("uabi", w3u.FIELDS.abilities)
end)

test("w3a has correct field mappings", function()
    assert_eq("anam", w3a.FIELDS.name)
    assert_eq("amcs", w3a.FIELDS.mana_cost)
    assert_eq("acdn", w3a.FIELDS.cooldown)
end)

test("w3t has correct field mappings", function()
    assert_eq("igol", w3t.FIELDS.gold_cost)
    assert_eq("ihtp", w3t.FIELDS.hp)
    assert_eq("iabi", w3t.FIELDS.abilities)
    assert_eq("iuse", w3t.FIELDS.uses)
end)

test("reverse mappings exist", function()
    assert_eq("hp", w3u.FIELD_NAMES["uhpm"])
    assert_eq("mana_cost", w3a.FIELD_NAMES["amcs"])
    assert_eq("gold_cost", w3t.FIELD_NAMES["igol"])
end)

test("w3b has correct field mappings", function()
    assert_eq("bnam", w3b.FIELDS.name)
    assert_eq("bhps", w3b.FIELDS.hp)
    assert_eq("bwal", w3b.FIELDS.walkable)
end)

test("w3d has correct field mappings", function()
    assert_eq("dnam", w3d.FIELDS.name)
    assert_eq("dscl", w3d.FIELDS.scale)
    assert_eq("dins", w3d.FIELDS.min_scale)
end)

test("w3h has correct field mappings", function()
    assert_eq("fnam", w3h.FIELDS.name)
    assert_eq("ftip", w3h.FIELDS.tooltip)
    assert_eq("fart", w3h.FIELDS.icon)
end)

test("w3q has correct field mappings", function()
    assert_eq("gnam", w3q.FIELDS.name)
    assert_eq("gglb", w3q.FIELDS.gold_cost)
    assert_eq("glvl", w3q.FIELDS.levels)
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

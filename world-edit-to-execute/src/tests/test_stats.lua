--[[
Tests for units' stats from the stock tables (Issue 525): field codes
looked up through the metadata table, custom types reading their parent's
row, the map's changes winning, comma-list fields, no install; and a game
built on DAoW 5.4b whose units take their stats (and combat its weapons)
from a stock source. The stock tables here are made up (their numbers
are this test's own, not the game's).
]]

-- {{{ Setup paths
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local unit_stock = require("gamedata.unit_stock")
local slk = require("parsers.slk")
-- }}}

-- {{{ Test infrastructure
local test_count, pass_count = 0, 0

local function test(name, condition, msg)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name .. (msg and ": " .. msg or ""))
    end
end

local function test_section(name)
    print("\n=== " .. name .. " ===")
end
-- }}}

-- {{{ Made-up tables, written as SYLK
local function sylk(columns, rows)
    local out = { "ID;PWXL;N;E" }
    local function cell(x, y, v)
        local val = type(v) == "number" and tostring(v) or ('"' .. tostring(v) .. '"')
        out[#out + 1] = string.format("C;X%d;Y%d;K%s", x, y, val)
    end
    for x, name in ipairs(columns) do cell(x, 1, name) end
    for y, r in ipairs(rows) do
        for x, name in ipairs(columns) do
            if r[name] ~= nil then cell(x, y + 1, r[name]) end
        end
    end
    out[#out + 1] = "E"
    return table.concat(out, "\n")
end

local META = {
    { "uhpm", "HP", "UnitBalance" }, { "umpm", "manaN", "UnitBalance" }, { "udef", "def", "UnitBalance" },
    { "usid", "sight", "UnitBalance" }, { "usin", "nsight", "UnitBalance" },
    { "ustr", "STR", "UnitBalance" }, { "uagi", "AGI", "UnitBalance" }, { "uint", "INT", "UnitBalance" },
    { "upra", "Primary", "UnitBalance" },
    { "ua1b", "dmgplus1", "UnitWeapons" }, { "ua1d", "dice1", "UnitWeapons" }, { "ua1s", "sides1", "UnitWeapons" },
    { "ua1c", "cool1", "UnitWeapons" }, { "ua1r", "rangeN1", "UnitWeapons" }, { "uacq", "acquire", "UnitWeapons" },
    { "uaen", "weapsOn", "UnitWeapons" }, { "udp1", "dmgpt1", "UnitWeapons" }, { "ubs1", "backSw1", "UnitWeapons" },
    { "ua1z", "Missilespeed", "UnitWeapons" }, { "ua1w", "weapTp1", "UnitWeapons" },
    { "umvs", "spd", "UnitData" }, { "ucol", "colors", "UnitData", 1 },
}
local meta_rows = {}
for _, m in ipairs(META) do meta_rows[#meta_rows + 1] = { ID = m[1], field = m[2], slk = m[3], index = m[4] or -1 } end

local FILES = {
    ["Units\\UnitMetaData.slk"] = sylk({ "ID", "field", "slk", "index" }, meta_rows),
    ["Units\\UnitBalance.slk"] = sylk({ "unitBalanceID", "HP", "manaN", "def", "sight", "nsight", "STR", "AGI", "INT", "Primary" }, {
        { unitBalanceID = "zz01", HP = 300, manaN = "-", def = 3, sight = 1300, nsight = 700 },
        { unitBalanceID = "zz02", HP = 100, manaN = 0, def = 1, sight = 1700, nsight = 900, STR = 20, AGI = 10, INT = 12, Primary = "STR" },
    }),
    ["Units\\UnitWeapons.slk"] = sylk({ "unitWeapID", "dmgplus1", "dice1", "sides1", "cool1", "rangeN1", "acquire", "weapsOn",
                                        "dmgpt1", "backSw1", "Missilespeed", "weapTp1" }, {
        { unitWeapID = "zz01", dmgplus1 = 10, dice1 = 2, sides1 = 3, cool1 = 1.2, rangeN1 = 90, acquire = 450, weapsOn = 1,
          dmgpt1 = 0.35, backSw1 = 0.45, Missilespeed = 0, weapTp1 = "normal" },
        { unitWeapID = "zz02", dmgplus1 = 5, dice1 = 1, sides1 = 4, cool1 = 1.8, rangeN1 = 600, acquire = 600, weapsOn = 1,
          dmgpt1 = 0.5, backSw1 = 0.3, Missilespeed = 1100, weapTp1 = "missile" },
    }),
    ["Units\\UnitData.slk"] = sylk({ "unitID", "spd", "colors" }, {
        { unitID = "zz01", spd = 280, colors = "10,20,30" }, { unitID = "zz02", spd = 300 },
    }),
}
local chain = { read = function(_, path)
    local f = FILES[path]
    if not f then error("not in the chain: " .. path) end
    return f, "test"
end }

-- the map's changes: a custom type zc01 copying zz01, with more hit points
local units = { custom = { zc01 = { parent_id = "zz01" } }, mods = { zc01 = { uhpm = 999 } } }
function units:has(id) return self.mods[id] ~= nil end
function units:get_modification(id, code) return self.mods[id] and self.mods[id][code] end
-- }}}

-- {{{ Looking values up
test_section("Values by field code")
do
    test("the made-up tables parse", slk.parse(FILES["Units\\UnitBalance.slk"]).rows.zz01.HP == 300)
    local S = unit_stock.new(chain, units)
    test("stock tables available", S.available)
    local v, from = S:value("zz01", "uhpm")
    test("a stock type's value, from the stock table", v == 300 and from == "stock")
    test("another table (weapons)", S:value("zz01", "ua1c") == 1.2 and S:value("zz01", "ua1w") == "normal")
    test("a custom type reads its parent's row", S:base("zc01") == "zz01" and S:value("zc01", "udef") == 3)
    v, from = S:value("zc01", "uhpm")
    test("but the map's change wins", v == 999 and from == "map")
    test("an entry of a comma list", S:value("zz01", "ucol") == 20)
    test("an empty cell (\"-\") is no value", S:value("zz01", "umpm") == nil)
    test("a code with no metadata row: nil", S:value("zz01", "uxyz") == nil)
    test("a type the tables don't have: nil", S:value("qq99", "uhpm") == nil)
    local none = unit_stock.new(nil, units)
    test("no install: not available", not none.available)
    test("but the map's changes still count", none:value("zc01", "uhpm") == 999 and none:value("zz01", "uhpm") == nil)
    local broken = unit_stock.new({ read = function() error("no such file") end }, units)
    test("an install without the metadata: not available, and says why", not broken.available and broken.error ~= nil)
end
-- }}}

-- {{{ A game on DAoW with a stock source
test_section("DAoW 5.4b's units with stock stats")
do
    local map_scene = require("demo.wc3map.scene")
    local game_mod = require("demo.wc3map.game")
    local s = map_scene.load(DIR .. "/assets/DAoW-5.4b-PUBLIC-TEST.w3x")
    -- every type gets the made-up zz01 row (a hero-like type the zz02 one)
    local S = unit_stock.new(chain, nil)
    local fake = { available = true }
    function fake:value(id, code)
        local v = S:stock_value(id:sub(1, 1):match("%u") and "zz02" or "zz01", code)
        return v, v ~= nil and "stock" or nil
    end
    local g = game_mod.new(s, { player = 0, minimap = false, vision = false, stock = fake })
    local r = g.stats_report()
    test("every unit type took stock values", r.types > 0 and r.stock == r.types, r.stock .. " of " .. r.types)
    local unit, hero
    for _, u in ipairs(g.units) do
        if u.spec.design == "unit" and not u.spec.hero and u.id:sub(1, 1):match("%l") then unit = unit or u end
        if u.id:sub(1, 1):match("%u") and u.spec.design == "unit" then hero = hero or u end
    end
    test("a unit's hit points and armour", unit and unit.hp_max == 300 and unit.armor == 3)
    test("its weapon: damage, cooldown, range", unit.weapon and unit.weapon.dmg_lo == 12 and unit.weapon.dmg_hi == 16
        and unit.weapon.cooldown == 1.2 and unit.weapon.range == 90)
    test("attack point and backswing", unit.weapon.attack_point == 0.35 and unit.weapon.backswing == 0.45)
    test("a normal weapon strikes at once", unit.weapon.missile == 0)
    test("sight by day and night", unit.sight_day == 1300 and unit.sight_night == 700)
    test("move speed", unit.speed == 280)
    if hero then
        test("a hero: hit points with strength (100 + 20 x 25)", hero.hp_max == 600, tostring(hero.hp_max))
        test("mana with intelligence (12 x 15)", hero.mana_max == 180)
        test("armour with agility (1 + 10 x 0.3)", math.abs(hero.armor - 4) < 1e-9)
        test("damage with its primary attribute (5 + 20 + 1 .. 5 + 20 + 4)",
            hero.weapon and hero.weapon.dmg_lo == 26 and hero.weapon.dmg_hi == 29)
        test("a missile weapon flies", hero.weapon.missile == 1100)
    end
end
-- }}}

-- {{{ Summary
print("\n" .. string.rep("=", 50))
print(string.format("Tests: %d passed, %d failed", pass_count, test_count - pass_count))
if pass_count == test_count then
    print("ALL TESTS PASSED")
else
    print("SOME TESTS FAILED")
    os.exit(1)
end
-- }}}

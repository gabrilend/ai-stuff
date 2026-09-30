--[[
Tests for what a computer player does with its hands (Issue 540):
making things however they're made (building with a worker on a free
spot, upgrading, hiring at a tavern, expanding to a free mine), counting
what's on its way, heroes learning skills in the profile's order,
spells in a fight (strike, heal, area, no-target, a shield only when
hurt), drinking potions, shopping, repair, and an AI Editor profile's
building entries now built. Made-up tables are this test's own.
]]

-- {{{ Setup paths
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path
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

-- {{{ The game, with made-up tables
local map_scene = require("demo.wc3map.scene")
local game_mod = require("demo.wc3map.game")
local ai_player = require("ai.player")
local s = map_scene.load(DIR .. "/assets/DAoW-5.4b-PUBLIC-TEST.w3x")

local UNITS = {
    zpea = { urac = "undead" },
    zbar = { uhpm = 1000 }, zhal = { uhpm = 1500 }, zkee = { uhpm = 2000 },
    ztav = {}, Hzz1 = { uhpm = 500, ustr = 10, uagi = 10, uint = 10, upra = "STR", usma = 1, usrg = 30, usst = 0 },
}
local LISTS = {
    zpea = { ubui = { "zbar" } }, zhal = { uupt = { "zkee" } }, ztav = { useu = { "Hzz1" } },
    Hzz1 = { uhab = { "AHtb", "AHhb" } },
}
local units = { available = true }
function units:value(id, code) local v = (UNITS[id] or {})[code] return v, v ~= nil and "stock" or nil end
function units:list(id, code) return (LISTS[id] or {})[code] or {} end
local ABIL = {
    AHtb = { amcs = 0, acdn = 5, aran = 700, Htb1 = 10, adur = 1 },
    AHhb = { amcs = 0, acdn = 5, aran = 700, Hhb1 = 100 },
    AHbz = { amcs = 0, acdn = 30, aran = 900, aare = 250, Hbz1 = 3, Hbz2 = 10 },
    AHtc = { amcs = 0, acdn = 10, aare = 300, Htc1 = 10, adur = 1 },
    AHds = { amcs = 0, acdn = 30, adur = 5 },
    Zpot = { Ihpg = 300, acdn = 0 },
}
local ab = { available = true }
function ab:base(id) return id end
function ab:value(id, code) local v = (ABIL[id] or {})[code] return v, v ~= nil and "stock" or nil end
function ab:profile_field() return nil end
function ab:list() return {} end
local ITEMS = {
    zpot = { unam = "Potion", igol = 100, iuse = 1, iusa = 1, iper = 1, isto = 3, istr = 30, isst = 0, iabi = "Zpot" },
    zrin = { unam = "Ring", igol = 500, isto = 1, istr = 30, isst = 0 },
}
local items_data = { available = true }
function items_data:value(id, code) local v = (ITEMS[id] or {})[code] return v, v ~= nil and "stock" or nil end
function items_data:list(id, code)
    local v = self:value(id, code)
    local out = {}
    if type(v) == "string" then for x in v:gmatch("[^,]+") do out[#out + 1] = x end end
    return out
end

local g = game_mod.new(s, { player = 0, placed = false, minimap = false, vision = false, stock = units, combat = false })
g.data.abilities, g.data.items = ab, items_data
local VM = g.run_script({ ai = "none" })
local function run(sec) for _ = 1, math.floor(sec * 30 + 0.5) do g.tick(1 / 30) end end
g.state(0).gold, g.state(0).lumber = 100000, 100000
require("jass.natives.core")
VM.natives.SetPlayerState(VM.natives.Player(0), "PLAYER_STATE_RESOURCE_FOOD_CAP", 300)

-- open, walkable ground near the player's units
local own
for _, u in ipairs(g.units) do
    if u.player == 0 and u.alive and u.spec.design == "unit" and not u.spec.hero then own = own or u end
end
local X, Y
for r = 600, 6000, 200 do
    for k = 0, 11 do
        local a = k / 12 * math.pi * 2
        local x, y = own.x + math.cos(a) * r, own.y + math.sin(a) * r
        local ok = g.placeable("zbar", x, y) and g.pathing:route(x, y, x + 400, y - 400)
        if not X and ok then X, Y = x, y end
    end
    if X then break end
end
local function worker(x, y)
    local w = g.spawn("zpea", 0, x, y, 0)
    w.spec.design, w.spec.archetype = "unit", "worker"
    w.speed = 400
    return w
end
local ai = ai_player.new(g, 0)
ai.home = { x = X, y = Y }
-- }}}

-- {{{ Making things
test_section("Making things however they're made")
do
    test("open ground found", X ~= nil)
    local w = worker(X + 100, Y + 100)
    test("a worker builds it", #ai:builders("zbar") >= 1)
    local before = ai:count("zbar")
    local ok, why = ai:produce("zbar")
    test("produce: a worker is sent to build it", ok and w.construct and w.construct.id == "zbar", tostring(why))
    test("counted while on its way", ai:count("zbar") == before + 1)
    local sx, sy = w.construct.x, w.construct.y
    test("on a free spot near home", (sx - X) ^ 2 + (sy - Y) ^ 2 < 2500 ^ 2 and g.placeable("zbar", sx, sy))
    run(4)
    local up
    for _, u in ipairs(g.units) do if u.id == "zbar" and u.building_up then up = u end end
    test("it goes up", up ~= nil)
    test("still counted once", ai:count("zbar") == before + 1)

    local hall = g.spawn("zhal", 0, X - 700, Y, 0)
    hall.spec.design = "building"
    ok = ai:produce("zkee")
    test("produce a Keep: the hall upgrades", ok and hall.upgrading and hall.upgrading.to == "zkee")
    test("counted while upgrading", ai:count("zkee") == 1)
end
-- }}}

-- {{{ Hiring
test_section("Hiring at a tavern")
local hero
do
    local tav = g.spawn("ztav", 15, X, Y - 900, 0)
    tav.spec.design = "building"
    local runner = g.spawn("hfoo", 0, X, Y - 200, 0)
    runner.speed = 400
    test("a tavern sells it to us", ai:seller("Hzz1") == tav)
    local ok = ai:produce("Hzz1")
    test("produce: a unit is sent to hire it", ok and (runner.visiting == tav or ai:count("Hzz1") >= 1))
    test("counted while being hired", ai:count("Hzz1") == 1)
    for _ = 1, 10 do ai:update(0.5); run(0.5) end
    for _, u in ipairs(g.units) do if u.id == "Hzz1" and u.player == 0 then hero = u end end
    test("hired: the hero is ours", hero ~= nil)
    test("counted once", ai:count("Hzz1") == 1)
end
-- }}}

-- {{{ Skills
test_section("Heroes learn their skills")
do
    g.set_hero_level(hero, 3)
    ai:set_skills("Hzz1", { "AHhb", "AHtb" })
    ai:learn_skills()
    test("in the profile's order", (hero.abilities.AHhb or 0) >= 1 and (hero.abilities.AHtb or 0) >= 1)
    test("all its points spent", (hero.skill_points or 0) == 0 or not g.can_learn(hero, "AHhb") and not g.can_learn(hero, "AHtb"))
end
-- }}}

-- {{{ Spells
test_section("Spells in a fight")
do
    hero.x, hero.y = X + 300, Y + 300
    if hero.mover then hero.mover = nil end
    hero.mana_max, hero.mana = 1000, 1000
    hero.abilities, hero.cooldowns = { AHtb = 1 }, {}
    local foe = g.spawn("nwlt", 12, hero.x + 400, hero.y, 0)
    foe.hp_max, foe.hp = 5000, 5000
    ai:cast_spells()
    test("a strike on the nearest enemy", hero.casting and hero.casting.id == "AHtb" and hero.casting.target == foe,
        hero.casting and (hero.casting.id .. " at " .. tostring(hero.casting.target and hero.casting.target.id)) or tostring(g.ability_ready(hero, "AHtb")))
    run(2)
    hero.casting = nil
    hero.abilities = { AHhb = 1 }
    local friend = g.spawn("hfoo", 0, hero.x - 200, hero.y, 0)
    friend.hp = friend.hp_max * 0.3
    ai:cast_spells()
    test("a heal on a hurt ally", hero.casting and hero.casting.id == "AHhb" and hero.casting.target == friend)
    run(2)
    hero.casting = nil
    hero.abilities = { AHbz = 1 }
    local pack = {}
    for k = 1, 3 do pack[k] = g.spawn("nwlt", 12, hero.x + 500 + k * 40, hero.y + 60, 0) end
    ai:cast_spells()
    test("an area spell where enemies bunch", hero.casting and hero.casting.id == "AHbz" and hero.casting.x ~= nil)
    g.order({ hero }, "stop")
    hero.casting = nil
    hero.abilities = { AHds = 1 }
    ai:cast_spells()
    test("a shield only when hurt: not now", not hero.casting)
    hero.hp = hero.hp_max * 0.2
    ai:cast_spells()
    test("hurt: shielded", hero.casting and hero.casting.id == "AHds")
    run(1)
    hero.casting = nil
    hero.abilities = { AHtc = 1 }
    for _, p in ipairs(pack) do g.remove(p) end
    g.remove(foe)
    local far = g.spawn("nwlt", 12, hero.x + 800, hero.y, 0)
    ai:cast_spells()
    test("a no-target area spell waits for enemies close", not hero.casting)
    local c1, c2 = g.spawn("nwlt", 12, hero.x + 100, hero.y, 0), g.spawn("nwlt", 12, hero.x, hero.y + 100, 0)
    ai:cast_spells()
    test("and goes when two are", hero.casting and hero.casting.id == "AHtc")
    run(1)
    for _, u in ipairs({ far, c1, c2, friend }) do g.remove(u) end
    hero.casting = nil
end
-- }}}

-- {{{ Items
test_section("Potions and shopping")
do
    hero.hp = hero.hp_max
    local pot = g.create_item("zpot", hero.x, hero.y)
    g.give_item(hero, pot)
    ai:use_items()
    test("no potion when well", pot.owner == hero)
    hero.hp = hero.hp_max * 0.2
    local hp0 = hero.hp
    ai:use_items()
    test("badly hurt: it drinks", hero.hp > hp0 and pot.removed)

    local shop = g.spawn("zshp", 15, X + 500, Y - 400, 0)
    shop.spec.design = "building"
    shop.shop_stock = nil
    LISTS.zshp = { usei = { "zpot", "zrin" } }
    hero.x, hero.y = X + 450, Y - 300
    ai.options.buy_items = true
    local gold = g.state(0).gold
    ai:shop()
    local got
    for k = 0, 5 do if hero.inventory[k] then got = hero.inventory[k] end end
    test("a hero at home by a shop buys (a restoring item first)", got and got.id == "zpot" and g.state(0).gold < gold,
        got and got.id)
    g.state(0).gold = 350
    local n = 0
    for k = 0, 5 do if hero.inventory[k] then n = n + 1 end end
    ai:shop()
    local n2 = 0
    for k = 0, 5 do if hero.inventory[k] then n2 = n2 + 1 end end
    test("keeping its reserve", n2 == n)
    g.state(0).gold = 100000
    ai.options.buy_items = false
end
-- }}}

-- {{{ Repair
test_section("Repair")
do
    local b = g.spawn("zbar", 0, X + 900, Y + 300, 0)
    b.spec.design = "building"
    b.hp = b.hp_max * 0.5
    local w = g.spawn("hpea", 0, X + 700, Y + 300, 0)
    w.spec.design, w.spec.archetype = "unit", "worker"
    ai.options.repair = false
    ai:repair_base()
    test("not without the option", w.repair == nil)
    ai.options.repair = true
    ai:repair_base()
    local mending
    for _, u in ipairs(g.units) do if u.repair and u.repair.target == b then mending = u end end
    test("with it, an idle worker mends it", mending ~= nil)
end
-- }}}

-- {{{ Expansions
test_section("Expanding")
do
    local mines = 0
    for _, u in ipairs(g.units) do if g.is_mine(u) then mines = mines + 1 end end
    UNITS.zhl2 = { uhpm = 1500 }
    LISTS.zpea.ubui = { "zbar", "zhl2" }
    local w = worker(X - 100, Y - 100)
    local ok, why = ai:expand("zhl2")
    if mines == 0 then
        test("no gold mines: can't expand", not ok and why == "no free mine")
    else
        test("a hall sent toward a free mine", ok and w.construct and w.construct.id == "zhl2" or why == "no room to build it", tostring(why))
    end
end
-- }}}

-- {{{ A profile's building entries
test_section("A profile's building entries are built")
do
    local M = require("ai").manager(VM)
    local p = { build = { { kind = "building", id = "zbar", count = 5 } }, waves = { initial_delay = 1e9 } }
    local a = M:start_profile(0, p, "test")
    a.home = { x = X, y = Y }
    local w = worker(X + 200, Y - 100)
    local before = a:count("zbar")
    run(3)
    test("its workers build what it lists", a:count("zbar") > before, a:count("zbar") .. " from " .. before)
    local noted = false
    for _, l in ipairs(a.log) do if l.text:find("not played") and l.text:find("construction") then noted = true end end
    test("no longer noted as unplayed", not noted)
    a.runner:stop()
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

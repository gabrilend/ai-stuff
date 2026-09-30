--[[
Tests for research (Issue 542): what a building researches, cost and
time by level, the queue (one level at a time, not past the last,
cancel refunds), requirements, effects on the player's units now and
later (damage, attack speed, armour, hit points, speed, an ability's
level), unknown effects left alone, levels as requirements, the
script's natives and events, the command card, and a computer player
researching. Made-up tables are this test's own.
]]

-- {{{ Setup paths
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path
local vm = require("jass.vm")
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
local function near(a, b) return math.abs(a - b) < 1e-6 end
-- }}}

-- {{{ The game, with made-up tables
local map_scene = require("demo.wc3map.scene")
local game_mod = require("demo.wc3map.game")
local s = map_scene.load(DIR .. "/assets/DAoW-5.4b-PUBLIC-TEST.w3x")

local UNITS = {
    zfor = { uhpm = 1000 }, zbig = { uhpm = 1000 },
    zfoo = { uhpm = 400, udef = 1, ua1b = 10, ua1d = 1, ua1s = 2, ua1c = 1.5, ua1r = 100, umvs = 270 },
    zpri = { uhpm = 300, umpm = 200 },
}
local LISTS = {
    zfor = { ures = { "Rzdm", "Rzar", "Rzad", "Rzxx" }, utra = { "zfoo" } },
    zfoo = { upgr = { "Rzdm", "Rzar", "Rzxx" } },
    zpri = { upgr = { "Rzad" }, uabi = { "Azhl" } },
}
local units = { available = true }
function units:value(id, code) local v = (UNITS[id] or {})[code] return v, v ~= nil and "stock" or nil end
function units:list(id, code) return (LISTS[id] or {})[code] or {} end
local UPG = {
    Rzdm = { gnam = "Sharper Swords", glvl = 3, gglb = 100, gglm = 50, glmb = 50, glmm = 25, gtib = 10, gtim = 5,
             gef1 = "ratx", gba1 = 2, gmo1 = 1, gef2 = "rats", gba2 = 0.1, gmo2 = 0.1 },
    Rzar = { gnam = "Plating", glvl = 1, gglb = 50, gtib = 5, greq = "zbig",
             gef1 = "rarm", gba1 = 2, gef2 = "rhpx", gba2 = 50, gef3 = "rmvx", gba3 = 20 },
    Rzad = { gnam = "Adept", glvl = 2, gglb = 10, gtib = 2, gef1 = "rlev", gba1 = 2, gmo1 = 1, gco1 = "Azhl" },
    Rzxx = { gnam = "Odd", glvl = 1, gglb = 1, gtib = 1, gef1 = "rzzz", gba1 = 5 },
}
local upgrades = { available = true }
function upgrades:value(id, code) local v = (UPG[id] or {})[code] return v, v ~= nil and "stock" or nil end
function upgrades:profile_field() return nil end

local g = game_mod.new(s, { player = 0, placed = false, minimap = false, vision = false, stock = units, combat = false })
g.data.upgrades = upgrades
local VM = g.run_script({ ai = "none" })
local N = VM.natives
local p0 = N.Player(0)
local function run(sec) for _ = 1, math.floor(sec * 30 + 0.5) do g.tick(1 / 30) end end
g.state(0).gold, g.state(0).lumber = 10000, 10000
N.SetPlayerState(p0, "PLAYER_STATE_RESOURCE_FOOD_CAP", 300)
local own
for _, u in ipairs(g.units) do
    if u.player == 0 and u.alive and u.spec.design == "unit" and not u.spec.hero then own = own or u end
end
local X, Y = own.x + 2000, own.y + 2000
local function building(id, x, y)
    local b = g.spawn(id, 0, x, y, 0)
    b.spec.design = "building"
    return b
end
local events = {}
for _, ev in ipairs({ "RESEARCH_START", "RESEARCH_CANCEL", "RESEARCH_FINISH" }) do
    local t = N.CreateTrigger()
    N.TriggerRegisterPlayerUnitEvent(t, p0, "EVENT_PLAYER_UNIT_" .. ev, nil)
    N.TriggerAddAction(t, function() events[#events + 1] = { ev = ev, id = N.GetResearched() } end)
end
local forge = building("zfor", X, Y)
local foot = g.spawn("zfoo", 0, X + 300, Y, 0)
foot.spec.design = "unit"
-- }}}

-- {{{ Data
test_section("What's researched, and what it costs")
do
    local r = g.researches(forge)
    test("a building's research list", #r == 4 and r[1] == "Rzdm")
    local i1, i2 = g.upgrade_info("Rzdm", 1), g.upgrade_info("Rzdm", 2)
    test("level 1: base cost and time", i1.gold == 100 and i1.lumber == 50 and i1.time == 10 and i1.max == 3)
    test("level 2: plus one increment", i2.gold == 150 and i2.lumber == 75 and i2.time == 15)
    test("its effects", #i1.effects == 2 and i1.effects[1].code == "ratx" and i1.effects[2].code == "rats")
    test("its name", i1.name == "Sharper Swords")
end
-- }}}

-- {{{ Researching
test_section("Researching")
local dmg_lo, dmg_hi, cd
do
    dmg_lo, dmg_hi, cd = foot.weapon.dmg_lo, foot.weapon.dmg_hi, foot.weapon.cooldown
    local gold = g.state(0).gold
    events = {}
    test("started", g.research(forge, "Rzdm"))
    test("paid", g.state(0).gold == gold - 100)
    test("RESEARCH_START, with the id", events[1] and events[1].ev == "RESEARCH_START" and vm.id2s(events[1].id) == "Rzdm")
    test("in the queue", forge.queue[1] and forge.queue[1].research == "Rzdm" and forge.queue[1].level == 1)
    test("the next queued is level 2 at its price", g.research(forge, "Rzdm") and forge.queue[2].level == 2
        and forge.queue[2].gold == 150)
    test("and level 3", g.research(forge, "Rzdm"))
    local ok, why = g.research(forge, "Rzdm")
    test("not past the last level", not ok and why == "fully researched", tostring(why))
    gold = g.state(0).gold
    test("cancelling the last refunds it", g.cancel_train(forge) and g.state(0).gold == gold + 200)
    test("RESEARCH_CANCEL", events[#events].ev == "RESEARCH_CANCEL")
    run(9)
    test("not done before its time", g.research_level(0, "Rzdm") == 0 and foot.weapon.dmg_lo == dmg_lo)
    run(1.5)
    test("done: level 1", g.research_level(0, "Rzdm") == 1)
    test("RESEARCH_FINISH", events[#events].ev == "RESEARCH_FINISH" and vm.id2s(events[#events].id) == "Rzdm")
    test("its units hit harder (+2)", foot.weapon.dmg_lo == dmg_lo + 2 and foot.weapon.dmg_hi == dmg_hi + 2)
    test("and faster (cooldown / 1.1)", near(foot.weapon.cooldown, cd / 1.1))
    run(15.5)
    test("level 2: +3 and cooldown / 1.2", g.research_level(0, "Rzdm") == 2 and foot.weapon.dmg_lo == dmg_lo + 3
        and near(foot.weapon.cooldown, cd / 1.2))
    local later = g.spawn("zfoo", 0, X + 400, Y, 0)
    test("a unit made later has it too", later.weapon.dmg_lo == dmg_lo + 3)
end
-- }}}

-- {{{ Requirements and other effects
test_section("Requirements, and other effects")
do
    local ok, why = g.can_research(forge, "Rzar")
    test("needs its requirement", not ok and why == "requires zbig", tostring(why))
    local big = building("zbig", X - 600, Y)
    test("which a building of that type meets", (g.can_research(forge, "Rzar")))
    local armor, hp_max, speed = foot.armor, foot.hp_max, foot.speed
    g.research(forge, "Rzar")
    run(6)
    test("armour +2", foot.armor == armor + 2)
    test("hit points +50 (and the unit gains them)", foot.hp_max == hp_max + 50 and foot.hp == foot.hp_max)
    test("move speed +20", foot.speed == speed + 20)
    local pri = g.spawn("zpri", 0, X, Y - 300, 0)
    test("an ability at level 1 first", pri.abilities.Azhl == 1)
    g.research(forge, "Rzad")
    run(3)
    test("rlev: its ability at the research's level (2)", pri.abilities.Azhl == 2, tostring(pri.abilities.Azhl))
    g.research(forge, "Rzxx")
    run(2)
    test("an unknown effect is left alone, and noted", g.research_unknown and g.research_unknown.rzzz)
    test("a research counts as a requirement", g.has_tech(0, "Rzar"))
    g.remove(big)
end
-- }}}

-- {{{ The script
test_section("The script's research")
do
    local dmg = foot.weapon.dmg_lo
    N.SetPlayerTechResearched(p0, vm.s2id("Rzdm"), 3)
    test("SetPlayerTechResearched: level 3, applied (+1 more)", g.research_level(0, "Rzdm") == 3
        and foot.weapon.dmg_lo == dmg + 1)
    test("GetPlayerTechCount", N.GetPlayerTechCount(p0, vm.s2id("Rzdm"), true) == 3)
    test("GetPlayerTechResearched", N.GetPlayerTechResearched(p0, vm.s2id("Rzdm"), true) == true
        and N.GetPlayerTechResearched(p0, vm.s2id("Rzzz"), true) == false)
    N.SetPlayerTechResearched(p0, vm.s2id("Rzdm"), 0)
    test("back to 0: taken off again", foot.weapon.dmg_lo == dmg_lo and near(foot.weapon.cooldown, cd))
    N.AddPlayerTechResearched(p0, vm.s2id("Rzdm"), 1)
    test("AddPlayerTechResearched", g.research_level(0, "Rzdm") == 1)
    test("IssueImmediateOrderById with a research id", N.IssueImmediateOrderById(forge, vm.s2id("Rzdm"))
        and forge.queue[#forge.queue].research == "Rzdm")
    g.cancel_train(forge)
end
-- }}}

-- {{{ The card, and a computer player
test_section("The command card and a computer player")
do
    local card = require("ui.wc3.commands").card(forge, g.db, "main")
    local labels, done = {}, nil
    for k = 1, 12 do
        if card[k] then labels[#labels + 1] = card[k].label end
        if card[k] and card[k].target == "Rzar" then done = card[k] end
    end
    local joined = table.concat(labels, "; ")
    test("research buttons with the next level", joined:find("Research Sharper Swords %(level 2%)") ~= nil, joined)
    test("a finished one is shown disabled", done and done.disabled == true)
    local ai = require("ai.player").new(g, 0)
    local before = ai:count("Rzdm")
    test("a computer player's produce researches", (ai:produce("Rzdm")) and forge.queue[#forge.queue].research == "Rzdm")
    test("and counts it, level and queued", ai:count("Rzdm") == before + 1)
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

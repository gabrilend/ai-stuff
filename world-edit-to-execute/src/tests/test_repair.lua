--[[
Tests for repair, helping a building up, and building upgrades (Issue
535): who repairs what, the rate and cost (RepairTimeRatio,
RepairCostRatio), stopping when the purse is empty; human workers
helping a building up faster, paid as repair; upgrades (cost, time, no
training meanwhile, cancel refunds, the new type in proportion, the
script's events and orders); the command card. Made-up tables are this
test's own.
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
-- }}}

-- {{{ The game, with made-up tables
local map_scene = require("demo.wc3map.scene")
local game_mod = require("demo.wc3map.game")
local s = map_scene.load(DIR .. "/assets/DAoW-5.4b-PUBLIC-TEST.w3x")

local UNITS = {
    zpea = { urac = "human" }, zpeo = { urac = "orc" }, zaco = { urac = "undead" }, zwsp = { urac = "nightelf" },
    zmac = { utyp = "mechanical", uhpm = 400 },
    zfoo = { uhpm = 400 },
    zbar = { uhpm = 1000 }, zhal = { uhpm = 1500 }, zkee = { uhpm = 2000 },
}
local LISTS = {
    zpea = { ubui = { "zbar" } }, zpeo = { ubui = { "zbar" } }, zaco = { ubui = { "zbar" } }, zwsp = { ubui = { "zbar" } },
    zhal = { uupt = { "zkee" } },
}
local units = { available = true }
function units:value(id, code) local v = (UNITS[id] or {})[code] return v, v ~= nil and "stock" or nil end
function units:list(id, code) return (LISTS[id] or {})[code] or {} end
local g = game_mod.new(s, { player = 0, placed = false, minimap = false, vision = false, stock = units, combat = false })
local VM = g.run_script({ ai = "none" })
local N = VM.natives
local p0 = N.Player(0)
local function run(sec) for _ = 1, math.floor(sec * 60 + 0.5) do g.tick(1 / 60) end end
local function worker(id, x, y)
    local u = g.spawn(id, 0, x, y, 0)
    u.spec.design, u.spec.archetype = "unit", "worker"
    u.speed = 400
    return u
end
local function building(id, x, y)
    local b = g.spawn(id, 0, x, y, 0)
    b.spec.design = "building"
    return b
end

local own
for _, u in ipairs(g.units) do
    if u.player == 0 and u.alive and u.spec.design == "unit" and not u.spec.hero then own = own or u end
end
local spots = {}
for r = 600, 6000, 200 do
    for k = 0, 15 do
        local a = k / 16 * math.pi * 2
        local x, y = g.snap(own.x + math.cos(a) * r, own.y + math.sin(a) * r)
        if g.placeable("zbar", x, y) then
            local far = true
            for _, sp in ipairs(spots) do if (sp[1] - x) ^ 2 + (sp[2] - y) ^ 2 < 700 ^ 2 then far = false end end
            if far then spots[#spots + 1] = { x, y } end
        end
        if #spots >= 6 then break end
    end
    if #spots >= 6 then break end
end

local events = {}
for _, ev in ipairs({ "UPGRADE_START", "UPGRADE_CANCEL", "UPGRADE_FINISH" }) do
    local trig = N.CreateTrigger()
    N.TriggerRegisterPlayerUnitEvent(trig, p0, "EVENT_PLAYER_UNIT_" .. ev, nil)
    N.TriggerAddAction(trig, function() events[#events + 1] = { ev = ev, u = N.GetTriggerUnit() } end)
end
g.state(0).gold, g.state(0).lumber = 100000, 100000
-- }}}

-- {{{ Repair
test_section("Repairing")
do
    local sp = spots[1]
    local bar = building("zbar", sp[1], sp[2])
    local pea = worker("zpea", sp[1] - 400, sp[2])
    local ok, why = g.can_repair(pea, bar)
    test("nothing to mend at full health", not ok and why == "not damaged")
    bar.hp = bar.hp_max * 0.5
    test("a human worker repairs a building", (g.can_repair(pea, bar)))
    test("an undead one doesn't", not g.can_repair(worker("zaco", sp[1], sp[2] - 600), bar))
    local foot = g.spawn("zfoo", 0, sp[1], sp[2] - 700, 0)
    foot.hp = 10
    test("a footman isn't a machine", not g.can_repair(pea, foot))
    local mac = g.spawn("zmac", 0, sp[1], sp[2] - 800, 0)
    mac.hp = 100
    test("a machine is", (g.can_repair(pea, mac)))
    local enemy = g.spawn("zbar", 5, sp[1] + 900, sp[2], 0)
    enemy.spec.design, enemy.hp = "building", 10
    test("not an enemy's", not g.can_repair(pea, enemy))
    g.remove(enemy)

    local cost = g.unit_cost("zbar")
    local gold = g.state(0).gold
    test("the order", g.repair(pea, bar))
    run(1.5)
    local hp0 = bar.hp
    test("walked there and mending", hp0 > bar.hp_max * 0.5, tostring(hp0))
    run(1)
    local rate = (bar.hp - hp0)
    local expect = bar.hp_max / (cost.time * 1.5)
    test("the whole over 1.5 times its build time", math.abs(rate - expect) < expect * 0.05,
        string.format("%.2f per second, %.2f expected", rate, expect))
    local spent = gold - g.state(0).gold
    local share = (bar.hp - bar.hp_max * 0.5) / bar.hp_max
    test("paid as it goes: 35% of its cost for all of it",
        math.abs(spent - cost.gold * 0.35 * share) <= 1.01, spent .. " for " .. share)
    -- a second repairer: twice as fast
    local pea2 = worker("zpea", sp[1] + 200, sp[2] - 200)
    g.repair(pea2, bar)
    run(1)
    local h1 = bar.hp
    run(1)
    test("repairers stack", math.abs((bar.hp - h1) - 2 * expect) < expect * 0.1, tostring(bar.hp - h1))
    -- out of gold: they stop
    g.state(0).gold = 0
    run(1)
    test("an empty purse stops them", pea.repair == nil and pea2.repair == nil)
    g.state(0).gold = 100000
    g.repair(pea, bar)
    run(cost.time * 1.5)
    test("done when whole", bar.hp == bar.hp_max and pea.repair == nil)
    test("another order stops repairing", (function()
        bar.hp = 1
        g.repair(pea, bar)
        g.order({ pea }, "move", pea.x + 300, pea.y)
        return pea.repair == nil
    end)())
    g.remove(pea); g.remove(pea2); g.remove(foot); g.remove(mac)
end
-- }}}

-- {{{ Helping
test_section("Helping a building up")
do
    local sp = spots[2]
    local pea = worker("zpea", sp[1] - 300, sp[2])
    g.build(pea, "zbar", sp[1], sp[2])
    run(2)
    local b = pea.construct and pea.construct.building
    test("started", b and b.building_up)
    local p0_ = b.progress
    run(2)
    local alone = b.progress - p0_
    local helpers = {}
    for k = 1, 2 do
        helpers[k] = worker("zpea", sp[1] + 250, sp[2] + k * 100)
        test("helper " .. k .. " ordered", (g.repair(helpers[k], b)))
    end
    local peo = worker("zpeo", sp[1] + 300, sp[2])
    test("an orc can't help a human building", not g.can_repair(peo, b))
    run(1.5)
    local gold = g.state(0).gold
    local p1 = b.progress
    run(2)
    local with = b.progress - p1
    local expect = alone * (1 + 2 / 1.5)
    test("faster with helpers (each at the repair rate)", math.abs(with - expect) < expect * 0.05,
        string.format("%.4f alone, %.4f with, %.4f expected", alone, with, expect))
    test("the helpers are paid as repair", g.state(0).gold < gold)
    -- the builder walks off: the helpers carry on
    g.order({ pea }, "move", pea.x - 500, pea.y)
    local p2 = b.progress
    run(1)
    test("helpers alone keep it rising", b.progress > p2)
    run(b.build_time)
    test("finished", not b.building_up)
    test("the helpers are free", helpers[1].repair == nil and helpers[2].repair == nil)
    g.remove(pea); g.remove(peo); g.remove(helpers[1]); g.remove(helpers[2])
end
-- }}}

-- {{{ Upgrades
test_section("Upgrading a hall")
local hall
do
    local sp = spots[3]
    hall = building("zhal", sp[1], sp[2])
    test("it upgrades to", g.upgrades(hall)[1] == "zkee")
    test("not to what it doesn't list", not g.can_upgrade(hall, "zbar"))
    hall.hp = hall.hp_max * 0.5
    local cost = g.unit_cost("zkee")
    local gold = g.state(0).gold
    events = {}
    test("the order", g.upgrade(hall, "zkee"))
    test("paid", g.state(0).gold == gold - cost.gold)
    test("UPGRADE_START", events[1] and events[1].ev == "UPGRADE_START" and events[1].u == hall)
    local ok, why = g.can_train(hall, "zpea")
    test("no training meanwhile", not ok and why == "upgrading")
    local card = require("ui.wc3.commands").card(hall, g.db, "main")
    test("the card: only Cancel", card[12] and card[12].action == "cancel_upgrade" and not card[1])
    test("cancelled: all back", g.cancel_upgrade(hall) and g.state(0).gold == gold and hall.upgrading == nil)
    test("UPGRADE_CANCEL", events[#events].ev == "UPGRADE_CANCEL")
    card = require("ui.wc3.commands").card(hall, g.db, "main")
    local up
    for k = 1, 12 do if card[k] and card[k].action == "upgrade" then up = card[k] end end
    test("the card offers the upgrade", up and up.target == "zkee")
    g.upgrade(hall, "zkee")
    run(cost.time - 1)
    test("not before its time", hall.id == "zhal")
    local share = hall.hp / hall.hp_max
    run(1.5)
    test("then it's the new type", hall.id == "zkee" and hall.upgrading == nil)
    test("its hit points in proportion", math.abs(hall.hp / hall.hp_max - share) < 0.005 and hall.hp_max == 2000,
        hall.hp .. " of " .. hall.hp_max)
    test("UPGRADE_FINISH", events[#events].ev == "UPGRADE_FINISH" and events[#events].u == hall)
    test("the same unit, still standing", hall.alive and not hall.removed)
end
test_section("The script's orders")
do
    local sp = spots[4]
    local h2 = building("zhal", sp[1], sp[2])
    test("IssueImmediateOrderById with the type upgrades", N.IssueImmediateOrderById(h2, vm.s2id("zkee")) and h2.upgrading)
    test("\"cancel\" cancels it", N.IssueImmediateOrder(h2, "cancel") and not h2.upgrading)
    local bar = building("zbar", sp[1] + 800, sp[2])
    bar.hp = 10
    local pea = worker("zpea", sp[1] + 500, sp[2])
    test("IssueTargetOrder repair", N.IssueTargetOrder(pea, "repair", bar) and pea.repair and pea.repair.target == bar)
    test("OrderId(\"repair\")", N.OrderId("repair") == 852024)
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

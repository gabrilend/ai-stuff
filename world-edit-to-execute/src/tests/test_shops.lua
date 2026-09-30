--[[
Tests for taverns and shops (Issue 533): what a building sells and its
stock (start delay, maximum, replenishing), buying heroes and units
(a unit of the buyer near, cost, hero limits, hero tokens), buying items
(into an inventory, or beside a full one), pawning, who a shop sells to,
the script's stock natives and SELL / SELL_ITEM / PAWN_ITEM events, and
the command card. Made-up tables are this test's own.
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
    ztav = { useu = "Hzz1,Hzz2" }, zshp = { usei = "zpot,zclw" }, zown = { useu = "zmer" },
    Hzz1 = { usma = 1, usrg = 10, usst = 0, uhpm = 100, ustr = 10, uagi = 10, uint = 10, upra = "STR" },
    Hzz2 = { usma = 1, usrg = 10, usst = 5, uhpm = 100, ustr = 10, uagi = 10, uint = 10, upra = "STR" },
    zmer = { usma = 3, usrg = 20, usst = 0 },
}
local units = { available = true }
function units:value(id, code) local v = (UNITS[id] or {})[code] return v, v ~= nil and "stock" or nil end
function units:list(id, code)
    local v = self:value(id, code)
    local out = {}
    if type(v) == "string" then for x in v:gmatch("[^,]+") do out[#out + 1] = x end end
    return out
end
local ITEMS = {
    zpot = { unam = "Potion", igol = 100, isto = 2, istr = 20, isst = 0, iuse = 2, iusa = 1, iper = 1 },
    zclw = { unam = "Claws", igol = 400, isto = 1, istr = 60, isst = 0 },
}
local items_data = { available = true }
function items_data:value(id, code) local v = (ITEMS[id] or {})[code] return v, v ~= nil and "stock" or nil end
function items_data:list() return {} end

local g = game_mod.new(s, { player = 0, placed = false, minimap = false, vision = false, stock = units, combat = false })
g.data.items = items_data
local VM = g.run_script({ ai = "none" })
local N = VM.natives
local p0 = N.Player(0)
local function run(sec) for _ = 1, math.floor(sec * 60 + 0.5) do g.tick(1 / 60) end end

local own
for _, u in ipairs(g.units) do
    if u.player == 0 and u.alive and u.spec.design == "unit" and not u.spec.hero then own = own or u end
end
-- a quiet place, far from the player's units
local X, Y = own.x + 4000, own.y + 4000
local function building(id, player, x, y)
    local b = g.spawn(id, player, x, y, 0)
    b.spec.design = "building"
    return b
end
local tavern = building("ztav", 15, X, Y)
local shop = building("zshp", 15, X + 2000, Y)

local seen = {}
for _, ev in ipairs({ "SELL", "SELL_ITEM", "PAWN_ITEM" }) do
    for _, pl in ipairs({ 0, 15 }) do
        local trig = N.CreateTrigger()
        N.TriggerRegisterPlayerUnitEvent(trig, N.Player(pl), "EVENT_PLAYER_UNIT_" .. ev, nil)
        N.TriggerAddAction(trig, function()
            seen[#seen + 1] = { ev = ev, shop = N.GetTriggerUnit(), sold = N.GetSoldUnit(), item = N.GetSoldItem(),
                                buyer = N.GetBuyingUnit() }
        end)
    end
end
local function last() return seen[#seen] or {} end
-- }}}

-- {{{ Stock
test_section("What a tavern and a shop sell")
do
    local st = g.stock(tavern)
    test("a tavern's heroes", #st == 2 and st[1].id == "Hzz1" and st[1].kind == "unit")
    test("in stock at once", st[1].count == 1 and st[1].max == 1)
    test("not before its start delay", st[2].count == 0)
    local items = g.stock(shop)
    test("a shop's items, with their maximum", #items == 2 and items[1].kind == "item" and items[1].count == 2)
    run(5.5)
    test("after the delay, in stock", st[2].count == 1)
    test("a footman isn't a shop", not g.is_shop(own))
end
-- }}}

-- {{{ Hiring
test_section("Hiring at a tavern")
do
    g.state(0).gold, g.state(0).lumber = 5000, 5000
    -- (the made-up tables give no farms: food from the script's state)
    N.SetPlayerState(p0, "PLAYER_STATE_RESOURCE_FOOD_CAP", 300)
    local ok, why = g.buy(tavern, 0, "Hzz1")
    test("no unit of the player near: no", not ok and why == "no unit of yours near the shop", tostring(why))
    local scout = g.spawn("hfoo", 0, X + 300, Y, 0)
    local gold = g.state(0).gold
    local cost = g.unit_cost("Hzz1")
    local hero
    ok, hero = g.buy(tavern, 0, "Hzz1")
    test("hired", ok and hero and hero.id == "Hzz1" and hero.player == 0)
    test("paid", g.state(0).gold == gold - cost.gold)
    test("beside the tavern", (hero.x - X) ^ 2 + (hero.y - Y) ^ 2 < 300 ^ 2)
    test("EVENT_PLAYER_UNIT_SELL for the tavern's owner: the tavern, the hero, the buyer",
        last().ev == "SELL" and last().shop == tavern and last().sold == hero and last().buyer == scout)
    ok, why = g.buy(tavern, 0, "Hzz1")
    test("out of stock", not ok and why == "out of stock")
    run(10.5)
    test("back in stock after its interval", g.stock(tavern)[1].count == 1)
    N.SetPlayerMaxHeroesAllowed(0, p0)
    ok, why = g.buy(tavern, 0, "Hzz1")
    test("the hero limit holds", not ok and why == "hero limit reached")
    N.SetPlayerMaxHeroesAllowed(99, p0)
    N.SetPlayerState(p0, "PLAYER_STATE_RESOURCE_HERO_TOKENS", 1)
    gold = g.state(0).gold
    test("a hero token hires for nothing", g.buy(tavern, 0, "Hzz1") and g.state(0).gold == gold
        and N.GetPlayerState(p0, "PLAYER_STATE_RESOURCE_HERO_TOKENS") == 0)
    g.remove(scout)
end
-- }}}

-- {{{ Items
test_section("Buying and pawning items")
do
    local ok, why = g.buy(shop, 0, "zpot")
    test("no hero near: no", not ok and why == "no hero near the shop", tostring(why))
    local hero = g.spawn("Hzz1", 0, X + 2200, Y, 0)
    local gold = g.state(0).gold
    local it
    ok, it = g.buy(shop, 0, "zpot")
    test("bought, into its inventory", ok and it.owner == hero and g.state(0).gold == gold - 100)
    test("EVENT_PLAYER_UNIT_SELL_ITEM", last().ev == "SELL_ITEM" and last().item == it and last().buyer == hero)
    test("one fewer in stock", g.stock(shop)[1].count == 1)
    for k = 1, 5 do g.give_item(hero, g.create_item("zclw", hero.x, hero.y)) end
    local it2
    ok, it2 = g.buy(shop, 0, "zpot")
    test("a full inventory: beside it on the ground", ok and not it2.owner and (it2.x - hero.x) ^ 2 < 100 ^ 2)
    gold = g.state(0).gold
    it.charges = 1
    local ok3, got = g.pawn(hero, it)
    test("pawned: half its cost, by the charges left (100 x 0.5 x 1/2)", ok3 and got == 25 and g.state(0).gold == gold + 25,
        tostring(got))
    test("EVENT_PLAYER_UNIT_PAWN_ITEM", last().ev == "PAWN_ITEM" and last().item == it)
    test("gone from the inventory", it.owner == nil and it.removed)
end
-- }}}

-- {{{ Whose shop
test_section("Whose shop, and the script")
do
    local camp = building("zown", 3, X - 2000, Y)
    test("a player's shop doesn't sell to its enemies", not g.sells_to(camp, 0))
    test("but to its owner", g.sells_to(camp, 3))
    N.AddUnitToStock(camp, vm.s2id("hfoo"), 3, 5)
    local e
    for _, x in ipairs(g.stock(camp)) do if x.id == "hfoo" then e = x end end
    test("AddUnitToStock", e and e.count == 3 and e.max == 5)
    N.RemoveUnitFromStock(camp, vm.s2id("hfoo"))
    e = nil
    for _, x in ipairs(g.stock(camp)) do if x.id == "hfoo" then e = x end end
    test("RemoveUnitFromStock", e == nil)
    N.AddItemToAllStock(vm.s2id("zclw"), 4, 4)
    local claws
    for _, x in ipairs(g.stock(shop)) do if x.id == "zclw" then claws = x end end
    test("AddItemToAllStock reaches the item shops", claws and claws.count == 4)
    local card = require("ui.wc3.commands").card(shop, g.db, "main")
    local labels = {}
    for k = 1, 12 do if card[k] then labels[#labels + 1] = card[k].label end end
    test("the card lists what it sells, with stock", table.concat(labels, "; "):find("Buy Potion") ~= nil,
        table.concat(labels, "; "))
    test("the script's stock natives are real", not VM.noop.AddUnitToStock and not VM.noop.AddItemToStock)
end
-- }}}

-- {{{ Which unit buys (issue 539)
test_section("Which unit buys")
do
    -- open ground near the player's units, with room to walk to the shop
    local SX, SY
    for r = 0, 3000, 100 do
        for k = 0, 11 do
            local a = k / 12 * math.pi * 2
            local x, y = own.x + math.cos(a) * r, own.y + math.sin(a) * r
            local route = g.pathing:route(x + 2000, y, x, y)
            if not SX and route and (route[#route].x - x) ^ 2 + (route[#route].y - y) ^ 2 < 50 ^ 2 then SX, SY = x, y end
        end
        if SX then break end
    end
    local sh = building("zshp", 15, SX, SY)
    local near_h = g.spawn("Hzz1", 0, SX + 150, SY, 0)
    local far_h = g.spawn("Hzz2", 0, SX + 450, SY, 0)
    local foot = g.spawn("hfoo", 0, SX + 100, SY + 50, 0)
    test("by default the nearest able one (a hero for items)", g.buyer_for(sh, 0, true) == near_h)
    local b = g.buyer_for(sh, 0, false)
    local function d(u) return (u.x - SX) ^ 2 + (u.y - SY) ^ 2 end
    test("for units, the nearest of all (a footman will do)", b and d(b) <= d(foot) and d(b) < d(near_h))
    local c = g.shop_candidates(sh, 0, true)
    local ok_order = #c >= 2
    for i = 2, #c do ok_order = ok_order and d(c[i - 1]) <= d(c[i]) end
    test("its candidates, nearest first", ok_order and c[1] == near_h)
    test("a chosen buyer", g.set_patron(sh, far_h) and g.buyer_for(sh, 0, true) == far_h)
    local ok, it = g.buy(sh, 0, "zclw")
    test("buys into its own inventory", ok and it.owner == far_h, tostring(it))
    local n1 = g.next_patron(sh, 0)
    test("the button cycles to the next", n1 ~= far_h and g.buyer_for(sh, 0, true) == n1)
    local seen_far = false
    for _ = 1, #c do if g.next_patron(sh, 0) == far_h then seen_far = true break end end
    test("and round again", seen_far)
    far_h.x = SX + 2000
    test("out of range: the nearest again", g.buyer_for(sh, 0, true) == near_h)
    test("can't choose one out of range", not g.set_patron(sh, far_h))
    test("a footman can't buy items", not g.set_patron(sh, foot) or g.buyer_for(sh, 0, true) ~= foot)
    -- sent there
    far_h.speed = 400
    if far_h.mover then far_h.mover = nil end
    test("sent to the shop", g.visit_shop(far_h, sh) and far_h.visiting == sh)
    run(6)
    test("arrived: it's the buyer", far_h.visiting == nil and g.buyer_for(sh, 0, true) == far_h,
        string.format("%.0f from the shop", math.sqrt((far_h.x - SX) ^ 2 + (far_h.y - SY) ^ 2)))
    local card = require("ui.wc3.commands").card(sh, g.db, "main")
    local btn
    for k = 1, 12 do if card[k] and card[k].action == "next_buyer" then btn = card[k] end end
    test("the card names the buyer", btn and btn.label:find("Buyer:") ~= nil, btn and btn.label)
    -- the HUD: a shop selected just after one of your units
    local hud = require("ui.wc3.hud").new(g, 1280, 720)
    hud:select({ near_h })
    hud:select({ sh })
    test("selecting the shop after a unit makes it the buyer", g.buyer_for(sh, 0, true) == near_h)
    g.remove(near_h); g.remove(far_h); g.remove(foot)
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

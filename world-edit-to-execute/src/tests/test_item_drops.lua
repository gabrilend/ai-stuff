--[[
Tests for item drops and moving items (Issue 537): the map's own drop
tables (compiled into DAoW's script) dropping on death, GetChangingUnit
only in a change of owner, random items by level and class
(ChooseRandomItem / Ex), carriers' items falling when they die (heroes
keep theirs but those dropped on death), and moving items: between slots,
handed to a unit (walking there), dropped at a point, and the natives.
Made-up tables are this test's own.
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

local map_scene = require("demo.wc3map.scene")
local game_mod = require("demo.wc3map.game")
local s = map_scene.load(DIR .. "/assets/DAoW-5.4b-PUBLIC-TEST.w3x")

-- {{{ The map's own drop tables
test_section("DAoW's drop tables, run by its script")
do
    local g = game_mod.new(s, { player = 0, placed = false, minimap = false, vision = false, combat = false })
    local VM = g.run_script({ ai = "none" })
    for _ = 1, 10 do g.tick(1 / 30) end
    local victim
    for _, u in ipairs(g.units) do
        if u.alive and (u.x + 26432) ^ 2 + (u.y + 22208) ^ 2 < 100 then victim = u end
    end
    test("the unit with a drop table is there", victim ~= nil)
    local before = {}
    for _, it in ipairs(g.items) do before[it] = true end
    g.kill(victim)
    for _ = 1, 5 do g.tick(1 / 30) end
    local dropped
    for _, it in ipairs(g.items) do if not before[it] then dropped = it end end
    test("it drops its table's item when it dies", dropped and dropped.id == "I001", dropped and dropped.id)
    test("where it died", dropped and (dropped.x - victim.x) ^ 2 + (dropped.y - victim.y) ^ 2 < 64 ^ 2)
    local seen
    local t = VM.natives.CreateTrigger()
    VM.natives.TriggerRegisterPlayerUnitEvent(t, VM.natives.Player(0), "EVENT_PLAYER_UNIT_DEATH", nil)
    VM.natives.TriggerAddAction(t, function() seen = { VM.env.GetChangingUnit() } end)
    local mine
    for _, u in ipairs(g.units) do if u.player == 0 and u.alive and u.spec.design == "unit" then mine = u end end
    g.kill(mine)
    test("GetChangingUnit is null in a death", seen and seen[1] == nil)
end
-- }}}

-- {{{ A game with made-up items
local ITEMS = {
    zpr1 = { unam = "Ring", ilev = 1, icla = "Permanent" },
    zpr2 = { unam = "Blade", ilev = 2, icla = "Permanent" },
    zch2 = { unam = "Potion", ilev = 2, icla = "Charged", iuse = 2 },
    zch9 = { unam = "Secret", ilev = 2, icla = "Charged", iprn = 0 },
    zcdd = { unam = "Cursed", ilev = 1, idrp = 1 },
    zcst = { unam = "Stuck", ilev = 1, idro = 0 },
}
local items_data = { available = true }
function items_data:value(id, code) local v = (ITEMS[id] or {})[code] return v, v ~= nil and "stock" or nil end
function items_data:list() return {} end
function items_data:ids() local out = {} for id in pairs(ITEMS) do out[#out + 1] = id end table.sort(out) return out end
local g = game_mod.new(s, { player = 0, placed = false, minimap = false, vision = false, combat = false })
g.data.items = items_data
local VM = g.run_script({ ai = "none" })
local N = VM.natives
local function run(sec) for _ = 1, math.floor(sec * 60 + 0.5) do g.tick(1 / 60) end end
local own
for _, u in ipairs(g.units) do
    if u.player == 0 and u.alive and u.spec.design == "unit" and not u.spec.hero then own = own or u end
end
-- open ground near the player's units, with room to walk east
local X, Y
for r = 0, 3000, 100 do
    for k = 0, 11 do
        local a = k / 12 * math.pi * 2
        local x, y = own.x + math.cos(a) * r, own.y + math.sin(a) * r
        local route = g.pathing:route(x, y, x + 1400, y)
        if not X and route and (route[#route].x - x - 1400) ^ 2 + (route[#route].y - y) ^ 2 < 50 ^ 2 then X, Y = x, y end
    end
    if X then break end
end
local function hero(x, y, player)
    local h = g.spawn("Hpal", player or 0, x, y, 0)
    h.speed = 400
    return h
end
-- }}}

-- {{{ Random items
test_section("Random items")
do
    local got = {}
    for _ = 1, 200 do got[g.random_item(2) or "none"] = true end
    test("level 2: only level 2 items", got.zpr2 and got.zch2 and not got.zpr1)
    test("never one that isn't a random choice", not got.zch9)
    got = {}
    for _ = 1, 100 do got[g.random_item(2, "charged") or "none"] = true end
    test("by class", got.zch2 and not got.zpr2)
    test("none of that level: nil", g.random_item(7) == nil)
    local id = N.ChooseRandomItemEx(N.ConvertItemType and N.ConvertItemType(1) or 1, 2)
    test("ChooseRandomItemEx(ITEM_TYPE_CHARGED, 2)", vm.id2s(id) == "zch2", tostring(id))
    test("ChooseRandomItem(7): -1", N.ChooseRandomItem(7) == -1)
    local u = g.spawn("hfoo", 0, X, Y, 0)
    test("UnitDropItem of -1: nothing", N.UnitDropItem(u, -1) == nil)
    g.remove(u)
end
-- }}}

-- {{{ Moving between slots
test_section("Between slots")
local h = hero(X, Y)
do
    local a, b = g.create_item("zpr1", X, Y), g.create_item("zpr2", X, Y)
    g.give_item(h, a); g.give_item(h, b)
    test("in slots 0 and 1", a.slot == 0 and b.slot == 1)
    test("to an empty slot", g.move_item(h, a, 4) and a.slot == 4 and h.inventory[4] == a and h.inventory[0] == nil)
    test("onto another: they swap", g.move_item(h, b, 4) and b.slot == 4 and a.slot == 1 and h.inventory[1] == a)
    test("not past its inventory", not g.move_item(h, a, 6))
    test("UnitDropItemSlot", N.UnitDropItemSlot(h, a, 2) and a.slot == 2)
end
-- }}}

-- {{{ Handing over
test_section("Handing to another unit, dropping at a point")
do
    local a = h.inventory[2]
    local friend = hero(X + 700, Y)
    test("ordered: walks to it", g.hand_item(h, a, friend) and a.owner == h and h.handing)
    run(3)
    test("arrived: it's the friend's", a.owner == friend and h.handing == nil)
    local foe = hero(X + 900, Y + 100, 5)
    local ok, why = g.hand_item(friend, a, foe)
    test("not to an enemy", not ok and why == "not to an enemy", tostring(why))
    local foot = g.spawn("hfoo", 0, friend.x + 50, friend.y, 0)
    ok, why = g.hand_item(friend, a, foot)
    test("not to a unit without an inventory", not ok and why == "it can't carry items", tostring(why))
    g.remove(foot)
    for k = 1, 5 do g.give_item(h, g.create_item("zpr1", h.x, h.y)) end
    ok, why = g.hand_item(friend, a, h)
    test("not to a full inventory", not ok and why == "its inventory is full", tostring(why))
    local stuck = g.create_item("zcst", friend.x, friend.y)
    g.give_item(friend, stuck)
    test("not one that can't be dropped", not g.hand_item(friend, stuck, foe) and not g.drop_item_at(friend, stuck, 0, 0))
    local tx, ty = friend.x + 500, friend.y
    test("dropped at a point: walks there", g.drop_item_at(friend, a, tx, ty) and a.owner == friend)
    run(3)
    test("and leaves it there", a.owner == nil and (a.x - tx) ^ 2 + (a.y - ty) ^ 2 < 1)
    g.give_item(friend, a)
    g.drop_item_at(friend, a, tx - 800, ty)
    g.order({ friend }, "move", friend.x, friend.y + 300)
    test("another order: it's kept", friend.handing == nil and a.owner == friend)
    friend.x, friend.y = h.x + 60, h.y
    g.remove_item(h.inventory[5])
    test("UnitDropItemTarget, near: at once", N.UnitDropItemTarget(friend, a, h) and a.owner == h)
    g.remove(foe)
end
-- }}}

-- {{{ Death
test_section("When a carrier dies")
do
    local mule = g.spawn("hfoo", 0, X - 600, Y, 0)
    mule.abilities = mule.abilities or {}
    mule.abilities.AInv = 1
    local it = g.create_item("zpr1", mule.x, mule.y)
    test("a unit with an inventory carries", g.give_item(mule, it))
    g.kill(mule)
    test("its items fall where it dies", it.owner == nil and (it.x - mule.x) ^ 2 + (it.y - mule.y) ^ 2 < 50 ^ 2)
    local hh = hero(X - 900, Y)
    local keep, curse = g.create_item("zpr1", hh.x, hh.y), g.create_item("zcdd", hh.x, hh.y)
    g.give_item(hh, keep); g.give_item(hh, curse)
    g.kill(hh)
    test("a hero keeps its own", keep.owner == hh)
    test("but not one dropped when its carrier dies", curse.owner == nil)
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

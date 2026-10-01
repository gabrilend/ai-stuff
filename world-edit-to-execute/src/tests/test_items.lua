--[[
Tests for items and inventories (Issue 532): item types, ground items,
picking up (walking there), inventory size, what carried items give,
dropping, a full inventory, potions (charges, cooldown, perishing),
tomes (powerups for good), an item that casts a spell, and the script's
item natives and events. Made-up tables are this test's own.
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

local ITEMS = {
    zclw = { unam = "Claws", iabi = "Zatt", icla = "Permanent" },
    zbel = { unam = "Belt", iabi = "Zstr" },
    zpot = { unam = "Potion", iabi = "Zhea", iusa = 1, iuse = 2, iper = 1, icla = "Charged" },
    ztom = { unam = "Tome", iabi = "Ztom", ipow = 1, icla = "PowerUp" },
    zwnd = { unam = "Wand", iabi = "Zbol", iusa = 1, iuse = 3 },
    zstk = { unam = "Stuck", idro = 0 },
}
local items_data = { available = true }
function items_data:value(id, code) local v = (ITEMS[id] or {})[code] return v, v ~= nil and "stock" or nil end
function items_data:list(id, code)
    local v = self:value(id, code)
    local out = {}
    if type(v) == "string" then for x in v:gmatch("[^,]+") do out[#out + 1] = x end end
    return out
end
local ABIL = {
    Zatt = { Iatt = 12 }, Zstr = { Istr = 6 }, Zhea = { Ihpg = 250, acdn = 5 }, Ztom = { Istr = 1 },
    Zbol = { aran = 800, Htb1 = 40, adur = 1 },
}
local BASE = { Zbol = "AHtb" }
local ab = { available = true }
function ab:base(id) return BASE[id] or id end
function ab:value(id, code) local v = (ABIL[id] or {})[code] return v, v ~= nil and "stock" or nil end
function ab:list() return {} end
local units = { available = true }
local UNIT = { uhpm = 100, ustr = 10, uagi = 10, uint = 10, upra = "STR", ua1b = 5, ua1d = 1, ua1s = 1 }
function units:value(id, code)
    if not id:sub(1, 1):match("%u") then return nil end
    local v = UNIT[code] return v, v ~= nil and "stock" or nil
end
function units:list() return {} end

local g = game_mod.new(s, { player = 0, placed = false, minimap = false, vision = false, stock = units, combat = false })
g.data.items, g.data.abilities = items_data, ab
local VM = g.run_script({ ai = "none" })
local N = VM.natives
local p0 = N.Player(0)
local function run(sec) for _ = 1, math.floor(sec * 60 + 0.5) do g.tick(1 / 60) end end

local own
for _, u in ipairs(g.units) do
    if u.player == 0 and u.alive and u.spec.design == "unit" and not u.spec.hero then own = own or u end
end
local X, Y = own.x, own.y
local hero = g.spawn("Hpal", 0, X, Y, 0)
hero.speed = 400
hero.hp_regen, hero.mana_regen = 0, 0

local seen = {}
for _, ev in ipairs({ "PICKUP_ITEM", "DROP_ITEM", "USE_ITEM" }) do
    local trig = N.CreateTrigger()
    N.TriggerRegisterPlayerUnitEvent(trig, p0, "EVENT_PLAYER_UNIT_" .. ev, nil)
    N.TriggerAddAction(trig, function()
        seen[#seen + 1] = { ev = ev, item = N.GetManipulatedItem(), unit = N.GetManipulatingUnit() }
    end)
end
local function last() return seen[#seen] or {} end
-- }}}

-- {{{ Types and the ground
test_section("Item types, and items on the ground")
do
    local t = g.item_type("zpot")
    test("a type's values", t.name == "Potion" and t.usable and t.perishable and t.charges == 2 and t.abilities[1] == "Zhea")
    test("defaults: droppable, not a powerup", t.droppable and not t.powerup)
    local claws = g.create_item("zclw", X + 400, Y)
    test("an item on the ground", not claws.owner and g.item_at(X + 400, Y) == claws)
    test("a hero carries six", g.inventory_size(hero) == 6)
    test("a footman none", g.inventory_size(own) == 0 and not g.pick_up(own, claws))
    test("the order to pick it up", g.pick_up(hero, claws))
    run(0.3)
    test("walking there first", not claws.owner and hero.fetch == claws)
    run(3)
    test("picked up", claws.owner == hero and hero.inventory[0] == claws)
    test("the script heard it, and which", last().ev == "PICKUP_ITEM" and last().item == claws and last().unit == hero)
end
-- }}}

-- {{{ Bonuses
test_section("What carried items give")
do
    local claws = hero.inventory[0]
    test("claws: +12 damage on every strike", g.modify_strike(hero, own, 10) == 22)
    local str, hp = hero.str, hero.hp_max
    local belt = g.create_item("zbel", hero.x, hero.y)
    test("given a belt", g.give_item(hero, belt))
    test("+6 strength, and hit points with it", hero.str == str + 6 and hero.hp_max == hp + 6 * 25)
    test("dropped", g.drop_item(hero, belt, X + 100, Y + 100) and not belt.owner and belt.x == X + 100)
    test("and its strength gone", hero.str == str)
    test("DROP_ITEM", last().ev == "DROP_ITEM" and last().item == belt)
    local stuck = g.create_item("zstk", X, Y)
    g.give_item(hero, stuck)
    local ok, why = g.drop_item(hero, stuck, X, Y)
    test("an undroppable item stays", not ok and why == "can't drop that")
    for k = 1, 4 do g.give_item(hero, g.create_item("zclw", X, Y)) end
    ok, why = g.give_item(hero, g.create_item("zclw", X, Y))
    test("a seventh doesn't fit", not ok and why == "inventory is full")
    -- clear out all but the first claws
    for k = 1, 5 do
        local it = hero.inventory[k]
        if it then it.droppable = true; g.drop_item(hero, it); g.remove_item(it) end
    end
end
-- }}}

-- {{{ Using
test_section("Using items")
do
    local pot = g.create_item("zpot", X, Y)
    g.give_item(hero, pot)
    hero.hp = 100
    test("a potion: 250 back", g.use_item(hero, pot) and hero.hp == math.min(hero.hp_max, 350))
    test("a charge spent", pot.charges == 1)
    test("USE_ITEM", last().ev == "USE_ITEM" and last().item == pot)
    local ok, why = g.use_item(hero, pot)
    test("then its cooldown", not ok and why == "not ready yet")
    run(5.1)
    test("used again", (g.use_item(hero, pot)))
    run(0.1)
    test("out of charges, it perishes", pot.removed and hero.inventory[pot.slot or 1] ~= pot)
    local str = hero.str
    local tome = g.create_item("ztom", hero.x + 30, hero.y)
    g.pick_up(hero, tome)
    run(1)
    test("a tome is used when picked up, and is gone", tome.removed and hero.str == str + 1)
    local keep = true
    for k = 0, 5 do if hero.inventory[k] == tome then keep = false end end
    test("it never takes a slot", keep)
    -- a wand that casts a Storm Bolt
    local foe = g.spawn("nwlt", 12, hero.x + 300, hero.y, 0)
    foe.hp_max, foe.hp = 1000, 1000
    local wand = g.create_item("zwnd", X, Y)
    g.give_item(hero, wand)
    ok, why = g.use_item(hero, wand)
    test("a wand needs its target", not ok and why == "needs a unit target", tostring(why))
    test("aimed at a foe", g.use_item(hero, wand, foe))
    run(1.5)
    test("its spell lands (40, and a little regenerated)", foe.hp >= 960 and foe.hp < 962 and wand.charges == 2,
        foe.hp .. ", " .. wand.charges)
    test("an item's ability isn't a button of its own", (function()
        for _, a in ipairs(g.castable(hero)) do if a.id == "Zbol" then return false end end
        return true
    end)())
    g.remove(foe)
end
-- }}}

-- {{{ The script
test_section("The script's item natives")
do
    local it = N.UnitAddItemById(hero, vm.s2id("zbel"))
    test("UnitAddItemById: carried", it.owner == hero)
    test("UnitItemInSlot finds it", N.UnitItemInSlot(hero, it.slot) == it)
    test("GetItemTypeId, GetItemName", N.GetItemTypeId(it) == vm.s2id("zbel") and N.GetItemName(it) == "Belt")
    test("UnitInventorySize", N.UnitInventorySize(hero) == 6)
    N.UnitRemoveItem(hero, it)
    test("UnitRemoveItem drops it where the hero stands", not it.owner and math.abs(it.x - hero.x) < 1)
    local ground = N.CreateItem(vm.s2id("zclw"), X + 2000, Y + 2000)
    local found = 0
    local r = N.Rect(X + 1900, Y + 1900, X + 2100, Y + 2100)
    N.EnumItemsInRect(r, nil, function() if N.GetEnumItem() == ground then found = found + 1 end end)
    test("EnumItemsInRect", found == 1)
    local pot = N.UnitAddItemById(hero, vm.s2id("zpot"))
    N.UnitResetCooldown(hero)   -- (the potions above share the ability)
    hero.hp = 1
    test("UnitUseItem", N.UnitUseItem(hero, pot) and hero.hp > 1 and N.GetItemCharges(pot) == 1)
    N.RemoveItem(ground)
    run(0.1)
    test("RemoveItem", ground.removed and g.item_at(X + 2000, Y + 2000) == nil)
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

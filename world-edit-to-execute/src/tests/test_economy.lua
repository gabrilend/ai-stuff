--[[
Tests for the economy (Issue 527) and its foundation: object tables of
every kind (gamedata/object_stock.lua, levels and profile fields), the
gameplay constants (defaults, the map's war3mapMisc.txt), player state,
food and upkeep, workers mining gold and cutting lumber, bounty, scores,
and the script's side (GetPlayerState, GetPlayerScore, resource amounts,
player state events). Stock tables here are made up (their numbers are
this test's own).
]]

-- {{{ Setup paths
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local object_stock = require("gamedata.object_stock")
local gc = require("gamedata.game_constants")
local economy = require("demo.wc3map.economy")
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

local function sylk(columns, rows)
    local out = { "ID;PWXL;N;E" }
    local function cell(x, y, v)
        out[#out + 1] = string.format("C;X%d;Y%d;K%s", x, y, type(v) == "number" and tostring(v) or ('"' .. v .. '"'))
    end
    for x, name in ipairs(columns) do cell(x, 1, name) end
    for y, r in ipairs(rows) do
        for x, name in ipairs(columns) do if r[name] ~= nil then cell(x, y + 1, r[name]) end end
    end
    out[#out + 1] = "E"
    return table.concat(out, "\n")
end
-- }}}

-- {{{ Abilities' tables: levels, data fields, profiles
test_section("Object tables with levels")
do
    local files = {
        ["Units\\AbilityMetaData.slk"] = sylk({ "ID", "field", "slk", "index", "repeat", "data" }, {
            { ID = "acdn", field = "Cool", slk = "AbilityData", index = -1, ["repeat"] = 1, data = 0 },
            { ID = "Hbz1", field = "Data", slk = "AbilityData", index = -1, ["repeat"] = 1, data = 1 },
            { ID = "ahky", field = "Hotkey", slk = "Profile", index = -1, ["repeat"] = 0, data = 0 },
            { ID = "atp1", field = "Tip", slk = "Profile", index = -1, ["repeat"] = 1, data = 0 },
        }),
        ["Units\\AbilityData.slk"] = sylk({ "alias", "Cool1", "Cool2", "DataA1", "DataA2" }, {
            { alias = "Zbz1", Cool1 = 6, Cool2 = 5, DataA1 = 30, DataA2 = 40 },
        }),
        ["Units\\HumanAbilityFunc.txt"] = "[Zbz1]\nHotkey=B\nTip=Blizzard - [|cffffcc00Level 1|r],Blizzard - [|cffffcc00Level 2|r]\n",
    }
    local chain = { read = function(_, p) local f = files[p]; if not f then error("no " .. p) end return f end }
    local abilities = { custom = { A001 = { parent_id = "Zbz1" } }, mods = {} }
    function abilities:has(id) return id == "A001" end
    function abilities:get_modification(id, code, level)
        if code == "acdn" and level == 2 then return 3 end
        return nil
    end
    local S = object_stock.new(chain, abilities, "abilities")
    test("a levelled column (Cool1, Cool2)", S:value("Zbz1", "acdn", 1) == 6 and S:value("Zbz1", "acdn", 2) == 5)
    test("a data field (DataA2)", S:value("Zbz1", "Hbz1", 2) == 40)
    test("a profile field", S:value("Zbz1", "ahky") == "B")
    test("a levelled profile field: its level's entry", S:value("Zbz1", "atp1", 2):find("Level 2") ~= nil)
    test("a custom ability: its parent's values", S:value("A001", "acdn", 1) == 6)
    local v, from = S:value("A001", "acdn", 2)
    test("and the map's change at its level", v == 3 and from == "map")
    test("upgrades are a kind too", object_stock.KINDS.upgrades.metadata:find("Upgrade") ~= nil)
end
-- }}}

-- {{{ Gameplay constants
test_section("Gameplay constants")
do
    local C = gc.load({})
    test("defaults: level 2 needs 200, 3 needs 500, 4 needs 900", C:hero_xp_needed(2) == 200
        and C:hero_xp_needed(3) == 500 and C:hero_xp_needed(4) == 900)
    test("a level-1 unit's kill is worth 25, level 3 60", C:kill_xp(1) == 25 and C:kill_xp(3) == 60)
    test("a level-2 hero's kill is worth 120", C:kill_xp(2, true) == 120)
    local tier, tax = C:upkeep(60)
    test("upkeep: 60 food is low upkeep, 30% gold", tier == 1 and math.abs(tax - 0.3) < 1e-9)
    test("the damage table: pierce against small doubles", C:damage_factor("pierce", "small") == 2)
    local M = gc.load({ map_text = "[Misc]\nFoodCeiling=300\nUpkeepUsage=0,0,0\nUpkeepGoldTax=0.00,0.00\nNeedHeroXP=400\nNeedHeroXPFormulaB=280.0\n" })
    test("a map's constants replace the defaults", M:get("FoodCeiling") == 300 and M.origins.FoodCeiling == "map")
    test("zeros switch upkeep off", (M:upkeep(90)) == 0)
    test("the map's experience curve", M:hero_xp_needed(2) == 400 and M:hero_xp_needed(3) == 400 + 280 * 3)
    test("levels from experience", M:level_for_xp(0) == 1 and M:level_for_xp(400) == 2 and M:level_for_xp(1239) == 2)
end
-- }}}

-- {{{ A game on DAoW: gathering, upkeep, bounty, scores, the script
test_section("DAoW 5.4b: the economy running")
do
    local map_scene = require("demo.wc3map.scene")
    local game_mod = require("demo.wc3map.game")
    local s = map_scene.load(DIR .. "/assets/DAoW-5.4b-PUBLIC-TEST.w3x")
    local g = game_mod.new(s, { player = 0, placed = false, minimap = false, vision = false })
    local VM = g.run_script({ ai = "none" })
    local N = VM.natives
    test("the map's constants are read (DAoW's food ceiling 300)", g.constants:get("FoodCeiling") == 300
        and g.food_ceiling(0) == 300)
    test("and upkeep is off", (g.upkeep(0)) == 0)

    -- a hall, a mine and workers on open ground near the player's units
    local own
    for _, u in ipairs(g.units) do if u.player == 0 and u.alive and u.spec.design == "unit" then own = own or u end end
    local x, y = own.x, own.y
    local hall = g.spawn("htow", 0, x + 400, y, 0)
    local mine = g.spawn("ngol", 15, x - 500, y, 0)
    N.SetResourceAmount(mine, 25)
    local p = N.Player(0)
    local gold0 = N.GetPlayerState(p, "PLAYER_STATE_RESOURCE_GOLD")
    test("a mine's gold, as the script set it", N.GetResourceAmount(mine) == 25 and g.is_mine(mine))
    test("a hall takes gold and lumber back", g.takes(hall, "gold") and g.takes(hall, "lumber"))
    local worker = g.spawn("hpea", 0, x, y, 0)
    worker.spec.archetype = "worker"   -- (whatever the classifier guessed)
    local fired = 0
    local trig = N.CreateTrigger()
    N.TriggerRegisterPlayerStateEvent(trig, p, "PLAYER_STATE_RESOURCE_GOLD", "GREATER_THAN_OR_EQUAL", gold0 + 10)
    N.TriggerAddAction(trig, function() fired = fired + 1 end)
    test("a worker takes a gather order on a mine", g.order({ worker }, "gather", mine.x, mine.y, mine))
    -- (45 s: DAoW's base stands between the mine and the hall, and its
    -- buildings are walked round since issue 541)
    for _ = 1, 60 * 45 do g.tick(1 / 60) end
    local gold1 = N.GetPlayerState(p, "PLAYER_STATE_RESOURCE_GOLD")
    test("gold comes back from the mine", gold1 >= gold0 + 20, gold0 .. " -> " .. gold1)
    test("the mine runs dry and falls", (mine.gold or 0) <= 0 and not mine.alive)
    test("gathered gold is counted", N.GetPlayerState(p, "PLAYER_STATE_GOLD_GATHERED") >= 20
        and N.GetPlayerScore(p, "PLAYER_SCORE_GOLD_MINED_TOTAL") >= 20)
    test("a player state event fired when gold passed its mark", fired == 1, tostring(fired))

    -- lumber: the tree nearest the worker
    local tree = g.nearest_tree(worker.x, worker.y, 3000)
    if tree then
        local lumber0 = N.GetPlayerState(p, "PLAYER_STATE_RESOURCE_LUMBER")
        g.order({ worker }, "gather", tree.x, tree.y)
        local hall2 = g.spawn("htow", 0, tree.x + 300, tree.y, 0)
        for _ = 1, 60 * 40 do g.tick(1 / 60) end
        local lumber1 = N.GetPlayerState(p, "PLAYER_STATE_RESOURCE_LUMBER")
        test("lumber comes back from the trees", lumber1 >= lumber0 + 10, lumber0 .. " -> " .. lumber1)
        test("a tree gives up its lumber", tree.lumber < economy.TREE_LUMBER)
        g.remove(hall2)
    end

    -- upkeep with the stock constants: food 60 is taxed 30%
    local C = gc.load({})
    local saved = g.constants
    g.constants = C
    local state = g.state(0)
    local before = state.gold
    local fake_food = g.food
    g.food = function() return 60, 100 end
    local kept = g.income(0, "gold", 10)
    g.food = fake_food
    g.constants = saved
    test("upkeep takes its share of gold brought in", kept == 7 and state.gold == before + 7)

    -- bounty and scores: a creep killed by the player
    g.data.units = { value = function(_, id, code)
        return ({ ubba = 20, ubdi = 2, ubsi = 1 })[code]
    end, list = function() return {} end }
    local creep = g.spawn("nwlt", 12, x + 200, y + 200, 0)
    local gold_before = g.state(0).gold
    local killed_before = N.GetPlayerScore(p, "PLAYER_SCORE_UNITS_KILLED")
    g.kill(creep, own)
    test("a creep's bounty to its killer's owner (20 + 2d1)", g.state(0).gold == gold_before + 22)
    test("and the kill is counted", N.GetPlayerScore(p, "PLAYER_SCORE_UNITS_KILLED") == killed_before + 1)
    test("food used through the script", N.GetPlayerState(p, "PLAYER_STATE_RESOURCE_FOOD_USED") == (g.food(0)))
    test("the natives aren't no-ops", not VM.noop.SetResourceAmount)
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

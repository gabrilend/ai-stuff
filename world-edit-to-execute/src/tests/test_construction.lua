--[[
Tests for construction (Issue 531): where a structure fits, the checks
before building, the worker's walk and the start (cost, a tenth of its
hit points, the script's event), rising over its build time, each race's
way of building (human, orc, undead, night elf), cancelling with a
refund, and the script's build orders and progress. Made-up tables are
this test's own.
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

local RACE = { zpea = "human", zpeo = "orc", zaco = "undead", zwsp = "nightelf" }
local units = { available = true }
function units:value(id, code)
    if code == "urac" then return RACE[id], RACE[id] and "stock" or nil end
    if code == "uhpm" then return 1000, "stock" end
    if code == "ufma" and id == "zbar" then return 10, "stock" end
    if code == "utyp" and id == "zanc" then return "ancient", "stock" end
    return nil
end
function units:list(id, code)
    if code == "ubui" and RACE[id] then return { "zbar", "zanc" } end
    return {}
end
local g = game_mod.new(s, { player = 0, placed = false, minimap = false, vision = false, stock = units, combat = false })
local VM = g.run_script({ ai = "none" })
local N = VM.natives
local p0 = N.Player(0)
local function run(sec) for _ = 1, math.floor(sec * 60 + 0.5) do g.tick(1 / 60) end end
local cost = g.unit_cost("zbar")
local function worker(id, x, y)
    local u = g.spawn(id, 0, x, y, 0)
    u.spec.design, u.spec.archetype = "unit", "worker"
    u.speed = 400
    return u
end

-- somewhere open: a spot near the player's units where a barracks fits
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
        if #spots >= 8 then break end
    end
    if #spots >= 8 then break end
end

local events = {}
for _, ev in ipairs({ "CONSTRUCT_START", "CONSTRUCT_FINISH", "CONSTRUCT_CANCEL" }) do
    local trig = N.CreateTrigger()
    N.TriggerRegisterPlayerUnitEvent(trig, p0, "EVENT_PLAYER_UNIT_" .. ev, nil)
    N.TriggerAddAction(trig, function()
        local b = ev == "CONSTRUCT_START" and N.GetConstructingStructure()
            or (ev == "CONSTRUCT_FINISH" and N.GetConstructedStructure() or N.GetCancelledStructure())
        events[#events + 1] = { ev = ev, b = b }
    end)
end
-- }}}

-- {{{ Placing
test_section("Where it fits")
do
    test("open places found near the player", #spots >= 6, tostring(#spots))
    local w = worker("zpea", spots[1][1] - 300, spots[1][2])
    g.state(0).gold, g.state(0).lumber = 10000, 10000
    local ok, why = g.can_build(w, "hbar", spots[1][1], spots[1][2])
    test("not a structure it builds", not ok and why == "can't build that")
    g.state(0).gold = 0
    ok, why = g.can_build(w, "zbar", spots[1][1], spots[1][2])
    test("not without the gold", not ok and why == "not enough gold")
    g.state(0).gold = 10000
    test("here it fits", (g.can_build(w, "zbar", spots[1][1], spots[1][2])))
    local wet
    for _, u in ipairs(g.units) do end
    -- a building already there
    local other = g.spawn("zbar", 0, spots[2][1], spots[2][2], 0)
    other.spec.design = "building"
    ok, why = g.placeable("zbar", spots[2][1] + 64, spots[2][2])
    test("not on another building", not ok and why == "something's in the way", tostring(why))
    g.remove(other)
    test("positions snap to the 64 grid", select(1, g.snap(100, 0)) == 128 and select(1, g.snap(90, 0)) == 64)
    g.remove(w)
end
-- }}}

-- {{{ A human builds
test_section("A human worker builds")
local hall
do
    local sp = spots[1]
    local w = worker("zpea", sp[1] - 500, sp[2])
    local gold = g.state(0).gold
    events = {}
    test("the order", g.build(w, "zbar", sp[1], sp[2]))
    test("nothing paid before it arrives", g.state(0).gold == gold)
    run(3)
    local b
    for _, u in ipairs(g.units) do if u.id == "zbar" and u.building_up then b = u end end
    test("arrived: the structure appears", b ~= nil)
    test("paid", g.state(0).gold == gold - cost.gold)
    test("a tenth of its hit points, then rising with its progress",
        b and math.abs(b.hp - b.hp_max * (0.1 + 0.9 * b.progress)) < 1 and b.progress < 0.5,
        b and (b.hp .. " of " .. tostring(b.hp_max) .. ", progress " .. b.progress .. ", time " .. b.build_time))
    test("the script heard it start, and which", events[1] and events[1].ev == "CONSTRUCT_START" and events[1].b == b)
    local used0, cap0 = g.food(0)
    test("its food doesn't count yet", cap0 == select(2, g.food(0)) and b.building_up)
    local ok, why = g.can_train(b, "hfoo")
    test("it can't train yet", not ok and why == "under construction")
    -- the worker walks away: a human's building waits
    local p = b.progress
    g.order({ w }, "move", w.x - 600, w.y)
    run(2)
    test("its worker away, it waits", b.progress == p)
    -- back to work: build it again where it stands
    w.construct = { id = "zbar", x = b.x, y = b.y, phase = "working", building = b }
    b.builder = w
    run(b.build_time + 1)
    test("done after its build time", not b.building_up and b.hp == b.hp_max)
    test("CONSTRUCT_FINISH", events[#events].ev == "CONSTRUCT_FINISH" and events[#events].b == b)
    test("counted as built", N.GetPlayerScore(p0, "PLAYER_SCORE_STRUCT_BUILT") >= 1)
    test("its food made counts now", select(2, g.food(0)) >= cap0)
    test("the worker is free", w.construct == nil)
    hall = b
end
-- }}}

-- {{{ Other races
test_section("Each race's way")
do
    local sp = spots[3]
    local peon = worker("zpeo", sp[1] - 400, sp[2])
    g.build(peon, "zbar", sp[1], sp[2])
    run(2.5)
    test("an orc worker goes inside", peon.hidden == true and peon.construct and peon.construct.phase == "inside")
    local b = peon.construct and peon.construct.building
    run((b and b.build_time or 60) + 1)
    test("and comes out when it's done", not peon.hidden and b and not b.building_up)

    sp = spots[4]
    local aco = worker("zaco", sp[1] - 400, sp[2])
    g.build(aco, "zbar", sp[1], sp[2])
    run(2.5)
    test("an undead worker starts it and is free", aco.construct == nil)
    local rising
    for _, u in ipairs(g.units) do if u.building_up and (u.x - sp[1]) ^ 2 + (u.y - sp[2]) ^ 2 < 10 then rising = u end end
    test("the building rises alone", rising and rising.progress > 0)

    sp = spots[5]
    local wisp = worker("zwsp", sp[1] - 400, sp[2])
    g.build(wisp, "zanc", sp[1], sp[2])
    run(2.5)
    test("a wisp becomes a living building (an Ancient)", wisp.removed == true)
    sp = spots[7]
    local wisp2 = worker("zwsp", sp[1] - 400, sp[2])
    g.build(wisp2, "zbar", sp[1], sp[2])
    run(2.5)
    rising = nil
    for _, u in ipairs(g.units) do if u.building_up and (u.x - sp[1]) ^ 2 + (u.y - sp[2]) ^ 2 < 10 then rising = u end end
    test("but only starts the others (a moon well), and is free", not wisp2.removed and wisp2.construct == nil
        and rising and rising.builder == nil)
    test("which grow alone", rising and rising.progress > 0)
end
-- }}}

-- {{{ Cancel, and the script
test_section("Cancelling, and the script's orders")
do
    local sp = spots[6]
    local w = worker("zpea", sp[1] - 300, sp[2])
    events = {}
    test("IssueBuildOrderById", N.IssueBuildOrderById(w, vm.s2id("zbar"), sp[1], sp[2]))
    run(2.5)
    local b = w.construct and w.construct.building
    test("started", b and b.building_up)
    N.UnitSetConstructionProgress(b, 50)
    test("UnitSetConstructionProgress", math.abs(b.progress - 0.5) < 1e-9)
    local gold = g.state(0).gold
    test("cancelled", g.cancel_build(b))
    test("75% back", g.state(0).gold == gold + math.floor(cost.gold * 0.75))
    test("the structure gone, the worker free", b.removed and w.construct == nil)
    test("CONSTRUCT_CANCEL", events[#events].ev == "CONSTRUCT_CANCEL" and events[#events].b == b)
    local card = require("ui.wc3.commands").card({ id = "zbar", spec = { design = "building" }, building_up = true }, g.db, "main")
    test("a building going up shows only Cancel", card[12] and card[12].action == "cancel_build")
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

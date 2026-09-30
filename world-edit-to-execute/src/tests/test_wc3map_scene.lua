--[[
Tests for model designs, object classification and the WC3 map scene
(Issue 517). Headless.
]]

-- {{{ Setup paths
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local designs = require("geometry.designs")
local classify = require("demo.wc3map.classify")
local map_scene = require("demo.wc3map.scene")
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

local function near(a, b, tol)
    return math.abs(a - b) <= (tol or 1e-6)
end
-- }}}

-- {{{ Designs
test_section("Designs")

local all = {
    { design = "tree", tileset = "L" }, { design = "tree", tileset = "N", style = "pine" },
    { design = "rock" }, { design = "plant" }, { design = "prop" }, { design = "prop", style = "lamp" },
    { design = "structure" }, { design = "structure", style = "wall" },
}
for _, race in ipairs({ "human", "orc", "undead", "nightelf", "neutral" }) do
    for _, size in ipairs({ "small", "medium", "hall", "tower", "altar", "special" }) do
        all[#all + 1] = { design = "building", race = race, size = size, team = 1 }
    end
end
for _, a in ipairs({ "infantry", "ranged", "gunner", "caster", "mounted", "heavy", "flyer",
                     "siege", "ship", "worker", "beast" }) do
    all[#all + 1] = { design = "unit", archetype = a, race = "orc", team = 3 }
end
local empty = 0
for _, spec in ipairs(all) do
    if #designs.build(spec, 0, 0, 0, 0, 1) == 0 then empty = empty + 1 end
end
test(#all .. " designs each build something", empty == 0)
test("an unknown design still draws", #designs.build({ design = "???" }, 0, 0, 0, 0, 1) > 0)

-- placement: a part 10 ahead, turned a quarter to the left, lands 10 north
local placed = designs.place({ { kind = "box", x = 10, y = 0, z = 0, len = 4, wid = 2, hgt = 1, yaw = 0 } },
    100, 200, 30, math.pi / 2, { 2, 3, 4 })
local b = placed[1]
test("placement turns and moves", near(b.x, 100) and near(b.y, 220) and near(b.z, 30))
test("placement scales each axis", near(b.len, 8) and near(b.wid, 6) and near(b.hgt, 4))
test("placement adds the facing", near(b.yaw, math.pi / 2))

local hero = designs.build({ design = "unit", hero = true }, 0, 0, 0, 0, { 1, 1, 1 })
local plain = designs.build({ design = "unit" }, 0, 0, 0, 0, 1)
test("a hero is larger and ringed", #hero > #plain)
test("team colours: 12 players and the neutrals", designs.TEAM[0] and designs.TEAM[11]
    and designs.TEAM[12] and designs.TEAM[15])
-- }}}

-- {{{ Classify
test_section("Classify")

local function unit(id, info) return classify.unit(id, info) end
local s = unit("h054", { model = "buildings\\other\\DragonBuildingBlack\\DragonBuildingBlack.mdl" })
test("model path: a building", s.design == "building" and s.by == "model")
s = unit("h900", { model = "units\\human\\Gryphon\\Gryphon.mdl" })
test("model path: a flyer", s.archetype == "flyer" and s.by == "model")
s = unit("h051", { name = "Tandred's Flagship", parent = "hbsh" })
test("name: a ship", s.archetype == "ship" and s.by == "name")
s = unit("n003", { name = "|cffffd700Control Point/10g|r" })
test("name inside colour codes", s.design == "building" and s.size == "special")
s = unit("n001", { name = "Iron Maiden" })
test("whole words only ('den' is not in 'Maiden')", s.design == "unit")
s = unit("h015", { name = "Reginald Windsor", parent = "hkni" })
test("parent: a copy of the knight rides", s.archetype == "mounted" and s.by == "parent")
s = unit("owtw")
test("stock table: orc watch tower", s.design == "building" and s.size == "tower" and s.by == "table")
s = unit("Hpal")
test("stock table: a hero", s.hero and s.by == "table")
s = unit("Nzzz")
test("convention: capital letter is a hero", s.hero and s.by == "guess")
s = unit("uzzz")
test("convention: first letter is the race", s.race == "undead")

test("pathing blockers draw nothing", classify.doodad("YTpb") == nil)
test("named blockers draw nothing", classify.doodad("B011", { name = "Pathing Blocker (Huge)" }) == nil)
test("tree by id", classify.doodad("LTlt").design == "tree")
test("northrend trees are pines", classify.doodad("NTtw").style == "pine")
test("rock by id", classify.doodad("ARrk").design == "rock")
test("custom tree by parent", classify.doodad("B005", { parent = "LTlt" }).design == "tree")
test("wall by model", classify.doodad("D00X",
    { model = "Doodads\\LordaeronSummer\\Terrain\\StoneWall0\\StoneWall04.mdl" }).style == "wall")
-- }}}

-- {{{ Script units
test_section("Units from a script")

local script = [[
function a takes nothing returns nothing
local player p=Player($C)
local unit u
set u=CreateUnit(p,'nban',100.,200.,90.)
set p=Player(3)set u=CreateUnit(p,'hfoo',-5.5,6,270.)
call CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE),'ngol',0,0,0)
set u=CreateUnit(p,'hkni',GetRectCenterX(r),0,0)
endfunction
]]
local su = map_scene.script_units(script)
test("literal positions only", #su == 3, #su .. " found")
test("local player variable", su[1] and su[1].player == 12 and su[1].id == "nban")
test("set player variable", su[2] and su[2].player == 3 and near(su[2].x, -5.5))
test("inline player constant", su[3] and su[3].player == 15)
test("hex player numbers", map_scene.player_number("$B") == 11 and map_scene.player_number("0x0A") == 10)
-- }}}

-- {{{ A whole map
test_section("Daow4.4")

local m = map_scene.load(DIR .. "/assets/Daow4.4.w3x")
test("doodads and units", m.counts.doodads > 1000 and m.counts.units > 1000, map_scene.summary(m))
local registry = #m.map.registry.doodads
test("every doodad drawn or skipped", m.counts.doodads + m.counts.skipped == registry)

local bad_owner, off_ground = 0, 0
for _, u in ipairs(m.units) do
    if u.player < 0 or u.player > 15 then bad_owner = bad_owner + 1 end
    local ground = m.sample.ground_at(u.x, u.y)
    if u.spec.archetype == "ship" then
        if u.z < ground - 1e-6 then off_ground = off_ground + 1 end
    elseif not near(u.z, ground, 1e-6) then
        off_ground = off_ground + 1
    end
end
test("owners are players 0-15", bad_owner == 0)
test("units stand on the ground (ships on the water)", off_ground == 0)

local guessed = 0
for _, u in ipairs(m.units) do if u.spec.by == "guess" then guessed = guessed + 1 end end
test("under a third of units guessed", guessed < #m.units / 3,
    string.format("%d of %d", guessed, #m.units))

local heights, colors, water = map_scene.terrain_arrays(m)
local w, h = m.terrain.width, m.terrain.height
test("height array", #heights == w * h * 4)
test("colour array", #colors == (w - 1) * (h - 1) * 3)
test("water array", #water == w * h * 4)
test("primitives for every object", #map_scene.prims(m) > m.counts.doodads + m.counts.units)
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

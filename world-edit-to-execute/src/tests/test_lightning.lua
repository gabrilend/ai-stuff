--[[
Tests for attachment points that follow the animation, and lightning
(Issue 538): where an attachment is in a posed model (a made-up arm with
a hand that turns), effects following it; lightning types (stand-ins
without the install), bolts between units and points, timed and
channelled bolts, a spell's lightning (alig), the script's lightning
natives, and the bolt's drawn shape. Made-up tables are this test's own.
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
local function near(a, b, e) return math.abs(a - b) < (e or 1e-3) end
-- }}}

local anim = require("assets.anim")
local draw_effects = require("demo.wc3map.draw_effects")

-- {{{ Attachment points in a pose
test_section("Attachment points follow the animation")
do
    local s = math.sqrt(0.5)
    local m = {
        sequences = { { name = "Stand", start = 0, finish = 1000, move_speed = 0, non_looping = false, rarity = 0 } },
        global_sequences = {},
        bones = {
            { name = "root", id = 0, parent = -1, flags = 0, tracks = {} },
            { name = "arm", id = 1, parent = 0, flags = 0, tracks = {
                KGRT = { interpolation = 1, keys = {
                    { frame = 0, value = { 0, 0, 0, 1 } }, { frame = 1000, value = { 0, 0, s, s } } } } } },
        },
        helpers = {},
        attachments = { { name = "Hand Right Ref", id = 2, parent = 1, flags = 0, tracks = {} } },
        pivots = { { 0, 0, 0 }, { 0, 0, 100 }, { 100, 0, 100 } },
        geosets = {}, geoset_animations = {}, materials = {}, textures = {},
    }
    local rig = anim.rig(m, {}, {})
    local st = anim.state()
    anim.play(rig, st, "stand")
    test("no pose yet: nothing", anim.attachment(rig, st, 2) == nil)
    st.t = 0
    anim.pose(rig, st)
    local p = anim.attachment(rig, st, 2)
    test("at rest: where its pivot is", p and near(p[1], 100) and near(p[2], 0) and near(p[3], 100))
    st.t = 1000
    anim.pose(rig, st)
    p = anim.attachment(rig, st, 2)
    test("the arm a quarter turned: the hand with it", p and near(p[1], 0, 0.5) and near(p[2], 100, 0.5) and near(p[3], 100),
        p and string.format("%.1f %.1f %.1f", p[1], p[2], p[3]))
    -- from the pose cache too
    st.t = 0
    anim.pose(rig, st)
    st.t = 1000
    anim.pose(rig, st)
    p = anim.attachment(rig, st, 2)
    test("a cached pose keeps its points", p and near(p[2], 100, 0.5))
    local u = { facing = 0, anim = st }
    local dx, dy, dz = draw_effects.attach_offset(u, "hand right", m, 2, rig)
    test("an effect on the hand goes where the animation has it (scaled)", near(dx, 0, 1) and near(dy, 200, 1) and near(dz, 200))
    dx, dy, dz = draw_effects.attach_offset(u, "hand right", m, 1, nil)
    test("without a rig: its rest place", near(dx, 100) and near(dy, 0))
    u.facing = math.pi / 2
    dx, dy = draw_effects.attach_offset(u, "hand right", m, 1, rig)
    test("turned with the unit", near(dx, -100, 1) and near(dy, 0, 1))
end
-- }}}

-- {{{ The game
local map_scene = require("demo.wc3map.scene")
local game_mod = require("demo.wc3map.game")
local s = map_scene.load(DIR .. "/assets/DAoW-5.4b-PUBLIC-TEST.w3x")
local g = game_mod.new(s, { player = 0, placed = false, minimap = false, vision = false, combat = false })
local VM = g.run_script({ ai = "none" })
local N = VM.natives
local ABIL = { AHtb = { amcs = 0, acdn = 0, aran = 800, adur = 2, Htb1 = 50, alig = "CLPB" } }
local ab = { available = true }
function ab:base(id) return id end
function ab:value(id, code) local v = (ABIL[id] or {})[code] return v, v ~= nil and "stock" or nil end
function ab:profile_field() return nil end
function ab:list() return {} end
g.data.abilities = ab
local function run(sec) for _ = 1, math.floor(sec * 60 + 0.5) do g.tick(1 / 60) end end
local own
for _, u in ipairs(g.units) do
    if u.player == 0 and u.alive and u.spec.design == "unit" and not u.spec.hero then own = own or u end
end
local X, Y = own.x, own.y
-- }}}

-- {{{ Lightning
test_section("Lightning")
do
    local t = g.lightning_type("clpb")
    test("a type by its code (any case)", t.code == "CLPB" and t.width > 0)
    test("without the install: a stand-in colour", t.standin and t.b >= t.r)
    local a = g.spawn("Hpal", 0, X, Y, 0)
    local b = g.spawn("hfoo", 0, X + 400, Y, 0)
    local l = g.add_lightning("DRAL", { unit = a }, { unit = b }, { duration = 1 })
    local x1, y1, z1, x2, y2, z2 = g.lightning_ends(l)
    test("between two units, at chest height", x1 == a.x and x2 == b.x and z1 > (a.z or 0))
    b.x = b.x + 100
    x1, y1, z1, x2 = g.lightning_ends(l)
    test("its ends follow them", x2 == b.x)
    run(0.5)
    test("there for its time", #g.lightnings == 1)
    run(0.6)
    test("then gone", #g.lightnings == 0)
    local c = { caster = a }
    a.casting = c
    local ch = g.add_lightning("DRAL", { unit = a }, { unit = b })
    ch.channel = c
    run(1)
    test("a channelled one stays while it channels", #g.lightnings == 1)
    a.casting = nil
    run(0.1)
    test("and goes when it stops", #g.lightnings == 0)
    local p = g.add_lightning("FORK", { unit = a }, { x = X, y = Y + 300, z = 50 })
    test("to a point, at its height", select(6, g.lightning_ends(p)) == 50)
    g.destroy_lightning(p)
    run(0.1)
    test("destroyed: gone", #g.lightnings == 0)
    -- a spell's lightning
    a.mana_max, a.mana = 1000, 1000
    a.abilities = { AHtb = 1 }
    local foe = g.spawn("nwlt", 12, X + 300, Y, 0)
    foe.hp_max, foe.hp = 5000, 5000
    test("cast", (g.cast(a, "AHtb", foe)))
    local seen
    for _ = 1, 60 do
        g.tick(1 / 60)
        for _, bl in ipairs(g.lightnings) do if bl.code == "CLPB" and bl.to.unit == foe then seen = bl end end
    end
    test("its lightning (alig) from the caster to the target", seen ~= nil and seen.from.unit == a)
    run(1)
    test("for a moment", #g.lightnings == 0)
    g.remove(a); g.remove(b); g.remove(foe)
end
-- }}}

-- {{{ The script's lightning
test_section("The script's lightning")
do
    local l = N.AddLightning("CLPB", true, X, Y, X + 500, Y)
    test("AddLightning: a bolt at the ground", l and #g.lightnings == 1
        and near(select(3, g.lightning_ends(l)), g.ground_at(X, Y)))
    test("AddLightningEx: its heights", select(6, g.lightning_ends(N.AddLightningEx("DRAM", true, X, Y, 10, X, Y + 300, 300))) == 300)
    test("MoveLightningEx", N.MoveLightningEx(l, true, X, Y, 5, X + 100, Y, 7) and select(4, g.lightning_ends(l)) == X + 100)
    test("SetLightningColor", N.SetLightningColor(l, 1, 0, 0, 0.5) and N.GetLightningColorR(l) == 1
        and N.GetLightningColorA(l) == 0.5)
    local loc1, loc2 = N.Location(X, Y), N.Location(X + 50, Y + 50)
    local bj = N.AddLightningLoc("HWPB", loc1, loc2)
    test("AddLightningLoc sets the last created", N.GetLastCreatedLightningBJ() == bj)
    test("DestroyLightning", N.DestroyLightning(l) and N.DestroyLightningBJ(bj))
    g.tick(1 / 60)
    test("gone from the world", #g.lightnings == 1)
    test("not no-ops", not VM.noop.AddLightning and not VM.noop.DestroyLightning and not VM.noop.MoveLightning)
end
-- }}}

-- {{{ The drawn bolt
test_section("Its drawn shape")
do
    local q = draw_effects.bolt(0, 0, 0, 640, 0, 0, 20, 64, { 255, 255, 255 }, 7, 0)
    test("segments of about its length, three quads each", #q == 30, tostring(#q))
    local first, last = q[2].pts[1], q[#q - 1].pts[2]
    test("from one end to the other", near(first[1], 0) and near(last[1], 640))
    local bent = false
    for i = 1, #q, 3 do if math.abs(q[i].pts[2][2]) > 5 then bent = true end end
    test("jagged between", bent)
    local q2 = draw_effects.bolt(0, 0, 0, 640, 0, 0, 20, 64, { 255, 255, 255 }, 7, 0.25)
    test("flickering: other bends a moment later", q2[1].pts[2][2] ~= q[1].pts[2][2])
    test("a bolt of no length: nothing", #draw_effects.bolt(1, 1, 1, 1, 1, 1) == 0)
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

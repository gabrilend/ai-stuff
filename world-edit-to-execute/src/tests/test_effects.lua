--[[
Tests for spell art and targeting (Issue 530): art read from the map's
changes over the stock profiles, effects (at points, on units, timed,
destroyed), missiles carrying a spell's effect, caster and target art,
buff and aura art, the script's effect natives, "targets allowed", and
DAoW's own art overrides. Made-up tables are this test's own.
]]

-- {{{ Setup paths
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path
local buffs = require("demo.wc3map.buffs")
local effects = require("demo.wc3map.effects")
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

-- {{{ DAoW's own art overrides (the map's changes, no install)
test_section("DAoW's art overrides")
local g = game_mod.new(s, { player = 0, placed = false, minimap = false, vision = false, combat = false })
local VM = g.run_script({ ai = "none" })
local N = VM.natives
do
    local missile = g.ability_art("A0AI", 1, "missile")
    test("a custom Storm Bolt's own missile", missile[1] and missile[1]:find("MoonPriestessMissile") ~= nil,
        tostring(missile[1]))
    local aura = g.ability_art("A0FZ", 1, "target")
    test("an aura's target art: a model the map imports", aura[1] == "war3mapImported\\lightaura.mdx", tostring(aura[1]))
    local A = require("assets").open(DIR .. "/assets/DAoW-5.4b-PUBLIC-TEST.w3x", { root = DIR })
    test("which the asset source finds", A:model(aura[1]) ~= nil)
    -- an imported model's attachment points
    local att
    local mpq = require("mpq")
    local ar = mpq.open(DIR .. "/assets/DAoW-5.4b-PUBLIC-TEST.w3x")
    for _, name in ipairs(ar:list()) do
        local ok, d = pcall(ar.extract, ar, name)
        if not att and ok and d and d:sub(1, 4) == "MDLX" then
            local m = require("parsers.mdx").parse(d)
            for _, node in ipairs(m.attachments or {}) do
                if (node.name or ""):lower():find("overhead") then att = m end
            end
        end
    end
    ar:close()
    if att then
        local dx, dy, dz = require("demo.wc3map.draw_effects").attach_offset({ facing = 0 }, "overhead", att, 1)
        test("an Overhead Ref attachment sits above the model's feet", dz > 40, tostring(dz))
    end
end
-- }}}

-- {{{ Made-up tables: art for a Storm Bolt, a buff with art, an aura
local ABIL = {
    AHtb = { amcs = 0, acdn = 0, aran = 800, adur = 2, Htb1 = 50, acat = "Caster.mdl", atat = "Target.mdl,Target2.mdl",
             amat = "Bolt.mdl", amsp = 500 },
    AHad = { aare = 600, Had1 = 2, atat = "Aura.mdl" },
    AHtc = { aare = 300, Htc1 = 10, atar = "enemies,ground,nonhero" },
    AHhb = { aran = 600, Hhb1 = 10, atar = "friend,self" },
}
local ab = { available = true }
function ab:base(id) return id end
function ab:value(id, code) local v = (ABIL[id] or {})[code] return v, v ~= nil and "stock" or nil end
function ab:profile_field(id, name) return nil end
function ab:list() return {} end
local bf = { available = true }
function bf:base(id) return id end
function bf:value(id, code) if id == "BPSE" and code == "ftat" then return "Stun.mdl", "stock" end return nil end
function bf:profile_field() return nil end
g.data.abilities, g.data.buffs = ab, bf

local own
for _, u in ipairs(g.units) do
    if u.player == 0 and u.alive and u.spec.design == "unit" and not u.spec.hero then own = own or u end
end
local X, Y = own.x, own.y
local caster = g.spawn("Hpal", 0, X, Y, 0)
caster.mana_max, caster.mana = 1000, 1000
caster.abilities = { AHtb = 1, AHad = 1, AHtc = 1, AHhb = 1 }
local function foe(dx, dy, id)
    local u = g.spawn(id or "nwlt", 12, X + dx, Y + dy, 0)
    u.hp_max, u.hp = 5000, 5000
    return u
end
local function run(sec) for _ = 1, math.floor(sec * 60 + 0.5) do g.tick(1 / 60) end end
local function effects_with(path)
    local n = 0
    for _, fx in ipairs(g.effects) do if fx.path == path and not fx.dying then n = n + 1 end end
    return n
end
-- }}}

-- {{{ A spell's art
test_section("A spell's art and missile")
do
    local t = foe(500, 0)
    g.cast(caster, "AHtb", t)
    run(0.35)
    test("caster art on the caster", effects_with("Caster.mdl") == 1)
    test("its missile flies with its model and speed", #g.missiles == 1 and g.missiles[1].path == "Bolt.mdl"
        and g.missiles[1].speed == 500)
    test("no effect before it lands", t.hp == 5000 and effects_with("Target.mdl") == 0)
    local zmax = 0
    for _ = 1, 30 do g.tick(1 / 60); if g.missiles[1] then zmax = math.max(zmax, g.missiles[1].z) end end
    test("an arc on the way", zmax > (caster.z or 0) + 60)
    run(1)
    test("landed: the effect", t.hp < 5000 and t.stunned)
    test("and every target art on the target", effects_with("Target.mdl") == 1 and effects_with("Target2.mdl") == 1)
    local fx
    for _, e in ipairs(g.effects) do if e.path == "Stun.mdl" then fx = e end end
    test("the stun buff's art, overhead", fx and fx.unit == t and fx.attach == "overhead")
    run(2.5)
    test("the buff ends: its art is dying", fx.dying ~= nil)
    run(2)
    test("and gone after its Death", effects_with("Stun.mdl") == 0 and (function()
        for _, e in ipairs(g.effects) do if e == fx then return false end end
        return true
    end)())
    test("timed art ends too", effects_with("Caster.mdl") == 0)
    g.remove(t)
end
-- }}}

-- {{{ Aura art
test_section("An aura's art")
do
    local friend = g.spawn("hfoo", 0, X + 200, Y, 0)
    run(1)
    test("allies near show the aura's art", effects_with("Aura.mdl") >= 1)
    local made = g.effects_made
    run(3)
    test("refreshing doesn't make it again", g.effects_made == made)
    friend.x = X + 5000
    run(3)
    local on_friend = false
    for _, e in ipairs(g.effects) do if e.path == "Aura.mdl" and e.unit == friend and not e.dying then on_friend = true end end
    test("gone when out of range", not on_friend)
    g.remove(friend)
    caster.abilities.AHad = 0
end
-- }}}

-- {{{ Targets allowed
test_section("Targets allowed")
do
    local t = foe(200, 0)
    local hero_foe = foe(250, 0, "Hblm")
    hero_foe.spec.hero = true
    local ok, why = g.cast(caster, "AHhb", t)
    test("friend,self: not an enemy", not ok and why == "can't target an enemy", tostring(why))
    test("friend,self: itself", (g.cast(caster, "AHhb", caster)))
    run(1)
    local flyer = foe(150, 0)
    flyer.spec.archetype = "flyer"
    local abilities = require("demo.wc3map.abilities")
    local i = g.ability_info("AHtc", 1)
    test("enemies,ground,nonhero: a ground enemy", (abilities.target_ok(g, caster, t, i)))
    ok, why = abilities.target_ok(g, caster, hero_foe, i)
    test("not a hero", not ok and why == "can't target a hero", tostring(why))
    ok, why = abilities.target_ok(g, caster, flyer, i)
    test("not air", not ok and why == "can't target air", tostring(why))
    ok, why = abilities.target_ok(g, caster, own, i)
    test("not an ally", not ok)
    g.remove(t); g.remove(hero_foe); g.remove(flyer)
end
-- }}}

-- {{{ The script's effects
test_section("The script's effect natives")
do
    local fx = N.AddSpecialEffect("Abilities\\Spells\\Human\\ThunderClap\\ThunderClapCaster.mdl", X, Y)
    test("AddSpecialEffect: at a point", fx and fx.x == X and effects_with(fx.path) == 1)
    local fx2 = N.AddSpecialEffectTarget("Some.mdl", own, "chest")
    test("AddSpecialEffectTarget: on a unit's chest", fx2.unit == own and fx2.attach == "chest")
    own.x = own.x + 100
    run(0.1)
    test("and follows it", fx2.x == own.x)
    N.DestroyEffect(fx)
    test("DestroyEffect: dying", fx.dying ~= nil)
    run(2)
    test("then gone", effects_with(fx.path) == 0)
    test("GetAbilityEffectById", N.GetAbilityEffectById(vm.s2id("AHtb"), "EFFECT_TYPE_TARGET", 1) == "Target2.mdl")
    local fx3 = N.AddSpellEffectTargetById(vm.s2id("AHtb"), 2, own, "origin")
    test("AddSpellEffectTargetById: the ability's caster art", fx3.path == "Caster.mdl")
    N.AddSpecialEffectLocBJ(N.Location(X, Y), "Last.mdl")
    test("bj_lastCreatedEffect", N.GetLastCreatedEffectBJ().path == "Last.mdl")
    test("no longer no-ops", not VM.noop.AddSpecialEffect and not VM.noop.DestroyEffect)
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

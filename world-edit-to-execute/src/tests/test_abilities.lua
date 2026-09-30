--[[
Tests for abilities and buffs (Issue 529): ability values by level and
base, casting (range, cast point, mana, cooldown) and the script's spell
events in order, the starter set's effects (a stun, an area slow, a
channelled storm, a summon, a shield, an aura, a critical strike), a
trigger-made Channel ability, interruption, regeneration, the command
card, and the natives (spell orders, buffs as abilities, cooldown reset,
damage events). The ability tables here are made up (numbers this test's
own).
]]

-- {{{ Setup paths
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path
local buffs = require("demo.wc3map.buffs")
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

local UNIT = { uhpm = 800, udef = 0, ua1b = 10, ua1d = 1, ua1s = 2, uhpr = 0, umpr = 0 }
local units = { available = true }
function units:value(id, code) local v = UNIT[code] return v, v ~= nil and "stock" or nil end
function units:list() return {} end

-- abilities: per id, per code, a value or a list by level
local ABIL = {
    AHtb = { amcs = 75, acdn = 9, aran = 600, adur = 5, ahdu = 3, Htb1 = 100 },
    AHtc = { amcs = 90, acdn = 6, aare = 300, adur = 5, Htc1 = 60, Htc3 = 0.5, Htc4 = 0.5 },
    AHbz = { amcs = 75, acdn = 6, aran = 800, aare = 250, Hbz1 = 3, Hbz2 = 30 },
    AHwe = { amcs = 125, acdn = 20, adur = 4, Hwe1 = "hwat", Hwe2 = 1 },
    AHds = { amcs = 25, acdn = 35, adur = 3 },
    AHad = { aare = 900, Had1 = 2 },
    AOcr = { Ocr1 = 100, Ocr2 = 2 },
    A00C = { amcs = 10, acdn = 1, aran = 700, Ncl1 = 2, Ncl2 = 1, Ncl6 = "rainoffire" },
}
local BASE = { A001 = "AHtb", A00C = "ANcl" }
local abilities_data = { available = true }
function abilities_data:base(id) return BASE[id] or id end
function abilities_data:value(id, code, level)
    local t = ABIL[id] or ABIL[BASE[id] or ""] or {}
    local v = t[code]
    return v, v ~= nil and "stock" or nil
end
function abilities_data:list() return {} end

-- (combat off: the map's own units would fight the test's)
local g = game_mod.new(s, { player = 0, placed = false, minimap = false, vision = false, stock = units, combat = false })
g.data.abilities = abilities_data
local VM = g.run_script({ ai = "none" })
local N = VM.natives
local p0 = N.Player(0)

-- a quiet corner: the caster and its targets, away from the map's units
local own
for _, u in ipairs(g.units) do
    if u.player == 0 and u.alive and u.spec.design == "unit" and not u.spec.hero then own = own or u end
end
local X, Y = own.x, own.y
local caster = g.spawn("Hpal", 0, X, Y, 0)
caster.mana_max, caster.mana = 1000, 1000
caster.abilities = { A001 = 1, AHtc = 1, AHbz = 1, AHwe = 1, AHds = 1, AHad = 1, AOcr = 1, A00C = 1 }
caster.hp_regen, caster.mana_regen = 0, 0
local function foe(dx, dy)
    local u = g.spawn("nwlt", 12, X + dx, Y + dy, 0)
    u.hp_max, u.hp, u.weapon, u.hp_regen = 5000, 5000, nil, 0
    return u
end
local function run(seconds) for _ = 1, math.floor(seconds * 60 + 0.5) do g.tick(1 / 60) end end

-- the script's spell events, in order
local seen = {}
for _, ev in ipairs({ "CHANNEL", "CAST", "EFFECT", "FINISH", "ENDCAST" }) do
    local trig = N.CreateTrigger()
    N.TriggerRegisterPlayerUnitEvent(trig, p0, "EVENT_PLAYER_UNIT_SPELL_" .. ev, nil)
    N.TriggerAddAction(trig, function()
        seen[#seen + 1] = { ev = ev, id = N.GetSpellAbilityId(), target = N.GetSpellTargetUnit(),
                            x = N.GetSpellTargetX(), unit = N.GetSpellAbilityUnit() }
    end)
end
local function events() local out = {} for _, e in ipairs(seen) do out[#out + 1] = e.ev end return table.concat(out, " ") end
-- }}}

-- {{{ Values
test_section("Ability values")
do
    local i = g.ability_info("A001", 1)
    test("a custom ability's base (A001 is a Storm Bolt)", i.base == "AHtb" and i.mana == 75 and i.cooldown == 9)
    test("and its data fields", i.data("Htb1", 0) == 100 and i.data("Nope", 7) == 7)
    local _, kind = g.ability_spec("A001", 1)
    test("a unit target", kind == "unit")
    local _, ckind = g.ability_spec("A00C", 1)
    test("a Channel ability's target from its data (Ncl2 = 1: unit)", ckind == "unit")
    test("its order string from its data", g.ability_order("A00C", 1) == "rainoffire")
end
-- }}}

-- {{{ Storm Bolt
test_section("Casting a Storm Bolt")
do
    local t = foe(400, 0)
    seen = {}
    test("cast at an enemy in range", g.cast(caster, "A001", t))
    test("the cast begins: CHANNEL and CAST", events() == "CHANNEL CAST")
    test("nothing spent before the cast point", caster.mana == 1000 and t.hp == 5000)
    run(0.35)
    test("then EFFECT, FINISH, ENDCAST", events() == "CHANNEL CAST EFFECT FINISH ENDCAST", events())
    test("the events know the spell, caster and target", seen[3].id == vm.s2id("A001") and seen[3].target == t
        and seen[3].unit == caster)
    test("mana spent", caster.mana == 1000 - 75)
    test("100 damage (spells against normal armour: DAoW's table 1.0)", t.hp == 4900, tostring(t.hp))
    test("stunned (a buff)", t.stunned and buffs.has(t, "BPSE") and N.GetUnitAbilityLevel(t, vm.s2id("BPSE")) == 1)
    local ok, why = g.cast(caster, "A001", t)
    test("cooling down", not ok and why == "not ready yet")
    local card = require("ui.wc3.commands").card(caster, g.db, "main")
    local bolt
    for k = 1, 12 do if card[k] and card[k].target == "A001" then bolt = card[k] end end
    test("the command card shows its cooldown", bolt and bolt.cooldown and bolt.cooldown > 0.9)
    run(5)
    test("the stun wears off", not t.stunned)
    run(4)
    test("ready again after its cooldown", (g.ability_ready(caster, "A001")))
    caster.mana = 10
    ok, why = g.cast(caster, "A001", t)
    test("not without mana", not ok and why == "not enough mana")
    caster.mana = 1000
    ok, why = g.cast(caster, "A001", own)
    test("not at an ally", not ok and why == "can't target an ally")
    -- out of range: it walks up first
    local far = foe(1400, 0)
    g.cast(caster, "A001", far)
    run(0.2)
    test("out of range: walking, not yet cast", caster.casting and caster.casting.phase == "approach" and far.hp == 5000)
    run(6)
    test("in range, cast", far.hp < 5000)
    g.remove(far)
    g.remove(t)
    -- back where it started
    caster.x, caster.y, caster.route = X, Y, nil
    if caster.mover then caster.mover.x, caster.mover.y = X, Y end
end
-- }}}

-- {{{ Thunder Clap, Blizzard, summon, shield
test_section("Areas, channels, summons, shields")
do
    local a, b, c = foe(150, 0), foe(-150, 100), foe(700, 0)
    local friend = g.spawn("hfoo", 0, X + 100, Y - 100, 0)
    friend.hp_max, friend.hp = 1000, 1000
    g.cast(caster, "AHtc")
    run(0.4)
    test("Thunder Clap hits the enemies near", a.hp == 4940 and b.hp == 4940)
    test("not those far", c.hp == 5000)
    test("not friends", friend.hp == 1000)
    test("and slows them", a.speed_mult == 0.5 and a.attack_mult == 0.5)
    run(5)
    test("the slow wears off", a.speed_mult == 1)
    g.remove(a); g.remove(b)

    -- Blizzard: 3 waves over 3 seconds; interrupted, it stops
    seen = {}
    local d = foe(500, 300)
    g.cast(caster, "AHbz", nil, d.x, d.y)
    run(0.4)
    test("Blizzard: channelling", caster.casting and caster.casting.phase == "channel")
    run(3.2)
    test("three waves", d.hp == 5000 - 90, tostring(d.hp))
    test("then FINISH and ENDCAST", events():find("FINISH ENDCAST") ~= nil)
    run(6)
    seen = {}
    g.cast(caster, "AHbz", nil, d.x, d.y)
    run(1.5)
    local mid = d.hp
    g.order({ caster }, "stop")
    run(2)
    test("interrupted: it stops", d.hp == mid)
    test("ENDCAST without FINISH", events():find("ENDCAST") ~= nil and events():find("FINISH") == nil, events())
    g.remove(d)

    g.cast(caster, "AHwe")
    run(0.4)
    local elemental
    for _, u in ipairs(g.units) do if u.summoned and u.id == "hwat" then elemental = u end end
    test("Water Elemental: a summoned unit", elemental and elemental.player == 0)
    run(4.5)
    test("gone when its time is up", elemental and elemental.alive == false)

    g.cast(caster, "AHds")
    run(0.4)
    local hp = caster.hp
    g.damage(c, caster, 500)
    test("Divine Shield: no damage taken", caster.hp == hp)
    run(3.5)
    g.damage(c, caster, 100)
    test("after it, damage again", caster.hp < hp)
    caster.hp = caster.hp_max
    g.remove(c)
    g.remove(friend)
end
-- }}}

-- {{{ Aura, passive
test_section("Auras and passives")
do
    local near = g.spawn("hfoo", 0, X + 300, Y, 0)
    local far = g.spawn("hfoo", 0, X + 3000, Y, 0)
    run(1)
    test("Devotion Aura: armour for allies near", near.armor_bonus == 2 and (far.armor_bonus or 0) == 0)
    near.x = X + 5000
    run(2)
    test("gone when they leave", near.armor_bonus == 0)
    local t = foe(80, 0)
    test("Critical Strike (100%): double damage", g.modify_strike(caster, t, 50) == 100)
    g.remove(near); g.remove(far); g.remove(t)
end
-- }}}

-- {{{ A trigger-made ability
test_section("A Channel ability for triggers")
do
    local t = foe(300, 0)
    seen = {}
    test("cast (at a unit)", g.cast(caster, "A00C", t))
    run(0.4)
    test("EFFECT fires, and it channels", events() == "CHANNEL CAST EFFECT" and caster.casting.phase == "channel")
    run(2)
    test("FINISH and ENDCAST after its 2 seconds", events() == "CHANNEL CAST EFFECT FINISH ENDCAST", events())
    test("no effect of its own", t.hp == 5000)
    g.remove(t)
end
-- }}}

-- {{{ The script's natives
test_section("The script's ability natives")
do
    local t = foe(300, 0)
    N.UnitResetCooldown(caster)
    test("UnitResetCooldown", (g.ability_ready(caster, "A001")))
    seen = {}
    test("IssueTargetOrder with the spell's order string", N.IssueTargetOrder(caster, "thunderbolt", t))
    run(0.4)
    test("cast", t.hp == 4900 and events():find("EFFECT") ~= nil)
    test("UnitHasBuffBJ sees the stun", N.UnitHasBuffBJ(t, vm.s2id("BPSE")))
    N.UnitRemoveBuffs(t, true, true)
    test("UnitRemoveBuffs ends it", not t.stunned)
    local got
    local trig = N.CreateTrigger()
    N.TriggerRegisterUnitEvent(trig, t, "EVENT_UNIT_DAMAGED")
    N.TriggerAddAction(trig, function() got = N.GetEventDamage() end)
    N.UnitDamageTarget(caster, t, 40, true, false, nil, nil, nil)
    test("EVENT_UNIT_DAMAGED, with the damage", got and got > 0 and got <= 40, tostring(got))
    test("IssueImmediateOrder casts a no-target spell", N.IssueImmediateOrder(caster, "thunderclap"))
    g.remove(t)
end
-- }}}

-- {{{ Regeneration
test_section("Regeneration")
do
    local u = g.spawn("hfoo", 0, X + 3000, Y + 3000, 0)
    u.hp_max, u.hp, u.hp_regen = 500, 100, 2
    run(5)
    test("hit points come back (2 a second)", math.abs(u.hp - 110) < 0.5, tostring(u.hp))
    u.mana_max, u.mana, u.mana_regen = 200, 0, 1
    buffs.add(g, u, { id = "BHab", mana_regen = 1, duration = 100 })
    run(5)
    test("mana too, with a buff's bonus", math.abs(u.mana - 10) < 0.5, tostring(u.mana))
    g.remove(u)
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

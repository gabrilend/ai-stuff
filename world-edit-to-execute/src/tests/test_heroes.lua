--[[
Tests for heroes (Issue 528): attributes and what they give, experience
and levels (with DAoW's own gameplay constants), skills and their level
requirements, experience from kills shared by range, death and revival at
an altar, hero limits and tokens, and the script's hero natives and
events. The hero's type values come from a made-up stock source (numbers
this test's own).
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

local function near(a, b) return math.abs(a - b) < 1e-6 end
-- }}}

-- {{{ A game on DAoW with a made-up stock source
local map_scene = require("demo.wc3map.scene")
local game_mod = require("demo.wc3map.game")
local s = map_scene.load(DIR .. "/assets/DAoW-5.4b-PUBLIC-TEST.w3x")

local HERO = { uhpm = 100, umpm = 0, udef = 0, ustr = 20, uagi = 10, uint = 15, ustp = 2.5, uagp = 1.5, uinp = 2,
               upra = "STR", ua1b = 20, ua1d = 2, ua1s = 6, ua1c = 1.5, ua1r = 100 }
local UNIT = { uhpm = 300, udef = 1, ua1b = 10, ua1d = 1, ua1s = 2, ulev = 3 }
local LISTS = { uhab = { "AHtb", "AHbz" }, utra = { "Hpal" } }
local fake = { available = true }
function fake:value(id, code)
    local t = id:sub(1, 1):match("%u") and HERO or UNIT
    local v = t[code]
    return v, v ~= nil and "stock" or nil
end
function fake:list(id, code) return LISTS[code] or {} end

local g = game_mod.new(s, { player = 0, placed = false, minimap = false, vision = false, stock = fake })
local VM = g.run_script({ ai = "none" })
local N = VM.natives
local p0 = N.Player(0)
local own
for _, u in ipairs(g.units) do
    if u.player == 0 and u.alive and u.spec.design == "unit" and not u.spec.hero then own = own or u end
end
local x, y = own.x, own.y
local hero = g.spawn("Hpal", 0, x + 100, y, 0)
-- }}}

-- {{{ Attributes
test_section("A new hero")
do
    test("level 1, no experience, a skill point", hero.level == 1 and hero.xp == 0 and hero.skill_points == 1)
    test("its attributes", hero.str == 20 and hero.agi == 10 and hero.int == 15)
    test("hit points: 100 + 20 x 25", hero.hp_max == 600 and hero.hp == 600)
    test("mana: 15 x 15", hero.mana_max == 225)
    test("armour: 10 x 0.3", near(hero.armor, 3))
    test("damage with its primary attribute: 20 + 20 + 2d6", hero.weapon and hero.weapon.dmg_lo == 42
        and hero.weapon.dmg_hi == 52)
end
-- }}}

-- {{{ Experience
test_section("Experience and levels (DAoW's constants)")
do
    test("DAoW: level 2 needs 400", g.constants:hero_xp_needed(2) == 400)
    g.add_xp(hero, 399)
    test("399: still level 1", hero.level == 1)
    g.add_xp(hero, 1)
    test("400: level 2", hero.level == 2)
    test("a skill point for the level", hero.skill_points == 2)
    test("attributes grow (20 + 2.5)", hero.str == 22 and hero.agi == 11 and hero.int == 17)
    test("and hit points with them", hero.hp_max == 100 + 22 * 25)
    g.set_hero_level(hero, 25)
    test("the level cap (DAoW: 20)", hero.level == 20)
    g.set_hero_level(hero, 2)
    test("levels can be taken away", hero.level == 2 and hero.skill_points == 2)
end
-- }}}

-- {{{ Skills
test_section("Skills")
do
    -- DAoW's paladin has its own skill list and ability data: these
    -- tests use two skills with 3 levels, first at 1, every 2 levels
    local real = g.hero_skills(hero)
    test("its skills, from the tables (the map's list)", #real >= 1, tostring(#real))
    g.hero_skills = function() return { "AHtb", "AHbz" } end
    g.hero_ability_rules = function() return 3, 1, 2 end
    test("learning one", g.learn(hero, "AHtb") and hero.abilities.AHtb == 1 and hero.skill_points == 1)
    local ok, why = g.learn(hero, "AHtb")
    test("its second level needs hero level 3", not ok and why == "needs hero level 3", tostring(why))
    test("another at level 1", g.learn(hero, "AHbz") and hero.skill_points == 0)
    ok, why = g.learn(hero, "AHbz")
    test("no points left", not ok and why == "no skill points")
    ok, why = g.learn(hero, "AXXX")
    test("not one of its skills", not ok)
end
-- }}}

-- {{{ Kills
test_section("Experience from kills")
do
    -- the map has heroes of its own: the kill is shared with those in range
    local function takers(cx, cy)
        local n = 0
        for _, u in ipairs(g.units) do
            if u.hero and u.alive and u.player == 0 and (u.x - cx) ^ 2 + (u.y - cy) ^ 2 <= 1200 ^ 2 then n = n + 1 end
        end
        return n
    end
    local creep = g.spawn("nwlt", 12, hero.x + 300, hero.y, 0)
    local n = takers(creep.x, creep.y)
    local before = hero.xp
    g.kill(creep, own)
    test("a level-3 kill (60) shared by the heroes near it", hero.xp - before == math.floor(60 / n + 0.5),
        (hero.xp - before) .. " with " .. n)
    local far = g.spawn("nwlt", 12, hero.x + 5000, hero.y, 0)
    before = hero.xp
    g.kill(far, own)
    test("out of range: nothing", hero.xp == before)
    local hero2 = g.spawn("Hpal", 0, hero.x - 100, hero.y, 0)
    local c2 = g.spawn("nwlt", 12, hero.x + 200, hero.y, 0)
    local n2 = takers(c2.x, c2.y)
    local a, b = hero.xp, hero2.xp
    g.kill(c2, own)
    test("one more hero, a smaller share each", n2 == n + 1 and hero.xp - a == math.floor(60 / n2 + 0.5)
        and hero2.xp - b == hero.xp - a)
    hero.xp_suspended = true
    local c3 = g.spawn("nwlt", 12, hero.x + 200, hero.y, 0)
    a = hero.xp
    g.kill(c3, own)
    test("a hero whose experience is suspended takes none", hero.xp == a)
    hero.xp_suspended = nil
    g.remove(hero2)
end
-- }}}

-- {{{ Death and revival
test_section("Death and revival")
do
    local revived = 0
    local trig = N.CreateTrigger()
    N.TriggerRegisterPlayerUnitEvent(trig, p0, "EVENT_PLAYER_HERO_REVIVE_FINISH", nil)
    N.TriggerAddAction(trig, function() revived = revived + 1 end)
    g.kill(hero, nil)
    for _ = 1, 60 * 12 do g.tick(1 / 60) end
    local still = false
    for _, u in ipairs(g.units) do if u == hero then still = true end end
    test("a fallen hero stays (no decay)", still and hero.alive == false)
    local altar = g.spawn("halt", 0, x - 400, y, 0)
    altar.spec.size = "altar"
    test("an altar", g.is_altar(altar) and #g.revivable(altar) == 1)
    local gold, lumber, time = g.revive_cost(hero)
    local c = g.unit_cost(hero.id)
    local expect = math.floor(math.min(c.gold * math.min(0.2 + 0.06 * (hero.level - 1), 4), 100))
    test("revival cost by DAoW's factors (0.2 + 0.06 a level, at most 100)", gold == expect, gold .. " vs " .. expect)
    g.state(0).gold = 1000
    test("revival queued at the altar", g.revive(altar, hero) and #altar.queue == 1 and g.state(0).gold == 1000 - gold)
    test("not twice", not g.revive(altar, hero))
    for _ = 1, math.ceil(time * 60) + 5 do g.tick(1 / 60) end
    test("back on its feet", hero.alive == true and hero.hp == hero.hp_max)
    -- (regeneration adds a little over the frames after)
    test("with DAoW's revival mana (25%, and regenerating)", hero.mana >= hero.mana_max * 0.25
        and hero.mana < hero.mana_max * 0.3, hero.mana .. " of " .. hero.mana_max)
    test("the script heard it", revived == 1)
end
-- }}}

-- {{{ Limits and tokens
test_section("Hero limits and tokens")
do
    -- a building type the map doesn't define: the made-up tables say it
    -- trains the paladin
    local hall = g.spawn("zbld", 0, x - 800, y, 0)
    hall.spec.design = "building"
    g.state(0).gold, g.state(0).lumber = 5000, 5000
    N.SetPlayerMaxHeroesAllowed(1, p0)
    local ok, why = g.can_train(hall, "Hpal")
    test("the hero limit holds", not ok and why == "hero limit reached", tostring(why))
    N.SetPlayerMaxHeroesAllowed(50, p0)   -- (the map gives player 0 heroes of its own)
    local ok2, why2 = g.can_train(hall, "Hpal")
    test("a higher limit lets one through", ok2, tostring(why2))
    N.SetPlayerTechMaxAllowed(p0, require("jass.vm").s2id("Hpal"), 1)
    ok, why = g.can_train(hall, "Hpal")
    test("one of each type", not ok and why == "limit reached", tostring(why))
    N.SetPlayerTechMaxAllowed(p0, require("jass.vm").s2id("Hpal"), -1)
    N.SetPlayerState(p0, "PLAYER_STATE_RESOURCE_HERO_TOKENS", 1)
    local gold = g.state(0).gold
    test("a hero token pays for a hero", g.train(hall, "Hpal") and g.state(0).gold == gold
        and N.GetPlayerState(p0, "PLAYER_STATE_RESOURCE_HERO_TOKENS") == 0)
end
-- }}}

-- {{{ The script's natives
test_section("The script's hero natives")
do
    local levelled = 0
    local trig = N.CreateTrigger()
    N.TriggerRegisterPlayerUnitEvent(trig, p0, "EVENT_PLAYER_HERO_LEVEL", nil)
    N.TriggerAddAction(trig, function() levelled = levelled + 1 end)
    N.SetHeroLevel(hero, 5, false)
    test("SetHeroLevel: level, points, the event", N.GetHeroLevel(hero) == 5 and levelled == 1 and hero.skill_points == 3)
    N.SetHeroStr(hero, 50, true)
    test("SetHeroStr: strength, and hit points with it", N.GetHeroStr(hero, true) == 50 and hero.hp_max == 100 + 50 * 25)
    local learned
    local t2 = N.CreateTrigger()
    N.TriggerRegisterPlayerUnitEvent(t2, p0, "EVENT_PLAYER_HERO_SKILL", nil)
    N.TriggerAddAction(t2, function() learned = N.GetLearnedSkill() end)
    N.SelectHeroSkill(hero, require("jass.vm").s2id("AHtb"))
    test("SelectHeroSkill learns, and the script hears which", hero.abilities.AHtb == 2
        and learned == require("jass.vm").s2id("AHtb"))
    N.AddHeroXP(hero, 100000, true)
    test("AddHeroXP up to the cap", N.GetHeroLevel(hero) == 20)
    N.UnitStripHeroLevel(hero, 3)
    test("UnitStripHeroLevel", N.GetHeroLevel(hero) == 17)
    g.kill(hero, nil)
    test("ReviveHero", N.ReviveHero(hero, x, y, false) and hero.alive)
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

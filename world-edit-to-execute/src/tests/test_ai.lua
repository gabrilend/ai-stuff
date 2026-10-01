--[[
Tests for production and computer players (Issue 521): training, the
AI Editor profile model, the AI mechanism, profiles played, an imported
.ai JASS script, melee AI and faction profile files. On DAoW 5.4b's
own script (issue 520).
]]

-- {{{ Setup paths
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local map_scene = require("demo.wc3map.scene")
local game_mod = require("demo.wc3map.game")
local profile = require("ai.profile")
local faction = require("ai.faction")
local melee = require("ai.melee")
local ai_mod = require("ai")
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

-- the game, its script running, no AI filled in (each test starts its own)
local scene = map_scene.load(DIR .. "/assets/DAoW-5.4b-PUBLIC-TEST.w3x")
local game = game_mod.new(scene, { player = 0, minimap = false, placed = false })
local imported = {}
local V = assert(game.run_script({ ai = "none", read_file = function(name) return imported[name] end }))
local M = ai_mod.manager(V)

local function run(seconds) for _ = 1, math.floor(seconds / 0.02 + 0.5) do game.tick(0.02) end end
local function owned(p, test_fn)
    local l = {}
    for _, u in ipairs(game.units) do
        if u.player == p and u.alive ~= false and (not test_fn or test_fn(u)) then l[#l + 1] = u end
    end
    return l
end

-- a building of player p that can train something now, and that thing
local function trainer(p)
    for _, b in ipairs(owned(p, function(u) return u.spec.design == "building" end)) do
        for _, id in ipairs(game.db.unit_list(b.id, "utra")) do
            if game.can_train(b, id) then return b, id end
        end
    end
end

-- {{{ Production
test_section("Production")

local b, id = trainer(0)
test("a building of the local player can train something", b ~= nil)
if b then
    local c = game.unit_cost(id)
    local purse = game.purse(0)
    local gold0 = purse.gold
    local ok = game.train(b, id)
    test("training takes the cost at once", ok and purse.gold == gold0 - c.gold)
    game.cancel_train(b)
    test("cancelling gives it back", purse.gold == gold0 and #b.queue == 0)
    local before = #owned(0, function(u) return u.id == id end)
    game.train(b, id)
    run(c.time + 0.5)
    test("the unit steps out when its time is up", #owned(0, function(u) return u.id == id end) == before + 1)
    purse.gold = 0
    local ok2, why = game.train(b, id)
    test("no gold, no unit", not ok2 and why == "not enough gold", why)
    purse.gold = gold0
end
local locked
for _, bb in ipairs(owned(0, function(u) return u.spec.design == "building" end)) do
    for _, t in ipairs(game.db.unit_list(bb.id, "utra")) do
        local ok, why = game.can_train(bb, t)
        if why == "not allowed" then locked = true end
    end
end
test("the map's own tech limits hold", locked)
-- }}}

-- {{{ Profiles
test_section("AI Editor profiles")

local p = profile.normalize({ groups = { main = { { id = "hfoo", count = 2 } } },
                              waves = { list = { { group = "main" }, { group = "nope" } } },
                              build = { { kind = "unit", id = "hfoo", count = 3, condition = "later" } } })
local problems = profile.check(p)
test("a profile is filled in with defaults", p.waves.initial_delay == 180 and #p.targets == 2)
test("check finds a wave naming no group and an unknown condition", #problems == 2, table.concat(problems, "; "))
local text = profile.serialize(melee.profile("orc"), "test")
local back = loadstring(text)()
test("a profile is written as Lua and reads back the same", back.race == "orc" and #back.build == #melee.profile("orc").build
    and back.waves.list[3].group == "late" and back.conditions.mid[1] == "and")
local ai3 = M:player(3)
local cp = profile.normalize({ conditions = { early = { "game_time", "<", 1e6 }, rich = { "gold", ">", 1e9 } } })
test("conditions: named, and/or/not, game time, gold, counts",
    profile.test(cp, "early", ai3) and not profile.test(cp, "rich", ai3)
    and profile.test(cp, { "or", "rich", { "not", "rich" } }, ai3)
    and profile.test(cp, { "count", "zzzz", "==", 0 }, ai3))
-- }}}

-- {{{ The mechanism
test_section("A computer player's mechanism")

local army = ai3:army()
test("the AI sees its army", #army > 5)
local base = ai3:enemy_base()
test("and an enemy base", base ~= nil and game.allied and not game.allied(3, base.player))
local counts = {}
for _, u in ipairs(army) do counts[u.id] = (counts[u.id] or 0) + 1 end
local some_id, n = next(counts)
ai3:init_assault()
ai3:add_assault(n, some_id)
test("an assault forms from its units", ai3:form_group() and #ai3:attackers() == n)
test("and attacks", ai3:attack(base.x, base.y) and ai3:attackers()[1].order.kind == "attack")
ai3:go_home()
test("and goes home", ai3:attackers()[1].order.kind == "move" and ai3.captains.attack.state == "returning")
ai3:disband()
-- }}}

-- {{{ A profile played
test_section("A profile played")

local derived = faction.derive(game, 3, "The Scourge")
test("a faction's profile is derived from what it owns", #derived.groups.main > 0 and #derived.build > 0)
derived.waves.initial_delay, derived.waves.max_wait = 2, 5
local a = M:start_profile(3, derived, "test")
run(12)
test("its first wave forms and attacks", a.runner.state.wave == 1 and a.captains.attack.state ~= "home",
    a.captains.attack.state .. ", wave " .. a.runner.state.wave)
local ordered = 0
for _, u in ipairs(a:attackers()) do if u.order and u.order.kind == "attack" then ordered = ordered + 1 end end
test("its attackers are on their way", ordered > 0)
a.runner:stop()
a:go_home()
a:disband()
-- }}}

-- {{{ An imported .ai script
test_section("A map's own .ai script")

imported["war3mapImported\\scourge.ai"] = [[
globals
    integer heard = 0
    boolean sent = false
endglobals
function main takes nothing returns nothing
    local unit target
    call SetCampaignAI()
    call SetHeroesFlee(false)
    call InitAssault()
    call AddAssault(2, ']] .. some_id .. [[')
    call FormGroup(1, true)
    set target = GetEnemyBase()
    if target != null then
        call CaptainAttack(GetUnitX(target), GetUnitY(target))
        set sent = true
    endif
    loop
        exitwhen CommandsWaiting() > 0
        call Sleep(1)
    endloop
    set heard = GetLastCommand()
    call PopLastCommand()
endfunction
]]
V.env.StartCampaignAI(V:player(3), "war3mapImported\\scourge.ai")
run(12)   -- FormGroup waits for its group (up to ten times its interval)
local env = M.players[3].env
test("StartCampaignAI runs the map's .ai file", env ~= nil and M.how[3] == "war3mapImported\\scourge.ai")
test("its options and captain act", env and env.sent == true and M.players[3].options.heroes_flee == false
    and M.players[3].options.melee == false)
V.env.CommandAI(V:player(3), 12, 4)
run(2)
test("CommandAI reaches it", env and env.heard == 12)
test("no errors from AI scripts", V:report().error_count == 0,
    V.errors[1] and V.errors[1].message)
-- }}}

-- {{{ Melee AI and profile files
test_section("Melee AI and faction files")

test("a melee script path names its race", melee.race_of("Scripts\\Undead.ai") == "undead"
    and melee.race_of("RACE_NIGHTELF") == "nightelf")
V.env.StartMeleeAI(V:player(5), "scripts\\orc.ai")
test("StartMeleeAI with the game's script gets our melee profile", M.how[5] == "melee:orc")

local dir = os.tmpname()
os.remove(dir)
local written = faction.write(dir, game, { 6, 7 }, { [6] = "Trolls", [7] = "Illidari" })
test("a profile file per faction is written", #written == 2 and written[1]:find("p06%-Trolls%.lua$"))
local f = io.open(written[1])
local body = f:read("*a")
f:close()
f = io.open(written[1], "w")
f:write((body:gsub('name = "Trolls"', 'name = "Trolls (edited)"')))
f:close()
local loaded, where = faction.load_or_derive(dir, game, 6, "Trolls")
test("and an edited file is used instead of deriving", loaded.name == "Trolls (edited)" and where == written[1])
local again = faction.write(dir, game, { 6 })
test("writing again doesn't overwrite it", #again == 0)
os.execute('rm -rf "' .. dir .. '"')
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

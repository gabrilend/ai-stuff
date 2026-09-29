--[[
AI Script Natives (Issue 521b)

A map may import its own AI as a .ai JASS script (what WC3's AI Editor
compiles to, or one written by hand) and start it with StartMeleeAI or
StartCampaignAI. Such a script runs in its own environment, one per
computer player, with the common.j natives and these: the AI natives
WC3 gives only to AI scripts, acting on that player's mechanism
(ai/player.lua). Written from their documented behaviour; the names
follow the game's.

Blizzard's common.ai library (which the game puts in front of every AI
script) isn't here; the few of its functions editor-made scripts lean on
most are, as our own (SetBuildUnit and friends). Anything else a script
calls becomes a counted stub, as in the map VM (V.missing), so a map
with a .ai shows at once what it needs.

    local env = require("ai.natives").env(V, ai)   -- for one player's script
]]

local vm = require("jass.vm")

local natives = {}

-- {{{ natives.TYPES (return types, for the transpiler)
natives.TYPES = {}
for name in ([[GetAiPlayer GetUnitCount GetUnitCountDone GetTownUnitCount GetPlayerUnitTypeCount
    GetUnitGoldCost GetUnitWoodCost GetUnitBuildTime GetGoldOwned GetWoodOwned GetMinesOwned
    GetHeroLevelAI GetHeroId GetUpgradeLevel GetEnemyPower GetLastCommand GetLastData CommandsWaiting
    CaptainGroupSize CaptainReadiness CaptainReadinessHP CaptainReadinessMa GetAllianceTarget
    GetFoodUsed GetFoodMade]]):gmatch("%S+") do
    natives.TYPES[name] = "integer"
end
for name in ([[GetExpansionX GetExpansionY]]):gmatch("%S+") do natives.TYPES[name] = "integer" end
-- }}}

-- {{{ natives.install
-- The AI natives, for the thread's own AI (V.ctx.ai)
function natives.install(V, N)
    local function me() return V.ctx and V.ctx.ai end
    local function id(n) return vm.id2s(n) end
    local function flag(field)
        return function(on) local ai = me() if ai then ai.options[field] = on and true or false end end
    end

    -- threads
    N.Sleep = function(seconds) V:sleep(seconds) end
    N.StartThread = function(fn) if fn then V:run_thread(fn, { ai = me() }) end end
    N.GetAiPlayer = function() local ai = me() return ai and ai.player or 0 end

    -- the General tab's options
    N.SetCampaignAI = function() local ai = me() if ai then ai.options.melee = false end end
    N.SetMeleeAI = function() local ai = me() if ai then ai.options.melee = true end end
    N.SetTargetHeroes = flag("target_heroes")
    N.SetPeonsRepair = flag("repair")
    N.SetRandomPaths = flag("random_paths")
    N.SetDefendPlayer = flag("defend_users")
    N.SetHeroesFlee = flag("heroes_flee")
    N.SetHeroesBuyItems = flag("buy_items")
    N.SetHeroesTakeItems = flag("take_items")
    N.SetWatchMegaTargets = flag("watch_mega_targets")
    N.SetIgnoreInjured = flag("ignore_injured")
    N.SetUnitsFlee = flag("units_flee")
    N.SetGroupsFlee = flag("groups_flee")
    N.SetSlowChopping = flag("slow_harvest")
    N.SetCaptainChanges = flag("captain_changes")
    N.SetSmartArtillery = flag("smart_artillery")

    -- counts and costs
    N.GetUnitCount = function(n) local ai = me() return ai and ai:count(id(n)) or 0 end
    N.GetUnitCountDone = function(n) local ai = me() return ai and ai:count_done(id(n)) or 0 end
    N.GetTownUnitCount = function(n, town, done)
        local ai = me()
        if not ai then return 0 end
        return done and ai:count_done(id(n)) or ai:count(id(n))
    end
    N.GetPlayerUnitTypeCount = function(p, n)
        local c, s = 0, id(n)
        for _, u in ipairs(V.world.units) do
            if u.player == p.id and u.id == s and u.alive ~= false then c = c + 1 end
        end
        return c
    end
    local function cost(n, k)
        local g = V.world
        return g.unit_cost and g.unit_cost(id(n))[k] or 0
    end
    N.GetUnitGoldCost = function(n) return cost(n, "gold") end
    N.GetUnitWoodCost = function(n) return cost(n, "lumber") end
    N.GetUnitBuildTime = function(n) return cost(n, "time") end
    N.GetGoldOwned = function() local ai = me() return ai and V.world.purse and V.world.purse(ai.player).gold or 0 end
    N.GetWoodOwned = function() local ai = me() return ai and V.world.purse and V.world.purse(ai.player).lumber or 0 end
    N.GetFoodUsed = function() local ai = me() return ai and V.world.food and (V.world.food(ai.player)) or 0 end
    N.GetFoodMade = function() local ai = me() return ai and V.world.food and select(2, V.world.food(ai.player)) or 0 end
    N.GetEnemyPower = function()
        local ai = me()
        if not ai then return 0 end
        local e = 0
        for _, u in ipairs(V.world.units) do
            if u.alive ~= false and u.player < 12 and u.player ~= ai.player and u.weapon
                and V.world.allied and not V.world.allied(ai.player, u.player) then
                e = e + (u.food or 1)
            end
        end
        return e
    end

    -- production
    N.SetProduce = function(qty, n, town)
        local ai = me()
        if not ai then return false end
        local s = id(n)
        local ok = false
        for _ = 1, math.max(1, qty or 1) - math.max(0, ai:count(s) - ai:count_done(s)) do
            ok = ai:produce(s) or ok
        end
        return ok
    end

    -- captains
    N.InitAssault = function() local ai = me() if ai then ai:init_assault() end end
    N.AddAssault = function(qty, n) local ai = me() if ai then ai:add_assault(qty, id(n)) end return true end
    N.AddDefenders = function(qty, n) local ai = me() if ai then ai:add_defenders(qty, id(n)) end return true end
    N.FormGroup = function(seconds, test_ready)
        local ai = me()
        if not ai then return end
        -- common.ai's FormGroup waits until the group is gathered; a bounded wait here
        local waited = 0
        while not ai:form_group() and waited < (seconds or 3) * 10 do
            V:sleep(seconds or 3)
            waited = waited + (seconds or 3)
        end
    end
    N.CaptainAttack = function(x, y) local ai = me() if ai then ai:attack(x, y) end end
    N.AttackMoveXY = function(x, y) local ai = me() if ai then ai:attack(x, y) end end
    N.AttackMoveKill = function(u) local ai = me() if ai and u then ai:attack(u.x, u.y) end end
    N.CaptainGoHome = function() local ai = me() if ai then ai:go_home() end end
    N.CaptainIsHome = function() local ai = me() return ai == nil or ai:is_home() end
    N.CaptainIsEmpty = function() local ai = me() return ai == nil or #ai:attackers() == 0 end
    N.CaptainIsFull = function() local ai = me() return ai ~= nil and ai:form_group() end
    N.CaptainInCombat = function(attackers) local ai = me() return ai ~= nil and ai:in_combat() end
    N.CaptainRetreating = function() local ai = me() return ai ~= nil and ai.captains.attack.state == "returning" end
    N.CaptainGroupSize = function() local ai = me() return ai and #ai:attackers() or 0 end
    N.CaptainReadiness = function() local ai = me() return ai and math.floor(ai:readiness() * 100) or 0 end
    N.CaptainReadinessHP = N.CaptainReadiness
    N.CaptainVsUnits = function(p) return true end
    N.CaptainVsPlayer = function(p) return true end
    N.ClearCaptainTargets = function() end
    N.CreateCaptains = function() end
    N.SetCaptainHome = function(which, x, y) local ai = me() if ai then ai.home = { x = x, y = y } end end
    N.ResetCaptainLocs = function() local ai = me() if ai then ai:find_home() end end
    N.TeleportCaptain = function(x, y) end
    N.SuicidePlayer = function(p, check_full)
        local ai = me()
        if not ai then return false end
        ai:form_group()
        ai.alliance_target = p and p.id
        local b = ai:enemy_base()
        return b ~= nil and ai:attack(b.x, b.y)
    end
    N.SuicidePlayerUnits = N.SuicidePlayer

    -- targets
    N.StartGetEnemyBase = function() end
    N.WaitGetEnemyBase = function() return true end
    N.GetEnemyBase = function() local ai = me() return ai and (ai:enemy_base()) end
    N.GetMegaTarget = function() local ai = me() return ai and ai:nearest_enemy() end
    N.GetCreepCamp = function(min, max, flyers) local ai = me() return ai and ai:creep_camp() end
    N.GetBuilding = function(p) local ai = me() return ai and (ai:enemy_base()) end
    N.SetAllianceTarget = function(n) local ai = me() if ai then ai.alliance_target = n end end
    N.GetAllianceTarget = function() local ai = me() return ai and ai.alliance_target or 0 end
    N.GetExpansionX = function() local ai = me() return ai and math.floor(ai.home.x) or 0 end
    N.GetExpansionY = function() local ai = me() return ai and math.floor(ai.home.y) or 0 end

    -- CommandAI's other end
    N.CommandsWaiting = function() local ai = me() return ai and ai:commands_waiting() or 0 end
    N.GetLastCommand = function() local ai = me() return ai and ai:last_command() or 0 end
    N.GetLastData = function() local ai = me() return ai and ai:last_data() or 0 end
    N.PopLastCommand = function() local ai = me() if ai then ai:pop_command() end end

    -- heroes
    N.GetHeroLevelAI = function()
        local ai = me()
        local best = 0
        if ai then for _, u in ipairs(ai:units(function(u) return u.spec.hero end)) do best = math.max(best, u.level or 1) end end
        return best
    end

    -- what the game can't do yet: counted
    local function kept(names)
        for name in names:gmatch("%S+") do
            V.noop[name] = true
            N[name] = function() V.noops[name] = (V.noops[name] or 0) + 1 return false end
        end
    end
    kept("SetUpgrade SetExpansion HarvestGold HarvestWood ClearHarvestAI StopGathering GetExpansionPeon "
      .. "AddGuardPost FillGuardPosts ReturnGuardPosts SetHeroLevels SetNewHeroes PurchaseZeppelin MergeUnits "
      .. "ConvertUnits Unsummon RemoveInjuries RemoveSiege GroupTimedLife SetStagePoint LoadZepWave "
      .. "ShiftTownSpot SetReplacementCount DebugS DebugFI DebugUnitID DoAiScriptDebug DisplayText DisplayTextI "
      .. "DisplayTextII DisplayTextIII")

    -- {{{ Our own versions of common.ai's build list (SetBuildUnit ...)
    -- the list a background thread keeps producing, in order
    N.InitBuildArray = function() local ai = me() if ai then ai.build_array = {} end end
    N.SetBuildUnit = function(qty, n)
        local ai = me()
        if not ai then return end
        ai.build_array = ai.build_array or {}
        table.insert(ai.build_array, { id = id(n), count = qty })
        if not ai.build_thread then
            ai.build_thread = V:run_thread(function()
                while true do
                    for _, b in ipairs(ai.build_array) do
                        if ai:count(b.id) < b.count then
                            local ok, why = ai:produce(b.id)
                            if not ok and why and why:find("^not enough") then break end
                        end
                    end
                    V:sleep(2)
                end
            end, { ai = ai })
        end
    end
    N.SetBuildNext = N.SetBuildUnit
    N.SetBuildAll = function(t, qty, n, town) N.SetBuildUnit(qty, n) end
    N.CampaignAI = function(farms, heroes) N.SetCampaignAI() end
    N.CampaignAttackerEx = function(easy, med, hard, n) N.AddAssault(med, n) end
    N.CampaignAttacker = function(level, qty, n) N.AddAssault(qty, n) end
    N.CampaignDefenderEx = function(easy, med, hard, n) N.AddDefenders(med, n) end
    N.CampaignDefender = function(level, qty, n) N.AddDefenders(qty, n) end
    N.SuicideOnPlayerEx = function(easy, med, hard, p) V:sleep(med) N.SuicidePlayer(p, true) end
    N.SuicideOnPlayer = function(seconds, p) V:sleep(seconds) N.SuicidePlayer(p, true) end
    -- }}}
end
-- }}}

-- {{{ natives.env
-- A fresh environment for one player's AI script: common.j natives, the
-- AI natives, unknown names as the VM treats them
function natives.env(V)
    if not V.ai_natives then
        V.ai_natives = {}
        natives.install(V, V.ai_natives)
    end
    local env = {}
    env.__jass = V.env.__jass
    setmetatable(env, { __index = function(t, k)
        local v = V.ai_natives[k]
        if v == nil then v = V.natives[k] end
        if v == nil then v = V.constants[k] end
        if v ~= nil then return v end
        return V:unknown(t, k)
    end })
    return env
end
-- }}}

return natives

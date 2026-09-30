--[[
Blizzard.j equivalents (Issue 520)

WC3 ships Blizzard.j, a library of JASS functions (the "BJ" functions
World Editor's triggers are made of) written on top of common.j's
natives. It isn't in the maps and isn't copied here: these are our own
functions with the same names and behaviour, written in Lua on the
natives in core.lua, world.lua and interface.lua. Most keep a "last
created" variable (bj_lastCreatedUnit and the rest) in the script's
environment, as the originals do.
]]

local vm = require("jass.vm")

return function(V, N, T)
    local function typed(kind, names)
        for name in names:gmatch("%S+") do T[name] = kind end
    end
    local function set(name, value) rawset(V.env, name, value) return value end
    local function get(name) return rawget(V.env, name) end
    local W = V.world

    -- {{{ Players and forces
    N.ConvertedPlayer = function(n) return V:player(n - 1) end
    N.GetConvertedPlayerId = function(p) return p and p.id + 1 or 0 end
    N.GetPlayersAll = function() return V.constants.bj_FORCE_ALL_PLAYERS end
    N.GetForceOfPlayer = function(p)
        local f = N.CreateForce()
        f.players[p.id] = p
        return f
    end
    N.GetPlayersAllies = function(p)
        local f = N.CreateForce()
        N.ForceEnumAllies(f, p, nil)
        f.players[p.id] = p
        return f
    end
    N.GetPlayersEnemies = function(p)
        local f = N.CreateForce()
        N.ForceEnumEnemies(f, p, nil)
        return f
    end
    N.GetPlayersMatching = function(filter)
        local f = N.CreateForce()
        N.ForceEnumPlayers(f, filter)
        return f
    end
    N.CountPlayersInForceBJ = function(f) return #V.force_list(f) end
    N.ForceAddPlayerSimple = function(p, f) N.ForceAddPlayer(f, p) end
    N.ForceRemovePlayerSimple = function(p, f) N.ForceRemovePlayer(f, p) end
    N.ForForceBJ = N.ForForce
    N.IsPlayerInForceBJ = function(p, f) return N.IsPlayerInForce(p, f) end
    N.GetPlayerTechCountSimple = function(id, p) return N.GetPlayerTechCount(p, id, true) end
    N.SetPlayerUnitAvailableBJ = function(id, avail, p)
        N.SetPlayerTechMaxAllowed(p, id, avail and -1 or 0)
    end
    N.SetPlayerTechMaxAllowedSwap = function(id, max, p) N.SetPlayerTechMaxAllowed(p, id, max) end
    N.SetPlayerAbilityAvailableBJ = function(avail, id, p) N.SetPlayerAbilityAvailable(p, id, avail) end
    N.SetPlayerTechResearchedSwap = function(id, level, p) N.SetPlayerTechResearched(p, id, level) end
    N.GetPlayerStartLocationX = function(p) return N.GetStartLocationX(p.start) end
    N.GetPlayerStartLocationY = function(p) return N.GetStartLocationY(p.start) end
    N.GetPlayerStartLocationLoc = function(p) return N.GetStartLocationLoc(p.start) end
    -- states
    N.SetPlayerStateBJ = function(p, s, v)
        if s == "PLAYER_STATE_RESOURCE_GOLD" or s == "PLAYER_STATE_RESOURCE_LUMBER" then
            local k = s == "PLAYER_STATE_RESOURCE_GOLD" and "gathered_gold" or "gathered_lumber"
            p[k] = (p[k] or 0) + math.max(0, v - N.GetPlayerState(p, s))
        end
        N.SetPlayerState(p, s, v)
    end
    N.AdjustPlayerStateBJ = function(delta, p, s)
        N.SetPlayerStateBJ(p, s, N.GetPlayerState(p, s) + delta)
    end
    N.AdjustPlayerStateSimpleBJ = function(p, s, delta) N.SetPlayerState(p, s, N.GetPlayerState(p, s) + delta) end
    N.SetPlayerFlagBJ = function() end
    N.SetPlayerHandicapBJ = function(p, pct) N.SetPlayerHandicap(p, pct / 100) end
    N.SetPlayerColorBJ = function(p, c, change_units)
        N.SetPlayerColor(p, c)
        if change_units then
            for _, u in ipairs(W.units) do if u.player == p.id then u.color = c end end
        end
    end
    N.SetPlayerOnScoreScreenBJ = function() end
    typed("integer", "GetConvertedPlayerId CountPlayersInForceBJ GetPlayerTechCountSimple")
    typed("real", "GetPlayerStartLocationX GetPlayerStartLocationY")
    -- }}}

    N.GetPlayersByMapControl = function(control)
        local f = N.CreateForce()
        for n = 0, 15 do
            local p = V:player(n)
            if p.controller == control then f.players[n] = p end
        end
        return f
    end
    N.SetPlayerHandicapXPBJ = function(p, pct) N.SetPlayerHandicapXP(p, pct / 100) end
    N.SetDestructableInvulnerableBJ = function(d, f) N.SetDestructableInvulnerable(d, f) end
    N.TriggerRegisterDialogEventBJ = function(trig, d) return N.TriggerRegisterDialogEvent(trig, d) end
    -- the "For each Integer A" loop's variables
    N.GetForLoopIndexA = function() return get("bj_forLoopAIndex") or 0 end
    N.GetForLoopIndexB = function() return get("bj_forLoopBIndex") or 0 end
    N.SetForLoopIndexA = function(n) set("bj_forLoopAIndex", n) end
    N.SetForLoopIndexB = function(n) set("bj_forLoopBIndex", n) end
    N.InitHashtableBJ = function()
        return set("bj_lastCreatedHashtable", N.InitHashtable())
    end
    N.GetLastCreatedHashtableBJ = function() return get("bj_lastCreatedHashtable") end
    typed("integer", "GetForLoopIndexA GetForLoopIndexB")

    -- {{{ Alliances (bj_ALLIANCE_* levels: passive, vision)
    local LEVELS = {
        [0] = { false, false }, [1] = { false, true }, [2] = { true, false }, [3] = { true, true },
        [4] = { true, true }, [5] = { true, true }, [6] = { true, false }, [7] = { true, true },
    }
    N.SetPlayerAllianceStateBJ = function(a, b, state)
        if not a or not b or a == b then return end
        local l = LEVELS[state] or LEVELS[0]
        a.ally[b.id] = l[1] or nil
        a.vision[b.id] = l[2] or nil
    end
    N.SetForceAllianceStateBJ = function(f1, f2, state)
        for _, a in ipairs(V.force_list(f1)) do
            for _, b in ipairs(V.force_list(f2)) do N.SetPlayerAllianceStateBJ(a, b, state) end
        end
    end
    N.SetPlayerAllianceStateAllyBJ = function(a, b, flag)
        if a and b and a ~= b then a.ally[b.id] = flag or nil end
    end
    N.SetPlayerAllianceStateVisionBJ = function(a, b, flag)
        if a and b and a ~= b then a.vision[b.id] = flag or nil end
    end
    N.SetPlayerAllianceStateControlBJ = function() end
    N.SetPlayerAllianceStateFullControlBJ = function() end
    N.SetPlayerAllianceBJ = function(a, setting, value, b) N.SetPlayerAlliance(a, b, setting, value) end
    N.MakeUnitsPassiveForPlayer = function(p) end
    N.MakeUnitsPassiveForTeam = function(p) end
    N.ShareEverythingWithTeam = function(p)
        for n = 0, 11 do
            local q = V:player(n)
            if q ~= p and q.team == p.team then p.ally[n], p.vision[n] = true, true end
        end
    end
    N.IsPlayerAlly = N.IsPlayerAlly
    -- }}}

    -- {{{ Messages
    N.DisplayTextToForce = function(f, msg)
        if f and f.players[V.local_id] then V:message(msg, 10) end
    end
    N.DisplayTimedTextToForce = function(f, t, msg)
        if f and f.players[V.local_id] then V:message(msg, t) end
    end
    N.QuestMessageBJ = function(f, kind, msg)
        if f and f.players[V.local_id] then V:message(msg, 20) end
    end
    -- }}}

    -- {{{ Units
    local function last_unit(u) set("bj_lastCreatedUnit", u) return u end
    N.CreateUnitAtLocSaveLast = function(p, id, l, facing) return last_unit(N.CreateUnitAtLoc(p, id, l, facing)) end
    N.CreateNUnitsAtLoc = function(n, id, p, l, facing)
        local g = N.CreateGroup()
        set("bj_lastCreatedGroup", g)
        for _ = 1, n do
            local u = N.CreateUnitAtLocSaveLast(p, id, l, facing)
            N.GroupAddUnit(g, u)
        end
        return g
    end
    N.CreateNUnitsAtLocFacingLocBJ = function(n, id, p, l, look)
        return N.CreateNUnitsAtLoc(n, id, p, l, N.AngleBetweenPoints(l, look))
    end
    N.GetLastCreatedUnit = function() return get("bj_lastCreatedUnit") end
    N.GetLastCreatedGroup = function() return get("bj_lastCreatedGroup") end
    -- a new unit of another type in the old one's place, keeping its
    -- owner, health fraction and facing (the items policy is ignored)
    N.ReplaceUnitBJ = function(u, id, policy)
        if not u then return nil end
        local frac = (u.hp_max and u.hp_max > 0) and u.hp / u.hp_max or 1
        local was_hidden = u.hidden
        local nu = V.create_unit(V:player(u.player), id, u.x, u.y, math.deg(u.facing or 0))
        if nu then
            if nu.hp_max and u.alive then nu.hp = math.max(1, nu.hp_max * frac) end
            nu.hidden = was_hidden
            if u.items then nu.items = u.items end
        end
        N.RemoveUnit(u)
        set("bj_lastReplacedUnit", nu)
        return nu
    end
    N.GetLastReplacedUnitBJ = function() return get("bj_lastReplacedUnit") end
    N.KillUnit = N.KillUnit
    N.RemoveUnit = N.RemoveUnit
    N.ShowUnitHide = function(u) N.ShowUnit(u, false) end
    N.ShowUnitShow = function(u) N.ShowUnit(u, true) end
    N.PauseUnitBJ = function(pause, u) N.PauseUnit(u, pause) end
    N.SetUnitInvulnerableBJ = function(u, flag) N.SetUnitInvulnerable(u, flag) end
    N.SetUnitLifeBJ = function(u, v) N.SetUnitState(u, "UNIT_STATE_LIFE", math.max(0, v)) end
    N.SetUnitManaBJ = function(u, v) N.SetUnitState(u, "UNIT_STATE_MANA", math.max(0, v)) end
    N.SetUnitLifePercentBJ = function(u, pct)
        N.SetUnitState(u, "UNIT_STATE_LIFE", N.GetUnitState(u, "UNIT_STATE_MAX_LIFE") * math.max(0, pct) * 0.01)
    end
    N.SetUnitManaPercentBJ = function(u, pct)
        N.SetUnitState(u, "UNIT_STATE_MANA", N.GetUnitState(u, "UNIT_STATE_MAX_MANA") * math.max(0, pct) * 0.01)
    end
    N.GetUnitStateSwap = function(s, u) return N.GetUnitState(u, s) end
    N.GetUnitStatePercent = function(u, s, smax)
        local m = N.GetUnitState(u, smax)
        return m > 0 and N.GetUnitState(u, s) / m * 100 or 0
    end
    N.GetUnitLifePercent = function(u) return N.GetUnitStatePercent(u, "UNIT_STATE_LIFE", "UNIT_STATE_MAX_LIFE") end
    N.GetUnitManaPercent = function(u) return N.GetUnitStatePercent(u, "UNIT_STATE_MANA", "UNIT_STATE_MAX_MANA") end
    N.SetUnitFacingToFaceLocTimed = function(u, l, dur) N.SetUnitFacing(u, N.AngleBetweenPoints(N.GetUnitLoc(u), l)) end
    N.SetUnitFacingToFaceUnitTimed = function(u, t, dur) N.SetUnitFacing(u, N.AngleBetweenPoints(N.GetUnitLoc(u), N.GetUnitLoc(t))) end
    N.SetUnitPositionLocFacingLocBJ = function(u, l, look)
        N.SetUnitPositionLoc(u, l)
        N.SetUnitFacing(u, N.AngleBetweenPoints(l, look))
    end
    N.UnitDamageTarget = function(src, t, amount)
        if not t or t.alive == false then return false end
        if W.damage then W.damage(src, t, amount) else
            t.hp = t.hp - amount
            if t.hp <= 0 then W.kill(t, src) end
        end
        return true
    end
    N.UnitDamageTargetBJ = function(src, t, amount) return N.UnitDamageTarget(src, t, amount) end
    N.UnitDamagePointLoc = function() return false end
    N.GetUnitAbilityLevelSwapped = function(id, u) return N.GetUnitAbilityLevel(u, id) end
    N.UnitAddAbilityBJ = function(id, u) return N.UnitAddAbility(u, id) end
    N.UnitRemoveAbilityBJ = function(id, u) return N.UnitRemoveAbility(u, id) end
    N.SetUnitAbilityLevelSwapped = function(id, u, lvl) return N.SetUnitAbilityLevel(u, id, lvl) end
    N.UnitRemoveBuffsBJ = function(kind, u) if u then N.UnitRemoveBuffs(u, true, true) end end
    N.UnitShareVisionBJ = function() end
    N.SetUnitVertexColorBJ = function() end
    N.SetUnitTimeScalePercent = function() end
    N.SetUnitScalePercent = function() end
    N.SetUnitFlyHeightBJ = function() end
    N.SetUnitAcquireRangeBJ = function(u, r) N.SetUnitAcquireRange(u, r) end
    N.SetUnitUserDataBJ = function(u, v) N.SetUnitUserData(u, v) end
    N.IsUnitIllusionBJ = function() return false end
    N.IsUnitHiddenBJ = function(u) return N.IsUnitHidden(u) end
    N.IsUnitPausedBJ = function(u) return N.IsUnitPaused(u) end
    N.IsUnitInRangeLocBJ = function(u, l, d) return N.IsUnitInRangeLoc(u, l, d) end
    N.UnitApplyTimedLifeBJ = N.UnitApplyTimedLifeBJ
    N.ExplodeUnitBJ = function(u) N.SetUnitExploded(u, true); N.KillUnit(u) end
    typed("real", "GetUnitStateSwap GetUnitStatePercent GetUnitLifePercent GetUnitManaPercent")
    typed("integer", "GetUnitAbilityLevelSwapped")
    -- }}}

    -- {{{ Heroes
    local STAT = { [0] = "str", [1] = "agi", [2] = "int" }
    N.ModifyHeroStat = function(stat, u, op, v)
        if not u then return end
        local k = STAT[stat]
        if not k then return end
        if op == 0 then u[k] = (u[k] or 0) + v
        elseif op == 1 then u[k] = math.max(0, (u[k] or 0) - v)
        else u[k] = v end
    end
    N.GetHeroStatBJ = function(stat, u, bonus) return u and u[STAT[stat]] or 0 end
    N.SetHeroLevelBJ = function(u, lvl, show) N.SetHeroLevel(u, lvl, show) end
    N.ModifyHeroSkillPoints = function(u, op, v)
        if op == 0 then return N.UnitModifySkillPoints(u, v)
        elseif op == 1 then return N.UnitModifySkillPoints(u, -v) end
        return N.UnitModifySkillPoints(u, v - N.GetHeroSkillPoints(u))
    end
    N.AddHeroXPSwapped = function(xp, u, show) N.AddHeroXP(u, xp, show) end
    N.SetHeroXPBJ = function(u, xp) N.SetHeroXP(u, xp) end
    N.ReviveHeroLoc = N.ReviveHeroLoc
    N.SuspendHeroXPBJ = function(flag, u) N.SuspendHeroXP(u, not flag) end
    N.IsHeroUnitId = function(id) local s = vm.id2s(id) return s:sub(1, 1):match("%u") ~= nil end
    typed("integer", "GetHeroStatBJ")
    -- }}}

    -- {{{ Items
    local function last_item(it) set("bj_lastCreatedItem", it) return it end
    N.CreateItemLoc = (function(orig) return function(id, l) return last_item(orig(id, l)) end end)(N.CreateItemLoc)
    N.GetLastCreatedItem = function() return get("bj_lastCreatedItem") end
    N.UnitAddItemSwapped = function(it, u) return N.UnitAddItem(u, it) end
    N.UnitAddItemByIdSwapped = function(id, u)
        local it = last_item(N.CreateItem(id, u.x, u.y))
        N.UnitAddItem(u, it)
        return it
    end
    N.UnitRemoveItemSwapped = function(it, u)
        set("bj_lastRemovedItem", it)
        N.UnitRemoveItem(u, it)
    end
    -- slots are counted from 1 here
    N.UnitRemoveItemFromSlotSwapped = function(slot, u)
        local it = N.UnitRemoveItemFromSlot(u, slot - 1)
        set("bj_lastRemovedItem", it)
        return it
    end
    N.UnitItemInSlotBJ = function(u, slot) return N.UnitItemInSlot(u, slot - 1) end
    N.GetItemOfTypeFromUnitBJ = function(u, id)
        if not u or not u.items then return nil end
        local s = vm.id2s(id)
        for k = 0, 5 do if u.items[k] and u.items[k].id == s then return u.items[k] end end
        return nil
    end
    N.UnitHasItemOfTypeBJ = function(u, id) return N.GetItemOfTypeFromUnitBJ(u, id) ~= nil end
    N.UnitInventoryCount = function(u)
        local n = 0
        if u and u.items then for k = 0, 5 do if u.items[k] then n = n + 1 end end end
        return n
    end
    N.GetInventoryIndexOfItemTypeBJ = function(u, id)
        if not u or not u.items then return 0 end
        local s = vm.id2s(id)
        for k = 0, 5 do if u.items[k] and u.items[k].id == s then return k + 1 end end
        return 0
    end
    N.GetLastRemovedItem = function() return get("bj_lastRemovedItem") end
    N.WidgetDropItem = function(u, id)
        local it = N.CreateItem(id, u and u.x or 0, u and u.y or 0)
        return it
    end
    N.SetItemPositionLoc = function(it, l) N.SetItemPosition(it, l.x, l.y) end
    N.RemoveItem = N.RemoveItem
    typed("integer", "UnitInventoryCount GetInventoryIndexOfItemTypeBJ")
    -- }}}

    -- {{{ Random distribution (Blizzard.j's item drop tables)
    local dist = {}
    N.RandomDistReset = function() dist = {} end
    N.RandomDistAddItem = function(id, chance) dist[#dist + 1] = { id = id, chance = chance } end
    N.RandomDistChoose = function()
        local total = 0
        for _, d in ipairs(dist) do total = total + d.chance end
        if total <= 0 then return -1 end
        local r = math.random(1, total)
        for _, d in ipairs(dist) do
            r = r - d.chance
            if r <= 0 then return d.id end
        end
        return -1
    end
    typed("integer", "RandomDistChoose")
    -- }}}

    -- {{{ Groups
    local function group_from(filter, test)
        local g = N.CreateGroup()
        V.enum_into(g, filter, test)
        return g
    end
    local function in_rect(r) return function(u) return N.RectContainsCoords(r, u.x, u.y) end end
    N.GetUnitsInRectAll = function(r) return group_from(nil, in_rect(r)) end
    N.GetUnitsInRectMatching = function(r, filter) return group_from(filter, in_rect(r)) end
    N.GetUnitsInRectOfPlayer = function(r, p)
        return group_from(nil, function(u) return u.player == p.id and N.RectContainsCoords(r, u.x, u.y) end)
    end
    N.GetUnitsInRangeOfLocAll = function(d, l)
        return group_from(nil, function(u) return (u.x - l.x) ^ 2 + (u.y - l.y) ^ 2 <= d * d end)
    end
    N.GetUnitsInRangeOfLocMatching = function(d, l, filter)
        return group_from(filter, function(u) return (u.x - l.x) ^ 2 + (u.y - l.y) ^ 2 <= d * d end)
    end
    N.GetUnitsOfPlayerAll = function(p) return group_from(nil, function(u) return u.player == p.id end) end
    N.GetUnitsOfPlayerMatching = function(p, filter) return group_from(filter, function(u) return u.player == p.id end) end
    N.GetUnitsOfPlayerAndTypeId = function(p, id)
        local s = vm.id2s(id)
        return group_from(nil, function(u) return u.player == p.id and u.id == s end)
    end
    N.GetUnitsOfTypeIdAll = function(id)
        local s = vm.id2s(id)
        return group_from(nil, function(u) return u.id == s end)
    end
    N.GetUnitsSelectedAll = function(p) return group_from(nil, function(u) return u.selected end) end
    N.CountLivingPlayerUnitsOfTypeId = function(id, p)
        local s, n = vm.id2s(id), 0
        for _, u in ipairs(W.units) do
            if u.player == p.id and u.id == s and u.alive ~= false and not u.removed then n = n + 1 end
        end
        return n
    end
    N.CountUnitsInGroup = N.CountUnitsInGroup
    -- ForGroupBJ destroys the group after if bj_wantDestroyGroup was set
    N.ForGroupBJ = function(g, fn)
        local destroy = get("bj_wantDestroyGroup")
        set("bj_wantDestroyGroup", false)
        N.ForGroup(g, fn)
        if destroy then N.DestroyGroup(g) end
    end
    -- the filters Blizzard.j's enumerations use, reading its bj_groupEnum* variables
    N.GetUnitsOfPlayerAndTypeIdFilter = function()
        local u = V.ctx and V.ctx.filter_unit
        return u ~= nil and vm.s2id(u.id) == get("bj_groupEnumTypeId")
    end
    N.GetUnitsInRectOfPlayerFilter = function()
        local u, p = V.ctx and V.ctx.filter_unit, get("bj_groupEnumOwningPlayer")
        return u ~= nil and p ~= nil and u.player == p.id
    end
    N.GetUnitsOfTypeIdAllFilter = function()
        local u = V.ctx and V.ctx.filter_unit
        return u ~= nil and vm.s2id(u.id) == get("bj_groupEnumTypeId")
    end
    N.CreatePermanentCorpseLocBJ = function(style, id, p, l, facing)
        local u = N.CreateCorpse(p, id, l.x, l.y, facing)
        if u then u.permanent_corpse = true end
        set("bj_lastCreatedUnit", u)
        return u
    end
    N.GroupAddUnitSimple = function(u, g) N.GroupAddUnit(g, u) end
    N.GroupRemoveUnitSimple = function(u, g) N.GroupRemoveUnit(g, u) end
    N.GroupAddGroup = N.GroupAddGroup
    N.GroupClear = N.GroupClear
    N.IsUnitGroupDeadBJ = function(g)
        for _, u in ipairs(V.group_units(g)) do if u.alive ~= false then return false end end
        return true
    end
    N.IsUnitGroupInRectBJ = function(g, r)
        for _, u in ipairs(V.group_units(g)) do if not N.RectContainsUnit(r, u) then return false end end
        return true
    end
    N.GroupPointOrderLocBJ = function(g, name, l) return N.GroupPointOrderLoc(g, name, l) end
    N.GroupTargetOrderBJ = function(g, name, t) return N.GroupTargetOrder(g, name, t) end
    N.GroupImmediateOrderBJ = function(g, name) return N.GroupImmediateOrder(g, name) end
    N.IssuePointOrderLocBJ = function(u, name, l) return N.IssuePointOrderLoc(u, name, l) end
    N.IssueTargetOrderBJ = function(u, name, t) return N.IssueTargetOrder(u, name, t) end
    N.IssueImmediateOrderBJ = function(u, name) return N.IssueImmediateOrder(u, name) end
    N.IssueTrainOrderByIdBJ = function() return false end
    N.GetUnitsInRectOfPlayerBJ = N.GetUnitsInRectOfPlayer
    typed("integer", "CountLivingPlayerUnitsOfTypeId")
    -- }}}

    -- {{{ Destructables
    N.EnumDestructablesInRectAll = function(r, fn) end
    N.EnumDestructablesInCircleBJ = function(radius, l, fn) end
    N.GetLastCreatedDestructable = function() return get("bj_lastCreatedDestructable") end
    N.KillDestructable = N.KillDestructable
    -- }}}

    -- {{{ Triggers and events
    N.TriggerRegisterTimerEventSingle = function(trig, t) return N.TriggerRegisterTimerEvent(trig, t, false) end
    N.TriggerRegisterTimerEventPeriodic = function(trig, t) return N.TriggerRegisterTimerEvent(trig, t, true) end
    N.TriggerRegisterTimerExpireEventBJ = function(trig, t) return N.TriggerRegisterTimerExpireEvent(trig, t) end
    local function rect_region(r)
        local g = N.CreateRegion()
        N.RegionAddRect(g, r)
        return g
    end
    N.TriggerRegisterEnterRectSimple = function(trig, r) return N.TriggerRegisterEnterRegion(trig, rect_region(r), nil) end
    N.TriggerRegisterLeaveRectSimple = function(trig, r) return N.TriggerRegisterLeaveRegion(trig, rect_region(r), nil) end
    N.TriggerRegisterPlayerUnitEventSimple = function(trig, p, ev)
        return N.TriggerRegisterPlayerUnitEvent(trig, p, ev, nil)
    end
    N.TriggerRegisterAnyUnitEventBJ = function(trig, ev)
        for n = 0, 15 do N.TriggerRegisterPlayerUnitEvent(trig, V:player(n), ev, nil) end
    end
    N.TriggerRegisterPlayerEventLeave = function(trig, p) return V:listen(trig, "EVENT_PLAYER_LEAVE", { player = p }) end
    N.TriggerRegisterPlayerEventDefeat = function(trig, p) return V:listen(trig, "EVENT_PLAYER_DEFEAT", { player = p }) end
    N.TriggerRegisterPlayerEventVictory = function(trig, p) return V:listen(trig, "EVENT_PLAYER_VICTORY", { player = p }) end
    N.TriggerRegisterPlayerEventEndCinematic = function(trig, p)
        return V:listen(trig, "EVENT_PLAYER_END_CINEMATIC", { player = p })
    end
    N.TriggerRegisterPlayerKeyEventBJ = function(trig, p, kind, key)
        return V:listen(trig, "EVENT_PLAYER_KEY", { player = p, key = key, kind = kind })
    end
    N.TriggerRegisterPlayerSelectionEventBJ = function(trig, p, selected)
        return V:listen(trig, selected and "EVENT_PLAYER_UNIT_SELECTED" or "EVENT_PLAYER_UNIT_DESELECTED", { player = p })
    end
    N.TriggerRegisterUnitStateEventBJ = function(trig, u, s, op, v)
        return V:listen(trig, "UNIT_STATE", { unit = u })
    end
    N.TriggerRegisterUnitLifeEvent = function(trig, u, op, v) return V:listen(trig, "UNIT_STATE", { unit = u }) end
    N.TriggerRegisterGameStateEventTimeOfDay = function(trig, op, v)
        return V:listen(trig, "TIME_OF_DAY", { op = op, value = v })
    end
    N.TriggerRegisterPlayerStateEvent = N.TriggerRegisterPlayerStateEvent
    N.TriggerRegisterDestDeathInRegionEvent = function() end
    N.TriggerRegisterUnitAcquiredBJ = function(trig, u, ev) return V:listen(trig, ev, { unit = u }) end
    N.EnableTrigger = N.EnableTrigger
    N.TriggerExecuteBJ = function(trig, check)
        if check then N.ConditionalTriggerExecute(trig) else N.TriggerExecute(trig) end
        return true
    end
    N.PostTriggerExecuteBJ = N.TriggerExecuteBJ
    N.QueuedTriggerAddBJ = function(trig, check) return N.TriggerExecuteBJ(trig, check) end
    N.QueuedTriggerRemoveBJ = function() end
    N.QueuedTriggerDoneBJ = function() end
    N.QueuedTriggerClearBJ = function() end
    N.QueuedTriggerCountBJ = function() return 0 end
    N.IsTriggerQueueEmptyBJ = function() return true end
    N.DoNothing = function() end
    N.CommentString = function() end
    N.WaitForCondition = function(interval, fn) end
    N.TriggerSleepActionBJ = N.TriggerSleepAction
    -- }}}

    -- {{{ Timers and their windows
    N.StartTimerBJ = function(t, periodic, timeout)
        set("bj_lastStartedTimer", t)
        N.TimerStart(t, timeout, periodic, nil)
        return t
    end
    N.CreateTimerBJ = function(periodic, timeout)
        return N.StartTimerBJ(N.CreateTimer(), periodic, timeout)
    end
    N.GetLastCreatedTimerBJ = function() return get("bj_lastStartedTimer") end
    N.PauseTimerBJ = function(pause, t) if pause then N.PauseTimer(t) else N.ResumeTimer(t) end end
    N.DestroyTimerBJ = function(t) N.DestroyTimer(t) end
    N.CreateTimerDialogBJ = function(t, title)
        local td = N.CreateTimerDialog(t)
        N.TimerDialogSetTitle(td, title)
        N.TimerDialogDisplay(td, true)
        set("bj_lastCreatedTimerDialog", td)
        return td
    end
    N.GetLastCreatedTimerDialogBJ = function() return get("bj_lastCreatedTimerDialog") end
    N.DestroyTimerDialogBJ = function(td) N.DestroyTimerDialog(td) end
    N.TimerDialogSetTitleBJ = function(td, s) N.TimerDialogSetTitle(td, s) end
    N.TimerDialogDisplayBJ = function(show, td) N.TimerDialogDisplay(td, show) end
    N.TimerDialogDisplayForPlayerBJ = function(show, td, p) if p.id == V.local_id then N.TimerDialogDisplay(td, show) end end
    N.TimerDialogSetTitleColorBJ = function() end
    N.TimerDialogSetTimeColorBJ = function() end
    typed("real", "")
    -- }}}

    -- {{{ Dialogs
    N.DialogDisplayBJ = function(flag, d, p) N.DialogDisplay(p, d, flag) end
    N.DialogSetMessageBJ = function(d, s) N.DialogSetMessage(d, s) end
    N.DialogAddButtonBJ = function(d, text)
        local b = N.DialogAddButton(d, text, 0)
        set("bj_lastCreatedButton", b)
        return b
    end
    N.DialogAddButtonWithHotkeyBJ = function(d, text, key)
        local b = N.DialogAddButton(d, text, key)
        set("bj_lastCreatedButton", b)
        return b
    end
    N.DialogClearBJ = function(d) N.DialogClear(d) end
    N.GetLastCreatedButtonBJ = function() return get("bj_lastCreatedButton") end
    N.GetClickedButtonBJ = N.GetClickedButton
    N.GetClickedDialogBJ = N.GetClickedDialog
    -- }}}

    -- {{{ Quests
    N.CreateQuestBJ = function(kind, title, desc, icon)
        local q = N.CreateQuest()
        N.QuestSetTitle(q, title)
        N.QuestSetDescription(q, desc)
        q.icon = icon
        q.required = kind == 0 or kind == 1
        q.discovered = kind == 0 or kind == 2
        set("bj_lastCreatedQuest", q)
        return q
    end
    N.GetLastCreatedQuestBJ = function() return get("bj_lastCreatedQuest") end
    N.DestroyQuestBJ = function(q) N.DestroyQuest(q) end
    N.QuestSetEnabledBJ = function(flag, q) N.QuestSetEnabled(q, flag) end
    N.QuestSetTitleBJ = function(q, s) N.QuestSetTitle(q, s) end
    N.QuestSetDescriptionBJ = function(q, s) N.QuestSetDescription(q, s) end
    N.QuestSetCompletedBJ = function(q, f) N.QuestSetCompleted(q, f) end
    N.QuestSetFailedBJ = function(q, f) N.QuestSetFailed(q, f) end
    N.QuestSetDiscoveredBJ = function(q, f) N.QuestSetDiscovered(q, f) end
    N.CreateQuestItemBJ = function(q, desc)
        local it = N.QuestCreateItem(q)
        N.QuestItemSetDescription(it, desc)
        set("bj_lastCreatedQuestItem", it)
        return it
    end
    N.QuestItemSetCompletedBJ = function(it, f) N.QuestItemSetCompleted(it, f) end
    N.GetLastCreatedQuestItemBJ = function() return get("bj_lastCreatedQuestItem") end
    N.FlashQuestDialogButtonBJ = function() N.FlashQuestDialogButton() end
    -- }}}

    -- {{{ Multiboards
    N.CreateMultiboardBJ = function(cols, rows, title)
        local mb = N.CreateMultiboard()
        mb.cols, mb.rows, mb.title, mb.shown = cols, rows, title, true
        set("bj_lastCreatedMultiboard", mb)
        return mb
    end
    N.GetLastCreatedMultiboard = function() return get("bj_lastCreatedMultiboard") end
    N.DestroyMultiboardBJ = function(mb) N.DestroyMultiboard(mb) end
    N.MultiboardDisplayBJ = function(show, mb) N.MultiboardDisplay(mb, show) end
    N.MultiboardMinimizeBJ = function(flag, mb) N.MultiboardMinimize(mb, flag) end
    N.MultiboardSetTitleTextColorBJ = function() end
    N.MultiboardAllowDisplayBJ = function() end
    -- col or row 0: every column or row (1-based otherwise)
    N.MultiboardSetItemValueBJ = function(mb, col, row, val)
        if not mb then return end
        for r = (row == 0 and 1 or row), (row == 0 and mb.rows or row) do
            for c = (col == 0 and 1 or col), (col == 0 and mb.cols or col) do
                mb.cells[(r - 1) * 64 + (c - 1)] = val
            end
        end
    end
    N.MultiboardSetItemColorBJ = function() end
    N.MultiboardSetItemStyleBJ = function() end
    N.MultiboardSetItemWidthBJ = function() end
    N.MultiboardSetItemIconBJ = function() end
    -- }}}

    -- {{{ Waygates
    N.WaygateSetDestinationLocBJ = function(u, l) N.WaygateSetDestination(u, l.x, l.y) end
    N.WaygateActivateBJ = function(on, u) N.WaygateActivate(u, on) end
    N.WaygateIsActiveBJ = function(u) return N.WaygateIsActive(u) end
    N.WaygateGetDestinationLocBJ = function(u) return N.Location(N.WaygateGetDestinationX(u), N.WaygateGetDestinationY(u)) end
    -- }}}

    -- {{{ Last-created handles for systems that don't exist yet
    N.GetLastCreatedEffectBJ = function() return get("bj_lastCreatedEffect") end
    N.GetLastCreatedTextTag = function() return get("bj_lastCreatedTextTag") end
    N.GetLastPlayedSound = function() return get("bj_lastPlayedSound") end
    -- }}}

    -- {{{ The rarer ones (each used somewhere in the 16 test maps)
    local function none() end
    local function quiet(names)
        for name in names:gmatch("%S+") do
            V.noop[name] = true
            N[name] = function() V.noops[name] = (V.noops[name] or 0) + 1 end
        end
    end
    local function from(field) return function() local c = V.ctx return c and c[field] end end
    N.GetKillingUnitBJ = N.GetKillingUnit
    N.GetDyingDestructable = from("destructable")
    N.GetSoldUnit = from("sold")
    N.GetLearningUnit = from("unit")
    N.GetLearnedSkill = from("ability")
    N.GetLearnedSkillLevel = from("learned_level")
    N.GetLearnedSkillBJ = N.GetLearnedSkill
    N.GetRevivingUnit = from("unit")
    N.GetRevivableUnit = from("unit")
    N.GetSummoningUnit = from("summoner")
    N.GetTrainedUnitType = from("trained_type")
    N.GetOrderPointX = function() local c = V.ctx return c and c.point and c.point.x or 0 end
    N.GetOrderPointY = function() local c = V.ctx return c and c.point and c.point.y or 0 end
    N.GetOrderPointLoc = function() return N.Location(N.GetOrderPointX(), N.GetOrderPointY()) end
    N.GetSpellTargetLoc = N.GetOrderPointLoc
    N.GetSpellTargetX = N.GetOrderPointX
    N.GetSpellTargetY = N.GetOrderPointY
    N.GetSpellAbility = from("ability")
    N.GetIssuedOrderIdBJ = N.GetIssuedOrderId
    N.OrderId2StringBJ = N.OrderId2String
    N.String2OrderIdBJ = N.OrderId
    N.UnitId2StringBJ = N.UnitId2String
    N.GetHandleIdBJ = N.GetHandleId
    N.PercentTo255 = function(p) return math.floor(p * 2.55 + 0.5) end
    N.PercentToInt = function(p, max) return math.floor(p * max / 100 + 0.5) end
    N.GetRandomDirectionDeg = function() return math.random() * 360 end
    N.GetRandomPercentageBJ = function() return math.random() * 100 end
    N.SinBJ = function(d) return math.sin(math.rad(d)) end
    N.CosBJ = function(d) return math.cos(math.rad(d)) end
    N.TanBJ = function(d) return math.tan(math.rad(d)) end
    N.Atan2BJ = function(y, x) return math.deg(math.atan2(y, x)) end
    typed("integer", "PercentTo255 PercentToInt GetIssuedOrderIdBJ String2OrderIdBJ GetHandleIdBJ GetTrainedUnitType GetLearnedSkill GetLearnedSkillLevel GetLearnedSkillBJ")
    typed("real", "GetOrderPointX GetOrderPointY GetSpellTargetX GetSpellTargetY GetRandomDirectionDeg GetRandomPercentageBJ SinBJ CosBJ TanBJ Atan2BJ")
    typed("string", "OrderId2StringBJ UnitId2StringBJ")
    -- regions and terrain
    N.TriggerRegisterEnterRegionSimple = function(trig, g) return N.TriggerRegisterEnterRegion(trig, g, nil) end
    N.TriggerRegisterLeaveRegionSimple = function(trig, g) return N.TriggerRegisterLeaveRegion(trig, g, nil) end
    N.TriggerRegisterUnitManaEvent = function(trig, u, op, v) return V:listen(trig, "UNIT_STATE", { unit = u }) end
    N.IsPointInRegion = function(g, x, y)
        for _, r in ipairs(g.rects) do if N.RectContainsCoords(r, x, y) then return true end end
        return false
    end
    N.IsLocationInRegion = function(g, l) return N.IsPointInRegion(g, l.x, l.y) end
    N.GetTerrainCliffLevel = function(x, y) return W.cliff_level and W.cliff_level(x, y) or 0 end
    N.GetTerrainCliffLevelBJ = function(l) return N.GetTerrainCliffLevel(l.x, l.y) end
    -- as WC3's: true where the ground is NOT pathable
    N.IsTerrainPathable = function(x, y, kind)
        if not W.pathing then return false end
        return not W.pathing:walkable(W.pathing:cell(x, y))
    end
    N.IsTerrainPathableBJ = function(l, kind) return N.IsTerrainPathable(l.x, l.y, kind) end
    N.GetCameraBoundsMapRect = N.GetPlayableMapRect
    N.GetCameraTargetPositionZ = function() return 0 end
    N.GetUnitFlyHeight = function(u) return u and u.fly_height or 0 end
    N.GetUnitPropWindow = function(u) return 60 end
    N.SetTimeOfDay = function(t) if W.set_time_of_day then W.set_time_of_day(t) end end
    N.IsDawnDuskEnabled = function() return true end
    typed("integer", "GetTerrainCliffLevel GetTerrainCliffLevelBJ")
    typed("real", "GetCameraTargetPositionZ GetUnitFlyHeight GetUnitPropWindow")
    -- groups
    N.GetRandomSubGroup = function(count, src)
        local pool = {}
        for k, u in ipairs(V.group_units(src)) do pool[k] = u end
        local g = N.CreateGroup()
        for _ = 1, math.min(count, #pool) do
            local k = math.random(#pool)
            N.GroupAddUnit(g, table.remove(pool, k))
        end
        return g
    end
    N.MeleeTrainedUnitIsHeroBJFilter = function()
        local u = V.ctx and V.ctx.filter_unit
        return u ~= nil and N.IsUnitType(u, "UNIT_TYPE_HERO")
    end
    N.LivingPlayerUnitsOfTypeIdFilter = function()
        local u = V.ctx and V.ctx.filter_unit
        return u ~= nil and u.alive ~= false and vm.s2id(u.id) == get("bj_livingPlayerUnitsTypeId")
    end
    N.IssueHauntOrderAtLocBJFilter = function()
        local u = V.ctx and V.ctx.filter_unit
        return u ~= nil and u.id == "ngol"
    end
    V.constants.filterGetUnitsInRectOfPlayer = N.Filter(N.GetUnitsInRectOfPlayerFilter)
    V.constants.filterGetUnitsOfPlayerAndTypeId = N.Filter(N.GetUnitsOfPlayerAndTypeIdFilter)
    V.constants.filterGetUnitsOfTypeIdAll = N.Filter(N.GetUnitsOfTypeIdAllFilter)
    V.constants.filterLivingPlayerUnitsOfTypeId = N.Filter(N.LivingPlayerUnitsOfTypeIdFilter)
    V.constants.filterMeleeTrainedUnitIsHeroBJ = N.Filter(N.MeleeTrainedUnitIsHeroBJFilter)
    V.constants.filterIssueHauntOrderAtLocBJ = N.Filter(N.IssueHauntOrderAtLocBJFilter)
    -- items
    N.UnitDropItem = function(u, id)
        local it = N.CreateItem(id, u and u.x or 0, u and u.y or 0)
        set("bj_lastCreatedItem", it)
        return it
    end
    N.GetItemLoc = function(it) return N.Location(N.GetItemX(it), N.GetItemY(it)) end
    N.GetItemType = function(it) return it and it.item_type or "ITEM_TYPE_PERMANENT" end
    N.EnumItemsInRect = function(r, filter, fn)
        for _, it in ipairs(V.items or {}) do
            if not it.removed and not it.owner and N.RectContainsCoords(r, it.x, it.y)
                and V:test(filter, { filter_item = it }) then
                V:with({ enum_item = it }, fn)
            end
        end
    end
    N.ChooseRandomItemEx = function() return -1 end
    N.ChooseRandomItem = function() return -1 end
    typed("integer", "ChooseRandomItemEx ChooseRandomItem")
    -- destructables
    N.CreateDestructableLoc = function(id, l, facing, scale, variation)
        return set("bj_lastCreatedDestructable", N.CreateDestructable(id, l.x, l.y, facing, scale, variation))
    end
    N.CreateDeadDestructableZ = function(id, x, y, z, facing, scale, variation)
        local d = N.CreateDestructable(id, x, y, facing, scale, variation)
        d.life = 0
        return d
    end
    N.GetDestructableLoc = function(d) return N.Location(N.GetDestructableX(d), N.GetDestructableY(d)) end
    N.GetDestructableMaxLife = function(d) return d and d.max_life or 100 end
    N.SetDestructableLifePercentBJ = function(d, pct) N.SetDestructableLife(d, N.GetDestructableMaxLife(d) * pct / 100) end
    N.IsDestructableDeadBJ = function(d) return d == nil or (d.life or 0) <= 0 end
    N.RandomDestructableInRectSimpleBJ = function() return nil end
    N.IssueTargetDestructableOrder = function() return false end
    typed("real", "GetDestructableMaxLife")
    -- BJ hashtables and caches (arguments in the BJ order: value, key, mission key, table)
    N.SaveRealBJ = function(v, k, mk, ht) N.SaveReal(ht, mk, k, v) end
    N.SaveIntegerBJ = function(v, k, mk, ht) N.SaveInteger(ht, mk, k, v) end
    N.SaveBooleanBJ = function(v, k, mk, ht) N.SaveBoolean(ht, mk, k, v) end
    N.SaveStringBJ = function(v, k, mk, ht) N.SaveStr(ht, mk, k, v) end
    N.LoadRealBJ = function(k, mk, ht) return N.LoadReal(ht, mk, k) end
    N.LoadIntegerBJ = function(k, mk, ht) return N.LoadInteger(ht, mk, k) end
    N.LoadBooleanBJ = function(k, mk, ht) return N.LoadBoolean(ht, mk, k) end
    N.LoadStringBJ = function(k, mk, ht) return N.LoadStr(ht, mk, k) end
    N.FlushChildHashtableBJ = function(mk, ht) N.FlushChildHashtable(ht, mk) end
    N.FlushParentHashtableBJ = function(ht) N.FlushParentHashtable(ht) end
    N.HaveStoredInteger = function(gc, m, k)
        return gc ~= nil and gc.data.integer ~= nil and gc.data.integer[m] ~= nil and gc.data.integer[m][k] ~= nil
    end
    N.FlushStoredBoolean = function(gc, m, k)
        if gc and gc.data.boolean and gc.data.boolean[m] then gc.data.boolean[m][k] = nil end
    end
    typed("real", "LoadRealBJ")
    typed("integer", "LoadIntegerBJ")
    typed("string", "LoadStringBJ")
    -- leaderboards (kept, not shown)
    N.CreateLeaderboardBJ = function(f, label)
        local lb = N.CreateLeaderboard()
        lb.label = label
        return set("bj_lastCreatedLeaderboard", lb)
    end
    N.GetLastCreatedLeaderboard = function() return get("bj_lastCreatedLeaderboard") end
    N.IsLeaderboardDisplayed = function(lb) return lb ~= nil and lb.shown == true end
    N.LeaderboardDisplayBJ = function(show, lb) if lb then lb.shown = show end end
    quiet("LeaderboardSetPlayerItemValueBJ LeaderboardSortItemsBJ LeaderboardAddItemBJ LeaderboardSetPlayerItemValueColorBJ "
      .. "LeaderboardSetPlayerItemLabelColorBJ LeaderboardSetPlayerItemLabelBJ")
    -- no system for these yet
    N.CameraSetupGetFieldSwap = function() return 0 end
    N.CameraSetupGetDestPositionX = function() return 0 end
    N.CameraSetupGetDestPositionY = function() return 0 end
    typed("real", "CameraSetupGetFieldSwap CameraSetupGetDestPositionX CameraSetupGetDestPositionY")
    N.UnitHasBuffBJ = function(u, id) return N.GetUnitAbilityLevel(u, id) > 0 end
    quiet("SetTextTagLifespanBJ SetTextTagPermanentBJ SetTextTagTextBJ SetTextTagFadepointBJ DestroyTextTagBJ SetTextTagAgeBJ "
      .. "SetTextTagColorBJ SetTextTagVelocityBJ SetTextTagPosBJ SetTextTagPosUnitBJ ShowTextTagForceBJ "
      .. "DestroyEffectBJ SyncSelections Cheat DoNotSaveReplay "
      .. "SetCameraPositionForPlayer SetCameraPositionLocForPlayer VolumeGroupSetVolumeBJ SetBlightRectBJ SetBlightRadiusLocBJ "
      .. "SetItemDropOnDeathBJ SetSoundPositionLocBJ AddWeatherEffectSaveLast RemoveWeatherEffectBJ EnableWeatherEffect "
      .. "SelectUnitAddForPlayer SelectUnitForPlayerSingle SelectUnitRemoveForPlayer ClearSelectionForPlayer "
      .. "AddUnitToStockBJ AddItemToStockBJ UpdateEachStockBuildingEnum EnableDawnDusk SetItemDropID "
      .. "TriggerWaitForSound WaitForSoundBJ PlayMusicBJ PlayMusicExBJ EndThematicMusicBJ "
      .. "StopMusicBJ PlayThematicMusicBJ SetMusicVolumeBJ SetCineFilterEndUV SetCineFilterTexMapFlags SetCineFilterStartUV "
      .. "SetCineFilterBlendMode SetCineFilterStartColor SetCineFilterEndColor SetCineFilterDuration SetCineFilterTexture "
      .. "DisplayCineFilterBJ ShowInterfaceForceOff ShowInterfaceForceOn SetUserControlForceOn SetUserControlForceOff "
      .. "MultiboardSuppressDisplay CameraSetTargetNoiseForPlayer CameraSetSourceNoiseForPlayer SetCineModeVolumeGroupsBJ "
      .. "CancelCineSceneBJ SetUnitTurnSpeedBJ CameraResetSmoothingFactorBJ ResetUnitAnimation")
    N.GetLastCreatedWeatherEffect = function() return get("bj_lastCreatedWeatherEffect") end
    -- }}}

    -- {{{ Game setup (Blizzard.j's InitBlizzard and melee helpers)
    local function none() end
    N.InitBlizzard = function() rawset(V.env, "bj_gameStarted", true) end
    N.InitGenericPlayerSlots = none
    N.InitQueuedTriggers = none
    N.InitRescuableBehaviorBJ = none
    N.InitDNCSounds = none
    N.InitMapRects = function()
        rawset(V.env, "bj_mapInitialPlayableArea", N.GetPlayableMapRect())
        rawset(V.env, "bj_mapInitialCameraBounds", N.GetPlayableMapRect())
    end
    N.DelayedSuspendDecayCreate = none
    N.RemovePurchasedItem = none
    N.UpdateStockAvailability = none
    N.PerformStockUpdates = none
    N.StartStockUpdates = none
    N.DetectGameStarted = function() rawset(V.env, "bj_gameStarted", true) end
    N.VersionGet = function() return "VERSION_FROZEN_THRONE" end
    N.VersionCompatible = function() return true end
    N.VersionSupported = function() return true end
    N.InitSummonableCaps = none
    N.InitNeutralBuildings = none
    N.InitBlizzardGlobals = none
    N.MeleeStartingVisibility = none
    -- Blizzard.j's: 3 heroes, one of each type (issue 528)
    N.SetPlayerMaxHeroesAllowed = function(max, p) if p then p.tech_max.HERO = max end end
    N.MeleeStartingHeroLimit = function()
        for n = 0, 11 do
            local p = V:player(n)
            p.tech_max.HERO = 3
            for _, id in ipairs({ "Hamg", "Hmkg", "Hpal", "Hblm", "Obla", "Ofar", "Otch", "Oshd", "Edem", "Ekee",
                                   "Emoo", "Ewar", "Udea", "Udre", "Ulic", "Ucrl" }) do
                p.tech_max[id] = 1
            end
        end
    end
    N.MeleeGrantHeroItems = none
    N.MeleeStartingResources = function()
        for n = 0, 11 do
            local p = V:player(n)
            p.gold, p.lumber = 500, 150
        end
    end
    N.MeleeClearExcessUnits = none
    N.MeleeStartingUnits = none
    N.MeleeStartingAI = none
    N.MeleeInitVictoryDefeat = none
    N.SetMapDescription = N.SetMapDescription
    -- }}}
end

--[[
wc3shim natives for units' state, heroes, orders and unit events
(issue W02e, step 2)

Licence: GNU AGPL v3 (server-side/LICENSE).

Life and death, owner, position and facing, the flags WC3 keeps on a unit
(invulnerable, hidden, paused, acquire range, user data, colour),
unit-type tests, ranges, abilities, timed life, ReplaceUnitBJ, waygates;
heroes' level, experience, attributes and skills; orders; and the unit
events (death, change of owner, a hero's level). Each does what the
project's own runtime's native of the same name does
(src/jass/natives/world.lua, bj.lua, core.lua; vm.lua's unit_event) on
its bare world, with the server's creature beside the unit.

Where the server forces a difference:

- Life is kept in WC3's numbers on the unit (u.hp of u.hp_max: 100 of
  100, as the VM's bare world, until creature templates carry WC3's hit
  points: W02e step 4), and the fraction is mirrored onto the creature
  (SetHealth). When the server's own combat changes the creature's
  health, the next read takes its fraction back. A unit brought to 0.405
  or less dies: the creature is killed.
- Deaths the script causes (KillUnit, life set to 0, timed life) fire
  their events at once, as the VM's. Deaths on the server (its combat)
  are seen at the next look (every shim.RECT_CHECK_MS, while a death event
  is registered), with no killing unit: ALE's creature death event would
  name one (step 3's loader, or step 4).
- Mana, the flags, abilities, heroes' level, experience and attributes,
  and waygates are kept on the unit: the server has no WC3 mechanics yet
  (step 7). A hero's level is not the creature's level.
- Orders are recorded as the VM's bare world records them (GetUnitCurrentOrder
  reads them), and the creature is asked to move there (MoveTo), attack
  (AttackStart) or stop (MoveStop). Spells and builds aren't orders the
  server knows yet: they answer false, as the VM's world without them.
- Unit types: a hero is a type whose id starts with a capital letter (as
  the VM's IsHeroUnitId; WC3's editor names custom heroes so); dead is
  not alive; ground is every unit; the rest (structure, flying ...) need
  WC3's unit data, which the server's templates don't carry yet, and
  answer false, as on the VM's bare world.

Installed by init.lua: require("wc3shim.units")(S, N, shim).
]]

return function(S, N, shim)
    local id2s = shim.id2s
    local function set(name, value) rawset(S.env, name, value) return value end
    local function get(name) return rawget(S.env, name) end
    local alive, sync = S.alive, S.sync
    local function owner(u) return S:player(u.player) end
    local names = {}
    for _, t in ipairs(S.data.templates or {}) do names[t.id] = names[t.id] or t.name end

    -- {{{ Unit events (as the VM's V:unit_event)
    -- "DEATH": EVENT_PLAYER_UNIT_DEATH for the owner (and data.also_player,
    -- a changed unit's previous owner), EVENT_UNIT_DEATH for the unit,
    -- and its widget death events
    function S:unit_event(what, u, data)
        local own = self:player(u.player)
        local also = data and data.also_player
        local function ctx()
            local c = { unit = u, player = own }
            if data then for k, v in pairs(data) do c[k] = v end end
            return c
        end
        local player_event = what:match("^HERO_") and ("EVENT_PLAYER_" .. what) or ("EVENT_PLAYER_UNIT_" .. what)
        self:dispatch(player_event, function(reg)
            return reg.player == own or (also and reg.player == also)
        end, ctx)
        self:dispatch("EVENT_UNIT_" .. what, function(reg) return reg.unit == u end, ctx)
        if what == "DEATH" then
            self:dispatch("WIDGET_DEATH", function(reg) return reg.unit == u end, ctx)
        end
    end
    local function watching(event)
        if tostring(event):find("DEATH", 1, true) then
            S.watch_deaths = true
            S:start_polling()
        end
    end
    N.TriggerRegisterPlayerUnitEvent = function(trig, p, event, filter)
        watching(event)
        return S:listen(trig, event, { player = p, filter = filter })
    end
    N.TriggerRegisterPlayerUnitEventSimple = function(trig, p, event)
        return N.TriggerRegisterPlayerUnitEvent(trig, p, event, nil)
    end
    N.TriggerRegisterAnyUnitEventBJ = function(trig, event)
        for n = 0, 15 do N.TriggerRegisterPlayerUnitEvent(trig, S:player(n), event, nil) end
    end
    N.TriggerRegisterUnitEvent = function(trig, u, event)
        watching(event)
        return S:listen(trig, event, { unit = u })
    end
    N.TriggerRegisterFilterUnitEvent = function(trig, u, event) return N.TriggerRegisterUnitEvent(trig, u, event) end
    N.TriggerRegisterDeathEvent = function(trig, widget)
        watching("DEATH")
        return S:listen(trig, "WIDGET_DEATH", { unit = widget })
    end
    local function from(field) return function() local c = S.ctx return c and c[field] end end
    N.GetDyingUnit = from("unit")
    N.GetKillingUnit = from("killer")
    N.GetKillingUnitBJ = N.GetKillingUnit
    N.GetTriggerWidget = from("unit")
    N.GetAttacker = from("attacker")
    N.GetAttackedUnitBJ = from("unit")
    -- only in a change of owner (as the VM's: drop tables ask it during deaths too, and must get null)
    N.GetChangingUnit = function()
        local c = S.ctx
        return c and c.event and tostring(c.event):find("CHANGE_OWNER", 1, true) and c.unit or nil
    end
    N.GetChangingUnitPrevOwner = from("prev_owner")
    N.GetLevelingUnit = from("unit")
    N.GetOrderedUnit = from("unit")
    N.GetIssuedOrderId = from("order_id")
    N.GetIssuedOrderIdBJ = N.GetIssuedOrderId
    N.GetOrderTargetUnit = from("target")
    N.GetSpellAbilityUnit = from("unit")
    N.GetSpellAbilityId = from("ability")
    N.GetSpellTargetUnit = from("target")

    -- deaths on the server: a creature found dead at a look
    function S:check_deaths()
        local list = {}
        for k, u in ipairs(self.units) do list[k] = u end
        for _, u in ipairs(list) do
            if u.creature and not u.removed and not u.death_raised and not alive(u) then
                u.death_raised, u.hp = true, 0
                self:unit_event("DEATH", u, { killer = nil })
            end
        end
    end
    -- }}}

    -- {{{ Life and death
    local function kill(u, killer)
        if not alive(u) then return end
        u.hp, u.alive, u.death_raised = 0, false, true
        if u.creature then u.creature:Kill(u.creature) end
        S:unit_event("DEATH", u, { killer = killer })
    end
    S.kill_unit = kill
    -- life as WC3 counts it, taking the creature's fraction when the server changed it
    local function life(u)
        local c = u.creature
        if c and not u.removed then
            local h, m = c:GetHealth(), c:GetMaxHealth()
            if h and m and m > 0 and h ~= u.wow_hp then
                u.hp = (u.hp_max or 100) * h / m
                u.wow_hp = h
            end
        end
        return u.hp or 0
    end
    local function set_life(u, v)
        u.hp = math.min(v, u.hp_max or v)
        local c = u.creature
        if c and u.hp > 0.405 then
            local m = c:GetMaxHealth()
            if m and m > 0 then
                local h = math.max(1, math.floor(m * u.hp / (u.hp_max or 100) + 0.5))
                c:SetHealth(h)
                u.wow_hp = h
            end
        end
        if u.hp <= 0.405 then kill(u, nil) end
    end
    N.KillUnit = function(u) kill(u, nil) end
    N.GetUnitState = function(u, s)
        if not u then return 0 end
        if s == "UNIT_STATE_LIFE" then return alive(u) and life(u) or 0 end
        if s == "UNIT_STATE_MAX_LIFE" then return u.hp_max or 0 end
        if s == "UNIT_STATE_MANA" then return u.mana or 0 end
        if s == "UNIT_STATE_MAX_MANA" then return u.mana_max or 0 end
        return 0
    end
    N.SetUnitState = function(u, s, v)
        if not u then return end
        if s == "UNIT_STATE_LIFE" then
            if not alive(u) then return end
            set_life(u, v)
        elseif s == "UNIT_STATE_MANA" then
            u.mana = math.max(0, math.min(v, u.mana_max or v))
        end
    end
    N.GetWidgetLife = function(u) return N.GetUnitState(u, "UNIT_STATE_LIFE") end
    N.SetWidgetLife = function(u, v) N.SetUnitState(u, "UNIT_STATE_LIFE", v) end
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
    N.IsUnitAliveBJ = function(u) return alive(u) end
    N.IsUnitDeadBJ = function(u) return not alive(u) end
    N.UnitAlive = N.IsUnitAliveBJ
    N.ExplodeUnitBJ = function(u) if u then u.exploded = true end; N.KillUnit(u) end
    N.SetUnitExploded = function(u, flag) if u then u.exploded = flag end end
    N.UnitApplyTimedLife = function(u, buff, seconds)
        if not u then return end
        S:after(seconds or 0, function() if alive(u) then kill(u, nil) end end)
    end
    N.UnitApplyTimedLifeBJ = function(seconds, buff, u) N.UnitApplyTimedLife(u, buff, seconds) end
    -- }}}

    -- {{{ Owner, position, facing
    N.SetUnitOwner = function(u, p, change_color)
        if not u or not p or u.player == p.id then return end
        local prev = owner(u)
        u.player = p.id
        if change_color ~= false then u.color = p.color end
        local faction = S.faction_of[p.id]
        if u.creature and faction then u.creature:SetFaction(faction) end
        u.target, u.order = nil, nil
        S:unit_event("CHANGE_OWNER", u, { prev_owner = prev, also_player = prev })
    end
    local function place(u, x, y)
        if not u then return end
        u.x, u.y = x, y
        local c = u.creature
        if c and not u.removed then
            local X, Y = S.to_wow(x, y)
            c:NearTeleport(X, Y, S.ground(X, Y), c:GetO())
            u.wow_x, u.wow_y = X, Y
        end
    end
    S.place_unit = place
    N.SetUnitX = function(u, x) if u then place(u, x, sync(u).y) end end
    N.SetUnitY = function(u, y) if u then place(u, sync(u).x, y) end end
    N.SetUnitPosition = place
    N.SetUnitPositionLoc = function(u, l) place(u, l.x, l.y) end
    local function face(u, f)
        if not u then return end
        u.facing = math.rad(f)
        local c = u.creature
        if c and not u.removed then
            local o = S.to_orientation(f)
            c:SetFacing(o)
            u.wow_o = o
        end
    end
    N.SetUnitFacing = face
    N.SetUnitFacingTimed = face
    N.SetUnitPositionLocFacingBJ = function(u, l, f) place(u, l.x, l.y); face(u, f) end
    N.SetUnitPositionLocFacingLocBJ = function(u, l, look)
        place(u, l.x, l.y)
        face(u, N.AngleBetweenPoints(l, look))
    end
    N.SetUnitFacingToFaceLocTimed = function(u, l) face(u, N.AngleBetweenPoints(N.GetUnitLoc(u), l)) end
    N.SetUnitFacingToFaceUnitTimed = function(u, t) face(u, N.AngleBetweenPoints(N.GetUnitLoc(u), N.GetUnitLoc(t))) end
    -- }}}

    -- {{{ Flags kept on the unit
    N.SetUnitInvulnerable = function(u, flag) if u then u.invulnerable = flag or nil end end
    N.SetUnitInvulnerableBJ = N.SetUnitInvulnerable
    N.IsUnitInvulnerable = function(u) return u ~= nil and u.invulnerable == true end
    N.ShowUnit = function(u, show) if u then u.hidden = not show or nil end end
    N.ShowUnitHide = function(u) N.ShowUnit(u, false) end
    N.ShowUnitShow = function(u) N.ShowUnit(u, true) end
    N.IsUnitHidden = function(u) return u ~= nil and u.hidden == true end
    N.IsUnitHiddenBJ = N.IsUnitHidden
    N.PauseUnit = function(u, flag)
        if u then u.paused = flag or nil; if flag then u.order, u.target = nil, nil end end
    end
    N.PauseUnitBJ = function(pause, u) N.PauseUnit(u, pause) end
    N.IsUnitPaused = function(u) return u ~= nil and u.paused == true end
    N.IsUnitPausedBJ = N.IsUnitPaused
    N.SetUnitAcquireRange = function(u, r) if u then u.acquire_range = r end end
    N.SetUnitAcquireRangeBJ = N.SetUnitAcquireRange
    N.GetUnitAcquireRange = function(u) return u and u.acquire_range or 0 end
    N.SetUnitUserData = function(u, v) if u then u.user_data = v end end
    N.SetUnitUserDataBJ = N.SetUnitUserData
    N.GetUnitUserData = function(u) return u and u.user_data or 0 end
    N.SetUnitColor = function(u, c) if u then u.color = c end end
    N.GetUnitMoveSpeed = function(u) return u and (u.speed or 270) or 0 end
    N.GetUnitDefaultMoveSpeed = function(u) return u and (u.speed or 270) or 0 end
    N.SetUnitMoveSpeed = function(u, s) if u then u.speed = s end end
    N.GetUnitName = function(u) return u and (u.name or names[u.id] or u.id) or "" end
    N.GetUnitLevel = function(u) return u and (u.level or 1) or 0 end
    N.GetUnitPointValue = function(u) return u and u.point_value or 0 end
    -- }}}

    -- {{{ Unit types, owners, ranges
    local function is_hero_id(s) return s:sub(1, 1):match("%u") ~= nil end
    N.IsHeroUnitId = function(id) return is_hero_id(id2s(id)) end
    local TYPE_TEST = {
        UNIT_TYPE_HERO = function(u) return is_hero_id(u.id) end,
        UNIT_TYPE_DEAD = function(u) return not alive(u) end,
        UNIT_TYPE_GROUND = function() return true end,
    }
    N.IsUnitType = function(u, t)
        local f = u and TYPE_TEST[t]
        return f ~= nil and f(u) and true or false
    end
    N.IsUnitOwnedByPlayer = function(u, p) return u ~= nil and p ~= nil and u.player == p.id end
    N.IsUnitAlly = function(u, p) return u ~= nil and N.IsPlayerAlly(owner(u), p) end
    N.IsUnitEnemy = function(u, p) return u ~= nil and N.IsPlayerEnemy(p, owner(u)) end
    N.IsUnit = function(a, b) return a == b end
    N.IsUnitInRange = function(a, b, d)
        if not a or not b then return false end
        sync(a); sync(b)
        return (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 <= d * d
    end
    N.IsUnitInRangeXY = function(a, x, y, d)
        if not a then return false end
        sync(a)
        return (a.x - x) ^ 2 + (a.y - y) ^ 2 <= d * d
    end
    N.IsUnitInRangeLoc = function(a, l, d) return N.IsUnitInRangeXY(a, l.x, l.y, d) end
    N.IsUnitInRangeLocBJ = N.IsUnitInRangeLoc
    N.RectContainsUnit = function(r, u) return u ~= nil and N.RectContainsCoords(r, sync(u).x, u.y) end
    N.IsUnitInRegion = function(g, u)
        for _, r in ipairs(g.rects) do if N.RectContainsUnit(r, u) then return true end end
        return false
    end
    N.IsUnitIllusionBJ = function() return false end
    -- }}}

    -- {{{ Abilities (kept on the unit: spells are step 7's)
    N.UnitAddAbility = function(u, id)
        if not u then return false end
        u.abilities = u.abilities or {}
        local k = id2s(id)
        if u.abilities[k] then return false end
        u.abilities[k] = 1
        return true
    end
    N.UnitRemoveAbility = function(u, id)
        if not u or not u.abilities then return false end
        local k = id2s(id)
        if not u.abilities[k] then return false end
        u.abilities[k] = nil
        return true
    end
    N.GetUnitAbilityLevel = function(u, id) return u and u.abilities and u.abilities[id2s(id)] or 0 end
    N.SetUnitAbilityLevel = function(u, id, lvl)
        if u then u.abilities = u.abilities or {}; u.abilities[id2s(id)] = lvl end
        return lvl
    end
    N.UnitAddAbilityBJ = function(id, u) return N.UnitAddAbility(u, id) end
    N.UnitRemoveAbilityBJ = function(id, u) return N.UnitRemoveAbility(u, id) end
    N.GetUnitAbilityLevelSwapped = function(id, u) return N.GetUnitAbilityLevel(u, id) end
    N.SetUnitAbilityLevelSwapped = function(id, u, lvl) return N.SetUnitAbilityLevel(u, id, lvl) end
    N.UnitMakeAbilityPermanent = function() return true end
    N.UnitResetCooldown = function(u) if u then u.cooldowns = {} end end
    -- }}}

    -- {{{ ReplaceUnitBJ: a unit of another type in the old one's place,
    -- keeping its owner, life fraction, facing and hiddenness
    N.ReplaceUnitBJ = function(u, id, policy)
        if not u then return nil end
        local frac = (u.hp_max and u.hp_max > 0) and life(u) / u.hp_max or 1
        local was_alive = alive(u)
        local nu = S.create_unit(owner(u), id, u.x, u.y, math.deg(u.facing or 0))
        if nu then
            if was_alive then set_life(nu, math.max(1, nu.hp_max * frac)) end
            nu.hidden = u.hidden
        end
        N.RemoveUnit(u)
        set("bj_lastReplacedUnit", nu)
        return nu
    end
    N.GetLastReplacedUnitBJ = function() return get("bj_lastReplacedUnit") end
    -- }}}

    -- {{{ Heroes (kept on the unit)
    N.GetHeroLevel = function(u) return u and (u.level or 1) or 0 end
    N.SetHeroLevel = function(u, lvl)
        if not u then return end
        local was = u.level or 1
        u.level = lvl
        if lvl > was then S:unit_event("HERO_LEVEL", u) end
    end
    N.SetHeroLevelBJ = function(u, lvl, show) N.SetHeroLevel(u, lvl, show) end
    N.UnitStripHeroLevel = function(u, n)
        if not u then return false end
        N.SetHeroLevel(u, math.max(1, (u.level or 1) - n))
        return true
    end
    N.GetHeroXP = function(u) return u and math.floor(u.xp or 0) or 0 end
    N.SetHeroXP = function(u, xp) if u then u.xp = xp end end
    N.AddHeroXP = function(u, xp) if u then u.xp = (u.xp or 0) + xp end end
    N.AddHeroXPSwapped = function(xp, u, show) N.AddHeroXP(u, xp, show) end
    N.SetHeroXPBJ = function(u, xp) N.SetHeroXP(u, xp) end
    N.SuspendHeroXP = function(u, flag) if u then u.xp_suspended = flag end end
    N.SuspendHeroXPBJ = function(flag, u) N.SuspendHeroXP(u, not flag) end
    N.IsSuspendedXP = function(u) return u ~= nil and u.xp_suspended == true end
    for _, name in ipairs({ "Str", "Agi", "Int" }) do
        local k = name:lower()
        N["GetHero" .. name] = function(u) return u and (u[k] or 0) or 0 end
        N["SetHero" .. name] = function(u, v) if u then u[k] = v end end
    end
    local STAT = { [0] = "str", [1] = "agi", [2] = "int" }
    N.ModifyHeroStat = function(stat, u, op, v)
        if not u then return end
        local k = STAT[stat]
        if not k then return end
        if op == 0 then u[k] = (u[k] or 0) + v
        elseif op == 1 then u[k] = math.max(0, (u[k] or 0) - v)
        else u[k] = v end
    end
    N.GetHeroStatBJ = function(stat, u) return u and u[STAT[stat]] or 0 end
    N.GetHeroProperName = function(u) return u and (u.proper_name or N.GetUnitName(u)) or "" end
    N.GetHeroSkillPoints = function(u) return u and u.skill_points or 0 end
    N.UnitModifySkillPoints = function(u, n)
        if not u then return false end
        u.skill_points = math.max(0, (u.skill_points or 0) + n)
        return true
    end
    N.ModifyHeroSkillPoints = function(u, op, v)
        if op == 0 then return N.UnitModifySkillPoints(u, v)
        elseif op == 1 then return N.UnitModifySkillPoints(u, -v) end
        return N.UnitModifySkillPoints(u, v - N.GetHeroSkillPoints(u))
    end
    N.SelectHeroSkill = function(u, id)
        if not u then return end
        local k = id2s(id)
        u.abilities = u.abilities or {}
        u.abilities[k] = (u.abilities[k] or 0) + 1
    end
    -- a dead hero back, full of life, where asked: the creature respawns there
    N.ReviveHero = function(u, x, y)
        if not u or u.removed or alive(u) then return false end
        if u.creature then u.creature:Respawn() end
        u.alive, u.death_raised, u.hp, u.wow_hp = true, nil, u.hp_max or 100, nil
        u.mana = u.mana_max
        place(u, x, y)
        return true
    end
    N.ReviveHeroLoc = function(u, l, fx) return N.ReviveHero(u, l.x, l.y, fx) end
    -- }}}

    -- {{{ Orders (ids from memory of the game, as the VM's)
    local ORDER = { smart = 851971, stop = 851972, attack = 851983, move = 851986, patrol = 851990,
                    holdposition = 851993, attackground = 851984, harvest = 852018, resumeharvesting = 852017,
                    returnresources = 852020, repair = 852024, cancel = 851976 }
    local ORDER_NAME = {}
    for k, v in pairs(ORDER) do ORDER_NAME[v] = k end
    N.OrderId = function(s) return ORDER[s] or 0 end
    N.OrderId2String = function(n) return ORDER_NAME[n] or "" end
    N.OrderId2StringBJ = N.OrderId2String
    N.String2OrderIdBJ = N.OrderId
    N.GetUnitCurrentOrder = function(u)
        local o = u and u.order
        if not o then return 0 end
        return ORDER[({ move = "move", attack = "attack", attack_unit = "attack", patrol = "patrol", hold = "holdposition" })[o.kind] or ""] or 0
    end
    -- the creature told: walk to a WC3 point, attack a unit's creature, stop
    local function go(u, kind, x, y, target)
        u.order, u.target = { kind = kind, x = x, y = y }, target
        local c = u.creature
        if not c or u.removed then return end
        if kind == "attack_unit" then
            if target and target.creature then c:AttackStart(target.creature) end
        elseif kind == "stop" or kind == "hold" then
            c:MoveStop()
        else
            local X, Y = S.to_wow(x, y)
            c:MoveTo(0, X, Y, S.ground(X, Y))
        end
    end
    local function point_order(u, name, x, y)
        if not alive(u) or u.paused then return false end
        name = type(name) == "number" and ORDER_NAME[name] or name
        local kind = ({ move = "move", smart = "move", attack = "attack", patrol = "patrol", attackground = "attack" })[name]
        if not kind then return false end
        go(u, kind, x, y)
        return true
    end
    local function target_order(u, name, t)
        if not alive(u) or not t or u.paused then return false end
        name = type(name) == "number" and ORDER_NAME[name] or name
        if name == "attack" or (name == "smart" and not N.IsPlayerAlly(owner(u), owner(t))) then
            go(u, "attack_unit", nil, nil, t)
        elseif name == "move" or name == "smart" then
            sync(t)
            go(u, "move", t.x, t.y)
        else
            return false
        end
        return true
    end
    local function immediate_order(u, name)
        if not alive(u) then return false end
        name = type(name) == "number" and ORDER_NAME[name] or name
        if name == "stop" then go(u, "stop")
        elseif name == "holdposition" then go(u, "hold")
        else return false end
        return true
    end
    S.point_order, S.target_order, S.immediate_order = point_order, target_order, immediate_order
    N.IssuePointOrder = point_order
    N.IssuePointOrderById = point_order
    N.IssuePointOrderLoc = function(u, name, l) return point_order(u, name, l.x, l.y) end
    N.IssuePointOrderByIdLoc = N.IssuePointOrderLoc
    N.IssuePointOrderLocBJ = N.IssuePointOrderLoc
    N.IssueTargetOrder = target_order
    N.IssueTargetOrderById = target_order
    N.IssueTargetOrderBJ = target_order
    N.IssueImmediateOrder = immediate_order
    N.IssueImmediateOrderById = immediate_order
    N.IssueImmediateOrderBJ = immediate_order
    -- }}}

    -- {{{ Waygates (kept on the unit: the server doesn't teleport through them yet)
    N.WaygateSetDestination = function(u, x, y) if u then u.waygate = { x = x, y = y, active = u.waygate and u.waygate.active } end end
    N.WaygateSetDestinationLocBJ = function(u, l) N.WaygateSetDestination(u, l.x, l.y) end
    N.WaygateActivate = function(u, on) if u then u.waygate = u.waygate or {}; u.waygate.active = on end end
    N.WaygateActivateBJ = function(on, u) N.WaygateActivate(u, on) end
    N.WaygateIsActive = function(u) return u ~= nil and u.waygate ~= nil and u.waygate.active == true end
    N.WaygateGetDestinationX = function(u) return u and u.waygate and u.waygate.x or 0 end
    N.WaygateGetDestinationY = function(u) return u and u.waygate and u.waygate.y or 0 end
    -- }}}
end

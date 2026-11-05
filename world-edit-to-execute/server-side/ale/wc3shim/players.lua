--[[
wc3shim natives for players and forces (issue W02e, step 2)

Licence: GNU AGPL v3 (server-side/LICENSE).

A WC3 player's slot (name, controller, race, colour, team, start
location), alliances, tech limits, the map's setup calls (config()),
forces and their enumerations, messages to players, and players' chat and
leave events. Each does what the project's own runtime's native of the
same name does (src/jass/natives/world.lua, bj.lua, interface.lua,
core.lua's chat event, vm.lua's V:chat and V:player_event).

Where the server forces a difference:

- Nothing here calls ALE. A WC3 player is a slot, not a WoW character;
  W02g seats characters in slots. Until then the slots are as the VM
  starts them (0-11 playing, 12-15 neutral; opts.playing names the
  playing ones, as the VM's), and names are map-data.lua's (the map's own
  player names), else "Player N".
- Allies at the start: the players of one of the map's forces, when the
  force is allied (map-data.lua's factions, from W02b), as the VM's world
  allies a force's players. A map-data without factions starts with no
  allies, as the VM's bare world.
- Messages. The VM shows a message only to its local player; a server has
  none, so a message goes to every player it names: opts.on_message(p,
  text, seconds) hears each (W02g sends it to the character seated in
  that slot), and S.messages keeps the last 200 { player, text, seconds,
  at }. TRIGSTR_ references are resolved from map-data.lua's strings.
- Chat and leaving come from outside: S:chat(player_id, text) and
  S:player_event(event, player_id), the VM's own entry points, are what
  the server's loader calls (step 3; W02g says which character is which
  slot).

Installed by init.lua: require("wc3shim.players")(S, N, shim).
]]

return function(S, N, shim)
    local data = S.data
    local id2s = shim.id2s

    -- {{{ The slots
    for _, p in ipairs(data.players or {}) do
        if type(p.number) == "number" and p.name and p.name ~= "" then S:player(p.number).name = p.name end
    end
    if S.opts.playing then
        for n = 0, 11 do S:player(n).slot = "PLAYER_SLOT_STATE_EMPTY" end
        for _, n in ipairs(S.opts.playing) do S:player(n).slot = "PLAYER_SLOT_STATE_PLAYING" end
    end
    for _, f in ipairs(data.factions or {}) do
        if f.allied and not f.neutral then
            for _, a in ipairs(f.players or {}) do
                for _, b in ipairs(f.players or {}) do
                    if a ~= b and a < 12 and b < 12 then S:player(a).ally[b] = true end
                end
            end
        end
    end

    N.GetPlayerName = function(p) return p and S:text(p.name) or "" end
    N.SetPlayerName = function(p, name) if p then p.name = name end end
    N.GetPlayerSlotState = function(p) return p and p.slot or "PLAYER_SLOT_STATE_EMPTY" end
    N.GetPlayerController = function(p) return p and p.controller end
    N.SetPlayerController = function(p, c) if p then p.controller = c end end
    N.GetPlayerRace = function(p) return p and p.race end
    N.SetPlayerRacePreference = function(p, r)
        if p then p.race = type(r) == "string" and r:gsub("RACE_PREF_", "RACE_") or r end
    end
    N.SetPlayerRaceSelectable = function() end
    N.GetPlayerColor = function(p) return p and p.color or 0 end
    N.SetPlayerColor = function(p, c) if p then p.color = c end end
    N.SetPlayerColorBJ = function(p, c, change_units)
        N.SetPlayerColor(p, c)
        if change_units then
            for _, u in ipairs(S.units) do if u.player == p.id then u.color = c end end
        end
    end
    N.GetPlayerTeam = function(p) return p and p.team or 0 end
    N.SetPlayerTeam = function(p, t) if p then p.team = t end end
    N.GetPlayerStartLocation = function(p) return p and p.start or 0 end
    N.SetPlayerStartLocation = function(p, n) if p then p.start = n end end
    N.ForcePlayerStartLocation = N.SetPlayerStartLocation
    N.SetPlayerHandicap = function(p, h) if p then p.handicap = h end end
    N.SetPlayerHandicapXP = function(p, h) if p then p.handicap_xp = h end end
    N.SetPlayerHandicapBJ = function(p, pct) N.SetPlayerHandicap(p, pct / 100) end
    N.SetPlayerHandicapXPBJ = function(p, pct) N.SetPlayerHandicapXP(p, pct / 100) end
    N.SetPlayerOnScoreScreen = function() end
    N.SetPlayerOnScoreScreenBJ = function() end
    N.SetPlayerFlagBJ = function() end
    N.IsPlayerObserver = function() return false end
    N.RemovePlayer = function(p, result) if p then p.slot, p.result = "PLAYER_SLOT_STATE_LEFT", result end end
    N.CachePlayerHeroData = function() end
    -- neutral victim (13) and extra (14): allied to everyone, as Blizzard.j sets them
    N.ConfigureNeutralVictim = function()
        local victim = S:player(13)
        for n = 0, 15 do
            if n ~= 13 then victim.ally[n] = true; S:player(n).ally[13] = true end
        end
    end
    -- }}}

    -- {{{ Alliances (bj_ALLIANCE_* levels: passive, vision)
    N.IsPlayerAlly = function(a, b) return a ~= nil and b ~= nil and (a == b or a.ally[b.id] == true) end
    N.IsPlayerEnemy = function(a, b) return a ~= nil and b ~= nil and a ~= b and not a.ally[b.id] end
    N.GetPlayerAlliance = function(a, b, kind)
        if kind == "ALLIANCE_SHARED_VISION" then return a.vision[b.id] == true end
        return a.ally[b.id] == true
    end
    N.SetPlayerAlliance = function(a, b, kind, value)
        if not a or not b or a == b then return end
        if kind == "ALLIANCE_PASSIVE" then a.ally[b.id] = value or nil
        elseif kind == "ALLIANCE_SHARED_VISION" then a.vision[b.id] = value or nil end
    end
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
    N.SetPlayerAllianceStateAllyBJ = function(a, b, flag)
        if a and b and a ~= b then a.ally[b.id] = flag or nil end
    end
    N.SetPlayerAllianceStateVisionBJ = function(a, b, flag)
        if a and b and a ~= b then a.vision[b.id] = flag or nil end
    end
    N.SetPlayerAllianceStateControlBJ = function() end
    N.SetPlayerAllianceStateFullControlBJ = function() end
    N.SetPlayerAllianceBJ = function(a, setting, value, b) N.SetPlayerAlliance(a, b, setting, value) end
    N.MakeUnitsPassiveForPlayer = function() end
    N.MakeUnitsPassiveForTeam = function() end
    N.ShareEverythingWithTeam = function(p)
        for n = 0, 11 do
            local q = S:player(n)
            if q ~= p and q.team == p.team then p.ally[n], p.vision[n] = true, true end
        end
    end
    -- }}}

    -- {{{ Tech: limits and research, kept per player (the server has no
    -- training lists or research yet: the mechanics, step 7)
    N.SetPlayerTechMaxAllowed = function(p, id, max) if p then p.tech_max[id2s(id)] = max end end
    N.GetPlayerTechMaxAllowed = function(p, id) return p and p.tech_max[id2s(id)] or -1 end
    N.SetPlayerTechMaxAllowedSwap = function(id, max, p) N.SetPlayerTechMaxAllowed(p, id, max) end
    N.SetPlayerUnitAvailableBJ = function(id, avail, p) N.SetPlayerTechMaxAllowed(p, id, avail and -1 or 0) end
    N.SetPlayerMaxHeroesAllowed = function(max, p) if p then p.tech_max.HERO = max end end
    local function research_level(p, s) return p.research and p.research[s] or 0 end
    N.SetPlayerTechResearched = function(p, id, level)
        if not p then return end
        p.research = p.research or {}
        p.research[id2s(id)] = level
    end
    N.SetPlayerTechResearchedSwap = function(id, level, p) N.SetPlayerTechResearched(p, id, level) end
    N.AddPlayerTechResearched = function(p, id, levels)
        if not p then return end
        N.SetPlayerTechResearched(p, id, research_level(p, id2s(id)) + (levels or 1))
    end
    -- a research's level, else how many living units of the type the
    -- player has (the VM asks its game the same: W.tech_count)
    N.GetPlayerTechCount = function(p, id, specific)
        if not p then return 0 end
        local s = id2s(id)
        local lvl = research_level(p, s)
        if lvl > 0 then return lvl end
        if #s == 4 and not s:match("^R") then
            local n = 0
            for _, u in ipairs(S.units) do
                if u.player == p.id and u.id == s and S.alive(u) then n = n + 1 end
            end
            return n
        end
        return 0
    end
    N.GetPlayerTechCountSimple = function(id, p) return N.GetPlayerTechCount(p, id, true) end
    N.GetPlayerTechResearched = function(p, id) return p ~= nil and research_level(p, id2s(id)) > 0 end
    N.SetPlayerAbilityAvailable = function(p, id, avail) if p then p.abilities_off[id2s(id)] = not avail or nil end end
    N.SetPlayerAbilityAvailableBJ = function(avail, id, p) N.SetPlayerAbilityAvailable(p, id, avail) end
    -- units the player has, living
    local function count(p, test)
        local n = 0
        for _, u in ipairs(S.units) do
            if p and u.player == p.id and S.alive(u) and test(u) then n = n + 1 end
        end
        return n
    end
    N.GetPlayerUnitCount = function(p) return count(p, function() return true end) end
    N.GetPlayerTypedUnitCount = function(p, name) return count(p, function(u) return u.id == name end) end
    -- }}}

    -- {{{ The map's setup (config())
    S.start_locs = {}
    N.SetMapName = function(s) S.map_name = s end
    N.SetMapDescription = function(s) S.map_description = s end
    N.SetPlayers = function(n) S.player_count = n end
    N.SetTeams = function(n) S.team_count = n end
    N.SetGamePlacement = function() end
    N.DefineStartLocation = function(n, x, y) S.start_locs[n] = { x = x, y = y } end
    N.DefineStartLocationLoc = function(n, l) S.start_locs[n] = { x = l.x, y = l.y } end
    N.SetStartLocPrioCount = function() end
    N.SetStartLocPrio = function() end
    N.GetStartLocationX = function(n) return S.start_locs[n] and S.start_locs[n].x or 0 end
    N.GetStartLocationY = function(n) return S.start_locs[n] and S.start_locs[n].y or 0 end
    N.GetStartLocationLoc = function(n) return N.Location(N.GetStartLocationX(n), N.GetStartLocationY(n)) end
    N.GetPlayerStartLocationX = function(p) return N.GetStartLocationX(p.start) end
    N.GetPlayerStartLocationY = function(p) return N.GetStartLocationY(p.start) end
    N.GetPlayerStartLocationLoc = function(p) return N.GetStartLocationLoc(p.start) end
    N.GetPlayers = function() return S.player_count or 12 end
    N.GetTeams = function() return S.team_count or 12 end
    -- }}}

    -- {{{ Forces
    local function new_force() return S:handle({ kind = "force", players = {} }) end
    local function force_list(f)
        local l = {}
        for n = 0, 15 do if f.players[n] then l[#l + 1] = f.players[n] end end
        return l
    end
    S.force_list = force_list
    N.CreateForce = new_force
    N.DestroyForce = function(f) if f then f.destroyed = true end end
    N.ForceAddPlayer = function(f, p) if f and p then f.players[p.id] = p end end
    N.ForceRemovePlayer = function(f, p) if f and p then f.players[p.id] = nil end end
    N.ForceClear = function(f) if f then f.players = {} end end
    N.IsPlayerInForce = function(p, f) return p ~= nil and f ~= nil and f.players[p.id] ~= nil end
    N.ForForce = function(f, fn)
        if not f or not fn then return end
        for _, p in ipairs(force_list(f)) do S:with({ enum_player = p }, fn) end
    end
    local function enum(f, filter, test)
        f.players = {}
        for n = 0, 15 do
            local p = S:player(n)
            if test(p) and S:test(filter, { filter_player = p }) then f.players[n] = p end
        end
    end
    N.ForceEnumPlayers = function(f, filter) enum(f, filter, function() return true end) end
    N.ForceEnumAllies = function(f, who, filter) enum(f, filter, function(p) return N.IsPlayerAlly(who, p) end) end
    N.ForceEnumEnemies = function(f, who, filter) enum(f, filter, function(p) return N.IsPlayerEnemy(who, p) end) end
    -- the Blizzard.j forces InitBlizzard makes
    local all = new_force()
    for n = 0, 15 do all.players[n] = S:player(n) end
    S.constants.bj_FORCE_ALL_PLAYERS = all
    local single = {}
    for n = 0, 15 do
        single[n] = new_force()
        single[n].players[n] = S:player(n)
    end
    S.constants.bj_FORCE_PLAYER = single
    N.GetPlayersAll = function() return all end
    N.GetForceOfPlayer = function(p)
        local f = new_force()
        f.players[p.id] = p
        return f
    end
    N.GetPlayersAllies = function(p)
        local f = new_force()
        N.ForceEnumAllies(f, p, nil)
        f.players[p.id] = p
        return f
    end
    N.GetPlayersEnemies = function(p)
        local f = new_force()
        N.ForceEnumEnemies(f, p, nil)
        return f
    end
    N.GetPlayersMatching = function(filter)
        local f = new_force()
        N.ForceEnumPlayers(f, filter)
        return f
    end
    N.GetPlayersByMapControl = function(control)
        local f = new_force()
        for n = 0, 15 do
            local p = S:player(n)
            if p.controller == control then f.players[n] = p end
        end
        return f
    end
    N.CountPlayersInForceBJ = function(f) return #force_list(f) end
    N.ForceAddPlayerSimple = function(p, f) N.ForceAddPlayer(f, p) end
    N.ForceRemovePlayerSimple = function(p, f) N.ForceRemovePlayer(f, p) end
    N.ForForceBJ = N.ForForce
    N.IsPlayerInForceBJ = function(p, f) return N.IsPlayerInForce(p, f) end
    N.SetForceAllianceStateBJ = function(f1, f2, state)
        for _, a in ipairs(force_list(f1)) do
            for _, b in ipairs(force_list(f2)) do N.SetPlayerAllianceStateBJ(a, b, state) end
        end
    end
    local function from(field) return function() local c = S.ctx return c and c[field] end end
    N.GetEnumPlayer = from("enum_player")
    N.GetFilterPlayer = from("filter_player")
    -- }}}

    -- {{{ Messages: to every player named (a server has no local player)
    S.messages = {}
    function S:text(s)
        if s == nil then return "" end
        s = tostring(s)
        local strings = self.data.strings
        if strings and s:find("TRIGSTR_", 1, true) then
            s = s:gsub("TRIGSTR_%d+", function(k) return strings[k] or k end)
        end
        return s
    end
    function S:message(p, text, seconds)
        if not p then return end
        text = self:text(text)
        seconds = seconds or 10
        local list = self.messages
        list[#list + 1] = { player = p.id, text = text, seconds = seconds, at = self:now() }
        if #list > 200 then table.remove(list, 1) end
        if self.opts.on_message then self.opts.on_message(p, text, seconds) end
    end
    local function to_force(f, text, seconds)
        if not f then return end
        for _, p in ipairs(force_list(f)) do S:message(p, text, seconds) end
    end
    N.DisplayTextToPlayer = function(p, x, y, msg) S:message(p, msg, 10) end
    N.DisplayTimedTextToPlayer = function(p, x, y, t, msg) S:message(p, msg, t) end
    N.DisplayTimedTextFromPlayer = function(p, x, y, t, msg) S:message(p, msg, t) end
    N.DisplayTextToForce = function(f, msg) to_force(f, msg, 10) end
    N.DisplayTimedTextToForce = function(f, t, msg) to_force(f, msg, t) end
    N.QuestMessageBJ = function(f, kind, msg) to_force(f, msg, 20) end
    N.ClearTextMessages = function() end
    -- }}}

    -- {{{ Chat and players' events (raised from outside: S:chat, S:player_event)
    N.TriggerRegisterPlayerChatEvent = function(trig, p, text, exact)
        return S:listen(trig, "EVENT_PLAYER_CHAT", { player = p, text = text or "", exact = exact })
    end
    N.TriggerRegisterPlayerEvent = function(trig, p, event) return S:listen(trig, event, { player = p }) end
    N.TriggerRegisterPlayerEventLeave = function(trig, p) return S:listen(trig, "EVENT_PLAYER_LEAVE", { player = p }) end
    N.TriggerRegisterPlayerEventDefeat = function(trig, p) return S:listen(trig, "EVENT_PLAYER_DEFEAT", { player = p }) end
    N.TriggerRegisterPlayerEventVictory = function(trig, p) return S:listen(trig, "EVENT_PLAYER_VICTORY", { player = p }) end
    N.TriggerRegisterPlayerEventEndCinematic = function(trig, p)
        return S:listen(trig, "EVENT_PLAYER_END_CINEMATIC", { player = p })
    end
    N.GetEventPlayerChatString = function() local c = S.ctx return c and c.chat or "" end
    N.GetEventPlayerChatStringMatched = function() local c = S.ctx return c and c.matched or "" end
    -- a player typed text into chat (as the VM's V:chat)
    function S:chat(player_id, text)
        local p = self:player(player_id)
        text = tostring(text or "")
        self:dispatch("EVENT_PLAYER_CHAT", function(reg)
            if reg.player ~= p then return false end
            if reg.exact then return text == reg.text end
            return reg.text == "" or text:find(reg.text, 1, true) ~= nil
        end, function(reg) return { player = p, chat = text, matched = reg.text } end)
    end
    -- a player event with no more to it than who (EVENT_PLAYER_LEAVE ...)
    function S:player_event(event, player_id)
        local p = self:player(player_id or self.local_id)
        self:dispatch(event, function(reg) return reg.player == p end, function() return { player = p } end)
    end
    -- }}}
end

--[[
JASS natives: the game world (Issue 520)

Players, forces, alliances, locations, rects, regions, units, groups,
orders, heroes and items, on the world the VM was given (jass/vm.lua).
Units are the world's own records; players and the rest are tables made
here.

Order ids are from memory of the game (smart 851971, stop 851972,
attack 851983, move 851986, patrol 851990, holdposition 851993), not
read from its data; issued orders become the world's move / attack /
attack_unit / patrol / stop / hold.
]]

local vm = require("jass.vm")

return function(V, N, T)
    local function typed(kind, names)
        for name in names:gmatch("%S+") do T[name] = kind end
    end
    local function noop(names)
        for name in names:gmatch("%S+") do
            V.noop[name] = true
            N[name] = function() V.noops[name] = (V.noops[name] or 0) + 1 end
        end
    end
    local W = V.world

    -- {{{ Players
    V.players = {}
    function V:player(n)
        n = math.floor(n or 0)
        local p = self.players[n]
        if not p then
            p = self:handle({ kind = "player", id = n, name = "Player " .. (n + 1), color = n,
                              team = n, gold = 0, lumber = 0, food_cap = 0, food_max = 100,
                              controller = n >= 12 and "MAP_CONTROL_NEUTRAL" or "MAP_CONTROL_USER",
                              slot = n < 12 and "PLAYER_SLOT_STATE_PLAYING" or "PLAYER_SLOT_STATE_EMPTY",
                              race = "RACE_HUMAN", ally = {}, vision = {}, tech_max = {}, abilities_off = {},
                              start = n })
            self.players[n] = p
        end
        return p
    end
    -- neutral players and forces' allies start as the world says
    function V:init_world()
        for n = 0, 15 do
            local p = self:player(n)
            for m = 0, 15 do
                if n ~= m and n < 12 and m < 12 and W.team_of and W.team_of(n) == W.team_of(m) then
                    p.ally[m] = true
                end
                -- and forces flagged to share vision share it
                if n ~= m and W.shares_vision and W.shares_vision(n, m) then p.vision[m] = true end
            end
        end
        for _, wp in ipairs(W.players or {}) do
            if wp.name then self:player(wp.number).name = self:text(wp.name) end
        end
        if self.opts.playing then
            for n = 0, 11 do self:player(n).slot = "PLAYER_SLOT_STATE_EMPTY" end
            for _, n in ipairs(self.opts.playing) do self:player(n).slot = "PLAYER_SLOT_STATE_PLAYING" end
        end
        -- the world asks the VM who's allied from now on
        W.allied = function(a, b)
            if a == b then return true end
            local pa = self.players[a]
            return pa ~= nil and pa.ally[b] == true
        end
        -- does a share its sight with b (fog of war: demo/wc3map/vision.lua)
        W.shares_vision = function(a, b)
            if a == b then return true end
            local pa = self.players[a]
            return pa ~= nil and pa.vision[b] == true
        end
        W.script = self
    end

    N.Player = function(n) return V:player(n) end
    N.GetLocalPlayer = function() return V:player(V.local_id) end
    N.GetPlayerId = function(p) return p and p.id or -1 end
    N.GetPlayerName = function(p) return p and p.name or "" end
    N.SetPlayerName = function(p, name) if p then p.name = name end end
    N.GetPlayerSlotState = function(p) return p and p.slot or "PLAYER_SLOT_STATE_EMPTY" end
    N.GetPlayerController = function(p) return p and p.controller end
    N.SetPlayerController = function(p, c) if p then p.controller = c end end
    N.GetPlayerRace = function(p) return p and p.race end
    N.SetPlayerRacePreference = function(p, r)
        if p then p.race = type(r) == "string" and r:gsub("RACE_PREF_", "RACE_") or r end
    end
    N.GetPlayerColor = function(p) return p and p.color or 0 end
    N.SetPlayerColor = function(p, c) if p then p.color = c end end
    N.GetPlayerTeam = function(p) return p and p.team or 0 end
    N.SetPlayerTeam = function(p, t) if p then p.team = t end end
    N.GetPlayerStartLocation = function(p) return p and p.start or 0 end
    N.SetPlayerStartLocation = function(p, n) if p then p.start = n end end
    N.ForcePlayerStartLocation = N.SetPlayerStartLocation
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
    N.IsPlayerObserver = function() return false end
    N.GetPlayerRace = function(p) return p and p.race end
    N.RemovePlayer = function(p, result) if p then p.slot, p.result = "PLAYER_SLOT_STATE_LEFT", result end end
    N.CachePlayerHeroData = function() end
    -- neutral victim (13) and extra (14): allied to everyone, as Blizzard.j sets them
    N.ConfigureNeutralVictim = function()
        local victim = V:player(13)
        for n = 0, 15 do
            if n ~= 13 then victim.ally[n] = true; V:player(n).ally[13] = true end
        end
    end

    -- states: gold, lumber, food
    local STATE = { PLAYER_STATE_RESOURCE_GOLD = "gold", PLAYER_STATE_RESOURCE_LUMBER = "lumber",
                    PLAYER_STATE_RESOURCE_FOOD_CAP = "food_cap", PLAYER_STATE_FOOD_CAP_CEILING = "food_max",
                    PLAYER_STATE_GIVES_BOUNTY = "bounty", PLAYER_STATE_ALLIED_VICTORY = "allied_victory",
                    PLAYER_STATE_OBSERVER = "observer", PLAYER_STATE_RESOURCE_HERO_TOKENS = "hero_tokens" }
    N.GetPlayerState = function(p, s)
        local k = STATE[s] or s
        return p and tonumber(p[k]) or 0
    end
    N.SetPlayerState = function(p, s, v) if p then p[STATE[s] or s] = v end end
    N.GetPlayerStructureCount = function(p, done)
        local n = 0
        for _, u in ipairs(W.units) do
            if u.player == p.id and u.alive and u.spec and u.spec.design == "building" then n = n + 1 end
        end
        return n
    end
    N.GetPlayerUnitCount = function(p, done)
        local n = 0
        for _, u in ipairs(W.units) do
            if u.player == p.id and u.alive then n = n + 1 end
        end
        return n
    end
    N.GetPlayerTypedUnitCount = function(p, name, done, upgrades)
        local n = 0
        for _, u in ipairs(W.units) do
            if u.player == p.id and u.alive and (u.name == name) then n = n + 1 end
        end
        return n
    end
    -- tech limits (training lists aren't driven by the script yet: kept)
    N.SetPlayerTechMaxAllowed = function(p, id, max) if p then p.tech_max[vm.id2s(id)] = max end end
    N.GetPlayerTechMaxAllowed = function(p, id) return p and p.tech_max[vm.id2s(id)] or -1 end
    N.SetPlayerTechResearched = function(p, id, level)
        if p then p.research = p.research or {}; p.research[vm.id2s(id)] = level end
    end
    N.GetPlayerTechCount = function(p, id, specific)
        return p and p.research and p.research[vm.id2s(id)] or 0
    end
    N.SetPlayerAbilityAvailable = function(p, id, avail) if p then p.abilities_off[vm.id2s(id)] = not avail or nil end end
    N.SetPlayerHandicap = function(p, h) if p then p.handicap = h end end
    N.SetPlayerHandicapXP = function(p, h) if p then p.handicap_xp = h end end
    N.SetPlayerOnScoreScreen = function() end
    N.SetPlayerRaceSelectable = function() end
    typed("integer", "GetPlayerId GetPlayerColor GetPlayerTeam GetPlayerStartLocation GetPlayerState GetPlayerStructureCount GetPlayerUnitCount GetPlayerTypedUnitCount GetPlayerTechMaxAllowed GetPlayerTechCount")
    typed("string", "GetPlayerName")
    -- }}}

    -- {{{ Map setup (config())
    V.start_locs = {}
    N.SetMapName = function(s) V.map_name = s end
    N.SetMapDescription = function(s) V.map_description = s end
    N.SetPlayers = function(n) V.player_count = n end
    N.SetTeams = function(n) V.team_count = n end
    N.SetGamePlacement = function() end
    N.DefineStartLocation = function(n, x, y) V.start_locs[n] = { x = x, y = y } end
    N.DefineStartLocationLoc = function(n, l) V.start_locs[n] = { x = l.x, y = l.y } end
    N.SetStartLocPrioCount = function() end
    N.SetStartLocPrio = function() end
    N.GetStartLocationX = function(n) return V.start_locs[n] and V.start_locs[n].x or 0 end
    N.GetStartLocationY = function(n) return V.start_locs[n] and V.start_locs[n].y or 0 end
    N.GetStartLocationLoc = function(n) return N.Location(N.GetStartLocationX(n), N.GetStartLocationY(n)) end
    N.GetPlayers = function() return V.player_count or 12 end
    N.GetTeams = function() return V.team_count or 12 end
    typed("real", "GetStartLocationX GetStartLocationY")
    typed("integer", "GetPlayers GetTeams")
    -- }}}

    -- {{{ Forces
    local function new_force() return V:handle({ kind = "force", players = {} }) end
    N.CreateForce = new_force
    N.DestroyForce = function(f) if f then f.destroyed = true end end
    N.ForceAddPlayer = function(f, p) if f and p then f.players[p.id] = p end end
    N.ForceRemovePlayer = function(f, p) if f and p then f.players[p.id] = nil end end
    N.ForceClear = function(f) if f then f.players = {} end end
    N.IsPlayerInForce = function(p, f) return p ~= nil and f ~= nil and f.players[p.id] ~= nil end
    local function force_list(f)
        local l = {}
        for n = 0, 15 do if f.players[n] then l[#l + 1] = f.players[n] end end
        return l
    end
    V.force_list = force_list
    N.ForForce = function(f, fn)
        if not f or not fn then return end
        for _, p in ipairs(force_list(f)) do V:with({ enum_player = p }, fn) end
    end
    N.ForceEnumPlayers = function(f, filter)
        f.players = {}
        for n = 0, 15 do
            local p = V:player(n)
            if V:test(filter, { filter_player = p }) then f.players[n] = p end
        end
    end
    N.ForceEnumAllies = function(f, who, filter)
        f.players = {}
        for n = 0, 15 do
            local p = V:player(n)
            if N.IsPlayerAlly(who, p) and V:test(filter, { filter_player = p }) then f.players[n] = p end
        end
    end
    N.ForceEnumEnemies = function(f, who, filter)
        f.players = {}
        for n = 0, 15 do
            local p = V:player(n)
            if N.IsPlayerEnemy(who, p) and V:test(filter, { filter_player = p }) then f.players[n] = p end
        end
    end
    -- the Blizzard.j forces InitBlizzard makes
    local all = new_force()
    for n = 0, 15 do all.players[n] = V:player(n) end
    V.constants.bj_FORCE_ALL_PLAYERS = all
    local single = {}
    for n = 0, 15 do
        single[n] = new_force()
        single[n].players[n] = V:player(n)
    end
    V.constants.bj_FORCE_PLAYER = single
    -- }}}

    -- {{{ Locations
    N.Location = function(x, y) return { kind = "location", x = x or 0, y = y or 0 } end
    N.RemoveLocation = function() end
    N.MoveLocation = function(l, x, y) l.x, l.y = x, y end
    N.GetLocationX = function(l) return l and l.x or 0 end
    N.GetLocationY = function(l) return l and l.y or 0 end
    N.GetLocationZ = function(l)
        return l and W.ground_at and W.ground_at(l.x, l.y) or 0
    end
    typed("real", "GetLocationX GetLocationY GetLocationZ")
    -- }}}

    -- {{{ Rects and regions
    N.Rect = function(x0, y0, x1, y1)
        return V:handle({ kind = "rect", minx = math.min(x0, x1), miny = math.min(y0, y1),
                          maxx = math.max(x0, x1), maxy = math.max(y0, y1) })
    end
    N.RectFromLoc = function(a, b) return N.Rect(a.x, a.y, b.x, b.y) end
    N.RemoveRect = function() end
    N.SetRect = function(r, x0, y0, x1, y1)
        r.minx, r.miny, r.maxx, r.maxy = math.min(x0, x1), math.min(y0, y1), math.max(x0, x1), math.max(y0, y1)
    end
    N.MoveRectTo = function(r, x, y)
        local hw, hh = (r.maxx - r.minx) / 2, (r.maxy - r.miny) / 2
        r.minx, r.maxx, r.miny, r.maxy = x - hw, x + hw, y - hh, y + hh
    end
    N.MoveRectToLoc = function(r, l) N.MoveRectTo(r, l.x, l.y) end
    N.GetRectCenterX = function(r) return (r.minx + r.maxx) / 2 end
    N.GetRectCenterY = function(r) return (r.miny + r.maxy) / 2 end
    N.GetRectCenter = function(r) return N.Location(N.GetRectCenterX(r), N.GetRectCenterY(r)) end
    N.GetRectMinX = function(r) return r.minx end
    N.GetRectMinY = function(r) return r.miny end
    N.GetRectMaxX = function(r) return r.maxx end
    N.GetRectMaxY = function(r) return r.maxy end
    N.GetRectWidthBJ = function(r) return r.maxx - r.minx end
    N.GetRectHeightBJ = function(r) return r.maxy - r.miny end
    N.RectContainsCoords = function(r, x, y) return x >= r.minx and x <= r.maxx and y >= r.miny and y <= r.maxy end
    N.RectContainsLoc = function(r, l) return N.RectContainsCoords(r, l.x, l.y) end
    N.RectContainsUnit = function(r, u) return u ~= nil and N.RectContainsCoords(r, u.x, u.y) end
    N.GetRandomLocInRect = function(r)
        return N.Location(r.minx + math.random() * (r.maxx - r.minx), r.miny + math.random() * (r.maxy - r.miny))
    end
    N.RectFromCenterSizeBJ = function(l, w, h)
        return N.Rect(l.x - w / 2, l.y - h / 2, l.x + w / 2, l.y + h / 2)
    end
    N.OffsetRectBJ = function(r, dx, dy) return N.Rect(r.minx + dx, r.miny + dy, r.maxx + dx, r.maxy + dy) end
    N.CreateRegion = function() return V:handle({ kind = "region", rects = {} }) end
    N.RemoveRegion = function() end
    N.RegionAddRect = function(g, r) g.rects[#g.rects + 1] = r end
    N.IsUnitInRegion = function(g, u)
        for _, r in ipairs(g.rects) do if N.RectContainsUnit(r, u) then return true end end
        return false
    end
    -- the map's area: the world's bounds when it has them
    local b = W.bounds or { x0 = -8192, y0 = -8192, x1 = 8192, y1 = 8192 }
    local map_rect = N.Rect(b.x0, b.y0, b.x1, b.y1)
    N.GetWorldBounds = function() return N.Rect(b.x0, b.y0, b.x1, b.y1) end
    N.GetEntireMapRect = N.GetWorldBounds
    N.GetPlayableMapRect = function() return map_rect end
    V.constants.bj_mapInitialPlayableArea = map_rect
    N.GetCameraBoundMinX = function() return b.x0 end
    N.GetCameraBoundMinY = function() return b.y0 end
    N.GetCameraBoundMaxX = function() return b.x1 end
    N.GetCameraBoundMaxY = function() return b.y1 end
    typed("real", "GetRectCenterX GetRectCenterY GetRectMinX GetRectMinY GetRectMaxX GetRectMaxY GetRectWidthBJ GetRectHeightBJ GetCameraBoundMinX GetCameraBoundMinY GetCameraBoundMaxX GetCameraBoundMaxY")
    -- }}}

    -- {{{ Geometry
    N.DistanceBetweenPoints = function(a, b) return math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2) end
    N.AngleBetweenPoints = function(a, b) return math.deg(math.atan2(b.y - a.y, b.x - a.x)) end
    N.PolarProjectionBJ = function(l, dist, angle)
        return N.Location(l.x + dist * math.cos(math.rad(angle)), l.y + dist * math.sin(math.rad(angle)))
    end
    N.OffsetLocation = function(l, dx, dy) return N.Location(l.x + dx, l.y + dy) end
    typed("real", "DistanceBetweenPoints AngleBetweenPoints")
    -- }}}

    -- {{{ Units
    local function alive(u) return u ~= nil and u.alive ~= false and not u.removed end
    local function create(p, id, x, y, facing)
        if not p then return nil end
        local u = W.spawn(vm.id2s(id), p.id, x or 0, y or 0, math.rad(facing or 0))
        if u then
            V:handle(u)
            u.vm_x = nil   -- checked against rects at the next look
        end
        return u
    end
    V.create_unit = create
    N.CreateUnit = create
    N.CreateUnitAtLoc = function(p, id, l, facing) return create(p, id, l.x, l.y, facing) end
    N.CreateUnitByName = function(p, name, x, y, facing) return nil end
    N.CreateCorpse = function(p, id, x, y, facing)
        local u = create(p, id, x, y, facing)
        if u then W.kill(u, nil) end
        return u
    end
    N.RemoveUnit = function(u) if u and not u.removed then W.remove(u) end end
    N.KillUnit = function(u) if alive(u) then W.kill(u, nil) end end
    N.GetUnitTypeId = function(u) return u and vm.s2id(u.id) or 0 end
    N.GetOwningPlayer = function(u) return u and V:player(u.player) end
    N.GetUnitX = function(u) return u and u.x or 0 end
    N.GetUnitY = function(u) return u and u.y or 0 end
    N.GetUnitLoc = function(u) return N.Location(u and u.x or 0, u and u.y or 0) end
    N.GetUnitFacing = function(u) return u and (math.deg(u.facing or 0) % 360) or 0 end
    N.GetUnitName = function(u) return u and (u.name or u.id) or "" end
    N.GetUnitDefaultMoveSpeed = function(u) return u and (u.speed or 270) or 0 end
    N.GetUnitMoveSpeed = function(u) return u and (u.speed or 270) or 0 end
    N.SetUnitMoveSpeed = function(u, s)
        if u then u.speed = s; if u.mover then u.mover.speed = s end end
    end
    local function place(u, x, y)
        if not u then return end
        u.x, u.y = x, y
        if W.ground_at then u.z = W.ground_at(x, y) end
        u.route = nil
        if u.mover then u.mover.x, u.mover.y = x, y end
    end
    N.SetUnitX = function(u, x) place(u, x, u.y) end
    N.SetUnitY = function(u, y) place(u, u.x, y) end
    N.SetUnitPosition = place
    N.SetUnitPositionLoc = function(u, l) place(u, l.x, l.y) end
    N.SetUnitFacing = function(u, f) if u then u.facing = math.rad(f) end end
    N.SetUnitFacingTimed = function(u, f) if u then u.facing = math.rad(f) end end
    N.SetUnitPositionLocFacingBJ = function(u, l, f) place(u, l.x, l.y); N.SetUnitFacing(u, f) end
    -- hit points and mana
    N.GetUnitState = function(u, s)
        if not u then return 0 end
        if s == "UNIT_STATE_LIFE" then return u.alive and u.hp or 0 end
        if s == "UNIT_STATE_MAX_LIFE" then return u.hp_max or 0 end
        if s == "UNIT_STATE_MANA" then return u.mana or 0 end
        if s == "UNIT_STATE_MAX_MANA" then return u.mana_max or 0 end
        return 0
    end
    N.SetUnitState = function(u, s, v)
        if not u then return end
        if s == "UNIT_STATE_LIFE" then
            if not u.alive then return end
            u.hp = math.min(v, u.hp_max or v)
            if u.hp <= 0.405 then W.kill(u, nil) end
        elseif s == "UNIT_STATE_MANA" then
            u.mana = math.max(0, math.min(v, u.mana_max or v))
        end
    end
    N.GetWidgetLife = function(u) return N.GetUnitState(u, "UNIT_STATE_LIFE") end
    N.SetWidgetLife = function(u, v) N.SetUnitState(u, "UNIT_STATE_LIFE", v) end
    N.IsUnitAliveBJ = function(u) return alive(u) end
    N.IsUnitDeadBJ = function(u) return not alive(u) end
    N.UnitAlive = N.IsUnitAliveBJ
    N.SetUnitInvulnerable = function(u, flag) if u then u.invulnerable = flag or nil end end
    N.IsUnitInvulnerable = function(u) return u ~= nil and u.invulnerable == true end
    N.ShowUnit = function(u, show)
        if not u or (not show) == (u.hidden == true) then return end
        u.hidden = not show or nil
        if u.spec and u.spec.design == "building" then W.buildings_changed = true end
    end
    N.IsUnitHidden = function(u) return u ~= nil and u.hidden == true end
    N.PauseUnit = function(u, flag)
        if u then u.paused = flag or nil; if flag then u.route, u.order, u.target = nil, nil, nil end end
    end
    N.IsUnitPaused = function(u) return u ~= nil and u.paused == true end
    N.SetUnitAcquireRange = function(u, r)
        if u then u.acquire_range = r; if u.weapon then u.weapon.acquire = math.max(r, u.weapon.range) end end
    end
    N.GetUnitAcquireRange = function(u) return u and (u.acquire_range or (u.weapon and u.weapon.acquire)) or 0 end
    N.SetUnitUserData = function(u, v) if u then u.user_data = v end end
    N.GetUnitUserData = function(u) return u and u.user_data or 0 end
    N.GetUnitPointValue = function(u) return u and u.point_value or 0 end
    N.GetUnitFoodUsed = function(u) return u and u.food or 0 end
    N.GetUnitFoodMade = function(u) return u and u.food_made or 0 end
    N.GetUnitLevel = function(u) return u and (u.level or 1) or 0 end
    N.GetUnitRace = function(u) return u and u.spec and u.spec.race end
    N.SetUnitColor = function(u, c) if u then u.color = c end end
    -- change of owner: the unit changes colour with it (as WC3's
    -- changeColor=true), and fires its events for both players
    N.SetUnitOwner = function(u, p, change_color)
        if not u or not p or u.player == p.id then return end
        local prev = V:player(u.player)
        u.player = p.id
        if u.spec and change_color ~= false then
            local s = {}
            for k, v in pairs(u.spec) do s[k] = v end
            s.team = p.id
            u.spec = s
        end
        u.target, u.order, u.route = nil, nil, nil
        if W.on_owner_change then W.on_owner_change(u, prev.id) end
        V:unit_event("CHANGE_OWNER", u, { prev_owner = prev, also_player = prev })
    end
    -- unit types
    local TYPE_TEST = {
        UNIT_TYPE_HERO = function(u) return u.spec and u.spec.hero end,
        UNIT_TYPE_STRUCTURE = function(u) return u.spec and u.spec.design == "building" end,
        UNIT_TYPE_DEAD = function(u) return not alive(u) end,
        UNIT_TYPE_FLYING = function(u) return u.spec and u.spec.archetype == "flyer" end,
        UNIT_TYPE_GROUND = function(u) return not (u.spec and u.spec.archetype == "flyer") end,
        UNIT_TYPE_MECHANICAL = function(u) return u.spec and (u.spec.archetype == "siege" or u.spec.archetype == "ship") end,
        UNIT_TYPE_PEON = function(u) return u.spec and u.spec.archetype == "worker" end,
        UNIT_TYPE_MELEE_ATTACKER = function(u) return u.weapon and u.weapon.missile == 0 end,
        UNIT_TYPE_RANGED_ATTACKER = function(u) return u.weapon and u.weapon.missile > 0 end,
        UNIT_TYPE_TOWNHALL = function(u) return u.spec and u.spec.size == "hall" end,
        UNIT_TYPE_SUMMONED = function(u) return u.summoned end,
    }
    N.IsUnitType = function(u, t)
        local f = u and TYPE_TEST[t]
        return f ~= nil and f(u) and true or false
    end
    N.IsUnitOwnedByPlayer = function(u, p) return u ~= nil and p ~= nil and u.player == p.id end
    N.IsUnitAlly = function(u, p) return u ~= nil and N.IsPlayerAlly(V:player(u.player), p) end
    N.IsUnitEnemy = function(u, p) return u ~= nil and N.IsPlayerEnemy(p, V:player(u.player)) end
    N.IsUnit = function(a, b) return a == b end
    N.IsUnitInRange = function(a, b, d) return a and b and (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 <= d * d end
    N.IsUnitInRangeXY = function(a, x, y, d) return a and (a.x - x) ^ 2 + (a.y - y) ^ 2 <= d * d end
    N.IsUnitInRangeLoc = function(a, l, d) return N.IsUnitInRangeXY(a, l.x, l.y, d) end
    N.IsUnitIdType = function(id, t) return false end
    N.UnitApplyTimedLife = function(u, buff, seconds)
        if not u then return end
        local t = V:new_timer()
        t.internal = true
        V:start_timer(t, seconds, false, nil)
        t.on_expire = function() if alive(u) then W.kill(u, nil) end end
    end
    N.UnitApplyTimedLifeBJ = function(seconds, buff, u) N.UnitApplyTimedLife(u, buff, seconds) end
    N.SetUnitExploded = function(u, flag) if u then u.exploded = flag end end
    -- abilities (kept on the unit; the command card doesn't read them yet)
    N.UnitAddAbility = function(u, id)
        if not u then return false end
        u.abilities = u.abilities or {}
        local k = vm.id2s(id)
        if u.abilities[k] then return false end
        u.abilities[k] = 1
        return true
    end
    N.UnitRemoveAbility = function(u, id)
        if not u or not u.abilities or not u.abilities[vm.id2s(id)] then return false end
        u.abilities[vm.id2s(id)] = nil
        return true
    end
    N.GetUnitAbilityLevel = function(u, id) return u and u.abilities and u.abilities[vm.id2s(id)] or 0 end
    N.SetUnitAbilityLevel = function(u, id, lvl)
        if u then u.abilities = u.abilities or {}; u.abilities[vm.id2s(id)] = lvl end
        return lvl
    end
    N.UnitMakeAbilityPermanent = function() return true end
    typed("integer", "GetUnitTypeId GetUnitUserData GetUnitPointValue GetUnitFoodUsed GetUnitFoodMade GetUnitLevel GetUnitAbilityLevel SetUnitAbilityLevel")
    typed("real", "GetUnitX GetUnitY GetUnitFacing GetUnitState GetWidgetLife GetUnitMoveSpeed GetUnitDefaultMoveSpeed GetUnitAcquireRange")
    typed("string", "GetUnitName UnitId2String")
    typed("integer", "UnitId")
    -- }}}

    -- {{{ Heroes
    N.GetHeroLevel = function(u) return u and (u.level or 1) or 0 end
    N.SetHeroLevel = function(u, lvl, show)
        if not u then return end
        local was = u.level or 1
        u.level = lvl
        if lvl > was then V:unit_event("HERO_LEVEL", u) end
    end
    N.UnitStripHeroLevel = function(u, n) if u then u.level = math.max(1, (u.level or 1) - n) end end
    N.GetHeroXP = function(u) return u and u.xp or 0 end
    N.SetHeroXP = function(u, xp) if u then u.xp = xp end end
    N.AddHeroXP = function(u, xp) if u then u.xp = (u.xp or 0) + xp end end
    N.GetHeroStr = function(u) return u and u.str or 0 end
    N.GetHeroAgi = function(u) return u and u.agi or 0 end
    N.GetHeroInt = function(u) return u and u.int or 0 end
    N.SetHeroStr = function(u, v) if u then u.str = v end end
    N.SetHeroAgi = function(u, v) if u then u.agi = v end end
    N.SetHeroInt = function(u, v) if u then u.int = v end end
    N.GetHeroProperName = function(u) return u and (u.proper_name or u.name or "") or "" end
    N.GetHeroSkillPoints = function(u) return u and u.skill_points or 0 end
    N.UnitModifySkillPoints = function(u, n) if u then u.skill_points = (u.skill_points or 0) + n end return true end
    N.SelectHeroSkill = function(u, id)
        if u then u.skills = u.skills or {}; local k = vm.id2s(id) u.skills[k] = (u.skills[k] or 0) + 1 end
    end
    N.SuspendHeroXP = function(u, flag) if u then u.xp_suspended = flag end end
    N.ReviveHero = function(u, x, y, fx)
        if not u or alive(u) or u.removed then return false end
        u.alive, u.hp, u.died_at = true, u.hp_max or 100, nil
        u.mana = u.mana_max
        place(u, x, y)
        if W.on_revive then W.on_revive(u) end
        return true
    end
    N.ReviveHeroLoc = function(u, l, fx) return N.ReviveHero(u, l.x, l.y, fx) end
    typed("integer", "GetHeroLevel GetHeroXP GetHeroStr GetHeroAgi GetHeroInt GetHeroSkillPoints")
    typed("string", "GetHeroProperName")
    -- }}}

    -- {{{ Orders
    local ORDER = { smart = 851971, stop = 851972, attack = 851983, move = 851986, patrol = 851990,
                    holdposition = 851993, attackground = 851984 }
    local ORDER_NAME = {}
    for k, v in pairs(ORDER) do ORDER_NAME[v] = k end
    N.OrderId = function(s) return ORDER[s] or 0 end
    N.OrderId2String = function(n) return ORDER_NAME[n] or "" end
    N.GetUnitCurrentOrder = function(u)
        local o = u and u.order
        if not o then return 0 end
        return ORDER[({ move = "move", attack = "attack", attack_unit = "attack", patrol = "patrol", hold = "holdposition" })[o.kind] or ""] or 0
    end
    local function point_order(u, name, x, y)
        if not alive(u) or u.paused then return false end
        name = type(name) == "number" and ORDER_NAME[name] or name
        local kind = ({ move = "move", smart = "move", attack = "attack", patrol = "patrol", attackground = "attack" })[name]
        if not kind then return false end
        W.order({ u }, kind, x, y)
        return true
    end
    local function target_order(u, name, t)
        if not alive(u) or not t or u.paused then return false end
        name = type(name) == "number" and ORDER_NAME[name] or name
        if name == "attack" or (name == "smart" and W.allied and not W.allied(u.player, t.player)) then
            W.order({ u }, "attack_unit", nil, nil, t)
        elseif name == "move" or name == "smart" then
            W.order({ u }, "move", t.x, t.y)
        else
            return false
        end
        return true
    end
    local function immediate_order(u, name)
        if not alive(u) then return false end
        name = type(name) == "number" and ORDER_NAME[name] or name
        if name == "stop" then W.order({ u }, "stop")
        elseif name == "holdposition" then W.order({ u }, "hold")
        else return false end
        return true
    end
    N.IssuePointOrder = point_order
    N.IssuePointOrderById = point_order
    N.IssuePointOrderLoc = function(u, name, l) return point_order(u, name, l.x, l.y) end
    N.IssuePointOrderByIdLoc = N.IssuePointOrderLoc
    N.IssueTargetOrder = target_order
    N.IssueTargetOrderById = target_order
    N.IssueImmediateOrder = immediate_order
    N.IssueImmediateOrderById = immediate_order
    typed("integer", "OrderId GetUnitCurrentOrder")
    typed("string", "OrderId2String")
    -- }}}

    -- {{{ Groups
    local function new_group() return V:handle({ kind = "group", list = {}, set = {} }) end
    V.new_group = new_group
    local function add(g, u)
        if g and u and not g.set[u] then g.set[u] = true; g.list[#g.list + 1] = u end
    end
    V.group_add = add
    local function clean(g)
        -- removed units leave groups (as WC3's do, lazily)
        local l = {}
        for _, u in ipairs(g.list) do
            if u.removed then g.set[u] = nil else l[#l + 1] = u end
        end
        g.list = l
        return l
    end
    V.group_units = clean
    N.CreateGroup = new_group
    N.DestroyGroup = function(g) if g then g.destroyed = true; g.list, g.set = {}, {} end end
    N.GroupAddUnit = add
    N.GroupRemoveUnit = function(g, u)
        if not g or not u or not g.set[u] then return end
        g.set[u] = nil
        for k, v in ipairs(g.list) do if v == u then table.remove(g.list, k) break end end
    end
    N.GroupClear = function(g) if g then g.list, g.set = {}, {} end end
    N.IsUnitInGroup = function(u, g) return g ~= nil and u ~= nil and g.set[u] == true end
    N.FirstOfGroup = function(g) return g and clean(g)[1] end
    N.ForGroup = function(g, fn)
        if not g or not fn then return end
        local copy = {}
        for k, u in ipairs(clean(g)) do copy[k] = u end
        for _, u in ipairs(copy) do V:with({ enum_unit = u }, fn) end
    end
    N.CountUnitsInGroup = function(g) return g and #clean(g) or 0 end
    N.GroupAddGroup = function(src, dst) if src and dst then for _, u in ipairs(clean(src)) do add(dst, u) end end end
    N.GroupRemoveGroup = function(src, dst)
        if src and dst then for _, u in ipairs(clean(src)) do N.GroupRemoveUnit(dst, u) end end
    end
    N.GroupPickRandomUnit = function(g)
        local l = g and clean(g) or {}
        return #l > 0 and l[math.random(#l)] or nil
    end
    N.IsUnitGroupEmptyBJ = function(g) return g == nil or #clean(g) == 0 end
    -- enumeration: living and dead units the world still has (not
    -- removed), tested with the filter as GetFilterUnit
    local function enum_into(g, filter, test)
        if not g then return end
        g.list, g.set = {}, {}
        for _, u in ipairs(W.units) do
            if not u.removed and test(u) and V:test(filter, { filter_unit = u }) then add(g, u) end
        end
    end
    V.enum_into = enum_into
    N.GroupEnumUnitsInRect = function(g, r, filter)
        enum_into(g, filter, function(u) return N.RectContainsCoords(r, u.x, u.y) end)
    end
    N.GroupEnumUnitsInRange = function(g, x, y, d, filter)
        enum_into(g, filter, function(u) return (u.x - x) ^ 2 + (u.y - y) ^ 2 <= d * d end)
    end
    N.GroupEnumUnitsInRangeOfLoc = function(g, l, d, filter) N.GroupEnumUnitsInRange(g, l.x, l.y, d, filter) end
    N.GroupEnumUnitsOfPlayer = function(g, p, filter)
        enum_into(g, filter, function(u) return u.player == p.id end)
    end
    -- by type name: WC3's names come from its unit data, which we don't
    -- have; UnitId2String gives the id itself back, so the usual round
    -- trip (GroupEnumUnitsOfType(g, UnitId2String(id), f)) finds the type
    N.UnitId2String = function(id) return vm.id2s(id) end
    N.UnitId = function(name) return #(name or "") == 4 and vm.s2id(name) or 0 end
    N.GroupEnumUnitsOfType = function(g, name, filter)
        enum_into(g, filter, function(u) return u.id == name or u.name == name end)
    end
    N.GroupEnumUnitsSelected = function(g, p, filter)
        enum_into(g, filter, function(u) return u.selected end)
    end
    -- group orders
    local function each_order(g, fn)
        if not g then return false end
        local any = false
        for _, u in ipairs(clean(g)) do any = fn(u) or any end
        return any
    end
    N.GroupPointOrder = function(g, name, x, y) return each_order(g, function(u) return point_order(u, name, x, y) end) end
    N.GroupPointOrderById = N.GroupPointOrder
    N.GroupPointOrderLoc = function(g, name, l) return N.GroupPointOrder(g, name, l.x, l.y) end
    N.GroupPointOrderByIdLoc = N.GroupPointOrderLoc
    N.GroupTargetOrder = function(g, name, t) return each_order(g, function(u) return target_order(u, name, t) end) end
    N.GroupTargetOrderById = N.GroupTargetOrder
    N.GroupImmediateOrder = function(g, name) return each_order(g, function(u) return immediate_order(u, name) end) end
    N.GroupImmediateOrderById = N.GroupImmediateOrder
    typed("integer", "CountUnitsInGroup")
    -- }}}

    -- {{{ Items (carried in six slots; ground items are records only)
    local function new_item(id, x, y)
        local it = V:handle({ kind = "item", id = vm.id2s(id), x = x or 0, y = y or 0, charges = 0 })
        V.items = V.items or {}
        V.items[#V.items + 1] = it
        return it
    end
    N.CreateItem = new_item
    N.CreateItemLoc = function(id, l) return new_item(id, l.x, l.y) end
    N.RemoveItem = function(it)
        if not it then return end
        it.removed = true
        if it.owner then N.UnitRemoveItem(it.owner, it) end
    end
    N.GetItemTypeId = function(it) return it and vm.s2id(it.id) or 0 end
    N.GetItemX = function(it) return it and it.x or 0 end
    N.GetItemY = function(it) return it and it.y or 0 end
    N.SetItemPosition = function(it, x, y) if it then it.x, it.y = x, y end end
    N.SetItemVisible = function(it, show) if it then it.hidden = not show end end
    N.IsItemVisible = function(it) return it ~= nil and not it.hidden end
    N.GetItemCharges = function(it) return it and it.charges or 0 end
    N.SetItemCharges = function(it, n) if it then it.charges = n end end
    N.SetItemPlayer = function(it, p) if it then it.player = p and p.id end end
    N.SetItemUserData = function(it, v) if it then it.user_data = v end end
    N.GetItemUserData = function(it) return it and it.user_data or 0 end
    N.GetItemName = function(it) return it and it.id or "" end
    local function slots(u) u.items = u.items or {} return u.items end
    N.UnitAddItem = function(u, it)
        if not u or not it then return false end
        local s = slots(u)
        for k = 0, 5 do
            if not s[k] then s[k], it.owner = it, u; return true end
        end
        return false
    end
    N.UnitAddItemById = function(u, id)
        local it = new_item(id, u and u.x, u and u.y)
        if not N.UnitAddItem(u, it) then return it end
        return it
    end
    N.UnitAddItemToSlotById = function(u, id, slot)
        if not u then return false end
        local s = slots(u)
        if s[slot] then return false end
        local it = new_item(id, u.x, u.y)
        s[slot], it.owner = it, u
        return true
    end
    N.UnitItemInSlot = function(u, slot) return u and u.items and u.items[slot] end
    N.UnitRemoveItem = function(u, it)
        if not u or not u.items then return end
        for k = 0, 5 do
            if u.items[k] == it then
                u.items[k], it.owner = nil, nil
                it.x, it.y = u.x, u.y
            end
        end
    end
    N.UnitRemoveItemFromSlot = function(u, slot)
        local it = u and u.items and u.items[slot]
        if it then N.UnitRemoveItem(u, it) end
        return it
    end
    N.UnitHasItem = function(u, it) return it ~= nil and it.owner == u end
    N.UnitInventorySize = function(u) return 6 end
    N.UnitDropItemPoint = function(u, it, x, y)
        N.UnitRemoveItem(u, it)
        if it then it.x, it.y = x, y end
        return true
    end
    N.UnitDropItemSlot = function() return false end
    N.UnitUseItem = function() return false end
    typed("integer", "GetItemTypeId GetItemCharges GetItemUserData UnitInventorySize")
    typed("real", "GetItemX GetItemY")
    typed("string", "GetItemName")
    -- }}}

    -- {{{ Destructables (the map's doodads aren't handles yet: none exist)
    N.EnumDestructablesInRect = function() end
    N.CreateDestructable = function(id, x, y, facing, scale, variation)
        return V:handle({ kind = "destructable", id = vm.id2s(id), x = x, y = y, life = 100 })
    end
    N.CreateDestructableZ = function(id, x, y, z, facing, scale, variation)
        return N.CreateDestructable(id, x, y, facing, scale, variation)
    end
    N.RemoveDestructable = function(d) if d then d.removed = true end end
    N.KillDestructable = function(d) if d then d.life = 0 end end
    N.GetDestructableTypeId = function(d) return d and vm.s2id(d.id) or 0 end
    N.GetDestructableX = function(d) return d and d.x or 0 end
    N.GetDestructableY = function(d) return d and d.y or 0 end
    N.GetDestructableLife = function(d) return d and d.life or 0 end
    N.SetDestructableLife = function(d, v) if d then d.life = v end end
    N.SetDestructableInvulnerable = function(d, f) if d then d.invulnerable = f end end
    N.DestructableRestoreLife = function(d, v) if d then d.life = v end end
    N.ModifyGateBJ = function() end
    typed("integer", "GetDestructableTypeId")
    typed("real", "GetDestructableX GetDestructableY GetDestructableLife")
    -- }}}

    -- {{{ Waygates (kept on the unit; the world doesn't teleport yet)
    N.WaygateSetDestination = function(u, x, y) if u then u.waygate = { x = x, y = y, active = u.waygate and u.waygate.active } end end
    N.WaygateActivate = function(u, on) if u then u.waygate = u.waygate or {}; u.waygate.active = on end end
    N.WaygateIsActive = function(u) return u ~= nil and u.waygate ~= nil and u.waygate.active == true end
    N.WaygateGetDestinationX = function(u) return u and u.waygate and u.waygate.x or 0 end
    N.WaygateGetDestinationY = function(u) return u and u.waygate and u.waygate.y or 0 end
    typed("real", "WaygateGetDestinationX WaygateGetDestinationY")
    -- }}}

    noop("SetUnitAnimation SetUnitAnimationByIndex SetUnitAnimationWithRarity QueueUnitAnimation ResetUnitAnimation "
      .. "SetUnitScale SetUnitTimeScale SetUnitVertexColor SetUnitBlendTime SetUnitFlyHeight SetUnitTurnSpeed "
      .. "SetUnitPropWindow AddUnitAnimationProperties SetUnitLookAt ResetUnitLookAt UnitShareVision "
      .. "SetUnitPathing SetUnitCreepGuard SetUnitRescuable SetUnitRescueRange UnitSuspendDecay "
      .. "UnitAddSleep UnitAddSleepPerm UnitIgnoreAlarm UnitWakeUp SetUnitUseFood UnitSetUsesAltIcon "
      .. "SelectUnit ClearSelection SetUnitMoveSpeedBJ UnitAddType UnitRemoveType UnitResetCooldown "
      .. "SetResourceAmount AddResourceAmount SetUnitPathingBJ UnitSetConstructionProgress "
      .. "UnitSetUpgradeProgress UnitPauseTimedLife SetAllItemTypeSlots SetAllUnitTypeSlots SetItemTypeSlots "
      .. "SetUnitTypeSlots AddItemToAllStock AddUnitToAllStock AddItemToStock AddUnitToStock "
      .. "RemoveItemFromAllStock RemoveUnitFromAllStock RemoveItemFromStock RemoveUnitFromStock "
      .. "SetItemDropOnDeath SetItemDroppable SetItemPawnable SetItemInvulnerable SetDestructableAnimation "
      .. "SetDestructableAnimationSpeed ShowDestructable SetDoodadAnimation SetDoodadAnimationRect "
      .. "RecycleGuardPosition SetUnitBlendTime")
end

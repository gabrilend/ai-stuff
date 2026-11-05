--[[
wc3shim natives that touch the world (issue W02e)

Licence: GNU AGPL v3 (server-side/LICENSE).

Players' resources, units made at a point, locations, rects, regions and
units entering and leaving them. Each does what the project's own
runtime's native of the same name does (src/jass/natives/world.lua,
core.lua, bj.lua), with the server's creatures standing in for the VM's
unit records.

Where the server forces a difference:

- Units are creatures. CreateUnit spawns the creature template W02b
  wrote for the type and its owner's faction (map-data.lua's templates);
  a type placed only for another owner takes that template and the
  owner's faction; a type with no template at all can't be made, and the
  unit is a "ghost" (a handle with a position, no creature), counted in
  S.unspawnable.
- WC3 places a map's units from its own main(); the server has already
  spawned them from W02b's server/world.sql. So while main() first runs,
  CreateUnit adopts the spawn of the same type and owner standing where
  it asks (within ADOPT_RANGE), instead of making a second one.
- Positions are read back from the creature, through the inverse of
  map.lua's transform, so GetUnitX answers in WC3 units.
- Players' gold, lumber and the rest live here, per WC3 player slot: a
  WC3 player isn't a WoW character, and lumber has no WoW counterpart.
  opts.on_player_state hears each change (W02g's resource bar).
- Ground height comes from the server's map (Map:GetHeight). Where it has
  none (before W02d writes the map's .map files) a creature stands at
  z = 0, counted in S.counts.no_ground.

Installed by init.lua: require("wc3shim.world")(S, N, shim).
]]

return function(S, N, shim)
    local ale, data = S.ale, S.data
    local ADOPT_RANGE = 1.0      -- WC3 units: main() writes positions to 0.1
    local function set(name, value) rawset(S.env, name, value) return value end
    local function get(name) return rawget(S.env, name) end

    -- {{{ The map: id and the WC3 -> WoW transform (map.lua's wc3_to_wow)
    local map_id = data.map and data.map.id or 0
    local instance = data.map and data.map.instance or 0
    local T = data.wc3_to_wow or { scale = 1 / 30.72, x0 = 0, y0 = 0 }
    local scale, x0, y0 = T.scale, T.x0, T.y0
    function S.to_wow(x, y) return x0 + scale * y, y0 - scale * x end
    function S.to_wc3(X, Y) return (y0 - Y) / scale, (X - x0) / scale end
    -- WC3 facing (degrees, 0 east, counter-clockwise) <-> WoW orientation
    -- (radians, 0 north): as wowbuild.placements.orientation
    local TWO_PI = 2 * math.pi
    function S.to_orientation(deg) return (math.rad(deg or 0) - math.pi / 2) % TWO_PI end
    function S.to_facing(o) return math.deg((o or 0) + math.pi / 2) % 360 end
    local the_map
    local function map()
        if the_map == nil then the_map = ale.GetMapById(map_id, instance) or false end
        return the_map or nil
    end
    -- }}}

    -- {{{ Templates and factions (W02b's, through map-data.lua)
    local faction_of = {}      -- WC3 player -> faction template
    for _, f in ipairs(data.factions or {}) do
        for _, p in ipairs(f.players or {}) do faction_of[p] = f.template end
    end
    local entries = {}         -- type id -> { [faction] = entry, first = entry }
    for _, t in ipairs(data.templates or {}) do
        local e = entries[t.id]
        if not e then e = {}; entries[t.id] = e end
        e[t.faction] = t.entry
        e.first = e.first or t.entry
        e.first_faction = e.first_faction or t.faction
    end
    local spawns = {}          -- "id@player" -> { spawn, ... } not yet adopted
    for _, s in ipairs(data.spawns or {}) do
        local key = s.id .. "@" .. tostring(s.player)
        spawns[key] = spawns[key] or {}
        table.insert(spawns[key], s)
    end
    S.faction_of = faction_of
    -- }}}

    -- {{{ Players
    S.players = {}
    function S:player(n)
        n = math.floor(n or 0)
        local p = self.players[n]
        if not p then
            p = self:handle({ kind = "player", id = n, name = "Player " .. (n + 1), gold = 0, lumber = 0, food_cap = 0 })
            self.players[n] = p
        end
        return p
    end
    N.Player = function(n) return S:player(n) end
    N.GetLocalPlayer = function() return S:player(S.local_id) end
    N.GetPlayerId = function(p) return p and p.id or -1 end
    N.ConvertedPlayer = function(n) return S:player(n - 1) end
    N.GetConvertedPlayerId = function(p) return p and p.id + 1 or 0 end

    local STATE = { PLAYER_STATE_RESOURCE_GOLD = "gold", PLAYER_STATE_RESOURCE_LUMBER = "lumber",
                    PLAYER_STATE_RESOURCE_FOOD_CAP = "food_cap", PLAYER_STATE_FOOD_CAP_CEILING = "food_max",
                    PLAYER_STATE_GIVES_BOUNTY = "bounty", PLAYER_STATE_ALLIED_VICTORY = "allied_victory",
                    PLAYER_STATE_OBSERVER = "observer", PLAYER_STATE_RESOURCE_HERO_TOKENS = "hero_tokens",
                    PLAYER_STATE_GOLD_GATHERED = "gold_gathered", PLAYER_STATE_LUMBER_GATHERED = "lumber_gathered",
                    PLAYER_STATE_NO_CREEP_SLEEP = "no_creep_sleep", PLAYER_STATE_PLACED = "placed" }
    -- the VM works these out from its game; the shim has no economy yet,
    -- and answers as the VM does on a world without one
    local COMPUTED = {
        PLAYER_STATE_RESOURCE_FOOD_USED = function() return 0 end,
        PLAYER_STATE_FOOD_CAP_CEILING = function(p) return tonumber(p.food_max) or 100 end,
        PLAYER_STATE_GOLD_UPKEEP_RATE = function() return 0 end,
        PLAYER_STATE_LUMBER_UPKEEP_RATE = function() return 0 end,
    }
    N.GetPlayerState = function(p, s)
        if not p then return 0 end
        if COMPUTED[s] then return COMPUTED[s](p) end
        return tonumber(p[STATE[s] or s]) or 0
    end
    N.SetPlayerState = function(p, s, v)
        if not p then return end
        if s == "PLAYER_STATE_RESOURCE_FOOD_USED" then return end
        local k = STATE[s] or s
        local was = p[k]
        p[k] = v
        if was ~= v then
            if S.opts.on_player_state then S.opts.on_player_state(p, k, v) end
            S:player_state_changed(p)
        end
    end
    N.SetPlayerStateBJ = function(p, s, v)
        if s == "PLAYER_STATE_RESOURCE_GOLD" or s == "PLAYER_STATE_RESOURCE_LUMBER" then
            -- counted where GetPlayerState(p, PLAYER_STATE_GOLD_GATHERED) reads it
            local k = s == "PLAYER_STATE_RESOURCE_GOLD" and "gold_gathered" or "lumber_gathered"
            p[k] = (p[k] or 0) + math.max(0, v - N.GetPlayerState(p, s))
        end
        N.SetPlayerState(p, s, v)
    end
    N.AdjustPlayerStateBJ = function(delta, p, s) N.SetPlayerStateBJ(p, s, N.GetPlayerState(p, s) + delta) end
    N.AdjustPlayerStateSimpleBJ = function(p, s, delta) N.SetPlayerState(p, s, N.GetPlayerState(p, s) + delta) end

    -- TriggerRegisterPlayerStateEvent(trig, p, state, limitop, limit): fires
    -- when the comparison turns true, as the VM's player_state_changed
    local COMPARE = {
        LESS_THAN = function(a, b) return a < b end, LESS_THAN_OR_EQUAL = function(a, b) return a <= b end,
        EQUAL = function(a, b) return a == b end, GREATER_THAN_OR_EQUAL = function(a, b) return a >= b end,
        GREATER_THAN = function(a, b) return a > b end, NOT_EQUAL = function(a, b) return a ~= b end,
    }
    local LIMITOP = { [0] = "LESS_THAN", "LESS_THAN_OR_EQUAL", "EQUAL", "GREATER_THAN_OR_EQUAL", "GREATER_THAN", "NOT_EQUAL" }
    N.TriggerRegisterPlayerStateEvent = function(trig, ...)
        return S:listen(trig, "PLAYER_STATE", { args = { ... } })
    end
    function S:player_state_changed(p)
        local list = self.listeners.PLAYER_STATE
        if not list then return end
        for _, reg in ipairs(list) do
            local a = reg.args or {}
            if a[1] == p then
                local cmp = COMPARE[LIMITOP[a[3]] or (tostring(a[3]):gsub("^LIMIT_OP_", ""))] or COMPARE.EQUAL
                local now = cmp(N.GetPlayerState(p, a[2]) or 0, tonumber(a[4]) or 0)
                if now and not reg.was_true then
                    self:fire_trigger(reg.trig, { player = p, event = "PLAYER_STATE" })
                end
                reg.was_true = now
            end
        end
    end
    -- }}}

    -- {{{ Locations
    N.Location = function(x, y) return { kind = "location", x = x or 0, y = y or 0 } end
    N.RemoveLocation = function() end
    N.MoveLocation = function(l, x, y) l.x, l.y = x, y end
    N.GetLocationX = function(l) return l and l.x or 0 end
    N.GetLocationY = function(l) return l and l.y or 0 end
    -- }}}

    -- {{{ Rects and regions
    N.Rect = function(xa, ya, xb, yb)
        return S:handle({ kind = "rect", minx = math.min(xa, xb), miny = math.min(ya, yb),
                          maxx = math.max(xa, xb), maxy = math.max(ya, yb) })
    end
    N.RectFromLoc = function(a, b) return N.Rect(a.x, a.y, b.x, b.y) end
    N.RemoveRect = function() end
    N.SetRect = function(r, xa, ya, xb, yb)
        r.minx, r.miny, r.maxx, r.maxy = math.min(xa, xb), math.min(ya, yb), math.max(xa, xb), math.max(ya, yb)
    end
    N.MoveRectTo = function(r, x, y)
        local hw, hh = (r.maxx - r.minx) / 2, (r.maxy - r.miny) / 2
        r.minx, r.maxx, r.miny, r.maxy = x - hw, x + hw, y - hh, y + hh
    end
    N.GetRectCenterX = function(r) return (r.minx + r.maxx) / 2 end
    N.GetRectCenterY = function(r) return (r.miny + r.maxy) / 2 end
    N.GetRectCenter = function(r) return N.Location(N.GetRectCenterX(r), N.GetRectCenterY(r)) end
    N.GetRectMinX = function(r) return r.minx end
    N.GetRectMinY = function(r) return r.miny end
    N.GetRectMaxX = function(r) return r.maxx end
    N.GetRectMaxY = function(r) return r.maxy end
    N.RectContainsCoords = function(r, x, y) return x >= r.minx and x <= r.maxx and y >= r.miny and y <= r.maxy end
    N.CreateRegion = function() return S:handle({ kind = "region", rects = {} }) end
    N.RemoveRegion = function() end
    N.RegionAddRect = function(g, r) g.rects[#g.rects + 1] = r end
    -- }}}

    -- {{{ Units
    -- a unit: { kind = "unit", id = "hfoo", player = n, creature = ALE's (nil for a ghost),
    --           entry, guid, x, y (WC3 units, as last read), facing (radians, WC3's), alive }
    local function sync(u)
        if u.creature and not u.removed then
            local c = u.creature
            local X, Y = c:GetX(), c:GetY()
            -- read back only when it moved, so a unit standing where it
            -- was put keeps its WC3 point exactly (no round trip)
            if X and Y and (X ~= u.wow_x or Y ~= u.wow_y) then
                u.x, u.y = S.to_wc3(X, Y)
                u.wow_x, u.wow_y = X, Y
            end
            local o = c:GetO()
            if o then u.facing = math.rad(S.to_facing(o)) end
            u.alive = c:IsAlive() and true or false
        end
        return u
    end
    S.sync = sync

    local function adopt(id, p, x, y)
        local list = spawns[id .. "@" .. tostring(p.id)]
        if not list then return nil end
        for k, s in ipairs(list) do
            if math.abs(s.x - x) <= ADOPT_RANGE and math.abs(s.y - y) <= ADOPT_RANGE then
                table.remove(list, k)
                return s
            end
        end
    end

    local function ground(X, Y)
        local m = map()
        local z = m and m:GetHeight(X, Y)
        if type(z) ~= "number" or z < shim.INVALID_HEIGHT then
            S.counts.no_ground = S.counts.no_ground + 1
            return 0
        end
        return z
    end

    local function create(p, id, x, y, facing)
        if not p then return nil end
        id = shim.id2s(id)
        x, y, facing = x or 0, y or 0, facing or 0
        local u = S:handle({ kind = "unit", id = id, player = p.id, x = x, y = y, facing = math.rad(facing), alive = true })
        local faction = faction_of[p.id]
        local s = S.adopting and adopt(id, p, x, y)
        if s then
            u.entry, u.guid, u.adopted = s.entry, s.guid, true
            local m = map()
            u.creature = m and m:GetWorldObject(ale.GetUnitGUID(s.guid, s.entry)) or nil
            if u.creature then u.wow_x, u.wow_y = u.creature:GetX(), u.creature:GetY() end
            S.counts.adopted = S.counts.adopted + 1
        else
            local e = entries[id]
            local entry = e and (e[faction] or e.first)
            if not entry then
                S.unspawnable[id] = (S.unspawnable[id] or 0) + 1
                S.counts.ghosts = S.counts.ghosts + 1
            else
                local X, Y = S.to_wow(x, y)
                u.wow_x, u.wow_y = X, Y
                local c = ale.PerformIngameSpawn(1, entry, map_id, instance, X, Y, ground(X, Y),
                                                 S.to_orientation(facing), false, 0)
                if c then
                    if faction and not e[faction] then c:SetFaction(faction) end
                    u.creature, u.entry, u.guid = c, entry, c:GetGUIDLow()
                    S.counts.spawned = S.counts.spawned + 1
                else
                    S.unspawnable[id] = (S.unspawnable[id] or 0) + 1
                    S.counts.ghosts = S.counts.ghosts + 1
                end
            end
        end
        u.seen_x = nil        -- checked against rects at the next look, as the VM's
        S.units[#S.units + 1] = u
        return u
    end
    S.create_unit = create
    N.CreateUnit = create
    N.CreateUnitAtLoc = function(p, id, l, facing) return create(p, id, l.x, l.y, facing) end
    N.CreateUnitAtLocSaveLast = function(p, id, l, facing) return set("bj_lastCreatedUnit", N.CreateUnitAtLoc(p, id, l, facing)) end
    N.GetLastCreatedUnit = function() return get("bj_lastCreatedUnit") end
    N.RemoveUnit = function(u)
        if not u or u.removed then return end
        if u.creature then u.creature:DespawnOrUnsummon(0) end
        u.removed, u.alive = true, false
        for k, v in ipairs(S.units) do
            if v == u then table.remove(S.units, k) break end
        end
    end
    N.GetUnitTypeId = function(u) return u and shim.s2id(u.id) or 0 end
    N.GetOwningPlayer = function(u) return u and S:player(u.player) end
    N.GetUnitX = function(u) return u and sync(u).x or 0 end
    N.GetUnitY = function(u) return u and sync(u).y or 0 end
    N.GetUnitLoc = function(u)
        if u then sync(u) end
        return N.Location(u and u.x or 0, u and u.y or 0)
    end
    N.GetUnitFacing = function(u) return u and (math.deg(sync(u).facing or 0) % 360) or 0 end
    -- }}}

    -- {{{ Regions entered and left
    -- Checked every shim.RECT_CHECK_MS, as the VM's check_rects: a unit
    -- whose position (or life) changed since the last look is tested
    -- against every watched rect; registering doesn't fire for units
    -- already inside.
    local polling = false
    local function inside(r, u) return u.alive ~= false and u.x >= r.minx and u.x <= r.maxx and u.y >= r.miny and u.y <= r.maxy end
    function S:check_rects()
        local regs = self.watched_rects
        for _, u in ipairs(self.units) do
            sync(u)
            if u.seen_x ~= u.x or u.seen_y ~= u.y or u.seen_alive ~= u.alive then
                u.seen_x, u.seen_y, u.seen_alive = u.x, u.y, u.alive
                for _, reg in ipairs(regs) do
                    local now = inside(reg.rect, u)
                    local was = reg.inside[u] or false
                    if now ~= was then
                        reg.inside[u] = now or nil
                        if (now and reg.enter) or (not now and not reg.enter and u.alive ~= false) then
                            local trig = reg.trig
                            if not trig.destroyed and trig.enabled then
                                local ctx = { unit = u, player = self:player(u.player), event = reg.event, region = reg.region }
                                if reg.filter == nil or self:test(reg.filter, { filter_unit = u }) then
                                    self:fire_trigger(trig, ctx)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    local function poll()
        S:check_rects()
        S:after(shim.RECT_CHECK_MS / 1000, poll)
    end
    function S:watch_rect(reg)
        reg.inside = {}
        for _, u in ipairs(self.units) do
            sync(u)
            if inside(reg.rect, u) then reg.inside[u] = true end
        end
        self.watched_rects[#self.watched_rects + 1] = reg
        if not polling then
            polling = true
            S:after(shim.RECT_CHECK_MS / 1000, poll)
        end
    end
    local function region_regs(trig, region, filter, enter)
        local event = enter and "EVENT_GAME_ENTER_REGION" or "EVENT_GAME_LEAVE_REGION"
        for _, r in ipairs(region.rects) do
            S:watch_rect({ trig = trig, rect = r, region = region, filter = filter, enter = enter, event = event })
        end
        return S:handle({ kind = "event" })
    end
    N.TriggerRegisterEnterRegion = function(trig, region, filter) return region_regs(trig, region, filter, true) end
    N.TriggerRegisterLeaveRegion = function(trig, region, filter) return region_regs(trig, region, filter, false) end
    local function rect_region(r)
        local g = N.CreateRegion()
        N.RegionAddRect(g, r)
        return g
    end
    N.TriggerRegisterEnterRectSimple = function(trig, r) return N.TriggerRegisterEnterRegion(trig, rect_region(r), nil) end
    N.TriggerRegisterLeaveRectSimple = function(trig, r) return N.TriggerRegisterLeaveRegion(trig, rect_region(r), nil) end
    local function from(field) return function() local c = S.ctx return c and c[field] end end
    N.GetTriggerUnit = from("unit")
    N.GetEnteringUnit = from("unit")
    N.GetLeavingUnit = from("unit")
    N.GetTriggeringRegion = from("region")
    N.GetTriggerPlayer = from("player")
    N.GetFilterUnit = function() local c = S.ctx return c and c.filter_unit end
    -- }}}
end

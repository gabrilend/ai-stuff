--[[
fake_ale - a stand-in for ALE's API in plain Lua (issue W02e)

Licence: GNU AGPL v3 (server-side/LICENSE).

The shim takes ALE's API as a table (on the server, _G). This is that
table without a server: a clock the caller moves, timed events, one map
with a ground function, and creatures that stand where they're put. It
implements exactly the calls listed in wc3shim's shim.ALE_USED, with the
argument orders and meanings remembered there (NOT CHECKED against
mod-ale); a call to anything else raises, so the list can't fall behind
what the shim uses. A.used counts each call.

    local fake = require("wc3shim.fake_ale")
    local A = fake.new({ map_id = 900, ground = function(x, y) return 10 end, update_ms = 20 })
    A:place(1000000, 9000000, x, y, z, o)    -- a spawn from server/world.sql, already on the map
    local S = shim.new(A, data)
    A:advance(5000)                          -- five seconds of world updates
    A:move(creature, x, y)                   -- a creature walked (tests only)

Events run as the server runs them (from memory, unchecked): at world
updates, every update_ms, an event fires at the first update at or after
it is due, in the order they come due.
]]

local fake = {}

local Creature = {}
Creature.__index = Creature
function Creature:GetX() return self.x end
function Creature:GetY() return self.y end
function Creature:GetZ() return self.z end
function Creature:GetO() return self.o end
function Creature:IsAlive() return self.alive end
function Creature:SetFaction(f) self.faction = f end
function Creature:DespawnOrUnsummon(ms) self.despawned, self.alive = true, false end
function Creature:GetGUIDLow() return self.guid end
function Creature:GetEntry() return self.entry end
-- W02e step 2 (units.lua)
function Creature:GetHealth() return self.alive and self.health or 0 end
function Creature:GetMaxHealth() return self.max_health end
function Creature:SetHealth(h) self.health = math.max(0, math.min(h, self.max_health)) end
function Creature:Kill(target) target.alive, target.health, target.killed_by = false, 0, self end
function Creature:NearTeleport(x, y, z, o) self.x, self.y, self.z, self.o = x, y, z, o end
function Creature:SetFacing(o) self.o = o end
function Creature:MoveTo(id, x, y, z) self.moving_to = { x = x, y = y, z = z, id = id } end
function Creature:AttackStart(target) self.attacking, self.moving_to = target, nil end
function Creature:MoveStop() self.moving_to = nil end
function Creature:Respawn() self.alive, self.health = true, self.max_health end

-- {{{ fake.new
-- opts: map_id (default 900), ground(x, y) -> z or nil (default: none,
-- as a server before W02d), update_ms (default 20), first_guid (the
-- server's next creature guid, default 6000000), max_health (every
-- creature's, default 42: a creature's health is the server's, not WC3's)
function fake.new(opts)
    opts = opts or {}
    local A = { time_ms = opts.start_ms or 1000, used = {}, events = {}, next_event = 0,
                creatures = {}, by_guid = {}, spawned = {}, update_ms = opts.update_ms or 20,
                next_guid = opts.first_guid or 6000000, map_id = opts.map_id or 900, ground = opts.ground,
                max_health = opts.max_health or 42 }
    local function use(name) A.used[name] = (A.used[name] or 0) + 1 end

    function A.GetCurrTime() use("GetCurrTime") return A.time_ms end
    function A.GetTimeDiff(old) use("GetTimeDiff") return A.time_ms - old end
    function A.CreateLuaEvent(fn, delay, repeats)
        use("CreateLuaEvent")
        assert(type(fn) == "function" and type(delay) == "number" and delay >= 0, "CreateLuaEvent(fn, delay, repeats)")
        A.next_event = A.next_event + 1
        A.events[A.next_event] = { id = A.next_event, fn = fn, delay = delay, repeats = repeats or 1,
                                   due = A.time_ms + delay }
        return A.next_event
    end
    function A.RemoveEventById(id) use("RemoveEventById") A.events[id] = nil end

    local Map = {}
    function Map:GetHeight(x, y)
        use("Map:GetHeight")
        local ground = rawget(A, "ground")
        return ground and ground(x, y) or nil
    end
    function Map:GetWorldObject(guid) use("Map:GetWorldObject") return A.by_guid[guid] end
    local the_map = setmetatable({ id = A.map_id }, { __index = Map })
    function A.GetMapById(id, instance)
        use("GetMapById")
        if id == A.map_id then return the_map end
    end
    local function guid_key(low, entry) return "creature:" .. tostring(entry) .. ":" .. tostring(low) end
    function A.GetUnitGUID(low, entry) use("GetUnitGUID") return guid_key(low, entry) end

    local function new_creature(guid, entry, map_id, x, y, z, o)
        local c = setmetatable({ guid = guid, entry = entry, map_id = map_id, x = x, y = y, z = z, o = o,
                                 alive = true, health = A.max_health, max_health = A.max_health }, {
            __index = function(t, k)
                local f = Creature[k]
                if f == nil then error("fake ALE: Creature:" .. tostring(k) .. " isn't in shim.ALE_USED", 2) end
                return function(self, ...) use("Creature:" .. k) return f(self, ...) end
            end })
        A.creatures[#A.creatures + 1] = c
        A.by_guid[guid_key(guid, entry)] = c
        return c
    end
    function A.PerformIngameSpawn(kind, entry, map_id, instance, x, y, z, o, save, despawn)
        use("PerformIngameSpawn")
        assert(kind == 1, "PerformIngameSpawn: only creatures (1)")
        assert(type(entry) == "number" and type(x) == "number" and type(y) == "number" and type(z) == "number"
               and type(o) == "number", "PerformIngameSpawn(1, entry, map, instance, x, y, z, o, save, despawn)")
        if map_id ~= A.map_id then return nil end
        A.next_guid = A.next_guid + 1
        local c = new_creature(A.next_guid, entry, map_id, x, y, z, o)
        c.save, c.despawn = save, despawn
        A.spawned[#A.spawned + 1] = c
        return c
    end

    -- {{{ for tests: the world outside the shim
    -- a creature from server/world.sql, already on the map
    function A:place(guid, entry, x, y, z, o, faction)
        local c = new_creature(guid, entry, self.map_id, x, y, z or 0, o or 0)
        c.faction = faction
        return c
    end
    function A:move(c, x, y) c.x, c.y = x, y end
    function A:kill(c) c.alive, c.health = false, 0 end
    -- the server's combat took some of a creature's health
    function A:hurt(c, amount)
        c.health = math.max(0, c.health - amount)
        if c.health == 0 then c.alive = false end
    end
    -- run world updates until `ms` more have passed
    function A:advance(ms)
        local stop = self.time_ms + ms
        while self.time_ms < stop do
            self.time_ms = math.min(stop, self.time_ms + self.update_ms)
            self:update()
        end
    end
    -- one world update: every event due by now, in the order they came due
    function A:update()
        local guard = 0
        while true do
            local pick
            for _, e in pairs(self.events) do
                if e.due <= self.time_ms and (not pick or e.due < pick.due or (e.due == pick.due and e.id < pick.id)) then
                    pick = e
                end
            end
            if not pick then return end
            guard = guard + 1
            if guard > 100000 then error("fake ALE: an update ran 100000 events") end
            if pick.repeats == 1 then
                self.events[pick.id] = nil
            else
                if pick.repeats > 1 then pick.repeats = pick.repeats - 1 end
                pick.due = pick.due + math.max(1, pick.delay)
            end
            pick.fn(pick.id, pick.delay, pick.repeats)
        end
    end
    -- }}}

    return setmetatable(A, { __index = function(_, k)
        error("fake ALE: " .. tostring(k) .. " isn't in shim.ALE_USED", 2)
    end })
end
-- }}}

return fake

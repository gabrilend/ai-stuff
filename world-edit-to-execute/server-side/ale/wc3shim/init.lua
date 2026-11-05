--[[
wc3shim - a WC3 map's triggers, run inside AzerothCore's Lua engine (issue W02e)

Licence: GNU AGPL v3 (server-side/LICENSE). This file runs inside
AzerothCore (AGPL v3) and ALE (GPL v3); see docs/licensing-and-boundaries.md.
It requires nothing outside this folder.

A converted map's war3map.j is transpiled to Lua by the converter (on the
owner's machine, src/wowbuild/triggers.lua, with the project's own
transpiler in its "env" scope: every name the script doesn't define is
looked up in an environment). This shim is that environment on the
server: JASS natives (and Blizzard.j's functions, which no map carries)
implemented with ALE's calls.

    local shim = require("wc3shim")
    local S = shim.new(ale, data, opts)    -- ale: ALE's API (_G on the server, or fake_ale.new())
                                           -- data: <build>/server/triggers/map-data.lua's table
    local ok, err = S:load(lua_text)       -- the transpiled war3map.lua
    S:run_main()                           -- config(), then main(), as WC3 calls them
    S:report()                             -- what the script called that the shim lacks

From there the script lives on in ALE's timed events: timers, waits and
the region check are one-shot CreateLuaEvent calls, each scheduling the
next. Nothing here ticks by itself.

The reference: the project's own runtime, src/jass/vm.lua, which runs the
same transpiled script in the converter and the editor. Each native here
does what the VM's native of the same name does; the tests
(src/tests/test_wow_triggers.lua) run the same scripts through both and
compare. Where the server forces a difference, it is written beside the
native.

Honest accounting, as the VM's: a name the script calls that the shim
lacks becomes a stub that returns nil and is counted in S.missing (name ->
calls); errors inside a thread end that thread and are kept in S.errors;
units the server couldn't make (no creature template for the type) are
counted in S.unspawnable. The converter lists the names a map calls that
the shim lacks before the map ever reaches a server (the coverage report).

ALE's API as this shim uses it. EVERY ROW IS FROM MEMORY, NOT CHECKED:
check each against AzerothCore's mod-ale (its Eluna-derived API docs, and
the C++ in src/LuaEngine/methods/) on the owner's machine. shim.ALE_USED
lists them; fake_ale.lua implements exactly these and nothing else.
]]

local PREFIX = (... or "wc3shim"):gsub("%.init$", "")

local shim = {}
shim.VERSION = 1
shim.MODULES = { "core", "world", "players", "units", "groups", "sounds" }
shim.RECT_CHECK_MS = 100        -- the VM checks rects every 0.1 s (vm.RECT_CHECK_EVERY)
shim.MIN_DELAY_MS = 1           -- a wait or timer of 0 still goes through ALE's event queue
shim.ZERO_PERIOD_MS = 20        -- a periodic timer of timeout 0 (the VM fires it once a tick: 0.02 s in its tests)
shim.INVALID_HEIGHT = -100000   -- below this a height is "no ground here" (the server's INVALID_HEIGHT is -200000, from memory)

-- {{{ shim.ALE_USED
-- name, what it is used for, and that it is from memory (checked = false)
shim.ALE_USED = {
    { name = "GetCurrTime", use = "milliseconds since the server started (getMSTime)", checked = false },
    { name = "GetTimeDiff", use = "milliseconds since a GetCurrTime value, across its wrap", checked = false },
    { name = "CreateLuaEvent", use = "CreateLuaEvent(fn, delay_ms, repeats) -> event id; repeats 1 = once; fn(event_id, delay, repeats)", checked = false },
    { name = "RemoveEventById", use = "cancel a timed event", checked = false },
    { name = "GetMapById", use = "GetMapById(map_id, instance_id) -> Map", checked = false },
    { name = "Map:GetHeight", use = "Map:GetHeight(x, y) -> ground z (nil or INVALID_HEIGHT where the server has no ground)", checked = false },
    { name = "Map:GetWorldObject", use = "Map:GetWorldObject(guid) -> a creature already on the map (W02b's spawns)", checked = false },
    { name = "GetUnitGUID", use = "GetUnitGUID(low_guid, entry) -> a creature's full guid", checked = false },
    { name = "PerformIngameSpawn", use = "PerformIngameSpawn(1, entry, map_id, instance_id, x, y, z, o, save, despawn_ms) -> Creature; 1 = a creature, save false = not in the database", checked = false },
    { name = "Creature:GetX/GetY/GetZ/GetO", use = "where a creature stands (yards, radians)", checked = false },
    { name = "Creature:IsAlive", use = "alive", checked = false },
    { name = "Creature:SetFaction", use = "a template's faction changed for one creature (another WC3 owner)", checked = false },
    { name = "Creature:DespawnOrUnsummon", use = "DespawnOrUnsummon(delay_ms): RemoveUnit", checked = false },
    { name = "Creature:GetGUIDLow", use = "the creature's low guid, for the report", checked = false },
    -- W02e step 2 (units.lua)
    { name = "Creature:GetHealth/GetMaxHealth", use = "health now and at most (the fraction WC3's life mirrors)", checked = false },
    { name = "Creature:SetHealth", use = "SetHealth(amount): WC3's life fraction onto the creature", checked = false },
    { name = "Creature:Kill", use = "creature:Kill(creature): KillUnit, life set to 0, timed life", checked = false },
    { name = "Creature:NearTeleport", use = "NearTeleport(x, y, z, o): SetUnitPosition and the rest, on the same map", checked = false },
    { name = "Creature:SetFacing", use = "SetFacing(o): SetUnitFacing", checked = false },
    { name = "Creature:MoveTo", use = "MoveTo(id, x, y, z): a move, patrol or attack-move order", checked = false },
    { name = "Creature:AttackStart", use = "AttackStart(target): an attack order on a unit", checked = false },
    { name = "Creature:MoveStop", use = "stop and hold-position orders", checked = false },
    { name = "Creature:Respawn", use = "ReviveHero: the dead creature back where it died, then teleported", checked = false },
}
-- }}}

-- {{{ compatibility: LuaJIT / Lua 5.1 and Lua 5.2+ (which ALE's build uses is unchecked)
local loadstring = loadstring or load
local unpack = unpack or table.unpack
local function load_in(text, name, env)
    if setfenv then
        local chunk, err = loadstring(text, name)
        if not chunk then return nil, err end
        setfenv(chunk, env)
        return chunk
    end
    return load(text, name, "t", env)
end
shim.load_in = load_in
shim.unpack = unpack
-- }}}

-- {{{ Rawcodes ('hfoo' is an integer in JASS; units carry the 4-character id), as vm.id2s / vm.s2id
function shim.id2s(n)
    if type(n) == "string" then return n end
    n = math.floor(n or 0)
    local s = ""
    for _ = 1, 4 do
        s = string.char(n % 256) .. s
        n = math.floor(n / 256)
    end
    return s
end

function shim.s2id(s)
    if type(s) == "number" then return s end
    local n = 0
    for k = 1, #s do n = n * 256 + s:byte(k) end
    return n
end
-- }}}

-- {{{ JASS operator helpers (the transpiler's __jass), as the VM's
local function jass_helpers()
    local J = {}
    function J.add(a, b)
        if type(a) == "string" or type(b) == "string" then
            return (a == nil and "" or tostring(a)) .. (b == nil and "" or tostring(b))
        end
        return (a or 0) + (b or 0)
    end
    function J.idiv(a, b)
        if b == 0 then return 0 end
        local q = a / b
        return q >= 0 and math.floor(q) or math.ceil(q)
    end
    function J.array(default)
        return setmetatable({}, { __index = function() return default end })
    end
    return J
end
-- }}}

local S_mt = {}
S_mt.__index = S_mt
shim.S = S_mt

-- {{{ shim.new
-- ale: ALE's API: on the server _G (or a table of its globals), in tests
-- fake_ale.new(). data: map-data.lua's table (map id, the WC3 -> WoW
-- transform, creature entries, factions, W02b's spawns). opts: player
-- (the local player for GetLocalPlayer: none on a server, default 0),
-- on_player_state(p, key, value) (told when gold, lumber ... change; for
-- W02g's resource bar), verbose
function shim.new(ale, data, opts)
    assert(type(ale) == "table", "wc3shim.new: no ALE API given")
    local S = setmetatable({}, S_mt)
    S.ale = ale
    S.data = data or {}
    S.opts = opts or {}
    S.local_id = S.opts.player or 0
    S.missing, S.errors, S.missing_constants = {}, {}, {}
    S.error_count = 0
    S.handle_count = 0
    S.listeners = {}
    S.watched_rects = {}
    S.units = {}
    S.unspawnable = {}
    S.counts = { spawned = 0, adopted = 0, ghosts = 0, no_ground = 0, events = 0 }
    S.started_ms = ale.GetCurrTime()
    S.natives, S.constants = {}, {}
    for _, name in ipairs(shim.MODULES) do
        require(PREFIX .. "." .. name)(S, S.natives, shim)
    end
    local env = {}
    for k, f in pairs(S.natives) do env[k] = f end
    -- common.j's and Blizzard.j's constants with values (PLAYER_NEUTRAL_PASSIVE
    -- = 15, bj_PI ...) come in map-data.lua, from the converter's reference
    -- runtime, so both agree; the shim's own (handles it makes) win
    for k, c in pairs(S.data.constants or {}) do env[k] = c end
    for k, c in pairs(S.constants) do env[k] = c end
    env.__jass = jass_helpers()
    S.declared = {}
    setmetatable(env, { __index = function(t, name) return S:unknown(t, name) end })
    S.env = env
    return S
end
-- }}}

-- {{{ Time
-- seconds since the shim was made
function S_mt:now()
    return self.ale.GetTimeDiff(self.started_ms) / 1000
end

-- fn() after `seconds` (a one-shot ALE event); returns the event id
function S_mt:after(seconds, fn)
    local ms = math.floor((seconds or 0) * 1000 + 0.5)
    if ms < shim.MIN_DELAY_MS then ms = shim.MIN_DELAY_MS end
    self.counts.events = self.counts.events + 1
    local S = self
    return self.ale.CreateLuaEvent(function()
        local ok, err = pcall(fn)
        if not ok then S:error(tostring(err)) end
    end, ms, 1)
end

function S_mt:cancel(id)
    if id then self.ale.RemoveEventById(id) end
end
-- }}}

-- {{{ S:unknown
-- As the VM's: ALL_CAPS names are constants (their own name), bj_ names
-- Blizzard.j variables (nil until set), and anything else a function the
-- shim doesn't have, stood in for by a counted stub. (The VM has nearly
-- every native, so its stubs are rare; here most are stubs for now.)
function S_mt:unknown(env, name)
    if type(name) ~= "string" or self.declared[name] then return nil end
    if name:match("^[A-Z][A-Z0-9_]*$") then
        rawset(env, name, name)
        self.missing_constants[name] = true
        return name
    end
    if name:sub(1, 3) == "bj_" then
        self.missing_constants[name] = true
        return nil
    end
    -- a stand-in answers its type's zero when map-data.lua gives the type
    -- (a native answering a number or a string), else nil: so the
    -- arithmetic around a missing native doesn't end the thread
    local S = self
    local kind = self.data.stubs and self.data.stubs[name]
    local answer = (kind == "integer" or kind == "real") and 0 or (kind == "string" and "" or nil)
    local stub = function()
        S.missing[name] = (S.missing[name] or 0) + 1
        return answer
    end
    rawset(env, name, stub)
    return stub
end
-- }}}

-- {{{ S:load
-- The transpiled war3map.lua (text). Its globals land in the environment.
-- declared: the map's global names (map-data.lua's globals, so a global
-- declared without a value isn't taken for a missing native)
function S_mt:load(text, declared)
    for _, g in ipairs(declared or self.data.globals or {}) do self.declared[g] = true end
    local chunk, err = load_in(text, "=war3map.lua", self.env)
    if not chunk then return nil, "lua: " .. tostring(err) end
    local ok, run_err = pcall(chunk)
    if not ok then return nil, "globals: " .. tostring(run_err) end
    return true
end
-- }}}

-- {{{ Threads (as the VM's: every action, timer callback and wait is a coroutine with its event context)
function S_mt:run_thread(fn, ctx, ...)
    if type(fn) ~= "function" then return end
    local th = { co = coroutine.create(fn), ctx = ctx or {} }
    self:resume(th, ...)
    return th
end

function S_mt:resume(th, ...)
    local prev_ctx, prev_th = self.ctx, self.thread
    self.ctx, self.thread = th.ctx, th
    local ok, wait = coroutine.resume(th.co, ...)
    self.ctx, self.thread = prev_ctx, prev_th
    if not ok then
        self:error(debug.traceback(th.co, tostring(wait)))
    elseif coroutine.status(th.co) == "suspended" then
        local S = self
        self:after(math.max(0, tonumber(wait) or 0), function() S:resume(th) end)
    end
end

-- TriggerSleepAction: suspends the running thread (outside one, a no-op)
function S_mt:sleep(seconds)
    local th = self.thread
    if th and coroutine.running() == th.co then
        coroutine.yield(seconds or 0)
    end
end

function S_mt:error(msg)
    if #self.errors < 200 then self.errors[#self.errors + 1] = { time = self:now(), message = msg } end
    self.error_count = self.error_count + 1
    if self.opts.verbose and print then print("[wc3shim] " .. msg) end
end

function S_mt:with(fields, fn, ...)
    local ctx = self.ctx
    if not ctx then ctx = {}; self.ctx = ctx end
    local saved = {}
    for k, v in pairs(fields) do saved[k] = ctx[k]; ctx[k] = v end
    local ok, r = pcall(fn, ...)
    for k in pairs(fields) do ctx[k] = saved[k] end
    if not ok then self:error(tostring(r)) end
    return r
end

function S_mt:test(bx, fields)
    if bx == nil then return true end
    local S = self
    return self:with(fields, function() return S:eval(bx) end) and true or false
end

function S_mt:eval(bx)
    if bx == nil then return true end
    if bx.fn then return bx.fn() and true or false end
    if bx.op == "and" then return self:eval(bx.a) and self:eval(bx.b) end
    if bx.op == "or" then return self:eval(bx.a) or self:eval(bx.b) end
    if bx.op == "not" then return not self:eval(bx.a) end
    return true
end
-- }}}

-- {{{ Triggers (as the VM's)
function S_mt:new_trigger()
    return self:handle({ kind = "trigger", enabled = true, conditions = {}, actions = {}, exec_count = 0 })
end

function S_mt:trigger_passes(trig, ctx)
    if #trig.conditions == 0 then return true end
    local prev_ctx, prev_th = self.ctx, self.thread
    self.ctx, self.thread = ctx, nil
    local pass = true
    for _, c in ipairs(trig.conditions) do
        local ok, r = pcall(self.eval, self, c)
        if not ok then self:error(tostring(r)); r = false end
        if not r then pass = false break end
    end
    self.ctx, self.thread = prev_ctx, prev_th
    return pass
end

function S_mt:trigger_execute(trig, ctx)
    ctx = ctx or {}
    ctx.trigger = trig
    trig.exec_count = trig.exec_count + 1
    local actions = trig.actions
    return self:run_thread(function()
        for _, a in ipairs(actions) do a() end
    end, ctx)
end

function S_mt:fire_trigger(trig, ctx)
    if trig.destroyed or not trig.enabled then return end
    ctx.trigger = trig
    if self:trigger_passes(trig, ctx) then self:trigger_execute(trig, ctx) end
end

function S_mt:listen(trig, event, reg)
    reg = reg or {}
    reg.trig, reg.event = trig, event
    local list = self.listeners[event]
    if not list then list = {}; self.listeners[event] = list end
    list[#list + 1] = reg
    return self:handle({ kind = "event", reg = reg })
end

function S_mt:dispatch(event, match, make_ctx)
    local list = self.listeners[event]
    if not list then return end
    local fired = {}
    for _, reg in ipairs(list) do
        if not fired[reg.trig] and (not match or match(reg)) then
            local ctx = make_ctx(reg)
            ctx.event = event
            if reg.filter == nil or self:test(reg.filter, { filter_unit = ctx.unit, filter_player = ctx.player }) then
                fired[reg.trig] = true
                self:fire_trigger(reg.trig, ctx)
            end
        end
    end
end
-- }}}

-- {{{ Handles
function S_mt:handle(t)
    self.handle_count = self.handle_count + 1
    t.hid = 0x100000 + self.handle_count
    return t
end
-- }}}

-- {{{ S:run_main
-- config() then main(), each as a thread. While main's first stretch runs
-- (before its first wait), CreateUnit adopts W02b's spawns (world.lua):
-- the World Editor's main() makes every placed unit itself, and the
-- server has already spawned them from server/world.sql
function S_mt:run_main()
    if type(rawget(self.env, "config")) == "function" then self:run_thread(self.env.config, {}) end
    if type(rawget(self.env, "main")) == "function" then
        self.adopting = true
        self:run_thread(self.env.main, {})
        self.adopting = false
    end
end
-- }}}

-- {{{ S:report
function S_mt:report()
    local function sorted(t)
        local l = {}
        for k, v in pairs(t) do l[#l + 1] = { k, v } end
        table.sort(l, function(a, b) return a[2] > b[2] or (a[2] == b[2] and a[1] < b[1]) end)
        return l
    end
    local natives = 0
    for _ in pairs(self.natives) do natives = natives + 1 end
    return {
        natives = natives,
        missing = sorted(self.missing),
        unspawnable = sorted(self.unspawnable),
        missing_constants = self.missing_constants,
        errors = self.errors,
        error_count = self.error_count,
        counts = self.counts,
    }
end
-- }}}

return shim

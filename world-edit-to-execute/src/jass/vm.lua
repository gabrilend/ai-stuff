--[[
JASS Virtual Machine (Issue 520)

Runs a map's own war3map.j against a game world: the script is transpiled
to Lua (jass/transpiler.lua, env scope), loaded into an environment whose
free names are the natives in jass/natives/*.lua, and then config() and
main() are called as WC3 calls them. From there the script lives on in
triggers, timers and waits, driven by V:tick(dt) and by the events the
world reports (deaths, chat, dialog clicks, units entering rects).

Threads: every trigger action, timer callback and ExecuteFunc runs as a
coroutine that carries its own event context, so TriggerSleepAction and
PolledWait suspend it and GetTriggerUnit() still answers after the wait.

Honest accounting: a name the script calls that no native module
provides becomes a stub that does nothing and returns nil, and is
counted in V.missing (name -> calls). Natives that deliberately do
nothing (sound, camera, fog, special effects: there is no system for
them yet) are counted in V.noops. Errors inside threads end that thread
only and are kept in V.errors.

    local vm = require("jass.vm")
    local V = vm.new(world, { player = 0 })   -- world: demo/wc3map/game.lua or vm.bare_world()
    local ok, err = V:load(source)            -- war3map.j text
    V:run_main()                              -- config(), then main()
    V:tick(0.02)                              -- timers, waits, rect events
    V:chat(0, "-help")                        -- a player typed
    V:player_event("EVENT_PLAYER_END_CINEMATIC")   -- the local player pressed Esc
    V:click(button)                           -- a dialog button pressed

The world is anything with: units (a list of records with id, player, x,
y, facing (radians), hp, hp_max, alive), spawn(id, player, x, y,
facing), remove(u), kill(u, killer), order(list, kind, x, y, target),
team_of(player) and an on_death slot the VM fills in.
]]

local lexer = require("jass.lexer")
local parser = require("jass.parser")
local transpiler = require("jass.transpiler")

local vm = {}

vm.NATIVE_MODULES = { "jass.natives.core", "jass.natives.world", "jass.natives.interface", "jass.natives.bj",
                      "jass.natives.ai_host", "jass.natives.fog" }
vm.RECT_CHECK_EVERY = 0.1    -- seconds between enter/leave rect checks
vm.MAX_TIMER_FIRES = 50      -- per timer per tick (a 0-period timer can't hang a tick)

local V_mt = {}
V_mt.__index = V_mt

-- {{{ Rawcodes
-- 'hfoo' is an integer in JASS; units carry the 4-character id
function vm.id2s(n)
    if type(n) == "string" then return n end
    n = math.floor(n or 0)
    local s = ""
    for _ = 1, 4 do
        s = string.char(n % 256) .. s
        n = math.floor(n / 256)
    end
    return s
end

function vm.s2id(s)
    if type(s) == "number" then return s end
    local n = 0
    for k = 1, #s do n = n * 256 + s:byte(k) end
    return n
end
-- }}}

-- {{{ JASS operator helpers (see transpiler.lua, env scope)
local function jass_helpers()
    local J = {}
    -- + on operands whose types weren't known when transpiling
    function J.add(a, b)
        if type(a) == "string" or type(b) == "string" then
            return (a == nil and "" or tostring(a)) .. (b == nil and "" or tostring(b))
        end
        return (a or 0) + (b or 0)
    end
    -- integer division truncates toward zero; by zero gives 0 (WC3 ends
    -- the thread; a quiet 0 keeps the map going)
    function J.idiv(a, b)
        if b == 0 then return 0 end
        local q = a / b
        return q >= 0 and math.floor(q) or math.ceil(q)
    end
    -- JASS arrays: every index starts out as the type's default
    function J.array(default)
        return setmetatable({}, { __index = function() return default end })
    end
    return J
end
-- }}}

-- {{{ vm.bare_world
-- A world with no map: units are plain records that stand where they're
-- put. For tests and for running a script headless.
function vm.bare_world()
    local w = { units = {}, time = 0 }
    function w.spawn(id, player, x, y, facing)
        local u = { id = id, player = player, x = x, y = y, z = 0, facing = facing or 0,
                    hp = 100, hp_max = 100, alive = true, spec = { design = "unit" } }
        w.units[#w.units + 1] = u
        return u
    end
    function w.remove(u)
        u.removed, u.alive = true, false
        for k, v in ipairs(w.units) do
            if v == u then table.remove(w.units, k) break end
        end
    end
    function w.kill(u, killer)
        if not u.alive then return end
        u.hp, u.alive = 0, false
        if w.on_death then w.on_death(u, killer) end
    end
    function w.order(list, kind, x, y, target)
        for _, u in ipairs(list) do
            u.order = { kind = kind, x = x, y = y }
            u.target = target
        end
    end
    function w.team_of(n) return n end
    return w
end
-- }}}

-- {{{ vm.new
function vm.new(world, opts)
    opts = opts or {}
    local V = setmetatable({}, V_mt)
    V.world = world or vm.bare_world()
    V.opts = opts
    V.time = 0
    V.local_id = opts.player or 0
    V.missing, V.noops, V.errors = {}, {}, {}
    V.calls = 0
    V.sleepers = {}
    V.timers = {}
    V.listeners = {}          -- event name -> { registration, ... }
    V.watched_rects = {}      -- enter/leave registrations
    V.rect_clock = 0
    V.messages = {}           -- { text, ends, at } shown to the local player
    V.dialogs = {}            -- every dialog made
    V.timer_dialogs = {}
    V.quests = {}
    V.multiboards = {}
    V.outcome = nil           -- "victory" / "defeat" for the local player
    V.handle_count = 0

    V.natives, V.types, V.noop = {}, {}, {}
    V.global_types = {}       -- Blizzard.j/common.j variables' types, for the transpiler
    V.constants = {}
    for _, name in ipairs(vm.NATIVE_MODULES) do
        require(name)(V, V.natives, V.types)
    end

    -- the script's environment: natives copied in (fast lookups), then
    -- the map's globals and functions land here as it loads
    local env = {}
    for k, f in pairs(V.natives) do env[k] = f end
    for k, c in pairs(V.constants) do env[k] = c end
    env.__jass = jass_helpers()
    V.declared = {}
    setmetatable(env, { __index = function(t, name) return V:unknown(t, name) end })
    V.env = env

    -- deaths reported by the world
    local chained = V.world.on_death
    V.world.on_death = function(u, killer)
        if chained then chained(u, killer) end
        V:unit_event("DEATH", u, { killer = killer })
    end
    local chained_attack = V.world.on_attack
    V.world.on_attack = function(u, target)
        if chained_attack then chained_attack(u, target) end
        V:unit_event("ATTACKED", target, { attacker = u })
    end
    local chained_damaged = V.world.on_damaged
    V.world.on_damaged = function(t, src, amount)
        if chained_damaged then chained_damaged(t, src, amount) end
        V:unit_event("DAMAGED", t, { damage = amount, attacker = src })
    end
    local chained_trained = V.world.on_trained
    V.world.on_trained = function(b, u)
        if chained_trained then chained_trained(b, u) end
        V:unit_event("TRAIN_FINISH", b, { trained = u })
    end
    if V.init_world then V:init_world() end
    return V
end
-- }}}

-- {{{ V:unknown
-- A free name nothing defines. ALL_CAPS names are constants (their own
-- name, interned: equal to themselves and distinct from every other);
-- bj_ names are Blizzard.j variables (nil until set); map globals
-- declared without a value are nil; anything else is a function the VM
-- doesn't have, stood in for by a counted stub.
function V_mt:unknown(env, name)
    if type(name) ~= "string" or self.declared[name] then return nil end
    if name:match("^[A-Z][A-Z0-9_]*$") then
        rawset(env, name, name)
        self.missing_constants = self.missing_constants or {}
        self.missing_constants[name] = true
        return name
    end
    if name:sub(1, 3) == "bj_" then
        self.missing_constants = self.missing_constants or {}
        self.missing_constants[name] = true
        return nil
    end
    local V = self
    local stub = function()
        V.missing[name] = (V.missing[name] or 0) + 1
        return nil
    end
    rawset(env, name, stub)
    return stub
end
-- }}}

-- {{{ V:load
-- Transpile and load a war3map.j. Returns true, or nil and a message.
function V_mt:load(source)
    local t0 = os.clock()
    local tokens, lex_errors = lexer.tokenize(source)
    local ast, parse_errors = parser.parse(tokens)
    if parse_errors and #parse_errors > 0 then
        return nil, "parse: " .. tostring(parse_errors[1].message or parse_errors[1])
    end
    for _, d in ipairs(ast.declarations or {}) do
        if d.type == "GLOBAL_BLOCK" then
            for _, g in ipairs(d.declarations or {}) do self.declared[g.name] = true end
        end
    end
    local lua, errors, stats = transpiler.transpile(ast, { scope = "env", native_types = self.types,
                                                           global_types = self.global_types })
    if errors and #errors > 0 then
        return nil, "transpile: " .. tostring(errors[1].message or errors[1])
    end
    local chunk, err = loadstring(lua, "=war3map.j")
    if not chunk then return nil, "lua: " .. tostring(err) end
    setfenv(chunk, self.env)
    local ok, run_err = pcall(chunk)
    if not ok then return nil, "globals: " .. tostring(run_err) end
    self.lua = lua
    self.stats = { unknown_ops = stats and stats.unknown_ops or 0, lex_errors = lex_errors and #lex_errors or 0,
                   load_seconds = os.clock() - t0 }
    return true
end
-- }}}

-- {{{ Threads
-- Run fn(...) as a new thread with event context ctx
function V_mt:run_thread(fn, ctx, ...)
    if type(fn) ~= "function" then return end
    local th = { co = coroutine.create(fn), ctx = ctx or {} }
    self:resume(th, ...)
    return th
end

function V_mt:resume(th, ...)
    local prev_ctx, prev_th = self.ctx, self.thread
    self.ctx, self.thread = th.ctx, th
    local ok, wait = coroutine.resume(th.co, ...)
    self.ctx, self.thread = prev_ctx, prev_th
    if not ok then
        self:error(debug.traceback(th.co, tostring(wait)))
    elseif coroutine.status(th.co) == "suspended" then
        self.sleepers[#self.sleepers + 1] = { th = th, at = self.time + math.max(0, tonumber(wait) or 0) }
    end
end

-- TriggerSleepAction: suspends the running thread (outside one, a no-op)
function V_mt:sleep(seconds)
    local th = self.thread
    if th and coroutine.running() == th.co then
        coroutine.yield(seconds or 0)
    end
end

function V_mt:error(msg)
    if #self.errors < 200 then self.errors[#self.errors + 1] = { time = self.time, message = msg } end
    self.error_count = (self.error_count or 0) + 1
    if self.opts.verbose then io.stderr:write("[jass] " .. msg .. "\n") end
end

-- Call fn synchronously in the current thread with some context fields
-- set (enumeration callbacks, filters); returns fn's result
function V_mt:with(fields, fn, ...)
    local ctx = self.ctx
    if not ctx then ctx = {}; self.ctx = ctx end
    local saved = {}
    for k, v in pairs(fields) do saved[k] = ctx[k]; ctx[k] = v end
    local ok, r = pcall(fn, ...)
    for k in pairs(fields) do ctx[k] = saved[k] end
    if not ok then self:error(tostring(r)) end
    return r
end

-- A boolexpr (Condition/Filter/And/Or/Not) tested with context fields
function V_mt:test(bx, fields)
    if bx == nil then return true end
    return self:with(fields, function() return self:eval(bx) end) and true or false
end

function V_mt:eval(bx)
    if bx == nil then return true end
    if bx.fn then return bx.fn() and true or false end
    if bx.op == "and" then return self:eval(bx.a) and self:eval(bx.b) end
    if bx.op == "or" then return self:eval(bx.a) or self:eval(bx.b) end
    if bx.op == "not" then return not self:eval(bx.a) end
    return true
end
-- }}}

-- {{{ Triggers
function V_mt:new_trigger()
    return self:handle({ kind = "trigger", enabled = true, conditions = {}, actions = {}, exec_count = 0 })
end

-- Conditions, in the firing thread
function V_mt:trigger_passes(trig, ctx)
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

-- Actions, in a new thread (all of them one after another, as WC3 does)
function V_mt:trigger_execute(trig, ctx)
    ctx = ctx or {}
    ctx.trigger = trig
    trig.exec_count = trig.exec_count + 1
    local actions = trig.actions
    return self:run_thread(function()
        for _, a in ipairs(actions) do a() end
    end, ctx)
end

-- An event reached trig: enabled, conditions pass, then the actions
function V_mt:fire_trigger(trig, ctx)
    if trig.destroyed or not trig.enabled then return end
    ctx.trigger = trig
    if self:trigger_passes(trig, ctx) then self:trigger_execute(trig, ctx) end
end

-- Registration: listeners[event] gets { trig = , ...filters }
function V_mt:listen(trig, event, reg)
    reg = reg or {}
    reg.trig, reg.event = trig, event
    local list = self.listeners[event]
    if not list then list = {}; self.listeners[event] = list end
    list[#list + 1] = reg
    return self:handle({ kind = "event", reg = reg })
end

-- Every registration of `event` for which match(reg) holds fires with a
-- fresh context from make_ctx(reg)
function V_mt:dispatch(event, match, make_ctx)
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

-- {{{ Events from the world
-- A unit event, e.g. "DEATH": fires EVENT_PLAYER_UNIT_DEATH for the
-- unit's owner (and data.also_player, the previous owner of a changed
-- unit), EVENT_UNIT_DEATH for the unit itself, and widget death events
function V_mt:unit_event(what, u, data)
    local owner = self:player(u.player)
    local also = data and data.also_player
    local function ctx()
        local c = { unit = u, player = owner }
        if data then for k, v in pairs(data) do c[k] = v end end
        return c
    end
    -- hero events are EVENT_PLAYER_HERO_LEVEL, not ..._UNIT_HERO_...
    local player_event = what:match("^HERO_") and ("EVENT_PLAYER_" .. what) or ("EVENT_PLAYER_UNIT_" .. what)
    self:dispatch(player_event, function(reg)
        return reg.player == owner or (also and reg.player == also)
    end, ctx)
    self:dispatch("EVENT_UNIT_" .. what, function(reg) return reg.unit == u end, ctx)
    if what == "DEATH" then
        self:dispatch("WIDGET_DEATH", function(reg) return reg.unit == u end, ctx)
    end
end

-- A player's state changed (gold, lumber ...: issue 527): each
-- TriggerRegisterPlayerStateEvent(trig, player, state, opcode, limit)
-- for that player fires when its comparison turns true
-- common.j's limitops, by name or number (ConvertLimitOp(0..5))
local COMPARE = {
    LESS_THAN = function(a, b) return a < b end, LESS_THAN_OR_EQUAL = function(a, b) return a <= b end,
    EQUAL = function(a, b) return a == b end, GREATER_THAN_OR_EQUAL = function(a, b) return a >= b end,
    GREATER_THAN = function(a, b) return a > b end, NOT_EQUAL = function(a, b) return a ~= b end,
}
local LIMITOP = { [0] = "LESS_THAN", "LESS_THAN_OR_EQUAL", "EQUAL", "GREATER_THAN_OR_EQUAL", "GREATER_THAN", "NOT_EQUAL" }
function V_mt:player_state_changed(player_id)
    local list = self.listeners.PLAYER_STATE
    if not list then return end
    local p = self:player(player_id)
    for _, reg in ipairs(list) do
        local a = reg.args or {}
        if a[1] == p then
            local cmp = COMPARE[LIMITOP[a[3]] or tostring(a[3])] or COMPARE.EQUAL
            local now = cmp(self.natives.GetPlayerState(p, a[2]) or 0, tonumber(a[4]) or 0)
            if now and not reg.was_true then
                self:fire_trigger(reg.trig, { player = p, event = "PLAYER_STATE" })
            end
            reg.was_true = now
        end
    end
end

-- A player typed text into chat
function V_mt:chat(player_id, text)
    local p = self:player(player_id)
    self:dispatch("EVENT_PLAYER_CHAT", function(reg)
        if reg.player ~= p then return false end
        if reg.exact then return text == reg.text end
        return reg.text == "" or text:find(reg.text, 1, true) ~= nil
    end, function(reg) return { player = p, chat = text, matched = reg.text } end)
end

-- A player event with no more to it than who: "EVENT_PLAYER_END_CINEMATIC"
-- (Esc), "EVENT_PLAYER_LEAVE", ... (player_id defaults to the local player)
function V_mt:player_event(event, player_id)
    local p = self:player(player_id or self.local_id)
    self:dispatch(event, function(reg) return reg.player == p end, function() return { player = p } end)
end

-- The local player (or player_id) pressed a dialog button
function V_mt:click(button, player_id)
    local d = button.dialog
    local p = self:player(player_id or self.local_id)
    d.shown[p.id] = false
    local function ctx() return { player = p, button = button, dialog = d } end
    self:dispatch("EVENT_DIALOG_BUTTON_CLICK", function(reg) return reg.button == button end, ctx)
    self:dispatch("EVENT_DIALOG_CLICK", function(reg) return reg.dialog == d end, ctx)
end

-- The dialogs showing to the local player
function V_mt:shown_dialogs()
    local out = {}
    for _, d in ipairs(self.dialogs) do
        if d.shown[self.local_id] and not d.destroyed then out[#out + 1] = d end
    end
    return out
end
-- }}}

-- {{{ Rect enter/leave
-- Checked every RECT_CHECK_EVERY seconds for units that moved or were
-- made; a rect starts out knowing who's already inside (no events for
-- them), as registering in WC3 doesn't fire for units standing there
function V_mt:watch_rect(reg)
    reg.inside = {}
    local r = reg.rect
    for _, u in ipairs(self.world.units) do
        if u.alive ~= false and u.x >= r.minx and u.x <= r.maxx and u.y >= r.miny and u.y <= r.maxy then
            reg.inside[u] = true
        end
    end
    self.watched_rects[#self.watched_rects + 1] = reg
end

function V_mt:check_rects()
    self:check_in_range()
    local regs = self.watched_rects
    if #regs == 0 then return end
    for _, u in ipairs(self.world.units) do
        if u.vm_x ~= u.x or u.vm_y ~= u.y or u.vm_alive ~= u.alive then
            u.vm_x, u.vm_y, u.vm_alive = u.x, u.y, u.alive
            for _, reg in ipairs(regs) do
                local r = reg.rect
                local now = u.alive ~= false and u.x >= r.minx and u.x <= r.maxx and u.y >= r.miny and u.y <= r.maxy
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
-- }}}

-- {{{ Unit in range
-- Units coming within range of a unit (TriggerRegisterUnitInRange):
-- fires once as each comes in, again only after it has left
function V_mt:check_in_range()
    local regs = self.in_range
    if not regs or #regs == 0 then return end
    local units = self.world.units
    for _, reg in ipairs(regs) do
        local c = reg.unit
        if c and c.alive ~= false and not c.removed and not reg.trig.destroyed then
            local r2 = reg.range * reg.range
            local now = {}
            for _, u in ipairs(units) do
                if u ~= c and u.alive ~= false and not u.removed and (u.x - c.x) ^ 2 + (u.y - c.y) ^ 2 <= r2 then
                    now[u] = true
                    if not reg.inside[u] and reg.trig.enabled
                        and (reg.filter == nil or self:test(reg.filter, { filter_unit = u })) then
                        self:fire_trigger(reg.trig, { unit = u, player = self:player(u.player),
                                                      event = "EVENT_UNIT_IN_RANGE", target = c })
                    end
                end
            end
            reg.inside = now
        end
    end
end
-- }}}

-- {{{ Timers
function V_mt:new_timer()
    local t = self:handle({ kind = "timer", remaining = 0, timeout = 0, periodic = false, running = false })
    self.timers[#self.timers + 1] = t
    return t
end

function V_mt:start_timer(t, timeout, periodic, fn)
    t.timeout, t.remaining, t.periodic, t.fn = timeout or 0, timeout or 0, periodic, fn
    t.running, t.paused = true, false
end

function V_mt:expire(t)
    local ctx = { timer = t }
    if t.fn then self:run_thread(t.fn, ctx) end
    self:dispatch("EVENT_TIMER_EXPIRE", function(reg) return reg.timer == t end,
        function() return { timer = t } end)
    if t.on_expire then t.on_expire(t) end
end

function V_mt:run_timers(dt)
    local live = {}
    for _, t in ipairs(self.timers) do
        if not t.destroyed then
            live[#live + 1] = t
            if t.running and not t.paused then
                t.remaining = t.remaining - dt
                local fires = 0
                while t.running and t.remaining <= 1e-9 and fires < vm.MAX_TIMER_FIRES do
                    fires = fires + 1
                    if t.periodic and t.timeout > 0 then
                        t.remaining = t.remaining + t.timeout
                    else
                        t.running, t.remaining = false, 0
                    end
                    self:expire(t)
                    if t.periodic and t.timeout <= 0 then break end
                end
            end
        end
    end
    self.timers = live
end
-- }}}

-- {{{ V:tick
function V_mt:tick(dt)
    self.time = self.time + dt
    self.world_time = self.time
    self:run_timers(dt)

    -- waits that are over, in the order they end
    if #self.sleepers > 0 then
        local due, keep = {}, {}
        for _, s in ipairs(self.sleepers) do
            if s.at <= self.time + 1e-9 then due[#due + 1] = s else keep[#keep + 1] = s end
        end
        self.sleepers = keep
        table.sort(due, function(a, b) return a.at < b.at end)
        for _, s in ipairs(due) do self:resume(s.th) end
    end

    self.rect_clock = self.rect_clock + dt
    if self.rect_clock >= vm.RECT_CHECK_EVERY then
        self.rect_clock = 0
        self:check_rects()
    end

    -- messages whose time is up
    local keep = {}
    for _, m in ipairs(self.messages) do
        if m.ends > self.time then keep[#keep + 1] = m end
    end
    self.messages = keep
end
-- }}}

-- {{{ V:apply_lobby
-- Who sits where once the lobby closes: the local player (and
-- opts.humans) are users, the rest of the map's player slots that are
-- playing (opts.playing, default all twelve) are computers. config()
-- only says what each slot may be.
function V_mt:apply_lobby()
    local humans = { [self.local_id] = true }
    for _, n in ipairs(self.opts.humans or {}) do humans[n] = true end
    for n = 0, 11 do
        local p = self:player(n)
        if p.slot == "PLAYER_SLOT_STATE_PLAYING" then
            p.controller = humans[n] and "MAP_CONTROL_USER" or "MAP_CONTROL_COMPUTER"
        end
    end
end
-- }}}

-- {{{ V:run_main
-- config() then main(), each as a thread (main's init triggers may wait)
function V_mt:run_main()
    local t0 = os.clock()
    if type(rawget(self.env, "config")) == "function" then self:run_thread(self.env.config, {}) end
    self:apply_lobby()
    if type(rawget(self.env, "main")) == "function" then self:run_thread(self.env.main, {}) end
    self.stats = self.stats or {}
    self.stats.main_seconds = os.clock() - t0
end
-- }}}

-- {{{ Handles
function V_mt:handle(t)
    self.handle_count = self.handle_count + 1
    t.hid = 0x100000 + self.handle_count
    return t
end
-- }}}

-- {{{ V:report
-- What the script asked for that the VM doesn't have, most called first
function V_mt:report()
    local function sorted(t)
        local l = {}
        for k, v in pairs(t) do l[#l + 1] = { k, v } end
        table.sort(l, function(a, b) return a[2] > b[2] end)
        return l
    end
    local natives = 0
    for _ in pairs(self.natives) do natives = natives + 1 end
    return {
        natives = natives,
        missing = sorted(self.missing),
        noops = sorted(self.noops),
        missing_constants = self.missing_constants or {},
        errors = self.errors,
        error_count = self.error_count or 0,
    }
end
-- }}}

-- {{{ V:text
-- A string as players see it: the map's TRIGSTR_nnn references resolved
-- (opts.strings(key) -> text), and WC3's |cAARRGGBB colour codes kept
function V_mt:text(s)
    if s == nil then return "" end
    s = tostring(s)
    local resolve = self.opts.strings
    if resolve and s:find("TRIGSTR_", 1, true) then
        s = s:gsub("TRIGSTR_%d+", function(k) return resolve(k) or k end)
    end
    return s
end
-- }}}

-- {{{ V:message
-- Text for the local player's screen
function V_mt:message(text, seconds)
    text = self:text(text)
    self.messages[#self.messages + 1] = { text = text, ends = self.time + (seconds or 10), at = self.time }
    if #self.messages > 40 then table.remove(self.messages, 1) end
    self.log = self.log or {}
    if #self.log < 2000 then self.log[#self.log + 1] = { time = self.time, text = text } end
end
-- }}}

return vm

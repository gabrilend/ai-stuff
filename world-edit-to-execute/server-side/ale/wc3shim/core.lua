--[[
wc3shim natives that don't touch the world (issue W02e)

Licence: GNU AGPL v3 (server-side/LICENSE).

Numbers and strings (plain Lua), triggers and boolexprs, timers, waits and
the timer events. Each does what src/jass/natives/core.lua (and, for the
Blizzard.j names, bj.lua) does in the project's own runtime; timers and
waits run on ALE's timed events instead of the VM's tick.

Installed by init.lua: require("wc3shim.core")(S, N, shim).
]]

return function(S, N, shim)
    local function none() end

    -- {{{ Numbers and strings (language)
    local function trunc(x)
        x = tonumber(x) or 0
        return x >= 0 and math.floor(x) or math.ceil(x)
    end
    N.I2R = function(i) return i or 0 end
    N.R2I = trunc
    N.I2S = function(i) return string.format("%d", trunc(i)) end
    N.R2S = function(r) return string.format("%.3f", r or 0) end
    N.R2SW = function(r, width, precision)
        return string.format("%" .. (width or 1) .. "." .. (precision or 3) .. "f", r or 0)
    end
    N.S2I = function(s)
        local n = tostring(s or ""):match("^%s*([%+%-]?%d+)")
        return n and tonumber(n) or 0
    end
    N.S2R = function(s)
        local n = tostring(s or ""):match("^%s*([%+%-]?%d*%.?%d+)")
        return n and tonumber(n) or 0
    end
    N.GetRandomInt = function(lo, hi)
        lo, hi = trunc(lo), trunc(hi)
        if hi < lo then lo, hi = hi, lo end
        return math.random(lo, hi)
    end
    N.GetRandomReal = function(lo, hi) return lo + math.random() * (hi - lo) end
    N.SquareRoot = function(x) return x > 0 and math.sqrt(x) or 0 end
    N.Pow = function(x, p) return x ^ p end
    N.Sin, N.Cos, N.Tan = math.sin, math.cos, math.tan
    N.Atan2 = function(y, x) return (math.atan2 or math.atan)(y, x) end
    N.Deg2Rad = math.rad
    N.Rad2Deg = math.deg
    N.ModuloInteger = function(a, b)
        local m = a - trunc(a / b) * b
        if m < 0 then m = m + b end
        return m
    end
    N.ModuloReal = N.ModuloInteger
    N.IMinBJ, N.IMaxBJ, N.RMinBJ, N.RMaxBJ = math.min, math.max, math.min, math.max
    N.IAbsBJ, N.RAbsBJ = math.abs, math.abs
    N.StringLength = function(s) return #(s or "") end
    N.SubString = function(s, a, b)
        s = s or ""
        return s:sub(math.max(0, a) + 1, math.min(#s, b))
    end
    N.SubStringBJ = function(s, a, b) return N.SubString(s, a - 1, b) end
    N.StringCase = function(s, upper) return upper and (s or ""):upper() or (s or ""):lower() end
    N.GetHandleId = function(h)
        if type(h) == "table" then return h.hid or 0 end
        if type(h) == "number" then return h end
        return 0
    end
    -- }}}

    -- {{{ Boolexprs
    N.Condition = function(fn) return fn and S:handle({ kind = "boolexpr", fn = fn }) or nil end
    N.Filter = N.Condition
    N.And = function(a, b) return S:handle({ kind = "boolexpr", op = "and", a = a, b = b }) end
    N.Or = function(a, b) return S:handle({ kind = "boolexpr", op = "or", a = a, b = b }) end
    N.Not = function(a) return S:handle({ kind = "boolexpr", op = "not", a = a }) end
    N.DestroyBoolExpr, N.DestroyCondition, N.DestroyFilter = none, none, none
    -- }}}

    -- {{{ Triggers
    N.CreateTrigger = function() return S:new_trigger() end
    N.DestroyTrigger = function(t) if t then t.destroyed = true end end
    N.EnableTrigger = function(t) if t then t.enabled = true end end
    N.DisableTrigger = function(t) if t then t.enabled = false end end
    N.IsTriggerEnabled = function(t) return t ~= nil and t.enabled end
    N.TriggerAddAction = function(t, fn)
        if t and fn then t.actions[#t.actions + 1] = fn end
        return S:handle({ kind = "triggeraction", fn = fn })
    end
    N.TriggerRemoveAction = function(t, a)
        for k, fn in ipairs(t.actions) do if fn == a.fn then table.remove(t.actions, k) break end end
    end
    N.TriggerClearActions = function(t) t.actions = {} end
    N.TriggerAddCondition = function(t, bx)
        if t and bx then t.conditions[#t.conditions + 1] = bx end
        return S:handle({ kind = "triggercondition", bx = bx })
    end
    N.TriggerRemoveCondition = function(t, c)
        for k, bx in ipairs(t.conditions) do if bx == c.bx then table.remove(t.conditions, k) break end end
    end
    N.TriggerClearConditions = function(t) t.conditions = {} end
    N.TriggerEvaluate = function(t) return S:trigger_passes(t, S.ctx or {}) end
    local function inherit()
        local c = {}
        for k, v in pairs(S.ctx or {}) do c[k] = v end
        return c
    end
    N.TriggerExecute = function(t) if t then S:trigger_execute(t, inherit()) end end
    N.ConditionalTriggerExecute = function(t)
        if t and S:trigger_passes(t, S.ctx or {}) then S:trigger_execute(t, inherit()) end
    end
    N.TriggerExecuteBJ = function(trig, check)
        if check then N.ConditionalTriggerExecute(trig) else N.TriggerExecute(trig) end
        return true
    end
    N.GetTriggerExecCount = function(t) return t and t.exec_count or 0 end
    N.ExecuteFunc = function(name)
        local fn = S.env[name]
        if type(fn) == "function" then S:run_thread(fn, inherit()) end
    end
    N.DoNothing = none
    local function from(field) return function() local c = S.ctx return c and c[field] end end
    N.GetTriggeringTrigger = from("trigger")
    N.GetTriggerEventId = from("event")
    -- }}}

    -- {{{ Waits
    N.TriggerSleepAction = function(seconds) S:sleep(seconds) end
    N.TriggerSleepActionBJ = N.TriggerSleepAction
    N.PolledWait = function(seconds) if seconds and seconds > 0 then S:sleep(seconds) end end
    -- }}}

    -- {{{ Timers
    -- The VM counts a timer down each tick; here each run is one ALE
    -- one-shot event. A periodic timer schedules its next run from when the
    -- last was due (not when ALE ran it), so it doesn't drift.
    local timer_mt = {}
    local function schedule(t, seconds)
        S:cancel(t.event)
        t.due = S:now() + seconds
        t.event = S:after(seconds, function()
            t.event = nil
            if t.destroyed or not t.running or t.paused then return end
            if t.periodic then
                local period = t.timeout > 0 and t.timeout or shim.ZERO_PERIOD_MS / 1000
                schedule(t, math.max(0, t.due + period - S:now()))
            else
                t.running = false
            end
            S:expire(t)
        end)
    end
    function S:new_timer()
        return S:handle(setmetatable({ kind = "timer", timeout = 0, periodic = false, running = false,
                                       paused = false, remaining = 0 }, timer_mt))
    end
    function S:start_timer(t, timeout, periodic, fn)
        t.timeout, t.periodic, t.fn = timeout or 0, periodic and true or false, fn
        t.running, t.paused, t.remaining = true, false, 0
        schedule(t, t.timeout)
    end
    function S:expire(t)
        if t.fn then S:run_thread(t.fn, { timer = t }) end
        S:dispatch("EVENT_TIMER_EXPIRE", function(reg) return reg.timer == t end,
            function() return { timer = t } end)
        if t.on_expire then t.on_expire(t) end
    end
    local function remaining(t)
        if t.paused then return t.remaining end
        if not t.running or not t.due then return 0 end
        return math.max(0, t.due - S:now())
    end
    N.CreateTimer = function() return S:new_timer() end
    N.DestroyTimer = function(t)
        if t then S:cancel(t.event); t.event, t.destroyed, t.running = nil, true, false end
    end
    N.TimerStart = function(t, timeout, periodic, fn) if t then S:start_timer(t, timeout, periodic, fn) end end
    N.PauseTimer = function(t)
        if not t or t.paused then return end
        t.remaining = remaining(t)
        S:cancel(t.event)
        t.event, t.paused = nil, true
    end
    N.ResumeTimer = function(t)
        if not t or not t.paused then return end
        t.paused = false
        if t.running then schedule(t, t.remaining) end
    end
    N.TimerGetRemaining = function(t) return t and remaining(t) or 0 end
    N.TimerGetTimeout = function(t) return t and t.timeout or 0 end
    N.TimerGetElapsed = function(t) return t and (t.timeout - remaining(t)) or 0 end
    N.GetExpiredTimer = from("timer")
    -- Blizzard.j's
    local function set(name, value) rawset(S.env, name, value) return value end
    N.StartTimerBJ = function(t, periodic, timeout)
        set("bj_lastStartedTimer", t)
        N.TimerStart(t, timeout, periodic, nil)
        return t
    end
    N.CreateTimerBJ = function(periodic, timeout) return N.StartTimerBJ(N.CreateTimer(), periodic, timeout) end
    N.GetLastCreatedTimerBJ = function() return rawget(S.env, "bj_lastStartedTimer") end
    N.PauseTimerBJ = function(pause, t) if pause then N.PauseTimer(t) else N.ResumeTimer(t) end end
    N.DestroyTimerBJ = function(t) N.DestroyTimer(t) end
    -- }}}

    -- {{{ Timer events
    N.TriggerRegisterTimerEvent = function(trig, timeout, periodic)
        local t = S:new_timer()
        t.internal = true
        S:start_timer(t, timeout, periodic, nil)
        t.on_expire = function() S:fire_trigger(trig, { timer = t, event = "EVENT_GAME_TIMER_EXPIRED" }) end
        return S:handle({ kind = "event", timer = t })
    end
    N.TriggerRegisterTimerExpireEvent = function(trig, timer)
        return S:listen(trig, "EVENT_TIMER_EXPIRE", { timer = timer })
    end
    N.TriggerRegisterTimerEventSingle = function(trig, t) return N.TriggerRegisterTimerEvent(trig, t, false) end
    N.TriggerRegisterTimerEventPeriodic = function(trig, t) return N.TriggerRegisterTimerEvent(trig, t, true) end
    N.TriggerRegisterTimerExpireEventBJ = function(trig, t) return N.TriggerRegisterTimerExpireEvent(trig, t) end
    -- }}}
    -- {{{ More of the language: Blizzard.j's arithmetic and conversions
    -- (W02e step 2), as core.lua's and bj.lua's in the VM
    local atan2 = math.atan2 or math.atan
    N.Asin, N.Acos, N.Atan = math.asin, math.acos, math.atan
    N.ISignBJ = function(a) return a > 0 and 1 or (a < 0 and -1 or 0) end
    N.RSignBJ = N.ISignBJ
    N.GetBooleanAnd = function(a, b) return a and b end
    N.GetBooleanOr = function(a, b) return a or b end
    N.SetRandomSeed = function(seed) math.randomseed(seed) end
    N.PercentTo255 = function(p) return math.floor(p * 2.55 + 0.5) end
    N.PercentToInt = function(p, max) return math.floor(p * max / 100 + 0.5) end
    N.GetRandomDirectionDeg = function() return math.random() * 360 end
    N.GetRandomPercentageBJ = function() return math.random() * 100 end
    N.SinBJ = function(d) return math.sin(math.rad(d)) end
    N.CosBJ = function(d) return math.cos(math.rad(d)) end
    N.TanBJ = function(d) return math.tan(math.rad(d)) end
    N.Atan2BJ = function(y, x) return math.deg(atan2(y, x)) end
    N.GetHandleIdBJ = N.GetHandleId
    -- common.j's Convert* make handles from numbers: here, as in the VM, the number
    local function ident(n) return n end
    for name in ([[ConvertPlayerColor ConvertRace ConvertAllianceType ConvertRacePref ConvertIGameState
        ConvertFGameState ConvertPlayerState ConvertPlayerScore ConvertPlayerGameResult ConvertUnitState
        ConvertAIDifficulty ConvertGameEvent ConvertPlayerEvent ConvertPlayerUnitEvent ConvertWidgetEvent
        ConvertDialogEvent ConvertUnitEvent ConvertLimitOp ConvertUnitType ConvertGameSpeed ConvertPlacement
        ConvertStartLocPrio ConvertGameDifficulty ConvertGameType ConvertMapFlag ConvertMapVisibility
        ConvertMapSetting ConvertMapDensity ConvertMapControl ConvertPlayerSlotState ConvertVolumeGroup
        ConvertCameraField ConvertBlendMode ConvertRarityControl ConvertTexMapFlags ConvertFogState
        ConvertEffectType ConvertVersion ConvertItemType ConvertAttackType ConvertDamageType
        ConvertWeaponType ConvertSoundType ConvertPathingType]]):gmatch("%S+") do
        N[name] = ident
    end
    -- the "For each Integer A" loop's variables
    N.GetForLoopIndexA = function() return rawget(S.env, "bj_forLoopAIndex") or 0 end
    N.GetForLoopIndexB = function() return rawget(S.env, "bj_forLoopBIndex") or 0 end
    N.SetForLoopIndexA = function(n) rawset(S.env, "bj_forLoopAIndex", n) end
    N.SetForLoopIndexB = function(n) rawset(S.env, "bj_forLoopBIndex", n) end
    -- Blizzard.j's random distribution (item drop tables)
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
    -- }}}
end

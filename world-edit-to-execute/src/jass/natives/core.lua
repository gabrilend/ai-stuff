--[[
JASS natives: the language's own (Issue 520)

Numbers, strings, conversions, boolexprs, triggers, events, timers and
threads: the common.j natives that don't touch the game world. Written
from the natives' documented behaviour, not from Blizzard's files.

Installed by jass/vm.lua: require("jass.natives.core")(V, N, T), where N
receives the natives and T their return types (the transpiler uses those
to tell integer division from real, and + on strings from numbers).
]]

return function(V, N, T)
    local function typed(kind, names)
        for name in names:gmatch("%S+") do T[name] = kind end
    end

    -- {{{ Numbers
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
    -- leading integer, as WC3 reads "12abc" as 12 and "abc" as 0
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
    N.Asin, N.Acos, N.Atan = math.asin, math.acos, math.atan
    N.Atan2 = function(y, x) return math.atan2(y, x) end
    N.Deg2Rad = math.rad
    N.Rad2Deg = math.deg
    N.ModuloInteger = function(a, b)
        local m = a - trunc(a / b) * b
        if m < 0 then m = m + b end
        return m
    end
    N.ModuloReal = function(a, b)
        local m = a - trunc(a / b) * b
        if m < 0 then m = m + b end
        return m
    end
    N.IMinBJ, N.IMaxBJ, N.RMinBJ, N.RMaxBJ = math.min, math.max, math.min, math.max
    N.IAbsBJ, N.RAbsBJ = math.abs, math.abs
    N.ISignBJ = function(a) return a > 0 and 1 or (a < 0 and -1 or 0) end
    N.RSignBJ = N.ISignBJ
    N.GetBooleanAnd = function(a, b) return a and b end
    N.GetBooleanOr = function(a, b) return a or b end
    N.SetRandomSeed = function(seed) math.randomseed(seed) end
    typed("integer", "R2I S2I GetRandomInt ModuloInteger IMinBJ IMaxBJ IAbsBJ ISignBJ")
    typed("real", "I2R S2R GetRandomReal SquareRoot Pow Sin Cos Tan Asin Acos Atan Atan2 Deg2Rad Rad2Deg ModuloReal RMinBJ RMaxBJ RAbsBJ RSignBJ")
    -- }}}

    -- {{{ Strings
    N.StringLength = function(s) return #(s or "") end
    -- SubString(s, start, end): characters start .. end-1, counted from 0
    N.SubString = function(s, a, b)
        s = s or ""
        return s:sub(math.max(0, a) + 1, math.min(#s, b))
    end
    -- SubStringBJ(s, start, end): 1-based, inclusive
    N.SubStringBJ = function(s, a, b) return N.SubString(s, a - 1, b) end
    N.StringCase = function(s, upper) return upper and (s or ""):upper() or (s or ""):lower() end
    N.StringHash = function(s)
        local h = 0
        for k = 1, #(s or "") do h = (h * 31 + s:byte(k)) % 4294967296 end
        return h >= 2147483648 and h - 4294967296 or h
    end
    typed("integer", "StringLength StringHash")
    typed("string", "I2S R2S R2SW SubString SubStringBJ StringCase")
    -- }}}

    -- {{{ Handles
    N.GetHandleId = function(h)
        if type(h) == "table" then return h.hid or 0 end
        if type(h) == "number" then return h end
        if type(h) == "string" then return N.StringHash(h) end
        return 0
    end
    typed("integer", "GetHandleId")
    -- }}}

    -- {{{ Boolexprs
    N.Condition = function(fn) return fn and V:handle({ kind = "boolexpr", fn = fn }) or nil end
    N.Filter = N.Condition
    N.And = function(a, b) return V:handle({ kind = "boolexpr", op = "and", a = a, b = b }) end
    N.Or = function(a, b) return V:handle({ kind = "boolexpr", op = "or", a = a, b = b }) end
    N.Not = function(a) return V:handle({ kind = "boolexpr", op = "not", a = a }) end
    local function none() end
    N.DestroyBoolExpr, N.DestroyCondition, N.DestroyFilter = none, none, none
    -- }}}

    -- {{{ Triggers
    N.CreateTrigger = function() return V:new_trigger() end
    N.DestroyTrigger = function(t) if t then t.destroyed = true end end
    N.EnableTrigger = function(t) if t then t.enabled = true end end
    N.DisableTrigger = function(t) if t then t.enabled = false end end
    N.IsTriggerEnabled = function(t) return t ~= nil and t.enabled end
    N.TriggerAddAction = function(t, fn)
        if t and fn then t.actions[#t.actions + 1] = fn end
        return V:handle({ kind = "triggeraction", fn = fn })
    end
    N.TriggerRemoveAction = function(t, a)
        for k, fn in ipairs(t.actions) do if fn == a.fn then table.remove(t.actions, k) break end end
    end
    N.TriggerClearActions = function(t) t.actions = {} end
    N.TriggerAddCondition = function(t, bx)
        if t and bx then t.conditions[#t.conditions + 1] = bx end
        return V:handle({ kind = "triggercondition", bx = bx })
    end
    N.TriggerRemoveCondition = function(t, c)
        for k, bx in ipairs(t.conditions) do if bx == c.bx then table.remove(t.conditions, k) break end end
    end
    N.TriggerClearConditions = function(t) t.conditions = {} end
    N.TriggerEvaluate = function(t) return V:trigger_passes(t, V.ctx or {}) end
    -- a new thread, with the caller's event responses
    local function inherit()
        local c = {}
        for k, v in pairs(V.ctx or {}) do c[k] = v end
        return c
    end
    N.TriggerExecute = function(t) if t then V:trigger_execute(t, inherit()) end end
    N.TriggerExecuteWait = N.TriggerExecute
    N.ConditionalTriggerExecute = function(t)
        if t and V:trigger_passes(t, V.ctx or {}) then V:trigger_execute(t, inherit()) end
    end
    N.GetTriggerExecCount = function(t) return t and t.exec_count or 0 end
    N.ResetTrigger = function(t) if t then t.exec_count = 0 end end
    N.TriggerWaitOnSleeps = none
    N.ExecuteFunc = function(name)
        local fn = V.env[name]
        if type(fn) == "function" then V:run_thread(fn, inherit()) end
    end
    typed("integer", "GetTriggerExecCount")
    -- }}}

    -- {{{ Waits
    N.TriggerSleepAction = function(seconds) V:sleep(seconds) end
    N.PolledWait = function(seconds) if seconds and seconds > 0 then V:sleep(seconds) end end
    N.TriggerSyncStart, N.TriggerSyncReady = none, none
    -- }}}

    -- {{{ Timers
    N.CreateTimer = function() return V:new_timer() end
    N.DestroyTimer = function(t) if t then t.destroyed, t.running = true, false end end
    N.TimerStart = function(t, timeout, periodic, fn) if t then V:start_timer(t, timeout, periodic, fn) end end
    N.PauseTimer = function(t) if t then t.paused = true end end
    N.ResumeTimer = function(t) if t then t.paused = false end end
    N.TimerGetRemaining = function(t) return t and math.max(0, t.remaining) or 0 end
    N.TimerGetTimeout = function(t) return t and t.timeout or 0 end
    N.TimerGetElapsed = function(t) return t and (t.timeout - math.max(0, t.remaining)) or 0 end
    N.GetExpiredTimer = function() return V.ctx and V.ctx.timer end
    typed("real", "TimerGetRemaining TimerGetTimeout TimerGetElapsed")
    -- }}}

    -- {{{ Event registration
    -- A trigger fired by its own timer (every `timeout` seconds, or once)
    N.TriggerRegisterTimerEvent = function(trig, timeout, periodic)
        local t = V:new_timer()
        t.internal = true
        V:start_timer(t, timeout, periodic, nil)
        t.on_expire = function() V:fire_trigger(trig, { timer = t, event = "EVENT_GAME_TIMER_EXPIRED" }) end
        return V:handle({ kind = "event", timer = t })
    end
    N.TriggerRegisterTimerExpireEvent = function(trig, timer)
        return V:listen(trig, "EVENT_TIMER_EXPIRE", { timer = timer })
    end
    N.TriggerRegisterPlayerChatEvent = function(trig, p, text, exact)
        return V:listen(trig, "EVENT_PLAYER_CHAT", { player = p, text = text or "", exact = exact })
    end
    -- player unit events: EVENT_PLAYER_UNIT_DEATH and the rest
    N.TriggerRegisterPlayerUnitEvent = function(trig, p, event, filter)
        return V:listen(trig, event, { player = p, filter = filter })
    end
    N.TriggerRegisterUnitEvent = function(trig, u, event)
        return V:listen(trig, event, { unit = u })
    end
    N.TriggerRegisterDeathEvent = function(trig, widget)
        return V:listen(trig, "WIDGET_DEATH", { unit = widget })
    end
    N.TriggerRegisterPlayerEvent = function(trig, p, event)
        return V:listen(trig, event, { player = p })
    end
    N.TriggerRegisterDialogEvent = function(trig, d)
        return V:listen(trig, "EVENT_DIALOG_CLICK", { dialog = d })
    end
    N.TriggerRegisterDialogButtonEvent = function(trig, b)
        return V:listen(trig, "EVENT_DIALOG_BUTTON_CLICK", { button = b })
    end
    -- rects entered and left (regions made of rects)
    local function region_regs(trig, region, filter, enter)
        local event = enter and "EVENT_GAME_ENTER_REGION" or "EVENT_GAME_LEAVE_REGION"
        for _, r in ipairs(region.rects) do
            V:watch_rect({ trig = trig, rect = r, region = region, filter = filter, enter = enter, event = event })
        end
        return V:handle({ kind = "event" })
    end
    N.TriggerRegisterEnterRegion = function(trig, region, filter) return region_regs(trig, region, filter, true) end
    N.TriggerRegisterLeaveRegion = function(trig, region, filter) return region_regs(trig, region, filter, false) end
    -- in range of a unit: checked with the rects (a moving square around it)
    N.TriggerRegisterUnitInRange = function(trig, u, range, filter)
        V.in_range = V.in_range or {}
        V.in_range[#V.in_range + 1] = { trig = trig, unit = u, range = range, filter = filter, inside = {} }
        return V:handle({ kind = "event" })
    end
    N.TriggerRegisterUnitInRangeSimple = function(trig, range, u)
        return N.TriggerRegisterUnitInRange(trig, u, range, nil)
    end
    -- events the world never raises yet: kept, so they could
    local function kept(event_name)
        return function(trig, ...)
            return V:listen(trig, event_name, { args = { ... } })
        end
    end
    N.TriggerRegisterGameStateEvent = kept("GAME_STATE")
    N.TriggerRegisterPlayerStateEvent = kept("PLAYER_STATE")
    N.TriggerRegisterVariableEvent = kept("VARIABLE")
    N.TriggerRegisterGameEvent = kept("GAME")
    N.TriggerRegisterTrackableHitEvent = kept("TRACKABLE_HIT")
    N.TriggerRegisterTrackableTrackEvent = kept("TRACKABLE_TRACK")
    N.TriggerRegisterPlayerAllianceChange = kept("ALLIANCE")
    N.TriggerRegisterUnitStateEvent = kept("UNIT_STATE")
    N.TriggerRegisterFilterUnitEvent = function(trig, u, event) return V:listen(trig, event, { unit = u }) end
    -- }}}

    -- {{{ Event responses (from the running thread's context)
    local function from(field) return function() local c = V.ctx return c and c[field] end end
    N.GetTriggeringTrigger = from("trigger")
    N.GetTriggerEventId = from("event")
    N.GetTriggerUnit = from("unit")
    N.GetTriggerWidget = from("unit")
    N.GetDyingUnit = from("unit")
    N.GetKillingUnit = from("killer")
    N.GetEnteringUnit = from("unit")
    N.GetLeavingUnit = from("unit")
    N.GetTriggeringRegion = from("region")
    N.GetChangingUnit = from("unit")
    N.GetChangingUnitPrevOwner = from("prev_owner")
    N.GetAttacker = from("attacker")
    N.GetAttackedUnitBJ = from("unit")
    N.GetOrderedUnit = from("unit")
    N.GetIssuedOrderId = from("order_id")
    N.GetOrderTargetUnit = from("target")
    N.GetSpellAbilityUnit = from("unit")
    N.GetSpellAbilityId = from("ability")
    N.GetSpellTargetUnit = from("target")
    N.GetLevelingUnit = from("unit")
    N.GetResearchingUnit = from("unit")
    N.GetResearched = from("research")
    N.GetManipulatingUnit = from("unit")
    N.GetManipulatedItem = from("item")
    N.GetSoldItem = from("item")
    N.GetBuyingUnit = from("buyer")
    N.GetSellingUnit = from("unit")
    N.GetTrainedUnit = from("trained")
    N.GetConstructedStructure = from("unit")
    N.GetSummonedUnit = from("unit")
    N.GetEventDamage = from("damage")
    N.GetEventDamageSource = from("attacker")
    N.GetEventTargetUnit = from("target")
    N.GetTriggerPlayer = from("player")
    N.GetEventPlayerChatString = function() local c = V.ctx return c and c.chat or "" end
    N.GetEventPlayerChatStringMatched = function() local c = V.ctx return c and c.matched or "" end
    N.GetClickedButton = from("button")
    N.GetClickedDialog = from("dialog")
    N.GetEnumUnit = from("enum_unit")
    N.GetFilterUnit = from("filter_unit")
    N.GetEnumPlayer = from("enum_player")
    N.GetFilterPlayer = from("filter_player")
    N.GetEnumItem = from("enum_item")
    N.GetFilterItem = from("filter_item")
    N.GetEnumDestructable = from("enum_destructable")
    N.GetFilterDestructable = from("filter_destructable")
    typed("string", "GetEventPlayerChatString GetEventPlayerChatStringMatched")
    typed("integer", "GetIssuedOrderId GetSpellAbilityId GetResearched")
    typed("real", "GetEventDamage")
    -- }}}

    -- {{{ Conversions (common.j's Convert* make handles from numbers)
    local function ident(n) return n end
    for _, name in ipairs({ "ConvertPlayerColor", "ConvertRace", "ConvertAllianceType", "ConvertRacePref",
        "ConvertIGameState", "ConvertFGameState", "ConvertPlayerState", "ConvertPlayerScore",
        "ConvertPlayerGameResult", "ConvertUnitState", "ConvertAIDifficulty", "ConvertGameEvent",
        "ConvertPlayerEvent", "ConvertPlayerUnitEvent", "ConvertWidgetEvent", "ConvertDialogEvent",
        "ConvertUnitEvent", "ConvertLimitOp", "ConvertUnitType", "ConvertGameSpeed", "ConvertPlacement",
        "ConvertStartLocPrio", "ConvertGameDifficulty", "ConvertGameType", "ConvertMapFlag",
        "ConvertMapVisibility", "ConvertMapSetting", "ConvertMapDensity", "ConvertMapControl",
        "ConvertPlayerSlotState", "ConvertVolumeGroup", "ConvertCameraField", "ConvertBlendMode",
        "ConvertRarityControl", "ConvertTexMapFlags", "ConvertFogState", "ConvertEffectType",
        "ConvertVersion", "ConvertItemType", "ConvertAttackType", "ConvertDamageType",
        "ConvertWeaponType", "ConvertSoundType", "ConvertPathingType" }) do
        N[name] = ident
    end
    -- }}}

    -- {{{ Constants with values scripts do arithmetic on (the rest are
    -- their own names: see V:unknown)
    local C = V.constants
    C.bj_PI = math.pi
    C.bj_E = math.exp(1)
    C.bj_DEGTORAD = math.pi / 180
    C.bj_RADTODEG = 180 / math.pi
    C.bj_CELLWIDTH = 128
    C.bj_CLIFFHEIGHT = 128
    C.bj_UNIT_FACING = 270
    C.bj_MAX_PLAYERS = 12
    C.bj_MAX_PLAYER_SLOTS = 16
    C.bj_PLAYER_NEUTRAL_VICTIM = 13
    C.bj_PLAYER_NEUTRAL_EXTRA = 14
    C.PLAYER_NEUTRAL_AGGRESSIVE = 12
    C.PLAYER_NEUTRAL_PASSIVE = 15
    C.bj_MAX_INVENTORY = 6
    C.bj_POLLED_WAIT_INTERVAL = 0.1
    C.bj_POLLED_WAIT_SKIP_THRESHOLD = 2
    C.bj_MAX_QUEUED_TRIGGERS = 100
    C.bj_QUEUED_TRIGGER_TIMEOUT = 180
    C.bj_STOCK_RESTOCK_INITIAL_DELAY = 120
    C.bj_STOCK_RESTOCK_INTERVAL = 30
    C.bj_STOCK_MAX_ITERATIONS = 20
    C.bj_MELEE_MAX_TWINKED_HEROES_V0 = 3
    C.bj_MELEE_MAX_TWINKED_HEROES_V1 = 1
    C.bj_TEXT_DELAY_QUEST = 20
    C.bj_TEXT_DELAY_HINT = 12
    C.bj_TEXT_DELAY_ALWAYSHINT = 12
    C.bj_TEXT_DELAY_UNITACQUIRED = 15
    C.bj_TEXT_DELAY_WARNING = 12
    C.bj_ALLIANCE_UNALLIED = 0
    C.bj_ALLIANCE_UNALLIED_VISION = 1
    C.bj_ALLIANCE_ALLIED = 2
    C.bj_ALLIANCE_ALLIED_VISION = 3
    C.bj_ALLIANCE_ALLIED_UNITS = 4
    C.bj_ALLIANCE_ALLIED_ADVUNITS = 5
    C.bj_ALLIANCE_NEUTRAL = 6
    C.bj_ALLIANCE_NEUTRAL_VISION = 7
    C.bj_HEROSTAT_STR, C.bj_HEROSTAT_AGI, C.bj_HEROSTAT_INT = 0, 1, 2
    C.bj_MODIFYMETHOD_ADD, C.bj_MODIFYMETHOD_SUB, C.bj_MODIFYMETHOD_SET = 0, 1, 2
    C.bj_UNIT_STATE_METHOD_ABSOLUTE, C.bj_UNIT_STATE_METHOD_RELATIVE = 0, 1
    C.bj_UNIT_STATE_METHOD_DEFAULTS, C.bj_UNIT_STATE_METHOD_MAXIMUM = 2, 3
    C.bj_QUESTTYPE_REQ_DISCOVERED, C.bj_QUESTTYPE_REQ_UNDISCOVERED = 0, 1
    C.bj_QUESTTYPE_OPT_DISCOVERED, C.bj_QUESTTYPE_OPT_UNDISCOVERED = 2, 3
    C.bj_TIMETYPE_ADD, C.bj_TIMETYPE_SET, C.bj_TIMETYPE_SUB = 0, 1, 2
    C.bj_KEEPSTATE, C.bj_DISABLE, C.bj_ENABLE = 0, 1, 2  -- (unused shapes kept simple)
    C.bj_forLoopAIndex, C.bj_forLoopBIndex = 0, 0
    C.bj_forLoopAIndexEnd, C.bj_forLoopBIndexEnd = 0, 0
    C.bj_wantDestroyGroup = false
    C.bj_isSinglePlayer = true
    C.bj_gameStarted = false
    C.bj_enumDestructableRadius = 0
    C.bj_stockItemPurchased = nil
    C.bj_randDistCount = 0
    C.PLAYER_COLOR_RED, C.PLAYER_COLOR_BLUE, C.PLAYER_COLOR_CYAN, C.PLAYER_COLOR_PURPLE = 0, 1, 2, 3
    C.PLAYER_COLOR_YELLOW, C.PLAYER_COLOR_ORANGE, C.PLAYER_COLOR_GREEN, C.PLAYER_COLOR_PINK = 4, 5, 6, 7
    C.PLAYER_COLOR_LIGHT_GRAY, C.PLAYER_COLOR_LIGHT_BLUE, C.PLAYER_COLOR_AQUA, C.PLAYER_COLOR_BROWN = 8, 9, 10, 11
    C.JASS_MAX_ARRAY_SIZE = 8192
    C.bj_KEYEVENTTYPE_DEPRESS, C.bj_KEYEVENTTYPE_RELEASE = 0, 1
    C.bj_KEYEVENTKEY_LEFT, C.bj_KEYEVENTKEY_RIGHT, C.bj_KEYEVENTKEY_DOWN, C.bj_KEYEVENTKEY_UP = 0, 1, 2, 3
    C.bj_SORTTYPE_SORTBYVALUE, C.bj_SORTTYPE_SORTBYPLAYER, C.bj_SORTTYPE_SORTBYLABEL = 0, 1, 2
    C.bj_CINEFADETYPE_FADEIN, C.bj_CINEFADETYPE_FADEOUT, C.bj_CINEFADETYPE_FADEOUTIN = 0, 1, 2
    C.bj_SMARTPAN_TRESHOLD_PAN, C.bj_SMARTPAN_TRESHOLD_SNAP = 500, 3500
    C.bj_CAMERA_MIN_FARZ = 100
    C.bj_WAIT_FOR_COND_MIN_INTERVAL = 0.1
    -- their JASS types, so + and / on them are typed when transpiling
    local GT = V.global_types
    for name in ([[bj_forLoopAIndex bj_forLoopBIndex bj_forLoopAIndexEnd bj_forLoopBIndexEnd bj_MAX_PLAYERS
        bj_MAX_PLAYER_SLOTS bj_PLAYER_NEUTRAL_VICTIM bj_PLAYER_NEUTRAL_EXTRA PLAYER_NEUTRAL_AGGRESSIVE
        PLAYER_NEUTRAL_PASSIVE bj_MAX_INVENTORY bj_MAX_QUEUED_TRIGGERS bj_STOCK_MAX_ITERATIONS
        bj_MELEE_MAX_TWINKED_HEROES_V0 bj_MELEE_MAX_TWINKED_HEROES_V1 bj_ALLIANCE_UNALLIED bj_ALLIANCE_ALLIED
        bj_ALLIANCE_ALLIED_VISION bj_ALLIANCE_NEUTRAL bj_HEROSTAT_STR bj_HEROSTAT_AGI bj_HEROSTAT_INT
        bj_MODIFYMETHOD_ADD bj_MODIFYMETHOD_SUB bj_MODIFYMETHOD_SET bj_randDistCount bj_queuedExecTotal
        bj_groupEnumTypeId bj_livingPlayerUnitsTypeId JASS_MAX_ARRAY_SIZE bj_meleeTwinkedHeroes
        bj_randDistID bj_randDistChance bj_groupCountUnits bj_groupRandomConsidered]]):gmatch("%S+") do
        GT[name] = "integer"
    end
    for name in ([[bj_PI bj_E bj_DEGTORAD bj_RADTODEG bj_CELLWIDTH bj_CLIFFHEIGHT bj_UNIT_FACING
        bj_POLLED_WAIT_INTERVAL bj_POLLED_WAIT_SKIP_THRESHOLD bj_QUEUED_TRIGGER_TIMEOUT
        bj_STOCK_RESTOCK_INITIAL_DELAY bj_STOCK_RESTOCK_INTERVAL bj_TEXT_DELAY_QUEST bj_TEXT_DELAY_HINT
        bj_TEXT_DELAY_ALWAYSHINT bj_TEXT_DELAY_UNITACQUIRED bj_TEXT_DELAY_WARNING bj_SMARTPAN_TRESHOLD_PAN
        bj_SMARTPAN_TRESHOLD_SNAP bj_CAMERA_MIN_FARZ bj_WAIT_FOR_COND_MIN_INTERVAL bj_enumDestructableRadius]]):gmatch("%S+") do
        GT[name] = "real"
    end
    C.bj_cineSceneBeingSkipped = false
    C.bj_cineModeAlreadyIn = false
    -- Blizzard.j's arrays (maps that inline InitBlizzard fill them in)
    local function array(default) return setmetatable({}, { __index = function() return default end }) end
    for name, default in pairs({ bj_queuedExecTriggers = false, bj_queuedExecUseConds = false,
        bj_meleeDefeated = false, bj_meleeVictoried = false, bj_meleeTwinkedHeroes = 0,
        bj_playerIsCrippled = false, bj_playerIsExposed = false, bj_crippledTimer = false,
        bj_crippledTimerWindows = false, bj_randDistID = 0, bj_randDistChance = 0,
        bj_ghoul = false, bj_rescueUnitBehavior = false,
        bj_stockAllowedPermanent = false, bj_stockAllowedCharged = false, bj_stockAllowedArtifact = false }) do
        C[name] = array(default ~= false and default or nil)
    end
    C.bj_queuedExecTotal = 0
    -- }}}
end

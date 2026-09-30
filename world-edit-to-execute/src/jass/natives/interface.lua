--[[
JASS natives: what players see and hear (Issue 520)

Messages, dialogs, quests, timer windows, multiboards, victory and
defeat are kept on the VM for the interface to show (ui/wc3/hud.lua reads
V.messages, V:shown_dialogs(), V.timer_dialogs, V.quests,
V.multiboards). Only what the local player would see is shown.

Fog of war is in natives/fog.lua (Issue 524). Sound, music, camera,
weather, special effects, cinematics and floating text do nothing yet (there is no system for them) and are
counted in V.noops.
]]

return function(V, N, T)
    local function typed(kind, names)
        for name in names:gmatch("%S+") do T[name] = kind end
    end
    local function noop(names, value)
        for name in names:gmatch("%S+") do
            V.noop[name] = true
            N[name] = function()
                V.noops[name] = (V.noops[name] or 0) + 1
                return value
            end
        end
    end
    local function mine(p) return p ~= nil and p.id == V.local_id end
    local function for_me(f) return f ~= nil and f.players[V.local_id] ~= nil end

    -- {{{ Messages
    N.DisplayTextToPlayer = function(p, x, y, msg) if mine(p) then V:message(msg, 10) end end
    N.DisplayTimedTextToPlayer = function(p, x, y, t, msg) if mine(p) then V:message(msg, t) end end
    N.DisplayTimedTextFromPlayer = function(p, x, y, t, msg) if mine(p) then V:message(msg, t) end end
    N.ClearTextMessages = function() V.messages = {} end
    -- }}}

    -- {{{ Dialogs
    N.DialogCreate = function()
        local d = V:handle({ kind = "dialog", message = "", buttons = {}, shown = {} })
        V.dialogs[#V.dialogs + 1] = d
        return d
    end
    N.DialogDestroy = function(d) if d then d.destroyed = true end end
    N.DialogClear = function(d) if d then d.buttons, d.message = {}, "" end end
    N.DialogSetMessage = function(d, msg) if d then d.message = msg or "" end end
    N.DialogAddButton = function(d, text, hotkey)
        local b = V:handle({ kind = "button", dialog = d, text = text or "", hotkey = hotkey })
        d.buttons[#d.buttons + 1] = b
        return b
    end
    N.DialogAddQuitButton = function(d, score, text, hotkey)
        local b = N.DialogAddButton(d, text, hotkey)
        b.quit = true
        return b
    end
    N.DialogDisplay = function(p, d, flag) if p and d then d.shown[p.id] = flag and true or false end end
    -- }}}

    -- {{{ Quests
    N.CreateQuest = function()
        local q = V:handle({ kind = "quest", title = "", description = "", required = true, discovered = true,
                             completed = false, failed = false, enabled = true, items = {} })
        V.quests[#V.quests + 1] = q
        return q
    end
    N.DestroyQuest = function(q) if q then q.destroyed = true end end
    N.QuestSetTitle = function(q, s) if q then q.title = s end end
    N.QuestSetDescription = function(q, s) if q then q.description = s end end
    N.QuestSetIconPath = function(q, s) if q then q.icon = s end end
    N.QuestSetRequired = function(q, f) if q then q.required = f end end
    N.QuestSetCompleted = function(q, f) if q then q.completed = f end end
    N.QuestSetFailed = function(q, f) if q then q.failed = f end end
    N.QuestSetDiscovered = function(q, f) if q then q.discovered = f end end
    N.QuestSetEnabled = function(q, f) if q then q.enabled = f end end
    N.IsQuestCompleted = function(q) return q ~= nil and q.completed end
    N.IsQuestFailed = function(q) return q ~= nil and q.failed end
    N.IsQuestDiscovered = function(q) return q ~= nil and q.discovered end
    N.IsQuestRequired = function(q) return q ~= nil and q.required end
    N.QuestCreateItem = function(q)
        local it = { kind = "questitem", text = "", completed = false }
        q.items[#q.items + 1] = it
        return it
    end
    N.QuestItemSetDescription = function(it, s) if it then it.text = s end end
    N.QuestItemSetCompleted = function(it, f) if it then it.completed = f end end
    N.FlashQuestDialogButton = function() V.quest_flash = V.time end
    noop("QuestSetIconPath ForceQuestDialogUpdate CreateDefeatCondition DefeatConditionSetDescription DestroyDefeatCondition")
    -- }}}

    -- {{{ Timer dialogs (the countdown windows)
    N.CreateTimerDialog = function(t)
        local td = V:handle({ kind = "timerdialog", timer = t, title = "", shown = false })
        V.timer_dialogs[#V.timer_dialogs + 1] = td
        return td
    end
    N.DestroyTimerDialog = function(td) if td then td.destroyed, td.shown = true, false end end
    N.TimerDialogSetTitle = function(td, s) if td then td.title = s or "" end end
    N.TimerDialogDisplay = function(td, flag) if td then td.shown = flag and true or false end end
    N.IsTimerDialogDisplayed = function(td) return td ~= nil and td.shown end
    N.TimerDialogSetTitleColor = function() end
    N.TimerDialogSetTimeColor = function() end
    N.TimerDialogSetSpeed = function() end
    N.TimerDialogSetRealTimeRemaining = function(td, r) if td and td.timer then td.timer.remaining = r end end
    -- }}}

    -- {{{ Multiboards
    N.CreateMultiboard = function()
        local mb = V:handle({ kind = "multiboard", title = "", rows = 0, cols = 0, cells = {}, shown = false })
        V.multiboards[#V.multiboards + 1] = mb
        return mb
    end
    N.DestroyMultiboard = function(mb) if mb then mb.destroyed, mb.shown = true, false end end
    N.MultiboardSetTitleText = function(mb, s) if mb then mb.title = s end end
    N.MultiboardGetTitleText = function(mb) return mb and mb.title or "" end
    N.MultiboardSetRowCount = function(mb, n) if mb then mb.rows = n end end
    N.MultiboardSetColumnCount = function(mb, n) if mb then mb.cols = n end end
    N.MultiboardGetRowCount = function(mb) return mb and mb.rows or 0 end
    N.MultiboardGetColumnCount = function(mb) return mb and mb.cols or 0 end
    N.MultiboardDisplay = function(mb, flag) if mb then mb.shown = flag and true or false end end
    N.MultiboardMinimize = function(mb, flag) if mb then mb.minimized = flag end end
    N.MultiboardGetItem = function(mb, row, col) return { board = mb, row = row, col = col } end
    N.MultiboardReleaseItem = function() end
    N.MultiboardSetItemValue = function(item, s)
        local mb = item.board
        mb.cells[item.row * 64 + item.col] = s
    end
    N.MultiboardSetItemStyle = function() end
    N.MultiboardSetItemWidth = function() end
    N.MultiboardSetItemIcon = function() end
    N.MultiboardSetItemValueColor = function() end
    N.MultiboardSetItemsStyle = function() end
    N.MultiboardSetItemsWidth = function() end
    N.MultiboardSetItemsValueColor = function() end
    N.MultiboardSetItemsIcon = function() end
    N.MultiboardSetTitleTextColor = function() end
    typed("string", "MultiboardGetTitleText")
    typed("integer", "MultiboardGetRowCount MultiboardGetColumnCount")
    -- }}}

    -- {{{ Leaderboards (kept, not shown)
    N.CreateLeaderboard = function() return V:handle({ kind = "leaderboard", items = {} }) end
    noop("DestroyLeaderboard LeaderboardDisplay LeaderboardSetLabel LeaderboardAddItem LeaderboardSetItemValue "
      .. "LeaderboardSetSizeByItemCount PlayerSetLeaderboard LeaderboardSetStyle LeaderboardSortItemsByValue")
    -- }}}

    -- {{{ Victory and defeat (the local player's outcome)
    N.CustomVictoryBJ = function(p, dialogs, scores)
        if mine(p) then V.outcome = "victory"; V:message("Victory!", 3600) end
        if p then p.result = "victory" end
    end
    N.CustomDefeatBJ = function(p, msg)
        if mine(p) then V.outcome = "defeat"; V:message(msg or "Defeat", 3600) end
        if p then p.result = "defeat" end
    end
    N.EndGame = function() V.ended = true end
    -- }}}

    -- {{{ The rest: no system yet
    noop("SetCameraBounds SetCameraPosition SetCameraQuickPosition SetCameraField SetCameraTargetController "
      .. "SetCameraOrientController SetCameraRotateMode PanCameraTo PanCameraToTimed PanCameraToWithZ "
      .. "PanCameraToTimedWithZ SmartCameraPanBJ ResetToGameCamera StopCamera CameraSetupApply "
      .. "CameraSetupApplyForceDuration CameraSetupApplyWithZ CameraSetupSetField CameraSetupSetDestPosition "
      .. "SetCameraFieldForPlayer PanCameraToTimedLocForPlayer PanCameraToLocForPlayer SetCameraBoundsToRect "
      .. "SetCameraBoundsToRectForPlayerBJ CameraSetEQNoiseForPlayer CameraClearNoiseForPlayer CameraSetSmoothingFactor "
      .. "SetCameraTargetControllerNoZForPlayer ResetToGameCameraForPlayer CameraSetupApplyForPlayer "
      .. "SetCinematicCamera SetDayNightModels NewSoundEnvironment SetAmbientDaySound SetAmbientNightSound "
      .. "SetMapMusic PlayMusic PlayMusicEx StopMusic ResumeMusic PlayThematicMusic PlayThematicMusicEx EndThematicMusic "
      .. "SetMusicVolume SetMusicPlayPosition ClearMapMusic VolumeGroupSetVolume VolumeGroupReset "
      .. "SetSoundParamsFromLabel SetSoundDuration SetSoundChannel SetSoundVolume SetSoundPitch SetSoundPosition "
      .. "SetSoundDistances SetSoundDistanceCutoff SetSoundConeAngles SetSoundConeOrientation SetSoundVelocity "
      .. "AttachSoundToUnit StartSound StopSound KillSoundWhenDone SetSoundPlayPosition RegisterStackedSound "
      .. "UnregisterStackedSound PlaySoundBJ StopSoundBJ PlaySoundAtPointBJ PlaySoundOnUnitBJ PlaySoundFromOffsetBJ "
      .. "SetSoundVolumeBJ KillSoundWhenDoneBJ StartSoundForPlayerBJ SetStackedSound "
      .. "SetTerrainFogEx ResetTerrainFog EnableWorldFogBoundary "
      .. "SetUnitTypeSlots AddWeatherEffect EnableWeatherEffect RemoveWeatherEffect "
      .. "SetTerrainType SetTerrainTypeBJ SetTerrainPathable AddLightning DestroyLightning MoveLightning "
      .. "PingMinimap PingMinimapEx PingMinimapLocForForce PingMinimapForForce PingMinimapForForceEx "
      .. "SetTextTagText SetTextTagPos SetTextTagPosUnit SetTextTagColor SetTextTagVelocity SetTextTagVisibility "
      .. "SetTextTagSuspended SetTextTagPermanent SetTextTagAge SetTextTagLifespan SetTextTagFadepoint DestroyTextTag "
      .. "CinematicModeBJ CinematicModeExBJ CinematicFadeBJ CinematicFilterGenericBJ ShowInterface EnableUserControl "
      .. "EnableUserUI EnableOcclusion SetCineFilterTexture DisplayCineFilter TransmissionFromUnitWithNameBJ "
      .. "TransmissionFromUnitTypeWithNameBJ SetCinematicScene EndCinematicScene ForceCinematicSubtitles "
      .. "SetDoodadAnimationRectBJ SetDoodadAnimationBJ SetSkyModel EnablePreSelect EnableSelect EnableDragSelect "
      .. "SetTimeOfDayScale SuspendTimeOfDay UseTimeOfDayBJ SetCreepCampFilterState SetAllyColorFilterState "
      .. "EnableMinimapFilterButtons SetReservedLocalHeroButtons StartMeleeAI StartCampaignAI CommandAI "
      .. "PauseCompAI SetGameSpeed LockGameSpeedBJ SetMapFlag SetResourceDensity SetCreatureDensity "
      .. "SetTutorialCleared SetMissionAvailable SetCampaignAvailable SetCampaignMenuRace SetFloatGameState "
      .. "SetIntegerGameState SetPlayerSlotAvailable SetDefaultDifficulty ShowUnitTeamGlow SetPortraitLight "
      .. "SetWaterBaseColor SetWaterDeforms SetBlight SetBlightRect SetBlightPoint SetBlightLoc Preload PreloadEnd "
      .. "PreloadStart PreloadRefresh PreloadEndEx PreloadGenClear PreloadGenStart PreloadGenEnd Preloader")
    noop("CreateSound CreateSoundFromLabel CreateSoundFilenameWithLabel CreateMIDISound "
      .. "CreateCameraSetup "
      .. "CreateTextTag CreateTextTagLocBJ CreateTextTagUnitBJ CreateTrackable CreateUbersplat CreateImage CreateBlightedGoldmine",
      nil)
    N.GetSoundDuration = function() return 0 end
    N.GetSoundFileDuration = function() return 0 end
    N.GetCameraMargin = function() return 0 end
    N.GetCameraField = function() return 0 end
    N.GetCameraTargetPositionX = function() return 0 end
    N.GetCameraTargetPositionY = function() return 0 end
    N.GetTimeOfDay = function() return V.world.time_of_day and V.world.time_of_day() or 12 end
    N.IsUnitSelected = function(u) return u ~= nil and u.selected == true end
    N.GetFloatGameState = function(s)
        if s == "GAME_STATE_TIME_OF_DAY" then return N.GetTimeOfDay() end
        return 0
    end
    N.GetIntegerGameState = function() return 0 end
    N.IsMapFlagSet = function() return false end
    N.GetGameSpeed = function() return "MAP_SPEED_NORMAL" end
    N.GetGameDifficulty = function() return "MAP_DIFFICULTY_NORMAL" end
    N.ReloadGameCachesFromDisk = function() return false end
    N.InitGameCache = function(name) return V:handle({ kind = "gamecache", name = name, data = {} }) end
    N.InitHashtable = function() return V:handle({ kind = "hashtable", data = {} }) end
    -- hashtables: (parent, child) keys; each value type in its own store,
    -- as WC3 keeps them (an integer and a real under one key don't clash)
    local function store(ht, kind, parent)
        local d = ht.data[kind]
        if not d then d = {}; ht.data[kind] = d end
        local p = d[parent]
        if not p then p = {}; d[parent] = p end
        return p
    end
    local HT = { Integer = { "integer", 0 }, Real = { "real", 0 }, Boolean = { "boolean", false },
                 Str = { "string", "" } }
    for suffix, info in pairs(HT) do
        local kind, default = info[1], info[2]
        N["Save" .. suffix] = function(ht, p, c, v) if ht then store(ht, kind, p)[c] = v end end
        N["Load" .. suffix] = function(ht, p, c)
            local v = ht and store(ht, kind, p)[c]
            if v == nil then return default end
            return v
        end
        N["HaveSaved" .. (suffix == "Str" and "String" or suffix)] = function(ht, p, c)
            return ht ~= nil and store(ht, kind, p)[c] ~= nil
        end
        N["RemoveSaved" .. (suffix == "Str" and "String" or suffix)] = function(ht, p, c)
            if ht then store(ht, kind, p)[c] = nil end
        end
        T["Load" .. suffix] = kind
    end
    for _, h in ipairs({ "Player", "Widget", "Destructable", "Item", "Unit", "Ability", "Timer", "Trigger",
        "TriggerCondition", "TriggerAction", "TriggerEvent", "Force", "Group", "Location", "Rect", "BooleanExpr",
        "Sound", "Effect", "UnitPool", "ItemPool", "Quest", "QuestItem", "DefeatCondition", "TimerDialog",
        "Leaderboard", "Multiboard", "MultiboardItem", "Trackable", "Dialog", "Button", "TextTag", "Lightning",
        "Image", "Ubersplat", "Region", "FogState", "FogModifier", "Hashtable" }) do
        N["Save" .. h .. "Handle"] = function(ht, p, c, v) if ht then store(ht, "handle", p)[c] = v end end
        N["Load" .. h .. "Handle"] = function(ht, p, c) return ht and store(ht, "handle", p)[c] end
    end
    N.HaveSavedHandle = function(ht, p, c) return ht ~= nil and store(ht, "handle", p)[c] ~= nil end
    N.RemoveSavedHandle = function(ht, p, c) if ht then store(ht, "handle", p)[c] = nil end end
    N.FlushChildHashtable = function(ht, p)
        if ht then for _, d in pairs(ht.data) do d[p] = nil end end
    end
    N.FlushParentHashtable = function(ht) if ht then ht.data = {} end end
    -- game caches: one store, by mission and key
    local function cache(gc, kind, mission)
        gc.data[kind] = gc.data[kind] or {}
        gc.data[kind][mission] = gc.data[kind][mission] or {}
        return gc.data[kind][mission]
    end
    for suffix, info in pairs(HT) do
        local kind, default = info[1], info[2]
        N["Store" .. (suffix == "Str" and "String" or suffix)] = function(gc, m, k, v) if gc then cache(gc, kind, m)[k] = v end end
        N["GetStored" .. (suffix == "Str" and "String" or suffix)] = function(gc, m, k)
            local v = gc and cache(gc, kind, m)[k]
            if v == nil then return default end
            return v
        end
        T["GetStored" .. (suffix == "Str" and "String" or suffix)] = kind
    end
    N.FlushGameCache = function(gc) if gc then gc.data = {} end end
    N.SaveGameCache = function() return true end
    typed("real", "GetSoundDuration GetSoundFileDuration GetCameraMargin GetCameraField GetCameraTargetPositionX GetCameraTargetPositionY GetTimeOfDay GetFloatGameState")
    typed("integer", "GetIntegerGameState")
    -- }}}
end

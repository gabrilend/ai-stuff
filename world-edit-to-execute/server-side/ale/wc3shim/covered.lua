-- wc3shim: every native (and Blizzard.j function) the shim implements, by
-- group (issue W02e). Licence: GNU AGPL v3 (server-side/LICENSE).
--
-- Data only: the converter (src/wowbuild/triggers.lua) reads this file in
-- an empty environment to write each map's coverage report, and runs none
-- of the shim. src/tests/test_wow_triggers.lua checks that these names are
-- exactly the ones the shim installs. Add a name here when its native is
-- added to core.lua or world.lua.
return {
    version = 1,
    groups = {
        { name = "language", about = "numbers, strings, conversions: plain Lua",
          names = "I2R R2I I2S R2S R2SW S2I S2R GetRandomInt GetRandomReal SquareRoot Pow Sin Cos Tan Atan2 Deg2Rad Rad2Deg ModuloInteger ModuloReal IMinBJ IMaxBJ RMinBJ RMaxBJ IAbsBJ RAbsBJ StringLength SubString SubStringBJ StringCase GetHandleId" },
        { name = "triggers", about = "triggers, conditions, actions, boolexprs, event responses",
          names = "CreateTrigger DestroyTrigger EnableTrigger DisableTrigger IsTriggerEnabled TriggerAddAction TriggerRemoveAction TriggerClearActions TriggerAddCondition TriggerRemoveCondition TriggerClearConditions TriggerEvaluate TriggerExecute ConditionalTriggerExecute TriggerExecuteBJ GetTriggerExecCount ExecuteFunc DoNothing GetTriggeringTrigger GetTriggerEventId Condition Filter And Or Not DestroyBoolExpr DestroyCondition DestroyFilter" },
        { name = "timers", about = "timers and timer events, on ALE's timed events",
          names = "CreateTimer DestroyTimer TimerStart PauseTimer ResumeTimer TimerGetRemaining TimerGetTimeout TimerGetElapsed GetExpiredTimer StartTimerBJ CreateTimerBJ GetLastCreatedTimerBJ PauseTimerBJ DestroyTimerBJ TriggerRegisterTimerEvent TriggerRegisterTimerExpireEvent TriggerRegisterTimerEventSingle TriggerRegisterTimerEventPeriodic TriggerRegisterTimerExpireEventBJ" },
        { name = "waits", about = "a trigger's thread waits",
          names = "TriggerSleepAction TriggerSleepActionBJ PolledWait" },
        { name = "players", about = "players and their gold, lumber and other states",
          names = "Player GetLocalPlayer GetPlayerId ConvertedPlayer GetConvertedPlayerId GetPlayerState SetPlayerState SetPlayerStateBJ AdjustPlayerStateBJ AdjustPlayerStateSimpleBJ TriggerRegisterPlayerStateEvent GetTriggerPlayer" },
        { name = "units", about = "units made at a point (creatures), where they stand, removed",
          names = "CreateUnit CreateUnitAtLoc CreateUnitAtLocSaveLast GetLastCreatedUnit RemoveUnit GetUnitTypeId GetOwningPlayer GetUnitX GetUnitY GetUnitLoc GetUnitFacing" },
        { name = "places", about = "locations and rects",
          names = "Location RemoveLocation MoveLocation GetLocationX GetLocationY Rect RectFromLoc RemoveRect SetRect MoveRectTo GetRectCenterX GetRectCenterY GetRectCenter GetRectMinX GetRectMinY GetRectMaxX GetRectMaxY RectContainsCoords" },
        { name = "regions", about = "regions, and units entering and leaving them",
          names = "CreateRegion RemoveRegion RegionAddRect TriggerRegisterEnterRegion TriggerRegisterLeaveRegion TriggerRegisterEnterRectSimple TriggerRegisterLeaveRectSimple GetTriggerUnit GetEnteringUnit GetLeavingUnit GetTriggeringRegion GetFilterUnit" },
    },
}

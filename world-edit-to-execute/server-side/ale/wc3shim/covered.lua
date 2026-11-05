-- wc3shim: every native (and Blizzard.j function) the shim implements, by
-- group (issue W02e). Licence: GNU AGPL v3 (server-side/LICENSE).
--
-- Data only: the converter (src/wowbuild/triggers.lua) reads this file in
-- an empty environment to write each map's coverage report, and runs none
-- of the shim. src/tests/test_wow_triggers.lua checks that these names are
-- exactly the ones the shim installs. Add a name here when its native is
-- added to one of the shim's modules (init.lua's shim.MODULES).
return {
    version = 2,
    groups = {
        { name = "language", about = "numbers, strings, conversions, Blizzard.j's arithmetic and random tables: plain Lua",
          names = [[I2R R2I I2S R2S R2SW S2I S2R GetRandomInt GetRandomReal SquareRoot Pow Sin Cos Tan Atan2 Deg2Rad
                  Rad2Deg ModuloInteger ModuloReal IMinBJ IMaxBJ RMinBJ RMaxBJ IAbsBJ RAbsBJ StringLength
                  SubString SubStringBJ StringCase GetHandleId Acos Asin Atan Atan2BJ ConvertAIDifficulty
                  ConvertAllianceType ConvertAttackType ConvertBlendMode ConvertCameraField ConvertDamageType
                  ConvertDialogEvent ConvertEffectType ConvertFGameState ConvertFogState ConvertGameDifficulty
                  ConvertGameEvent ConvertGameSpeed ConvertGameType ConvertIGameState ConvertItemType
                  ConvertLimitOp ConvertMapControl ConvertMapDensity ConvertMapFlag ConvertMapSetting
                  ConvertMapVisibility ConvertPathingType ConvertPlacement ConvertPlayerColor ConvertPlayerEvent
                  ConvertPlayerGameResult ConvertPlayerScore ConvertPlayerSlotState ConvertPlayerState
                  ConvertPlayerUnitEvent ConvertRace ConvertRacePref ConvertRarityControl ConvertSoundType
                  ConvertStartLocPrio ConvertTexMapFlags ConvertUnitEvent ConvertUnitState ConvertUnitType
                  ConvertVersion ConvertVolumeGroup ConvertWeaponType ConvertWidgetEvent CosBJ GetBooleanAnd
                  GetBooleanOr GetForLoopIndexA GetForLoopIndexB GetHandleIdBJ GetRandomDirectionDeg
                  GetRandomPercentageBJ ISignBJ PercentTo255 PercentToInt RSignBJ RandomDistAddItem
                  RandomDistChoose RandomDistReset SetForLoopIndexA SetForLoopIndexB SetRandomSeed SinBJ TanBJ]] },
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
        { name = "places", about = "locations, rects, points in regions, the map's area, geometry",
          names = [[Location RemoveLocation MoveLocation GetLocationX GetLocationY Rect RectFromLoc RemoveRect
                  SetRect MoveRectTo GetRectCenterX GetRectCenterY GetRectCenter GetRectMinX GetRectMinY
                  GetRectMaxX GetRectMaxY RectContainsCoords AngleBetweenPoints DistanceBetweenPoints
                  GetCameraBoundsMapRect GetEntireMapRect GetPlayableMapRect GetRandomLocInRect GetRectHeightBJ
                  GetRectWidthBJ GetWorldBounds IsLocationInRegion IsPointInRegion MoveRectToLoc OffsetLocation
                  OffsetRectBJ PolarProjectionBJ RectContainsLoc RectFromCenterSizeBJ]] },
        { name = "regions", about = "regions, and units entering and leaving them",
          names = "CreateRegion RemoveRegion RegionAddRect TriggerRegisterEnterRegion TriggerRegisterLeaveRegion TriggerRegisterEnterRectSimple TriggerRegisterLeaveRectSimple GetTriggerUnit GetEnteringUnit GetLeavingUnit GetTriggeringRegion GetFilterUnit" },
        { name = "player slots", about = "a player's slot, name, colour, team, start location and tech limits; the map's setup (config())",
          names = [[AddPlayerTechResearched CachePlayerHeroData DefineStartLocation DefineStartLocationLoc
                  GetPlayerColor GetPlayerController GetPlayerName GetPlayerRace GetPlayerSlotState
                  GetPlayerStartLocation GetPlayerStartLocationLoc GetPlayerStartLocationX GetPlayerStartLocationY
                  GetPlayerTeam GetPlayerTechCount GetPlayerTechCountSimple GetPlayerTechMaxAllowed
                  GetPlayerTechResearched GetPlayerTypedUnitCount GetPlayerUnitCount GetPlayers
                  GetStartLocationLoc GetStartLocationX GetStartLocationY GetTeams IsPlayerObserver RemovePlayer
                  SetGamePlacement SetMapDescription SetMapName SetPlayerAbilityAvailable
                  SetPlayerAbilityAvailableBJ SetPlayerColor SetPlayerColorBJ SetPlayerController SetPlayerFlagBJ
                  SetPlayerHandicap SetPlayerHandicapBJ SetPlayerHandicapXP SetPlayerHandicapXPBJ
                  SetPlayerMaxHeroesAllowed SetPlayerName SetPlayerOnScoreScreen SetPlayerOnScoreScreenBJ
                  SetPlayerRacePreference SetPlayerRaceSelectable SetPlayerStartLocation SetPlayerTeam
                  SetPlayerTechMaxAllowed SetPlayerTechMaxAllowedSwap SetPlayerTechResearched
                  SetPlayerTechResearchedSwap SetPlayerUnitAvailableBJ SetPlayers SetStartLocPrio
                  SetStartLocPrioCount SetTeams]] },
        { name = "alliances", about = "alliances and Blizzard.j's alliance levels, kept per player",
          names = [[ConfigureNeutralVictim GetPlayerAlliance IsPlayerAlly IsPlayerEnemy MakeUnitsPassiveForPlayer
                  MakeUnitsPassiveForTeam SetForceAllianceStateBJ SetPlayerAlliance SetPlayerAllianceBJ
                  SetPlayerAllianceStateAllyBJ SetPlayerAllianceStateBJ SetPlayerAllianceStateControlBJ
                  SetPlayerAllianceStateFullControlBJ SetPlayerAllianceStateVisionBJ ShareEverythingWithTeam]] },
        { name = "forces", about = "forces, ForForce and their enumerations; bj_FORCE_ALL_PLAYERS and bj_FORCE_PLAYER",
          names = [[CountPlayersInForceBJ CreateForce DestroyForce ForForce ForForceBJ ForceAddPlayer
                  ForceAddPlayerSimple ForceClear ForceEnumAllies ForceEnumEnemies ForceEnumPlayers
                  ForcePlayerStartLocation ForceRemovePlayer ForceRemovePlayerSimple GetEnumPlayer GetFilterPlayer
                  GetForceOfPlayer GetPlayersAll GetPlayersAllies GetPlayersByMapControl GetPlayersEnemies
                  GetPlayersMatching IsPlayerInForce IsPlayerInForceBJ]] },
        { name = "messages", about = "text to players: every player named (opts.on_message), TRIGSTR_ resolved",
          names = [[ClearTextMessages DisplayTextToForce DisplayTextToPlayer DisplayTimedTextFromPlayer
                  DisplayTimedTextToForce DisplayTimedTextToPlayer QuestMessageBJ]] },
        { name = "player events", about = "chat and players' events, raised by S:chat and S:player_event",
          names = [[GetEventPlayerChatString GetEventPlayerChatStringMatched TriggerRegisterPlayerChatEvent
                  TriggerRegisterPlayerEvent TriggerRegisterPlayerEventDefeat
                  TriggerRegisterPlayerEventEndCinematic TriggerRegisterPlayerEventLeave
                  TriggerRegisterPlayerEventVictory]] },
        { name = "unit state", about = "life (mirrored onto the creature), death, owner, position, facing, flags, types, ranges, abilities, waygates",
          names = [[ExplodeUnitBJ GetLastReplacedUnitBJ GetUnitAbilityLevel GetUnitAbilityLevelSwapped
                  GetUnitAcquireRange GetUnitDefaultMoveSpeed GetUnitLevel GetUnitLifePercent GetUnitManaPercent
                  GetUnitMoveSpeed GetUnitName GetUnitPointValue GetUnitState GetUnitStatePercent GetUnitStateSwap
                  GetUnitUserData GetWidgetLife IsUnit IsUnitAliveBJ IsUnitAlly IsUnitDeadBJ IsUnitEnemy
                  IsUnitHidden IsUnitHiddenBJ IsUnitIllusionBJ IsUnitInRange IsUnitInRangeLoc IsUnitInRangeLocBJ
                  IsUnitInRangeXY IsUnitInRegion IsUnitInvulnerable IsUnitOwnedByPlayer IsUnitPaused
                  IsUnitPausedBJ IsUnitType KillUnit PauseUnit PauseUnitBJ RectContainsUnit ReplaceUnitBJ
                  SetUnitAbilityLevel SetUnitAbilityLevelSwapped SetUnitAcquireRange SetUnitAcquireRangeBJ
                  SetUnitColor SetUnitExploded SetUnitFacing SetUnitFacingTimed SetUnitFacingToFaceLocTimed
                  SetUnitFacingToFaceUnitTimed SetUnitInvulnerable SetUnitInvulnerableBJ SetUnitLifeBJ
                  SetUnitLifePercentBJ SetUnitManaBJ SetUnitManaPercentBJ SetUnitMoveSpeed SetUnitOwner
                  SetUnitPosition SetUnitPositionLoc SetUnitPositionLocFacingBJ SetUnitPositionLocFacingLocBJ
                  SetUnitState SetUnitUserData SetUnitUserDataBJ SetUnitX SetUnitY SetWidgetLife ShowUnit
                  ShowUnitHide ShowUnitShow UnitAddAbility UnitAddAbilityBJ UnitAlive UnitApplyTimedLife
                  UnitApplyTimedLifeBJ UnitMakeAbilityPermanent UnitRemoveAbility UnitRemoveAbilityBJ
                  UnitResetCooldown WaygateActivate WaygateActivateBJ WaygateGetDestinationX
                  WaygateGetDestinationY WaygateIsActive WaygateSetDestination WaygateSetDestinationLocBJ]] },
        { name = "heroes", about = "heroes' level, experience, attributes, skills, revival: kept on the unit",
          names = [[AddHeroXP AddHeroXPSwapped GetHeroAgi GetHeroInt GetHeroLevel GetHeroProperName
                  GetHeroSkillPoints GetHeroStatBJ GetHeroStr GetHeroXP IsHeroUnitId IsSuspendedXP
                  ModifyHeroSkillPoints ModifyHeroStat ReviveHero ReviveHeroLoc SelectHeroSkill SetHeroAgi
                  SetHeroInt SetHeroLevel SetHeroLevelBJ SetHeroStr SetHeroXP SetHeroXPBJ SuspendHeroXP
                  SuspendHeroXPBJ UnitModifySkillPoints UnitStripHeroLevel]] },
        { name = "orders", about = "orders, recorded as the VM's and passed to the creature (MoveTo, AttackStart, MoveStop)",
          names = [[GetUnitCurrentOrder IssueImmediateOrder IssueImmediateOrderBJ IssueImmediateOrderById
                  IssuePointOrder IssuePointOrderById IssuePointOrderByIdLoc IssuePointOrderLoc
                  IssuePointOrderLocBJ IssueTargetOrder IssueTargetOrderBJ IssueTargetOrderById OrderId
                  OrderId2String OrderId2StringBJ String2OrderIdBJ]] },
        { name = "unit events", about = "unit events: death (the script's at once, the server's at the next look), change of owner, hero level",
          names = [[GetAttackedUnitBJ GetAttacker GetChangingUnit GetChangingUnitPrevOwner GetDyingUnit
                  GetIssuedOrderId GetIssuedOrderIdBJ GetKillingUnit GetKillingUnitBJ GetLevelingUnit
                  GetOrderTargetUnit GetOrderedUnit GetSpellAbilityId GetSpellAbilityUnit GetSpellTargetUnit
                  GetTriggerWidget TriggerRegisterAnyUnitEventBJ TriggerRegisterDeathEvent
                  TriggerRegisterFilterUnitEvent TriggerRegisterPlayerUnitEvent
                  TriggerRegisterPlayerUnitEventSimple TriggerRegisterUnitEvent]] },
        { name = "groups", about = "unit groups, ForGroup, enumerations over the units the script knows, group orders",
          names = [[CountLivingPlayerUnitsOfTypeId CountUnitsInGroup CreateGroup CreateNUnitsAtLoc
                  CreateNUnitsAtLocFacingLocBJ DestroyGroup FirstOfGroup ForGroup ForGroupBJ GetEnumUnit
                  GetLastCreatedGroup GetRandomSubGroup GetUnitsInRangeOfLocAll GetUnitsInRangeOfLocMatching
                  GetUnitsInRectAll GetUnitsInRectMatching GetUnitsInRectOfPlayer GetUnitsInRectOfPlayerBJ
                  GetUnitsInRectOfPlayerFilter GetUnitsOfPlayerAll GetUnitsOfPlayerAndTypeId
                  GetUnitsOfPlayerAndTypeIdFilter GetUnitsOfPlayerMatching GetUnitsOfTypeIdAll
                  GetUnitsOfTypeIdAllFilter GroupAddGroup GroupAddUnit GroupAddUnitSimple GroupClear
                  GroupEnumUnitsInRange GroupEnumUnitsInRangeOfLoc GroupEnumUnitsInRect GroupEnumUnitsOfPlayer
                  GroupEnumUnitsOfType GroupImmediateOrder GroupImmediateOrderBJ GroupImmediateOrderById
                  GroupPickRandomUnit GroupPointOrder GroupPointOrderById GroupPointOrderByIdLoc
                  GroupPointOrderLoc GroupPointOrderLocBJ GroupRemoveGroup GroupRemoveUnit GroupRemoveUnitSimple
                  GroupTargetOrder GroupTargetOrderBJ GroupTargetOrderById IsUnitGroupDeadBJ IsUnitGroupEmptyBJ
                  IsUnitGroupInRectBJ IsUnitInGroup UnitId UnitId2String UnitId2StringBJ]] },
        { name = "sounds", about = "sounds and music: handles kept, plays heard by opts.on_sound (the server plays nothing)",
          names = [[AttachSoundToUnit CreateMIDISound CreateSound CreateSoundFilenameWithLabel CreateSoundFromLabel
                  GetLastPlayedSound GetSoundDuration GetSoundFileDuration GetSoundIsPlaying KillSoundWhenDone
                  KillSoundWhenDoneBJ PlayMusic PlayMusicBJ PlayMusicEx PlayMusicExBJ PlaySoundAtPointBJ
                  PlaySoundBJ PlaySoundFromOffsetBJ PlaySoundOnUnitBJ PlayThematicMusic PlayThematicMusicBJ
                  ResumeMusic SetMapMusic SetSoundChannel SetSoundDuration SetSoundParamsFromLabel SetSoundPitch
                  SetSoundPosition SetSoundVolume SetSoundVolumeBJ StartSound StartSoundForPlayerBJ StopMusic
                  StopMusicBJ StopSound StopSoundBJ]] },
    },
}

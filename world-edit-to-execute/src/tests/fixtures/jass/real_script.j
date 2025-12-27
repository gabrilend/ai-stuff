// Sample JASS Script - Mimics real war3map.j structure
// This fixture tests the lexer with realistic JASS code patterns

globals
    constant integer MAX_PLAYERS = 12
    constant real SPAWN_INTERVAL = 30.0
    constant string MAP_VERSION = "1.2.3"

    integer array playerScore
    unit array playerHero
    timer gameTimer = null
    boolean gameStarted = false
endglobals

// Native declarations (type definitions)
type player extends handle
type unit extends handle
type timer extends handle
type trigger extends handle

native CreateUnit takes player owner, integer id, real x, real y, real facing returns unit
native GetLocalPlayer takes nothing returns player
native DisplayTextToPlayer takes player p, real x, real y, string msg returns nothing
native CreateTimer takes nothing returns timer
native TimerStart takes timer t, real timeout, boolean periodic, code callback returns nothing

// Utility function: Check if player is valid
function IsPlayerValid takes player p returns boolean
    local integer id = GetPlayerId(p)
    if id < 0 or id >= MAX_PLAYERS then
        return false
    endif
    return true
endfunction

// Initialize player scores
function InitPlayerScores takes nothing returns nothing
    local integer i = 0
    loop
        exitwhen i >= MAX_PLAYERS
        set playerScore[i] = 0
        set i = i + 1
    endloop
endfunction

// Create hero for player
function CreatePlayerHero takes player p, real x, real y returns unit
    local integer heroType = 'Hpal'  // Paladin rawcode
    local unit hero = null

    if not IsPlayerValid(p) then
        return null
    endif

    set hero = CreateUnit(p, heroType, x, y, 270.0)
    set playerHero[GetPlayerId(p)] = hero

    return hero
endfunction

// Timer callback for spawning
function SpawnCallback takes nothing returns nothing
    local integer i = 0
    local player p = null
    local real spawnX = 0.0
    local real spawnY = 0.0

    loop
        exitwhen i >= MAX_PLAYERS
        set p = Player(i)
        if IsPlayerValid(p) then
            set spawnX = 100.0 * i
            set spawnY = 200.0
            call CreateUnit(p, 'hfoo', spawnX, spawnY, 0.0)
        endif
        set i = i + 1
    endloop
endfunction

// Main initialization trigger
function InitTrig_Initialization takes nothing returns nothing
    local trigger t = CreateTrigger()
    call TriggerRegisterTimerEventPeriodic(t, 1.0)
    call TriggerAddAction(t, function SpawnCallback)
endfunction

// Condition: Game has started
function Trig_GameStart_Conditions takes nothing returns boolean
    return gameStarted == true
endfunction

// Action: Display welcome message
function Trig_GameStart_Actions takes nothing returns nothing
    local player p = GetLocalPlayer()
    local string welcome = "Welcome to " + MAP_VERSION + "!"

    call DisplayTextToPlayer(p, 0.0, 0.0, welcome)

    // Complex expression test
    if playerScore[0] >= 10 and playerScore[0] <= 100 or gameStarted then
        call DisplayTextToPlayer(p, 0.0, 0.0, "Score check passed!")
    elseif playerScore[0] == 0 then
        call DisplayTextToPlayer(p, 0.0, 0.0, "No score yet")
    else
        call DisplayTextToPlayer(p, 0.0, 0.0, "Unknown state")
    endif
endfunction

// Map initialization
function main takes nothing returns nothing
    call InitPlayerScores()
    call InitTrig_Initialization()
    set gameTimer = CreateTimer()
    call TimerStart(gameTimer, SPAWN_INTERVAL, true, function SpawnCallback)
    set gameStarted = true
endfunction

// Configuration (called before main)
function config takes nothing returns nothing
    call SetMapName("Test Map")
    call SetMapDescription("A map for testing the JASS lexer")
    call SetPlayers(MAX_PLAYERS)
endfunction

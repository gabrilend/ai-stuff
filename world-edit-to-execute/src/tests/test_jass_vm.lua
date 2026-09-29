--[[
Tests for the JASS VM (Issue 520): small scripts on a bare world, then a
real map's own script on the game.
]]

-- {{{ Setup paths
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local vm = require("jass.vm")
-- }}}

-- {{{ Test infrastructure
local test_count, pass_count = 0, 0

local function test(name, condition, msg)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name .. (msg and ": " .. msg or ""))
    end
end

local function test_section(name)
    print("\n=== " .. name .. " ===")
end

-- A VM on a bare world running `source` (config/main if it has them)
local function run(source, opts)
    local V = vm.new(nil, opts or { player = 0 })
    local ok, err = V:load(source)
    if not ok then error("load failed: " .. tostring(err)) end
    V:run_main()
    return V
end

local function ticks(V, seconds)
    for _ = 1, math.floor(seconds / 0.02 + 0.5) do V:tick(0.02) end
end

local function messages(V)
    local out = {}
    for _, m in ipairs(V.log or {}) do out[#out + 1] = m.text end
    return table.concat(out, "|")
end
-- }}}

-- {{{ Values
test_section("Values")

local V = run([[
globals
    integer array counts
    string s = ""
    real r = 0
    integer i = 0
    integer id = 0
endglobals
function main takes nothing returns nothing
    set i = 7 / 2
    set r = 7.0 / 2
    set s = "gold: " + I2S(-7 / 2)
    set counts[5] = counts[5] + 1
    set id = 'hfoo'
endfunction
]])
test("integer division truncates", V.env.i == 3)
test("real division doesn't", V.env.r == 3.5)
test("toward zero, and + joins strings", V.env.s == "gold: -3", V.env.s)
test("arrays start at their default", V.env.counts[5] == 1 and V.env.counts[6] == 0)
test("rawcodes are integers", V.env.id == vm.s2id("hfoo") and vm.id2s(V.env.id) == "hfoo")
-- }}}

-- {{{ Triggers, timers and waits
test_section("Triggers, timers and waits")

V = run([[
globals
    integer fired = 0
    integer ticks = 0
    real woke = 0
    timer t = null
endglobals
function Once takes nothing returns nothing
    set fired = fired + 1
    call DisplayTextToPlayer(Player(0), 0, 0, "once")
endfunction
function Every takes nothing returns nothing
    set ticks = ticks + 1
endfunction
function Sleeper takes nothing returns nothing
    call TriggerSleepAction(2.0)
    set woke = 1
    call DisplayTextToPlayer(Player(0), 0, 0, "awake")
endfunction
function Expired takes nothing returns nothing
    if GetExpiredTimer() == t then
        call DisplayTextToPlayer(Player(0), 0, 0, "timer")
    endif
endfunction
function main takes nothing returns nothing
    local trigger a = CreateTrigger()
    local trigger b = CreateTrigger()
    local trigger c = CreateTrigger()
    call TriggerRegisterTimerEventSingle(a, 1.0)
    call TriggerAddAction(a, function Once)
    call TriggerRegisterTimerEventPeriodic(b, 0.5)
    call TriggerAddAction(b, function Every)
    call TriggerRegisterTimerEventSingle(c, 0.0)
    call TriggerAddAction(c, function Sleeper)
    set t = CreateTimer()
    call TimerStart(t, 3.0, false, function Expired)
endfunction
]])
ticks(V, 0.9)
test("nothing before its time", V.env.fired == 0)
ticks(V, 0.2)
test("a single timer event fires once", V.env.fired == 1)
ticks(V, 2)
test("still once", V.env.fired == 1)
test("periodic: every half second", V.env.ticks == 6, tostring(V.env.ticks))
test("a sleeping action wakes after its wait", V.env.woke == 1)
ticks(V, 1)
test("TimerStart's callback, with GetExpiredTimer", messages(V) == "once|awake|timer", messages(V))
-- }}}

-- {{{ Waits keep their event responses
test_section("Event responses across waits")

V = run([[
globals
    unit first = null
    unit second = null
    unit seen_after_wait = null
    integer deaths = 0
endglobals
function OnDeath takes nothing returns nothing
    local unit u = GetDyingUnit()
    set deaths = deaths + 1
    call TriggerSleepAction(1.0)
    if seen_after_wait == null then
        set seen_after_wait = GetTriggerUnit()
    endif
endfunction
function main takes nothing returns nothing
    local trigger t = CreateTrigger()
    set first = CreateUnit(Player(0), 'hfoo', 0, 0, 0)
    set second = CreateUnit(Player(1), 'hfoo', 100, 0, 0)
    call TriggerRegisterAnyUnitEventBJ(t, EVENT_PLAYER_UNIT_DEATH)
    call TriggerAddAction(t, function OnDeath)
endfunction
]])
V.env.KillUnit(V.env.first)
ticks(V, 0.5)
V.env.KillUnit(V.env.second)
ticks(V, 1)
test("both deaths fired", V.env.deaths == 2)
test("GetTriggerUnit after a wait is still the thread's own unit", V.env.seen_after_wait == V.env.first)
-- }}}

-- {{{ Chat, dialogs, rects, groups
test_section("Chat, dialogs, rects and groups")

V = run([[
globals
    dialog d = null
    button yes = null
    rect r = null
    integer entered = 0
    integer counted = 0
    string heard = ""
endglobals
function Heard takes nothing returns nothing
    set heard = heard + GetEventPlayerChatString() + ";"
endfunction
function Clicked takes nothing returns nothing
    if GetClickedButton() == yes then
        call DisplayTextToPlayer(GetTriggerPlayer(), 0, 0, "yes")
    endif
endfunction
function Entered takes nothing returns nothing
    set entered = entered + 1
endfunction
function IsFootman takes nothing returns boolean
    return GetUnitTypeId(GetFilterUnit()) == 'hfoo'
endfunction
function Count takes nothing returns nothing
    set counted = counted + 1
endfunction
function main takes nothing returns nothing
    local trigger t = CreateTrigger()
    local trigger e = CreateTrigger()
    local trigger k = CreateTrigger()
    local group g = CreateGroup()
    call TriggerRegisterPlayerChatEvent(t, Player(0), "-gold", true)
    call TriggerRegisterPlayerChatEvent(t, Player(0), "-say", false)
    call TriggerAddAction(t, function Heard)
    set d = DialogCreate()
    set yes = DialogAddButton(d, "Yes", 0)
    call DialogDisplay(Player(0), d, true)
    call TriggerRegisterDialogEvent(k, d)
    call TriggerAddAction(k, function Clicked)
    call CreateUnit(Player(0), 'hfoo', 50, 50, 0)
    set r = Rect(0, 0, 100, 100)
    call TriggerRegisterEnterRectSimple(e, r)
    call TriggerAddAction(e, function Entered)
    call CreateUnit(Player(0), 'hfoo', 500, 500, 0)
    call CreateUnit(Player(0), 'hkni', 510, 500, 0)
    call GroupEnumUnitsInRange(g, 500, 500, 100, Filter(function IsFootman))
    call ForGroup(g, function Count)
endfunction
]])
V:chat(0, "-gold")
V:chat(0, "-gold please")
V:chat(0, "I -say hi")
V:chat(1, "-gold")
test("exact and substring chat matches, own player only", V.env.heard == "-gold;I -say hi;", V.env.heard)
test("the dialog shows to its player", #V:shown_dialogs() == 1)
V:click(V.env.yes)
test("a click fires the dialog's trigger and hides it", messages(V) == "yes" and #V:shown_dialogs() == 0)
ticks(V, 0.2)
test("a unit already in a rect doesn't 'enter' it", V.env.entered == 0)
V.world.units[2].x, V.world.units[2].y = 60, 60
ticks(V, 0.2)
test("one that walks in does", V.env.entered == 1)
test("group enumeration with a filter, ForGroup", V.env.counted == 1)
-- }}}

-- {{{ Honest failures
test_section("What the VM doesn't have")

V = run([[
globals
    integer after = 0
endglobals
function Broken takes nothing returns nothing
    local unit u = null
    call SomeNativeNobodyWrote(1, 2)
    call SetUnitX(u, GetUnitX(u) + nothing_here())
endfunction
function main takes nothing returns nothing
    local trigger t = CreateTrigger()
    call TriggerRegisterTimerEventSingle(t, 0.0)
    call TriggerAddAction(t, function Broken)
    set after = 1
endfunction
]])
ticks(V, 0.1)
local report = V:report()
test("an unknown native is a counted stub", V.missing.SomeNativeNobodyWrote == 1)
test("an error ends its own thread only", report.error_count == 1 and V.env.after == 1)
-- }}}

-- {{{ A real map on the game
test_section("DAoW 5.4b's own script on the game")

local map_scene = require("demo.wc3map.scene")
local game_mod = require("demo.wc3map.game")
local scene = map_scene.load(DIR .. "/assets/DAoW-5.4b-PUBLIC-TEST.w3x")
local game = game_mod.new(scene, { player = 0, minimap = false, placed = false })
local S, err = game.run_script()
test("the script loads and main() runs", S ~= nil, err)
if S then
    test("it makes the map's units itself", #game.units >= #scene.units,
        #game.units .. " made, " .. #scene.units .. " read from the text")
    for _ = 1, 50 * 12 do game.tick(0.02) end
    local r = S:report()
    test("no errors, nothing missing", r.error_count == 0 and #r.missing == 0,
        r.errors[1] and r.errors[1].message or (#r.missing .. " missing"))
    test("its story is told (TRIGSTR resolved)", messages(S):find("Scarlet Crusade", 1, true) ~= nil)
    test("its quests are made", #S.quests >= 10)
    test("the script sets the resources", game.resources(0).lumber == 750, tostring(game.resources(0).lumber))
    local owned = 0
    for _, u in ipairs(game.units) do if u.player == 0 then owned = owned + 1 end end
    test("the local player owns units", owned > 50)
end
-- }}}

-- {{{ Summary
print("\n" .. string.rep("=", 50))
print(string.format("Tests: %d passed, %d failed", pass_count, test_count - pass_count))
if pass_count == test_count then
    print("ALL TESTS PASSED")
else
    print("SOME TESTS FAILED")
    os.exit(1)
end
-- }}}

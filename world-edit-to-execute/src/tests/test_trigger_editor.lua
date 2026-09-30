--[[
Tests for the trigger editor (Issue 905): triggers built from blocks,
the JASS they become, undo, checking; saved into DAoW 5.4b's protected
script and played: a map-initialization message shows, a periodic trigger
pays gold, a chat message makes units in a region, a unit dying counts
into a variable through an if / then, units picked in a region; the
blocks kept in the map and read back, the written JASS taken out again
when the saved copy is opened; the script's own triggers listed, one
switched off and a function rewritten.
]]

-- {{{ Setup paths
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path
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
-- }}}

local editor = require("editor")
local blocks = require("editor.trigger_blocks")
local tmod = require("editor.triggers")

-- {{{ Blocks
test_section("Blocks")
do
    test("values: a player", blocks.value("player", 3) == "Player(3)")
    test("a unit by role", blocks.value("unit", "dying") == "GetDyingUnit()")
    test("a text, quoted", blocks.value("string", 'say "hi"') == '"say \\"hi\\""')
    test("a unit type", blocks.value("unit_type", "hfoo") == "'hfoo'")
    test("an expression in any slot", blocks.value("integer", { expr = "udg_X + 1" }) == "udg_X + 1")
    test("a real", blocks.value("real", 2) == "2.0" and blocks.value("real", 0.25) == "0.25")
    test("safe JASS names", blocks.safe("Kill Count!") == "Kill_Count" and blocks.trigger_var("A b") == "gg_trg_A_b")
    local b = { kind = "player_chat", args = blocks.defaults("events", "player_chat") }
    b.args.text = "-spawn"
    test("described for the list", blocks.describe("events", b) == 'Player 1 types a chat message containing "-spawn"',
        blocks.describe("events", b))
    test("the stored table read back", tmod.deserialize(tmod.serialize({ a = { 1, 2, { x = "q\"" } }, b = true })).a[3].x == 'q"')
    test("and nothing else runs in it", tmod.deserialize("return os.exit()") == nil)
end
-- }}}

local E = assert(editor.open(DIR .. "/assets/DAoW-5.4b-PUBLIC-TEST.w3x"))
local region = E:regions()[1]

-- {{{ Building triggers
test_section("Triggers from blocks")
local hello, pay, spawn, deaths, picker
do
    local gold = E:new_variable("Deaths", "integer", 0)
    test("a variable", gold and E:variable_named("Deaths") == gold)

    hello = E:new_trigger("Hello")
    E:add_block(hello, "events", "map_init")
    E:add_block(hello, "actions", "display_text", { text = "Editor trigger says hello" })

    pay = E:new_trigger("Pay")
    E:add_block(pay, "events", "periodic", { seconds = 1 })
    E:add_block(pay, "actions", "gold", { player = 0, op = "add", value = 7 })

    spawn = E:new_trigger("Spawn")
    E:add_block(spawn, "events", "player_chat", { player = 0, text = "-spawn", exact = true })
    E:add_block(spawn, "actions", "create_units", { count = 3, unit_type = "hfoo", player = 0, region = region.var })

    deaths = E:new_trigger("Count deaths")
    E:add_block(deaths, "events", "unit_dies")
    E:add_block(deaths, "conditions", "unit_type_is", { unit = "dying", unit_type = "hfoo" })
    local branch = E:add_block(deaths, "actions", "if_then_else")
    E:add_block(deaths, "if_conditions", "owner_is", { unit = "dying", player = 0 }, branch)
    E:add_block(deaths, "then_actions", "set_variable", { variable = "Deaths", value = "udg_Deaths + 1" }, branch)
    E:add_block(deaths, "else_actions", "comment", { text = "someone else's" }, branch)

    picker = E:new_trigger("Pick")
    E:add_block(picker, "events", "player_chat", { player = 0, text = "-kill", exact = true })
    local pick = E:add_block(picker, "actions", "pick_units", { region = region.var })
    E:add_block(picker, "loop_actions", "kill_unit", { unit = "picked" }, pick)

    test("five triggers", #E:triggers() == 5)
    local j = E:trigger_jass(deaths)
    test("its JASS: the conditions function", j:find("function Trig_Count_deaths_Conditions takes nothing returns boolean", 1, true) ~= nil)
    test("the condition", j:find("GetUnitTypeId(GetDyingUnit()) == 'hfoo'", 1, true) ~= nil)
    test("the if / then / else", j:find("if (GetOwningPlayer(GetDyingUnit()) == Player(0)) then", 1, true) ~= nil
        and j:find("set udg_Deaths = udg_Deaths + 1", 1, true) and j:find("else", 1, true))
    test("the event", j:find("call TriggerRegisterAnyUnitEventBJ(gg_trg_Count_deaths, EVENT_PLAYER_UNIT_DEATH)", 1, true) ~= nil)
    local pj = E:trigger_jass(picker)
    test("picked units: a function of their own", pj:find("function Trig_Pick_Func001", 1, true) ~= nil
        and pj:find("ForGroupBJ(GetUnitsInRectAll(" .. region.var .. "), function Trig_Pick_Func001)", 1, true) ~= nil)
    test("nothing wrong with them", #E:check_triggers() == 0, (E:check_triggers()[1] or {}).message)

    -- undo and redo
    E:undo()
    test("undo takes the last block out", #picker.actions[1].loop_actions == 0)
    E:redo()
    test("redo puts it back", #picker.actions[1].loop_actions == 1)
    local t = E:new_trigger("Scratch")
    E:rename_trigger(t, "Scratch 2")
    test("renamed", t.name == "Scratch 2")
    E:undo(); E:undo()
    test("undone: no scratch trigger", #E:triggers() == 5)
    local bad = E:new_trigger("Bad")
    E:add_block(bad, "actions", "move_unit", {})
    local probs = E:check_triggers()
    local saw_region, saw_events = false, false
    for _, p in ipairs(probs) do
        if p.trigger == bad and p.message:find("needs a region", 1, true) then saw_region = true end
        if p.trigger == bad and p.message:find("no events", 1, true) then saw_events = true end
    end
    test("checking finds a missing region and no events", saw_region and saw_events)
    E:delete_trigger(bad)
    test("deleted", #E:triggers() == 5 and #E:check_triggers() == 0)
    local on = E:new_trigger("Off")
    E:set_trigger_on(on, false)
    test("initially off", E:trigger_jass(on):find("call DisableTrigger(gg_trg_Off)", 1, true) ~= nil)
    E:delete_trigger(on)
end
-- }}}

-- {{{ The map's own triggers
test_section("The script's own triggers")
local off_mt
do
    local list = E:map_triggers()
    test("listed", #list > 20, tostring(#list))
    local with_action
    for _, mt in ipairs(list) do if #mt.actions > 0 and #mt.events > 0 and not with_action then with_action = mt end end
    test("with events and actions", with_action ~= nil)
    local text, at, to = E:map_function(with_action.actions[1])
    test("an action function's text", text and text:match("^function%s+" .. with_action.actions[1]) and text:match("endfunction$"))
    test("a rewrite that isn't the function refused", not E:set_map_function(with_action.actions[1], "call Foo()"))
    -- switch off one of the map's triggers
    off_mt = with_action
    E:set_map_trigger_on(off_mt, false)
    local st = E:script_text()
    test("switched off: its TriggerAddAction gone", st and not st:find("TriggerAddAction%(%s*" .. off_mt.var .. "%s*,%s*function%s+" .. off_mt.actions[1] .. "%s*%)"))
    E:undo()
    st = E:script_text()
    test("undone", st:find("TriggerAddAction%(%s*" .. off_mt.var .. "%s*,%s*function%s+" .. off_mt.actions[1] .. "%s*%)") ~= nil)
    -- rewrite a function of the script: main's last words
    local mt_text = E:map_function("main")
    local new = mt_text:gsub("endfunction$", "call DisplayTimedTextToForce(GetPlayersAll(), 5.0, \"main was rewritten\")\nendfunction")
    test("a function rewritten", E:set_map_function("main", new))
end
-- }}}

-- {{{ Saved and played
test_section("Saved, and played")
local TMP = os.tmpname() .. ".w3x"
do
    local text = E:script_text()
    test("the script has the editor's pieces", text:find(tmod.BEGIN, 1, true) ~= nil
        and text:find("call EditorInitTriggers()", 1, true) ~= nil)
    local probs = E:check_triggers({ full = true })
    test("the whole script loads", #probs == 0, (probs[1] or {}).message)
    local ok, rep = E:save(TMP)
    test("saved", ok, tostring(rep))
    local files = E:files()
    test("with the blocks kept", files["war3mapEditor.lua"] ~= nil)

    local s = require("demo.wc3map.scene").load(TMP)
    local g = require("demo.wc3map.game").new(s, { player = 0, placed = false, minimap = false, vision = false, combat = false })
    local V = g.run_script({ ai = "none" })
    test("the map's script runs", V ~= nil and #g.units > 1000)
    local hello_seen, main_seen = false, false
    for _, m in ipairs(V.messages) do
        if tostring(m.text):find("Editor trigger says hello", 1, true) then hello_seen = true end
        if tostring(m.text):find("main was rewritten", 1, true) then main_seen = true end
    end
    test("the map-initialization trigger showed its message", hello_seen)
    test("the rewritten main ran", main_seen)
    local gold0 = V.natives.GetPlayerState(V.natives.Player(0), V.env.PLAYER_STATE_RESOURCE_GOLD)
    for _ = 1, 26 do g.tick(0.1) end
    local gold1 = V.natives.GetPlayerState(V.natives.Player(0), V.env.PLAYER_STATE_RESOURCE_GOLD)
    test("the periodic trigger paid gold", gold1 - gold0 >= 14, gold0 .. " -> " .. gold1)
    local function footmen_in_region()
        local n = 0
        for _, u in ipairs(g.units) do
            if u.id == "hfoo" and u.alive and u.player == 0 and u.x >= region.left and u.x <= region.right
                and u.y >= region.bottom and u.y <= region.top then n = n + 1 end
        end
        return n
    end
    local before = footmen_in_region()
    V:chat(0, "-spawn")
    g.tick(0.05)
    test("the chat trigger made three footmen in the region", footmen_in_region() == before + 3,
        before .. " -> " .. footmen_in_region())
    local d0 = V.env.udg_Deaths
    V:chat(0, "-kill")
    for _ = 1, 3 do g.tick(0.05) end
    test("units picked in the region and killed", footmen_in_region() == 0)
    test("their deaths counted through if / then", (V.env.udg_Deaths or 0) - (d0 or 0) >= 3,
        tostring(d0) .. " -> " .. tostring(V.env.udg_Deaths))
    test("no script errors", #V.errors == 0, V.errors[1] and V.errors[1].message)
end
-- }}}

-- {{{ Opened again
test_section("The saved copy opened again")
do
    local E2 = assert(editor.open(TMP))
    test("the triggers read back from the map", #E2:triggers() == 5 and E2:trigger_named("Count deaths") ~= nil)
    local d = E2:trigger_named("Count deaths")
    test("with their blocks", d.actions[1].kind == "if_then_else" and d.actions[1].then_actions[1].args.variable == "Deaths")
    test("the variable", E2:variable_named("Deaths") ~= nil)
    test("the written JASS taken out of the script", E2.had_editor_code and not E2.script:find(tmod.BEGIN, 1, true)
        and not E2.script:find("EditorInitTriggers", 1, true))
    E2:add_block(E2:trigger_named("Hello"), "actions", "display_text", { text = "second line" })
    local text = E2:script_text()
    local _, n = text:gsub("function EditorInitTriggers", "")
    test("saving again writes them once", n == 1)
    test("the rewritten main is the script's now", text:find("main was rewritten", 1, true) ~= nil)
    os.remove(TMP)
end
-- }}}

-- {{{ The panel
test_section("The trigger editor's panel")
do
    local E3 = assert(editor.open(DIR .. "/assets/Daow4.4.w3x"))
    local ui = require("editor.ui").new(E3, 1280, 800, { run_tests = false })
    local drawn = {}
    local render = setmetatable({ ui_text = function(s) drawn[#drawn + 1] = s end,
                                  ui_text_width = function(s, size) return #s * math.floor(size * 0.6) end },
                                { __index = function() return function() end end })
    local function press(label)
        local b
        for _, x in ipairs(ui.buttons) do if x.label == label then b = x end end
        if not b and ui.tui then b = ui.tui:button(label) end
        if not b then return false end
        ui:update({ mx = b.x + 2, my = b.y + 2, lp = true, keys = {}, chars = "" }, 0.016)
        return true
    end
    test("opened from the toolbar", press("Triggers") and ui.tui ~= nil)
    test("a trigger made", press("+ Trigger") and #E3:triggers() == 1)
    local t = E3:triggers()[1]
    -- renamed by typing
    local old_name = t.name
    for _, b in ipairs(ui.tui.buttons) do
        if b.action == "edit_name" then ui:update({ mx = b.x + 2, my = b.y + 2, lp = true, keys = {}, chars = "" }, 0.016) end
    end
    ui:update({ keys = {}, chars = "Waves" }, 0.016)
    ui:update({ keys = { "BACKSPACE" }, chars = "" }, 0.016)
    ui:update({ keys = { "ENTER" }, chars = "" }, 0.016)
    test("renamed by typing (the old name replaced)", t.name == "Wave", t.name)
    test("+ Event lists the events", press("+ Event") and ui.tui.chooser and ui.tui:button("Every seconds seconds of game time"))
    press("Every seconds seconds of game time")
    test("an event added and chosen", #t.events == 1 and ui.tui.block == t.events[1])
    press("+")
    test("stepped: 2.5 seconds", t.events[1].args.seconds == 2.5, tostring(t.events[1].args.seconds))
    press("+ Action"); press("If (conditions) then (actions) else (actions)")
    local branch = t.actions[1]
    test("an if / then / else", branch and branch.kind == "if_then_else")
    ui.tui:layout()
    -- its Then part's "+": the second "+" after the If
    local plus = {}
    for _, b in ipairs(ui.tui.buttons) do if b.label == "+" and b.action == "open_chooser" then plus[#plus + 1] = b end end
    ui:update({ mx = plus[2].x + 2, my = plus[2].y + 2, lp = true, keys = {}, chars = "" }, 0.016)
    test("adding into Then", ui.tui.chooser and ui.tui.chooser.section == "then_actions")
    press("Player - op player's gold: value")
    test("gold in the Then part", #branch.then_actions == 1 and branch.then_actions[1].kind == "gold")
    -- a value typed as an expression
    local vb
    for _, b in ipairs(ui.tui.buttons) do if b.action == "edit_arg" and b.arg == "value" then vb = b end end
    ui:update({ mx = vb.x + 2, my = vb.y + 2, lp = true, keys = {}, chars = "" }, 0.016)
    ui:update({ keys = {}, chars = "GetRandomInt(1, 5)" }, 0.016)
    ui:update({ keys = {}, chars = "" }, 0.016)
    local fb = ui.tui:button("GetRandomInt(1, 5)_")
    test("typing shows in the field", fb ~= nil)
    ui:update({ keys = { "ENTER" }, chars = "" }, 0.016)
    test("an expression kept", type(branch.then_actions[1].args.value) == "table"
        and branch.then_actions[1].args.value.expr == "GetRandomInt(1, 5)")
    test("in the JASS", E3:trigger_jass(t):find("AdjustPlayerStateBJ(GetRandomInt(1, 5), Player(0), PLAYER_STATE_RESOURCE_GOLD)", 1, true) ~= nil)
    press("Code")
    test("the code view", ui.tui.code and ui.tui.code.readonly and ui.tui.code.te:text():find("InitTrig_", 1, true))
    ui:draw(render)
    local coloured = false
    for _, s in ipairs(drawn) do if s == "function" then coloured = true end end
    test("drawn in coloured pieces", coloured)
    press("Close")
    ui:update({ keys = { "Z" }, ctrl = true, chars = "" }, 0.016)
    test("Ctrl+Z in the panel undoes", type(branch.then_actions[1].args.value) == "number")
    -- the map's triggers: a function edited in the code view
    local mt
    for _, x in ipairs(E3:map_triggers()) do if #x.actions > 0 and not mt then mt = x end end
    ui.tui:press({ action = "pick", arg = { "map", mt } })
    test("one of the map's triggers shown", press("Edit function " .. mt.actions[1]) and ui.tui.code and not ui.tui.code.readonly)
    local te = ui.tui.code.te
    te:key("END", true)
    te:key("HOME")
    ui:update({ keys = {}, chars = "call DoNothing()" }, 0.016)
    ui:update({ keys = { "ENTER" }, chars = "" }, 0.016)
    test("typed into the code", te:text():find("call DoNothing()\nendfunction", 1, true) ~= nil, te:text():sub(-120))
    press("Apply")
    test("applied: the function rewritten", E3.map_fn_edits[mt.actions[1]] ~= nil and ui.tui.code == nil)
    test("switched off from the panel", press("Switch off") and E3.map_trigger_off[mt])
    press("Triggers")
    test("closed again", ui.tui == nil)
end
-- }}}

print(string.format("\n%d/%d tests passed", pass_count, test_count))
os.exit(pass_count == test_count and 0 or 1)

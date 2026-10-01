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
    test("the code view: the trigger as Lua", ui.tui.code and ui.tui.code.kind == "lua" and not ui.tui.code.readonly
        and ui.tui.code.te:text():find('trigger "Wave" {', 1, true))
    press("JASS")
    test("and its JASS, read only", ui.tui.code and ui.tui.code.readonly and ui.tui.code.te:text():find("InitTrig_", 1, true))
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

-- {{{ Lua: the second view that edits (issue 905b)
test_section("Triggers as Lua")
do
    local tl = require("editor.trigger_lua")
    local E4 = assert(editor.open(DIR .. "/assets/Daow4.4.w3x"))
    local r = E4:regions()[1]
    E4:new_variable("Deaths", "integer", 0)
    local d = E4:new_trigger("Count deaths")
    E4:add_block(d, "events", "unit_dies")
    E4:add_block(d, "conditions", "unit_type_is", { unit = "dying", unit_type = "hfoo" })
    local br = E4:add_block(d, "actions", "if_then_else")
    E4:add_block(d, "if_conditions", "owner_is", { unit = "dying", player = 0 }, br)
    E4:add_block(d, "then_actions", "set_variable", { variable = "Deaths", value = "udg_Deaths + 1" }, br)
    E4:add_block(d, "else_actions", "custom", { code = 'call BJDebugMsg("x")' }, br)
    local pk = E4:new_trigger("Pick")
    E4:add_block(pk, "events", "player_chat", { text = "-k" })
    local pick = E4:add_block(pk, "actions", "pick_units", { region = r.var })
    E4:add_block(pk, "loop_actions", "kill_unit", { unit = "picked" }, pick)
    E4:add_block(pk, "actions", "display_text", { seconds = { expr = "udg_Deaths * 1.0" } })

    local text = E4:trigger_lua(d)
    test("a trigger as Lua", text:find('unit_type_is { unit = "dying", unit_type = "hfoo" }', 1, true)
        and text:find('then_actions = {', 1, true) and text:find('"call BJDebugMsg(\\"x\\")",', 1, true), text)
    local j1 = E4:trigger_jass(d)
    test("read back unchanged: the same JASS", E4:set_trigger_lua(d, text) and E4:trigger_jass(d) == j1)
    local edited = text:gsub('unit_type = "hfoo"', 'unit_type = "hkni"'):gsub("on = true", "on = false")
    test("edited as Lua", E4:set_trigger_lua(d, edited) and d.conditions[1].args.unit_type == "hkni" and d.on == false)
    test("the blocks' JASS follows", E4:trigger_jass(d):find("'hkni'", 1, true) and E4:trigger_jass(d):find("DisableTrigger", 1, true))
    E4:undo()
    test("one step to undo", d.conditions[1].args.unit_type == "hfoo" and d.on ~= false)
    local ok, why, line = E4:set_trigger_lua(d, text:gsub("unit_dies", "unit_dances"))
    test("an unknown block: why, and its line", not ok and why:find("unit_dances isn't one of the events", 1, true)
        and line == 4, tostring(why) .. " @" .. tostring(line))
    ok, why, line = E4:set_trigger_lua(d, 'trigger "x" {\n events = {\n')
    test("broken Lua: why, and where", not ok and line ~= nil, tostring(why))
    test("renaming onto another trigger refused", not E4:set_trigger_lua(d, text:gsub('"Count deaths"', '"Pick"')))
    test("a loop can't hang it", not tl.from_lua("while true do end"))
    test("nor reach outside", not tl.from_lua('os.remove("x")'))

    -- a string where an action goes: custom script
    local t2 = assert(tl.from_lua('trigger "S" { events = { map_init {} }, actions = { "call Foo()", wait { seconds = 2 } } }'))
    test("a string is custom script", t2.actions[1].kind == "custom" and t2.actions[1].args.code == "call Foo()"
        and t2.actions[2].args.seconds == 2)

    -- everything at once
    local all = E4:triggers_lua()
    test("every trigger and variable", all:find('variable "Deaths" { type = "integer", initial = 0 }', 1, true)
        and all:find('trigger "Pick"', 1, true))
    local js = {}
    for i, t in ipairs(E4:triggers()) do js[i] = E4:trigger_jass(t) end
    test("read back: the same", E4:set_triggers_lua(all) and E4:trigger_jass(E4:triggers()[1]) == js[1]
        and E4:trigger_jass(E4:triggers()[2]) == js[2] and E4:triggers()[1] == d)
    local more = all .. '\ntrigger "Hello" { category = "Intro", events = { map_init {} }, actions = { display_text { text = "hi" } } }\n'
        .. 'variable "Score" { type = "real", initial = 1.5 }\n'
    test("a trigger and a variable added as Lua", E4:set_triggers_lua(more) and E4:trigger_named("Hello")
        and E4:trigger_named("Hello").category == "Intro" and E4:variable_named("Score").initial == 1.5)
    E4:undo()
    test("undone together", not E4:trigger_named("Hello") and not E4:variable_named("Score") and #E4:triggers() == 2)
    test("nothing wrong after all that", #E4:check_triggers() == 0, (E4:check_triggers()[1] or {}).message)

    -- the panel: the Lua view, a mistake marked, completion, categories
    local ui = require("editor.ui").new(E4, 1280, 800, { run_tests = false })
    local function click(b) ui:update({ mx = b.x + 2, my = b.y + 2, lp = true, keys = {}, chars = "" }, 0.016) end
    local function find(action, f)
        for _, b in ipairs(ui.tui and ui.tui.buttons or ui.buttons) do if b.action == action and (not f or f(b.arg)) then return b end end
    end
    for _, b in ipairs(ui.buttons) do if b.label == "Triggers" then click(b) end end
    ui.tui:press({ action = "pick", arg = { "trigger", d } })
    ui.tui:press({ action = "show_code", arg = d })
    local te = ui.tui.code.te
    te.cy, te.cx = 4, #te.lines[4]
    te.lines[4] = "        unit_dances {},"
    click(find("apply_code"))
    test("a mistake: the view stays, the line marked", ui.tui.code and te.error and te.error.line == 4)
    te.lines[4] = "        "
    te.cy, te.cx = 4, 8
    ui:update({ keys = {}, chars = "unit_di" }, 0.016)
    test("completion offered", te.suggest and te.suggest[1] == "unit_dies", te.suggest and table.concat(te.suggest, ","))
    ui:update({ keys = { "TAB" }, chars = "" }, 0.016)
    ui:update({ keys = {}, chars = " {}," }, 0.016)
    test("Tab takes it", te.lines[4] == "        unit_dies {},", te.lines[4])
    ui:update({ keys = { "ENTER" }, ctrl = true, chars = "" }, 0.016)
    test("Ctrl+Enter applies", ui.tui.code == nil and d.events[1].kind == "unit_dies")
    click(find("edit_category"))
    ui:update({ keys = {}, chars = "Combat" }, 0.016)
    ui:update({ keys = { "ENTER" }, chars = "" }, 0.016)
    test("a category typed", d.category == "Combat")
    test("the list by category", find("fold", function(a) return a == "Combat" end) ~= nil)
    click(find("fold", function(a) return a == "Combat" end))
    test("folded", not find("pick", function(a) return a[2] == d end))
    click(find("lua_all"))
    test("Lua (all) opens every trigger", ui.tui.code.kind == "lua_all" and ui.tui.code.te:text():find('category = "Combat"', 1, true))
end
-- }}}

print(string.format("\n%d/%d tests passed", pass_count, test_count))
os.exit(pass_count == test_count and 0 or 1)

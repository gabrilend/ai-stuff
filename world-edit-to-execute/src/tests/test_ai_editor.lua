--[[
Tests for the AI editor (Issue 909): DAoW 5.4b's computer players'
profiles opened (the profiles folder's files, else derived), edited
(name, options, harvest, build priorities, groups, waves, conditions),
undone, checked, saved into the map as war3mapAI\pNN.lua, and played:
the game gives the player the map's profile when the folder has none,
and its first wave goes at the edited time. Also: a profile carried in
a map is read as data only, and written to a folder on export.
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
local editor_ai = require("editor.ai")
local faction = require("ai.faction")

-- {{{ Reading profiles as data
test_section("Profiles carried in a map")
do
    local p = faction.read_profile('return { name = "X", waves = { delay = 5 } }', "t")
    test("read", p.name == "X" and p.waves.delay == 5)
    test("nothing but data", not pcall(faction.read_profile, 'return { os.exit() }', "t"))
    test("conditions as text and back", editor_ai.condition_text({ "gold", ">=", 500 }) == '{ "gold", ">=", 500 }',
        editor_ai.condition_text({ "gold", ">=", 500 }))
    local c, ok = editor_ai.parse_condition('{ "and", { "army", ">=", 8 }, "early" }')
    test("parsed", ok and c[1] == "and" and c[3] == "early")
    local _, bad = editor_ai.parse_condition("os.exit()")
    test("and code refused", not bad)
end
-- }}}

local E = assert(editor.open(DIR .. "/assets/DAoW-5.4b-PUBLIC-TEST.w3x"))

-- {{{ Opening
test_section("DAoW's computer players")
local e
do
    local list = assert(E:load_ai({ root = DIR }))
    test("a profile each", #list >= 10, tostring(#list))
    e = E:ai_profile_of(3)
    test("the Scourge's, from the profiles folder", e and e.name:find("Scourge") and e.source:find("p03", 1, true),
        e and (e.name .. " " .. e.source))
    test("what its buildings train, to choose from", #e.trains > 0)
    test("names for types", E:ai_name_of("ugho") == "Ghoul", E:ai_name_of("ugho"))
    local from_folder = 0
    for _, x in ipairs(list) do if x.file then from_folder = from_folder + 1 end end
    test("the folder's eleven files used", from_folder == 11, tostring(from_folder))
end
-- }}}

-- {{{ Editing
test_section("Edited")
do
    local p = e.profile
    E:ai_set(e, { "name" }, "The Scourge (edited)")
    E:ai_set(e, { "options", "have_no_mercy" }, true)
    E:ai_set(e, { "harvest", "gold" }, 7)
    E:ai_set(e, { "waves", "initial_delay" }, 20)
    E:ai_set(e, { "waves", "max_wait" }, 5)
    E:ai_set(e, { "waves", "min_fraction" }, 0.1)
    local nb = #p.build
    E:ai_insert(e, { "build" }, { kind = "unit", id = "ugho", count = 20, condition = "army_up" }, 1)
    test("a build priority first", #p.build == nb + 1 and p.build[1].count == 20)
    E:ai_move(e, { "build" }, 1, 2)
    test("moved down", p.build[3].count == 20)
    E:ai_insert(e, { "groups", "main" }, { id = "uabo", count = 1 })
    E:ai_set(e, { "groups", "raid" }, { { id = "ugho", count = 2 } })
    E:ai_insert(e, { "waves", "list" }, { group = "raid" }, 1)
    E:ai_set(e, { "conditions", "rich" }, { "gold", ">=", 2000 })
    test("the edits", p.name == "The Scourge (edited)" and p.options.have_no_mercy and p.harvest.gold == 7
        and p.waves.list[1].group == "raid" and p.groups.raid[1].id == "ugho")
    test("nothing wrong", #E:ai_check() == 0, (E:ai_check()[1] or {}).message)
    E:ai_insert(e, { "waves", "list" }, { group = "nobody" })
    local probs = E:ai_check()
    test("a wave with no such group found", #probs == 1 and probs[1].message:find("nobody", 1, true), (probs[1] or {}).message)
    E:undo()
    test("undone", #E:ai_check() == 0 and #p.waves.list == 4)
    E:ai_remove(e, { "groups", "main" }, #p.groups.main)
    E:undo()
    test("removed and back", p.groups.main[#p.groups.main].id == "uabo")
    E:ai_set(e, { "harvest", "lumber" }, 1)
    E:undo()
    test("a set undone", p.harvest.lumber == 3, tostring(p.harvest.lumber))
    test("marked changed", E.dirty.ai[3])
end
-- }}}

-- {{{ Saved and played
test_section("Saved into the map, and played")
local TMP = os.tmpname() .. ".w3x"
do
    local files = E:files()
    local text = files[faction.map_file(3)]
    test("saving writes the profile into the map", text and text:find("The Scourge (edited)", 1, true)
        and text:find("-- Ghoul", 1, true))
    test("only the changed one", files[faction.map_file(1)] == nil)
    assert(E:save(TMP))
    local s = require("demo.wc3map.scene").load(TMP)
    local g = require("demo.wc3map.game").new(s, { player = 0, placed = false, minimap = false, vision = false })
    local V = g.run_script({ ai = "auto", ai_dir = TMP .. ".no-profiles" })
    local M = g.ai_manager
    test("the game plays the map's profile", M and M.how[3] == "map:" .. faction.map_file(3), M and tostring(M.how[3]))
    local a = M.players[3]
    test("with its name and options", a.profile_name == "The Scourge (edited)" and a.options.have_no_mercy)
    test("and its workers", a.harvest_plan.gold == 7)
    local others = 0
    for p, how in pairs(M.how) do if p ~= 3 and how == "derived" then others = others + 1 end end
    test("the others derived as before", others > 0)
    -- the first wave: edited to go after 20 s instead of 240
    local waved = false
    for _ = 1, 40 * 10 do
        g.tick(0.1)
        if a.runner.state.wave >= 1 then waved = true break end
    end
    test("its first wave went at the edited time", waved, "t=" .. string.format("%.1f", g.time))
    test("the raid group", waved and a.runner.p.waves.list[a.runner.state.wave].group == "raid")
    test("no script errors", #V.errors == 0, V.errors[1] and V.errors[1].message)

    -- opened again: the map's own profile read back
    local E2 = assert(editor.open(TMP))
    E2:load_ai({ dir = TMP .. ".no-profiles" })
    local e2 = E2:ai_profile_of(3)
    test("opened again: the map's profile", e2 and e2.source == "map:" .. faction.map_file(3)
        and e2.profile.name == "The Scourge (edited)")
    os.remove(TMP)
end
-- }}}

-- {{{ Export
test_section("Written to a folder")
do
    local dir = os.tmpname() .. "-ai"
    local written = E:export_ai(dir)
    test("one file", #written == 1 and written[1]:match("/p03%-.*%.lua$"), written[1])
    local p = faction.read_profile(io.open(written[1]):read("*a"), "export")
    test("the edited profile", p.name == "The Scourge (edited)" and p.waves.initial_delay == 20)
    os.execute('rm -rf "' .. dir .. '"')
end
-- }}}

-- {{{ The panel
test_section("The AI editor's panel")
do
    local ui = require("editor.ui").new(E, 1280, 800, { run_tests = false, root = DIR })
    local function click(b)
        ui:update({ mx = b.x + 2, my = b.y + 2, lp = true, keys = {}, chars = "" }, 0.016)
    end
    local function press(label)
        local b
        for _, x in ipairs(ui.buttons) do if x.label == label then b = x end end
        if not b and ui.tui then b = ui.tui:button(label) end
        if not b then return false end
        click(b)
        return true
    end
    local function find(action, test_arg)
        for _, b in ipairs(ui.tui.buttons) do
            if b.action == action and (not test_arg or test_arg(b.arg)) then return b end
        end
    end
    local function type_in(text)
        ui:update({ keys = {}, chars = text }, 0.016)
        ui:update({ keys = { "ENTER" }, chars = "" }, 0.016)
    end
    test("opened from the toolbar", press("AI") and ui.panel == "ai")
    local aui = ui.tui
    aui:press({ action = "entry", arg = e })
    test("the players listed, the Scourge chosen", aui.entry == e)
    press("Build")
    local p = e.profile
    local n = #p.build
    press("+ Unit")
    test("a build line added", #p.build == n + 1)
    -- its type picked from what the buildings train
    click(find("pick", function(a) return a[2] == n + 1 end))
    test("the picker lists trained types", aui.picker ~= nil and find("picked") ~= nil)
    local choice = find("picked")
    click(choice)
    test("picked", p.build[n + 1].id == choice.arg)
    click(find("number", function(a) return a[1][2] == n + 1 and a[1][3] == "count" and a[2] > 0 end))
    test("its count stepped up", p.build[n + 1].count == 2)
    click(find("field", function(a) return a.key == "build." .. (n + 1) .. ".condition" end))
    type_in('{ "gold", ">=", 300 }')
    test("a condition typed", type(p.build[n + 1].condition) == "table" and p.build[n + 1].condition[3] == 300)
    click(find("field", function(a) return a.key == "build." .. (n + 1) .. ".condition" end))
    type_in("os.exit()")
    test("code refused as a condition", p.build[n + 1].condition[3] == 300)
    press("Waves")
    local d = p.waves.delay
    click(find("number", function(a) return a[1][2] == "delay" and a[2] > 0 end))
    test("the delay between waves up by ten", p.waves.delay == d + 10)
    press("General")
    local was = p.options.take_items == true
    press("take items")
    test("an option ticked", (p.options.take_items == true) ~= was)
    ui:update({ keys = { "Z" }, ctrl = true, chars = "" }, 0.016)
    test("Ctrl+Z undoes it", (p.options.take_items == true) == was)
    press("Groups")
    press("+ Group")
    test("a new group", aui.group and p.groups[aui.group] ~= nil)
    press("Conditions")
    press("+ Condition")
    test("a new condition", p.conditions.condition1 ~= nil)
    local drawn = {}
    ui:draw(setmetatable({ ui_text = function(s) drawn[#drawn + 1] = s end },
        { __index = function() return function() return 0 end end }))
    test("drawn", #drawn > 10)
    press("AI")
    test("closed", ui.tui == nil)
end
-- }}}

print(string.format("\n%d/%d tests passed", pass_count, test_count))
os.exit(pass_count == test_count and 0 or 1)

--[[
Phase 9 Integration Test (Issue 912): one workflow through every part of
the editor, on a map made from nothing, then the saved map opened again
and played.

  made       a two-player melee map (editor/new_map.lua)
  terrain    ground raised, painted, water poured
  objects    a unit placed; a gold mine (a script unit) moved
  types      a custom unit type from the footman, stronger; one placed
  regions    a new region
  cameras    a new camera
  sounds     a new sound, its file imported
  triggers   a variable; entering the region counts, shows a message,
             plays the sound; a chat command applies the camera and pays;
             another wins the game once the region was visited
  AI         the computer player's profile: its first wave sooner
  imports    a texture imported
  music      the map's music changed
  saved      checked, saved; opened again: everything read back
  played     the game: the custom unit's hit points, the placed unit,
             the moved mine, the region trigger fired by walking in, the
             chat trigger, the edited AI's profile from the map, the
             music, no script errors
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
local new_map = require("editor.new_map")
local faction = require("ai.faction")

local MAP = os.tmpname() .. ".w3x"
local SAVED = os.tmpname() .. ".w3x"

local function tga(w, h)
    return string.char(0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, w % 256, math.floor(w / 256), h % 256, math.floor(h / 256), 32, 8)
        .. string.rep(string.char(40, 160, 60, 255), w * h)
end
local WAV = "RIFF" .. string.rep("\0", 4) .. "WAVEfmt " .. string.char(16, 0, 0, 0, 1, 0, 1, 0, 0x44, 0xAC, 0, 0,
    0x88, 0x58, 1, 0, 2, 0, 16, 0) .. "data" .. string.rep("\0", 4) .. string.rep("\1\0", 2205)

-- {{{ Made
test_section("A map made from nothing")
local L
do
    local ok, _, layout = new_map.create(MAP, { name = "Integration", author = "Phase 9", width = 64, height = 64,
        melee = true, players = { { race = "human" }, { race = "orc", computer = true } } })
    L = layout
    test("made", ok)
end
local E = assert(editor.open(MAP, { root = DIR }))
local home = L.players[1]
-- }}}

-- {{{ Editing
test_section("Edited through every part of the editor")
local mine, foot_id, region, cam, horn
do
    -- terrain: a hill east of home, painted, and a pond north of it
    local hx, hy = home.x + 1200, home.y
    E:set_tool("raise"); E.brush.size = 2
    E:stroke_begin(nil, hx, hy); E:stroke(hx, hy); E:stroke(hx, hy); E:stroke_end()
    local i, j = E:tile_at(hx, hy)
    test("ground raised", E.terrain.tilepoints[j][i].height > 0)
    E:set_tool("paint"); E.brush.texture = 3
    E:stroke_begin(nil, hx, hy); E:stroke(hx, hy); E:stroke_end()
    test("ground painted", E.terrain.tilepoints[j][i].ground_texture == 3)
    E:set_tool("water")
    E:stroke_begin(nil, home.x, home.y + 1400); E:stroke(home.x, home.y + 1400); E:stroke_end()
    local wi, wj = E:tile_at(home.x, home.y + 1400)
    test("water poured", E.terrain.tilepoints[wj][wi].has_water)

    -- objects: the human's gold mine moved a little; a knight placed
    for _, o in ipairs(E.script_units) do
        if not mine or (o.x - home.x) ^ 2 + (o.y - home.y) ^ 2 < (mine.x - home.x) ^ 2 + (mine.y - home.y) ^ 2 then mine = o end
    end
    E:select({ mine }); E:move_selection(64, 0)
    test("a gold mine moved", mine.x ~= mine.orig.x)
    E:place_unit("hkni", 0, home.x - 400, home.y + 300, math.rad(90))
    test("a knight placed", #E.new_units == 1)

    -- types: a stronger footman, placed
    foot_id = E:new_type("units", "hfoo")
    E:set_field("units", foot_id, "uhpm", 777)
    E:set_field("units", foot_id, "unam", "Integration Guard")
    E:place_unit(foot_id, 0, home.x - 500, home.y + 300, math.rad(90))
    test("a custom type made and placed", foot_id and #E.new_units == 2)

    -- regions, cameras, sounds
    region = E:new_region("Pond", home.x - 300, home.y + 900, home.x + 300, home.y + 1200)
    cam = E:new_camera("Overlook", home.x, home.y)
    E:camera_from_view(cam, home.x, home.y + 200, 2400, 120, 300, 65)
    horn = E:new_sound("Horn", "war3mapImported\\Horn.wav")
    E:import_bytes(WAV, "war3mapImported\\Horn.wav")
    test("a region, a camera, a sound", region and cam.distance == 2400 and E:sound_file(horn.file) == WAV)

    -- triggers
    E:new_variable("Visits", "integer", 0)
    local t = E:new_trigger("Pond visit")
    E:add_block(t, "events", "enters_region", { region = region.var })
    E:add_block(t, "conditions", "owner_is", { unit = "entering", player = 0 })
    E:add_block(t, "actions", "set_variable", { variable = "Visits", value = "udg_Visits + 1" })
    E:add_block(t, "actions", "display_text", { text = "Someone reached the pond" })
    E:add_block(t, "actions", "play_sound", { sound = horn.var })
    local t2 = E:new_trigger("Overlook")
    E:add_block(t2, "events", "player_chat", { player = 0, text = "-look", exact = true })
    E:add_block(t2, "actions", "apply_camera", { camera = cam.var, player = 0, seconds = 1 })
    E:add_block(t2, "actions", "gold", { player = 0, op = "add", value = 250 })
    -- a victory condition (issue 912's play-test scenario)
    local t3 = E:new_trigger("Victory")
    E:add_block(t3, "events", "player_chat", { player = 0, text = "-win", exact = true })
    E:add_block(t3, "conditions", "integer_compare", { a = { expr = "udg_Visits" }, compare = ">=", b = 1 })
    E:add_block(t3, "actions", "victory", { player = 0 })
    test("triggers with no problems", #E:check_triggers() == 0, (E:check_triggers()[1] or {}).message)

    -- AI: the orc's first wave sooner
    E:load_ai({ root = DIR, dir = MAP .. ".no-profiles" })
    local orc = E:ai_profile_of(1)
    test("the computer player's profile", orc ~= nil and orc.source == "derived")
    if orc then
        E:ai_set(orc, { "name" }, "Integration Orcs")
        E:ai_set(orc, { "waves", "initial_delay" }, 15)
    end

    -- imports and music
    E:import_bytes(tga(8, 8), "war3mapImported\\Banner.tga")
    for _, m in ipairs(E:music()) do if m.call == "SetMapMusic" then E:set_music(m, "Sound\\Music\\mp3Music\\Human1.mp3") end end
    test("a texture imported", E:import_named("war3mapImported\\Banner.tga") ~= nil)
    test("the music changed", E:music()[1] and E:music()[1].file == "Sound\\Music\\mp3Music\\Human1.mp3")
    test("many steps to undo", #E.history.done >= 25, tostring(#E.history.done))
end
-- }}}

-- {{{ Saved and opened again
test_section("Saved, and opened again")
do
    local probs = E:check_triggers({ full = true })
    test("the whole script loads", #probs == 0, (probs[1] or {}).message)
    local ok, rep = E:save(SAVED)
    test("saved", ok, tostring(rep))
    local files = E:files()
    for _, name in ipairs({ "war3map.w3e", "war3map.j", "war3map.w3u", "war3mapEditor.lua", faction.map_file(1),
                            "war3mapImported\\Banner.tga", "war3mapImported\\Horn.wav" }) do
        test("wrote " .. name, files[name] ~= nil)
    end
    local E2 = assert(editor.open(SAVED, { root = DIR }))
    test("the triggers back", #E2:triggers() == 3 and E2:variable_named("Visits") ~= nil)
    test("the region, camera and sound back", E2:camera_named(cam.var) and E2:sound_named(horn.var)
        and (function() for _, r in ipairs(E2:regions()) do if r.var == region.var then return true end end end)())
    test("the imports back", E2:import_named("war3mapImported\\Banner.tga") ~= nil)
    test("the custom type back", E2:object_table("units").custom[foot_id] ~= nil)
    local i, j = E2:tile_at(home.x + 1200, home.y)
    test("the raised, painted ground back", E2.terrain.tilepoints[j][i].height > 0 and E2.terrain.tilepoints[j][i].ground_texture == 3)
    local placed = 0
    for _, o in ipairs(E2.script_units) do if o.id == "hkni" or o.id == foot_id then placed = placed + 1 end end
    test("the placed units now the script's", placed == 2)
    E2:load_ai({ root = DIR, dir = SAVED .. ".no-profiles" })
    test("the AI profile back from the map", E2:ai_profile_of(1) and E2:ai_profile_of(1).profile.name == "Integration Orcs")
end
-- }}}

-- {{{ Played
test_section("Played")
do
    local s = require("demo.wc3map.scene").load(SAVED)
    local g = require("demo.wc3map.game").new(s, { player = 0, placed = false, minimap = false, vision = false })
    local asked = {}
    g.on_camera = function(r) asked[#asked + 1] = r end
    local V = g.run_script({ ai = "auto", ai_dir = SAVED .. ".no-profiles" })
    test("the script runs", V and #V.errors == 0, V and V.errors[1] and V.errors[1].message)
    local guard, knight, mine_now
    for _, u in ipairs(g.units) do
        if u.id == foot_id then guard = u end
        if u.id == "hkni" then knight = u end
        if u.id == "ngol" and math.abs(u.x - mine.x) < 1 and math.abs(u.y - mine.y) < 1 then mine_now = u end
    end
    test("the custom unit, with its hit points", guard and guard.hp_max == 777 and guard.name == "Integration Guard")
    test("the knight", knight and knight.player == 0)
    test("the mine where it was moved", mine_now ~= nil)
    test("the melee start", (function() for _, u in ipairs(g.units) do if u.id == "htow" then return true end end end)())
    test("the map's music", V.map_music == "Sound\\Music\\mp3Music\\Human1.mp3", tostring(V.map_music))
    test("the edited AI from the map", g.ai_manager.how[1] == "map:" .. faction.map_file(1)
        and g.ai_manager.players[1].profile_name == "Integration Orcs", tostring(g.ai_manager.how[1]))
    -- the knight walks into the pond region
    local cx, cy = (region.left + region.right) / 2, (region.bottom + region.top) / 2
    g.walk_to(knight, cx, cy)
    local seen = false
    for _ = 1, 200 do
        g.tick(0.1)
        if (V.env.udg_Visits or 0) > 0 then seen = true break end
    end
    test("walking into the region fired its trigger", seen, "knight at " .. math.floor(knight.x) .. "," .. math.floor(knight.y))
    local said = false
    for _, m in ipairs(V.messages) do if tostring(m.text):find("reached the pond", 1, true) then said = true end end
    test("its message", said)
    local heard = V.sounds_played[#V.sounds_played]
    test("its sound", heard and heard.file == "war3mapImported\\Horn.wav")
    local gold0 = V.natives.GetPlayerState(V.natives.Player(0), V.env.PLAYER_STATE_RESOURCE_GOLD)
    V:chat(0, "-look")
    g.tick(0.05)
    local gold1 = V.natives.GetPlayerState(V.natives.Player(0), V.env.PLAYER_STATE_RESOURCE_GOLD)
    local r = asked[#asked]
    test("the chat command: the camera", r and r.distance == 2400 and r.rotation == 120)
    test("and the gold", gold1 - gold0 == 250, gold0 .. " -> " .. gold1)
    V:chat(0, "-win")
    g.tick(0.05)
    test("the victory condition met: won", V.outcome == "victory", tostring(V.outcome))
    for _ = 1, 150 do g.tick(0.1) end
    local runner = g.ai_manager.players[1].runner
    test("the orc AI's first wave at the edited time", runner and runner.state.wave >= 1, runner and tostring(runner.state.wave))
    test("still no script errors", #V.errors == 0, V.errors[1] and V.errors[1].message)
end
-- }}}

os.remove(MAP)
os.remove(SAVED)
print(string.format("\n%d/%d tests passed", pass_count, test_count))
os.exit(pass_count == test_count and 0 or 1)

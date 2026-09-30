--[[
Tests for the sound editor (Issue 907): DAoW 5.4b's sounds found in its
protected script (CreateSound and its setters) and its music; a sound's
file, flags and volume changed (a setter the script didn't call added),
the music's file changed, undone; a new sound made in the editor and
played by an editor trigger; its file imported into the map and found
there; saved and played: the game's sounds have the new settings, the
trigger's sound is heard (V.sounds_played), and the VM keeps sounds.
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
local sounds = require("editor.sounds")

-- {{{ Literals
test_section("Reading calls")
do
    local a = sounds.split_args('"a,b\\"c",false,$A, f(1,2) ,"x"')
    test("arguments split at the top level", #a == 5 and a[1] == '"a,b\\"c"' and a[4] == "f(1,2)")
    test("literals", sounds.literal("$A") == 10 and sounds.literal("false") == false
        and sounds.literal('"Sound\\\\X.wav"') == "Sound\\X.wav" and sounds.literal("0x10") == 16)
    test("and back", sounds.jass("Sound\\X.wav") == '"Sound\\\\X.wav"' and sounds.jass(true) == "true")
end
-- }}}

local E = assert(editor.open(DIR .. "/assets/DAoW-5.4b-PUBLIC-TEST.w3x"))

-- {{{ The map's sounds
test_section("DAoW's sounds")
local s1, plain
do
    local list = E:sounds()
    test("its sounds, from the script", #list == 85, tostring(#list))
    for _, s in ipairs(list) do
        if s.file == "Sound\\Music\\mp3Music\\PH1.mp3" then s1 = s end
        if not s.setters.volume and not plain then plain = s end
    end
    test("one read whole", s1 and s1.looping == false and s1.fade_in == 10 and s1.eax == "DefaultEAXON"
        and s1.label == "PHMusic" and s1.duration == 0x44BEE and s1.channel == 7 and s1.volume == 127)
    local played = 0
    for _, s in ipairs(list) do played = played + s.plays end
    test("where they're played", played > 20, tostring(played))
    local calls = {}
    for _, m in ipairs(E:music()) do calls[m.call] = (calls[m.call] or 0) + 1 end
    test("the music: the map's and the themes played", calls.SetMapMusic == 1 and (calls.PlayThematicMusic or 0) >= 10)
end
-- }}}

-- {{{ Changed
test_section("Changed")
local new_music = "Sound\\Music\\mp3Music\\Comradeship.mp3"
do
    E:set_sound(s1, "looping", true)
    E:set_sound(s1, "volume", 90)
    E:set_sound(s1, "file", "Sound\\Music\\mp3Music\\Doom.mp3")
    E:set_sound(plain, "volume", 50)
    for _, m in ipairs(E:music()) do if m.call == "SetMapMusic" then E:set_music(m, new_music) end end
    local text = E:script_text()
    test("the call rewritten", text:find('CreateSound("Sound\\\\Music\\\\mp3Music\\\\Doom.mp3",true,false,false,10,10,"DefaultEAXON")', 1, true) ~= nil)
    test("its volume setter rewritten", text:find("SetSoundVolume(" .. s1.var .. ",90)", 1, true) ~= nil)
    test("a volume setter added where there was none", text:find("call SetSoundVolume(" .. plain.var .. ",50)", 1, true) ~= nil)
    test("the music's file", text:find(new_music:gsub("\\", "\\\\"), 1, true) ~= nil)
    E:set_sound(plain, "pitch", 1.5)
    E:undo()
    test("undone", plain.pitch == plain.orig.pitch)
end
-- }}}

-- {{{ The editor's own sounds
test_section("A new sound, played by a trigger")
local horn
do
    horn = E:new_sound("Horn", "war3mapImported\\Horn.wav")
    test("made", horn.var == "gg_snd_Horn" and E:sound_named("gg_snd_Horn") == horn)
    local wav = "RIFF" .. string.rep("\0", 4) .. "WAVEfmt " .. string.char(16, 0, 0, 0, 1, 0, 1, 0, 0x44, 0xAC, 0, 0,
        0x88, 0x58, 1, 0, 2, 0, 16, 0) .. "data" .. string.rep("\0", 4) .. string.rep("\1\0", 4410)
    E:import_bytes(wav, "war3mapImported\\Horn.wav")
    local d, where = E:sound_file(horn.file)
    test("its file found in the map", d == wav and where == "map")
    E:set_sound(horn, "volume", 100)
    local t = E:new_trigger("Horn blows")
    E:add_block(t, "events", "player_chat", { player = 0, text = "-horn", exact = true })
    E:add_block(t, "actions", "play_sound", { sound = horn.var })
    test("the trigger's JASS plays it", E:trigger_jass(t):find("call PlaySoundBJ(gg_snd_Horn)", 1, true) ~= nil)
    local code = E:trigger_code()
    test("made at the start", code.functions:find("set gg_snd_Horn = CreateSound(", 1, true) ~= nil
        and code.globals:find("sound gg_snd_Horn = null", 1, true) ~= nil)
    test("nothing wrong", #E:check_triggers() == 0, (E:check_triggers()[1] or {}).message)
    local t2 = E:new_trigger("Bad sound")
    E:add_block(t2, "events", "map_init")
    E:add_block(t2, "actions", "play_sound", { sound = "gg_snd_Nothing" })
    local found = false
    for _, p in ipairs(E:check_triggers()) do if p.message == "no sound gg_snd_Nothing" then found = true end end
    test("a missing sound found", found)
    E:delete_trigger(t2)
    test("the script's own sounds aren't deleted", not E:delete_sound(s1))
end
-- }}}

-- {{{ Saved and played
test_section("Saved, and played")
local TMP = os.tmpname() .. ".w3x"
do
    local ok, why = E:save(TMP)
    test("saved", ok, tostring(why))
    local s = require("demo.wc3map.scene").load(TMP)
    local g = require("demo.wc3map.game").new(s, { player = 0, placed = false, minimap = false, vision = false, combat = false })
    local V = g.run_script({ ai = "none" })
    test("the script runs", V and #g.units > 1000 and #V.errors == 0, V and V.errors[1] and V.errors[1].message)
    local h = V.env[s1.var]
    test("the changed sound, as the game has it", type(h) == "table" and h.kind == "sound"
        and h.file == "Sound\\Music\\mp3Music\\Doom.mp3" and h.looping == true and h.volume == 90,
        type(h) == "table" and tostring(h.file) or tostring(h))
    local p = V.env[plain.var]
    test("the one given a volume", type(p) == "table" and p.volume == 50)
    test("the map's music", V.map_music == new_music, tostring(V.map_music))
    local heard
    g.on_sound = function(ev) heard = ev end
    V:chat(0, "-horn")
    g.tick(0.05)
    local last = V.sounds_played[#V.sounds_played]
    test("the trigger played the new sound", last and last.file == "war3mapImported\\Horn.wav" and last.sound.volume == 100)
    test("and the world heard it", heard and heard.file == "war3mapImported\\Horn.wav")
    local E2 = assert(editor.open(TMP))
    local h2 = E2:sound_named("gg_snd_Horn")
    test("opened again: the new sound read back, not twice", h2 and h2.kind == "editor" and h2.volume == 100
        and #E2:sounds() == 86, tostring(#E2:sounds()))
    test("the script's own changed sound is the script's now", E2:sound_named(s1.var).file == "Sound\\Music\\mp3Music\\Doom.mp3")
    os.remove(TMP)
end
-- }}}

-- {{{ The panel
test_section("The sound editor's panel")
do
    local played
    local ui = require("editor.ui").new(E, 1280, 720, { run_tests = false,
        play_sound = function(bytes, ext) played = { bytes = bytes, ext = ext } return true end, stop_sound = function() end })
    local function click(b) ui:update({ mx = b.x + 2, my = b.y + 2, lp = true, keys = {}, chars = "" }, 0.016) end
    local function press(label)
        local b
        for _, x in ipairs(ui.buttons) do if x.label == label then b = x end end
        if not b and ui.tui then b = ui.tui:button(label) end
        if b then click(b) end
        return b ~= nil
    end
    local function type_in(text)
        ui:update({ keys = {}, chars = text }, 0.016)
        ui:update({ keys = { "ENTER" }, chars = "" }, 0.016)
    end
    test("opened from the toolbar", press("Sounds") and ui.panel == "sounds")
    local sui = ui.tui
    sui:press({ action = "pick", arg = horn })
    test("the new sound chosen, its file found in the map", sui.sel == horn and sui.where == "map")
    press("Play")
    test("played through the window", played and played.ext == ".wav" and played.bytes:sub(1, 4) == "RIFF")
    local v = horn.volume
    local minus
    for _, b in ipairs(sui.buttons) do if b.action == "step" and b.arg[1] == "volume" and b.arg[2] < 0 then minus = b end end
    click(minus)
    test("volume stepped down", horn.volume == v - 8)
    press("Looping")
    test("looping ticked", horn.looping == true)
    local fb
    for _, b in ipairs(sui.buttons) do if b.action == "field" and b.arg.key == "label" then fb = b end end
    click(fb)
    type_in("HornLabel")
    test("a label typed", horn.label == "HornLabel")
    press("Music")
    local m1
    for _, b in ipairs(sui.buttons) do if b.action == "field" and b.arg.key == "music1" then m1 = b end end
    click(m1)
    type_in("Sound\\Music\\mp3Music\\War2IntroMusic.mp3")
    test("a music file typed", E:music()[1].file == "Sound\\Music\\mp3Music\\War2IntroMusic.mp3")
    click(sui:button("Sounds"))      -- the tab (the toolbar's button has the same name)
    sui:press({ action = "pick", arg = horn })
    press("Delete")
    test("the editor's sound deleted", E:sound_named("gg_snd_Horn") == nil)
    ui:update({ keys = { "Z" }, ctrl = true, chars = "" }, 0.016)
    test("and back with Ctrl+Z", E:sound_named("gg_snd_Horn") ~= nil)
    press("Sounds")
    test("closed", ui.tui == nil)
end
-- }}}

print(string.format("\n%d/%d tests passed", pass_count, test_count))
os.exit(pass_count == test_count and 0 or 1)

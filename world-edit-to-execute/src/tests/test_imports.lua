--[[
Tests for the import manager (Issue 908): DAoW 5.4b's files beyond its
own listed with the names the map refers to (its listfile is gone),
kinds, what uses each, validation; a file imported, one replaced, one
renamed (a named one and an unnamed one), one deleted (named and
unnamed), undo; exported; saved into a copy of the map (in place: the
deleted ones gone, the new ones there, every other file as it was) and
the copy opened again; and the patcher taking files out.
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
local imports = require("editor.imports")
local mpq = require("mpq")

-- a made-up 4x2 TGA (32 bits)
local function tga(w, h)
    local head = string.char(0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, w % 256, math.floor(w / 256), h % 256,
        math.floor(h / 256), 32, 8)
    return head .. string.rep(string.char(10, 20, 30, 255), w * h)
end

-- {{{ Validation
test_section("Reading files as their kind")
do
    test("kinds", imports.kind_of("x\\A.mdx") == "model" and imports.kind_of("b.BLP") == "texture"
        and imports.kind_of("c.wav") == "sound" and imports.kind_of("d.zzz") == "other")
    test("a TGA", imports.validate("a.tga", tga(4, 2)).message == "TGA 4x2, 32 bits")
    test("a broken model", imports.validate("a.mdx", "MDLXjunk").status == "error")
    local wav = "RIFF" .. string.rep("\0", 4) .. "WAVEfmt " .. string.char(16, 0, 0, 0, 1, 0, 1, 0, 0x44, 0xAC, 0, 0,
        0x88, 0x58, 1, 0, 2, 0, 16, 0) .. "data" .. string.rep("\0", 4) .. string.rep("\0", 88200)
    local v = imports.validate("a.wav", wav)
    test("a WAV: a second at 44100", v.status == "ok" and v.message == "WAV 1.0 s at 44100 Hz", v.message)
    local names = {}
    imports.variants("Units\\Orc\\Grunt\\Grunt.mdl", names)
    test("a model path's variants", names[1] == "Units\\Orc\\Grunt\\Grunt.mdx"
        and names[2] == "war3mapImported\\Units\\Orc\\Grunt\\Grunt.mdx")
end
-- }}}

local E = assert(editor.open(DIR .. "/assets/DAoW-5.4b-PUBLIC-TEST.w3x"))

-- {{{ Listing
test_section("DAoW's files")
local named_model, unnamed_tex, unnamed_other
do
    local list = E:imports()
    local named, used, models = 0, 0, 0
    for _, f in ipairs(list) do
        if not f.unnamed then named = named + 1 end
        if #f.users > 0 then used = used + 1 end
        if f.kind == "model" then models = models + 1 end
        if f.kind == "model" and not f.unnamed and #f.users > 0 and not named_model then named_model = f end
        if f.kind == "texture" and f.unnamed and not unnamed_tex then unnamed_tex = f
        elseif f.kind == "texture" and f.unnamed and not unnamed_other then unnamed_other = f end
    end
    test("its files, not the map's own", #list > 150 and not E:import_named("war3map.w3e"), tostring(#list))
    test("most named from what the map refers to", named >= 90, tostring(named))
    test("each with what uses it", used >= 90 and named_model.users[1]:match("^units %w+ umdl"),
        named_model and named_model.users[1])
    test("models", models > 50)
    local v = E:validate_import(named_model.name)
    test("a model read", v.status == "ok" and v.message:match("^MDX"), v.message)
    test("unused ones found", #E:unused_imports() > 0)
end
-- }}}

-- {{{ Changes
test_section("Imported, replaced, renamed, deleted")
local TMPDIR = os.tmpname() .. "-imp"
os.execute('mkdir -p "' .. TMPDIR .. '"')
do
    local f = io.open(TMPDIR .. "/Portrait.tga", "wb")
    f:write(tga(8, 8))
    f:close()
    local n = #E:imports()
    test("a file imported from disk", E:import_file(TMPDIR .. "/Portrait.tga") and E:import_named("war3mapImported\\Portrait.tga")
        and #E:imports() == n + 1)
    E:undo()
    test("undone", not E:import_named("war3mapImported\\Portrait.tga") and #E:imports() == n)
    E:redo()
    E:import_bytes(tga(16, 16), "war3mapImported\\Portrait.tga")
    test("replaced", E:import_named("war3mapImported\\Portrait.tga").size == #tga(16, 16) and #E:imports() == n + 1)
    test("its bytes, as they'll be saved", E:import_data("war3mapImported\\Portrait.tga") == tga(16, 16))
    local old_bytes = E:import_data(named_model.name)
    test("a named file renamed", E:rename_import(named_model.name, "war3mapImported\\Renamed.mdx")
        and E:import_named("war3mapImported\\Renamed.mdx") and not E:import_named(named_model.name))
    test("with its bytes", E:import_data("war3mapImported\\Renamed.mdx") == old_bytes)
    E:undo()
    test("the rename undone in one step", E:import_named(named_model.name) ~= nil
        and not E:import_named("war3mapImported\\Renamed.mdx"))
    test("an unnamed file named", E:rename_import(unnamed_tex.name, "war3mapImported\\Found.blp")
        and E:import_named("war3mapImported\\Found.blp"))
    test("an unnamed file deleted", E:delete_import(unnamed_other.name) and not E:import_named(unnamed_other.name))
    test("exported to disk", E:export_import("war3mapImported\\Found.blp", TMPDIR .. "/Found.blp")
        and io.open(TMPDIR .. "/Found.blp", "rb"):read("*a"):sub(1, 4) == "BLP1")
end
-- }}}

-- {{{ Saved
test_section("Saved, and opened again")
local TMP = os.tmpname() .. ".w3x"
do
    local ok, rep = E:save(TMP)
    test("saved in place", ok and rep.how == "patched", type(rep) == "table" and tostring(rep.how) or tostring(rep))
    local a = mpq.open(TMP)
    test("the imported file there", a:extract("war3mapImported\\Portrait.tga") == tga(16, 16))
    test("the named one there", a:has("war3mapImported\\Found.blp"))
    local blocks = {}
    for _, f in ipairs(a:files()) do blocks[f.block] = f end
    test("the unnamed ones taken out", not blocks[unnamed_tex.block] and not blocks[unnamed_other.block])
    test("the rest as they were", a:extract(named_model.name) == E:import_data(named_model.name))
    local listed = a:extract("(listfile)") or ""
    test("listed", listed:find("war3mapImported\\Portrait.tga", 1, true) ~= nil)
    a:close()
    local E2 = assert(editor.open(TMP))
    test("opened again: the new names", E2:import_named("war3mapImported\\Portrait.tga") ~= nil
        and E2:import_named("war3mapImported\\Found.blp") ~= nil and not E2:import_named(unnamed_tex.name))
    test("one fewer unnamed file, twice", #E2:imports() == #E:imports())
    -- the game still plays it
    local s = require("demo.wc3map.scene").load(TMP)
    local g = require("demo.wc3map.game").new(s, { player = 0, placed = false, minimap = false, vision = false, combat = false })
    local V = g.run_script({ ai = "none" })
    test("the map's script runs on the copy", V and #g.units > 1000 and #V.errors == 0)
    os.remove(TMP)
end
os.execute('rm -rf "' .. TMPDIR .. '"')
-- }}}

-- {{{ The panel
test_section("The import manager's panel")
do
    local E3 = assert(editor.open(DIR .. "/assets/DAoW-5.4b-PUBLIC-TEST.w3x"))
    local ui = require("editor.ui").new(E3, 1280, 800, { run_tests = false })
    local function click(b) ui:update({ mx = b.x + 2, my = b.y + 2, lp = true, keys = {}, chars = "" }, 0.016) end
    local function press(label)
        local b
        for _, x in ipairs(ui.buttons) do if x.label == label then b = x end end
        if not b and ui.tui then b = ui.tui:button(label) end
        if b then click(b) end
        return b ~= nil
    end
    local function find(action, f)
        for _, b in ipairs(ui.tui.buttons) do if b.action == action and (not f or f(b.arg)) then return b end end
    end
    local function type_in(text)
        ui:update({ keys = {}, chars = text }, 0.016)
        ui:update({ keys = { "ENTER" }, chars = "" }, 0.016)
    end
    test("opened from the toolbar", press("Files") and ui.panel == "files")
    press("texture")
    local first = find("pick")
    click(first)
    local fui = ui.tui
    test("a texture chosen and read", fui.sel and fui.sel.kind == "texture" and fui.valid and fui.valid.status ~= "error")
    test("its picture", fui.preview and fui.preview.width > 0)
    local loaded = 0
    ui:draw(setmetatable({ ui_image_load = function() loaded = loaded + 1 return 0 end },
        { __index = function() return function() return 0 end end }))
    test("drawn once into its picture", loaded == 1)
    click(find("field", function(a) return a.key == "rename" end))
    type_in("war3mapImported\\Panel.blp")
    test("renamed by typing", E3:import_named("war3mapImported\\Panel.blp") ~= nil and fui.sel.name == "war3mapImported\\Panel.blp")
    local dir = os.tmpname() .. "-fui"
    os.execute('mkdir -p "' .. dir .. '"')
    click(find("field", function(a) return a.key == "export" end))
    type_in(dir .. "/out.blp")
    press("Export")
    test("exported where typed", io.open(dir .. "/out.blp", "rb") ~= nil)
    click(find("field", function(a) return a.key == "import_path" end))
    type_in(dir .. "/out.blp")
    click(find("field", function(a) return a.key == "import_name" end))
    type_in("Textures\\Again.blp")
    press("Import")
    test("imported from disk under the name typed", E3:import_named("Textures\\Again.blp") ~= nil
        and fui.sel.name == "Textures\\Again.blp")
    press("Delete")
    test("deleted", E3:import_named("Textures\\Again.blp") == nil)
    press("unused")
    test("the unused filter", #fui:shown() == #E3:unused_imports())
    press("Files")
    test("closed", ui.tui == nil)
    os.execute('rm -rf "' .. dir .. '"')
end
-- }}}

-- {{{ The patcher
test_section("Files taken out by the patcher")
do
    local patch = require("mpq.patch")
    local f = io.open(DIR .. "/assets/Daow4.4.w3x", "rb")
    local bytes = f:read("*a")
    f:close()
    local out, rep = patch.apply(bytes, { ["war3map.wtg"] = false, ["war3map.shd"] = false })
    test("a report", out and rep.removed >= 1, rep and tostring(rep.removed))
    local P = os.tmpname() .. ".w3x"
    local o = io.open(P, "wb"); o:write(out); o:close()
    local a = mpq.open(P)
    test("gone", not a:has("war3map.shd") and a:has("war3map.w3e") and a:extract("war3map.w3e") ~= nil)
    a:close()
    os.remove(P)
end
-- }}}

print(string.format("\n%d/%d tests passed", pass_count, test_count))
os.exit(pass_count == test_count and 0 or 1)

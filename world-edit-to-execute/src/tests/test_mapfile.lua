--[[
Tests for map projects, the unified format (Issue 911c): Lua data read
back; DAoW 5.4b exported to a folder (readable forms where they give the
file back byte for byte, its unnamed files kept by block, its hash table)
and built back: every hash slot finds the same bytes, and the game plays
it; edits made in the folder's text reach the map (its name, a doodad,
the terrain, an object type), assets added and taken away; the WoW layer
left out with a warning; a lightweight project (no assets) built with
them from elsewhere; one .wex file packed and unpacked (a stored ZIP,
checked); the editor opening a .wex and saving it back; a new map as a
project; the command line.
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

local mapfile = require("editor.mapfile")
local patch = require("mpq.patch")
local mpq = require("mpq")

local TMP = os.tmpname()
os.remove(TMP)
local P = TMP .. "-proj"
local MAP = DIR .. "/assets/DAoW-5.4b-PUBLIC-TEST.w3x"

local function read(p) local f = io.open(p, "rb") if not f then return nil end local d = f:read("*a") f:close() return d end
local function write(p, d) local f = assert(io.open(p, "wb")) f:write(d) f:close() end

-- every hash slot's bytes
local function slot_bytes(path)
    local t = patch.tables(read(path))
    local a = mpq.open(path)
    local out = {}
    for s, e in pairs(t.slots) do
        if e[4] ~= 0xFFFFFFFE then
            local ok, d = pcall(a._storm.read, a._storm, string.format("File%08d.xxx", e[4]))
            out[s] = ok and d or false
        end
    end
    a:close()
    return out
end
local function same_slots(x, y)
    local A, B = slot_bytes(x), slot_bytes(y)
    local same, n = 0, 0
    for s, d in pairs(A) do
        if d then n = n + 1; if B[s] == d then same = same + 1 end end
    end
    return same, n
end

-- {{{ Lua data
test_section("Lua data, one item a line")
do
    local t = { name = "x\ny\0z", n = 0.1, big = 2 ^ 40, list = { { a = 1, b = "q\"" }, { a = -2.5e-7 } }, _skip = 1 }
    local text = mapfile.data_text(t, { "list" }, "t")
    local back = mapfile.read_data(text, "t")
    test("read back", back.name == t.name and back.n == 0.1 and back.big == 2 ^ 40 and back.list[1].b == 'q"'
        and back.list[2].a == -2.5e-7 and back._skip == nil)
    test("each item on its own line", select(2, text:gsub("\n", "")) == 5)
    test("as data only", mapfile.read_data("return os.exit()", "x") == nil)
end
-- }}}

-- {{{ Exported and built
test_section("DAoW 5.4b as a project, and back")
local report
do
    local ok, rep = mapfile.export(MAP, P)
    report = rep
    test("exported", ok and rep.files == 201, ok and rep.files or tostring(rep))
    test("readable forms for the map's data", rep.readable >= 10, tostring(rep.readable))
    test("its unnamed files kept", rep.unnamed == 83, tostring(rep.unnamed))
    test("the folders", read(P .. "/info.lua") and read(P .. "/terrain/points.txt") and read(P .. "/objects/doodads.lua")
        and read(P .. "/definitions/units.lua") and read(P .. "/manifest.lua") and read(P .. "/wow/README.txt"))
    local info = read(P .. "/info.lua")
    test("the map info as Lua", info:find("players=", 1, true) ~= nil)
    local rows = 0
    for _ in read(P .. "/terrain/points.txt"):gmatch("[^\n]+") do rows = rows + 1 end
    local t = require("parsers.w3e").parse(mpq.open(MAP):extract("war3map.w3e"))
    test("the terrain a row a line", rows == t.height, rows .. " / " .. t.height)
    local dl = 0
    for _ in read(P .. "/objects/doodads.lua"):gmatch("\n{") do dl = dl + 1 end
    test("a doodad a line", dl > 10000, tostring(dl))
    test("no problems", #mapfile.validate(P, "wc3") == 0)
    local B = TMP .. "-built.w3x"
    local bok, brep = mapfile.build(P, B)
    test("built", bok, tostring(brep))
    local same, n = same_slots(MAP, B)
    test("every hash slot finds the same bytes", same == n and n == 201, same .. "/" .. n)
    local wrap = require("mpq.map_wrapper").read(B)
    test("its header as it was", wrap and wrap.map_name == require("mpq.map_wrapper").read(MAP).map_name)
    local s = require("demo.wc3map.scene").load(B)
    local g = require("demo.wc3map.game").new(s, { player = 0, placed = false, minimap = false, vision = false, combat = false })
    local V = g.run_script({ ai = "none" })
    test("the game plays the built map", V and #g.units > 1000 and #V.errors == 0, V and V.errors[1] and V.errors[1].message)
    os.remove(B)
end
-- }}}

-- {{{ Edited in the folder
test_section("Edited as text")
do
    local info = read(P .. "/info.lua")
    -- the map's own name (keys are written sorted: it comes before playable_height)
    write(P .. "/info.lua", (info:gsub('([,{])name="[^"]*",playable_height', '%1name="Edited in a text editor",playable_height', 1)))
    local doo = read(P .. "/objects/doodads.lua")
    local first = doo:match("\n({[^\n]+})")
    local x = tonumber(first:match("position={[^}]-x=(%-?[%d%.e%-]+)"))
    write(P .. "/objects/doodads.lua", doo:gsub("position={([^}]-)x=" .. tostring(first:match("position={[^}]-x=(%-?[%d%.e%-]+)")):gsub("%p", "%%%0"),
        "position={%1x=" .. (x + 64), 1))
    local pts = read(P .. "/terrain/points.txt")
    write(P .. "/terrain/points.txt", "2400" .. pts:sub(5))          -- the first point's height: 0x2400
    local units = read(P .. "/definitions/units.lua")
    local edited_units = units:gsub('value="([^"]-)",var_type=3', 'value="Edited Name",var_type=3', 1)
    write(P .. "/definitions/units.lua", edited_units)
    os.execute('mkdir -p "' .. P .. '/assets/war3mapImported"')
    local tga = string.char(0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 2, 0, 32, 8) .. string.rep("\255", 16)
    write(P .. "/assets/war3mapImported/Added.tga", tga)
    -- a named asset taken away
    local m = mapfile.read_data(read(P .. "/manifest.lua"), "m")
    local gone
    for name, e in pairs(m.files) do if not gone and e.path:match("^assets/") and not e.unnamed then gone = { name, e.path } end end
    os.remove(P .. "/" .. gone[2])
    write(P .. "/wow/quests.lua", "return {}\n")
    local probs = mapfile.validate(P, "wc3")
    local wow_warned, gone_warned = false, false
    for _, p in ipairs(probs) do
        if p.message:find("WoW-only", 1, true) then wow_warned = true end
        if p.message:find("taken away", 1, true) then gone_warned = true end
    end
    test("validation: the WoW layer and the file taken away", wow_warned and gone_warned)
    local B = TMP .. "-edited.w3x"
    assert(mapfile.build(P, B))
    local a = mpq.open(B)
    local w = require("parsers.w3i").parse(a:extract("war3map.w3i"))
    test("the map's name edited", w.name == "Edited in a text editor", w.name)
    local d = require("parsers.doo").parse(a:extract("war3map.doo"))
    test("a doodad moved", math.abs(d.doodads[1].position.x - (x + 64)) < 0.01)
    local t = require("parsers.w3e").parse(a:extract("war3map.w3e"))
    test("a terrain point raised", t.tilepoints[0][0].height_raw == 0x2400)
    test("an object type renamed", a:extract("war3map.w3u"):find("Edited Name", 1, true) ~= nil)
    test("an asset added, and listed", a:extract("war3mapImported\\Added.tga") == tga
        and (a:extract("(listfile)") or ""):find("war3mapImported\\Added.tga", 1, true) ~= nil)
    test("an asset taken out", not a:has(gone[1]))
    a:close()
    os.remove(B)
end
-- }}}

-- {{{ Lightweight
test_section("Lightweight, and one file")
do
    local L = TMP .. "-light"
    local ok, rep = mapfile.export(MAP, L, { lightweight = true })
    test("exported without assets", ok and rep.left_out > 80 and #mapfile.walk(L .. "/assets") == 0, tostring(rep.left_out))
    local bad = false
    for _, p in ipairs(mapfile.validate(L, "wc3")) do if p.level == "error" then bad = true end end
    test("can't build alone", bad and not mapfile.build(L, TMP .. "-l.w3x"))
    local B = TMP .. "-l.w3x"
    assert(mapfile.build(L, B, { assets_from = MAP }))
    local same, n = same_slots(MAP, B)
    test("built with the assets from the map", same == n and n == 201, same .. "/" .. n)
    os.remove(B)
    -- one .wex file
    local W = TMP .. ".wex"
    local pok, count = mapfile.pack(L, W)
    test("packed", pok and read(W):sub(1, 4) == "PK\3\4")
    local U = TMP .. "-unpacked"
    local uok, un = mapfile.unpack(W, U)
    test("unpacked: every file the same", uok and un == count and read(U .. "/terrain/points.txt") == read(L .. "/terrain/points.txt")
        and read(U .. "/manifest.lua") == read(L .. "/manifest.lua"))
    local z = read(W)
    local at = z:find("points.txt", 1, true) + 20
    write(W .. ".bad", z:sub(1, at - 1) .. "X" .. z:sub(at + 1))
    test("a damaged one refused", not mapfile.unpack(W .. ".bad", U .. "2"))
    test("a .wex is a project", mapfile.is_project(W) and mapfile.is_project(L) and not mapfile.is_project(MAP))
    os.execute('rm -rf "' .. L .. '" "' .. U .. '" "' .. U .. '2"')
    os.remove(W); os.remove(W .. ".bad")
end
-- }}}

-- {{{ The editor
test_section("The editor opens a project and saves it back")
do
    local N = TMP .. "-new.w3x"
    assert(require("editor.new_map").create(N, { name = "Project Map", width = 32, height = 32,
        players = { { race = "human" }, { race = "orc", computer = true } } }))
    local NP = TMP .. "-new"
    assert(mapfile.export(N, NP))
    local W = TMP .. "-new.wex"
    assert(mapfile.pack(NP, W))
    local E = assert(require("editor").open(W))
    test("a .wex opened as a map", E.project == W and #E.script_units == 2)
    local pts0 = read(NP .. "/terrain/points.txt")
    local x, y = E.script_units[1].x, E.script_units[1].y
    E:set_tool("raise")
    E:stroke_begin(nil, x, y + 400); E:stroke(x, y + 400); E:stroke_end()
    local t = E:new_trigger("Hello")
    E:add_block(t, "events", "map_init")
    E:add_block(t, "actions", "display_text", { text = "from a project" })
    local ok, why = E:save()
    test("saved back into the .wex", ok, tostring(why))
    local E2 = assert(require("editor").open(W))
    local i, j = E2:tile_at(x, y + 400)
    test("opened again: the raised ground", E2.terrain.tilepoints[j][i].height > 0)
    test("and the trigger", E2:trigger_named("Hello") ~= nil)
    local U = TMP .. "-new-u"
    assert(mapfile.unpack(W, U))
    test("the project's text changed where the map did", read(U .. "/terrain/points.txt") ~= pts0
        and read(U .. "/scripts/war3mapEditor.lua"):find("from a project", 1, true) ~= nil)
    os.execute('rm -rf "' .. NP .. '" "' .. U .. '"')
    os.remove(N); os.remove(W)
end
-- }}}

-- {{{ The command line
test_section("The command line")
do
    local C = TMP .. "-cli"
    local out = io.popen('cd "' .. DIR .. '" && luajit src/editor/mapfile.lua export assets/Daow4.4.w3x "' .. C
        .. '" 2>&1 && luajit src/editor/mapfile.lua validate "' .. C .. '" 2>&1 && luajit src/editor/mapfile.lua build "'
        .. C .. '" "' .. C .. '.w3x" 2>&1'):read("*a")
    test("export, validate, build", out:find("export: ", 1, true) and out:find("no problems", 1, true)
        and out:find("build: ", 1, true), out)
    local same, n = same_slots(DIR .. "/assets/Daow4.4.w3x", C .. ".w3x")
    test("Daow4.4 the same, slot for slot", same == n and n > 20, same .. "/" .. n)
    os.execute('rm -rf "' .. C .. '"'); os.remove(C .. ".w3x")
end
-- }}}

os.execute('rm -rf "' .. P .. '"')
print(string.format("\n%d/%d tests passed", pass_count, test_count))
os.exit(pass_count == test_count and 0 or 1)

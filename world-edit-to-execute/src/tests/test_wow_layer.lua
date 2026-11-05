--[[
Tests for issue W10a: the WoW layer of a map (src/editor/wowmap.lua and
the WoW layer in src/editor/mapfile.lua). One map holds both games: a map
project keeps WoW maps under wow/World/Maps/<dir>/, byte for byte, and
the editor reads their tiles through the W client's own reader.

The WoW map used here is made by W02's converter from a made WC3 terrain
(no WC3 or WoW install): two tiles with a lake, a tree and a hut. The
reader's part needs the W client's reader library ($W_CLIENT_BUILD: a
folder holding libwreaders.so and wreaders.h); without it that part is
skipped. The map project part needs StormLib (a map from assets/).

    luajit src/tests/test_wow_layer.lua [project folder]
]]

-- {{{ Setup
local DIR = arg[1] or (debug.getinfo(1, "S").source:match("^@(.-)/?src/tests/[^/]*$"))
    or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if DIR == "" then DIR = "." end
if DIR:sub(-1) ~= "/" then DIR = DIR .. "/" end
package.path = DIR .. "src/?.lua;" .. DIR .. "src/?/init.lua;" .. package.path

local w3e = require("parsers.w3e")
local coords = require("wowbuild.coords")
local wowbuild = require("wowbuild")
local wowmap = require("editor.wowmap")
local mapfile = require("editor.mapfile")

local test_count, pass_count, skip_count = 0, 0, 0
local function test(name, condition, msg)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name .. (msg and ": " .. tostring(msg) or ""))
    end
end
local function skip(name, why)
    skip_count = skip_count + 1
    print("  [SKIP] " .. name .. ": " .. why)
end
local function section(name) print("\n=== " .. name .. " ===") end
local function quote(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end
local function read(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end
local function write(path, text)
    local dir = path:match("^(.*)/[^/]*$")
    if dir then os.execute("mkdir -p " .. quote(dir)) end
    local f = assert(io.open(path, "wb"))
    f:write(text)
    f:close()
end
local function has(problems, level, needle)
    for _, p in ipairs(problems) do
        if (not level or p.level == level) and p.message:find(needle, 1, true) then return true end
    end
    return false
end
local function levels(problems)
    local o = {}
    for _, p in ipairs(problems) do o[#o + 1] = p.level .. ": " .. p.message end
    return table.concat(o, "; ")
end
local function same_tree(a, b)
    local la, lb = mapfile.walk(a), mapfile.walk(b)
    if #la ~= #lb or #la == 0 then return false, #la .. " files, " .. #lb .. " files" end
    for i, p in ipairs(la) do
        if lb[i] ~= p then return false, p .. " / " .. tostring(lb[i]) end
        if read(a .. "/" .. p) ~= read(b .. "/" .. p) then return false, p .. " differs" end
    end
    return true
end
local TMP = os.tmpname()
os.remove(TMP)
os.execute("mkdir -p " .. quote(TMP))
-- }}}

-- {{{ A WoW map, made by W02's converter
-- 200 x 65 tile points: two ADT tiles across, one down; a lake in the west
local function made_terrain(w, h)
    local t = setmetatable({
        width = w, height = h, offset_x = -64 * (w - 1), offset_y = -64 * (h - 1),
        tileset_code = "L", ground_tilesets = { "Ldrt", "Lgrs" }, cliff_tilesets = {}, tilepoints = {},
    }, w3e.Terrain)
    for j = 0, h - 1 do
        t.tilepoints[j] = {}
        for i = 0, w - 1 do
            local lake = i >= 20 and i <= 30 and j >= 20 and j <= 30
            t.tilepoints[j][i] = { height = lake and -100 or (i * 4), layer_height = 2, ground_texture = (i > 100) and 1 or 0,
                                   texture_details = 0, has_water = lake, water_level = 64 + 89.6,
                                   is_blight = false, is_ramp = false }
        end
    end
    return t
end
local terrain = made_terrain(200, 65)
local L0 = coords.layout(terrain)
local function at(i, j) return L0.offset_x + i * 128, L0.offset_y + j * 128 end
local function doodad(id, i, j, n)
    local x, y = at(i, j)
    return { id = id, variation = 0, position = { x = x, y = y, z = 0 }, angle = 0.7, scale = { x = 1, y = 1, z = 1 },
             flags = 2, life = 100, creation_number = n }
end
local models = TMP .. "/models.lua"
write(models, [[
return { format = 1,
  doodads = { types = { LTlt = { name = "tree", wow = "World\\Test\\Tree.m2", checked = false },
                        LTwm = { name = "a hut", wow = "World\\Test\\Hut.wmo", size = { 20, 10 }, checked = false } } },
  units = { fallback = { name = "Unmapped unit", wow = "World\\Test\\Crate.m2", checked = false } },
}
]])
local made_map = {
    doodads = { version = 8, doodads = { doodad("LTlt", 10, 40, 1), doodad("LTwm", 150, 30, 2) } },
    units = { version = 8, units = {} },
    info = { version = 25, flags = { use_custom_forces = false },
             players = { { number = 0, name = "Red", start_x = select(1, at(5, 5)), start_y = select(2, at(5, 5)) } } },
}
local BUILD = TMP .. "/build"
local report = wowbuild.convert("made.w3x", BUILD, { terrain = terrain, map = made_map, models = models, name = "WC3_made" })
local MAPDIR = BUILD .. "/World/Maps/WC3_made"
-- the files the converter leaves in the map's folder: the WDT, the WDL, two
-- tiles, and (W02c, since the stacks were joined) its registration and
-- loading screen
local NFILES = #mapfile.walk(MAPDIR)
-- }}}

-- {{{ A map's files
section("A WoW map's files, from the files present")
do
    test("the converter made a WoW map", report and read(MAPDIR .. "/WC3_made.wdt") ~= nil)
    test("its folder: the WDT, the WDL, two tiles, its registration and loading screen", NFILES == 6, NFILES)
    test("its folder is a WoW map: it holds its WDT", table.concat(wowmap.maps(BUILD), ",") == "WC3_made")
    write(BUILD .. "/World/Maps/NoWdt/NoWdt_1_1.adt", "not a map")
    test("a folder without its WDT isn't one", table.concat(wowmap.maps(BUILD), ",") == "WC3_made")
    local f = wowmap.files(BUILD, "WC3_made")
    test("the WDT, the WDL and the tiles, by kind", f.wdt == "WC3_made.wdt" and f.wdl == "WC3_made.wdl" and #f.tiles == 2)
    test("tiles sorted, numbered west to east, then north to south", f.tiles[1].tx + 1 == f.tiles[2].tx
        and f.tiles[1].ty == f.tiles[2].ty and f.tiles[1].file == string.format("WC3_made_%d_%d.adt", f.tiles[1].tx, f.tiles[1].ty))
    local others = #f.other                -- W02c's registration and loading screen, on the joined stacks
    write(MAPDIR .. "/WC3_made_99_1.adt", "out of range")
    write(MAPDIR .. "/notes.txt", "a note")
    f = wowmap.files(BUILD, "WC3_made")
    test("a tile number past 63, or another file: not a tile", #f.tiles == 2 and #f.other == others + 2)
    os.remove(MAPDIR .. "/WC3_made_99_1.adt")
    os.remove(MAPDIR .. "/notes.txt")
    local m, why = wowmap.open(BUILD, "Missing")
    test("a map that isn't there: refused, saying so", m == nil and why:find("no World/Maps/Missing/Missing.wdt", 1, true), why)
    m, why = wowmap.open(BUILD, "../etc")
    test("a name that isn't a folder name: refused", m == nil and why ~= nil)
    m = wowmap.open(BUILD, "WC3_made")
    test("opened: its tiles listed, nothing read yet", m and #m.tiles == 2 and next(m.read_tiles) == nil)
    local t, twhy = m:tile(0, 0)
    test("a tile it hasn't: nil and why", t == nil and twhy:find("no tile 0, 0", 1, true), twhy)
end
-- }}}

-- {{{ Read through the W client's reader
section("Its tiles, read through the W client's reader")
local lib, lib_why = wowmap.reader()
if not lib then
    skip("the tiles through the W client's reader", lib_why)
else
    local m = wowmap.open(BUILD, "WC3_made")
    local e1, e2 = m.tiles[1], m.tiles[2]
    local t, why = m:tile(e1.tx, e1.ty)
    test("the west tile read", t ~= nil, why)
    test("the WDT's blend-map form: 8 bits a point, as W02 writes it", m.big_alpha == true)
    t = t or { chunks = {}, doodads = {}, buildings = {}, liquids = {}, textures = {} }
    test("256 chunks, each its column and row", #t.chunks == 256 and t.chunks[1].ix == 0 and t.chunks[256].iy == 15
        and t.chunks[18].ix == 1 and t.chunks[18].iy == 1)
    test("each with 145 heights", #(t.chunks[1].heights or {}) == 145)
    -- the ground against W02's own heights: a corner of a chunk is a WC3
    -- tile point (the layout's vertex), here x * 4 units high at column i
    local worst = 0
    local job = select(2, wowbuild.convert("made.w3x", TMP .. "/again", { terrain = terrain, map = made_map, models = models,
                                                                            name = "WC3_made" }))
    local L = job.layout
    for k = 1, 256, 17 do
        local c = t.chunks[k]
        local R0, C0 = (e1.ty - L.ty0) * 128 + c.iy * 8, (e1.tx - L.tx0) * 128 + c.ix * 8
        local X, Y = L:vertex_world(R0, C0)
        worst = math.max(worst, math.abs(c.x - X), math.abs(c.y - Y))
    end
    test("each chunk where W02's layout puts it (yards)", worst < 0.01, worst)
    test("the texture names, as W02 wrote them", #t.textures >= 1 and t.chunks[1].layers[1].texture == t.textures[1])
    local layered = false
    for _, c in ipairs(t.chunks) do
        if #c.layers > 1 then layered = #c.layers[2].alpha == 4096 and c.layers[1].alpha == nil end
    end
    test("a blend map is 64 x 64 strengths a layer above the first", layered or #t.textures == 1)
    test("shadow and tints: 4096 and 145", #t.chunks[1].shadow == 4096 and #t.chunks[1].tint == 145)
    test("the lake: water in the west tile", #t.liquids > 0 and t.liquids[1].kind ~= nil
        and #t.liquids[1].wet == 64 and #t.liquids[1].height == 81, #t.liquids)
    test("the tree: a model placed, with its name and unique id", #t.doodads == 1
        and t.doodads[1].model == "World\\Test\\Tree.m2" and t.doodads[1].uid ~= nil, t.doodads[1] and t.doodads[1].model)
    local t2 = m:tile(e2.tx, e2.ty)
    test("the hut: a building in the east tile, with its box", t2 and #t2.buildings >= 1
        and t2.buildings[1].model == "World\\Test\\Hut.wmo" and #t2.buildings[1].lo == 3)
    test("a tile read once is kept", m:tile(e1.tx, e1.ty) == t)
    local ok, bad = m:read_all()
    test("every tile reads", ok, table.concat(bad, "; "))
    -- a damaged tile
    local broken = TMP .. "/broken"
    os.execute("mkdir -p " .. quote(broken .. "/World/Maps/WC3_made"))
    for _, name in ipairs(mapfile.walk(MAPDIR)) do write(broken .. "/World/Maps/WC3_made/" .. name, read(MAPDIR .. "/" .. name)) end
    local bytes = read(MAPDIR .. "/" .. e1.file)
    write(broken .. "/World/Maps/WC3_made/" .. e1.file, bytes:sub(1, 200))
    local mb = wowmap.open(broken, "WC3_made")
    local bt, bwhy = mb:tile(e1.tx, e1.ty)
    test("a damaged tile: nil and the reader's why, with its file", bt == nil and bwhy:find(e1.file, 1, true), bwhy)
end
-- }}}

-- {{{ The map project's WoW layer
section("A map project holds both games: its WoW layer")
local P = TMP .. "/proj"
local stormlib = pcall(function() require("mpq").open(DIR .. "assets/Daow4.4.w3x"):close() end)
if not stormlib then
    skip("the WoW layer of a map project", "no StormLib to export a WC3 map")
else
    local ok, rep = mapfile.export(DIR .. "assets/Daow4.4.w3x", P)
    test("a WC3 map exported as a project", ok, rep)
    test("its README says what wow/ holds", (read(P .. "/wow/README.txt") or ""):find("World/Maps", 1, true) ~= nil)
    local aok, arep = mapfile.add_wow(P, BUILD, "WC3_made")
    test("the WoW map added to it", aok and arep.files == NFILES and arep.tiles == 2, arep)
    local same, why = same_tree(MAPDIR, P .. "/wow/World/Maps/WC3_made")
    test("... byte for byte, at the client's own paths", same, why)
    local layer = mapfile.read_data(read(P .. "/wow/layer.lua") or "", "layer")
    test("wow/layer.lua records each file's size and CRC-32", layer and layer.maps.WC3_made
        and layer.maps.WC3_made.files["WC3_made.wdt"].size == #read(MAPDIR .. "/WC3_made.wdt"))
    test("not a project: refused", not mapfile.add_wow(TMP .. "/nothing", BUILD, "WC3_made"))
    test("a map that isn't there: refused", not mapfile.add_wow(P, BUILD, "Missing"))

    local probs = mapfile.validate(P, "wow")
    test("the WoW layer validates", not has(probs, "error", "") and not has(probs, "warn", ""), levels(probs))
    local wprobs = mapfile.validate(P, "wc3")
    test("a WC3 build: the WoW map left out, said once", has(wprobs, "info", "the WoW map WC3_made (" .. NFILES .. " files): WoW-only")
        and not has(wprobs, "error", ""), levels(wprobs))
    local B = TMP .. "/proj.w3x"
    local bok = mapfile.build(P, B)
    test("... and the WC3 map still builds", bok and read(B) ~= nil)

    -- the WoW build: the layer out as a loose folder, byte for byte
    local OUT = TMP .. "/wow-out"
    local wok, wrep = mapfile.build_wow(P, OUT)
    test("the WoW build: the layer out as a loose folder", wok and wrep.files == NFILES and wrep.maps == 1, wrep)
    same, why = same_tree(MAPDIR, OUT .. "/World/Maps/WC3_made")
    test("... the map that was added, byte for byte", same, why)
    test("... and nothing of the WC3 part, nor the layer's own notes", #mapfile.walk(OUT) == NFILES)

    -- a WC3 export again leaves the layer as it is
    mapfile.export(DIR .. "assets/Daow4.4.w3x", P)
    same = same_tree(MAPDIR, P .. "/wow/World/Maps/WC3_made")
    test("the WC3 part exported again: the WoW layer kept, and its record", same and read(P .. "/wow/layer.lua") ~= nil)

    -- what validation sees
    local adt = P .. "/wow/World/Maps/WC3_made/" .. wowmap.files(BUILD, "WC3_made").tiles[1].file
    local was = read(adt)
    write(adt, was .. "\0")
    test("a tile changed since it was added: said, not an error", has(mapfile.validate(P, "wow"), "info", "changed since it was added"))
    write(adt, was)
    write(P .. "/wow/quests.lua", "return {}\n")
    test("a file not at a client path: left out of the WoW build, said",
        has(mapfile.validate(P, "wow"), "warn", "wow/quests.lua: not under wow/World/"))
    os.remove(P .. "/wow/quests.lua")
    write(P .. "/wow/World/Maps/Loose/Loose_1_1.adt", "x")
    local lp = mapfile.validate(P, "wow")
    test("a map folder with no WDT: an error, and the WoW build refused", has(lp, "error", "Loose has no Loose.wdt")
        and not mapfile.build_wow(P, TMP .. "/refused"), levels(lp))
    os.execute("rm -rf " .. quote(P .. "/wow/World/Maps/Loose"))
    write(P .. "/wow/World/Maps/WC3_made/WC3_made_70_1.adt", "x")
    test("a ground file not named as a tile: warned", has(mapfile.validate(P, "wow"), "warn", "so no tile"))
    os.remove(P .. "/wow/World/Maps/WC3_made/WC3_made_70_1.adt")
    os.rename(P .. "/wow/World/Maps/WC3_made/WC3_made.wdt", TMP .. "/wdt")
    test("an added map whose WDT is gone: an error", has(mapfile.validate(P, "wow"), "error", "was added but"))
    os.rename(TMP .. "/wdt", P .. "/wow/World/Maps/WC3_made/WC3_made.wdt")
    test("a project mode it doesn't build: said", has(mapfile.validate(P, "ps2"), "error", "no build for ps2"))
    if lib then
        local rp = mapfile.validate(P, "wow", { read = true })
        test("validated with every tile read through the W client's reader", not has(rp, "error", ""), levels(rp))
    else
        skip("validation reading every tile", lib_why)
    end

    -- the editor: a map opened from the project has its WoW layer
    local editor = require("editor")
    local E, eerr = editor.open(P)
    test("the editor opens the project", E ~= nil, eerr)
    if E then
        test("... and lists its WoW maps", table.concat(E:wow_maps(), ",") == "WC3_made")
        local wm, wwhy = E:wow_map("WC3_made")
        test("... and opens one, kept for the tools", wm ~= nil and E:wow_map("WC3_made") == wm and #wm.tiles == 2, wwhy)
        if lib then
            local t = wm:tile(wm.tiles[1].tx, wm.tiles[1].ty)
            test("... its tiles read through the W client's reader", t and #t.chunks == 256)
        end
        local E2 = editor.open(DIR .. "assets/Daow4.4.w3x")
        local none, nwhy
        if E2 then none, nwhy = E2:wow_map("WC3_made") end
        test("a map opened from a .w3x has no WoW layer: said", E2 and #E2:wow_maps() == 0 and none == nil
            and (nwhy or ""):find("no WoW layer", 1, true), nwhy)
    end
end
-- }}}

os.execute("rm -rf " .. quote(TMP))

print(string.format("\n%s\nTests: %d passed, %d failed, %d skipped", string.rep("=", 50), pass_count,
    test_count - pass_count, skip_count))
os.exit(pass_count == test_count and 0 or 1)

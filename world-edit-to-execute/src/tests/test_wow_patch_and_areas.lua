--[[
Tests for issue W10h: patch-W.MPQ never behind the folder, and more areas
a map. After any save that writes a file of a map W02c registered
(ground, water, objects, tiles added or taken off, the WDT and WDL, area
rows), the folder's tables and patch-W.MPQ are made again
(editor/wowareas.lua's forms, through wowbuild.output), and its
server-stamp and install plan after them; when patch-W.MPQ can't be made
(no StormLib, patch = false, a failure) the old one is removed, never
left stale. A map's areas past its first nine take the slot's second id
block and the lowest free bits of the areas' block (wowbuild.registration).

StormLib isn't needed: a stand-in (package.loaded["mpq.stormlib"])
writes each archive as a plain list of its files, so what patch-W.MPQ
would carry is compared with the folder file by file. Everything here
needs the W client's reader library ($W_CLIENT_BUILD); without it the
tests are skipped, saying so.

    luajit src/tests/test_wow_patch_and_areas.lua [project folder]
]]

-- {{{ Setup
local DIR = arg[1] or (debug.getinfo(1, "S").source:match("^@(.-)/?src/tests/[^/]*$"))
    or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if DIR == "" then DIR = "." end
if DIR:sub(-1) ~= "/" then DIR = DIR .. "/" end
package.path = DIR .. "src/?.lua;" .. DIR .. "src/?/init.lua;" .. package.path

local ffi = require("ffi")
local bit = require("bit")
local w3e = require("parsers.w3e")
local bw = require("parsers.binwrite")
local coords = require("wowbuild.coords")
local wowbuild = require("wowbuild")
local adt = require("wowbuild.adt")
local wowmap = require("editor.wowmap")
local wt = require("editor.wowterrain")
local tiles = require("editor.wowtiles")
local pl = require("editor.wowplace")
local history = require("editor.history")

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

-- {{{ a stand-in for StormLib: an archive as "name\0size\0bytes" a file
local real_stormlib = package.loaded["mpq.stormlib"]
local fake = { fail_write = false, made = 0 }
function fake.create(path)
    local f = assert(io.open(path, "wb"))
    fake.made = fake.made + 1
    local a = {}
    function a:write(name, bytes)
        if fake.fail_write then error("the stand-in refuses " .. name, 0) end
        f:write(name, "\0", #bytes, "\0", bytes)
    end
    function a:close() f:close() end
    return a
end
local function use_fake(on) package.loaded["mpq.stormlib"] = on and fake or real_stormlib end
local function no_stormlib()
    package.loaded["mpq.stormlib"] = { create = function() error("StormLib not found (the stand-in for none)", 0) end }
end
-- what an archive written by the stand-in holds: { [name] = bytes }
local function archive(path)
    local s = read(path)
    if not s then return nil end
    local out, at = {}, 1
    while at <= #s do
        local z1 = s:find("\0", at, true)
        local z2 = s:find("\0", z1 + 1, true)
        local name, n = s:sub(at, z1 - 1), tonumber(s:sub(z1 + 1, z2 - 1))
        out[name] = s:sub(z2 + 1, z2 + n)
        at = z2 + n + 1
    end
    return out
end
-- }}}
use_fake(true)

local TMP = os.tmpname()
os.remove(TMP)
os.execute("mkdir -p " .. quote(TMP))

local ORIGIN, TILE, CHUNK, CELL = coords.ORIGIN, coords.TILE, coords.CHUNK, coords.CELL
local KEY = 32768
local HT = 256                -- half cells a tile side (128 cells)
local function u32(s, at)
    local a, b, c, d = s:byte(at + 1, at + 4)
    return a + b * 256 + c * 65536 + d * 16777216
end
local function u16(s, at) local a, b = s:byte(at + 1, at + 2) return a + b * 256 end
local function i16(s, at) local v = u16(s, at) return v >= 32768 and v - 65536 or v end
local function le32(v) return string.char(v % 256, math.floor(v / 256) % 256, math.floor(v / 65536) % 256, math.floor(v / 16777216) % 256) end
local function put(s, at, bytes) return s:sub(1, at) .. bytes .. s:sub(at + #bytes + 1) end
local function differ(a, b)
    if #a ~= #b then return -1 end
    local n = 0
    for p = 1, #a do if a:byte(p) ~= b:byte(p) then n = n + 1 end end
    return n
end
-- }}}

-- {{{ A WoW map, made by W02's converter
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
wowbuild.convert("made.w3x", BUILD, { terrain = terrain, map = made_map, models = models, name = "WC3_made" })
local MAPDIR = BUILD .. "/World/Maps/WC3_made"

local copies = 0
local function copy_map()
    copies = copies + 1
    local root = TMP .. "/copy" .. copies
    os.execute("mkdir -p " .. quote(root .. "/World/Maps") .. " && cp -r " .. quote(MAPDIR) .. " " .. quote(root .. "/World/Maps/"))
    return root, root .. "/World/Maps/WC3_made"
end
local function names(m)
    local out = {}
    for _, e in ipairs(m.tiles) do out[#out + 1] = e.tx .. "_" .. e.ty end
    return table.concat(out, " ")
end
-- }}}

local lib, lib_why = wowmap.reader()
if not lib then
    skip("W10h's tests", "no W client reader library: " .. tostring(lib_why))
else

-- {{{ helpers
local ww = require("editor.wowwater")
local ar = require("editor.wowareas")
local registration = require("wowbuild.registration")
local server_stamp = require("wowbuild.server_stamp")
local install_plan = require("wowbuild.install_plan")
local mapfile = require("editor.mapfile")
local dbc = require("wowbuild.dbc")
local WEST, EAST = "WC3_made_31_32.adt", "WC3_made_32_32.adt"
local function list(t) return table.concat(t, ",") end
local function chunk_centre(tx, ty, ix, iy)
    return ORIGIN - (ty * 16 + iy + 0.5) * CHUNK, ORIGIN - (tx * 16 + ix + 0.5) * CHUNK
end
local builds = 0
-- the whole build folder copied (its tables, patch, stamp and plan with it)
local function copy_build()
    builds = builds + 1
    local root = TMP .. "/build-copy" .. builds
    os.execute("cp -r " .. quote(BUILD) .. " " .. quote(root))
    return root, root .. "/World/Maps/WC3_made"
end
-- every map file of the folder against patch-W.MPQ: the same names and bytes
local function patch_matches(root)
    local a = archive(root .. "/patch-W.MPQ")
    if not a then return false, "no patch-W.MPQ" end
    local want, n = {}, 0
    for _, f in ipairs(mapfile.walk(root .. "/World/Maps")) do
        local dir, name = f:match("^([^/]+)/([^/]+)$")
        local lower = (name or ""):lower()
        if lower:match("%.adt$") or lower:match("%.wdt$") or lower:match("%.wdl$") or lower:match("%.blp$") then
            want["World\\Maps\\" .. dir .. "\\" .. name] = read(root .. "/World/Maps/" .. f)
        end
    end
    for name, bytes in pairs(want) do
        n = n + 1
        if a[name] ~= bytes then return false, name .. " differs" end
    end
    for name in pairs(a) do
        if name:match("^World") and not want[name] then return false, name .. " in the patch, not the folder" end
    end
    return true, n
end
local function stamp_current(root)
    return read(root .. "/" .. server_stamp.FILE) == server_stamp.text(root)
end
-- }}}

-- {{{ The converter's patch, through the stand-in
section("The converter's patch-W.MPQ, through the stand-in")
do
    local ok, n = patch_matches(BUILD)
    test("it carries every map file of the folder, byte for byte", ok and n == 4 + 1, n)
    test("the stamp names it, and is the folder's", (read(BUILD .. "/" .. server_stamp.FILE) or ""):find("patch-W.MPQ", 1, true)
        and stamp_current(BUILD))
    test("an install plan beside it", read(BUILD .. "/" .. install_plan.FILE) ~= nil)
end
-- }}}

-- {{{ Every kind of edit, saved: the patch made again
section("Ground, water, objects, tiles added and taken off: patch-W.MPQ made again each save")
do
    local root, folder = copy_build()
    local m = wowmap.open(root, "WC3_made", { stock_dbc = false })
    local x, y = chunk_centre(31, 32, 5, 5)
    local before = fake.made
    wt.raise(m, x, y, { radius = 10, amount = 3 })
    local written, why = wt.save(m)
    table.sort(written or {})
    test("ground raised, saved: the tile and the WDL", written and list(written) == "WC3_made.wdl," .. WEST, written and list(written) or why)
    local ok, bad = patch_matches(root)
    test("... patch-W.MPQ made again, carrying them as the folder has them", ok and fake.made == before + 1, bad)
    test("... the stamp written again, the folder's", stamp_current(root))
    test("... the install plan written again", read(root .. "/" .. install_plan.FILE) ~= nil
        and install_plan.read(root) ~= nil)

    ww.water(m, x, y, { radius = 12, level = (wt.ground(m, x, y) or 0) + 2 })
    wt.save(m)
    ok, bad = patch_matches(root)
    test("water put on, saved: the patch matches", ok, bad)

    assert(pl.load(m))
    pl.place(m, { model = "World\\Test\\Rock.m2", x = x + 5, y = y })
    wt.save(m)
    ok, bad = patch_matches(root)
    test("a model placed, saved: the patch matches", ok, bad)

    local t = tiles.add(m, 33, 32, { height = 20 })
    wt.save(m)
    ok, bad = patch_matches(root)
    test("a tile added, saved: the patch carries it and the new WDT", t and ok and archive(root .. "/patch-W.MPQ")
        ["World\\Maps\\WC3_made\\WC3_made_33_32.adt"] ~= nil, bad)
    tiles.remove(m, 33, 32)
    written = wt.save(m)
    ok, bad = patch_matches(root)
    test("taken off, saved: gone from the folder and the patch", ok and read(folder .. "/WC3_made_33_32.adt") == nil
        and archive(root .. "/patch-W.MPQ")["World\\Maps\\WC3_made\\WC3_made_33_32.adt"] == nil, bad)
    test("... and the stamp still the folder's", stamp_current(root))

    local stamp = read(root .. "/" .. server_stamp.FILE)
    before = fake.made
    written = wt.save(m)
    test("nothing edited: nothing written, the patch not made again", written and #written == 0 and fake.made == before
        and read(root .. "/" .. server_stamp.FILE) == stamp)
end
-- }}}

-- {{{ When patch-W.MPQ can't be made
section("When patch-W.MPQ can't be made: the old one removed, said")
do
    local root = copy_build()
    local m = wowmap.open(root, "WC3_made", { stock_dbc = false })
    local x, y = chunk_centre(31, 32, 3, 3)
    no_stormlib()
    wt.raise(m, x, y, { radius = 10, amount = 2 })
    local written, why = wt.save(m)
    local said = table.concat(m.forms and m.forms.warnings or {}, " | ")
    test("no StormLib: saved, the old patch removed", written ~= nil and read(root .. "/patch-W.MPQ") == nil, why)
    test("... said, as the converter says it", said:find("patch-W.MPQ not written (an older one removed)", 1, true), said)
    test("... the stamp written again, without it", stamp_current(root)
        and not (read(root .. "/" .. server_stamp.FILE) or ""):find("patch-W.MPQ", 1, true))

    use_fake(true)
    wt.raise(m, x, y, { radius = 10, amount = 2 })
    wt.save(m)
    test("StormLib back: made again at the next save", patch_matches(root))

    fake.fail_write = true
    wt.raise(m, x, y, { radius = 10, amount = 2 })
    written, why = wt.save(m)
    fake.fail_write = false
    test("a failure making it: the save says so", written == nil and (why or ""):find("couldn't be made again", 1, true), why)
    test("... the old one removed, said", read(root .. "/patch-W.MPQ") == nil
        and (why or ""):find("the old patch-W.MPQ was removed", 1, true))
    test("... no stamp or plan naming what changed", read(root .. "/" .. server_stamp.FILE) == nil
        and read(root .. "/" .. install_plan.FILE) == nil)
    test("... the tile itself written", wowmap.open(root, "WC3_made"):tile(31, 32) ~= nil
        and math.abs(wt.ground(wowmap.open(root, "WC3_made"), x, y) - wt.ground(m, x, y)) < 1e-3)

    local r2 = copy_build()
    local m2 = wowmap.open(r2, "WC3_made", { stock_dbc = false, patch = false })
    wt.raise(m2, x, y, { radius = 10, amount = 2 })
    wt.save(m2)
    said = table.concat(m2.forms and m2.forms.warnings or {}, " | ")
    test("patch = false: the old one removed, said", read(r2 .. "/patch-W.MPQ") == nil
        and said:find("patch = false", 1, true), said)

    -- the editor says it
    local P = TMP .. "/fake-project"
    os.execute("mkdir -p " .. quote(P) .. " && cp -r " .. quote(BUILD) .. " " .. quote(P .. "/wow"))
    local E = {}
    E.__index = E
    function E:say(text) self.messages[#self.messages + 1] = text end
    wowmap.attach(E)
    wt.attach(E)
    local e = setmetatable({ project_dir = P, history = history.new(50), dirty = {}, messages = {},
                             brush = { size = 1, strength = 1, wow_radius = 8, wow_amount = 2 } }, E)
    local em = assert(e:wow_edit("WC3_made"))
    em.opts.stock_dbc = false
    no_stormlib()
    e:wow_stroke_begin("raise", x, y)
    e:wow_stroke(x, y)
    e:wow_stroke_end()
    e:wow_save()
    use_fake(true)
    test("E:wow_save says the patch was removed", table.concat(e.messages, " | "):find("an older one removed", 1, true),
        table.concat(e.messages, " | "))
end
-- }}}

-- {{{ A map W02c didn't register
section("A map W02c didn't register: no patch carries it, nothing made for it")
do
    local root, folder = copy_build()
    os.remove(folder .. "/registration.lua")
    local patch = read(root .. "/patch-W.MPQ")
    local m = wowmap.open(root, "WC3_made", { stock_dbc = false })
    local x, y = chunk_centre(31, 32, 3, 3)
    local before = fake.made
    wt.raise(m, x, y, { radius = 10, amount = 2 })
    local written = wt.save(m)
    test("saved: its tiles; the folder's forms left as they were", written and #written > 0 and fake.made == before
        and m.forms and m.forms.skipped and read(root .. "/patch-W.MPQ") == patch)
end
-- }}}

-- {{{ A project's WoW layer carries the forms
section("A map project's WoW layer: the tables and patch-W.MPQ are its own, and go out with its WoW build")
do
    local P = TMP .. "/layer-project"
    os.execute("mkdir -p " .. quote(P) .. " && cp -r " .. quote(BUILD) .. " " .. quote(P .. "/wow"))
    os.remove(P .. "/wow/" .. server_stamp.FILE)
    os.remove(P .. "/wow/" .. install_plan.FILE)
    write(P .. "/wow/notes.txt", "a note")
    local probs = mapfile.validate_wow(P)
    local warned = {}
    for _, p in ipairs(probs) do if p.level == "warn" then warned[#warned + 1] = p.message end end
    test("validated: only the stray note warned of, not the tables or patch",
        #warned >= 1 and table.concat(warned, " | "):find("notes.txt", 1, true)
        and not table.concat(warned, " | "):find("DBFilesClient", 1, true)
        and not table.concat(warned, " | "):find("patch-W.MPQ", 1, true), table.concat(warned, " | "))
    local OUT = TMP .. "/wow-out"
    local ok = mapfile.build_wow(P, OUT)
    test("its WoW build carries them", ok and read(OUT .. "/patch-W.MPQ") == read(P .. "/wow/patch-W.MPQ")
        and read(OUT .. "/DBFilesClient/AreaTable.dbc") == read(P .. "/wow/DBFilesClient/AreaTable.dbc")
        and read(OUT .. "/server/dbc.sql") ~= nil and read(OUT .. "/notes.txt") == nil)
end
-- }}}

-- {{{ More than nine areas
section("A map's areas past its first nine")
do
    local root = copy_build()
    local m = wowmap.open(root, "WC3_made", { stock_dbc = false })
    local rows = {}
    for k = 1, 99 do rows[k] = ar.create(m, { name = "Area " .. k }) end
    local nope, nwhy = ar.create(m, { name = "Area 100" })
    test("99 areas besides the zone, then refused", rows[99] and nope == nil and ar.MAX == 100
        and (nwhy or ""):find("99 areas", 1, true), nwhy)
    test("the first nine: the zone's block, the slot's own bits", rows[9].ID == 9009 and rows[9].AreaBit == 3987)
    test("the tenth on: the slot's second block (10000-10089), the block's lowest free bits",
        rows[10].ID == 10000 and rows[10].AreaBit == 3096 and rows[99].ID == 10089 and rows[99].AreaBit == 3185)
    local x, y = chunk_centre(31, 32, 2, 2)
    wt.area(m, x, y, { area = 10089 })
    local written, why = wt.save(m)
    test("saved", written ~= nil, why)
    local names = wowmap.area_names(root)
    test("the overlay's table names them, 100 rows", names and names[10089] and names[10089].name == "Area 99"
        and names[9009].name == "Area 9")
    test("the chunk in area 10089, read again", wt.area_at(wowmap.open(root, "WC3_made"), x, y) == 10089)
    test("the scheme: 10000-18999 are the areas' too (a stock row there is replaced)", registration.in_scheme("area", 10000)
        and registration.in_scheme("area", 18999) and not registration.in_scheme("area", 19000)
        and registration.ids(1).area_more == 10090 and registration.ids(99).area_more_last == 18999)

    -- another map converted into the folder: every id and bit its own
    local rep = wowbuild.convert("two.w3x", root, { terrain = made_terrain(40, 40), map = made_map, models = models,
        name = "WC3_two", stock_dbc = false })
    local m2 = wowmap.open(root, "WC3_two", { stock_dbc = false })
    local a2 = rep and ar.create(m2, { name = "Second Glade" })
    local b2 = a2 and ar.create(m2, { name = "Second Shore" })
    test("the second map, slot 1: its own first bits (3986, 3985)", a2 and a2.ID == 9011 and a2.AreaBit == 3986
        and b2.AreaBit == 3985)
    for k = 3, 9 do ar.create(m2, { name = "Second " .. k }) end
    local c2 = ar.create(m2, { name = "Second 10" })
    test("... its tenth: id 10090, the next free bit of the block (3186)", c2 and c2.ID == 10090 and c2.AreaBit == 3186)
    local x2, y2 = chunk_centre(32, 32, 0, 0)
    test("... painted onto its own ground", wt.area(m2, x2, y2, { area = 10090 }) ~= nil)
    wt.save(m2)
    local ids, bits, clash = {}, {}, false
    local bytes = read(root .. "/DBFilesClient/AreaTable.dbc")
    local all = 0
    for _, id in ipairs(dbc.column(bytes, 1)) do if ids[id] then clash = true end ids[id] = true all = all + 1 end
    for _, b in ipairs(dbc.column(bytes, 4)) do if bits[b] then clash = true end bits[b] = true end
    test("the folder's AreaTable: 111 rows, no id or bit twice", all == 111 and not clash, all)
    local ok, n = patch_matches(root)
    test("... and patch-W.MPQ made again with both maps", ok and archive(root .. "/patch-W.MPQ")
        ["World\\Maps\\WC3_two\\WC3_two.wdt"] ~= nil, n)
end
-- }}}

end

use_fake(false)
os.execute("rm -rf " .. quote(TMP))

print(string.format("\n%s\nTests: %d passed, %d failed, %d skipped", string.rep("=", 50), pass_count,
    test_count - pass_count, skip_count))
os.exit(pass_count == test_count and 0 or 1)

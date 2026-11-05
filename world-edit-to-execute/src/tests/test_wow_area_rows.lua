--[[
Tests for issue W10g: a WoW map's own areas as AreaTable rows
(src/editor/wowareas.lua). Areas made, renamed and taken away on a map
W02c converted, with W02c's ids and explored-zones bits
(wowbuild.registration); painted onto chunks by W10f's area brush; saved
as the map's registration.lua and the folder's tables in every form
(wowbuild.output): the overlay's DBFilesClient/AreaTable.dbc, read back
through the W client's table reader (016-dbc: dbc_open, dbc_u32,
dbc_text) and wowmap.area_names, the server's SQL, and with stock tables
given, the merged table; the editor's steps with undo and redo around
saves.

The WoW map is made by W02's converter from a made WC3 terrain, as
test_wow_areas makes it. Everything here needs the W client's reader
library ($W_CLIENT_BUILD); without it the tests are skipped, saying so.

    luajit src/tests/test_wow_area_rows.lua [project folder]
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

local ar = require("editor.wowareas")
local registration = require("wowbuild.registration")
local dbc = require("wowbuild.dbc")
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
    skip("W10g's tests", "no W client reader library: " .. tostring(lib_why))
else

-- {{{ helpers
local WEST = "WC3_made_31_32.adt"
local function list(t) return table.concat(t, ",") end
local function chunk_centre(tx, ty, ix, iy)
    return ORIGIN - (ty * 16 + iy + 0.5) * CHUNK, ORIGIN - (tx * 16 + ix + 0.5) * CHUNK
end
local REG = read(MAPDIR .. "/registration.lua")
local reg0 = registration.read(MAPDIR .. "/registration.lua")
local Z, MAP, SLOT = reg0.ids.area, reg0.ids.map, reg0.slot
-- a table through the W client's reader: { fields, rows = { [i] = { id, map, parent, bit, flags, name } } }
local function read_table(path)
    local bytes = read(path)
    if not bytes then return nil end
    local buf = ffi.new("unsigned char[?]", #bytes)
    ffi.copy(buf, bytes, #bytes)
    local d, w = ffi.new("Dbc"), ffi.new("WWhy")
    if lib.dbc_open(d, buf, #bytes, w) ~= 0 then return nil, ffi.string(w.text) end
    local out = { fields = d.fields, rows = {} }
    for r = 0, d.rows - 1 do
        out.rows[r + 1] = { id = lib.dbc_u32(d, r, 1), map = lib.dbc_u32(d, r, 2), parent = lib.dbc_u32(d, r, 3),
                            bit = lib.dbc_u32(d, r, 4), flags = lib.dbc_u32(d, r, 5),
                            name = ffi.string(lib.dbc_text(d, r, 12)) }
    end
    return out
end
local function ids_of(t)
    local out = {}
    for _, r in ipairs(t and t.rows or {}) do out[#out + 1] = r.id end
    return list(out)
end
-- }}}

-- {{{ The map's registration
section("A converted map's registration: its zone, its one area")
do
    local root = copy_map()
    local m = wowmap.open(root, "WC3_made", { stock_dbc = false })
    local reg, why = ar.load(m)
    test("loaded: slot 0, map 900, zone 9000", reg and SLOT == 0 and MAP == 900 and Z == 9000, why)
    local l = ar.list(m)
    test("one area: the zone, its bit 4095, no parent", l and #l == 1 and l[1].id == Z and l[1].zone and l[1].bit == 4095
        and l[1].parent == 0)
    test("the scheme: nine more ids a slot, their bits under the zones'", registration.SUBAREAS == 9
        and registration.SUBAREA_BIT_TOP == 3995 and registration.subarea_bit(0, 1) == 3995
        and registration.subarea_bit(99, 9) == 3096 and registration.subarea_bit(1, 1) == 3986)
    local r2 = TMP .. "/no-registration"
    os.execute("mkdir -p " .. quote(r2 .. "/World/Maps") .. " && cp -r " .. quote(MAPDIR) .. " " .. quote(r2 .. "/World/Maps/"))
    os.remove(r2 .. "/World/Maps/WC3_made/registration.lua")
    local m2 = wowmap.open(r2, "WC3_made", { stock_dbc = false })
    local nope, nwhy = ar.create(m2, { name = "Glade" })
    test("a map without W02c's registration: no areas made, saying so", nope == nil
        and (nwhy or ""):find("registration.lua", 1, true), nwhy)
    local x1, y1 = chunk_centre(31, 32, 1, 1)
    local got = wt.area(m2, x1, y1, { area = 77 })
    test("... its chunks still take any number", got and got.chunks == 1 and wt.area_at(m2, x1, y1) == 77)
end
-- }}}

-- {{{ Areas made
section("Areas made: ids, bits, parents, flags")
local root, folder = copy_map()
local m = wowmap.open(root, "WC3_made", { stock_dbc = false })
do
    local a, why = ar.create(m, { name = "Hut |cFFFF0000Hollow|r" })
    test("the first: id 9001, bit 3995, in the zone", a and a.ID == Z + 1 and a.AreaBit == 3995 and a.ParentAreaID == Z
        and a.ContinentID == MAP, why)
    test("... its name a plain line", a and a.AreaName == "Hut Hollow")
    test("... the zone's other columns", a and a.Flags == 0 and a.MinElevation == -500 and a.LightID == 0
        and a.ExplorationLevel == 0)
    local b
    b, why = ar.create(m, { name = "Far Shore", parent = 0, flags = { "town", "rest_horde", "town" } })
    test("the second: id 9002, bit 3994, a zone of its own, town and Horde rest", b and b.ID == Z + 2 and b.AreaBit == 3994
        and b.ParentAreaID == 0 and b.Flags == 0x600000, why)
    local l = ar.list(m)
    test("listed by id", l and #l == 3 and l[2].name == "Hut Hollow" and l[3].flags == 0x600000)
    test("marked to save", m.areas_dirty == true)

    local cases = {
        { { name = "" }, "needs a name" }, { { name = "|cFF000000|r" }, "needs a name" },
        { { name = "X", parent = 1234 }, "parent" }, { { name = "X", parent = Z + 1 }, "parent" },
        { { name = "X", flags = { "bogus" } }, "no flag bogus" }, { { name = "X", flags = 1.5 }, "whole number" },
        { { name = "X", flags = -1 }, "whole number" },
    }
    for _, c in ipairs(cases) do
        local nope, nwhy = ar.create(m, c[1])
        test("refused: " .. c[2], nope == nil and (nwhy or ""):find(c[2], 1, true), nwhy)
    end
    local long = ar.create(m, { name = string.rep("a", 200), flags = 0x800 })
    test("a long name cut to 120 characters; flags as a number", long and #long.AreaName == 120 and long.Flags == 0x800)
    test("ar.change: renamed, flags set", ar.change(m, long.ID, { name = "Long Meadow", flags = { "sanctuary" } }) ~= nil
        and long.AreaName == "Long Meadow" and long.Flags == 0x800)
    test("ar.change: refused for an area not the map's", ar.change(m, 12, { name = "Elwynn" }) == nil)
    local nope, nwhy = ar.delete(m, Z)
    test("the zone: not taken away", nope == nil and (nwhy or ""):find("zone", 1, true), nwhy)
    test("an unused area taken away", ar.delete(m, long.ID) ~= nil and #ar.list(m) == 3)

    local m9 = wowmap.open((copy_map()), "WC3_made", { stock_dbc = false })
    local made, rows = 0, {}
    for k = 1, 9 do rows[k] = ar.create(m9, { name = "Area " .. k }) if rows[k] then made = made + 1 end end
    test("nine areas: the zone's block, the slot's own bits", made == 9 and rows[9].ID == Z + 9 and rows[9].AreaBit == 3987)
end
-- }}}

-- {{{ Painted and saved
section("Painted, saved: the registration and the folder's tables")
do
    local x, y = chunk_centre(31, 32, 4, 4)
    local got = wt.area(m, x, y, { radius = 2 * CHUNK, area = Z + 1 })
    test("painted with the new area", got and got.chunks > 0 and wt.area_at(m, x, y) == Z + 1)
    local written, why = wt.save(m)
    table.sort(written or {})
    test("saved: the tile and the registration", written and list(written) == WEST .. ",registration.lua",
        written and list(written) or why)
    local r = registration.read(folder .. "/registration.lua")
    test("registration.lua: three AreaTable rows, the rest as the converter wrote it", r and #r.rows.AreaTable == 3
        and r.rows.AreaTable[2].AreaName == "Hut Hollow" and r.written == reg0.written and r.slot == 0
        and #r.rows.Map == 1 and r.rows.Map[1].AreaTableID == Z)
    local t = read_table(root .. "/DBFilesClient/AreaTable.dbc")
    test("the overlay's AreaTable.dbc, through the W client's reader: 36 fields, the three rows", t and t.fields == 36
        and ids_of(t) == "9000,9001,9002", t and ids_of(t))
    test("... their map, parent, bit, flags and name", t and t.rows[2].map == MAP and t.rows[2].parent == Z
        and t.rows[2].bit == 3995 and t.rows[2].name == "Hut Hollow" and t.rows[3].parent == 0 and t.rows[3].flags == 0x600000
        and t.rows[1].name == reg0.rows.AreaTable[1].AreaName)
    local names, nwhy = wowmap.area_names(root)
    test("wowmap.area_names reads them", names and names[Z + 1] and names[Z + 1].name == "Hut Hollow"
        and names[Z + 1].parent == Z and names[Z + 2].map == MAP, nwhy)
    local mt = read_table(root .. "/DBFilesClient/Map.dbc")
    test("the other tables written as the converter writes them (Map.dbc: the map)", mt and mt.rows[1].id == MAP)
    local sql = read(root .. "/server/dbc.sql") or ""
    test("the server's SQL: REPLACE INTO areatable_dbc, the new rows", sql:find("REPLACE INTO `areatable_dbc`", 1, true)
        and sql:find("(9001, 900, 9000, 3995,", 1, true) and sql:find("'Hut Hollow'", 1, true))
    local said = table.concat(m.forms and m.forms.warnings or {}, " | ")
    test("patch-W.MPQ written, or said why not", read(root .. "/patch-W.MPQ") ~= nil or said:find("patch-W.MPQ", 1, true), said)
    test("the map read again: the chunks in 9001", wt.area_at(wowmap.open(root, "WC3_made"), x, y) == Z + 1)
    written = wt.save(m)
    test("saved again with nothing edited: nothing written", written and #written == 0)
end
-- }}}

-- {{{ Taken away while used
section("An area in use, not taken away; then taken away")
do
    local nope, nwhy = ar.delete(m, Z + 1)
    test("refused while chunks are in it, saying how many and where", nope == nil
        and (nwhy or ""):find("chunks are in it (31_32)", 1, true), nwhy)
    local x, y = chunk_centre(31, 32, 4, 4)
    wt.area(m, x, y, { radius = 2 * CHUNK, area = Z })
    test("painted back into the zone: taken away", ar.delete(m, Z + 1) ~= nil)
    wt.save(m)
    local t = read_table(root .. "/DBFilesClient/AreaTable.dbc")
    test("saved: the table without it", ids_of(t) == "9000,9002", ids_of(t))
    local again = ar.create(m, { name = "New Glade" })
    test("its id and bit free again", again and again.ID == Z + 1 and again.AreaBit == 3995)
    ar.delete(m, Z + 1)
    ar.delete(m, Z + 2)
    wt.save(m)
    test("every area taken away and saved: registration.lua byte for byte the converter's",
        read(folder .. "/registration.lua") == REG)
end
-- }}}

-- {{{ Stock tables
section("With stock tables: their bits avoided, their rows merged")
do
    local S = TMP .. "/stock"
    write(S .. "/AreaTable.dbc", dbc.write("AreaTable", {
        { ID = 1, ContinentID = 0, ParentAreaID = 0, AreaBit = 3995, AreaName = "Dun Morogh" },
        { ID = 12, ContinentID = 0, ParentAreaID = 0, AreaBit = 3994, AreaName = "Elwynn Forest" },
        { ID = 40, ContinentID = 0, ParentAreaID = 0, AreaBit = 3096, AreaName = "Westfall" },
    }))
    local r3 = copy_map()
    local m3 = wowmap.open(r3, "WC3_made", { stock_dbc = S })
    local a = ar.create(m3, { name = "Glade" })
    local b = ar.create(m3, { name = "Shore" })
    test("a stock row's bits taken: the lowest free of the block (W10h)", a and a.AreaBit == 3097 and b and b.AreaBit == 3098,
        a and (a.AreaBit .. " " .. (b and b.AreaBit or "-")))
    local written, why = wt.save(m3)
    test("saved", written ~= nil, why)
    local merged = read_table(r3 .. "/server/dbc/AreaTable.dbc")
    test("the server's AreaTable.dbc: the stock rows and the map's", merged and ids_of(merged) == "1,12,40,9000,9001,9002",
        merged and ids_of(merged))
    local overlay = read_table(r3 .. "/DBFilesClient/AreaTable.dbc")
    test("the overlay: the map's rows only", overlay and ids_of(overlay) == "9000,9001,9002")
end
-- }}}

-- {{{ The editor
section("The editor: a new area painted, renamed, undone and redone around saves")
do
    local P = TMP .. "/fake-project"
    os.execute("mkdir -p " .. quote(P .. "/wow/World/Maps") .. " && cp -r " .. quote(MAPDIR) .. " " .. quote(P .. "/wow/World/Maps/"))
    local E = {}
    E.__index = E
    function E:say(text) self.messages[#self.messages + 1] = text end
    function E:undo() return self.history:undo() end
    function E:redo() return self.history:redo() end
    wowmap.attach(E)
    wt.attach(E)
    ar.attach(E)
    local e = setmetatable({ project_dir = P, history = history.new(50), dirty = {}, messages = {},
                             brush = { size = 1, strength = 1, wow_radius = 0 } }, E)
    local em = assert(e:wow_edit("WC3_made", { stock_dbc = false }))
    em.opts.stock_dbc = false
    local ef = P .. "/wow/World/Maps/WC3_made"
    local before_west = read(ef .. "/" .. WEST)
    local row = e:wow_new_area({ name = "Glade" })
    test("E:wow_new_area: one step, the brush paints it", row and row.ID == Z + 1 and e.brush.wow_area == Z + 1
        and e.messages[#e.messages]:find("Glade", 1, true))
    local x, y = chunk_centre(31, 32, 6, 6)
    e:wow_stroke_begin("area", x, y)
    e:wow_stroke(x, y)
    e:wow_stroke_end()
    test("painted", wt.area_at(em, x, y) == Z + 1)
    e:wow_change_area(Z + 1, { name = "Green Glade", flags = { "sanctuary" } })
    e:wow_save()
    local names = wowmap.area_names(P .. "/wow")
    test("saved: the project's wow/ has the table, the area named", names and names[Z + 1] and names[Z + 1].name == "Green Glade")
    local nope = e:wow_delete_area(Z + 1)
    test("taken away while painted: refused, said", nope == nil and e.messages[#e.messages]:find("chunks are in it", 1, true))
    e:undo()
    test("the rename undone", ar.list(em)[2].name == "Glade" and ar.list(em)[2].flags == 0)
    e:undo() e:undo()
    e:wow_save()
    test("all undone, saved: registration.lua and the tile byte for byte as made", read(ef .. "/registration.lua") == REG
        and read(ef .. "/" .. WEST) == before_west)
    names = wowmap.area_names(P .. "/wow")
    test("... the table holds the zone alone", names and names[Z] and not names[Z + 1])
    e:redo() e:redo() e:redo()
    e:wow_save()
    names = wowmap.area_names(P .. "/wow")
    local m2 = wowmap.open(P .. "/wow", "WC3_made")
    test("redone, saved: named again, its chunk in it", names and names[Z + 1] and names[Z + 1].name == "Green Glade"
        and wt.area_at(m2, x, y) == Z + 1)
end
-- }}}

-- {{{ Converted again beside it
section("Another map converted into the folder keeps this map's areas in the tables")
do
    local B2 = TMP .. "/build2"
    os.execute("cp -r " .. quote(BUILD) .. " " .. quote(B2))
    local m4 = wowmap.open(B2, "WC3_made", { stock_dbc = false })
    local a = ar.create(m4, { name = "Hut Hollow" })
    wt.save(m4)
    local t2 = made_terrain(40, 40)
    local rep = wowbuild.convert("two.w3x", B2, { terrain = t2, map = made_map, models = models, name = "WC3_two", stock_dbc = false })
    local t = read_table(B2 .. "/DBFilesClient/AreaTable.dbc")
    test("the second map: slot 1, its zone 9010", rep ~= nil and ids_of(t) == "9000,9001,9010", ids_of(t))
    local bits = {}
    for _, r in ipairs(t and t.rows or {}) do bits[#bits + 1] = r.bit end
    test("every bit its own", list(bits) == "4095," .. a.AreaBit .. ",4094", list(bits))
end
-- }}}

end

os.execute("rm -rf " .. quote(TMP))

print(string.format("\n%s\nTests: %d passed, %d failed, %d skipped", string.rep("=", 50), pass_count,
    test_count - pass_count, skip_count))
os.exit(pass_count == test_count and 0 or 1)

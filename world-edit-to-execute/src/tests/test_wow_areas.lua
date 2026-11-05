--[[
Tests for issue W10f: areas and doodad sets on a WoW map's tiles. Each
chunk's area number (AreaTable's id, MCNK header byte 52), read from the
tiles (editor/wowmap.lua), set over whole chunks by wt.area and the
editor's area brush (editor/wowterrain.lua), taken by a new tile from its
neighbours (editor/wowtiles.lua), and written in place by the tile
writer; a building's doodad set (MODF byte 58) set by pl.doodad_set
(editor/wowplace.lua); the areas' names read from a loose
DBFilesClient/AreaTable.dbc through the W client's table reader.

The WoW map is made by W02's converter from a made WC3 terrain, as
test_wow_objects makes it: two tiles side by side (31_32 west, 32_32
east), a tree in the west one and a hut in the east one. Everything here
needs the W client's reader library ($W_CLIENT_BUILD); without it the
tests are skipped, saying so.

    luajit src/tests/test_wow_areas.lua [project folder]
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
local has_place_read = lib and pcall(function() return lib.adt_place_read end)
if not lib then
    skip("W10f's tests", "no W client reader library: " .. tostring(lib_why))
elseif not has_place_read then
    skip("W10f's tests", "the W client's reader library has no adt_place_read (built before custom-client #25)")
else

-- {{{ helpers
local WEST, EAST, NEW = "WC3_made_31_32.adt", "WC3_made_32_32.adt", "WC3_made_33_32.adt"
local function block(bytes, tag)
    for _, b in ipairs(wt.walk(bytes)) do if b.tag == tag then return bytes:sub(b.at + 9, b.at + b.len) end end
end
-- where each chunk's MCNK block starts in a tile's bytes: { [k] = at }
local function chunk_starts(bytes)
    local out = {}
    for _, b in ipairs(wt.walk(bytes)) do
        if b.tag == "MCNK" then out[u32(bytes, b.at + 16) * 16 + u32(bytes, b.at + 12) + 1] = b.at end
    end
    return out
end
-- the bytes with chunk k's area number set to a (what a save should give)
local function with_area(bytes, k, a)
    return put(bytes, chunk_starts(bytes)[k] + 8 + 52, le32(a))
end
-- each chunk's building references (MCRF after its model references)
local function wmo_refs(bytes)
    local out = {}
    for k, at in pairs(chunk_starts(bytes)) do
        local B = bytes:sub(at + 1)
        local nd, nw, r = u32(B, 8 + 16), u32(B, 8 + 56), u32(B, 8 + 32)
        local l = {}
        for i = 0, nw - 1 do l[#l + 1] = u32(B, r + 8 + (nd + i) * 4) end
        out[k] = table.concat(l, ",")
    end
    return out
end
local function list(t) return table.concat(t, ",") end
local function place_read(rec, doodad)
    local buf = ffi.new("unsigned char[?]", #rec)
    ffi.copy(buf, rec, #rec)
    local p = ffi.new("AdtPlace")
    lib.adt_place_read(buf, doodad and 1 or 0, p)
    return p
end
local function chunk_centre(tx, ty, ix, iy)
    return ORIGIN - (ty * 16 + iy + 0.5) * CHUNK, ORIGIN - (tx * 16 + ix + 0.5) * CHUNK
end
local function every(t, f) for _, c in ipairs(t.chunks) do if not f(c) then return false end end return true end
local function summary(g)
    local out = {}
    for _, e in ipairs(g or {}) do out[#out + 1] = e.area .. ":" .. e.chunks .. ":" .. list(e.tiles) end
    return table.concat(out, " ")
end
local HUT = "World\\Test\\Hut.wmo"
local orig = { west = read(MAPDIR .. "/" .. WEST), east = read(MAPDIR .. "/" .. EAST), wdl = read(MAPDIR .. "/WC3_made.wdl"),
               wdt = read(MAPDIR .. "/WC3_made.wdt") }
-- the converted map's own zone: W02c's area id for its slot, which W02a
-- writes in every chunk
local reg = require("wowbuild.registration").read(MAPDIR .. "/registration.lua")
local Z = reg and reg.ids and reg.ids.area or 0
local function same_files(folder)
    return read(folder .. "/" .. WEST) == orig.west and read(folder .. "/" .. EAST) == orig.east
        and read(folder .. "/WC3_made.wdl") == orig.wdl and read(folder .. "/WC3_made.wdt") == orig.wdt
end
-- a made AreaTable.dbc: 36 fields a row (3.3.5a's), rows { id, map, parent, name }
local function area_table(rows, fields)
    fields = fields or 36
    local text, body = "\0", {}
    for _, r in ipairs(rows) do
        local f = {}
        for i = 1, fields do f[i] = 0 end
        f[1], f[2], f[3] = r[1], r[2], r[3]
        if fields >= 12 then f[12] = #text end
        text = text .. r[4] .. "\0"
        local row = {}
        for i = 1, fields do row[i] = le32(f[i]) end
        body[#body + 1] = table.concat(row)
    end
    return "WDBC" .. le32(#rows) .. le32(fields) .. le32(fields * 4) .. le32(#text) .. table.concat(body) .. text
end
-- }}}

-- {{{ Read
section("Each chunk's area, read from its header")
do
    local root = copy_map()
    local m = wowmap.open(root, "WC3_made")
    local w, e = m:tile(31, 32), m:tile(32, 32)
    test("the map's zone: W02c's id for slot 0, 9000", Z == 9000, Z)
    test("every chunk of both tiles: in it, as W02a writes it", w and e and every(w, function(c) return c.area == Z end)
        and every(e, function(c) return c.area == Z end))
    local a = wowmap.chunk_areas(orig.west)
    local n = 0
    for _ in pairs(a) do n = n + 1 end
    test("chunk_areas: 256 chunks, by iy * 16 + ix", n == 256 and a[1] == Z and a[256] == Z)
    local made = with_area(with_area(orig.west, 1, 9010), 16 * 3 + 7 + 1, 65535)
    a = wowmap.chunk_areas(made)
    test("... reading the header's byte 52 (chunk 0,0 and 7,3 set by hand)", a[1] == 9010 and a[16 * 3 + 7 + 1] == 65535
        and a[2] == Z)
    test("wt.areas: one area, 512 chunks over both tiles", summary(wt.areas(m)) == Z .. ":512:31_32,32_32", summary(wt.areas(m)))
    local here = wt.area_at(m, chunk_centre(32, 32, 3, 4))
    test("wt.area_at: the area under a point", here == Z)
    test("... nil off the map", wt.area_at(m, ORIGIN - 40 * TILE, ORIGIN - 40 * TILE) == nil)
end
-- }}}

-- {{{ One chunk set
section("One chunk's area set, saved, read back")
local root, folder = copy_map()
local m = wowmap.open(root, "WC3_made")
local rx, ry = chunk_centre(31, 32, 5, 5)
local K = 5 * 16 + 5 + 1
do
    local got, why = wt.area(m, rx, ry, { area = 5 })
    test("set: one chunk of the west tile", got and got.chunks == 1 and list(got.tiles) == "31_32", why)
    test("wt.area_at reads it", wt.area_at(m, rx, ry) == 5 and wt.area_at(m, rx + CHUNK, ry) == Z)
    local again = wt.area(m, rx, ry, { area = 5 })
    test("set again to the same: nothing changed", again and again.chunks == 0)
    local written = wt.save(m)
    test("saved: the west tile only", written and list(written) == WEST, written and list(written))
    local now = read(folder .. "/" .. WEST)
    test("the file: W02's but for that chunk's header bytes 52-55", now == with_area(orig.west, K, 5),
        now and differ(now, orig.west))
    test("the east tile, the WDT and the WDL untouched", read(folder .. "/" .. EAST) == orig.east
        and read(folder .. "/WC3_made.wdl") == orig.wdl and read(folder .. "/WC3_made.wdt") == orig.wdt)
    local t2 = wowmap.open(root, "WC3_made"):tile(31, 32)
    test("read again (adt_read and the header): area 5 there, the zone elsewhere", t2 and t2.chunks[K].area == 5
        and t2.chunks[K + 1].area == Z)
    local w = m:tile(31, 32)
    local same = t2 ~= nil
    for k = 1, 256 do
        for i = 1, 145 do if t2 and t2.chunks[k].heights[i] ~= w.chunks[k].heights[i] then same = false end end
    end
    test("... the ground as it was", same)
    written = wt.save(m)
    test("saved again with nothing edited: nothing written", written and #written == 0)
end
-- }}}

-- {{{ A radius over the tile edge
section("A brush's worth of chunks over the tile edge")
do
    local edge = ORIGIN - 32 * TILE                  -- world y of the line between the tiles
    local x = ORIGIN - (32 * 16 + 8.5) * CHUNK       -- the middle of the chunks' row 8
    -- middles within 1.6 chunks: each side's row 8 +- 1 (3), and row 8 one further in (1)
    local got, why = wt.area(m, x, edge, { radius = 1.6 * CHUNK, area = 7 })
    test("set: 8 chunks, 4 a side", got and got.chunks == 8 and list(got.tiles) == "31_32,32_32", why)
    local w, e = m:tile(31, 32), m:tile(32, 32)
    local ok = true
    for _, d in ipairs({ { w, 15, 7 }, { w, 15, 8 }, { w, 15, 9 }, { w, 14, 8 }, { e, 0, 7 }, { e, 0, 8 }, { e, 0, 9 }, { e, 1, 8 } }) do
        if d[1].chunks[d[3] * 16 + d[2] + 1].area ~= 7 then ok = false end
    end
    test("... the chunks expected", ok and w.chunks[6 * 16 + 15 + 1].area == Z and e.chunks[8 * 16 + 2 + 1].area == Z)
    test("wt.areas: 5, 7 and the zone with their chunks and tiles", summary(wt.areas(m)) == "5:1:31_32 7:8:31_32,32_32 " .. Z .. ":503:31_32,32_32",
        summary(wt.areas(m)))
    local written = wt.save(m)
    table.sort(written)
    test("saved: both tiles", written and list(written) == WEST .. "," .. EAST)
    local m2 = wowmap.open(root, "WC3_made")
    test("read again: the same areas", summary(wt.areas(m2)) == summary(wt.areas(m)))
    local a = wowmap.chunk_areas(read(folder .. "/" .. EAST))
    test("... in the east file's headers", a[8 * 16 + 1] == 7 and a[8 * 16 + 2] == 7 and a[8 * 16 + 3] == Z)
end
-- }}}

-- {{{ Refused
section("Refused: numbers out of range, places off the map")
do
    for _, v in ipairs({ -1, 65536, 70000, 1.5 }) do
        local got, why = wt.area(m, rx, ry, { area = v })
        test("area " .. v .. ": refused", got == nil and (why or ""):find("0 to 65535", 1, true), why)
    end
    local got, why = wt.area(m, rx, ry, {})
    test("no area: refused", got == nil and why ~= nil)
    got, why = wt.area(m, ORIGIN - 40 * TILE, ORIGIN - 40 * TILE, { area = 3 })
    test("off the map, at a point: refused, saying where", got == nil and (why or ""):find("no tile", 1, true), why)
    got = wt.area(m, ORIGIN - 40 * TILE, ORIGIN - 40 * TILE, { area = 3, radius = 10 })
    test("off the map, with a radius: nothing set", got == nil or got.chunks == 0)
    test("65535, the largest: taken", wt.area(m, rx, ry, { area = 65535 }) ~= nil and wt.area_at(m, rx, ry) == 65535)
    wt.area(m, rx, ry, { area = 5 })
end
-- }}}

-- {{{ Area and ground in one save
section("An area and raised ground in one chunk, one save")
do
    local x, y = chunk_centre(31, 32, 2, 2)
    local k = 2 * 16 + 2 + 1
    local before = wt.ground(m, x, y)
    wt.area(m, x, y, { area = 3 })
    wt.raise(m, x, y, { radius = 10, amount = 4 })
    local written, why = wt.save(m)
    table.sort(written or {})
    test("saved: the west tile (and the far view, for the ground)", written and list(written) == "WC3_made.wdl," .. WEST,
        written and list(written) or why)
    local t2 = wowmap.open(root, "WC3_made"):tile(31, 32)
    test("read again: area 3 and the ground raised", t2 and t2.chunks[k].area == 3 and wt.ground(m, x, y) ~= nil
        and math.abs(t2.chunks[k].z + t2.chunks[k].heights[73] - wt.ground(m, x, y)) < 1e-3)
    test("... the other areas as they were", t2 and t2.chunks[K].area == 5 and t2.chunks[8 * 16 + 15 + 1].area == 7)
    test("... higher than it was", wt.ground(wowmap.open(root, "WC3_made"), x, y) > before + 1)
end
-- }}}

-- {{{ A new tile's area
section("A new tile takes its neighbours' area")
do
    local function near(t, dx, dy) return { t = t, dx = dx, dy = dy } end
    local function fake(areas) local t = { chunks = {} } for k = 1, 256 do t.chunks[k] = { area = areas(k) } end return t end
    local col15 = fake(function(k) return ((k - 1) % 16 == 15) and 7 or 0 end)
    test("area_of: the west neighbour's east column (ix 15)", tiles.area_of({ near(col15, -1, 0) }) == 7)
    test("... not the east neighbour's (its ix 0 faces)", tiles.area_of({ near(col15, 1, 0) }) == 0)
    local half = fake(function(k) return ((k - 1) % 16 == 0 and k <= 128) and 4 or ((k - 1) % 16 == 0 and 9 or 1) end)
    test("a tie (8 of 4, 8 of 9): the lower number", tiles.area_of({ near(half, 1, 0) }) == 4)
    local north = fake(function(k) return k > 240 and 6 or 0 end)
    test("the north neighbour's row 15 (dy -1)", tiles.area_of({ near(north, 0, -1) }) == 6)
    test("two sides, 16 chunks each (6 and 7): counted together, the lower on the tie",
        tiles.area_of({ near(north, 0, -1), near(col15, -1, 0) }) == 6)
    local north7 = fake(function(k) return k > 245 and 7 or 6 end)
    test("... 5 more of 7 along the north: 7", tiles.area_of({ near(north7, 0, -1), near(col15, -1, 0) }) == 7)
    local corner = fake(function(k) return k == 256 and 11 or 2 end)
    test("only a corner neighbour: its corner chunk", tiles.area_of({ near(corner, -1, -1) }) == 11)
    test("... a side neighbour first", tiles.area_of({ near(corner, -1, -1), near(north, 0, -1) }) == 6)
    test("no neighbour: 0", tiles.area_of({}) == 0)

    local r2, f2 = copy_map()
    local m2 = wowmap.open(r2, "WC3_made")
    for iy = 0, 9 do
        local x, y = chunk_centre(32, 32, 15, iy)
        wt.area(m2, x, y, { area = 7 })
    end
    local t, why = tiles.add(m2, 33, 32, { height = 20 })
    test("tile 33, 32 added east of the east tile: area 7, ten of its sixteen facing chunks'",
        t and every(t, function(c) return c.area == 7 and c.dirty.area end), why)
    local written
    written, why = wt.save(m2)
    test("saved: the new tile with the others", written ~= nil, why)
    local a = wowmap.chunk_areas(read(f2 .. "/" .. NEW) or "")
    local all7 = true
    for k = 1, 256 do if a[k] ~= 7 then all7 = false end end
    test("its file: every chunk's header says 7", all7)
    local t2 = wowmap.open(r2, "WC3_made"):tile(33, 32)
    test("read again: area 7", t2 and every(t2, function(c) return c.area == 7 end))

    local m3 = wowmap.open((copy_map()), "WC3_made")
    t, why = tiles.add(m3, 33, 32, { height = 20, area = 9 })
    test("opts.area 9: area 9", t and every(t, function(c) return c.area == 9 end), why)
    tiles.remove(m3, 33, 32)
    t, why = tiles.add(m3, 33, 32, { height = 20 })
    test("taken off, added again: the map's zone, its neighbours'",
        t and every(t, function(c) return c.area == Z and c.dirty.area end), why)
    for _, v in ipairs({ -3, 70000, 2.5, "x" }) do
        tiles.remove(m3, 33, 32)
        local nope, nwhy = tiles.add(m3, 33, 32, { height = 20, area = v })
        test("opts.area " .. tostring(v) .. ": refused", nope == nil and (nwhy or ""):find("0 to 65535", 1, true), nwhy)
    end
end
-- }}}

-- {{{ A building's doodad set
section("A building's doodad set")
do
    assert(pl.load(m))
    local h = { kind = "wmo", uid = 2 }
    local e = m:tile(32, 32)
    local before_file = read(folder .. "/" .. EAST)
    local old = block(before_file, "MODF")
    local got, why = pl.doodad_set(m, h, 3)
    test("set: the hut, on the east tile", got and list(got.tiles) == "32_32", why)
    test("its entry says 3", e.buildings[1].doodad_set == 3)
    local written = wt.save(m)
    test("saved: the east tile only", written and list(written) == EAST, written and list(written))
    local now = read(folder .. "/" .. EAST)
    local rec = block(now, "MODF")
    test("MODF: the record as it was but bytes 58-59", #rec == 64 and rec:sub(1, 58) == old:sub(1, 58)
        and rec:sub(61) == old:sub(61) and u16(rec, 58) == 3)
    test("adt_place_read gives doodad set 3", place_read(rec, false).doodad_set == 3)
    local a, b = wmo_refs(before_file), wmo_refs(now)
    local same = true
    for k = 1, 256 do if a[k] ~= b[k] then same = false end end
    test("every chunk's references as they were", same)
    test("the file: only those two bytes changed", differ(now, before_file) == 1)
    local t2 = wowmap.open(root, "WC3_made"):tile(32, 32)
    test("read again: the hut's doodad set 3", t2 and t2.buildings[1].doodad_set == 3 and t2.buildings[1].model == HUT)

    local nope, nwhy = pl.doodad_set(m, { kind = "m2", uid = 1 }, 1)
    test("a model: refused", nope == nil and (nwhy or ""):find("WMO", 1, true), nwhy)
    for _, v in ipairs({ -1, 65536, 1.5 }) do
        nope, nwhy = pl.doodad_set(m, h, v)
        test("set " .. v .. ": refused", nope == nil and (nwhy or ""):find("0 to 65535", 1, true), nwhy)
    end
    nope, nwhy = pl.doodad_set(m, { kind = "wmo", uid = 99 }, 1)
    test("a building not on the map: refused", nope == nil and nwhy ~= nil, nwhy)
    test("65535: taken", pl.doodad_set(m, h, 65535) ~= nil)
    pl.doodad_set(m, h, 0)
    wt.save(m)
    test("set back to 0, saved: the record W02 wrote", block(read(folder .. "/" .. EAST), "MODF") == block(orig.east, "MODF"))
end
-- }}}

-- {{{ The editor
section("The editor's area brush and doodad set: undo and redo, before and after a save")
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
    pl.attach(E)
    local e = setmetatable({ project_dir = P, history = history.new(50), dirty = {}, messages = {}, brush = {} }, E)
    local em = assert(e:wow_edit("WC3_made"))
    local ef = P .. "/wow/World/Maps/WC3_made"

    e.brush = { size = 1, strength = 1, wow_radius = 0, wow_area = 12 }
    test("the area brush: a WoW tool", wt.TOOLS.area and e:wow_stroke_begin("area", rx, ry))
    local ok = e:wow_stroke(rx, ry)
    local x2, y2 = chunk_centre(31, 32, 6, 5)
    e:wow_stroke(x2, y2)
    local name = e:wow_stroke_end()
    test("one stroke over two chunks: one step", ok and name and name:find("^Set area") and wt.area_at(em, rx, ry) == 12
        and wt.area_at(em, x2, y2) == 12, name)
    e:undo()
    test("undone", wt.area_at(em, rx, ry) == Z and wt.area_at(em, x2, y2) == Z)
    e:redo()
    test("redone", wt.area_at(em, rx, ry) == 12)

    e.brush = { size = 1, strength = 1, wow_radius = 1.6 * CHUNK, wow_area = 30 }
    e:wow_stroke_begin("area", ORIGIN - (32 * 16 + 8.5) * CHUNK, ORIGIN - 32 * TILE)
    e:wow_stroke(ORIGIN - (32 * 16 + 8.5) * CHUNK, ORIGIN - 32 * TILE)
    e:wow_stroke_end()
    test("a wider stroke over the tile edge", summary(wt.areas(em)) == "12:2:31_32 30:8:31_32,32_32 " .. Z .. ":502:31_32,32_32",
        summary(wt.areas(em)))
    e.brush = { size = 1, strength = 1, wow_radius = 0 }
    e:wow_stroke_begin("area", rx, ry)
    local nope = e:wow_stroke(rx, ry)
    e:wow_stroke_end()
    test("no brush.wow_area: refused, said", not nope and e.messages[#e.messages]:find("0 to 65535", 1, true))

    local got = e:wow_doodad_set({ kind = "wmo", uid = 2 }, 5)
    test("E:wow_doodad_set: one step", got and em:tile(32, 32).buildings[1].doodad_set == 5)
    e:wow_save()
    -- four steps: the refused stroke is one too (as every WoW brush's is), changing nothing
    test("four steps, saved", read(ef .. "/" .. WEST) ~= orig.west and read(ef .. "/" .. EAST) ~= orig.east
        and wowmap.chunk_areas(read(ef .. "/" .. WEST))[K] == 12 and u16(block(read(ef .. "/" .. EAST), "MODF"), 58) == 5)
    e:undo() e:undo() e:undo() e:undo()
    e:wow_save()
    test("all undone after the save, saved again: every file byte for byte as made", same_files(ef),
        string.format("west %s east %s", tostring(read(ef .. "/" .. WEST) == orig.west), tostring(read(ef .. "/" .. EAST) == orig.east)))
    e:redo() e:redo() e:redo() e:redo()
    e:wow_save()
    local m2 = wowmap.open(P .. "/wow", "WC3_made")
    test("redone after that, saved: the areas and the set back", summary(wt.areas(m2)) == "12:2:31_32 30:8:31_32,32_32 " .. Z .. ":502:31_32,32_32"
        and m2:tile(32, 32).buildings[1].doodad_set == 5, summary(wt.areas(m2)))
    e:undo()
    e:wow_save()
    test("one undone after that save: the set 0 again, the areas kept",
        wowmap.open(P .. "/wow", "WC3_made"):tile(32, 32).buildings[1].doodad_set == 0
        and wowmap.chunk_areas(read(ef .. "/" .. WEST))[K] == 12)
end
-- }}}

-- {{{ Area names
section("The areas' names, from a loose AreaTable.dbc")
do
    local W = TMP .. "/names"
    local got, why = wowmap.area_names(W)
    test("no table: nil, saying so", got == nil and (why or ""):find("AreaTable.dbc", 1, true), why)
    write(W .. "/DBFilesClient/AreaTable.dbc", area_table({ { 9010, 9000, 0, "Made Vale" }, { 9011, 9000, 9010, "Hut Hollow" } }))
    got, why = wowmap.area_names(W)
    test("two rows: names, map and parent", got and got[9010] and got[9010].name == "Made Vale" and got[9010].map == 9000
        and got[9011].name == "Hut Hollow" and got[9011].parent == 9010, why)
    write(W .. "/DBFilesClient/AreaTable.dbc", area_table({ { 1, 0, 0, "x" } }, 4))
    got, why = wowmap.area_names(W)
    test("4 fields a row: refused (the name is field 12)", got == nil and (why or ""):find("field 12", 1, true), why)
    local whole = area_table({ { 9010, 9000, 0, "Made Vale" } })
    write(W .. "/DBFilesClient/AreaTable.dbc", whole:sub(1, #whole - 4))
    got, why = wowmap.area_names(W)
    test("cut short: refused, not read past its end", got == nil and (why or ""):find("don't fit", 1, true), why)
    write(W .. "/DBFilesClient/AreaTable.dbc", put(whole, 20 + 44, le32(5000)))
    got, why = wowmap.area_names(W)
    test("a name past the text: refused", got == nil and (why or ""):find("past the table's text", 1, true), why)
    write(W .. "/DBFilesClient/AreaTable.dbc", "nope")
    got, why = wowmap.area_names(W)
    test("not a table: refused", got == nil and why ~= nil, why)
end
-- }}}

end

os.execute("rm -rf " .. quote(TMP))

print(string.format("\n%s\nTests: %d passed, %d failed, %d skipped", string.rep("=", 50), pass_count,
    test_count - pass_count, skip_count))
os.exit(pass_count == test_count and 0 or 1)

--[[
Tests for issue W10e: models (M2: MMDX, MMID, MDDF) and buildings (WMO:
MWMO, MWID, MODF) placed, moved, turned, sized and taken away on a WoW
map's tiles (src/editor/wowplace.lua), each edited tile's placement
blocks and chunk references (MCRF) written again by the tile writer
(src/editor/wowterrain.lua), read back through the W client's own reader
(adt_read, and its public adt_place_read for single records).

The WoW map is made by W02's converter from a made WC3 terrain, as
test_wow_tiles makes it: two tiles side by side (31_32 west, 32_32 east),
a tree in the west one and a hut in the east one. Everything here needs
the W client's reader library ($W_CLIENT_BUILD); without it the tests
are skipped, saying so.

    luajit src/tests/test_wow_objects.lua [project folder]
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
local ww = require("editor.wowwater")
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
    skip("W10e's tests", "no W client reader library: " .. tostring(lib_why))
elseif not has_place_read then
    skip("W10e's tests", "the W client's reader library has no adt_place_read (built before custom-client #25)")
else

-- {{{ helpers: a tile's blocks, records and references
local WEST, EAST = "WC3_made_31_32.adt", "WC3_made_32_32.adt"
local function block(bytes, tag)
    for _, b in ipairs(wt.walk(bytes)) do if b.tag == tag then return bytes:sub(b.at + 9, b.at + b.len) end end
end
local function records(bytes, tag)
    local d, each, out = block(bytes, tag), tag == "MDDF" and 36 or 64, {}
    for i = 0, math.floor(#d / each) - 1 do out[i + 1] = d:sub(i * each + 1, (i + 1) * each) end
    return out
end
-- each chunk's MCNK block and its references: { [k] = { bytes, d = {}, w = {} } }
local function chunks(bytes)
    local out = {}
    for _, b in ipairs(wt.walk(bytes)) do
        if b.tag == "MCNK" then
            local B = bytes:sub(b.at + 1, b.at + b.len)
            local ix, iy, nd, nw, at = u32(B, 12), u32(B, 16), u32(B, 8 + 16), u32(B, 8 + 56), u32(B, 8 + 32)
            local e = { bytes = B, d = {}, w = {} }
            for i = 0, nd - 1 do e.d[#e.d + 1] = u32(B, at + 8 + i * 4) end
            for i = 0, nw - 1 do e.w[#e.w + 1] = u32(B, at + 8 + (nd + i) * 4) end
            out[iy * 16 + ix + 1] = e
        end
    end
    return out
end
local function list(t) return table.concat(t, ",") end
-- a record through the W client's adt_place_read
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
local function find(m, kind, model)
    for _, e in ipairs(m.tiles) do
        local t = m.read_tiles[e.tx .. "_" .. e.ty]
        for _, p in ipairs(kind == "m2" and t.doodads or t.buildings) do
            if p.model == model then return { kind = kind, uid = p.uid }, p, t end
        end
    end
end
local TREE, HUT = "World\\Test\\Tree.m2", "World\\Test\\Hut.wmo"
local ROCK, TOWER, BARREL = "World\\Test\\Rock.m2", "World\\Test\\Tower.wmo", "World\\Test\\Barrel.m2"
local orig = { west = read(MAPDIR .. "/" .. WEST), east = read(MAPDIR .. "/" .. EAST), wdl = read(MAPDIR .. "/WC3_made.wdl"),
               wdt = read(MAPDIR .. "/WC3_made.wdt") }
local function same_files(folder)
    return read(folder .. "/" .. WEST) == orig.west and read(folder .. "/" .. EAST) == orig.east
        and read(folder .. "/WC3_made.wdl") == orig.wdl and read(folder .. "/WC3_made.wdt") == orig.wdt
end
-- }}}

-- {{{ Loaded, and W02's placements written again
section("The map's placements, loaded; W02's written again unchanged")
do
    local root, folder = copy_map()
    local m = wowmap.open(root, "WC3_made")
    local ok, why = pl.load(m)
    test("loaded: every tile read, each entry with its file record", ok, why)
    local o, tree, west = find(m, "m2", TREE)
    local h, hut = find(m, "wmo", HUT)
    test("the tree and the hut, with W02b's unique ids 1 and 2; the next id 3", o and h and o.uid == 1 and h.uid == 2
        and m.next_uid == 3)
    test("their records: 36 and 64 bytes, numbered as in the file", tree and #tree.raw == 36 and tree.slot == 0
        and hut and #hut.raw == 64 and hut.slot == 0)
    local p = place_read(tree.raw, true)
    test("adt_place_read gives the record's place as adt_read did", math.abs(p.x - tree.x) < 1e-6 and math.abs(p.y - tree.y) < 1e-6
        and p.uid == 1)
    test("encoded again from the data, the tree's record is W02's byte for byte",
        pl.encode(setmetatable({ raw = false }, { __index = tree }), 0) == tree.raw)
    test("... and the hut's", pl.encode(setmetatable({ raw = false }, { __index = hut }), 0) == hut.raw)
    local near = pl.near(m, tree.x, tree.y, 1)
    test("pl.near finds the tree where it stands", #near == 1 and near[1].uid == 1 and near[1].kind == "m2")

    local written = wt.save(m)
    test("nothing edited: nothing written", written and #written == 0)
    pl.touch(west)
    pl.touch(m:tile(32, 32))
    written, why = wt.save(m)
    test("every entry of both tiles written again from the data (records and references)", written and #written == 2, why)
    test("... both tiles byte for byte W02's (its MDDF, MODF, names and every MCRF)", same_files(folder))
end
-- }}}

-- {{{ A model placed
section("A model placed, saved, read back")
local root, folder = copy_map()
local m = wowmap.open(root, "WC3_made")
assert(pl.load(m))
local west, east = m:tile(31, 32), m:tile(32, 32)
local rx, ry = chunk_centre(31, 32, 5, 5)
do
    local g = wt.ground(m, rx, ry)
    local o, why = pl.place(m, { model = ROCK, x = rx, y = ry, yaw = 30, scale = 1.25 })
    test("placed: unique id 3, on the west tile", o and o.uid == 3 and list(o.tiles) == "31_32" and m.next_uid == 4, why)
    local written = wt.save(m)
    table.sort(written)
    test("saved: the west tile only", written and list(written) == WEST, written and list(written))
    local now = read(folder .. "/" .. WEST)
    local t2 = wowmap.open(root, "WC3_made"):tile(31, 32)
    local d = t2 and t2.doodads[2]
    test("read back by adt_read: the rock, its name, id, place, turn and size", d and d.model == ROCK and d.uid == 3
        and math.abs(d.x - rx) < 1e-3 and math.abs(d.y - ry) < 1e-3 and math.abs(d.z - g) < 1e-3
        and math.abs(d.rot[2] - 30) < 1e-4 and d.scale == 1.25)
    test("the tree as it was", t2 and t2.doodads[1].model == TREE and t2.doodads[1].uid == 1)
    test("MMDX: the new name added at the end, MMID with it", block(now, "MMDX") == block(orig.west, "MMDX") .. ROCK .. "\0"
        and block(now, "MMID") == block(orig.west, "MMID") .. le32(#block(orig.west, "MMDX")))
    test("MDDF: the tree's record byte for byte, the rock's after it", records(now, "MDDF")[1] == records(orig.west, "MDDF")[1]
        and #records(now, "MDDF") == 2)
    local p = place_read(records(now, "MDDF")[2], true)
    test("the rock's record through adt_place_read", math.abs(p.x - rx) < 1e-3 and math.abs(p.y - ry) < 1e-3 and p.uid == 3
        and math.abs(p.scale - 1.25) < 1e-6)
    local a, b = chunks(orig.west), chunks(now)
    local k = 5 * 16 + 5 + 1
    local others = true
    for i = 1, 256 do if i ~= k and a[i].bytes ~= b[i].bytes then others = false end end
    test("its chunk references it (MCRF), the count in the header", list(b[k].d) == "1" and #b[k].w == 0)
    test("every other chunk byte for byte", others)
    test("the WDT and WDL untouched", read(folder .. "/WC3_made.wdl") == orig.wdl and read(folder .. "/WC3_made.wdt") == orig.wdt)
end
-- }}}

-- {{{ Moved across the tile edge, turned, sized
section("The tree moved to the east tile; the rock turned and sized")
do
    local o, tree = find(m, "m2", TREE)
    local above = tree.z - wt.ground(m, tree.x, tree.y)
    local was_k
    for k, c in pairs(chunks(read(folder .. "/" .. WEST))) do if list(c.d):match("^0") or list(c.d) == "0" then was_k = k end end
    local tx, ty = chunk_centre(32, 32, 2, 7)
    local got, why = pl.move(m, o, tx, ty)
    test("moved: both tiles touched", got and list(got.tiles) == "31_32,32_32", why)
    test("it stands as high over the ground as it did", math.abs((find(m, "m2", TREE) and select(2, find(m, "m2", TREE)).z
        or 0) - wt.ground(m, tx, ty) - above) < 1e-6)
    local _, rock = find(m, "m2", ROCK)
    local before = rock.raw
    pl.rotate(m, { kind = "m2", uid = 3 }, { yaw = 200 })
    pl.scale(m, { kind = "m2", uid = 3 }, 0.5)
    local written = wt.save(m)
    table.sort(written)
    test("saved: the two tiles", written and list(written) == WEST .. "," .. EAST, written and list(written))
    local mw = wowmap.open(root, "WC3_made")
    local w2, e2 = mw:tile(31, 32), mw:tile(32, 32)
    test("the west tile lists only the rock now", w2 and #w2.doodads == 1 and w2.doodads[1].model == ROCK)
    test("the east tile lists the tree, same id, where it was moved", e2 and #e2.doodads == 1 and e2.doodads[1].uid == 1
        and e2.doodads[1].model == TREE and math.abs(e2.doodads[1].x - tx) < 1e-3 and math.abs(e2.doodads[1].y - ty) < 1e-3)
    local rec = records(read(folder .. "/" .. WEST), "MDDF")[1]
    test("the rock's record: name, id and place as they were (renumbered only where it must)", rec:sub(5, 20) == before:sub(5, 20))
    test("... turned to 200 and sized 0.5", math.abs(w2.doodads[1].rot[2] - 200) < 1e-4 and w2.doodads[1].scale == 0.5)
    local wc, ec = chunks(read(folder .. "/" .. WEST)), chunks(read(folder .. "/" .. EAST))
    local k = 5 * 16 + 5 + 1
    test("west: the rock's chunk references MDDF 0 (it moved up one); the tree's old chunk none",
        list(wc[k].d) == "0" and (not was_k or was_k == k or #wc[was_k].d == 0))
    test("east: the tree's new chunk references it", list(ec[7 * 16 + 2 + 1].d) == "0")
    local hut_refs = 0
    for _, c in pairs(ec) do hut_refs = hut_refs + #c.w end
    local oe = chunks(orig.east)
    local before_refs = 0
    for _, c in pairs(oe) do before_refs = before_refs + #c.w end
    test("east: the hut's references as they were", hut_refs == before_refs and before_refs > 0)
end
-- }}}

-- {{{ A building over the tile edge
section("A building over the tile edge, turned, and the hut taken away")
local tower
do
    local edge = ORIGIN - 32 * TILE                 -- world y of the line between the tiles
    local bx = ORIGIN - (32 * 16 + 9.5) * CHUNK
    local got, why = pl.place(m, { model = TOWER, x = bx, y = edge + 3, size = { 20, 15 } })
    tower = got and { kind = "wmo", uid = got.uid }
    test("placed over the edge: unique id 4, listed by both tiles", got and got.uid == 4 and list(got.tiles) == "31_32,32_32", why)
    local written = wt.save(m)
    test("saved", written and #written == 2)
    local mw = wowmap.open(root, "WC3_made")
    local w2, e2 = mw:tile(31, 32), mw:tile(32, 32)
    local a = w2 and w2.buildings[1]
    local b = e2 and e2.buildings[2]
    test("read back: in both tiles, one id", a and b and a.uid == 4 and b.uid == 4 and a.model == TOWER and b.model == TOWER
        and e2.buildings[1].model == HUT)
    test("its box, 20 across and 15 up, in world axes", a and math.abs((a.hi[1] - a.lo[1]) - 20) < 1e-3
        and math.abs((a.hi[2] - a.lo[2]) - 20) < 1e-3 and math.abs((a.hi[3] - a.lo[3]) - 15) < 1e-3
        and math.abs(a.lo[2] - (edge + 3 - 10)) < 1e-3)
    local wc, ec = chunks(read(folder .. "/" .. WEST)), chunks(read(folder .. "/" .. EAST))
    local wn, en = 0, 0
    for _, c in pairs(wc) do wn = wn + #c.w end
    for k, c in pairs(ec) do for _, n in ipairs(c.w) do if n == 1 then en = en + 1 end end end
    -- x 9.5 chunks down, 20 across: rows 9 (and 9 only); west column 15, east column 0
    test("references: the chunks its box touches on each side", wn == 1 and list(wc[9 * 16 + 15 + 1].w) == "0"
        and en == 1 and list(ec[9 * 16 + 1].w):match("1") ~= nil, wn .. " " .. en)
    local p = place_read(records(read(folder .. "/" .. WEST), "MODF")[1], false)
    test("its record through adt_place_read: the same box", math.abs(p.lo[1] - a.lo[2]) < 1e-6 and math.abs(p.hi[0] - a.hi[1]) < 1e-6
        and math.abs(p.lo[2] - a.lo[3]) < 1e-6, string.format("%f %f %f %f", p.lo[1], a.lo[2], p.hi[0], a.hi[1]))

    pl.rotate(m, tower, { yaw = 45 })
    local _, e1 = find(m, "wmo", TOWER)
    test("turned: a square box centred where it stands (W02b's kind) kept as it is",
        math.abs((e1.hi[1] - e1.lo[1]) - 20) < 1e-9 and math.abs((e1.hi[2] - e1.lo[2]) - 20) < 1e-9)
    pl.rotate(m, tower, { yaw = 80 })
    -- a long one: 20 west-east, 10 north-south
    local long = pl.place(m, { model = "World\\Test\\Wall.wmo", x = bx, y = edge + 200, size = { 20, 5, 10 } })
    local lo = long and { kind = "wmo", uid = long.uid }
    local _, w0 = find(m, "wmo", "World\\Test\\Wall.wmo")
    test("a building 20 by 10", w0 and math.abs((w0.hi[2] - w0.lo[2]) - 20) < 1e-9 and math.abs((w0.hi[1] - w0.lo[1]) - 10) < 1e-9)
    pl.rotate(m, lo, { yaw = 30 })
    local _, w1 = find(m, "wmo", "World\\Test\\Wall.wmo")
    local side1 = w1.hi[1] - w1.lo[1]
    test("turned: its box the square that holds it at every turn (11.18 yards out)", math.abs(side1 / 2 - math.sqrt(125)) < 1e-6
        and math.abs((w1.hi[2] - w1.lo[2]) - side1) < 1e-9)
    pl.rotate(m, lo, { yaw = 60 })
    local _, w2 = find(m, "wmo", "World\\Test\\Wall.wmo")
    test("turned again: the box doesn't grow", math.abs((w2.hi[1] - w2.lo[1]) - side1) < 1e-9)
    pl.delete(m, lo)
    local o = find(m, "wmo", HUT)
    test("the hut taken away", pl.delete(m, o) ~= nil)
    test("a building can't be sized", select(2, pl.scale(m, tower, 2)):find("own size", 1, true) ~= nil)
    local nope, nwhy = pl.place(m, { model = ROCK, x = 0, y = 5000 })
    test("placing off the map's tiles: refused", nope == nil and nwhy ~= nil, nwhy)
    nope, nwhy = pl.place(m, { model = "World\\Test\\Thing.blp", x = rx, y = ry })
    test("a file that is neither model nor building: refused", nope == nil and (nwhy or ""):find("neither", 1, true), nwhy)
    nope, nwhy = pl.move(m, { kind = "m2", uid = 99 }, rx, ry)
    test("an id the map hasn't: refused", nope == nil and (nwhy or ""):find("unique id 99", 1, true), nwhy)
    local got2, gwhy = pl.place(m, { model = BARREL, x = rx + 5, y = ry })
    test("a new placement after a deletion: a new id (6, after the wall's 5), none reused", got2 and got2.uid == 6, gwhy or (got2 and got2.uid))
    written = wt.save(m)
    local now = read(folder .. "/" .. EAST)
    local e3 = wowmap.open(root, "WC3_made"):tile(32, 32)
    test("saved and read back: the hut gone, the tower turned", e3 and #e3.buildings == 1 and e3.buildings[1].model == TOWER
        and math.abs(e3.buildings[1].rot[2] - 80) < 1e-4)
    test("the hut's name stays in MWMO (no other name renumbered)", block(now, "MWMO"):find(HUT, 1, true) ~= nil)
    local ec2 = chunks(now)
    local hut_left = 0
    for _, c in pairs(ec2) do for _, n in ipairs(c.w) do if n ~= 0 then hut_left = hut_left + 1 end end end
    test("no chunk references the hut; the tower's renumbered to 0", hut_left == 0)
end
-- }}}

-- {{{ Placements and ground on one tile
section("Placements and ground edited on one tile, one save")
do
    local o = { kind = "m2", uid = 3 }
    pl.move(m, o, rx + 3, ry + 3)
    wt.paint(m, rx, ry, { radius = 8, texture = "Tileset\\Test\\Paint.blp", falloff = "flat" })
    wt.raise(m, rx - 40, ry, { radius = 8, amount = 3 })
    local written, why = wt.save(m)
    test("saved", written ~= nil, why)
    local t2 = wowmap.open(root, "WC3_made"):tile(31, 32)
    local k = 5 * 16 + 5 + 1
    test("read back: the rock moved, the paint and the raised ground there", t2 and math.abs(t2.doodads[1].x - (rx + 3)) < 1e-3
        and #t2.chunks[k].layers == 2)
end
-- }}}

-- {{{ The editor: undo and redo around saves
section("The editor's object tools: undo and redo, before and after a save")
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
    local got = e:wow_place({ model = ROCK, x = rx, y = ry })
    local w = em:tile(31, 32)
    test("E:wow_place: one step", got and got.uid == 3 and e.history:can_undo() and #w.doodads == 2)
    e:undo()
    test("undone: as it was, nothing to write", #w.doodads == 1 and not w.dirty and not w.places_dirty
        and not em:tile(32, 32).dirty)
    e:redo()
    test("redone", #w.doodads == 2 and w.places_dirty)
    local o = { kind = "m2", uid = 1 }
    e:wow_move_object(o, chunk_centre(32, 32, 2, 7))
    e:wow_rotate_object({ kind = "m2", uid = 3 }, { yaw = 90 })
    e:wow_delete_object({ kind = "wmo", uid = 2 })
    e:wow_save()
    test("four steps, saved", read(ef .. "/" .. WEST) ~= orig.west and read(ef .. "/" .. EAST) ~= orig.east)
    e:undo() e:undo() e:undo() e:undo()
    e:wow_save()
    test("all undone after the save, saved again: every file byte for byte as made", same_files(ef),
        string.format("west %s east %s", tostring(read(ef .. "/" .. WEST) == orig.west), tostring(read(ef .. "/" .. EAST) == orig.east)))
    if not same_files(ef) then
        for _, f in ipairs({ WEST, EAST }) do
            local a, b = read(ef .. "/" .. f), f == WEST and orig.west or orig.east
            for _, tag in ipairs({ "MMDX", "MMID", "MWMO", "MWID", "MDDF", "MODF" }) do
                if block(a, tag) ~= block(b, tag) then print("   differs", f, tag, #block(a, tag), #block(b, tag)) end
            end
            local ca, cb = chunks(a), chunks(b)
            for k = 1, 256 do if ca[k].bytes ~= cb[k].bytes then print("   chunk", f, k, list(ca[k].d), list(cb[k].d), list(ca[k].w), list(cb[k].w)) end end
        end
    end
    e:redo() e:redo() e:redo() e:redo()
    e:wow_save()
    local mw = wowmap.open(P .. "/wow", "WC3_made")
    local w2, e2 = mw:tile(31, 32), mw:tile(32, 32)
    test("redone after that, saved: the rock turned, the tree moved, the hut gone", w2 and #w2.doodads == 1
        and math.abs(w2.doodads[1].rot[2] - 90) < 1e-4 and e2 and #e2.doodads == 1 and e2.doodads[1].uid == 1
        and #e2.buildings == 0)
    e:undo()
    e:wow_save()
    local e3 = wowmap.open(P .. "/wow", "WC3_made"):tile(32, 32)
    test("one undone after that save: the hut back, its id and place as made", e3 and #e3.buildings == 1
        and e3.buildings[1].uid == 2 and e3.buildings[1].model == HUT)
    local hut_refs = 0
    for _, c in pairs(chunks(read(ef .. "/" .. EAST))) do hut_refs = hut_refs + #c.w end
    local before_refs = 0
    for _, c in pairs(chunks(orig.east)) do before_refs = before_refs + #c.w end
    test("... and the chunks its box touches reference it again", hut_refs == before_refs)
end
-- }}}

end

os.execute("rm -rf " .. quote(TMP))

print(string.format("\n%s\nTests: %d passed, %d failed, %d skipped", string.rep("=", 50), pass_count,
    test_count - pass_count, skip_count))
os.exit(pass_count == test_count and 0 or 1)

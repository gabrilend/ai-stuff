--[[
Tests for issue W10d: a WoW map's tile list read from its WDT through
the W client's wdt_read (src/editor/wowmap.lua), tiles added and taken
off (src/editor/wowtiles.lua: the tile's file, its WDT flag patched in
place, its far view in the WDL, undo), and water of vertex formats 1 and
3 keeping its format and picture positions through an edit
(src/editor/wowwater.lua).

The WoW map is made by W02's converter from a made WC3 terrain (no WC3
or WoW install), as test_wow_water_and_far_view makes it: two tiles side
by side, a lake in the west one, a tree and a hut. Everything here reads
through the W client's reader library ($W_CLIENT_BUILD: a folder holding
libwreaders.so and wreaders.h, built with its 098-wdt.c); without it the
tests are skipped, saying so.

    luajit src/tests/test_wow_tiles.lua [project folder]
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
local tiles = require("editor.wowtiles")
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
local has_wdt = lib and pcall(function() return lib.wdt_read end) and pcall(ffi.typeof, "Wdt")
if not lib then
    skip("W10d's tests", "no W client reader library: " .. tostring(lib_why))
elseif not has_wdt then
    skip("W10d's tests", "the W client's reader library has no wdt_read (built before its 098-wdt.c)")
else

-- the WDT's tiles, as wdt_read gives them
local function wdt_names(bytes)
    local info, why = wowmap.read_wdt(bytes, lib)
    if not info then return "(" .. tostring(why) .. ")" end
    local out = {}
    for _, e in ipairs(info.tiles) do out[#out + 1] = e.tx .. "_" .. e.ty end
    return table.concat(out, " "), info
end
-- a WDL read by the W client's reader
local function wdl_read(bytes)
    local W, why = ffi.new("AdtWdl"), ffi.new("WWhy")
    local buf = ffi.new("unsigned char[?]", #bytes)
    ffi.copy(buf, bytes, #bytes)
    if lib.adt_wdl_read(buf, #bytes, W, why) ~= 0 then return nil, ffi.string(why.text) end
    return W
end
-- a WDL's MAOF entries: { [ty * 64 + tx] = offset }
local function maof(bytes)
    local out = {}
    for _, b in ipairs(wt.walk(bytes)) do
        if b.tag == "MAOF" then
            for i = 0, 4095 do
                local o = u32(bytes, b.at + 8 + i * 4)
                if o ~= 0 then out[i] = o end
            end
        end
    end
    return out
end
-- the height at a point of the map's half-cell grid, from a tile's data
local function point_height(t, R, C)
    local r, c = R - t.ty * HT, C - t.tx * HT
    if r < 0 or r > HT or c < 0 or c > HT or r % 2 ~= 0 or c % 2 ~= 0 then return nil end
    local iy, ix = math.min(15, math.floor(r / 16)), math.min(15, math.floor(c / 16))
    local ch = t.chunks[iy * 16 + ix + 1]
    local pr, pc = r / 2 - iy * 8, c / 2 - ix * 8        -- the corner's row and column in its chunk (0-8)
    return ch.z + ch.heights[pr * 17 + pc + 1]
end
-- each MCNK's MCNR data in a tile's bytes: { [k 1-256] = 435 bytes }
local function normals_of(bytes)
    local out = {}
    for _, b in ipairs(wt.walk(bytes)) do
        if b.tag == "MCNK" then
            local h = b.at + 8
            local ix, iy = u32(bytes, h + 4), u32(bytes, h + 8)
            local n = b.at + u32(bytes, h + 24)
            out[iy * 16 + ix + 1] = bytes:sub(n + 9, n + 8 + 435)
        end
    end
    return out
end

local m0 = wowmap.open(MAPDIR:match("^(.*)/World/Maps/"), "WC3_made")
local west, east = assert(m0:tile(m0.tiles[1].tx, m0.tiles[1].ty)), assert(m0:tile(m0.tiles[2].tx, m0.tiles[2].ty))

-- {{{ The tile list, from the WDT
section("A WoW map's tiles: its WDT's list (wdt_read)")
do
    test("opened: the tiles the WDT lists, read through wdt_read", m0.tile_source == "wdt" and names(m0) == "31_32 32_32"
        and m0.tiles[1].file == "WC3_made_31_32.adt" and #m0.missing == 0 and #m0.unlisted == 0, names(m0))
    test("the WDT's own facts kept: 8-bit blend maps, a ground map", m0.wdt_info and m0.wdt_info.big_alpha
        and not m0.wdt_info.wmo_only and m0.wdt_info.ntiles == 2)

    local root, folder = copy_map()
    -- a tile file the WDT doesn't list: not a tile
    write(folder .. "/WC3_made_40_40.adt", read(folder .. "/WC3_made_31_32.adt"))
    -- a tile the WDT lists whose file is gone
    os.remove(folder .. "/WC3_made_32_32.adt")
    local m = wowmap.open(root, "WC3_made")
    test("a file the WDT doesn't list: not a tile, said in unlisted", names(m) == "31_32 32_32" and #m.unlisted == 1
        and m.unlisted[1].file == "WC3_made_40_40.adt", names(m))
    local t, why = m:tile(32, 32)
    test("a tile the WDT lists with no file: listed, and reading it says why", #m.missing == 1 and t == nil
        and (why or ""):find("lists tile 32, 32 but its file WC3_made_32_32.adt isn't there", 1, true), why)
    local mapfile = require("editor.mapfile")
    local P = TMP .. "/proj"
    os.execute("mkdir -p " .. quote(P .. "/wow/World/Maps") .. " && cp -r " .. quote(folder) .. " " .. quote(P .. "/wow/World/Maps/"))
    local probs = mapfile.validate_wow(P, { read = true })
    local said_missing, said_unlisted = false, false
    for _, p in ipairs(probs) do
        if p.level == "error" and p.message:find("isn't there", 1, true) then said_missing = true end
        if p.level == "warn" and p.message:find("WC3_made_40_40.adt: its WDT doesn't list", 1, true) then said_unlisted = true end
    end
    test("the project's check says both: the missing file an error, the unlisted one a warning", said_missing and said_unlisted)

    -- the WDT's flag cleared by hand: that tile is no longer the map's, though its file is there
    write(folder .. "/WC3_made_32_32.adt", read(MAPDIR .. "/WC3_made_32_32.adt"))
    local wdt = read(folder .. "/WC3_made.wdt")
    local main = 60                       -- W02a's: MVER 12, MPHD 8 + 32, then MAIN's data
    write(folder .. "/WC3_made.wdt", put(wdt, main + (32 * 64 + 32) * 8, le32(0)))
    m = wowmap.open(root, "WC3_made")
    test("a flag cleared in MAIN: the tile is gone from the list, its file unlisted", names(m) == "31_32"
        and #m.unlisted == 2, names(m))
    -- a WDT the reader can't read: refused
    write(folder .. "/WC3_made.wdt", wdt:sub(1, 30))
    local nope, nwhy = wowmap.open(root, "WC3_made")
    test("a WDT cut short: the map isn't opened, the reader's why given", nope == nil and (nwhy or ""):find("WC3_made.wdt", 1, true), nwhy)
    -- a reader library without wdt_read: the files present, saying why
    write(folder .. "/WC3_made.wdt", wdt)
    local old = setmetatable({}, { __index = function(_, k)
        if k == "wdt_read" then error("missing: undefined symbol wdt_read") end
        return lib[k]
    end })
    m = wowmap.open(root, "WC3_made", { reader = old })
    test("a reader library without wdt_read: the tiles from the files present, and why", m and m.tile_source == "files"
        and (m.tile_source_why or ""):find("no WDT reader", 1, true) and names(m) == "31_32 32_32 40_40", m and names(m))
end
-- }}}

-- {{{ A flat tile added
section("A tile added, flat: its file, its WDT flag, its far view")
local FLAT = 20
do
    local root, folder = copy_map()
    local m = wowmap.open(root, "WC3_made")
    local was = { wdt = read(folder .. "/WC3_made.wdt"), wdl = read(folder .. "/WC3_made.wdl"),
                  west = read(folder .. "/WC3_made_31_32.adt"), east = read(folder .. "/WC3_made_32_32.adt") }
    local nope, nwhy = tiles.add(m, 32, 32, { height = 1 })
    test("where the map has a tile: refused", nope == nil and (nwhy or ""):find("already has tile 32, 32", 1, true), nwhy)
    nope, nwhy = tiles.add(m, 64, 2, { height = 1 })
    test("past 63: refused", nope == nil and (nwhy or ""):find("0 to 63", 1, true), nwhy)
    write(folder .. "/WC3_made_10_10.adt", "a stray file")
    m = wowmap.open(root, "WC3_made")
    nope, nwhy = tiles.add(m, 10, 10, { height = 1, texture = "x.blp" })
    test("where a file is that the WDT doesn't list: refused, not written over", nope == nil
        and (nwhy or ""):find("WC3_made_10_10.adt is there already", 1, true), nwhy)
    os.remove(folder .. "/WC3_made_10_10.adt")
    m = wowmap.open(root, "WC3_made")
    nope, nwhy = tiles.add(m, 10, 10, {})
    test("far from every tile, matching: refused (no neighbour)", nope == nil and (nwhy or ""):find("no neighbour", 1, true), nwhy)

    -- east of the east tile (the hut's): flat at 20 yards
    local t, why = tiles.add(m, 33, 32, { height = FLAT })
    test("added: tile 33, 32, in the list, read and marked to write", t and names(m) == "31_32 32_32 33_32"
        and m:tile(33, 32) == t and t.dirty and t.made, why)
    local e = m:tile(32, 32)
    local inside, edge_ok, worst = true, true, 0
    for R = 32 * HT, 33 * HT, 2 do
        for C = 33 * HT, 34 * HT, 2 do
            local h = point_height(t, R, C)
            if C == 33 * HT then
                local other = point_height(e, R, C)
                worst = math.max(worst, math.abs(h - other))
            elseif math.abs(h - FLAT) > 1e-9 then inside = false end
        end
    end
    test("flat at 20 yards but where it meets the east tile", inside)
    test("its west edge: the east tile's own heights, point for point", worst < 1e-6, worst)
    test("one texture, the one the neighbour starts with", #t.textures == 1 and t.textures[1] == e.chunks[1].layers[1].texture
        and #t.chunks[1].layers == 1)
    test("its chunks where the reader puts a tile's (x north, y west)", math.abs(t.chunks[1].x - e.chunks[1].x) < 1e-6
        and math.abs(t.chunks[1].y - (e.chunks[1].y - TILE)) < 1e-3)
    local en = e.chunks[16].normals
    test("the east tile's east edge: its normals worked out again (it has a neighbour now)", en ~= nil and en[9] ~= nil
        and e.chunks[16].dirty and e.chunks[16].dirty.normals)

    local written, swhy = wt.save(m)
    table.sort(written or {})
    test("saved: the new tile, the east tile (its edge normals), the WDT, the WDL",
        written and table.concat(written, " ") == "WC3_made.wdl WC3_made.wdt WC3_made_32_32.adt WC3_made_33_32.adt",
        written and table.concat(written, " ") or swhy)
    local wdt = read(folder .. "/WC3_made.wdt")
    local list, info = wdt_names(wdt)
    test("the WDT read back through wdt_read: the new tile listed", list == "31_32 32_32 33_32" and info.ntiles == 3, list)
    test("... its one flag the only change (the WDT patched in place)", differ(wdt, was.wdt) == 1
        and u32(wdt, 60 + (32 * 64 + 33) * 8) == 1)
    test("the west tile, not next to it: byte for byte as it was", read(folder .. "/WC3_made_31_32.adt") == was.west)
    local a, b = normals_of(was.east), normals_of(read(folder .. "/WC3_made_32_32.adt"))
    local other = 0
    for k = 1, 256 do if a[k] ~= b[k] and (k - 1) % 16 ~= 15 then other = other + 1 end end
    test("the east tile: only its east column of chunks' normals changed", other == 0
        and differ(was.east, read(folder .. "/WC3_made_32_32.adt")) > 0 and #was.east == #read(folder .. "/WC3_made_32_32.adt"))

    -- read back through the W client's reader, the map opened again
    local m2 = wowmap.open(root, "WC3_made")
    local t2, rwhy = m2:tile(33, 32)
    test("opened again: the new tile listed by the WDT and read by adt_read", t2 ~= nil and names(m2) == "31_32 32_32 33_32", rwhy)
    if t2 then
        local hw, pos = 0, 0
        for k = 1, 256 do
            local c, d = t.chunks[k], t2.chunks[k]
            pos = math.max(pos, math.abs(c.x - d.x), math.abs(c.y - d.y))
            for i = 1, 145 do hw = math.max(hw, math.abs((c.z + c.heights[i]) - (d.z + d.heights[i]))) end
        end
        test("... its ground and its chunks' places as made", hw < 1e-3 and pos < 1e-3, hw .. " " .. pos)
        test("... no holes, one texture, no water, nothing placed, no shadow, plain tints",
            t2.chunks[1].holes == 0 and #t2.chunks[1].layers == 1 and #t2.liquids == 0 and #t2.doodads == 0
            and #t2.buildings == 0 and t2.chunks[5].shadow == string.rep("\0", 4096) and t2.chunks[5].tint[3][2] == 127)
        local e2 = m2:tile(32, 32)
        local seam = 0
        for R = 32 * HT, 33 * HT, 2 do
            seam = math.max(seam, math.abs(point_height(t2, R, 33 * HT) - point_height(e2, R, 33 * HT)))
        end
        test("... joined to the east tile along their edge (read back)", seam < 1e-3, seam)
        local nn, ne = normals_of(read(folder .. "/WC3_made_33_32.adt")), normals_of(read(folder .. "/WC3_made_32_32.adt"))
        local same = true
        for iy = 0, 15 do
            for r = 0, 8 do
                -- the new tile's west chunk column's first corner, the east tile's east column's last
                local p1 = (r * 17) * 3
                local p2 = (r * 17 + 8) * 3
                if nn[iy * 16 + 1]:sub(p1 + 1, p1 + 3) ~= ne[iy * 16 + 16]:sub(p2 + 1, p2 + 3) then same = false end
            end
        end
        test("... the shared edge's normals the same in both files", same)
    end
    local W = wdl_read(read(folder .. "/WC3_made.wdl"))
    local k = 32 * 64 + 33
    test("the WDL read by the W client: the new tile's far view at 20 yards", W and W.have[k] == 1
        and W.heights[k][17 * 8 + 8] == FLAT and W.heights[k][17 * 16 + 16] == FLAT and W.heights[k][17 * 5 + 1] == FLAT)
    local now = read(folder .. "/WC3_made.wdl")
    local before, after = maof(was.wdl), maof(now)
    local kept = true
    for _, i in ipairs({ 32 * 64 + 31, 32 * 64 + 32 }) do
        if before[i] ~= after[i] or now:sub(before[i] + 1, before[i] + 8 + 1090 + 40) ~= was.wdl:sub(before[i] + 1, before[i] + 8 + 1090 + 40) then
            kept = false
        end
    end
    test("... the other tiles' far view where it was, as it was (the new one added at the end)", kept
        and after[k] == #was.wdl)

    -- saved again with nothing changed: nothing written
    local again = wt.save(m)
    test("saved again, no edit: nothing written", again and #again == 0)

    -- taken off again: the files as they were before the add
    local gone, gwhy = tiles.remove(m, 33, 32)
    test("taken off: out of the list", gone and names(m) == "31_32 32_32", gwhy)
    written = wt.save(m)
    test("saved: the file deleted, the WDT and WDL written", written and read(folder .. "/WC3_made_33_32.adt") == nil)
    test("the WDT as it was before the add, byte for byte", read(folder .. "/WC3_made.wdt") == was.wdt)
    test("the WDL as it was before the add, byte for byte", read(folder .. "/WC3_made.wdl") == was.wdl)
    test("the east tile as it was before the add (its edge one-sided again, W02a's rule)",
        read(folder .. "/WC3_made_32_32.adt") == was.east)
end
-- }}}

-- {{{ A tile added to meet its neighbours, edited before it is saved
section("A tile added to meet its neighbours, then edited, then saved")
do
    local root, folder = copy_map()
    local m = wowmap.open(root, "WC3_made")
    local was = { wdt = read(folder .. "/WC3_made.wdt"), wdl = read(folder .. "/WC3_made.wdl") }
    -- south of the west tile (and the east tile at its north-east corner)
    local t, why = tiles.add(m, 31, 33)
    test("added below the west tile, matching", t ~= nil, why)
    t = t or { chunks = {} }
    local w = m:tile(31, 32)
    local north, through, far = 0, 0, 0
    for C = 31 * HT, 32 * HT, 2 do
        local edge = point_height(w, 33 * HT, C)
        north = math.max(north, math.abs(point_height(t, 33 * HT, C) - edge))
        through = math.max(through, math.abs(point_height(t, 33 * HT + HT / 2, C) - edge))
        far = math.max(far, math.abs(point_height(t, 34 * HT, C) - edge))
    end
    test("its north edge is the west tile's south edge", north < 1e-6, north)
    test("with nothing else round it, that edge carried south across the tile", through < 1e-6 and far < 1e-6,
        through .. " " .. far)
    local rising = point_height(t, 33 * HT + HT / 2, 32 * HT) > point_height(t, 33 * HT + HT / 2, 31 * HT)
    test("so the ground still rises to the east as the WC3 map did", rising)
    test("its texture: the west tile's first", t.textures and t.textures[1] == w.chunks[1].layers[1].texture)

    -- edited before it was ever written: raised, painted, a hole, water
    local x, y = ORIGIN - (33 * 16 + 4.5) * CHUNK, ORIGIN - (31 * 16 + 4.5) * CHUNK
    local g0 = wt.ground(m, x, y)
    test("raised on the new tile", wt.raise(m, x, y, { radius = 10, amount = 5 }) ~= nil and wt.ground(m, x, y) > g0 + 4)
    local p = wt.paint(m, x, y, { radius = 10, texture = "Tileset\\Test\\Paint.blp", falloff = "flat" })
    test("painted", p and p.chunks > 0)
    wt.holes(m, ORIGIN - (33 * 16 + 9.5) * CHUNK, ORIGIN - (31 * 16 + 9.5) * CHUNK, { radius = 0 })
    local wx, wy = ORIGIN - (33 * 16 + 12.5) * CHUNK, ORIGIN - (31 * 16 + 12.5) * CHUNK
    local wl = ww.water(m, wx, wy, { radius = 6 })
    test("watered", wl and wl.cells > 0)
    local written, swhy = wt.save(m)
    test("saved", written ~= nil, swhy)
    local m2 = wowmap.open(root, "WC3_made")
    local t2, rwhy = m2:tile(31, 33)
    test("read back by the W client's reader", t2 ~= nil, rwhy)
    if t2 then
        local hw = 0
        for k = 1, 256 do
            for i = 1, 145 do hw = math.max(hw, math.abs((t.chunks[k].z + t.chunks[k].heights[i]) - (t2.chunks[k].z + t2.chunks[k].heights[i]))) end
        end
        test("... the raised ground", hw < 1e-3, hw)
        local k = 4 * 16 + 4 + 1
        test("... the painted layer", #t2.chunks[k].layers == 2 and t2.chunks[k].layers[2].texture == "Tileset\\Test\\Paint.blp"
            and t2.chunks[k].layers[2].alpha:byte(64 * 32 + 33) == 255)
        test("... the hole", t2.chunks[9 * 16 + 9 + 1].holes ~= 0)
        test("... the water", #t2.liquids == #t.liquids and #t2.liquids > 0 and t2.liquids[1].kind == 1)
    end
    local list = wdt_names(read(folder .. "/WC3_made.wdt"))
    test("the WDT lists it", list == "31_32 32_32 31_33", list)
    local W = wdl_read(read(folder .. "/WC3_made.wdl"))
    test("the WDL holds its far view", W and W.have[33 * 64 + 31] == 1)

    -- through the editor: undo and redo of an add and of a take-off
    local P = TMP .. "/fake-project"
    os.execute("mkdir -p " .. quote(P .. "/wow/World/Maps") .. " && cp -r " .. quote(MAPDIR) .. " " .. quote(P .. "/wow/World/Maps/"))
    local E = {}
    E.__index = E
    function E:say(text) self.messages[#self.messages + 1] = text end
    function E:undo() return self.history:undo() end
    function E:redo() return self.history:redo() end
    wowmap.attach(E)
    wt.attach(E)
    local e = setmetatable({ project_dir = P, history = history.new(50), dirty = {}, messages = {}, brush = {} }, E)
    local em = assert(e:wow_edit("WC3_made"))
    local efolder = P .. "/wow/World/Maps/WC3_made"
    local orig = { wdt = read(efolder .. "/WC3_made.wdt"), wdl = read(efolder .. "/WC3_made.wdl"),
                   west = read(efolder .. "/WC3_made_31_32.adt"), east = read(efolder .. "/WC3_made_32_32.adt") }
    local added = e:wow_add_tile(31, 33)
    test("the editor adds a tile, one step of its history", added ~= nil and names(em) == "31_32 32_32 31_33"
        and e.history:can_undo() and e.dirty.wow)
    e:undo()
    local clean = true
    for _, t0 in ipairs({ em:tile(31, 32), em:tile(32, 32) }) do
        if t0.dirty then clean = false end
        for _, c in ipairs(t0.chunks) do if c.dirty or c.normals then clean = false end end
    end
    test("undone: the tile gone, its neighbours with nothing to write", names(em) == "31_32 32_32" and clean)
    e:redo()
    test("redone: back", names(em) == "31_32 32_32 31_33" and em:tile(31, 33) == added)
    e:wow_save()
    test("saved: its file there", read(efolder .. "/WC3_made_31_33.adt") ~= nil
        and wdt_names(read(efolder .. "/WC3_made.wdt")) == "31_32 32_32 31_33")
    e:undo()
    e:wow_save()
    test("undone after the save, saved again: every file as it was", read(efolder .. "/WC3_made_31_33.adt") == nil
        and read(efolder .. "/WC3_made.wdt") == orig.wdt and read(efolder .. "/WC3_made.wdl") == orig.wdl
        and read(efolder .. "/WC3_made_31_32.adt") == orig.west and read(efolder .. "/WC3_made_32_32.adt") == orig.east)
    e:redo()
    e:wow_save()
    local again = read(efolder .. "/WC3_made_31_33.adt")
    test("redone after that, saved: the tile written again", again ~= nil
        and wdt_names(read(efolder .. "/WC3_made.wdt")) == "31_32 32_32 31_33")

    -- a tile of the map taken off through the editor, saved, put back
    local gone = e:wow_remove_tile(32, 32)
    test("the editor takes off the hut's tile", gone ~= nil and names(em) == "31_32 31_33")
    e:wow_save()
    test("saved: its file deleted, the WDT and the WDL without it", read(efolder .. "/WC3_made_32_32.adt") == nil
        and wdt_names(read(efolder .. "/WC3_made.wdt")) == "31_32 31_33" and maof(read(efolder .. "/WC3_made.wdl"))[32 * 64 + 32] == nil)
    local W2 = wdl_read(read(efolder .. "/WC3_made.wdl"))
    test("... the WDL still read by the W client, its other tiles' far view there", W2 and W2.have[32 * 64 + 31] == 1
        and W2.have[33 * 64 + 31] == 1 and W2.have[32 * 64 + 32] == 0)
    e:undo()
    e:wow_save()
    test("undone and saved: the hut's tile back byte for byte", read(efolder .. "/WC3_made_32_32.adt") == orig.east)
    local mb = wowmap.open(P .. "/wow", "WC3_made")
    local hut = mb:tile(32, 32)
    test("... listed and read again, the hut in it", hut and #hut.buildings == 1 and names(mb) == "31_32 32_32 31_33")
    local W3 = wdl_read(read(efolder .. "/WC3_made.wdl"))
    test("... its far view back in the WDL", W3 and W3.have[32 * 64 + 32] == 1)
end
-- }}}

-- {{{ Water of formats 1 and 3
section("Water layers of vertex formats 1 and 3 keep their format through an edit")
do
    local root, folder = copy_map()
    local path = folder .. "/WC3_made_31_32.adt"
    local bytes = read(path)
    -- the west tile's water again, written here (not by the module under test):
    -- the lake's first chunk format 3, its second format 1, the rest format 0;
    -- picture positions u = 37 c + 5, v = 41 r + 7 (c, r the chunk's corner)
    local function uv_of(r, c) return 37 * c + 5, 41 * r + 7 end
    local FMT = {}
    local lake = {}
    for _, q in ipairs(west.liquids) do lake[#lake + 1] = q.chunk end
    FMT[lake[1]], FMT[lake[2]] = 3, 1
    local function mh2o(liquids)
        local by = {}
        for _, q in ipairs(liquids) do by[q.chunk] = by[q.chunk] or {} table.insert(by[q.chunk], q) end
        local heads, body = {}, {}
        local at = 256 * 12
        for k = 1, 256 do
            local list = by[k]
            if list then
                local info = at
                local entries, parts = {}, {}
                local after = at + 24 * #list + 16
                for _, q in ipairs(list) do
                    local fmt = FMT[k] or 0
                    local mask = bw.new()
                    local bitsv, nb = 0, 0
                    for r = 0, q.h - 1 do
                        for c = 0, q.w - 1 do
                            if q.wet:byte((q.row + r) * 8 + q.col + c + 1) == 1 then bitsv = bitsv + 2 ^ nb end
                            nb = nb + 1
                            if nb == 8 then mask:u8(bitsv) bitsv, nb = 0, 0 end
                        end
                    end
                    if nb > 0 then mask:u8(bitsv) end
                    local mb = mask:done()
                    mb = mb .. string.rep("\0", (4 - #mb % 4) % 4)
                    local V, UV, D = bw.new(), bw.new(), {}
                    local lo, hi = math.huge, -math.huge
                    for r = q.row, q.row + q.h do
                        for c = q.col, q.col + q.w do
                            local h = q.height[r * 9 + c + 1]
                            V:f32(h)
                            local u, v = uv_of(r, c)
                            UV:u16(u):u16(v)
                            D[#D + 1] = q.depth:sub(r * 9 + c + 1, r * 9 + c + 1)
                            lo, hi = math.min(lo, h), math.max(hi, h)
                        end
                    end
                    local verts = fmt == 0 and (V:done() .. table.concat(D)) or fmt == 1 and (V:done() .. UV:done())
                        or (V:done() .. UV:done() .. table.concat(D))
                    verts = verts .. string.rep("\0", (4 - #verts % 4) % 4)
                    entries[#entries + 1] = bw.new():u16(q.kind):u16(fmt):f32(lo):f32(hi):u8(q.col):u8(q.row):u8(q.w):u8(q.h)
                        :u32(after):u32(after + #mb):done()
                    parts[#parts + 1] = mb .. verts
                    after = after + #mb + #verts
                end
                local attr = string.rep("\0", 16)
                heads[k] = le32(info) .. le32(#list) .. le32(at + 24 * #list)
                local chunk = table.concat(entries) .. attr .. table.concat(parts)
                body[#body + 1] = chunk
                at = at + #chunk
            else
                heads[k] = string.rep("\0", 12)
            end
        end
        return adt.block("MH2O", table.concat(heads) .. table.concat(body))
    end
    -- the new MH2O in place of the old, MCIN's offsets moved along (W02a puts MH2O just before the chunks)
    local blocks = wt.walk(bytes)
    local old
    for _, b in ipairs(blocks) do if b.tag == "MH2O" then old = b end end
    local new = mh2o(west.liquids)
    local delta = #new - old.len
    local out = bytes:sub(1, old.at) .. new .. bytes:sub(old.at + old.len + 1)
    for _, b in ipairs(blocks) do
        if b.tag == "MCIN" then
            for k = 0, 255 do
                local o = b.at + 8 + k * 16
                out = put(out, o, le32(u32(out, o) + delta))
            end
        end
    end
    write(path, out)
    local m = wowmap.open(root, "WC3_made")
    local t, why = m:tile(31, 32)
    test("a tile with water of formats 3 and 1 (made here) reads", t ~= nil and #t.liquids == #west.liquids, why)
    t = t or { liquids = {}, chunks = {} }
    local q1 = t.liquids[1]
    local depth_kept = q1 and q1.depth == west.liquids[1].depth
    local q2
    for _, q in ipairs(t.liquids) do if q.chunk == lake[2] then q2 = q end end
    test("... format 3's depths read, format 1 has none (255)", depth_kept and q2 and q2.depth:byte(q2.row * 9 + q2.col + 1) == 255)

    -- the file's layout, read here
    local function layer_of(file, k)
        local s = read(file)
        for _, b in ipairs(wt.walk(s)) do
            if b.tag == "MH2O" then
                local D = s:sub(b.at + 9, b.at + b.len)
                local L = ww.layout(D)
                local f = L[k].layers[1]
                if not f then return nil end
                local uv = {}
                if f.fmt == 1 or f.fmt == 3 then
                    local base, i = f.ov + (f.w + 1) * (f.h + 1) * 4, 0
                    for r = 0, f.h do
                        for c = 0, f.w do
                            uv[(f.row + r) * 9 + f.col + c + 1] = { u16(D, base + i * 4), u16(D, base + i * 4 + 2) }
                            i = i + 1
                        end
                    end
                end
                return f, uv, D
            end
        end
    end
    local f3 = layer_of(path, lake[1])
    test("... its first lake chunk format 3, as written here", f3 and f3.fmt == 3)

    -- water put on a cell next to the lake in the format-3 chunk, and one cell of the format-1 chunk dried
    local k3 = lake[1]
    local c3 = t.chunks[k3]
    local qa
    for _, q in ipairs(t.liquids) do if q.chunk == k3 then qa = q end end
    local level = qa.height[qa.row * 9 + qa.col + 1]
    local was_a = { row = qa.row, col = qa.col, w = qa.w, h = qa.h }      -- (the tools change the layer in place)
    -- a dry cell of the chunk, beside the rectangle (west of it, or north)
    local nr, nc = qa.row, qa.col - 1
    if nc < 0 then nr, nc = qa.row - 1, qa.col end
    local ok_cell = nr >= 0 and nc >= 0
    test("a dry cell next to the format-3 water", ok_cell, qa.row .. " " .. qa.col)
    if ok_cell then
        local x = ORIGIN - (32 * 16 + c3.iy) * CHUNK - (nr + 0.5) * CELL
        local y = ORIGIN - (31 * 16 + c3.ix) * CHUNK - (nc + 0.5) * CELL
        local got = ww.water(m, x, y, { radius = 0, level = level })
        test("watered at the lake's level", got and got.cells == 1)
        local k1 = lake[2]
        local qb
        for _, q in ipairs(t.liquids) do if q.chunk == k1 then qb = q end end
        local c1 = t.chunks[k1]
        local dr, dc = qb.row + qb.h - 1, qb.col + qb.w - 1
        local dx = ORIGIN - (32 * 16 + c1.iy) * CHUNK - (dr + 0.5) * CELL
        local dy = ORIGIN - (31 * 16 + c1.ix) * CHUNK - (dc + 0.5) * CELL
        local dried = ww.dry(m, dx, dy, { radius = 0 })
        test("a cell of the format-1 water dried", dried and dried.cells == 1)
        local written, swhy = wt.save(m)
        test("saved", written ~= nil, swhy)
        local g3, uv3 = layer_of(path, k3)
        test("the edited format-3 layer is format 3 still", g3 and g3.fmt == 3, g3 and g3.fmt)
        local kept, fresh, nk, nf = true, true, 0, 0
        if g3 then
            for r = g3.row, g3.row + g3.h do
                for c = g3.col, g3.col + g3.w do
                    local e = uv3[r * 9 + c + 1]
                    local u, v = uv_of(r, c)
                    local inside_old = r >= was_a.row and r <= was_a.row + was_a.h and c >= was_a.col and c <= was_a.col + was_a.w
                    if inside_old then nk = nk + 1 if e[1] ~= u or e[2] ~= v then kept = false end
                    else nf = nf + 1 if e[1] ~= u or e[2] ~= v then fresh = false end end
                end
            end
        end
        test("... the points it had keep their picture positions", g3 and kept and nk > 0, nk)
        test("... the new points get the ones the layer's own lie on (here exactly 37 c + 5, 41 r + 7)",
            g3 and fresh and nf > 0, nf)
        local g1, uv1 = layer_of(path, k1)
        local kept1 = true
        if g1 then
            for p, e in pairs(uv1) do
                local u, v = uv_of(math.floor((p - 1) / 9), (p - 1) % 9)
                if e[1] ~= u or e[2] ~= v then kept1 = false end
            end
        end
        test("the edited format-1 layer: format 1 still, its positions kept", g1 and g1.fmt == 1 and kept1, g1 and g1.fmt)
        local m2 = wowmap.open(root, "WC3_made")
        local t2 = m2:tile(31, 32)
        local same = t2 ~= nil
        if t2 then
            for i, q in ipairs(t.liquids) do
                local r = t2.liquids[i]
                if not r or r.wet ~= q.wet or r.kind ~= q.kind then same = false
                else
                    for row = q.row, q.row + q.h do
                        for col = q.col, q.col + q.w do
                            if math.abs(r.height[row * 9 + col + 1] - q.height[row * 9 + col + 1]) > 1e-3 then same = false end
                        end
                    end
                end
            end
        end
        test("read back by the W client's reader: the water as edited", same)
        local qq
        for _, q in ipairs(t2 and t2.liquids or {}) do if q.chunk == k3 then qq = q end end
        test("... format 3's depths there still (format 1 none)", qq and qq.depth:byte(nr * 9 + nc + 1) ~= 255)
        -- the other water chunks byte for byte
        local s_after = read(path)
        local other_same = true
        local function chunk_part(s, k)
            for _, b in ipairs(wt.walk(s)) do
                if b.tag == "MH2O" then
                    local D = s:sub(b.at + 9, b.at + b.len)
                    local L = ww.layout(D)
                    -- each layer's own fields (not where its parts are), then its mask and points
                    local parts = {}
                    for _, q in ipairs(L[k].layers) do
                        parts[#parts + 1] = D:sub(q.e + 1, q.e + 16)
                        for _, p in ipairs(L[k].parts) do
                            if p.start == q.ob or p.start == q.ov then parts[#parts + 1] = D:sub(p.start + 1, p.stop) end
                        end
                    end
                    return table.concat(parts)
                end
            end
        end
        for _, k in ipairs(lake) do
            if k ~= k3 and k ~= k1 and chunk_part(s_after, k) ~= chunk_part(out, k) then other_same = false end
        end
        test("the lake's other chunks: their water's bytes as they were", other_same)
    end
    -- the plane through a layer's positions (ww.plane)
    local fit = ww.plane({ [1] = { 10, 20 }, [2] = { 13, 20 }, [10] = { 10, 25 } })
    local u, v = fit(2, 2)
    test("ww.plane: positions on a plane extended across it", u == 16 and v == 30, u .. " " .. v)
    u, v = ww.plane({})(1, 3)
    test("ww.plane with no positions: UV_STEP a cell", u == 3 * ww.UV_STEP and v == ww.UV_STEP)
end
-- }}}

end

os.execute("rm -rf " .. quote(TMP))

print(string.format("\n%s\nTests: %d passed, %d failed, %d skipped", string.rep("=", 50), pass_count,
    test_count - pass_count, skip_count))
os.exit(pass_count == test_count and 0 or 1)

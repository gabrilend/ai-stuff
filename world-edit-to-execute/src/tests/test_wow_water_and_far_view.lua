--[[
Tests for issue W10c: a WoW map's far view (its WDL) made again from
edited tiles (src/editor/wowwdl.lua), and water put on and taken off its
tiles (src/editor/wowwater.lua), the tile's MH2O written again with the
edits in it, both read back through the W client's own reader.

The WoW map is made by W02's converter from a made WC3 terrain (no WC3
or WoW install): two tiles, a lake in the west one, a tree and a hut.
The reader's part needs the W client's reader library ($W_CLIENT_BUILD,
a folder holding libwreaders.so and wreaders.h); without it only what
needs no reading runs, and the rest is skipped.

    luajit src/tests/test_wow_water_and_far_view.lua [project folder]
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
local coords = require("wowbuild.coords")
local wowbuild = require("wowbuild")
local wowmap = require("editor.wowmap")
local wt = require("editor.wowterrain")
local mapfile = require("editor.mapfile")
local history = require("editor.history")
local ww = require("editor.wowwater")
local wdl = require("editor.wowwdl")
local adt = require("wowbuild.adt")

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
local cell = ffi.new("union { uint32_t u; float f; }")
local function u32(s, at)
    local a, b, c, d = s:byte(at + 1, at + 4)
    return a + b * 256 + c * 65536 + d * 16777216
end
local function le32(v) cell.u = v return string.char(v % 256, math.floor(v / 256) % 256, math.floor(v / 65536) % 256, math.floor(v / 16777216) % 256) end
local function put(s, at, bytes) return s:sub(1, at) .. bytes .. s:sub(at + #bytes + 1) end
-- }}}

-- {{{ A WoW map, made by W02's converter (as test_wow_layer makes it)
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

-- a fresh copy of the made map, as a loose folder of its own
local copies = 0
local function copy_map()
    copies = copies + 1
    local root = TMP .. "/copy" .. copies
    os.execute("mkdir -p " .. quote(root .. "/World/Maps") .. " && cp -r " .. quote(MAPDIR) .. " " .. quote(root .. "/World/Maps/"))
    return root, root .. "/World/Maps/WC3_made"
end

-- each MCNK's sub-blocks: where MCVT's and MCNR's data are in the file
local function chunk_spans(bytes)
    local out = {}
    for _, b in ipairs(wt.walk(bytes)) do
        if b.tag == "MCNK" then
            local h = b.at + 8
            local mcvt, mcnr = b.at + u32(bytes, h + 20), b.at + u32(bytes, h + 24)
            out[#out + 1] = { at = b.at, len = b.len, ix = u32(bytes, h + 4), iy = u32(bytes, h + 8),
                              mcvt = { mcvt + 8, mcvt + 8 + 580 }, mcnr = { mcnr + 8, mcnr + 8 + 435 } }
        end
    end
    return out
end
-- bytes that differ outside the given spans (from 0, end not included)
local function differ_outside(a, b, spans)
    if #a ~= #b then return -1 end
    local inside = {}
    for _, s in ipairs(spans) do inside[#inside + 1] = s end
    local n = 0
    for p = 0, #a - 1 do
        if a:byte(p + 1) ~= b:byte(p + 1) then
            local ok = false
            for _, s in ipairs(inside) do if p >= s[1] and p < s[2] then ok = true break end end
            if not ok then n = n + 1 end
        end
    end
    return n
end
-- a chunk's world centre
local function centre(t, ix, iy)
    return ORIGIN - (t.ty * 16 + iy + 0.5) * CHUNK, ORIGIN - (t.tx * 16 + ix + 0.5) * CHUNK
end
local function cx(t, ix, iy) return (centre(t, ix, iy)) end
local function cy(t, ix, iy) return select(2, centre(t, ix, iy)) end
-- }}}

-- {{{ more helpers: a WDL's tiles, water compared
local function u16(s, at) local a, b = s:byte(at + 1, at + 2) return a + b * 256 end
local function i16(s, at) local v = u16(s, at) return v >= 32768 and v - 65536 or v end
local function h16(v) return math.floor(v + 0.5) end
-- a WDL's tiles: { [ty * 64 + tx] = { at, values = { 545 }, holes = { 16 } or nil } }
local function wdl_tiles(bytes)
    local out = {}
    for _, b in ipairs(wt.walk(bytes)) do
        if b.tag == "MAOF" then
            for i = 0, 4095 do
                local o = u32(bytes, b.at + 8 + i * 4)
                if o ~= 0 then
                    local e = { at = o, values = {} }
                    for n = 1, 545 do e.values[n] = i16(bytes, o + 8 + (n - 1) * 2) end
                    local h = o + 8 + u32(bytes, o + 4)
                    if h + 8 <= #bytes and bytes:sub(h + 1, h + 4) == "OHAM" then
                        e.holes = {}
                        for r = 1, 16 do e.holes[r] = u16(bytes, h + 8 + (r - 1) * 2) end
                    end
                    out[i] = e
                end
            end
        end
    end
    return out
end
-- the water of a tile (or of its chunk k), as two tiles' data compare:
-- the rectangle, wet cells, kind, and inside the rectangle heights and depths
local function water_of(t, k)
    local out = {}
    for _, q in ipairs(t.liquids) do if not k or q.chunk == k then out[#out + 1] = q end end
    return out
end
local function same_water(a, b, k)
    local la, lb = water_of(a, k), water_of(b, k)
    if #la ~= #lb then return false, #la .. " layers, " .. #lb .. " layers" end
    for i = 1, #la do
        local p, q = la[i], lb[i]
        if p.chunk ~= q.chunk or p.kind ~= q.kind or p.col ~= q.col or p.row ~= q.row or p.w ~= q.w or p.h ~= q.h
            or p.wet ~= q.wet then
            return false, string.format("chunk %d layer %d: its cells differ", p.chunk, i)
        end
        for r = p.row, p.row + p.h do
            for c = p.col, p.col + p.w do
                local n = r * 9 + c + 1
                if math.abs(p.height[n] - q.height[n]) > 1e-3 then
                    return false, string.format("chunk %d corner %d, %d: height %.3f, %.3f", p.chunk, r, c, p.height[n], q.height[n])
                end
                if p.depth:byte(n) ~= q.depth:byte(n) then
                    return false, string.format("chunk %d corner %d, %d: depth %d, %d", p.chunk, r, c, p.depth:byte(n), q.depth:byte(n))
                end
            end
        end
    end
    return true
end
-- the MH2O block of a tile file: { at (its tag), data }
local function mh2o_of(bytes)
    for _, b in ipairs(wt.walk(bytes)) do
        if b.tag == "MH2O" then return { at = b.at, len = b.len, data = bytes:sub(b.at + 9, b.at + b.len) } end
    end
end
local function read_tile(root, t)
    local m = wowmap.open(root, "WC3_made")
    return m:tile(t.tx, t.ty)
end
-- }}}

-- {{{ No edit: as it was (no reader needed)
section("No edit: the WDL and the water as they were")
do
    local f = wowmap.files(BUILD, "WC3_made")
    local original = read(MAPDIR .. "/WC3_made.wdl")
    test("the WDL patched for no tile: byte for byte", wdl.patch(original, {}) == original)
    local bytes = read(MAPDIR .. "/" .. f.tiles[1].file)
    local block = mh2o_of(bytes)
    test("the west tile has water (W02's lake): an MH2O block", block ~= nil)
    local whole = bytes:sub(block.at + 1, block.at + block.len)
    test("its MH2O with no water edit: byte for byte", ww.mh2o_bytes(whole, { chunks = {}, liquids = {} }) == whole)
    local L = ww.layout(block.data)
    local wet, fmt0 = 0, true
    for k = 1, 256 do
        wet = wet + (L[k].count > 0 and 1 or 0)
        for _, q in ipairs(L[k].layers) do fmt0 = fmt0 and q.fmt == 0 and q.depth_at ~= nil end
    end
    test("its layout: the lake's chunks, a layer each in format 0 (heights, then depths)", wet >= 2 and wet <= 9 and fmt0, wet)
    test("the east tile: no water, no MH2O", mh2o_of(read(MAPDIR .. "/" .. f.tiles[2].file)) == nil)
    local bad = ww.layout(string.rep("\0", 100))
    test("an MH2O shorter than its heads: refused", bad == nil)
end
-- }}}

local lib, lib_why = wowmap.reader()
if not lib then
    skip("the far view and the water, read back through the W client's reader", lib_why)
else

local function reader_wdl(bytes)
    local W, why = ffi.new("AdtWdl"), ffi.new("WWhy")
    local buf = ffi.new("unsigned char[?]", #bytes)
    ffi.copy(buf, bytes, #bytes)
    if lib.adt_wdl_read(buf, #bytes, W, why) ~= 0 then return nil, ffi.string(why.text) end
    return W
end

local root0 = copy_map()
local m0 = wowmap.open(root0, "WC3_made")
local tiles = {}
for i, e in ipairs(m0.tiles) do tiles[i] = assert(m0:tile(e.tx, e.ty)) end
local west, east = tiles[1], tiles[2]
local WI, EI = west.ty * 64 + west.tx, east.ty * 64 + east.tx
-- the lake's chunks (1-256), north-west first; and where a chunk is
local LAKE = {}
for _, q in ipairs(west.liquids) do LAKE[#LAKE + 1] = q.chunk end
local function ixy(k) return (k - 1) % 16, math.floor((k - 1) / 16) end

-- {{{ The WDL
section("The far view (WDL) from the tiles")
do
    local made = wdl.make(m0)
    local a, b = wdl_tiles(read(MAPDIR .. "/WC3_made.wdl")), wdl_tiles(made)
    local worst, exact, n = 0, 0, 0
    for _, i in ipairs({ WI, EI }) do
        for k = 1, 545 do
            local d = math.abs(a[i].values[k] - b[i].values[k])
            worst = math.max(worst, d)
            n = n + 1
            if d == 0 then exact = exact + 1 end
        end
    end
    test("made afresh from the tiles: W02's own WDL within a yard (rounding)", a[WI] and b[WI] and b[EI] and worst <= 1,
        string.format("worst %d, %d of %d exact", worst, exact, n))
    test("... the same size and tiles", #made == #read(MAPDIR .. "/WC3_made.wdl"))
    local W = reader_wdl(made)
    test("... read by the W client's reader: both tiles", W and W.have[WI] == 1 and W.have[EI] == 1 and W.have[WI + 2] == 0)

    -- raised ground and a chunk all holes, saved
    local root, folder = copy_map()
    local m = wowmap.open(root, "WC3_made")
    local t = assert(m:tile(west.tx, west.ty))
    local before = read(folder .. "/WC3_made.wdl")
    local x, y = centre(t, 5, 5)
    wt.raise(m, x, y, { radius = 20, amount = 6 })
    wt.holes(m, cx(t, 8, 8), cy(t, 8, 8), { radius = 30 })
    local written = wt.save(m)
    test("saved: the tile and the WDL", written and #written == 2 and written[2] == "WC3_made.wdl",
        written and table.concat(written, ", "))
    local now = read(folder .. "/WC3_made.wdl")
    test("the WDL changed in place: the same size", #now == #before)
    local A, B = wdl_tiles(before), wdl_tiles(now)
    local bad, changed = 0, 0
    for k = 1, 545 do
        local s = wdl.SOURCES[k]
        local c, c0 = t.chunks[s[1]], west.chunks[s[1]]
        local moved = false
        for i = 1, 145 do if c.heights[i] ~= c0.heights[i] then moved = true break end end
        if moved then
            changed = changed + 1
            if B[WI].values[k] ~= h16(c.z + c.heights[s[2]]) then bad = bad + 1 end
        elseif B[WI].values[k] ~= A[WI].values[k] then bad = bad + 1 end
    end
    test("each far height under the edit from the new ground; every other as it was", bad == 0 and changed > 0,
        string.format("%d wrong, %d changed", bad, changed))
    local same_east = true
    for k = 1, 545 do same_east = same_east and A[EI].values[k] == B[EI].values[k] end
    test("... the unedited tile's untouched", same_east)
    local W2 = reader_wdl(now)
    local agree = W2 ~= nil
    for k = 0, 288 do agree = agree and W2.heights[WI][k] == B[WI].values[k + 1] end
    test("read by the W client's reader: those heights", agree)
    test("the chunk all holes: its far hole bit set; its neighbours, partly holes, not",
        W2 and bit.band(W2.holes[WI][8], 2 ^ 8) ~= 0 and bit.band(W2.holes[WI][8], 2 ^ 9) == 0
        and bit.band(W2.holes[WI][8], 2 ^ 7) == 0, W2 and W2.holes[WI][8])
    -- filled again
    wt.holes(m, cx(t, 8, 8), cy(t, 8, 8), { radius = 30, on = false })
    wt.save(m)
    local W3 = reader_wdl(read(folder .. "/WC3_made.wdl"))
    test("filled again: the bit cleared", W3 and W3.holes[WI][8] == 0)
end

section("A WDL laid out otherwise: a tile with no MAHO, a tile missing")
do
    local root, folder = copy_map()
    local mare_w = wdl.blocks(west)
    local mare_e, maho_e = wdl.blocks(east)
    local mver = adt.block("MVER", le32(18))
    local at0 = #mver + 8 + 4096 * 4
    local function maof(list)
        local parts = {}
        for i = 0, 4095 do parts[i + 1] = le32(list[i] or 0) end
        return adt.block("MAOF", table.concat(parts))
    end
    -- the west tile's MARE with no MAHO after it, then the east tile's
    local odd = mver .. maof({ [WI] = at0, [EI] = at0 + #mare_w }) .. mare_w .. mare_e .. maho_e
    write(folder .. "/WC3_made.wdl", odd)
    test("made: the W client's reader reads it", reader_wdl(odd) ~= nil)
    local m = wowmap.open(root, "WC3_made")
    local t = assert(m:tile(west.tx, west.ty))
    wt.holes(m, cx(t, 3, 12), cy(t, 3, 12), { radius = 30 })
    local ok, why = wt.save(m)
    test("a chunk all holes in the tile with no MAHO: saved", ok, why)
    local now = read(folder .. "/WC3_made.wdl")
    local W = reader_wdl(now)
    test("... a MAHO put in, its bit set, the next tile's offset moved along", W and #now == #odd + 8 + 32
        and bit.band(W.holes[WI][12], 2 ^ 3) ~= 0 and W.have[EI] == 1 and W.heights[EI][0] == wdl_tiles(odd)[EI].values[1])

    -- a WDL that lists only the east tile
    local only_east = mver .. maof({ [EI] = at0 }) .. mare_e .. maho_e
    write(folder .. "/WC3_made.wdl", only_east)
    local m2 = wowmap.open(root, "WC3_made")
    local t2 = assert(m2:tile(west.tx, west.ty))
    wt.raise(m2, cx(t2, 6, 6), cy(t2, 6, 6), { radius = 10, amount = 1 })
    wt.save(m2)
    local W2 = reader_wdl(read(folder .. "/WC3_made.wdl"))
    test("a tile the WDL hadn't: added at its end, listed", W2 and W2.have[WI] == 1 and W2.have[EI] == 1
        and W2.heights[WI][6 * 17 + 6] == h16(t2.chunks[6 * 16 + 7].z + t2.chunks[6 * 16 + 7].heights[1]))

    -- MAOF pointing at something that isn't an MARE
    local broken = put(only_east, #mver + 8 + EI * 4, le32(7))
    local t3 = { tx = east.tx, ty = east.ty, chunks = {} }
    for k = 1, 256 do t3.chunks[k] = { z = 0, heights = east.chunks[k].heights, holes = 0, dirty = { heights = true } } end
    local nope, nwhy = wdl.patch(broken, { t3 })
    test("MAOF pointing where no MARE is: refused, saying so", nope == nil and (nwhy or ""):find("no MARE", 1, true), nwhy)
    local none, mwhy = wdl.patch(mver, { t3 })
    test("a WDL with no MAOF: refused", none == nil and mwhy ~= nil)
end
-- }}}

-- {{{ Water
section("Water: W02's written again by the water writer, unchanged")
do
    local bytes = read(m0.folder .. "/" .. west.file)
    for k, c in ipairs(west.chunks) do
        if #water_of(west, k) > 0 then c.dirty = { water = true } west.dirty = true end
    end
    test("every chunk with water written again in W02a's form: the tile byte for byte",
        wt.tile_bytes(bytes, west, { big_alpha = true }) == bytes)
    for _, c in ipairs(west.chunks) do c.dirty = nil end
    west.dirty = nil
end

section("Water put on, taken off, under changed ground")
do
    local root, folder = copy_map()
    local m = wowmap.open(root, "WC3_made")
    local t = assert(m:tile(west.tx, west.ty))
    local before = read(folder .. "/" .. t.file)
    local x, y = centre(t, 10, 10)
    local g = wt.ground(m, x, y)
    local got = ww.water(m, x, y, { radius = 6, level = g + 3 })
    local k = 10 * 16 + 10 + 1
    local q = water_of(t, k)[1]
    test("water put on dry ground: a layer in that chunk, its cells under the brush", got and got.cells >= 4
        and q and q.kind == 1 and q.wet:byte(4 * 8 + 4 + 1) == 1 and q.wet:byte(1) == 0, got and got.cells)
    local c = t.chunks[k]
    test("... its corners at the level, its depth from the ground (yards x 9)", q and q.height[4 * 9 + 4 + 1] == g + 3
        and q.depth:byte(4 * 9 + 4 + 1) == math.floor((g + 3 - (c.z + c.heights[4 * 17 + 4 + 1])) * 9 + 0.5))
    test("a radius of 0: the one cell at the point", ww.water(m, x + 12, y, { level = g + 3 }).cells == 1)
    local written, why = wt.save(m)
    test("saved", written and written[1] == t.file, why)
    local t2 = read_tile(root, t)
    local ok, wwhy = same_water(t, t2)
    test("read back through the reader: every chunk's water as left", ok, wwhy)
    test("... the lake's as it was made", #LAKE == 4 and same_water(west, t2, LAKE[1]) and same_water(west, t2, LAKE[4]), #LAKE)
    -- the lake's bytes kept: its points the same bytes, only where they are moved
    local L0, L1 = ww.layout(mh2o_of(before).data), ww.layout(mh2o_of(read(folder .. "/" .. t.file)).data)
    local kept = true
    for kk = 1, 256 do
        if kk ~= k and L0[kk].count > 0 then
            local a, b = L0[kk].layers[1], L1[kk].layers[1]
            local np = (a.w + 1) * (a.h + 1)
            kept = kept and mh2o_of(before).data:sub(a.ov + 1, a.ov + np * 5) == mh2o_of(read(folder .. "/" .. t.file)).data:sub(b.ov + 1, b.ov + np * 5)
        end
    end
    test("... every other chunk's water byte for byte", kept)

    -- the east tile had none: an MH2O made
    local e = assert(m:tile(east.tx, east.ty))
    local ex, ey = centre(e, 4, 4)
    ww.water(m, ex, ey, { radius = 8, kind = 2 })
    local w2, why2 = wt.save(m)
    test("water on a tile with none: saved", w2 and #w2 >= 1, why2)
    local ebytes = read(folder .. "/" .. e.file)
    local e2 = read_tile(root, e)
    test("... an MH2O made, and the reader finds the water (ocean, kind 2)", mh2o_of(ebytes) ~= nil and e2
        and #e2.liquids >= 1 and e2.liquids[1].kind == 2 and same_water(e, e2))
    test("... the hut still found (MHDR's and MCIN's offsets followed)", e2 and #e2.buildings == #east.buildings
        and e2.buildings[1].model == east.buildings[1].model)

    -- dried
    local lx, ly = centre(t, ixy(LAKE[4]))
    local d = ww.dry(m, lx, ly, { radius = 25 })
    test("dried: a chunk's every cell, so it has no water left", d.cells > 0 and #water_of(t, LAKE[4]) == 0)
    test("... its neighbour's lake cells partly left", #water_of(t, LAKE[2]) == 1
        and water_of(t, LAKE[2])[1].wet ~= water_of(west, LAKE[2])[1].wet)
    wt.save(m)
    local t3 = read_tile(root, t)
    test("read back: dried", same_water(t, t3) and #water_of(t3, LAKE[4]) == 0, select(2, same_water(t, t3)))
end

section("The ground moved under water: depths follow, in place")
do
    local root, folder = copy_map()
    local m = wowmap.open(root, "WC3_made")
    local t = assert(m:tile(west.tx, west.ty))
    local before = read(folder .. "/" .. t.file)
    local q = water_of(t, LAKE[1])[1]
    local qx, qy = ixy(LAKE[1])
    local lx = ORIGIN - (t.ty * 16 + qy) * CHUNK - (q.row + 1) * CELL
    local ly = ORIGIN - (t.tx * 16 + qx) * CHUNK - (q.col + 1) * CELL
    wt.raise(m, lx, ly, { radius = 8, amount = 1 })
    wt.save(m)
    local now = read(folder .. "/" .. t.file)
    local t2 = read_tile(root, t)
    test("raised under the lake: the file the same size", #now == #before)
    local ok, why = same_water(t, t2)
    test("read back: the water's depths as the data has them", ok, why)
    local c = t.chunks[LAKE[1]]
    local r, cc = q.row + 1, q.col + 1
    test("... a moved corner's depth from its new ground", q.depth:byte(r * 9 + cc + 1)
        == math.max(0, math.min(255, math.floor((q.height[r * 9 + cc + 1] - (c.z + c.heights[r * 17 + cc + 1])) * 9 + 0.5)))
        and q.depth ~= water_of(west, LAKE[1])[1].depth)
    -- only depth bytes (and heights and normals) changed
    local spans = {}
    for _, s in ipairs(chunk_spans(before)) do spans[#spans + 1] = s.mcvt spans[#spans + 1] = s.mcnr end
    local B = mh2o_of(before)
    local L = ww.layout(B.data)
    for k = 1, 256 do
        for _, f in ipairs(L[k].layers) do
            local np = (f.w + 1) * (f.h + 1)
            spans[#spans + 1] = { B.at + 8 + f.depth_at, B.at + 8 + f.depth_at + np }
        end
    end
    test("... nothing else in the file changed", differ_outside(before, now, spans) == 0)
    local changed = 0
    for p = 1, #before do if before:byte(p) ~= now:byte(p) then changed = changed + 1 end end
    local dchanged = 0
    for _, s in ipairs(spans) do
        if s[2] - s[1] < 200 then
            for p = s[1] + 1, s[2] do if before:byte(p) ~= now:byte(p) then dchanged = dchanged + 1 end end
        end
    end
    test("... and some depth bytes did", dchanged > 0, dchanged)
end

section("Water laid out as the original's: grouped parts, a depth-only layer, an unknown format")
do
    local root, folder = copy_map()
    local file = folder .. "/" .. west.file
    local bytes = read(file)
    local B = mh2o_of(bytes)
    local D = B.data
    local L = ww.layout(D)
    -- every chunk's parts grouped by kind: all layers, all attributes, all masks, all points
    local function pad4(n) return n + (4 - n % 4) % 4 end
    local wet = {}
    for k = 1, 256 do if L[k].count > 0 then wet[#wet + 1] = k end end
    local groups = { infos = {}, attrs = {}, masks = {}, points = {} }
    local at = 3072
    local where = {}
    for _, k in ipairs(wet) do where[k] = { info = at } at = at + 24 * L[k].count end
    for _, k in ipairs(wet) do where[k].attr = at at = at + 16 end
    for _, k in ipairs(wet) do
        local f = L[k].layers[1]
        if f.ob ~= 0 then where[k].ob = at at = at + pad4(math.ceil(f.w * f.h / 8)) end
    end
    for _, k in ipairs(wet) do
        local f = L[k].layers[1]
        where[k].ov = at
        at = at + pad4((f.w + 1) * (f.h + 1) * 5)
    end
    test("grouped: the same size as W02a's", at == #D, at .. " / " .. #D)
    local G = {}
    for k = 1, 256 do
        local w = where[k]
        G[#G + 1] = w and (le32(w.info) .. le32(L[k].count) .. le32(w.attr)) or string.rep("\0", 12)
    end
    local body = string.rep("\0", #D - 3072)
    local function place(s, pos, what) body = put(body, pos - 3072, what) end
    for _, k in ipairs(wet) do
        local f, w = L[k].layers[1], where[k]
        local np = (f.w + 1) * (f.h + 1)
        local info = D:sub(f.e + 1, f.e + 24)
        info = put(info, 16, le32(f.ob ~= 0 and w.ob or 0))
        info = put(info, 20, le32(w.ov))
        place(body, w.info, info)
        place(body, w.attr, D:sub(L[k].attr + 1, L[k].attr + 16))
        if f.ob ~= 0 then place(body, w.ob, D:sub(f.ob + 1, f.ob + math.ceil(f.w * f.h / 8))) end
        place(body, w.ov, D:sub(f.ov + 1, f.ov + np * 5))
    end
    local D2 = table.concat(G) .. body
    -- the first wet chunk's layer: depths only (format 2), its points at its depths
    local k2 = wet[1]
    local f2 = L[k2].layers[1]
    local e2 = where[k2].info
    D2 = put(D2, e2 + 2, string.char(2, 0))
    D2 = put(D2, e2 + 20, le32(where[k2].ov + (f2.w + 1) * (f2.h + 1) * 4))
    local grouped = put(bytes, B.at + 8, D2)
    write(file, grouped)
    local m = wowmap.open(root, "WC3_made")
    local t = assert(m:tile(west.tx, west.ty))
    test("the reader reads it: every other chunk's water as made", (function()
        for _, k in ipairs(wet) do if k ~= k2 and not same_water(west, t, k) then return false end end
        return true end)())
    local q2 = water_of(t, k2)[1]
    test("... the depth-only layer: its depths, its surface flat", q2 and q2.depth == water_of(west, k2)[1].depth
        and q2.height[q2.row * 9 + q2.col + 1] == q2.height[(q2.row + q2.h) * 9 + q2.col + q2.w + 1])
    test("written with no edit: byte for byte", wt.tile_bytes(grouped, t, { big_alpha = true }) == grouped)

    -- one chunk's water edited: the others' parts kept, the depth-only layer still depth-only
    local k3 = wet[#wet]
    local c3 = t.chunks[k3]
    local q3 = water_of(t, k3)[1]
    local x3 = ORIGIN - (t.ty * 16 + c3.iy) * CHUNK - (q3.row + 0.5) * CELL
    local y3 = ORIGIN - (t.tx * 16 + c3.ix) * CHUNK - (q3.col + 0.5) * CELL
    ww.water(m, x3, y3, { level = q3.height[q3.row * 9 + q3.col + 1] + 1 })
    local out, why = wt.tile_bytes(grouped, t, { big_alpha = true })
    test("one chunk's water edited among grouped parts: written", out ~= nil, why)
    out = out or grouped
    write(file, out)
    local t2 = read_tile(root, t)
    test("... read back: that chunk as edited, every other as it was", t2 and same_water(t, t2), t2 and select(2, same_water(t, t2)))
    local L2 = ww.layout(mh2o_of(out).data)
    test("... the depth-only layer still format 2, its depth bytes the same", L2[k2].layers[1].fmt == 2
        and mh2o_of(out).data:sub(L2[k2].layers[1].ov + 1, L2[k2].layers[1].ov + (f2.w + 1) * (f2.h + 1))
        == D2:sub(where[k2].ov + (f2.w + 1) * (f2.h + 1) * 4 + 1, where[k2].ov + (f2.w + 1) * (f2.h + 1) * 5))

    -- the ground under the depth-only layer raised: its depth bytes follow
    local m3 = wowmap.open(root, "WC3_made")
    local t3 = assert(m3:tile(west.tx, west.ty))
    local c2 = t3.chunks[k2]
    local q = water_of(t3, k2)[1]
    wt.raise(m3, ORIGIN - (t3.ty * 16 + c2.iy) * CHUNK - (q.row + 1) * CELL,
        ORIGIN - (t3.tx * 16 + c2.ix) * CHUNK - (q.col + 1) * CELL, { radius = 6, amount = 0.5 })
    local before_depth = q.depth
    local ok3, why3 = wt.save(m3)
    local t4 = ok3 and read_tile(root, t3)
    test("raised under the depth-only layer: its depths follow in the file", t4 and same_water(t3, t4, k2)
        and water_of(t4, k2)[1].depth ~= water_of(west, k2)[1].depth, why3)

    -- an unknown format: its own chunk can't be rewritten, the others can
    local now = read(file)
    local B5 = mh2o_of(now)
    local L5 = ww.layout(B5.data)
    local odd = put(now, B5.at + 8 + L5[k2].layers[1].e + 2, string.char(9, 0))
    local m5 = wowmap.open(root, "WC3_made")
    write(file, odd)
    local t5 = assert(m5:tile(west.tx, west.ty))
    local c5 = t5.chunks[k3]
    c5.dirty = { water = true }
    local fine, fwhy = wt.tile_bytes(odd, t5, { big_alpha = true })
    test("an unknown vertex format in one chunk: another chunk's water still written", fine ~= nil, fwhy)
    c5.dirty = nil
    t5.chunks[k2].dirty = { water = true }
    local nope, nwhy = wt.tile_bytes(odd, t5, { big_alpha = true })
    test("... its own chunk's water: refused, saying which format", nope == nil and (nwhy or ""):find("vertex format 9", 1, true), nwhy)
end
-- }}}

-- {{{ The editor's water strokes
section("The editor's water and dry strokes on a WoW map")
do
    local root, folder = copy_map()
    local P = TMP .. "/fake-project"
    os.execute("mkdir -p " .. quote(P .. "/wow/World/Maps") .. " && cp -r " .. quote(folder) .. " " .. quote(P .. "/wow/World/Maps/"))
    local E = {}
    E.__index = E
    function E:say(text) self.messages[#self.messages + 1] = text end
    function E:undo() return self.history:undo() end
    function E:redo() return self.history:redo() end
    require("editor.terrain")(E)
    wowmap.attach(E)
    wt.attach(E)
    local e = setmetatable({ project_dir = P, history = history.new(50), dirty = {}, messages = {}, changed_tiles = {},
                             terrain_touched = {}, tool = "water",
                             brush = { size = 2, strength = 32, texture = 0, wow_radius = 8 } }, E)
    local m = assert(e:wow_edit("WC3_made"))
    local t = assert(m:tile(west.tx, west.ty))
    local x, y = centre(t, 12, 6)
    local k = 6 * 16 + 12 + 1
    local g = wt.ground(m, x, y)
    e:stroke_begin(nil, x, y) e:stroke(x, y)
    local name = e:stroke_end()
    local q = water_of(t, k)[1]
    test("a water stroke: water 2 yards over the ground where it began", name == "Water (WoW map WC3_made)" and q
        and q.height[4 * 9 + 4 + 1] == g + 2, name)
    e:undo()
    local clean = t.dirty == nil
    for _, c in ipairs(t.chunks) do if c.dirty then clean = false end end
    test("undone: no water there, nothing to write", #water_of(t, k) == 0 and clean)
    e:redo()
    test("redone", #water_of(t, k) == 1 and t.dirty == true)
    e.tool = "dry"
    local lx, ly = centre(t, ixy(LAKE[4]))
    e:stroke_begin(nil, lx, ly) e:stroke(lx, ly) e:stroke_end()
    test("a dry stroke on the lake", #water_of(t, LAKE[4]) == 0 or water_of(t, LAKE[4])[1].wet ~= water_of(west, LAKE[4])[1].wet)
    local written, why = e:wow_save()
    test("saved", written and #written >= 1, why)
    local t2 = assert(wowmap.open(P .. "/wow", "WC3_made"):tile(t.tx, t.ty))
    test("... read back: the new water and the dried lake", same_water(t, t2), select(2, same_water(t, t2)))
    e:undo() e:undo()
    e:wow_save()
    local t3 = assert(wowmap.open(P .. "/wow", "WC3_made"):tile(t.tx, t.ty))
    test("undone after the save and saved again: the water as the map was made", same_water(west, t3),
        select(2, same_water(west, t3)))
end
-- }}}

end

os.execute("rm -rf " .. quote(TMP))

print(string.format("\n%s\nTests: %d passed, %d failed, %d skipped", string.rep("=", 50), pass_count,
    test_count - pass_count, skip_count))
os.exit(pass_count == test_count and 0 or 1)

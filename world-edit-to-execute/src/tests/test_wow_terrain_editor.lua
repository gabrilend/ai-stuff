--[[
Tests for issue W10b: the terrain editor on a WoW map's tiles, without
its window (src/editor/wowterrain.lua, and the editor's strokes in
src/editor/terrain.lua): raise, lower, smooth, flatten, paint and holes
as plain Lua on the tiles the W client's reader gives, and the writer
that turns an edited tile back into its file.

The WoW map is made by W02's converter from a made WC3 terrain (no WC3
or WoW install): two tiles with a lake, a tree and a hut, two ground
textures. Every written tile is read back through the W client's own
reader (libwreaders.so; $W_CLIENT_BUILD, a folder holding it and its
wreaders.h); without it only what needs no reading runs, and the rest is
skipped. The project part needs StormLib (a map from assets/).

    luajit src/tests/test_wow_terrain_editor.lua [project folder]
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
-- }}}

-- {{{ No edit: the file again, byte for byte (no reader needed)
section("A tile written without an edit is the file read")
do
    local f = wowmap.files(BUILD, "WC3_made")
    local same = #f.tiles == 2
    for _, e in ipairs(f.tiles) do
        local bytes = read(MAPDIR .. "/" .. e.file)
        same = same and wt.tile_bytes(bytes, { textures = {}, chunks = {} }) == bytes
    end
    test("each of W02's tiles, written again without an edit: byte for byte", same)
    local blocks = wt.walk(read(MAPDIR .. "/" .. f.tiles[1].file))
    local tags = {}
    for _, b in ipairs(blocks) do tags[b.tag] = (tags[b.tag] or 0) + 1 end
    test("its blocks walked: MVER, MHDR, MCIN, MTEX, 256 MCNK", tags.MVER == 1 and tags.MHDR == 1 and tags.MCIN == 1
        and tags.MTEX == 1 and tags.MCNK == 256)
    local bad, why = wt.tile_bytes(read(MAPDIR .. "/" .. f.tiles[1].file):sub(1, 300), { textures = {}, chunks = {} })
    test("a cut-off tile: refused, saying where", bad == nil and why:find("past the file's end", 1, true), why)
end
-- }}}

local lib, lib_why = wowmap.reader()
if not lib then
    skip("the tools and the writer, read back through the W client's reader", lib_why)
else

-- {{{ Read, then written: still the same
section("Read through the reader, then written: the same")
local root0 = copy_map()
local m0 = wowmap.open(root0, "WC3_made")
local tiles = {}
for i, e in ipairs(m0.tiles) do tiles[i] = assert(m0:tile(e.tx, e.ty)) end
local west, east = tiles[1], tiles[2]
do
    local same = true
    for _, t in ipairs(tiles) do
        local bytes = read(m0.folder .. "/" .. t.file)
        same = same and wt.tile_bytes(bytes, t, { big_alpha = m0.big_alpha }) == bytes
    end
    test("each tile, as read, written again: byte for byte", same)
    local written = wt.save(m0)
    test("saving a map with no edit writes nothing", written and #written == 0)
    -- the points' grid against the reader's chunk positions
    local worst = 0
    for _, t in ipairs(tiles) do
        for _, c in ipairs(t.chunks) do
            local x = ORIGIN - (t.ty * 16 + c.iy) * CHUNK
            local y = ORIGIN - (t.tx * 16 + c.ix) * CHUNK
            worst = math.max(worst, math.abs(x - c.x), math.abs(y - c.y))
        end
    end
    test("every chunk where the tools' grid puts it (within 0.01 yards)", worst < 0.01, worst)
end
-- }}}

-- {{{ Normals: W02a's rule, worked out again
section("Normals, worked out again by W02a's rule")
do
    -- make every point known to the tools, then each point's normal against its file
    wt.ground(m0, centre(west, 8, 8))
    wt.ground(m0, centre(east, 8, 8))
    local exact, off1, worse, n = 0, 0, 0, 0
    for _, t in ipairs(tiles) do
        local bytes = read(m0.folder .. "/" .. t.file)
        for _, s in ipairs(chunk_spans(bytes)) do
            local c = t.chunks[s.iy * 16 + s.ix + 1]
            local R, C = (t.ty * 16 + c.iy) * 16, (t.tx * 16 + c.ix) * 16
            for i = 1, 145 do
                local key = (R + wt.POINT_ROW[i]) * 32768 + C + wt.POINT_COLUMN[i]
                local got = wt.normal(m0, key)
                local d = 0
                for a = 1, 3 do
                    local v = bytes:byte(s.mcnr[1] + (i - 1) * 3 + a)
                    if v > 127 then v = v - 256 end
                    d = math.max(d, math.abs(v - got[a]))
                end
                n = n + 1
                if d == 0 then exact = exact + 1 elseif d == 1 then off1 = off1 + 1 else worse = worse + 1 end
            end
        end
    end
    test("every point's normal as W02 wrote it, within 1 (rounding)", worse == 0, string.format("%d exact, %d off by 1, %d worse of %d", exact, off1, worse, n))
    test("... and nearly all exactly", exact >= n * 0.98, string.format("%d of %d", exact, n))
end
-- }}}

-- {{{ The height tools, written and read back
section("Raise, lower, smooth, flatten: written, and read back")
do
    local root, folder = copy_map()
    local m = wowmap.open(root, "WC3_made")
    local t = assert(m:tile(west.tx, west.ty))
    local before = read(folder .. "/" .. t.file)
    local x, y = centre(t, 5, 3)
    local h0 = wt.ground(m, x, y)
    local got = wt.raise(m, x, y, { radius = 20, amount = 5 })
    test("raise: the ground at the middle up by the amount", math.abs(wt.ground(m, x, y) - (h0 + 5)) < 1e-6,
        wt.ground(m, x, y) - h0)
    local hx = wt.ground(m, x - 3 * CELL, y)
    test("... half as much half way to the edge", got and got.points > 0 and got.chunks >= 4 and got.tiles[1] == west.tx .. "_" .. west.ty)
    local far = wt.ground(m, x - 30, y)
    test("... and none past it", far == wt.ground(m0, x - 30, y))
    test("... less toward the edge: by the distance (3 cells out of 20 yards)",
        math.abs((hx - wt.ground(m0, x - 3 * CELL, y)) - 5 * (1 - 3 * CELL / 20)) < 1e-6, hx - wt.ground(m0, x - 3 * CELL, y))
    -- a raise and the same lower: as it was
    wt.raise(m, x + 40, y, { radius = 15, amount = 3 })
    wt.lower(m, x + 40, y, { radius = 15, amount = 3 })
    test("lower undoes the same raise", math.abs(wt.ground(m, x + 40, y) - wt.ground(m0, x + 40, y)) < 1e-6)
    -- smooth a spike
    local sx, sy = centre(t, 10, 2)
    wt.raise(m, sx, sy, { radius = 5, amount = 20 })
    local spike = wt.ground(m, sx, sy) - wt.ground(m, sx, sy - 2 * CELL)
    for _ = 1, 3 do wt.smooth(m, sx, sy, { radius = 10, strength = 1 }) end
    local after = wt.ground(m, sx, sy) - wt.ground(m, sx, sy - 2 * CELL)
    test("smooth: a spike brought down toward its neighbours", after < spike * 0.6, string.format("%.2f -> %.2f", spike, after))
    -- flatten
    local fx, fy = centre(t, 3, 12)
    wt.flatten(m, fx, fy, { radius = 15, height = 40 })
    local flat = true
    for _, d in ipairs({ { 0, 0 }, { 10, 0 }, { -10, 5 }, { 0, -14 } }) do
        flat = flat and math.abs(wt.ground(m, fx + d[1], fy + d[2]) - 40) < 1e-6
    end
    test("flatten: the ground under the brush at the height asked", flat)
    local g = wt.flatten(m, fx + 60, fy, { radius = 6 })
    test("flatten with no height: to the ground at the middle", g and g.points > 0)

    -- the seam between the two tiles: one point, both copies
    local bx, by = ORIGIN - (t.ty * 16 + 6.5) * CHUNK, ORIGIN - (t.tx + 1) * TILE
    wt.raise(m, bx, by, { radius = 12, amount = 4 })
    local e = assert(m:tile(east.tx, east.ty))
    local wc, ec = t.chunks[6 * 16 + 15 + 1], e.chunks[6 * 16 + 0 + 1]
    local joined = true
    for r = 0, 8 do
        joined = joined and math.abs((wc.z + wc.heights[r * 17 + 9]) - (ec.z + ec.heights[r * 17 + 1])) < 1e-6
    end
    test("a raise on the tiles' edge: both tiles' copies of each point moved alike", joined)

    -- written over the files, read back
    local written, why = wt.save(m)
    test("the two edited tiles written, and the far view (WDL, issue W10c)", written and #written == 3
        and written[3] == "WC3_made.wdl", why or (written and table.concat(written, ", ")))
    local now = read(folder .. "/" .. t.file)
    local spans = {}
    for _, s in ipairs(chunk_spans(before)) do spans[#spans + 1] = s.mcvt spans[#spans + 1] = s.mcnr end
    test("... in place: the same size, nothing changed but heights and normals", differ_outside(before, now, spans) == 0,
        differ_outside(before, now, spans))
    test("... and it's no longer dirty", t.dirty == nil and wt.edited(m)[1] == nil)
    local again = wowmap.open(root, "WC3_made")
    local t2 = assert(again:tile(t.tx, t.ty))
    local worst = 0
    for k = 1, 256 do
        for i = 1, 145 do worst = math.max(worst, math.abs(t2.chunks[k].heights[i] - t.chunks[k].heights[i])) end
    end
    test("read back through the reader: every height as edited (float precision)", worst < 1e-3, worst)
    local e2 = assert(again:tile(e.tx, e.ty))
    test("... the east tile's edge too", math.abs(e2.chunks[6 * 16 + 1].heights[1] - e.chunks[6 * 16 + 1].heights[1]) < 1e-3)
    test("... its placements and water as they were", #e2.buildings == #east.buildings and #t2.doodads == #west.doodads
        and #t2.liquids == #west.liquids and t2.doodads[1].uid == west.doodads[1].uid)
    -- a new normal where the ground changed, the old one where it didn't
    local nb = chunk_spans(now)
    local changed_n, kept_far = 0, true
    local old_spans = chunk_spans(before)
    for n, s in ipairs(nb) do
        local a, b = before:sub(old_spans[n].mcnr[1] + 1, old_spans[n].mcnr[2]), now:sub(s.mcnr[1] + 1, s.mcnr[2])
        if a ~= b then changed_n = changed_n + 1 end
        if s.ix == 15 and s.iy == 15 and a ~= b then kept_far = false end
    end
    test("normals changed where the ground did, and not far away", changed_n > 0 and kept_far, changed_n)
end
-- }}}

-- {{{ Holes
section("Holes: cut, filled, written, read back")
do
    local root, folder = copy_map()
    local m = wowmap.open(root, "WC3_made")
    local t = assert(m:tile(west.tx, west.ty))
    local before = read(folder .. "/" .. t.file)
    -- the chunk (4, 2)'s hole square at its row 1, column 2: cells 2-3 down, 4-5 across
    local x = ORIGIN - (t.ty * 16 + 2) * CHUNK - 2.5 * CELL
    local y = ORIGIN - (t.tx * 16 + 4) * CHUNK - 4.5 * CELL
    local got = wt.holes(m, x, y)
    local c = t.chunks[2 * 16 + 4 + 1]
    test("a hole cut: its bit (row * 4 + column, as the W client draws it)", c.holes == 2 ^ (1 * 4 + 2) and got.points == 1,
        c.holes)
    test("cutting it again changes nothing", wt.holes(m, x, y).points == 0)
    local wide = wt.holes(m, ORIGIN - (t.ty * 16 + 9) * CHUNK, ORIGIN - (t.tx * 16 + 9) * CHUNK, { radius = 9 })
    test("a wider brush: every square with its middle under it, across chunks", wide.points >= 4 and wide.chunks == 4,
        wide.points .. " squares, " .. wide.chunks .. " chunks")
    wt.save(m)
    local now = read(folder .. "/" .. t.file)
    local spans = {}
    for _, s in ipairs(chunk_spans(before)) do spans[#spans + 1] = { s.at + 8 + 60, s.at + 8 + 62 } end
    test("written in place: only the chunks' hole bytes changed", differ_outside(before, now, spans) == 0)
    local t2 = assert(wowmap.open(root, "WC3_made"):tile(t.tx, t.ty))
    local same = true
    for k = 1, 256 do same = same and t2.chunks[k].holes == t.chunks[k].holes end
    test("read back: every chunk's holes as cut", same and t2.chunks[2 * 16 + 5].holes ~= 0)
    wt.holes(m, x, y, { on = false })
    test("filled again", c.holes == 0)
end
-- }}}

-- {{{ Paint
section("Paint: blend maps, new layers, new textures")
local function first_chunk(t, pred)
    for _, c in ipairs(t.chunks) do if pred(c) then return c end end
end
do
    local root, folder = copy_map()
    local m = wowmap.open(root, "WC3_made")
    local t = assert(m:tile(west.tx, west.ty))
    local textures_were = #t.textures
    local one = first_chunk(t, function(c) return #c.layers == 1 and c.iy == 2 and c.ix >= 2 and c.ix <= 8 end)
    local other = t.textures[one.layers[1].texture_index == 1 and 2 or 1]
    test("the made map: two textures, a chunk with one layer", textures_were == 2 and one ~= nil)
    local x, y = centre(t, one.ix, one.iy)
    local got = wt.paint(m, x, y, { radius = 10, texture = other, strength = 1 })
    test("painted: the chunk has a second layer, that texture", #one.layers == 2 and one.layers[2].texture == other
        and got.chunks >= 1)
    test("... nearly fully at the middle (the brush falls off), none past the edge",
        one.layers[2].alpha:byte(32 * 64 + 32 + 1) >= 240 and one.layers[2].alpha:byte(1) == 0,
        one.layers[2].alpha:byte(32 * 64 + 32 + 1))
    local x2 = x - 0.4 * CHUNK
    wt.paint(m, x2, y, { radius = 6, texture = other, strength = 0.5 })
    -- the painted layer's point at about (x2, y) is half way up
    local pr = math.floor((ORIGIN - (t.ty * 16 + one.iy) * CHUNK - x2) / (CHUNK / 64))
    local v = one.layers[2].alpha:byte(pr * 64 + 32 + 1)
    test("half strength: about half covered", v > 90 and v < 165, v)
    -- the first layer painted back: the layer above it covers less
    wt.paint(m, x, y, { radius = 4, texture = one.layers[1].texture, strength = 1, falloff = "flat" })
    test("painting the first texture: the layer above it uncovered there", one.layers[2].alpha:byte(32 * 64 + 32 + 1) == 0)

    -- a texture the tile hasn't
    local two = first_chunk(t, function(c) return #c.layers == 1 and c.iy == 10 and c.ix == 4 end)
    local nx, ny = centre(t, two.ix, two.iy)
    local NEW = "Tileset\\Test\\NewGround.blp"
    wt.paint(m, nx, ny, { radius = 8, texture = NEW, falloff = "flat" })
    test("a new texture: added to the tile's list, and a layer of it", #t.textures == 3 and t.textures[3] == NEW
        and two.layers[2].texture_index == 3)

    -- four layers, then a fifth texture
    local cx, cy = centre(t, 12, 12)
    local full = t.chunks[12 * 16 + 12 + 1]
    for k = 1, 4 do wt.paint(m, cx, cy, { radius = 6, texture = "Tileset\\Test\\T" .. k .. ".blp" }) end
    test("textures until the chunk has four layers; the next has no room, said", #full.layers == 4
        and #(wt.paint(m, cx, cy, { radius = 6, texture = "Tileset\\Test\\T5.blp" }).full) >= 1, #full.layers)
    wt.paint(m, cx, cy, { radius = 30, texture = full.layers[1].texture, falloff = "flat" })
    local g5 = wt.paint(m, cx, cy, { radius = 6, texture = "Tileset\\Test\\T5.blp" })
    test("the first painted over the whole chunk: the fifth takes an uncovered layer's place", #g5.full == 0
        and full.layers[2].texture == "Tileset\\Test\\T5.blp", #g5.full)

    local before = read(folder .. "/" .. t.file)
    local written, why = wt.save(m)
    test("written: the tile grew (layers, maps, names), its blocks moved along", written and #written == 1
        and #read(folder .. "/" .. t.file) > #before, why)
    local again = wowmap.open(root, "WC3_made")
    local t2, rwhy = again:tile(t.tx, t.ty)
    test("read back through the reader", t2 ~= nil, rwhy)
    t2 = t2 or { chunks = {}, textures = {}, doodads = {}, liquids = {} }
    local same = #t2.textures == #t.textures
    for k = 1, 256 do
        local a, b = t.chunks[k], t2.chunks[k]
        if not b or #a.layers ~= #b.layers then same = false break end
        for l = 1, #a.layers do
            same = same and a.layers[l].texture == b.layers[l].texture and a.layers[l].alpha == b.layers[l].alpha
        end
        for i = 1, 145 do same = same and a.heights[i] == b.heights[i] end
        same = same and a.holes == b.holes and a.shadow == b.shadow
    end
    test("... every chunk's layers, textures and blend maps as painted, heights and holes as they were", same)
    test("... the new names in the tile's list", t2.textures[3] == NEW and t2.textures[#t2.textures] == "Tileset\\Test\\T5.blp")
    test("... its placements and water still found (MHDR's and MCIN's offsets followed)",
        #t2.doodads == #west.doodads and t2.doodads[1] and t2.doodads[1].model == west.doodads[1].model
        and #t2.liquids == #west.liquids and t2.liquids[1] and t2.liquids[1].height[1] == west.liquids[1].height[1])
    -- the low-quality map in the painted chunk's header
    local now = read(folder .. "/" .. t.file)
    local low
    for _, s in ipairs(chunk_spans(now)) do
        if s.ix == two.ix and s.iy == two.iy then low = now:sub(s.at + 8 + 64 + 1, s.at + 8 + 80) end
    end
    local nonzero = false
    for p = 1, 16 do if low:byte(p) ~= 0 then nonzero = true end end
    test("the painted chunk's low-quality map shows its new layer", nonzero)
    test("a texture with no path: refused", wt.paint(m, x, y, {}) == nil)
end
-- }}}

-- {{{ 4-bit blend maps
section("A map whose WDT says 4-bit blend maps")
do
    local root, folder = copy_map()
    local m = wowmap.open(root, "WC3_made")
    local t = assert(m:tile(west.tx, west.ty))
    m.big_alpha = false                      -- as a 4-bit map's WDT would say
    local n = 0
    for _, c in ipairs(t.chunks) do
        if #c.layers > 1 then c.dirty = { layers = true } t.dirty = true n = n + 1 end
    end
    local written = wt.save(m)
    test("every layered chunk written again, 4 bits a point", written and #written == 1 and n > 0, n)
    local again = wowmap.open(root, "WC3_made")
    again:reader()
    again.big_alpha = false
    local t2, why = again:tile(t.tx, t.ty)
    local same = t2 ~= nil
    if t2 then
        for k = 1, 256 do
            local a, b = t.chunks[k], t2.chunks[k]
            for l = 2, #a.layers do
                for p = 1, 4096, 37 do
                    same = same and b.layers[l].alpha:byte(p) == math.floor(a.layers[l].alpha:byte(p) / 17 + 0.5) * 17
                end
            end
        end
    end
    test("read back as 4-bit: each point the nearest of 16 steps", same, why)
end
-- }}}

-- {{{ A chunk laid out as the original game's are
section("A chunk the way the original's files have it: packed maps, MCNR's padding outside it")
do
    local root, folder = copy_map()
    local m = wowmap.open(root, "WC3_made")
    local t = assert(m:tile(west.tx, west.ty))
    local file = folder .. "/" .. t.file
    local bytes = read(file)
    -- a chunk with two layers: its map packed in runs, MCAL's own size
    -- left as it was (the header's smaller), MCNR's size 435
    local target
    for _, s in ipairs(chunk_spans(bytes)) do
        local c = t.chunks[s.iy * 16 + s.ix + 1]
        if #c.layers == 2 and not target then target = s end
    end
    local h = target.at + 8
    local mcly, mcal, mcnr = target.at + u32(bytes, h + 28), target.at + u32(bytes, h + 36), target.at + u32(bytes, h + 24)
    local alpha = bytes:sub(mcal + 8 + 1, mcal + 8 + 4096)
    local runs, p = {}, 1
    while p <= 4096 do
        local b, n = alpha:byte(p), 1
        while p + n <= 4096 and n < 127 and alpha:byte(p + n) == b do n = n + 1 end
        runs[#runs + 1] = string.char(0x80 + n, b)
        p = p + n
    end
    local packed = table.concat(runs)
    bytes = put(bytes, mcal + 8, packed .. string.rep("\0", 4096 - #packed))
    bytes = put(bytes, mcly + 8 + 16 + 4, le32(0x100 + 0x200))
    bytes = put(bytes, h + 40, le32(8 + #packed))
    bytes = put(bytes, mcnr + 4, le32(435))
    write(file, bytes)
    local m2 = wowmap.open(root, "WC3_made")
    local t2, why = m2:tile(t.tx, t.ty)
    local c2 = t2 and t2.chunks[target.iy * 16 + target.ix + 1]
    test("the reader reads it: the same blend map, from " .. #packed .. " packed bytes", c2 and c2.layers[2].alpha == alpha, why)
    test("written without an edit: byte for byte", wt.tile_bytes(bytes, t2, { big_alpha = true }) == bytes)
    local x, y = centre(t2, target.ix, target.iy)
    wt.raise(m2, x, y, { radius = 6, amount = 2 })
    local raised = wt.tile_bytes(bytes, t2, { big_alpha = true })
    local spans = {}
    for _, s in ipairs(chunk_spans(bytes)) do spans[#spans + 1] = s.mcvt spans[#spans + 1] = s.mcnr end
    test("raised: its packed map and the rest kept as they were", raised and differ_outside(bytes, raised, spans) == 0)
    wt.paint(m2, x, y, { radius = 6, texture = c2.layers[1].texture })
    local ok, werr = wt.save(m2)
    local t3 = ok and wowmap.open(root, "WC3_made"):tile(t.tx, t.ty)
    local c3 = t3 and t3.chunks[target.iy * 16 + target.ix + 1]
    test("painted: written plain, and the reader agrees", c3 and c3.layers[2].alpha == c2.layers[2].alpha
        and math.abs(c3.heights[73] - c2.heights[73]) < 1e-3, werr)
    local now = read(file)
    local s3
    for _, s in ipairs(chunk_spans(now)) do if s.ix == target.ix and s.iy == target.iy then s3 = s end end
    local ly = s3.at + u32(now, s3.at + 8 + 28)
    test("... its layer no longer marked packed", bit.band(u32(now, ly + 8 + 16 + 4), 0x200) == 0)
    -- a header offset that points into the layers: no move is made past it
    local odd = put(read(file), s3.at + 8 + 88, le32(u32(now, s3.at + 8 + 28) + 4))
    local t4 = wowmap.open(root, "WC3_made")
    local tt = assert(t4:tile(t.tx, t.ty))
    wt.paint(t4, x, y, { radius = 3, texture = "Tileset\\Test\\Odd.blp" })
    local nope, nwhy = wt.tile_bytes(odd, tt, { big_alpha = true })
    test("a header offset inside the moved blocks: refused, saying which", nope == nil
        and (nwhy or ""):find("header byte 88", 1, true), nwhy)
end
-- }}}

-- {{{ The editor's strokes (a stand-in editor: no WC3 map needed)
section("The editor's terrain tools on a WoW map")
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
                             terrain_touched = {}, tool = "raise",
                             brush = { size = 2, strength = 32, texture = 0 } }, E)
    test("holes aren't a WC3 map's tool", not e:is_terrain_tool("hole"))
    local m, why = e:wow_edit("WC3_made")
    test("a WoW map of the project picked for the terrain tools", m ~= nil, why)
    test("... and now hole is a terrain tool", e:is_terrain_tool("hole"))
    local t = assert(m:tile(west.tx, west.ty))
    local x, y = centre(t, 6, 6)
    local h0 = wt.ground(m, x, y)
    e.brush.wow_radius, e.brush.wow_amount = 12, 3
    e:stroke_begin("raise", x, y)
    e:stroke(x, y)
    e:stroke(x, y)
    local name = e:stroke_end()
    test("a stroke: the same calls as on a WC3 map, twice raised", math.abs(wt.ground(m, x, y) - (h0 + 6)) < 1e-6
        and name == "Raise (WoW map WC3_made)", name)
    e:undo()
    local clean = t.dirty == nil
    for _, c in ipairs(t.chunks) do if c.dirty or c.normals then clean = false end end
    test("undone: the ground as it was, nothing left to write", math.abs(wt.ground(m, x, y) - h0) < 1e-9 and clean)
    e:redo()
    test("redone", math.abs(wt.ground(m, x, y) - (h0 + 6)) < 1e-6 and t.dirty == true)
    -- paint a new texture, undone and redone
    e.tool = "paint"
    e.brush.wow_texture, e.brush.wow_paint = "Tileset\\Test\\Stroke.blp", 1
    local n_tex = #t.textures
    e:stroke_begin(nil, x, y) e:stroke(x, y) e:stroke_end()
    test("paint: a stroke of a new texture", #t.textures == n_tex + 1)
    e:undo()
    test("... undone: the texture's name gone from the tile again", #t.textures == n_tex)
    e:redo()
    test("... redone: back", #t.textures == n_tex + 1 and t.textures[#t.textures] == "Tileset\\Test\\Stroke.blp")
    e.tool = "hole"
    e.brush.wow_radius = 0
    e:stroke_begin(nil, x, y) e:stroke(x, y) e:stroke_end()
    local c = t.chunks[6 * 16 + 6 + 1]
    test("hole: cut under the stroke", c.holes ~= 0)
    test("a WC3-only tool on a WoW map: refused, said", not e:stroke_begin("cliff_up", x, y)
        and e.messages[#e.messages]:find("Not on a WoW map", 1, true))
    local written, swhy = e:wow_save()
    test("saved: the edited tile over its file in the project (and its far view, W10c)", written
        and #written == 2 and written[1] == "WC3_made/WC3_made.wdl" and written[2] == "WC3_made/" .. t.file, swhy)
    local t2 = assert(wowmap.open(P .. "/wow", "WC3_made"):tile(t.tx, t.ty))
    test("... read back: raised, painted, holed", math.abs(t2.chunks[6 * 16 + 7].heights[73] - c.heights[73]) < 1e-3
        and t2.chunks[6 * 16 + 7].holes == c.holes and t2.textures[#t2.textures] == "Tileset\\Test\\Stroke.blp")
    -- undo after the save: written whole again
    e:undo() e:undo() e:undo()
    test("undone after the save: the ground back, the chunks to be written again", math.abs(wt.ground(m, x, y) - h0) < 1e-6
        and t.dirty == true)
    e:wow_save()
    local t3 = assert(wowmap.open(P .. "/wow", "WC3_made"):tile(t.tx, t.ty))
    local worst = 0
    for k = 1, 256 do for i = 1, 145 do worst = math.max(worst, math.abs(t3.chunks[k].heights[i] - west.chunks[k].heights[i])) end end
    test("... saved again: every height as the map was made, no holes", worst < 1e-3 and t3.chunks[6 * 16 + 7].holes == 0, worst)
    e:wow_edit(nil)
    test("back to the WC3 map: holes aren't a tool there", not e:is_terrain_tool("hole") and e.wow_editing == nil)
end
-- }}}

-- {{{ A map project, through the editor's own save
section("A map project: the editor's save writes the WoW layer's edits")
local stormlib = pcall(function() require("mpq").open(DIR .. "assets/Daow4.4.w3x"):close() end)
if not stormlib then
    skip("the editor's save of a project's WoW layer", "no StormLib to export a WC3 map")
else
    local P = TMP .. "/proj"
    local ok, rep = mapfile.export(DIR .. "assets/Daow4.4.w3x", P)
    test("a WC3 map exported as a project", ok, rep)
    test("the WoW map added to it", mapfile.add_wow(P, BUILD, "WC3_made"))
    local editor = require("editor")
    local E, eerr = editor.open(P)
    test("the editor opens the project", E ~= nil, eerr)
    if E then
        test("hole and unhole are tools of the editor", E:set_tool("hole") and E:set_tool("raise"))
        test("... not terrain tools on its WC3 map", not E:is_terrain_tool("hole") and not E:stroke_begin("hole", 0, 0))
        local m = assert(E:wow_edit("WC3_made"))
        local t = assert(m:tile(west.tx, west.ty))
        local x, y = centre(t, 4, 4)
        local h0 = wt.ground(m, x, y)
        E.brush.wow_radius, E.brush.wow_amount = 10, 2
        E:stroke_begin("raise", x, y) E:stroke(x, y) E:stroke_end()
        local sok, serr = E:save()
        test("the project saved", sok, serr)
        local probs = mapfile.validate(P, "wow", { read = true })
        local said = false
        for _, p in ipairs(probs) do if p.message:find("changed since it was added", 1, true) then said = true end end
        test("validation: the tile changed since it was added (information)", said)
        local E2 = editor.open(P)
        local m2 = E2 and E2:wow_map("WC3_made")
        local h2 = m2 and wt.ground(m2, x, y)
        test("opened again: the WoW ground as edited", h2 and math.abs(h2 - (h0 + 2)) < 1e-3, h2 and (h2 - h0))
    end
end
-- }}}

end

os.execute("rm -rf " .. quote(TMP))

print(string.format("\n%s\nTests: %d passed, %d failed, %d skipped", string.rep("=", 50), pass_count,
    test_count - pass_count, skip_count))
os.exit(pass_count == test_count and 0 or 1)

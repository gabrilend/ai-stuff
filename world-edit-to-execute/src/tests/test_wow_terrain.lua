--[[
Tests for the terrain-to-ADT writer (Issue W02a): where a WC3 map lands in
a WoW map, heights, normals, texture layers and their blend maps, the
texture reduction rule (folds counted, strict mode), unmapped ground types,
water, the WDT and WDL, and the converter's command.

Made grounds (small terrains built here) and the maps in assets/ (the
smallest DAoW map first, W02's acceptance; WOW_TERRAIN_ALL=1 for every
map) are converted, and every written ADT, the WDT and the WDL are read
back through the W client's own reader (libwreaders.so, its src/020-adt.c)
by LuaJIT's FFI. The ground there must match the WC3 height field within
0.5 yards at sampled points (W02's acceptance; here every outer vertex and
every cell centre is sampled).

The reader library is found in $W_CLIENT_BUILD (a folder holding
libwreaders.so and the wreaders.h its scripts/build writes), else the W
client's usual build folder. Without it those checks are skipped and
counted as skipped. Real maps need StormLib (src/mpq/stormlib.lua finds it,
or $STORMLIB_PATH).

    luajit src/tests/test_wow_terrain.lua [project folder]
]]

-- {{{ Setup paths
-- the project folder: the argument, else from this file's path ("" when
-- run as src/tests/..., from the project folder)
local DIR = arg[1] or (debug.getinfo(1, "S").source:match("^@(.-)/?src/tests/[^/]*$"))
    or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if DIR == "" then DIR = "." end
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local ffi = require("ffi")
local w3e = require("parsers.w3e")
local coords = require("wowbuild.coords")
local wterrain = require("wowbuild.terrain")
local adt = require("wowbuild.adt")
local wowbuild = require("wowbuild")
-- }}}

-- {{{ Test infrastructure
local test_count, pass_count, skip_count = 0, 0, 0

local function test(name, condition, msg)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name .. (msg and ": " .. msg or ""))
    end
end

local function skip(name, why)
    skip_count = skip_count + 1
    print("  [SKIP] " .. name .. ": " .. why)
end

local function test_section(name)
    print("\n=== " .. name .. " ===")
end

local function u32(s, at) local a, b, c, d = s:byte(at + 1, at + 4) return a + b * 256 + c * 65536 + d * 16777216 end
local function tag_at(s, at) return s:sub(at + 1, at + 4):reverse() end
local function quote(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end
local TMP = os.tmpname()
os.remove(TMP)
os.execute("mkdir -p " .. quote(TMP))
-- }}}

-- {{{ The W client's reader library
local W, WHY
do
    local build = os.getenv("W_CLIENT_BUILD") or "/mnt/kaun/custom-client/tmp/tmp/build"
    local f = io.open(build .. "/wreaders.h", "r")
    if f then
        local ok, err = pcall(function()
            ffi.cdef(f:read("*a"))
            W = ffi.load(build .. "/libwreaders.so")
        end)
        if not ok then W = nil print("(the W client's reader library didn't load: " .. tostring(err) .. ")") end
        f:close()
    end
    if W then WHY = ffi.new("WWhy") print("(the W client's reader: " .. build .. ")")
    else print("(no W client reader library in " .. build .. "; its checks are skipped)") end
end
local wtile = W and ffi.new("AdtTile")
local wwdl = W and ffi.new("AdtWdl")
local function why_text() return ffi.string(WHY.text) end
-- }}}

-- {{{ made grounds: a terrain table as parsers.w3e makes, from fn(i, j) -> fields
local function made(w, h, ground, fn, tileset)
    local t = setmetatable({
        width = w, height = h, offset_x = -64 * (w - 1), offset_y = -64 * (h - 1),
        tileset_code = tileset or "L", ground_tilesets = ground, cliff_tilesets = {}, tilepoints = {},
    }, w3e.Terrain)
    for j = 0, h - 1 do
        t.tilepoints[j] = {}
        for i = 0, w - 1 do
            local tp = { height = 0, layer_height = 2, ground_texture = 0, texture_details = 0,
                         has_water = false, water_level = 0, is_blight = false, is_ramp = false }
            if fn then
                for k, v in pairs(fn(i, j) or {}) do tp[k] = v end
            end
            t.tilepoints[j][i] = tp
        end
    end
    return t
end
-- }}}

-- {{{ check_against_reader
-- Converts a terrain tile by tile and reads each ADT back through the W
-- client's reader: positions, every outer vertex and every cell centre
-- against the WC3 height field, layers, textures, blend maps, water. Returns
-- the job, the tiles' byte strings and a summary of what it found.
local function convert_and_read(terrain, opts)
    local job = wterrain.prepare(terrain, opts)
    local L = job.layout
    local out = { tiles = {}, bytes = {}, max_err = 0, samples = 0, read_ok = 0, read_fail = {},
                  pos_bad = 0, layer_bad = 0, tex_bad = 0, alpha_bad = 0, water_bad = 0, liquids = 0, written_liquids = 0 }
    local function wc3_z(i, j) return w3e.ground_z(terrain.tilepoints[j][i]) * coords.YARDS_PER_UNIT end
    for _, t in ipairs(L:tiles()) do
        local tile = job:tile(t)
        local bytes = adt.tile_bytes(tile)
        out.tiles[#out.tiles + 1] = tile
        out.bytes[#out.bytes + 1] = bytes
        for k = 0, 255 do if tile.chunks[k].liquid then out.written_liquids = out.written_liquids + 1 end end
        if W then
            local buf = ffi.new("unsigned char[?]", #bytes)
            ffi.copy(buf, bytes, #bytes)
            if W.adt_read(buf, #bytes, 1, wtile, WHY) ~= 0 then
                out.read_fail[#out.read_fail + 1] = string.format("%d_%d: %s", t.tx, t.ty, why_text())
            else
                out.read_ok = out.read_ok + 1
                for k = 0, 255 do
                    local c, mine = wtile.chunks[k], tile.chunks[k]
                    local R0, C0 = t.by * 128 + c.iy * 8, t.bx * 128 + c.ix * 8
                    local X, Y = L:vertex_world(R0, C0)
                    if c.ix ~= k % 16 or c.iy ~= math.floor(k / 16) or math.abs(c.x - X) > 0.01 or math.abs(c.y - Y) > 0.01 then
                        out.pos_bad = out.pos_bad + 1
                    end
                    -- outer vertices against the tile points; cell centres against the field between them
                    for r = 0, 8 do
                        for col = 0, 8 do
                            local i, j = L:tilepoint(R0 + r, C0 + col)
                            local e = math.abs(c.z + c.heights[r * 17 + col] - wc3_z(i, j))
                            if e > out.max_err then out.max_err = e end
                            out.samples = out.samples + 1
                        end
                    end
                    for r = 0, 7 do
                        for col = 0, 7 do
                            local R, C = R0 + r, C0 + col
                            if R + 1 <= L.H - 1 and C + 1 <= L.W - 1 then        -- inside the WC3 map
                                local cx, cy = L:vertex_world(R + 0.5, C + 0.5)
                                local wx, wy = L:to_wc3(cx, cy)
                                local e = math.abs(c.z + c.heights[r * 17 + 9 + col] - job:height_at(wx, wy))
                                if e > out.max_err then out.max_err = e end
                                out.samples = out.samples + 1
                            end
                        end
                    end
                    if c.nlayers ~= #mine.layers then out.layer_bad = out.layer_bad + 1 end
                    for l = 0, math.min(c.nlayers, #mine.layers) - 1 do
                        if ffi.string(wtile.textures[c.tex[l]]) ~= tile.textures[mine.layers[l + 1].tex + 1] then
                            out.tex_bad = out.tex_bad + 1
                        end
                        local want = l == 0 and string.rep("\255", 4096) or mine.layers[l + 1].alpha
                        if ffi.string(c.alpha[l], 4096) ~= want then out.alpha_bad = out.alpha_bad + 1 end
                    end
                end
                -- water: every written layer comes back, with its cells and heights
                out.liquids = out.liquids + wtile.nliquids
                for n = 0, wtile.nliquids - 1 do
                    local q = wtile.liquids[n]
                    local mine = tile.chunks[q.chunk].liquid
                    local bad = not mine or q.kind ~= mine.kind or q.col ~= mine.col or q.row ~= mine.row
                        or q.w ~= mine.w or q.h ~= mine.h
                    if not bad then
                        for r = 0, 7 do for col = 0, 7 do
                            if q.wet[r][col] ~= mine.wet[r][col] then bad = true end
                        end end
                        local v = 0
                        for r = 0, mine.h do for col = 0, mine.w do
                            v = v + 1
                            if math.abs(q.height[mine.row + r][mine.col + col] - mine.heights[v]) > 1e-3 then bad = true end
                            if q.depth[mine.row + r][mine.col + col] ~= mine.depths[v] then bad = true end
                        end end
                    end
                    if bad then out.water_bad = out.water_bad + 1 end
                end
                W.adt_free(wtile)
            end
        end
    end
    return job, out
end

local function reader_checks(label, out, ntiles)
    if not W then skip(label .. ": the W client's reader", "no library") return end
    test(label .. ": the W client's reader reads all " .. ntiles .. " ADTs", out.read_ok == ntiles,
        table.concat(out.read_fail, "; "))
    test(label .. ": chunk indices and positions", out.pos_bad == 0, out.pos_bad .. " chunks off")
    test(label .. ": ground within 0.5 yd of the WC3 height field (" .. out.samples .. " points)",
        out.max_err <= 0.5 and out.samples > 0, string.format("worst %.4f yd", out.max_err))
    test(label .. ": layer counts as written", out.layer_bad == 0, out.layer_bad .. " chunks differ")
    test(label .. ": each layer's texture path", out.tex_bad == 0, out.tex_bad .. " layers differ")
    test(label .. ": blend maps byte for byte", out.alpha_bad == 0, out.alpha_bad .. " maps differ")
    test(label .. ": water layers (" .. out.written_liquids .. " written)",
        out.liquids == out.written_liquids and out.water_bad == 0,
        string.format("read %d, %d differ", out.liquids, out.water_bad))
end
-- }}}

-- {{{ structure: the blocks other readers walk (Noggit, AzerothCore's extractor)
local function structure_problems(s)
    local p = {}
    local order, at = {}, 0
    while at + 8 <= #s do
        local tag = tag_at(s, at)
        order[#order + 1] = { tag = tag, at = at }
        at = at + 8 + u32(s, at + 4)
    end
    if at ~= #s then p[#p + 1] = "blocks don't end at the file's end" end
    local want = { "MVER", "MHDR", "MCIN", "MTEX", "MMDX", "MMID", "MWMO", "MWID", "MDDF", "MODF" }
    for n, tag in ipairs(want) do
        if not order[n] or order[n].tag ~= tag then p[#p + 1] = "block " .. n .. " is not " .. tag end
    end
    if u32(s, 8) ~= 18 then p[#p + 1] = "version not 18" end
    -- MHDR's offsets name each block's tag, from MHDR's data
    local names = { [1] = "MCIN", [2] = "MTEX", [3] = "MMDX", [4] = "MMID", [5] = "MWMO", [6] = "MWID", [7] = "MDDF", [8] = "MODF", [10] = "MH2O" }
    for n, tag in pairs(names) do
        local off = u32(s, 20 + n * 4)
        if off ~= 0 and tag_at(s, 20 + off) ~= tag then p[#p + 1] = "MHDR's " .. tag .. " offset points elsewhere" end
        if off == 0 and tag ~= "MH2O" then p[#p + 1] = "MHDR has no " .. tag end
    end
    -- MCIN: 256 entries, each at an MCNK of that size, in order
    local mcin = 20 + u32(s, 24)
    local chunks = 0
    for k = 0, 255 do
        local off, size = u32(s, mcin + 8 + k * 16), u32(s, mcin + 12 + k * 16)
        if tag_at(s, off) ~= "MCNK" or u32(s, off + 4) + 8 ~= size then
            p[#p + 1] = "MCIN entry " .. k .. " doesn't name its MCNK"
            break
        end
        local h = off + 8
        if u32(s, h + 4) ~= k % 16 or u32(s, h + 8) ~= math.floor(k / 16) then p[#p + 1] = "MCNK " .. k .. " out of order" end
        for _, sub in ipairs({ { 20, "MCVT", 580 }, { 24, "MCNR", 448 }, { 28, "MCLY" }, { 32, "MCRF" }, { 36, "MCAL" }, { 88, "MCSE" }, { 96, "MCLQ" } }) do
            local so = off + u32(s, h + sub[1])
            if tag_at(s, so) ~= sub[2] then p[#p + 1] = "MCNK " .. k .. ": no " .. sub[2] .. " where its header says" end
            if sub[3] and u32(s, so + 4) ~= sub[3] then p[#p + 1] = "MCNK " .. k .. ": " .. sub[2] .. " is not " .. sub[3] .. " bytes" end
        end
        local mcly = off + u32(s, h + 28)
        if u32(s, mcly + 4) ~= u32(s, h + 12) * 16 then p[#p + 1] = "MCNK " .. k .. ": MCLY size and layer count disagree" end
        if u32(s, h + 40) ~= 8 + (u32(s, h + 12) - 1) * 4096 then p[#p + 1] = "MCNK " .. k .. ": MCAL size is not 4096 a layer" end
        -- the subblocks follow each other to the chunk's end
        local sub, last = off + 8 + 128, off + 8 + u32(s, off + 4)
        while sub < last do sub = sub + 8 + u32(s, sub + 4) end
        if sub ~= last then p[#p + 1] = "MCNK " .. k .. ": its subblocks don't end at its end" end
        chunks = chunks + 1
        if #p > 5 then break end
    end
    return p, chunks
end
-- }}}

-- {{{ Where the map lands
test_section("Where the map lands")
do
    local L = coords.layout({ width = 257, height = 257, offset_x = -16384, offset_y = -16384 })
    test("a 256-tile map is 2 x 2 ADT tiles", L.ntx == 2 and L.nty == 2)
    test("centred: the first tile is 31_31", L.tx0 == 31 and L.ty0 == 31)
    local x, y, z = L:to_wow(-16384, 16384, 128)
    test("the north-west tile point is the north-west corner of tile 31_31",
        math.abs(x - (coords.ORIGIN - 31 * coords.TILE)) < 1e-6 and math.abs(y - (coords.ORIGIN - 31 * coords.TILE)) < 1e-6)
    test("128 WC3 units up are one cell, 4.1667 yd", math.abs(z - 4.1666667) < 1e-5)
    local x2, y2 = L:to_wow(-16384 + 128, 16384)
    test("one tile east is one cell west-to-east (world y falls by 4.1667)", math.abs((y - y2) - coords.CELL) < 1e-6 and math.abs(x - x2) < 1e-9)
    local x3 = L:to_wow(-16384, 16384 - 128)
    test("one tile south is one cell south (world x falls by 4.1667)", math.abs((x - x3) - coords.CELL) < 1e-6)
    local wx, wy = L:to_wc3(L:to_wow(1234.5, -987.25, 0))
    test("to_wc3 undoes to_wow", math.abs(wx - 1234.5) < 1e-6 and math.abs(wy + 987.25) < 1e-6)
    local i, j = L:tilepoint(0, 0)
    test("block vertex (0, 0) is tile point (0, H-1), the north-west one", i == 0 and j == 256)
    i, j = L:tilepoint(300, -5)
    test("past the map, tile points clamp to its edge", i == 0 and j == 0)
    local one = coords.layout({ width = 33, height = 17, offset_x = 0, offset_y = 0 })
    test("a small map is one tile, 32_32, starting at world (0, 0)", one.ntx == 1 and one.nty == 1 and one.tx0 == 32
        and math.abs(select(1, one:vertex_world(0, 0))) < 1e-6)
    local big = coords.layout({ width = 481, height = 481, offset_x = 0, offset_y = 0 })
    test("a 480-tile map is 4 x 4 tiles from 30_30", big.ntx == 4 and big.tx0 == 30 and big.ty0 == 30)
end
-- }}}

-- {{{ Made grounds
test_section("Heights and normals")
do
    -- rises 64 units a tile to the east; cliff level 3 in the north-east quarter
    local t = made(33, 33, { "Ldrt" }, function(i, j)
        return { height = 64 * i, layer_height = (i >= 24 and j >= 24) and 3 or 2 }
    end)
    local job, out = convert_and_read(t)
    local tile = out.tiles[1]
    local c = tile.chunks[0]
    local function abs(n) return c.z + c.heights[n] end
    -- chunk (0, 0): its NW vertex is tile point (0, 32)
    test("outer vertex: the tile point's height in yards", math.abs(abs(1) - 0) < 1e-6 and math.abs(abs(2) - 64 / 30.72) < 1e-5)
    test("inner vertex: its cell corners' average", math.abs(abs(10) - 32 / 30.72) < 1e-5)
    test("base height is the chunk's lowest vertex", math.abs(c.z - 0) < 1e-9)
    local hi = tile.chunks[3 * 16 + 3]
    -- chunk (3, 3) is the south-east one of the map; the cliff is in the north-east
    local ne = tile.chunks[0 * 16 + 3]
    test("a cliff level adds 128 units (4.1667 yd)", math.abs((ne.z + ne.heights[1]) - (64 * 24 + 128) / 30.72) < 1e-4,
        tostring(ne.z + ne.heights[1]))
    test("south-east chunk keeps level 2", math.abs((hi.z + hi.heights[145]) - 64 * 32 / 30.72) < 1e-4)
    -- normals: rising to the east, so tilted toward the west (world +y), x ~ 0
    local function normal(ch, v)
        local n = { ch.normals:byte(v * 3 - 2, v * 3) }
        for k = 1, 3 do if n[k] > 127 then n[k] = n[k] - 256 end end
        return n
    end
    local slope = (64 / 30.72) / coords.CELL
    local ny = slope / math.sqrt(1 + slope * slope)
    local nz = 1 / math.sqrt(1 + slope * slope)
    local n = normal(c, 1)
    test("normal at the map's edge: x (north) 0, y (west) leans with the slope, z up",
        n[1] == 0 and math.abs(n[2] - ny * 127) <= 1 and math.abs(n[3] - nz * 127) <= 1, table.concat(n, ","))
    n = normal(tile.chunks[1 * 16 + 1], 10)       -- an inner vertex well inside
    test("normal inside the map, an inner vertex", n[1] == 0 and math.abs(n[2] - ny * 127) <= 1, table.concat(n, ","))
    reader_checks("slope and cliff", out, 1)
    local bytes = out.bytes[1]
    local problems = structure_problems(bytes)
    test("block structure as Noggit and the server's extractor walk it", #problems == 0, table.concat(problems, "; "))
end

test_section("Layers and blend maps")
do
    -- west half dirt, east half grass: the boundary crosses chunk (1, 0)'s cells
    local t = made(33, 33, { "Ldrt", "Lgrs" }, function(i) return { ground_texture = i >= 12 and 1 or 0 } end)
    local job, out = convert_and_read(t)
    local tile = out.tiles[1]
    test("a one-texture chunk has one layer and no blend map", #tile.chunks[0].layers == 1 and not tile.chunks[0].layers[1].alpha)
    local c = tile.chunks[1]           -- columns 8-16: grass from column 12
    test("a two-texture chunk has two layers, the map's lower one first", #c.layers == 2
        and tile.textures[c.layers[1].tex + 1]:find("Dirt") and tile.textures[c.layers[2].tex + 1]:find("Grass"))
    local a = c.layers[2].alpha
    local west, east, edge = a:byte(1), a:byte(64), a:byte(3 * 8 + 4 + 1)
    test("grass blend: 0 in the west, 255 in the east", west == 0 and east == 255, west .. " " .. east)
    test("across the boundary cell the blend rises through the middle", edge > 0 and edge < 255, tostring(edge))
    test("the texture list holds each path once", #tile.textures == 2)
    reader_checks("two textures", out, 1)
    -- three textures meeting: the shares come out right after stacking
    local t3 = made(9, 9, { "Ldrt", "Lgrs", "Lrok" }, function(i, j)
        if i >= 4 and j >= 4 then return { ground_texture = 2 } end
        return { ground_texture = i >= 4 and 1 or 0 }
    end)
    local job3, out3 = convert_and_read(t3)
    local c3 = out3.tiles[1].chunks[0]
    test("three textures, three layers", #c3.layers == 3)
    -- at a point inside the cell whose corners are grass (south) and rock (north),
    -- stacking dirt -> grass -> rock leaves no dirt
    local p = 4 * 64 + 4 * 8 + 4            -- cell (row 4, col 4)'s blend-map points
    local function at(l, q) return c3.layers[l].alpha:byte(q + 1) / 255 end
    local q = (3 * 8 + 4) * 64 + 4 * 8 + 4     -- cell row 3 (rock north, grass south), col 4
    local a2, a3 = at(2, q), at(3, q)
    local dirt = (1 - a2) * (1 - a3)
    test("stacked blends leave a texture no share where none of its corners are", dirt < 0.01, string.format("%.3f", dirt))
    reader_checks("three textures", out3, 1)
end

test_section("The texture reduction rule")
do
    -- five ground types in one chunk; Lgrd (dark grass) covers least and is nearest grass by colour
    local ground = { "Ldrt", "Lgrs", "Lrok", "Wsnw", "Lgrd" }
    local function paint(i, j)
        if i == 4 and j == 4 then return { ground_texture = 4 } end
        if i < 4 and j < 4 then return { ground_texture = 0 } end
        if i >= 4 and j < 4 then return { ground_texture = 1 } end
        if i < 4 then return { ground_texture = 2 } end
        return { ground_texture = 3 }
    end
    local t = made(9, 9, ground, paint)
    local job, out = convert_and_read(t)
    local rep = job:finish()
    local c = out.tiles[1].chunks[0]
    test("a chunk with five textures keeps four layers", #c.layers == 4)
    test("one fold, counted as a warning", rep.folds == 1 and rep.chunks_folded == 1 and rep.warnings == 1)
    local f = rep.fold_list[1]
    test("the least-covering texture folds into the nearest by colour",
        f and f.from:find("GrassHighlight") and f.into:find("GrassBase"), f and (f.from .. " -> " .. f.into))
    test("the fold is listed with its tile and chunk", f and f.tile[1] == 32 and f.chunk[1] == 0 and f.chunk[2] == 0)
    local paths = {}
    for _, l in ipairs(c.layers) do paths[#paths + 1] = out.tiles[1].textures[l.tex + 1] end
    test("the folded texture is not among the chunk's layers", not table.concat(paths, " "):find("GrassHighlight"))
    reader_checks("five textures", out, 1)
    local ok, err = pcall(wterrain.prepare(made(9, 9, ground, paint), { strict = true }).tile,
        wterrain.prepare(made(9, 9, ground, paint), { strict = true }), { tx = 32, ty = 32, bx = 0, by = 0 })
    test("strict mode stops on a fold, naming the chunk and textures", not ok and tostring(err):find("strict: chunk %(0, 0%)"), tostring(err))
end

test_section("Unmapped ground types and blight")
do
    -- "Xzzz" is no stock id: a custom tileset's own; index 3 is past the map's list
    local t = made(17, 9, { "Ldrt", "Xzzz" }, function(i, j)
        if i >= 8 then return { ground_texture = 1 } end
        if i == 0 and j == 0 then return { ground_texture = 3 } end
        if i == 2 and j == 2 then return { is_blight = true } end
    end)
    local job, out = convert_and_read(t)
    local rep = job:finish()
    test("unmapped ids are counted by tile point", rep.unmapped["Xzzz"] == 9 * 9 and rep.unmapped_ids == 2,
        tostring(rep.unmapped["Xzzz"]) .. " / " .. rep.unmapped_ids)
    test("a ground index past the map's list is unmapped too", rep.unmapped["ground index 3 (past the map's list)"] == 1)
    test("unmapped ground gets the fallback texture", table.concat(out.tiles[1].textures, " "):find("Generic\\Grey", 1, true) ~= nil)
    test("each unmapped id is one warning", rep.warnings == rep.folds + 2)
    local c = out.tiles[1].chunks[0]
    local last = out.tiles[1].textures[c.layers[#c.layers].tex + 1]
    test("blight is the main tileset's blight texture, laid last", last:find("Corrupted") ~= nil, last)
    reader_checks("unmapped and blight", out, 1)
    local mapped = job:finish()
    local t2 = made(9, 9, { "Ldrt" }, function(i, j) if i == 1 and j == 1 then return { is_blight = true } end end, "?")
    local r2 = wterrain.prepare(t2):finish()
    test("blight on an unknown main tileset is counted unmapped",
        r2.unmapped["blight (main tileset ? has no row)"] == 1, tostring(next(r2.unmapped)))
end

test_section("Water")
do
    -- a lake: ground 0 (WC3 height) with a pit, water flag in the middle, surface 64 units up
    local t = made(17, 17, { "Ldrt" }, function(i, j)
        local inside = i >= 4 and i <= 12 and j >= 4 and j <= 12
        return { height = inside and -100 or 0, has_water = inside, water_level = 64 + 89.6 }
    end)
    local job, out = convert_and_read(t)
    local rep = job:finish()
    local c = out.tiles[1].chunks[0]          -- NW chunk: cells cols 0-7, rows 0-7 (tile points j 16..8)
    local q = c.liquid
    test("a chunk with wet cells gets one water layer", q ~= nil and q.kind == 1)
    -- rows from the north: tile point j = 16 - row; wet tile points j <= 12 -> rows >= 4; cells touching them start at row 3
    test("its rectangle covers the wet cells", q and q.col == 3 and q.row == 3 and q.w == 5 and q.h == 5,
        q and string.format("%d %d %d %d", q.col, q.row, q.w, q.h))
    test("the surface is the water level in yards", q and math.abs(q.heights[#q.heights] - 64 / 30.72) < 1e-5)
    test("depth: surface over ground, 9 a yard", q and q.depths[#q.depths] == math.floor((164 / 30.72) * 9 + 0.5))
    test("dry corners in the rectangle take the flagged ones' surface", q and math.abs(q.heights[1] - 64 / 30.72) < 1e-5)
    test("water counted in the report", rep.liquid.chunks == 4 and rep.liquid.cells > 0,
        rep.liquid.chunks .. " chunks")
    reader_checks("lake", out, 1)
    -- a pond with an L-shape: the rectangle needs a which-cells map
    local t2 = made(9, 9, { "Ldrt" }, function(i, j)
        local wet = (i == 1 and j <= 3) or (j == 1 and i <= 3)
        return { height = -200, has_water = wet, water_level = 8192 / 4 - 2048 }
    end)
    local job2, out2 = convert_and_read(t2)
    local q2 = out2.tiles[1].chunks[0].liquid
    local holes = 0
    if q2 then for r = q2.row, q2.row + q2.h - 1 do for col = q2.col, q2.col + q2.w - 1 do
        if q2.wet[r][col] == 0 then holes = holes + 1 end end end end
    test("an L-shaped pond leaves dry cells in its rectangle", holes > 0, tostring(holes))
    reader_checks("L-shaped pond", out2, 1)
    -- the water flag with its surface under the ground is no water
    local t3 = made(9, 9, { "Ldrt" }, function() return { height = 500, has_water = true, water_level = 0 } end)
    local job3, out3 = convert_and_read(t3)
    test("water under the ground is not written", out3.written_liquids == 0)
end

test_section("Sizes")
do
    -- not a multiple of a chunk: the rest of the tile is a clamped skirt
    local t = made(41, 25, { "Ldrt", "Lgrs" }, function(i, j) return { height = i * 10 + j, ground_texture = (i + j) % 2 } end)
    local job, out = convert_and_read(t)
    test("41 x 25 tile points: one ADT", #out.tiles == 1)
    local far = out.tiles[1].chunks[255]
    local edge = (40 * 10 + 0) / 30.72
    test("past the map's edge the ground is the nearest edge tile point's", math.abs(far.z + far.heights[1] - edge) < 1e-4)
    reader_checks("41 x 25", out, 1)
    -- three tiles across
    local t2 = made(301, 9, { "Ldrt" }, function(i) return { height = (i % 50) * 8 } end)
    local job2, out2 = convert_and_read(t2)
    test("300 tiles across: three ADTs from 31_32", #out2.tiles == 3 and out2.tiles[1].tx == 31 and out2.tiles[3].tx == 33
        and out2.tiles[1].ty == 32)
    reader_checks("301 x 9", out2, 3)
end
-- }}}

-- {{{ The WDT and WDL
test_section("The WDT and WDL")
do
    local tiles = { { tx = 31, ty = 31 }, { tx = 32, ty = 31 }, { tx = 31, ty = 32 }, { tx = 32, ty = 32 } }
    local wdt = adt.wdt_bytes(tiles)
    test("WDT blocks: MVER MPHD MAIN MWMO", tag_at(wdt, 0) == "MVER" and tag_at(wdt, 12) == "MPHD"
        and tag_at(wdt, 52) == "MAIN" and tag_at(wdt, 60 + 32768) == "MWMO" and #wdt == 60 + 32768 + 8)
    test("MPHD says 8-bit blend maps", u32(wdt, 20) == 4)
    local on = 0
    for k = 0, 4095 do if u32(wdt, 60 + k * 8) == 1 then on = on + 1 end end
    test("MAIN marks exactly the written tiles, row by row", on == 4 and u32(wdt, 60 + (31 * 64 + 32) * 8) == 1
        and u32(wdt, 60 + (33 * 64 + 31) * 8) == 0)
    if W then
        local buf = ffi.new("unsigned char[?]", #wdt)
        ffi.copy(buf, wdt, #wdt)
        test("the W client's reader finds 8-bit blend maps in the WDT", W.adt_wdt_big_alpha(buf, #wdt, WHY) == 1)
    else
        skip("the W client reads the WDT", "no library")
    end
    local t = made(17, 17, { "Ldrt" }, function(i, j) return { height = i * 30.72 * 4 } end)   -- 4 yd a tile, east
    local job = wterrain.prepare(t)
    local wdl = adt.wdl_bytes(job)
    test("WDL: MVER, MAOF, then MARE and MAHO", tag_at(wdl, 0) == "MVER" and tag_at(wdl, 12) == "MAOF"
        and tag_at(wdl, 12 + 8 + 16384) == "MARE")
    if W then
        local buf = ffi.new("unsigned char[?]", #wdl)
        ffi.copy(buf, wdl, #wdl)
        local ok = W.adt_wdl_read(buf, #wdl, wwdl, WHY) == 0
        local k = 32 * 64 + 32
        test("the W client's reader reads the WDL", ok, ok and "" or why_text())
        test("its tile 32_32 is there and only it", ok and wwdl.have[k] == 1 and wwdl.have[k + 1] == 0)
        -- chunk corner 1 (8 cells east of the corner): 8 tiles x 4 yd = 32
        test("far-off heights: chunk corners in yards", ok and wwdl.heights[k][0] == 0 and wwdl.heights[k][1] == 32
            and wwdl.heights[k][2] == 64, ok and (wwdl.heights[k][0] .. " " .. wwdl.heights[k][1]) or "")
    else
        skip("the W client reads the WDL", "no library")
    end
end
-- }}}

-- {{{ The camera point (Test Map, issue 913)
-- The editor's view looks at a WC3 point; the W client's --camera takes
-- its own world x (north) and y (west) in yards. The converter's report
-- carries the placement (placement.client); here it is held to the
-- layout, to the W client's own rule for which ADT a point is in
-- (coords.client_adt: its 018-maps.c and 033-ground-prep.c), and, with its
-- reader, to the ground the client reads there.
test_section("The camera point (Test Map, issue 913)")
do
    -- the placement is the layout's own mapping, over maps of every shape
    local shapes = { { 17, 17 }, { 41, 25 }, { 301, 9 }, { 129, 129 }, { 257, 193, 1000.5, -333.25 }, { 2, 2 } }
    local worst, back, sampled = 0, 0, 0
    for _, d in ipairs(shapes) do
        local L = coords.layout({ width = d[1], height = d[2], offset_x = d[3] or -64 * (d[1] - 1), offset_y = d[4] or -64 * (d[2] - 1) })
        local P = L:client_placement()
        for j = 0, d[2] - 1, math.max(1, math.floor(d[2] / 7)) do
            for i = 0, d[1] - 1, math.max(1, math.floor(d[1] / 7)) do
                local wx, wy = L.offset_x + 128 * i + 40, L.offset_y + 128 * j + 40
                local X, Y = L:to_wow(wx, wy)
                local cx, cy = P.x0 + P.scale * wy, P.y0 - P.scale * wx
                worst = math.max(worst, math.abs(cx - X), math.abs(cy - Y))
                local bx, by = L:to_wc3(cx, cy)
                back = math.max(back, math.abs(bx - wx), math.abs(by - wy))
                sampled = sampled + 1
            end
        end
    end
    test("client_placement is the layout's to_wow, as a scale and a shift (" .. sampled .. " points)", worst < 1e-9,
        string.format("worst %.3g yd", worst))
    test("and to_wc3 takes it back", back < 1e-6, string.format("worst %.3g units", back))

    -- the axes: WC3 north is the client's +x, WC3 east its -y; 30.72 units a yard
    local L = coords.layout({ width = 17, height = 17, offset_x = -1024, offset_y = -1024 })
    local P = L:client_placement()
    local x0, y0 = coords.wc3_to_client(P, 0, 0)
    local xn, yn = coords.wc3_to_client(P, 0, 307.2)
    local xe, ye = coords.wc3_to_client(P, 307.2, 0)
    test("WC3 north is the W client's +x (north)", math.abs(xn - x0 - 10) < 1e-9 and math.abs(yn - y0) < 1e-9)
    test("WC3 east is the W client's -y (y points west)", math.abs(ye - y0 + 10) < 1e-9 and math.abs(xe - x0) < 1e-9)
    -- a one-tile map's middle: tile 32_32 starts at world (0, 0) and runs south and east
    test("a 17 x 17 map centred on WC3's (0, 0) is 33.3 yd south-east of world (0, 0)",
        math.abs(x0 + 100 / 3) < 1e-9 and math.abs(y0 + 100 / 3) < 1e-9, x0 .. ", " .. y0)

    -- off the map: moved inside its edge
    local X, Y, moved = coords.wc3_to_client(P, 1e6, -1e6)
    local _, _, moved_in = coords.wc3_to_client(P, 10, 10)
    test("a point off the map moves onto it, just inside its edge", moved and not moved_in
        and math.abs(X - (P.x0 + P.scale * (-1024 + coords.EDGE_INSET))) < 1e-9
        and math.abs(Y - (P.y0 - P.scale * (1024 - coords.EDGE_INSET))) < 1e-9)
    test("bad placements refused", coords.wc3_to_client(nil, 0, 0) == nil
        and coords.wc3_to_client({ scale = 0, x0 = 0, y0 = 0, wc3_min = { 0, 0 }, wc3_max = { 1, 1 } }, 0, 0) == nil
        and coords.wc3_to_client({ scale = 1, x0 = 0 / 0, y0 = 0, wc3_min = { 0, 0 }, wc3_max = { 1, 1 } }, 0, 0) == nil
        and coords.wc3_to_client({ scale = 1, x0 = 0, y0 = 0, wc3_min = { 2, 0 }, wc3_max = { 1, 1 } }, 0, 0) == nil
        and coords.wc3_to_client({ scale = 1, x0 = 0, y0 = 0, wc3_min = { 0 }, wc3_max = { 1, 1 } }, 0, 0) == nil
        and coords.wc3_to_client(P, "1", 0) == nil)
    test("the W client's own tile rule: Astranaar (2717, -400) is in Kalimdor_32_26, world (0, 0) in _32_32",
        select(1, coords.client_adt(2717, -400)) == 32 and select(2, coords.client_adt(2717, -400)) == 26
        and select(1, coords.client_adt(0, 0)) == 32 and select(2, coords.client_adt(0, 0)) == 32)

    -- every point of each map, edges and corners too, is in an ADT written,
    -- by the client's rule; with its reader, the ground it reads at the
    -- camera's vertex is the WC3 ground at the tile point asked for (the
    -- grounds slope, so a camera turned or shifted would read another height)
    local function camera_lands(label, terrain)
        local job = wterrain.prepare(terrain)
        local Lm = job.layout
        local Pm = Lm:client_placement()
        local written, bytes = {}, {}
        for _, t in ipairs(Lm:tiles()) do written[t.tx .. "_" .. t.ty] = t end
        local missed, n, err, read_bad = 0, 0, 0, 0
        local function at(wx, wy)
            local cx, cy = coords.wc3_to_client(Pm, wx, wy)
            local atx, aty = coords.client_adt(cx, cy)
            local t = written[atx .. "_" .. aty]
            n = n + 1
            if not t then missed = missed + 1 return end
            if not W then return end
            if not bytes[t] then bytes[t] = adt.tile_bytes(job:tile(t)) end
            local b = bytes[t]
            local buf = ffi.new("unsigned char[?]", #b)
            ffi.copy(buf, b, #b)
            if W.adt_read(buf, #b, 1, wtile, WHY) ~= 0 then read_bad = read_bad + 1 return end
            -- the chunk the point is in, from its own position (MCNK 104,
            -- 32-bit floats: a point on a chunk's edge counts for either):
            -- the nearest outer vertex's height against the WC3 ground there
            local found = false
            local e = 1e-3
            for k = 0, 255 do
                local c = wtile.chunks[k]
                if not found and cx <= c.x + e and cx >= c.x - coords.CHUNK - e
                   and cy <= c.y + e and cy >= c.y - coords.CHUNK - e then
                    local r = math.floor((c.x - cx) / coords.CELL + 0.5)
                    local col = math.floor((c.y - cy) / coords.CELL + 0.5)
                    -- the WC3 tile point nearest where the camera was asked for
                    -- (an off-map one: the nearest on the map)
                    local i = math.floor((wx - Lm.offset_x) / 128 + 0.5)
                    local j = math.floor((wy - Lm.offset_y) / 128 + 0.5)
                    i, j = math.max(0, math.min(Lm.W - 1, i)), math.max(0, math.min(Lm.H - 1, j))
                    local want = w3e.ground_z(terrain.tilepoints[j][i]) * coords.YARDS_PER_UNIT
                    err = math.max(err, math.abs(c.z + c.heights[r * 17 + col] - want))
                    found = true
                end
            end
            if not found then read_bad = read_bad + 1 end
            W.adt_free(wtile)
        end
        local x1, y1 = Pm.wc3_max[1], Pm.wc3_max[2]
        local xa, ya = Pm.wc3_min[1], Pm.wc3_min[2]
        for _, c in ipairs({ { xa, ya }, { xa, y1 }, { x1, ya }, { x1, y1 }, { (xa + x1) / 2, (ya + y1) / 2 },
                             { xa - 5000, ya - 5000 }, { x1 + 5000, y1 + 5000 } }) do at(c[1], c[2]) end
        for j = 0, Lm.H - 1, math.max(1, math.floor(Lm.H / 11)) do
            for i = 0, Lm.W - 1, math.max(1, math.floor(Lm.W / 11)) do at(xa + 128 * i, ya + 128 * j) end
        end
        test(label .. ": the camera lands in a written ADT by the W client's rule (" .. n .. " points, corners and off-map too)",
            missed == 0, missed .. " in a tile not written")
        if W then
            test(label .. ": the W client's reader has the camera's chunk there, its ground the WC3 ground",
                read_bad == 0 and err <= 0.5, string.format("%d not found; worst %.3f yd", read_bad, err))
        else
            skip(label .. ": the camera's ground through the W client's reader", "no library")
        end
    end
    camera_lands("17 x 17 slope", made(17, 17, { "Ldrt" }, function(i, j) return { height = i * 61 - j * 17 } end))
    camera_lands("129 x 129 (one whole ADT)", made(129, 129, { "Ldrt" }, function(i, j) return { height = (i + 2 * j) * 9 } end))
    camera_lands("301 x 9", made(301, 9, { "Ldrt" }, function(i, j) return { height = (i % 7) * 40 } end))

    -- the report: placement.client written, read back exact
    local build = TMP .. "/camera-build"
    local terrain = made(41, 25, { "Ldrt" })
    terrain.offset_x, terrain.offset_y = -2560.25, -1536.5
    local report = wowbuild.convert("camera.w3x", build, { terrain = terrain })
    local loaded = loadfile(build .. "/conversion-report.lua")
    local data = loaded and setfenv(loaded, {})()
    local want = coords.layout(terrain):client_placement()
    local got = data and data.placement and data.placement.client
    test("the report carries placement.client", got ~= nil and coords.check_placement(got) ~= nil
        and report.placement.client ~= nil)
    test("its numbers read back exactly as written", got and got.scale == want.scale and got.x0 == want.x0 and got.y0 == want.y0
        and got.wc3_min[1] == want.wc3_min[1] and got.wc3_min[2] == want.wc3_min[2]
        and got.wc3_max[1] == want.wc3_max[1] and got.wc3_max[2] == want.wc3_max[2],
        got and string.format("%.17g %.17g %.17g", got.scale, got.x0, got.y0))
end
-- }}}

-- {{{ The command
test_section("The command")
do
    local cmd = "luajit " .. quote(DIR .. "/src/cli/wow-convert.lua")
    local function run(args)
        local p = io.popen(cmd .. " " .. args .. " 2>&1; echo \"exit=$?\"")
        local text = p:read("*a")
        p:close()
        return text, tonumber(text:match("exit=(%d+)%s*$"))
    end
    local text, code = run("")
    test("no paths: exit 2 with the usage", code == 2 and text:find("usage:"))
    text, code = run("--bogus a b")
    test("an unknown option: exit 2", code == 2 and text:find("unknown option"))
    text, code = run("--help")
    -- (since W02b: the terrain and the placements)
    test("the usage says which parts are built and that later parts add to it",
        code == 0 and text:find("Today the terrain") and text:find("placements") and text:find("add to this command"))
    text, code = run(quote(TMP .. "/no-such.w3x") .. " " .. quote(TMP .. "/b"))
    test("a missing map: exit 1, said why", code == 1 and text:find("no map file"))
    text, code = run("--name 'bad name' x y")
    test("a bad --name: exit 2", code == 2)
end
-- }}}

-- {{{ The maps in assets/
test_section("Maps in assets/")
local maps = {}
do
    local p = io.popen('ls -S -r ' .. quote(DIR .. "/assets") .. '/*.w3x 2>/dev/null')
    for line in p:lines() do maps[#maps + 1] = line end
    p:close()
end
local mpq_ok, mpq_err = pcall(function() require("mpq").open(maps[1] or ""):close() end)
local function smallest_daow()
    for _, m in ipairs(maps) do if m:match("[^/]*$"):lower():find("^daow") then return m end end
end
local chosen = {}
local first = smallest_daow()
if first then chosen[#chosen + 1] = first end
if os.getenv("WOW_TERRAIN_ALL") == "1" then
    for _, m in ipairs(maps) do if m ~= first then chosen[#chosen + 1] = m end end
else
    -- the smallest map of all and a non-square one, besides the DAoW map
    for _, m in ipairs(maps) do
        local name = m:match("[^/]*$")
        if (name:find("^Conquest") or name:find("Plaguelands")) and m ~= first then chosen[#chosen + 1] = m end
    end
end
if #maps == 0 then
    skip("maps in assets/", "none found in " .. DIR .. "/assets")
elseif not mpq_ok and tostring(mpq_err):find("StormLib") then
    skip("maps in assets/", "StormLib isn't built here")
else
    local total_folds, total_tiles = 0, 0
    for n, path in ipairs(chosen) do
        local label = path:match("[^/]*$")
        local terrain = wowbuild.read_terrain(path)
        local job, out = convert_and_read(terrain)
        local rep = job:finish()
        total_folds, total_tiles = total_folds + rep.folds, total_tiles + #out.tiles
        print(string.format("  (%s: %d ADTs, layers 1/2/3/4 = %d/%d/%d/%d, %d folds, %d unmapped, %d water chunks; worst height %.2g yd)",
            label, #out.tiles, rep.layers.one, rep.layers.two, rep.layers.three, rep.layers.four,
            rep.folds, rep.unmapped_ids, rep.liquid.chunks, out.max_err))
        local problems = {}
        for _, b in ipairs(out.bytes) do
            for _, pr in ipairs(structure_problems(b)) do problems[#problems + 1] = pr end
        end
        test(label .. ": every ADT's block structure", #problems == 0, table.concat(problems, "; "))
        test(label .. ": no chunk past four layers", rep.layers.four + rep.layers.three + rep.layers.two + rep.layers.one == rep.chunks)
        reader_checks(label, out, #out.tiles)
        if n == 1 then
            -- the whole command on it, files on disk, the report read back as data
            local build = TMP .. "/build"
            local report = wowbuild.convert(path, build, { terrain = terrain, stock_dbc = false, patch = false })
            local dir = build .. "/World/Maps/" .. report.map_directory
            local f = io.open(dir .. "/" .. report.map_directory .. ".wdt", "rb")
            test(label .. ": the WDT is in the build folder under World/Maps", f ~= nil)
            if f then f:close() end
            local loaded = loadfile(build .. "/conversion-report.lua")
            local data = loaded and setfenv(loaded, {})()
            test(label .. ": the conversion report loads as data", data and data.format == 1 and data.map_directory == report.map_directory)
            test(label .. ": the report counts folds and unmapped ground",
                data and data.terrain.folds == rep.folds and data.terrain.unmapped_ids == rep.unmapped_ids
                and data.warnings == rep.folds + rep.unmapped_ids)
            local adts = 0
            for _, file in ipairs(data and data.files or {}) do if file.path:find("%.adt$") then adts = adts + 1 end end
            test(label .. ": the report lists every ADT written", adts == #out.tiles)
            local found = 0
            local p = io.popen("ls " .. quote(dir))
            for name in p:lines() do if name:find("%.adt$") then found = found + 1 end end
            p:close()
            test(label .. ": exactly those ADT files on disk", found == #out.tiles)
            if W then
                -- read the files from disk too, through the reader
                local bad = 0
                for _, file in ipairs(data.files) do
                    if file.path:find("%.adt$") then
                        local h = io.open(build .. "/" .. file.path, "rb")
                        local s = h:read("*a")
                        h:close()
                        local buf = ffi.new("unsigned char[?]", #s)
                        ffi.copy(buf, s, #s)
                        if W.adt_read(buf, #s, 1, wtile, WHY) ~= 0 then bad = bad + 1 else W.adt_free(wtile) end
                    end
                end
                test(label .. ": the W client reads the ADT files from the build folder", bad == 0)
                local function slurp(path)
                    local h = io.open(path, "rb")
                    local str = h and h:read("*a")
                    if h then h:close() end
                    local b = str and ffi.new("unsigned char[?]", #str)
                    if b then ffi.copy(b, str, #str) end
                    return b, str and #str or 0
                end
                local wb, wn = slurp(dir .. "/" .. report.map_directory .. ".wdt")
                test(label .. ": the W client reads its WDT (8-bit blend maps)", wb and W.adt_wdt_big_alpha(wb, wn, WHY) == 1)
                local lb, ln = slurp(dir .. "/" .. report.map_directory .. ".wdl")
                local wdl_ok = lb and W.adt_wdl_read(lb, ln, wwdl, WHY) == 0
                local have = 0
                if wdl_ok then for k = 0, 4095 do have = have + wwdl.have[k] end end
                test(label .. ": the W client reads its WDL, a tile for every ADT", wdl_ok and have == #out.tiles,
                    wdl_ok and (have .. " tiles") or why_text())
            end
        end
    end
    print(string.format("  (%d maps, %d ADT tiles, %d texture folds in all)", #chosen, total_tiles, total_folds))
end
-- }}}

-- {{{ Nothing proprietary: the build holds paths, never textures
test_section("Nothing proprietary in the build")
do
    local p = io.popen("find " .. quote(TMP .. "/build") .. " -type f 2>/dev/null")
    local kinds = {}
    -- (2026-11-05: and W02f's server-stamp, which has no ending)
    for f in p:lines() do kinds[#kinds + 1] = f:match("%.([%w]+)$") or (f:match("/server%-stamp$") and "stamp") or "?" end
    p:close()
    local only = #kinds > 0
    -- (since W02b also the placement list, .lua, and the creatures' SQL; the
    -- map's own imports are W02b's tests' to check. Since W02c the tables
    -- with this map's rows only (.dbc; no stock tables were given), the
    -- creature list (.tsv), the loading screen drawn from the map itself
    -- (.blp) and patch-W.MPQ (left out here); W02c's tests check them)
    local allowed = { adt = true, wdt = true, wdl = true, lua = true, sql = true, dbc = true, tsv = true, blp = true, MPQ = true, stamp = true }
    for _, k in ipairs(kinds) do if not allowed[k] then only = false end end
    if #kinds == 0 then skip("build folder contents", "no map was converted")
    else test("the build holds ADT, WDT, WDL, the report, the placement list, the SQL and W02c's own tables only (no textures of Blizzard's)", only, table.concat(kinds, " ")) end
end
-- }}}

os.execute("rm -rf " .. quote(TMP))
print(string.format("\nTests: %d passed, %d failed, %d skipped", pass_count, test_count - pass_count, skip_count))
os.exit(pass_count == test_count and 0 or 1)

--[[
Ground Textures (Issue 526)

WC3 paints its ground from up to 16 tilesets a map picks (war3map.w3e's
list: "Ldrt", "Lgrs" ...). Each tile point names one; each cell between
four tile points is drawn as the game does:

  lowest     the lowest-numbered tileset among its corners, as a whole
             tile: subtile 15 of a plain tileset, or one of the 16 whole
             variations in an extended (twice as wide) tileset's right
             half, picked by the tile point's variation
  above      each higher tileset among its corners, as the subtile whose
             alpha covers just the corners it's on: subtile number =
             the corner bits (below) of those corners

A tileset texture is 4 x 4 subtiles (256 x 256), or 8 x 4 (512 x 256) when
extended; subtiles are a quarter of the height square, north at the top.

Where the textures come from:

  install    TerrainArt\Terrain.slk names each tileset's folder and file
             (the map's own import of that path wins, as with all art)
  stand-in   without one, a texture drawn here in the same layout: the
             tileset's colour (demo/wc3map/scene.lua's) with noise, and
             the same corner shapes with soft, ragged edges. Not
             Blizzard's art; enough to see the blending work

Corner bits (ground.BITS) follow the published map viewers' reading of
the tilesets: south-east 1, south-west 2, north-east 4, north-west 8. It
has only been checked against the stand-ins, which are drawn by the same
rule: if stock tiles show their blends mirrored on the owner's install,
this table is the one thing to change.

Cliff cells (corners on different cliff levels, not a ramp) keep the
landscape's rock colour (WC3 draws cliffs as models); blighted cells keep
their blight colour; slopes, however steep, are textured.

    local ground = require("assets.ground")
    local report = ground.apply(render, A, scene)   -- after render.land_build
    report.real, report.standin                      -- tilesets by source
]]

local ffi = require("ffi")
local bit = require("bit")

local ground = {}

ground.BITS = { se = 1, sw = 2, ne = 4, nw = 8 }
ground.SLK = "TerrainArt\\Terrain.slk"
ground.STANDIN_W, ground.STANDIN_H = 512, 256

-- {{{ ground.variation
-- The subtile a cell's lowest tileset is drawn with, from its south-west
-- tile point's variation (0-31)
function ground.variation(extended, v)
    if extended then
        if v < 16 then return 16 + v end
        if v == 16 then return 15 end
        return 0
    end
    return v == 0 and 15 or 0
end
-- }}}

-- {{{ ground.cells
-- For each cell (rows from the south), up to four (tileset, subtile)
-- pairs, lowest tileset first, as 8 bytes (255: none). extended: tileset
-- index (0-based) -> true for 512-wide ones. skip(i, j): cells to leave
-- to the landscape's own colours
function ground.cells(terrain, extended, skip)
    local w, h = terrain.width, terrain.height
    local cw, ch = w - 1, h - 1
    local buf = ffi.new("uint8_t[?]", cw * ch * 8)
    ffi.fill(buf, cw * ch * 8, 255)
    local B = ground.BITS
    local tex = ffi.new("uint8_t[?]", w * h)
    local var = ffi.new("uint8_t[?]", w * h)
    for j = 0, h - 1 do
        for i = 0, w - 1 do
            local tp = terrain:get_tile(i, j)
            tex[j * w + i] = tp.ground_texture or 0
            var[j * w + i] = tp.texture_details or 0
        end
    end
    local used = 0
    for j = 0, ch - 1 do
        for i = 0, cw - 1 do
            if not (skip and skip(i, j)) then
                local sw, se = tex[j * w + i], tex[j * w + i + 1]
                local nw, ne = tex[(j + 1) * w + i], tex[(j + 1) * w + i + 1]
                local o = (j * cw + i) * 8
                -- the distinct tilesets, lowest first
                local list = { sw }
                for _, t in ipairs({ se, nw, ne }) do
                    local seen = false
                    for _, x in ipairs(list) do if x == t then seen = true end end
                    if not seen then list[#list + 1] = t end
                end
                table.sort(list)
                buf[o] = list[1]
                buf[o + 1] = ground.variation(extended[list[1]], var[j * w + i])
                for q = 2, #list do
                    local t = list[q]
                    local bits = (se == t and B.se or 0) + (sw == t and B.sw or 0)
                               + (ne == t and B.ne or 0) + (nw == t and B.nw or 0)
                    buf[o + (q - 1) * 2] = t
                    buf[o + (q - 1) * 2 + 1] = bits
                end
                used = used + 1
            end
        end
    end
    return ffi.string(buf, cw * ch * 8), used
end
-- }}}

-- {{{ Stand-in textures
local function hash(x, y, seed)
    local n = bit.bxor(x * 374761393 + y * 668265263 + seed * 2147483647, 0)
    n = bit.bxor(n, bit.rshift(n, 13)) * 1274126177
    n = bit.bxor(n, bit.rshift(n, 16))
    return bit.band(n, 0xffff) / 65535
end

-- smooth value noise on a grid of cell size s, wrapping every `wrap` cells
local function noise(x, y, s, seed, wrap)
    local fx, fy = x / s, y / s
    local ix, iy = math.floor(fx), math.floor(fy)
    local tx, ty = fx - ix, fy - iy
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    local x0, x1, y0, y1 = ix % wrap, (ix + 1) % wrap, iy % wrap, (iy + 1) % wrap
    local a, b = hash(x0, y0, seed), hash(x1, y0, seed)
    local c, d = hash(x0, y1, seed), hash(x1, y1, seed)
    return a + (b - a) * tx + (c - a) * ty + (a - b - c + d) * tx * ty
end

-- A tileset in WC3's extended layout (512 x 256): the left half the 16
-- corner shapes, the right half 16 whole variations. rgb: its colour
function ground.standin(rgb, seed)
    local W, H = ground.STANDIN_W, ground.STANDIN_H
    local S = H / 4
    local buf = ffi.new("uint8_t[?]", W * H * 4)
    local B = ground.BITS
    for py = 0, H - 1 do
        for px = 0, W - 1 do
            local col, row = math.floor(px / S), math.floor(py / S)
            local lx, ly = px % S, py % S
            -- texture detail: it tiles across subtiles, so neighbours join
            local n1 = noise(lx, ly, 8, seed, S / 8)
            local n2 = noise(lx, ly, 4, seed + 7, S / 4)
            local k = 0.78 + 0.3 * n1 + 0.14 * n2
            local a = 255
            if col < 4 then
                local v = row * 4 + col
                local fx, fy = (lx + 0.5) / S, (ly + 0.5) / S     -- fy: 0 north .. 1 south
                local cov = (bit.band(v, B.nw) ~= 0 and 1 or 0) * (1 - fx) * (1 - fy)
                          + (bit.band(v, B.ne) ~= 0 and 1 or 0) * fx * (1 - fy)
                          + (bit.band(v, B.sw) ~= 0 and 1 or 0) * (1 - fx) * fy
                          + (bit.band(v, B.se) ~= 0 and 1 or 0) * fx * fy
                local e = cov + (noise(lx, ly, 4, seed + 3, S / 4) - 0.5) * 0.35
                local t = math.max(0, math.min(1, (e - 0.35) / 0.3))
                a = math.floor(255 * t * t * (3 - 2 * t))
                if v == 15 then a = 255 elseif v == 0 then a = 0 end
            else
                -- whole variations: the same ground, a little different each
                k = k * (0.94 + 0.12 * hash(col, row, seed + 11))
            end
            local o = (py * W + px) * 4
            buf[o] = math.min(255, rgb[1] * k)
            buf[o + 1] = math.min(255, rgb[2] * k)
            buf[o + 2] = math.min(255, rgb[3] * k)
            buf[o + 3] = a
        end
    end
    return { width = W, height = H, rgba = ffi.string(buf, W * H * 4) }
end
-- }}}

-- {{{ ground.path
-- The install's texture path for a tileset id, or nil
function ground.path(A, id)
    local t = A and A.table and A:table(ground.SLK)
    local row = t and t.rows[id]
    if not row or not row.dir or not row.file then return nil end
    return tostring(row.dir) .. "\\" .. tostring(row.file) .. ".blp"
end
-- }}}

-- {{{ ground.apply
-- Load every tileset the map uses (the install's, else a stand-in) and
-- give the renderer its ground layers. A: assets.open's (or nil)
function ground.apply(render, A, scene, opts)
    local ids, extended, report = ground.textures(render, A, scene.terrain, opts)
    local used, triangles = ground.lay(render, scene.terrain, ids, extended)
    report.cells, report.triangles = used, triangles
    return report
end

-- the tilesets' textures, made once (the editor lays them again after
-- each change: issue 901)
function ground.textures(render, A, t, opts)
    opts = opts or {}
    local map_scene = require("demo.wc3map.scene")
    local ids, extended = {}, {}
    local report = { real = 0, standin = 0, tilesets = #t.ground_tilesets, paths = {} }
    for k, id in ipairs(t.ground_tilesets) do
        local img
        local path = ground.path(A, id)
        if path and A and not opts.standins then img = A:texture(path) end
        if img then
            report.real = report.real + 1
            report.paths[id] = path
        else
            img = ground.standin(map_scene.ground_color(id), k * 97)
            report.standin = report.standin + 1
        end
        ids[k] = render.tex_create(img.width, img.height, img.rgba, false)
        extended[k - 1] = img.width > img.height
    end
    return ids, extended, report
end

-- the textured cells over the landscape built last (render.land_build)
function ground.lay(render, t, ids, extended)
    -- cliffs (corners on different cliff levels, not a ramp) and blight
    -- keep the landscape's colours; slopes are textured, as in WC3
    local function skip(i, j)
        local lo, hi, ramp = 99, -1, false
        for _, p in ipairs({ { i, j }, { i + 1, j }, { i, j + 1 }, { i + 1, j + 1 } }) do
            local tp = t:get_tile(p[1], p[2])
            if tp.is_blight then return true end
            local lv = tp.layer_height or 0
            lo, hi = math.min(lo, lv), math.max(hi, lv)
            ramp = ramp or tp.is_ramp
        end
        return hi > lo and not ramp
    end
    local cells, used = ground.cells(t, extended, skip)
    return used, render.land_tiles(ids, cells)
end
-- }}}

return ground

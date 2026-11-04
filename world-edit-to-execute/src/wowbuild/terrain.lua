--[[
terrain.lua - a WC3 terrain grid as WoW ground tiles (issue W02a)

Turns parsers.w3e's terrain into what each WoW 3.3.5a ADT file holds for its
256 chunks: heights, normals, up to four texture layers with 64 x 64 blend
maps, and water. The bytes are written by wowbuild.adt; this decides the
numbers. Placement and scale come from wowbuild.coords (one WC3 tile = one
WoW cell, 4.1667 yards; 30.72 WC3 units a yard, up as well as across).

Heights. A chunk's 9 x 9 outer vertices are WC3 tile points one-to-one, each
at the tile point's ground height (w3e.ground_z: its height plus 128 units a
cliff level above level 2), in yards. The 8 x 8 inner vertices (cell
centres) are the average of their cell's four corners. The chunk's base
height (MCNK position z) is its lowest vertex.

Textures. Each tile point names one WC3 ground type; blighted tile points
use the blight texture of the map's main tileset. Through the data table
wowbuild/ground_textures.lua each becomes a WoW texture path; two WC3 types
sharing a path count as one texture. In a chunk, each texture's share at a
blend-map point is the bilinear weight of the corners of its cell painted
with it, so the blend is WC3's own corner rule smoothed over a cell.
The texture reduction rule (docs/datapath-wc3-map-into-wow-client.md): a
chunk keeps the four textures that cover most of it; each further texture is
folded into the kept texture nearest to it by colour (the rows' rgb), and
every fold is counted and listed in the report as a warning. With
opts.strict a fold is an error instead. Layers are stacked in the WC3 map's
own order (its ground list; blight last), and each layer's blend value is
its share divided by the shares of itself and the layers under it, so
blending the layers in turn gives each texture exactly its share.

Water. A cell has water when any of its corners is wet (w3e.is_wet: the
water flag set and the surface above the ground). Each chunk with water gets
one MH2O layer over the rectangle of its wet cells, LiquidType 1 (water),
vertex format 0 (a height and a depth per vertex). A vertex's height is its
tile point's water surface (w3e.water_z, yards) where the tile point has the
water flag, else the mean of the flagged vertices of that chunk; its depth
is (surface - ground) in yards times 9, clamped to 0-255, the scale the W
client's reader measured on the original's lakes.

Normals: from the height field by central differences, one cell apart;
stored WoW-world x (north), y (west), z (up), each times 127.

    local wterrain = require("wowbuild.terrain")
    local job = wterrain.prepare(terrain, { strict = false })   -- or errors
    for _, t in ipairs(job.layout:tiles()) do
        local tile = job:tile(t)          -- { tx, ty, textures, chunks[0..255] }
        -- write it (wowbuild.adt.tile_bytes), then let it go
    end
    local report = job:finish()           -- counts: folds, unmapped, layers, water

A chunk: { ix, iy, x, y, z, heights[1..145] (above z, MCVT order),
normals (string, 145 x 3 signed bytes), layers = { { tex = texture number,
alpha = 4096-byte string or nil for layer 1 } }, lowres (16 bytes),
liquid = nil or { kind, col, row, w, h, wet[r][c] (0-based, 8 x 8),
heights[1..(w+1)(h+1)], depths[1..], lo, hi } }.
]]

local ffi = require("ffi")
local w3e = require("parsers.w3e")
local coords = require("wowbuild.coords")

local wterrain = {}

wterrain.LIQUID_WATER = 1           -- LiquidType.dbc's "Water" in 3.3.5a
wterrain.DEPTH_PER_YARD = 9         -- MH2O depth byte per yard of water (W client's measurement)
wterrain.MAX_LAYERS = 4
wterrain.BLIGHT_ORDER = 1000        -- blight is laid over every ground type, as in WC3
wterrain.FOLD_LIST_MAX = 200        -- folds listed one by one in the report (all are counted)

-- {{{ wterrain.load_textures
-- The ground table: path (default wowbuild/ground_textures.lua beside this
-- file) read as data, with an index of every ground id
function wterrain.load_textures(path)
    if not path then
        local here = debug.getinfo(1, "S").source:match("^@(.*)terrain%.lua$") or "./"
        path = here .. "ground_textures.lua"
    end
    local chunk, err = loadfile(path)
    if not chunk then error("ground texture table: " .. tostring(err)) end
    setfenv(chunk, {})
    local t = chunk()
    assert(type(t) == "table" and t.format == 1, "ground texture table " .. path .. ": not format 1")
    t.index = {}
    for code, set in pairs(t.tilesets) do
        for id, row in pairs(set.grounds) do
            row.id, row.tileset = id, code
            t.index[id] = row
        end
        if set.blight then set.blight.id, set.blight.tileset = "blight:" .. code, code end
    end
    t.fallback.id = "fallback"
    t.path = path
    return t
end
-- }}}

local Job = {}
Job.__index = Job

-- {{{ wterrain.prepare
-- terrain: parsers.w3e's. opts: strict (a fold is an error), textures (a
-- table from load_textures, or a path to one)
function wterrain.prepare(terrain, opts)
    opts = opts or {}
    local tex = opts.textures
    if type(tex) ~= "table" then tex = wterrain.load_textures(tex) end
    local L = coords.layout(terrain)
    local rows, cols = L.nty * 128 + 1, L.ntx * 128 + 1
    local self = setmetatable({
        terrain = terrain, layout = L, strict = opts.strict and true or false, table = tex,
        rows = rows, cols = cols,
        gh = ffi.new("double[?]", rows * cols),      -- ground height, yards
        gw = ffi.new("double[?]", rows * cols),      -- water surface, yards
        gflag = ffi.new("uint8_t[?]", rows * cols),  -- 1: water flag; 2: also wet (surface above ground)
        gkey = ffi.new("int16_t[?]", rows * cols),   -- texture key (index into self.keys)
        keys = {}, key_of_path = {},
        report = {
            folds = 0, chunks_folded = 0, fold_pairs = {}, fold_list = {},
            unmapped = {}, unmapped_tilepoints = 0,
            layers = { [1] = 0, [2] = 0, [3] = 0, [4] = 0 },
            liquid_chunks = 0, liquid_cells = 0, chunks = 0, tiles = 0,
            textures_used = {},
        },
    }, Job)

    -- the map's ground ids, each to a texture key once
    local main = tex.tilesets[terrain.tileset_code]
    local blight_row = main and main.blight or tex.fallback
    local per_index = {}            -- ground list index (0-based) -> key
    local function key_for(row, order, wc3_id)
        local k = self.key_of_path[row.wow]
        if not k then
            k = #self.keys + 1
            self.keys[k] = { path = row.wow, rgb = row.rgb, order = order, ids = {}, checked = row.checked }
            self.key_of_path[row.wow] = k
        end
        local key = self.keys[k]
        if order < key.order then key.order = order end
        key.ids[#key.ids + 1] = wc3_id
        return k
    end
    local unmapped_index = {}
    local function ground_key(index)
        if per_index[index] then return per_index[index] end
        local id = terrain.ground_tilesets[index + 1]
        local row = id and tex.index[id]
        if not row then
            local name = id or ("ground index " .. index .. " (past the map's list)")
            unmapped_index[index] = name
            row = tex.fallback
        end
        per_index[index] = key_for(row, index, id or ("#" .. index))
        return per_index[index]
    end
    local blight_key

    -- the grid, clamped past the WC3 map's edges
    local W, H = L.W, L.H
    for r = 0, rows - 1 do
        for c = 0, cols - 1 do
            local i, j = L:tilepoint(r, c)
            local tp = terrain.tilepoints[j][i]
            local at = r * cols + c
            self.gh[at] = w3e.ground_z(tp) * coords.YARDS_PER_UNIT
            self.gw[at] = w3e.water_z(tp) * coords.YARDS_PER_UNIT
            self.gflag[at] = (tp.has_water and 1 or 0) + (w3e.is_wet(tp) and 2 or 0)
            if tp.is_blight then
                blight_key = blight_key or key_for(blight_row, wterrain.BLIGHT_ORDER, "blight")
                self.gkey[at] = blight_key
            else
                self.gkey[at] = ground_key(tp.ground_texture or 0)
            end
        end
    end
    -- unmapped ground ids, counted over the map's own tile points (not the
    -- skirt); blight on a map whose main tileset has no row counts too
    local no_blight = not main and ("blight (main tileset " .. tostring(terrain.tileset_code) .. " has no row)")
    for j = 0, H - 1 do
        for i = 0, W - 1 do
            local tp = terrain.tilepoints[j][i]
            local name
            if tp.is_blight then name = no_blight else name = unmapped_index[tp.ground_texture or 0] end
            if name then
                self.report.unmapped[name] = (self.report.unmapped[name] or 0) + 1
                self.report.unmapped_tilepoints = self.report.unmapped_tilepoints + 1
            end
        end
    end
    return self
end
-- }}}

-- {{{ bilinear weights inside a cell, per blend-map point (8 x 8 a cell)
local WNW, WNE, WSW, WSE = {}, {}, {}, {}
for q = 0, 63 do
    local fy, fx = (math.floor(q / 8) + 0.5) / 8, (q % 8 + 0.5) / 8   -- fy: 0 north .. 1 south
    WNW[q] = (1 - fx) * (1 - fy)
    WNE[q] = fx * (1 - fy)
    WSW[q] = (1 - fx) * fy
    WSE[q] = fx * fy
end
-- }}}

local function rgb_distance(a, b)
    local dr, dg, db = a[1] - b[1], a[2] - b[2], a[3] - b[3]
    return dr * dr + dg * dg + db * db
end

local weights = ffi.new("double[4][4096]")
local alpha_buf = ffi.new("uint8_t[4096]")
local normal_buf = ffi.new("int8_t[435]")

-- {{{ Job:chunk_textures
-- The chunk's layers (at most four): fold, order, blend maps
function Job:chunk_textures(R0, C0, tile, where)
    local cols, gkey = self.cols, self.gkey
    -- corner keys and each key's coverage
    local K, cover, seen = {}, {}, {}
    for r = 0, 8 do
        for c = 0, 8 do
            local k = gkey[(R0 + r) * cols + C0 + c]
            K[r * 9 + c] = k
        end
    end
    for r = 0, 7 do
        for c = 0, 7 do
            for _, k in ipairs({ K[r * 9 + c], K[r * 9 + c + 1], K[(r + 1) * 9 + c], K[(r + 1) * 9 + c + 1] }) do
                if not cover[k] then cover[k] = 0; seen[#seen + 1] = k end
                cover[k] = cover[k] + 0.25
            end
        end
    end
    local keys = self.keys
    -- the reduction rule: keep the four covering most; fold the rest by colour
    if #seen > wterrain.MAX_LAYERS then
        table.sort(seen, function(a, b)
            if cover[a] ~= cover[b] then return cover[a] > cover[b] end
            return keys[a].order < keys[b].order
        end)
        local into = {}
        for n = wterrain.MAX_LAYERS + 1, #seen do
            local k = seen[n]
            local best, bd = nil, math.huge
            for m = 1, wterrain.MAX_LAYERS do
                local d = rgb_distance(keys[k].rgb, keys[seen[m]].rgb)
                if d < bd then best, bd = seen[m], d end
            end
            into[k] = best
            local rep = self.report
            rep.folds = rep.folds + 1
            local pair = keys[k].path .. " -> " .. keys[best].path
            rep.fold_pairs[pair] = (rep.fold_pairs[pair] or 0) + 1
            if #rep.fold_list < wterrain.FOLD_LIST_MAX then
                rep.fold_list[#rep.fold_list + 1] = {
                    tile = { tile.tx, tile.ty }, chunk = { where.ix, where.iy },
                    from = keys[k].path, into = keys[best].path, share = cover[k] / 64,
                }
            end
            if self.strict then
                error(string.format("strict: chunk (%d, %d) of tile %d_%d has more than %d textures; %s would fold into %s",
                    where.ix, where.iy, tile.tx, tile.ty, wterrain.MAX_LAYERS, keys[k].path, keys[best].path), 0)
            end
        end
        self.report.chunks_folded = self.report.chunks_folded + 1
        for q = 0, 80 do K[q] = into[K[q]] or K[q] end
        for n = #seen, wterrain.MAX_LAYERS + 1, -1 do seen[n] = nil end
    end
    -- layers in the map's own order
    table.sort(seen, function(a, b)
        if keys[a].order ~= keys[b].order then return keys[a].order < keys[b].order end
        return a < b
    end)
    local layer_of = {}
    local layers = {}
    for n, k in ipairs(seen) do
        layer_of[k] = n - 1
        if not tile.tex_of_key[k] then
            tile.textures[#tile.textures + 1] = keys[k].path
            tile.tex_of_key[k] = #tile.textures - 1
            self.report.textures_used[keys[k].path] = true
        end
        layers[n] = { tex = tile.tex_of_key[k] }
    end
    local n = #layers
    self.report.layers[n] = self.report.layers[n] + 1
    -- the low-quality map: per cell, the layer covering most of it
    local low = {}
    for r = 0, 7 do
        local row = 0
        for c = 0, 7 do
            local share = {}
            for _, k in ipairs({ K[r * 9 + c], K[r * 9 + c + 1], K[(r + 1) * 9 + c], K[(r + 1) * 9 + c + 1] }) do
                share[layer_of[k]] = (share[layer_of[k]] or 0) + 1
            end
            local best, bv = 0, -1
            for l = 0, n - 1 do
                if (share[l] or 0) > bv then best, bv = l, share[l] or 0 end
            end
            row = row + best * 2 ^ (c * 2)
        end
        low[r + 1] = string.char(row % 256, math.floor(row / 256))
    end
    local lowres = table.concat(low)
    if n == 1 then return layers, lowres end
    -- shares per blend-map point
    ffi.fill(weights, ffi.sizeof(weights), 0)
    for cr = 0, 7 do
        for cc = 0, 7 do
            local lnw, lne = layer_of[K[cr * 9 + cc]], layer_of[K[cr * 9 + cc + 1]]
            local lsw, lse = layer_of[K[(cr + 1) * 9 + cc]], layer_of[K[(cr + 1) * 9 + cc + 1]]
            for q = 0, 63 do
                local p = (cr * 8 + math.floor(q / 8)) * 64 + cc * 8 + q % 8
                weights[lnw][p] = weights[lnw][p] + WNW[q]
                weights[lne][p] = weights[lne][p] + WNE[q]
                weights[lsw][p] = weights[lsw][p] + WSW[q]
                weights[lse][p] = weights[lse][p] + WSE[q]
            end
        end
    end
    -- blend values: share over the shares of this layer and those under it
    for l = 1, n - 1 do
        for p = 0, 4095 do
            local below = 0
            for m = 0, l do below = below + weights[m][p] end
            local a = below > 1e-9 and weights[l][p] / below or 0
            alpha_buf[p] = math.floor(a * 255 + 0.5)
        end
        layers[l + 1].alpha = ffi.string(alpha_buf, 4096)
    end
    return layers, lowres
end
-- }}}

-- {{{ Job:chunk_liquid
function Job:chunk_liquid(R0, C0)
    local cols, gflag, gw, gh = self.cols, self.gflag, self.gw, self.gh
    local wet = {}
    local any = false
    local r0, r1, c0, c1 = 8, -1, 8, -1
    for r = 0, 7 do
        wet[r] = {}
        for c = 0, 7 do
            local at = (R0 + r) * cols + C0 + c
            local w = gflag[at] >= 2 or gflag[at + 1] >= 2 or gflag[at + cols] >= 2 or gflag[at + cols + 1] >= 2
            wet[r][c] = w and 1 or 0
            if w then
                any = true
                if r < r0 then r0 = r end
                if r > r1 then r1 = r end
                if c < c0 then c0 = c end
                if c > c1 then c1 = c end
            end
        end
    end
    if not any then return nil end
    local q = { kind = wterrain.LIQUID_WATER, col = c0, row = r0, w = c1 - c0 + 1, h = r1 - r0 + 1, wet = wet,
                heights = {}, depths = {} }
    -- the flagged vertices' mean, for the vertices without the flag
    local sum, n = 0, 0
    for r = r0, r1 + 1 do
        for c = c0, c1 + 1 do
            local at = (R0 + r) * cols + C0 + c
            if gflag[at] >= 1 then sum = sum + gw[at]; n = n + 1 end
        end
    end
    local mean = n > 0 and sum / n or 0
    local lo, hi = math.huge, -math.huge
    local cells = 0
    for r = r0, r1 do for c = c0, c1 do cells = cells + wet[r][c] end end
    for r = r0, r1 + 1 do
        for c = c0, c1 + 1 do
            local at = (R0 + r) * cols + C0 + c
            local h = gflag[at] >= 1 and gw[at] or mean
            q.heights[#q.heights + 1] = h
            local d = math.floor((h - gh[at]) * wterrain.DEPTH_PER_YARD + 0.5)
            q.depths[#q.depths + 1] = d < 0 and 0 or (d > 255 and 255 or d)
            if h < lo then lo = h end
            if h > hi then hi = h end
        end
    end
    q.lo, q.hi, q.cells = lo, hi, cells
    return q
end
-- }}}

-- {{{ Job:chunk_heights: the 145 heights (above the base) and normals
function Job:chunk_heights(R0, C0)
    local rows, cols, gh = self.rows, self.cols, self.gh
    local function H(r, c)
        if r < 0 then r = 0 elseif r > rows - 1 then r = rows - 1 end
        if c < 0 then c = 0 elseif c > cols - 1 then c = cols - 1 end
        return gh[r * cols + c]
    end
    local abs, list, nrm = {}, {}, {}
    local n = 0
    local base = math.huge
    local inv = 1 / coords.CELL
    for k = 0, 16 do
        local outer = k % 2 == 0
        local r = math.floor(k / 2)
        for c = 0, outer and 8 or 7 do
            local R, C = R0 + r, C0 + c
            local h, dr, dc
            if outer then
                h = H(R, C)
                -- one-sided at the block's edges, so the slope isn't halved there
                local r1, r2 = math.max(R - 1, 0), math.min(R + 1, rows - 1)
                local c1, c2 = math.max(C - 1, 0), math.min(C + 1, cols - 1)
                dr = (H(r2, C) - H(r1, C)) / (r2 - r1)
                dc = (H(R, c2) - H(R, c1)) / (c2 - c1)
            else
                local a, b, d, e = H(R, C), H(R, C + 1), H(R + 1, C), H(R + 1, C + 1)
                h = (a + b + d + e) / 4
                dr = ((d + e) - (a + b)) / 2
                dc = ((b + e) - (a + d)) / 2
            end
            n = n + 1
            abs[n] = h
            if h < base then base = h end
            -- world x falls with the row and y with the column, so the
            -- surface's normal is (dh/drow, dh/dcol, cell) / length
            local nx, ny, nz = dr * inv, dc * inv, 1
            local len = math.sqrt(nx * nx + ny * ny + nz * nz)
            nrm[n] = { nx / len, ny / len, nz / len }
        end
    end
    for i = 1, 145 do list[i] = abs[i] - base end
    for i = 1, 145 do
        for a = 1, 3 do normal_buf[(i - 1) * 3 + a - 1] = math.floor(nrm[i][a] * 127 + 0.5) end
    end
    return base, list, ffi.string(normal_buf, 435)
end
-- }}}

-- {{{ Job:tile
-- One ADT tile's chunks. t: an entry of layout:tiles()
function Job:tile(t)
    local tile = { tx = t.tx, ty = t.ty, textures = {}, tex_of_key = {}, chunks = {} }
    local L = self.layout
    for iy = 0, 15 do
        for ix = 0, 15 do
            local R0, C0 = t.by * 128 + iy * 8, t.bx * 128 + ix * 8
            local x, y = L:vertex_world(R0, C0)
            local base, heights, normals = self:chunk_heights(R0, C0)
            local layers, lowres = self:chunk_textures(R0, C0, tile, { ix = ix, iy = iy })
            local liquid = self:chunk_liquid(R0, C0)
            if liquid then
                self.report.liquid_chunks = self.report.liquid_chunks + 1
                self.report.liquid_cells = self.report.liquid_cells + liquid.cells
            end
            tile.chunks[iy * 16 + ix] = {
                ix = ix, iy = iy, x = x, y = y, z = base, heights = heights, normals = normals,
                layers = layers, lowres = lowres, liquid = liquid,
            }
        end
    end
    self.report.chunks = self.report.chunks + 256
    self.report.tiles = self.report.tiles + 1
    return tile
end
-- }}}

-- {{{ Job:height_at
-- The WC3 height field at a WC3 world point (x, y), in yards: bilinear
-- between the four tile points around it, as the outer vertices hold them.
-- What the written ground must match (W02's acceptance: within 0.5 yd)
function Job:height_at(wx, wy)
    local t, L = self.terrain, self.layout
    local fi, fj = (wx - L.offset_x) / 128, (wy - L.offset_y) / 128
    local i0, j0 = math.max(0, math.min(L.W - 2, math.floor(fi))), math.max(0, math.min(L.H - 2, math.floor(fj)))
    local fx, fy = fi - i0, fj - j0
    local function z(i, j) return w3e.ground_z(t.tilepoints[j][i]) * coords.YARDS_PER_UNIT end
    return z(i0, j0) * (1 - fx) * (1 - fy) + z(i0 + 1, j0) * fx * (1 - fy)
         + z(i0, j0 + 1) * (1 - fx) * fy + z(i0 + 1, j0 + 1) * fx * fy
end
-- }}}

-- {{{ Job:finish
-- The report's terrain part (plain data)
function Job:finish()
    local r = self.report
    local L = self.layout
    local unmapped_ids = 0
    for _ in pairs(r.unmapped) do unmapped_ids = unmapped_ids + 1 end
    local used = {}
    for path in pairs(r.textures_used) do used[#used + 1] = path end
    table.sort(used)
    local unchecked = 0
    for _, k in ipairs(self.keys) do
        if r.textures_used[k.path] and not k.checked then unchecked = unchecked + 1 end
    end
    return {
        tileset = self.terrain.tileset_code,
        tilepoints = { L.W, L.H },
        adt_tiles = { first = { L.tx0, L.ty0 }, across = L.ntx, down = L.nty },
        chunks = r.chunks,
        layers = { one = r.layers[1], two = r.layers[2], three = r.layers[3], four = r.layers[4] },
        folds = r.folds, chunks_folded = r.chunks_folded, fold_pairs = r.fold_pairs, fold_list = r.fold_list,
        unmapped = r.unmapped, unmapped_ids = unmapped_ids, unmapped_tilepoints = r.unmapped_tilepoints,
        textures = used, textures_unchecked = unchecked,
        liquid = { chunks = r.liquid_chunks, cells = r.liquid_cells },
        warnings = r.folds + unmapped_ids,
    }
end
-- }}}

return wterrain

--[[
The Terrain Editor on a WoW Map's Tiles (Issue W10b)

W10's step 2 without its window: the ground tools on the tiles of a WoW
map (editor/wowmap.lua reads them through the W client's reader), and a
writer that turns an edited tile back into its file.

The tools, on a map opened with wowmap.open (or E:wow_map), at a point
in world yards (x north, y west, as the reader gives them) with a radius
in yards; each reads the tiles it needs:

  wt.raise(m, x, y, { radius, amount, falloff })    up by amount yards at the middle
  wt.lower(m, x, y, { radius, amount, falloff })    down
  wt.smooth(m, x, y, { radius, strength, falloff }) each point toward its neighbours' mean
  wt.flatten(m, x, y, { radius, height, strength, falloff })
                                                     toward height (else the ground at x, y)
  wt.paint(m, x, y, { radius, texture, strength, falloff })
                                                     a texture (its path) over the blend maps
  wt.holes(m, x, y, { radius, on })                  cut (on, the default) or fill holes

falloff is "linear" (full at the middle, none at the edge; the default,
flatten's "flat") or "flat". Each returns what it changed: { points,
chunks, tiles = { "tx_ty" }, full = { chunks that had no room for a
fifth texture } }.

A tile's ground is shared at its edges: a chunk's border points are
also its neighbours' (in this tile or the next), and a tool changes
every copy of a point, so the tiles stay joined. Each changed point's
normal is worked out again, and those of the points next to it, by
W02a's rule (wowbuild.terrain's Job:chunk_heights); no other normal
changes.

The writer patches the tile's own bytes rather than writing the tile
afresh: what an edit didn't touch stays as it was, byte for byte (a
tile written without an edit is the file that was read).

  - heights (MCVT), the changed normals (MCNR) and holes (MCNK header,
    byte 60) in place;
  - a painted chunk's layers (MCLY) and blend maps (MCAL) written again,
    uncompressed, 8 bits a point when the map's WDT says so, else 4;
    its header's layer count, MCAL size and low-quality map with them,
    flag 0x8000 set (every row and column of its maps is real), and the
    chunk's later sub-blocks moved along;
  - a new texture's name added to MTEX, the blocks after it moved along,
    MHDR's and MCIN's offsets and MCIN's sizes made to follow.

    local wt = require("editor.wowterrain")
    wt.raise(m, x, y, { radius = 12, amount = 3 })
    local bytes, why = wt.tile_bytes(original, m:tile(tx, ty), { big_alpha = m.big_alpha })
    local written, why = wt.save(m)          -- every edited tile, written over its file, and the
                                             -- map's WDL where ground or holes changed (W10c)

Water is editor/wowwater.lua's (W10c: its tools, and the MH2O block
tile_bytes writes again); the far view, editor/wowwdl.lua's.
Tiles added and taken off are editor/wowtiles.lua's (W10d); the save
writes them (a new tile's file, the WDT's MAIN flags, the far view) and
deletes a taken-off tile's file.

    wt.attach(E)     -- the editor's strokes on a WoW map (E:wow_edit), editor/init.lua does this
                     -- and E:wow_add_tile, E:wow_remove_tile (W10d)
]]

local ffi = require("ffi")
local bit = require("bit")
local coords = require("wowbuild.coords")
local adt = require("wowbuild.adt")
local bw = require("parsers.binwrite")

local wt = {}

local TILE, CHUNK, CELL, ORIGIN = coords.TILE, coords.CHUNK, coords.CELL, coords.ORIGIN
local KEY = 32768                     -- a point's key: row * KEY + column, on the half-cell grid
local MCLY_PACKED = 0x200             -- a blend map kept in runs (8-bit maps only)

-- {{{ bytes
local cell = ffi.new("union { uint32_t u; float f; }")
local function u32(s, at)             -- at: from 0
    local a, b, c, d = s:byte(at + 1, at + 4)
    return a + b * 256 + c * 65536 + d * 16777216
end
local function u16(s, at)
    local a, b = s:byte(at + 1, at + 2)
    return a + b * 256
end
local function tag_at(s, at) return s:sub(at + 1, at + 4):reverse() end
local function put(s, at, bytes) return s:sub(1, at) .. bytes .. s:sub(at + #bytes + 1) end
local function le32(v) return bw.new():u32(v):done() end

-- the top-level blocks: { tag, at, len (with the 8-byte head) }; nil and why
local function walk(s)
    local out, at = {}, 0
    while at + 8 <= #s do
        local size = u32(s, at + 4)
        if at + 8 + size > #s then
            return nil, string.format("a block at byte %d says it is %d bytes, past the file's end (%d)", at, size, #s)
        end
        out[#out + 1] = { tag = tag_at(s, at), at = at, len = 8 + size }
        at = at + 8 + size
    end
    return out, at
end
wt.walk = walk

-- s with regions replaced: each { start, stop, data, seq } (from 0, stop
-- not included; data a string, or a function(new_at) giving len bytes;
-- seq orders regions inserted at one place). Returns the bytes and
-- moved(p): where byte p is now (nil when p is inside a replaced region),
-- or nil and why when regions overlap.
local function splice(s, regions)
    table.sort(regions, function(a, b)
        if a.start ~= b.start then return a.start < b.start end
        if a.stop ~= b.stop then return a.stop < b.stop end
        return (a.seq or 0) < (b.seq or 0)
    end)
    for i = 2, #regions do
        if regions[i].start < regions[i - 1].stop then return nil, "two of the parts to replace overlap" end
    end
    local shift = 0
    for _, g in ipairs(regions) do
        g.len = g.len or #g.data
        g.new_at = g.start + shift
        shift = shift + g.len - (g.stop - g.start)
    end
    local parts, from = {}, 0
    for _, g in ipairs(regions) do
        parts[#parts + 1] = s:sub(from + 1, g.start)
        local d = type(g.data) == "function" and g.data(g.new_at) or g.data
        assert(#d == g.len, "a part came out another length than it said")
        parts[#parts + 1] = d
        from = g.stop
    end
    parts[#parts + 1] = s:sub(from + 1)
    local function moved(p)
        local q = p
        for _, g in ipairs(regions) do
            if p > g.start and p < g.stop then return nil end
            if g.stop <= p then q = q + g.len - (g.stop - g.start) end
        end
        return q
    end
    return table.concat(parts), moved
end
wt.splice = splice
-- }}}

-- {{{ points: where each of a chunk's 145 is, on the half-cell grid
-- A chunk's points come row by row: 9 corners, then 8 middles, ... 9
-- corners. On a grid of half cells a corner is at even (row, column),
-- a middle at odd.
local PR, PC = {}, {}
for i = 1, 145 do
    local j = i - 1
    local band, rest = math.floor(j / 17), j % 17
    if rest < 9 then PR[i], PC[i] = band * 2, rest * 2
    else PR[i], PC[i] = band * 2 + 1, (rest - 9) * 2 + 1 end
end
wt.POINT_ROW, wt.POINT_COLUMN = PR, PC

-- a chunk's north-west corner on the whole map's grid of half cells
local function chunk_origin(t, c)
    return (t.ty * 16 + c.iy) * 16, (t.tx * 16 + c.ix) * 16
end

local function key_world(key)
    local r2, c2 = math.floor(key / KEY), key % KEY
    return ORIGIN - r2 * CELL / 2, ORIGIN - c2 * CELL / 2
end
wt.key_world = key_world

local function index_tile(m, t)
    if t.indexed then return end
    m.points = m.points or {}
    local vx = m.points
    for k = 1, 256 do
        local c = t.chunks[k]
        c.tile = t
        local R, C = chunk_origin(t, c)
        for i = 1, 145 do
            local key = (R + PR[i]) * KEY + C + PC[i]
            local e = vx[key]
            if not e then e = {} vx[key] = e end
            e[#e + 1] = c
            e[#e + 1] = i
        end
    end
    t.indexed = true
end

-- the tiles a box of world yards falls on, read (those the map has)
local function load_area(m, x, y, r)
    local tx0, tx1 = math.floor((ORIGIN - (y + r)) / TILE), math.floor((ORIGIN - (y - r)) / TILE)
    local ty0, ty1 = math.floor((ORIGIN - (x + r)) / TILE), math.floor((ORIGIN - (x - r)) / TILE)
    local tiles = {}
    for ty = math.max(0, ty0), math.min(63, ty1) do
        for tx = math.max(0, tx0), math.min(63, tx1) do
            if m.by_key[tx .. "_" .. ty] then
                local t, why = m:tile(tx, ty)
                if not t then return nil, why end
                index_tile(m, t)
                tiles[#tiles + 1] = t
            end
        end
    end
    return tiles
end

local function height(m, key)
    local e = m.points[key]
    if not e then return nil end
    return e[1].z + e[1].heights[e[2]]
end
wt.height = height

local function mark(c, what)
    c.dirty = c.dirty or {}
    c.dirty[what] = true
    c.tile.dirty = true
end

local function set_height(m, key, h)
    local e = m.points[key]
    for n = 1, #e, 2 do
        local c, i = e[n], e[n + 1]
        c.heights[i] = h - c.z
        mark(c, "heights")
        c.dirty.points = c.dirty.points or {}
        c.dirty.points[i] = true
    end
end

-- the points within r yards of (x, y): { { key, d } }
local function points_near(m, x, y, r)
    local out = {}
    local r0 = math.max(0, math.ceil((ORIGIN - (x + r)) / CELL * 2))
    local r1 = math.floor((ORIGIN - (x - r)) / CELL * 2)
    local c0 = math.max(0, math.ceil((ORIGIN - (y + r)) / CELL * 2))
    local c1 = math.floor((ORIGIN - (y - r)) / CELL * 2)
    local vx = m.points or {}
    for r2 = r0, r1 do
        local px = ORIGIN - r2 * CELL / 2
        for c2 = c0, c1 do
            local key = r2 * KEY + c2
            if vx[key] then
                local py = ORIGIN - c2 * CELL / 2
                local d = math.sqrt((px - x) ^ 2 + (py - y) ^ 2)
                if d <= r then out[#out + 1] = { key = key, d = d } end
            end
        end
    end
    return out
end

local function weight(d, r, falloff)
    if falloff == "flat" or r <= 0 then return 1 end
    return math.max(0, 1 - d / r)
end
-- }}}

-- {{{ normals: W02a's rule (wowbuild.terrain's Job:chunk_heights)
-- A corner's slope from the corners either side of it (one-sided where
-- the map has none), a middle's from the four corners round it; the
-- normal (dh/drow, dh/dcolumn, one cell) / its length, each part * 127.
local function normal(m, key)
    local r2, c2 = math.floor(key / KEY), key % KEY
    local dr, dc
    if r2 % 2 == 0 then
        local h = height(m, key)
        local n, s = height(m, key - 2 * KEY), height(m, key + 2 * KEY)
        local w, e = height(m, key - 2), height(m, key + 2)
        if n and s then dr = (s - n) / 2 elseif s then dr = s - h elseif n then dr = h - n else dr = 0 end
        if w and e then dc = (e - w) / 2 elseif e then dc = e - h elseif w then dc = h - w else dc = 0 end
    else
        local a, b = height(m, key - KEY - 1), height(m, key - KEY + 1)
        local d, e = height(m, key + KEY - 1), height(m, key + KEY + 1)
        if not (a and b and d and e) then return nil end
        dr = ((d + e) - (a + b)) / 2
        dc = ((b + e) - (a + d)) / 2
    end
    local nx, ny, nz = dr / CELL, dc / CELL, 1
    local len = math.sqrt(nx * nx + ny * ny + nz * nz)
    return { math.floor(nx / len * 127 + 0.5), math.floor(ny / len * 127 + 0.5), math.floor(nz / len * 127 + 0.5) }
end
wt.normal = normal

-- the normals that depend on the changed points, worked out again
local AROUND = { { -2, 0 }, { 2, 0 }, { 0, -2 }, { 0, 2 }, { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }
local function renormal(m, changed)
    local todo = {}
    for key in pairs(changed) do
        if math.floor(key / KEY) % 2 == 0 then          -- a corner: its own, and its neighbours'
            todo[key] = true
            for _, o in ipairs(AROUND) do todo[key + o[1] * KEY + o[2]] = true end
        end
    end
    for key in pairs(todo) do
        local e = m.points[key]
        local n = e and normal(m, key)
        if n then
            for k = 1, #e, 2 do
                local c, i = e[k], e[k + 1]
                c.normals = c.normals or {}
                c.normals[i] = n
                mark(c, "normals")
            end
        end
    end
end
-- }}}

-- {{{ the height tools
local function result(m, keys)
    local chunks, tiles, seen = {}, {}, {}
    local n = 0
    for _, key in ipairs(keys) do
        local e = m.points[key]
        for k = 1, #e, 2 do
            local c = e[k]
            if not chunks[c] then chunks[c] = true n = n + 1 end
            local tk = c.tile.tx .. "_" .. c.tile.ty
            if not seen[tk] then seen[tk] = true tiles[#tiles + 1] = tk end
        end
    end
    table.sort(tiles)
    return { points = #keys, chunks = n, tiles = tiles, full = {} }
end

-- each point near (x, y) to fn(key, old height, weight) (all read first)
local function shape(m, x, y, o, fn, falloff_default)
    o = o or {}
    local r = o.radius or CELL * 2
    local _, why = load_area(m, x, y, r + 2 * CELL)
    if why then return nil, why end
    local near = points_near(m, x, y, r)
    local new = {}
    for n, p in ipairs(near) do
        new[n] = fn(p.key, height(m, p.key), weight(p.d, r, o.falloff or falloff_default))
    end
    local changed, keys = {}, {}
    for n, p in ipairs(near) do
        if new[n] and new[n] ~= height(m, p.key) then
            set_height(m, p.key, new[n])
            changed[p.key] = true
            keys[#keys + 1] = p.key
        end
    end
    renormal(m, changed)
    return result(m, keys)
end

function wt.raise(m, x, y, o)
    local a = (o and o.amount) or 1
    return shape(m, x, y, o, function(_, h, w) return h + a * w end)
end

function wt.lower(m, x, y, o)
    local a = (o and o.amount) or 1
    return shape(m, x, y, o, function(_, h, w) return h - a * w end)
end

function wt.smooth(m, x, y, o)
    local s = (o and o.strength) or 0.5
    return shape(m, x, y, o, function(key, h, w)
        local sum, n = 0, 0
        for _, d in ipairs(AROUND) do
            local v = height(m, key + d[1] * KEY + d[2])
            if v then sum, n = sum + v, n + 1 end
        end
        if n == 0 then return h end
        return h + (sum / n - h) * math.min(1, s * w)
    end)
end

-- the ground at (x, y): its nearest point's height
function wt.ground(m, x, y)
    local _, why = load_area(m, x, y, CELL)
    if why then return nil, why end
    local best, bd
    for _, p in ipairs(points_near(m, x, y, CELL)) do
        if not bd or p.d < bd then best, bd = p.key, p.d end
    end
    if not best then return nil, string.format("no ground of %s at %.1f, %.1f", m.directory, x, y) end
    return height(m, best)
end

function wt.flatten(m, x, y, o)
    o = o or {}
    local target = o.height
    if not target then
        local why
        target, why = wt.ground(m, x, y)
        if not target then return nil, why end
    end
    local s = o.strength or 1
    return shape(m, x, y, o, function(_, h, w) return h + (target - h) * math.min(1, s * w) end, "flat")
end
-- }}}

-- {{{ holes: 4 x 4 a chunk, each 2 x 2 cells (bit row * 4 + column, as the W client draws them)
function wt.holes(m, x, y, o)
    o = o or {}
    local on = o.on ~= false
    local r = o.radius or 0
    local _, why = load_area(m, x, y, r + CELL)
    if why then return nil, why end
    local QUAD = 2 * CELL
    local quads = {}
    if r <= 0 then
        quads[1] = { math.floor((ORIGIN - x) / QUAD), math.floor((ORIGIN - y) / QUAD) }
    else
        for qr = math.floor((ORIGIN - x - r) / QUAD), math.floor((ORIGIN - x + r) / QUAD) do
            for qc = math.floor((ORIGIN - y - r) / QUAD), math.floor((ORIGIN - y + r) / QUAD) do
                local cx, cy = ORIGIN - (qr + 0.5) * QUAD, ORIGIN - (qc + 0.5) * QUAD
                if (cx - x) ^ 2 + (cy - y) ^ 2 <= r * r then quads[#quads + 1] = { qr, qc } end
            end
        end
    end
    local touched, tiles = {}, {}
    local n, nc = 0, 0
    for _, q in ipairs(quads) do
        local qr, qc = q[1], q[2]
        local t = qr >= 0 and qc >= 0 and m.read_tiles[math.floor(qc / 64) .. "_" .. math.floor(qr / 64)]
        if t then
            local c = t.chunks[(math.floor(qr / 4) % 16) * 16 + math.floor(qc / 4) % 16 + 1]
            local b = 2 ^ ((qr % 4) * 4 + qc % 4)
            local has = bit.band(c.holes, b) ~= 0
            if has ~= on then
                c.holes = on and bit.bor(c.holes, b) or bit.band(c.holes, bit.bnot(b))
                mark(c, "holes")
                n = n + 1
                if not touched[c] then
                    touched[c] = true
                    nc = nc + 1
                    tiles[t.tx .. "_" .. t.ty] = true
                end
            end
        end
    end
    local list = {}
    for k in pairs(tiles) do list[#list + 1] = k end
    table.sort(list)
    return { points = n, chunks = nc, tiles = list, full = {} }
end
-- }}}

-- {{{ paint: a texture over a chunk's blend maps
-- Each layer above the first is a 64 x 64 map of how much it covers
-- what is under it (0-255). Painting layer L by w (0-1) at a point:
-- L covers more, (255 - a) * w more; every layer above it covers w
-- less, so L shows. Painting the first layer: every layer above it
-- covers w less.
local ZEROS = string.rep("\0", 4096)

local function texture_number(t, path)
    for i, p in ipairs(t.textures) do
        if p:lower() == path:lower() then return i end
    end
    t.textures[#t.textures + 1] = path
    t.dirty = true
    return #t.textures
end

-- the chunk's layer for texture number tn, made when there is room: a
-- fifth texture takes the place of a layer above the first that no
-- longer covers anything; nil when there is none
local function layer_for(c, tn, path)
    for l, L in ipairs(c.layers) do
        if L.texture_index == tn then return l end
    end
    if #c.layers < 4 then
        c.layers[#c.layers + 1] = { texture = path, texture_index = tn, alpha = ZEROS }
        return #c.layers
    end
    for l = 2, #c.layers do
        if c.layers[l].alpha == ZEROS then
            c.layers[l] = { texture = path, texture_index = tn, alpha = ZEROS }
            return l
        end
    end
    return nil
end

function wt.paint(m, x, y, o)
    o = o or {}
    if type(o.texture) ~= "string" or o.texture == "" then return nil, "paint: which texture (its path)?" end
    local r = o.radius or CELL * 2
    local s = o.strength or 1
    local tiles, why = load_area(m, x, y, r)
    if not tiles then return nil, why end
    local STEP = CHUNK / 64
    local out = { points = 0, chunks = 0, tiles = {}, full = {} }
    local buf = ffi.new("uint8_t[4096]")
    for _, t in ipairs(tiles) do
        local painted_here = false
        for k = 1, 256 do
            local c = t.chunks[k]
            local R, C = chunk_origin(t, c)
            local cx, cy = ORIGIN - R * CELL / 2, ORIGIN - C * CELL / 2
            -- the chunk's points under the brush, with their weights
            if cx - CHUNK <= x + r and cx >= x - r and cy - CHUNK <= y + r and cy >= y - r then
                local hits = {}
                for pr = 0, 63 do
                    local px = cx - (pr + 0.5) * STEP
                    if math.abs(px - x) <= r then
                        for pc = 0, 63 do
                            local py = cy - (pc + 0.5) * STEP
                            local d = math.sqrt((px - x) ^ 2 + (py - y) ^ 2)
                            if d <= r then
                                local w = math.min(1, s * weight(d, r, o.falloff))
                                if w > 0 then hits[#hits + 1] = pr * 64 + pc hits[#hits + 1] = w end
                            end
                        end
                    end
                end
                if #hits > 0 then
                    local tn = texture_number(t, o.texture)
                    local had = #c.layers
                    local L = layer_for(c, tn, o.texture)
                    local changed = L ~= nil and (#c.layers ~= had or c.layers[L].alpha == ZEROS)
                    if not L then
                        out.full[#out.full + 1] = { tx = t.tx, ty = t.ty, ix = c.ix, iy = c.iy }
                    else
                        for l = math.max(2, L), #c.layers do
                            local layer = c.layers[l]
                            ffi.copy(buf, layer.alpha or ZEROS, 4096)
                            for h = 1, #hits, 2 do
                                local p, w = hits[h], hits[h + 1]
                                local a = buf[p]
                                if l == L then a = a + (255 - a) * w else a = a * (1 - w) end
                                buf[p] = math.max(0, math.min(255, math.floor(a + 0.5)))
                            end
                            local now = ffi.string(buf, 4096)
                            if now ~= layer.alpha then changed = true end
                            layer.alpha = now
                        end
                        if changed then
                            mark(c, "layers")
                            out.chunks = out.chunks + 1
                            out.points = out.points + #hits / 2
                            painted_here = true
                        end
                    end
                end
            end
        end
        if painted_here then out.tiles[#out.tiles + 1] = t.tx .. "_" .. t.ty end
    end
    table.sort(out.tiles)
    return out
end
-- }}}

-- {{{ a chunk's bytes again
-- the header's offsets (from the MCNK tag) to its sub-blocks: MCVT MCNR
-- MCLY MCRF MCAL MCSH MCSE MCLQ MCCV MCLV
local OFFSET_FIELDS = { 20, 24, 28, 32, 36, 44, 88, 96, 116, 120 }

local function encode_alpha(a, big)
    if big then return a end
    local out = {}
    for i = 0, 2047 do
        local lo = math.min(15, math.floor(a:byte(i * 2 + 1) / 17 + 0.5))
        local hi = math.min(15, math.floor(a:byte(i * 2 + 2) / 17 + 0.5))
        out[i + 1] = string.char(lo + hi * 16)
    end
    return table.concat(out)
end

-- the low-quality map: per 8 x 8 cell, the layer that shows most
-- (2 bits a cell, row by row, lowest bits first, as W02a writes it)
local function lowres(layers)
    local n = #layers
    local share = {}
    local rows = {}
    for cr = 0, 7 do
        local row = 0
        for cc = 0, 7 do
            for l = 1, n do share[l] = 0 end
            for pr = cr * 8, cr * 8 + 7 do
                for pc = cc * 8, cc * 8 + 7 do
                    local left = 1
                    for l = n, 2, -1 do
                        local v = layers[l].alpha:byte(pr * 64 + pc + 1) / 255 * left
                        share[l] = share[l] + v
                        left = left - v
                    end
                    share[1] = share[1] + left
                end
            end
            local best = 1
            for l = 2, n do if share[l] > share[best] + 1e-9 then best = l end end
            row = row + (best - 1) * 4 ^ cc
        end
        rows[cr + 1] = string.char(row % 256, math.floor(row / 256))
    end
    return table.concat(rows)
end

local function patch_chunk(B, c, big_alpha)
    local where = string.format("chunk (%d, %d)", c.ix, c.iy)
    local function sub(off, tag, need)
        local at = u32(B, 8 + off)
        if at == 0 or at + 8 + need > #B or tag_at(B, at) ~= tag then
            return nil, string.format("%s: no %s block where its header says (byte %d)", where, tag, at)
        end
        return at
    end
    local d = c.dirty or {}
    if d.heights then
        local at, why = sub(20, "MCVT", 580)
        if not at then return nil, why end
        local H = bw.new()
        for i = 1, 145 do H:f32(c.heights[i]) end
        B = put(B, at + 8, H:done())
    end
    if c.normals then
        local at, why = sub(24, "MCNR", 435)
        if not at then return nil, why end
        local bytes = { B:byte(at + 9, at + 8 + 435) }
        for i, n in pairs(c.normals) do
            for a = 1, 3 do bytes[(i - 1) * 3 + a] = n[a] % 256 end
        end
        local parts = {}
        for i = 1, 435 do parts[i] = string.char(bytes[i]) end
        B = put(B, at + 8, table.concat(parts))
    end
    if d.holes then
        B = put(B, 8 + 60, string.char(c.holes % 256, math.floor(c.holes / 256) % 256))
    end
    if not d.layers then return B end

    -- the layers and blend maps again, and what comes after them moved along
    local n = #c.layers
    if n < 1 or n > 4 then return nil, string.format("%s: %d layers (1 to 4 fit)", where, n) end
    local mcly, why = sub(28, "MCLY", 0)
    if not mcly then return nil, why end
    local mcly_end = mcly + 8 + u32(B, mcly + 4)
    local was = {}                                     -- each texture's flags and ground effect, as they were
    for l = 0, math.floor((mcly_end - mcly - 8) / 16) - 1 do
        local e = mcly + 8 + l * 16
        local tex = u32(B, e)
        if not was[tex] then was[tex] = { flags = u32(B, e + 4), effect = u32(B, e + 12) } end
    end
    local LY, maps, at = bw.new(), {}, 0
    for l = 1, n do
        local L = c.layers[l]
        local tex = L.texture_index - 1
        local w = was[tex] or { flags = 0, effect = 0 }
        local flags = bit.band(w.flags, bit.bnot(adt.MCLY_USE_ALPHA + MCLY_PACKED))
        local offset = 0
        if l > 1 then
            if type(L.alpha) ~= "string" or #L.alpha ~= 4096 then
                return nil, string.format("%s layer %d: its blend map isn't 4096 points", where, l)
            end
            flags = bit.bor(flags, adt.MCLY_USE_ALPHA)
            offset = at
            maps[#maps + 1] = encode_alpha(L.alpha, big_alpha)
            at = at + #maps[#maps]
        end
        LY:u32(tex):u32(flags % 4294967296):u32(offset):u32(w.effect)
    end
    local new_mcly = adt.block("MCLY", LY:done())
    local new_mcal = adt.block("MCAL", table.concat(maps))
    -- where MCAL was: the larger of its own size and the header's (offset
    -- 40, which counts its head), as the W client's reader takes it; a
    -- chunk with none gets it after MCLY
    local mcal = u32(B, 8 + 36)
    local regions
    if mcal ~= 0 and mcal + 8 <= #B and tag_at(B, mcal) == "MCAL" then
        local stop = math.min(#B, math.max(mcal + 8 + u32(B, mcal + 4), mcal + u32(B, 8 + 40)))
        if mcal < mcly_end and stop > mcly then
            return nil, string.format("%s: its MCLY and MCAL overlap", where)
        end
        regions = { { start = mcly, stop = mcly_end, data = new_mcly }, { start = mcal, stop = stop, data = new_mcal } }
    else
        regions = { { start = mcly, stop = mcly_end, data = new_mcly }, { start = mcly_end, stop = mcly_end, data = new_mcal } }
    end
    local first = math.min(regions[1].start, regions[2].start)
    local out, moved = splice(B, regions)
    if not out then return nil, where .. ": " .. moved end
    -- the header: its offsets moved along, then what the layers changed
    for _, f in ipairs(OFFSET_FIELDS) do
        local v = u32(B, 8 + f)
        if v ~= 0 and v > first then
            local q = moved(v)
            if not q or not tag_at(B, v):match("^MC%u%u$") then
                return nil, string.format("%s: header byte %d holds %d, which isn't where a block starts; "
                    .. "the blocks after its layers can't be moved past it", where, f, v)
            end
            out = put(out, 8 + f, le32(q))
        end
    end
    for _, g in ipairs(regions) do
        if g.data == new_mcly then out = put(out, 8 + 28, le32(g.new_at)) end
        if g.data == new_mcal then out = put(out, 8 + 36, le32(g.new_at)) end
    end
    out = put(out, 4, le32(#out - 8))
    out = put(out, 8, le32(bit.bor(u32(B, 8), adt.MCNK_NO_FIX_ALPHA) % 4294967296))
    out = put(out, 8 + 12, le32(n))
    out = put(out, 8 + 40, le32(#new_mcal))
    out = put(out, 8 + 64, lowres(c.layers))
    return out
end
-- }}}

-- {{{ wt.tile_bytes: the tile's file again, its edits in it
-- original: the tile's file as it was read; tile: its data (wowmap's,
-- edited); opts.big_alpha: the map's blend maps are 8 bits a point (its
-- WDT says). A tile with no edit gives the original back. Water is
-- editor/wowwater.lua's (MH2O: written again when a chunk's water was
-- edited or the ground under it moved; made, before the first MCNK, for
-- a tile that had none).
function wt.tile_bytes(original, tile, opts)
    opts = opts or {}
    local ww = require("editor.wowwater")
    local blocks, tail = walk(original)
    if not blocks then return nil, tail end
    -- placements (W10e, editor/wowplace.lua): the blocks and chunk references to write
    local plan
    if tile.places_dirty then
        if not opts.map then return nil, "the tile's placements were edited; writing them needs its map (opts.map)" end
        local why
        plan, why = require("editor.wowplace").plan(opts.map, original, tile)
        if not plan then return nil, why end
        tile.places_pending = plan.pending
    end
    local list, any_moved = {}, false          -- { old = the block or nil (made here), bytes }
    local mhdr, mcin, mh2o
    for _, b in ipairs(blocks) do
        local bytes = original:sub(b.at + 1, b.at + b.len)
        if b.tag == "MHDR" then mhdr = #list + 1 end
        if b.tag == "MCIN" then mcin = #list + 1 end
        if plan and plan.blocks[b.tag] then bytes = plan.blocks[b.tag] end
        if b.tag == "MTEX" then
            local names, data = 0, bytes:sub(9)
            for _ in data:gmatch("([^%z]*)%z") do names = names + 1 end
            if #tile.textures > names then
                local more = {}
                for i = names + 1, #tile.textures do more[#more + 1] = tile.textures[i] .. "\0" end
                if #data > 0 and data:sub(-1) ~= "\0" then
                    return nil, "MTEX's last name has no ending zero byte; a texture can't be added after it"
                end
                bytes = adt.block("MTEX", data .. table.concat(more))
            end
        elseif b.tag == "MH2O" then
            mh2o = true
            local why
            bytes, why = ww.mh2o_bytes(bytes, tile)
            if not bytes then return nil, why end
        elseif b.tag == "MCNK" and #bytes >= 8 + 128 then
            if not mh2o and ww.needs_block(tile) then
                -- water in a tile that had none: MH2O made, before the chunks
                mh2o = true
                local made, why = ww.mh2o_bytes(nil, tile)
                if not made then return nil, why end
                list[#list + 1] = { bytes = made, new = "MH2O" }
                any_moved = true
            end
            local ix, iy = u32(bytes, 12), u32(bytes, 16)
            local c = ix < 16 and iy < 16 and tile.chunks[iy * 16 + ix + 1]
            if c and (c.dirty or c.normals) then
                local why
                bytes, why = patch_chunk(bytes, c, opts.big_alpha)
                if not bytes then return nil, why end
            end
            local refs = plan and ix < 16 and iy < 16 and plan.refs[iy * 16 + ix + 1]
            if refs then
                local why
                bytes, why = require("editor.wowplace").patch_refs(bytes, refs)
                if not bytes then return nil, string.format("chunk (%d, %d): %s", ix, iy, why) end
            end
        end
        list[#list + 1] = { old = b, bytes = bytes }
        if #bytes ~= b.len then any_moved = true end
    end
    local rest = original:sub(tail + 1)
    if any_moved then
        -- where each block starts now
        local by_old, at, made_mh2o = {}, 0, nil
        for _, e in ipairs(list) do
            e.new_at = at
            if e.old then by_old[e.old.at] = e end
            if e.new == "MH2O" then made_mh2o = e end
            at = at + #e.bytes
        end
        if mhdr then
            local E = list[mhdr]
            local base_old, base_new = E.old.at + 8, E.new_at + 8
            local data = E.bytes
            for f = 1, 11 do                    -- MCIN MTEX MMDX MMID MWMO MWID MDDF MODF MFBO MH2O MTXF
                local v = u32(data, 8 + f * 4)
                if v ~= 0 then
                    local e = by_old[base_old + v]
                    if not e then
                        return nil, string.format("MHDR's field %d points at byte %d, where no block starts; "
                            .. "the tile's blocks can't be moved", f, base_old + v)
                    end
                    data = put(data, 8 + f * 4, le32(e.new_at - base_new))
                elseif f == 10 and made_mh2o then
                    data = put(data, 8 + f * 4, le32(made_mh2o.new_at - base_new))
                end
            end
            E.bytes = data
        elseif made_mh2o then
            return nil, "the tile has no MHDR to say where its new water is"
        end
        if mcin then
            local E = list[mcin]
            local data = E.bytes
            for k = 0, math.min(255, math.floor((#data - 8) / 16) - 1) do
                local o = 8 + k * 16
                local off = u32(data, o)
                if off ~= 0 then
                    local e = by_old[off]
                    if not e then
                        return nil, string.format("MCIN's entry %d points at byte %d, where no block starts", k, off)
                    end
                    data = put(data, o, le32(e.new_at))
                    data = put(data, o + 4, le32(u32(data, o + 4) + #e.bytes - e.old.len))
                end
            end
            E.bytes = data
        end
    end
    local out = {}
    for i, e in ipairs(list) do out[i] = e.bytes end
    return table.concat(out) .. rest
end
-- }}}

-- {{{ wt.save: the map's edited tiles over their files
local function read(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local d = f:read("*a")
    f:close()
    return d
end

local function clean(t)
    t.dirty = nil
    t.saves = (t.saves or 0) + 1
    for _, c in ipairs(t.chunks) do c.dirty, c.normals = nil, nil end
    if t.places_dirty then require("editor.wowplace").saved(t, t.places_pending) end
    t.places_pending = nil
end

function wt.edited(m)
    local out = {}
    for _, e in ipairs(m.tiles) do
        local t = m.read_tiles[e.tx .. "_" .. e.ty]
        if t and t.dirty then out[#out + 1] = t end
    end
    return out
end

-- every edited tile written over its file (the file as it stands is what
-- is patched), and the map's WDL with the far view of the tiles whose
-- ground or holes changed (editor/wowwdl.lua); the files written, or nil
-- and why (nothing written then)
function wt.save(m)
    local tl = require("editor.wowtiles")
    local changed = m.tiles_changed or {}          -- tiles added or taken off (W10d, editor/wowtiles.lua)
    local done, far = {}, {}
    for _, t in ipairs(wt.edited(m)) do
        local path = m.folder .. "/" .. t.file
        local original, why
        if t.made or t.kept then original, why = tl.base_bytes(m, t)
        else original = read(path) end
        if not original then return nil, why or ("can't read " .. path) end
        local bytes
        bytes, why = wt.tile_bytes(original, t, { big_alpha = m.big_alpha, map = m })
        if not bytes then return nil, t.file .. ": " .. why end
        done[#done + 1] = { t = t, path = path, bytes = bytes, file = t.file }
        local whole = changed[t.tx .. "_" .. t.ty]
        for _, c in ipairs(t.chunks) do
            if whole or (c.dirty and (c.dirty.heights or c.dirty.holes)) then far[#far + 1] = t break end
        end
    end
    local off = tl.taken_off(m)
    if next(changed) then
        local path = m.folder .. "/" .. m.wdt
        local original = read(path)
        if not original then return nil, "can't read " .. path end
        local bytes, why = tl.wdt_bytes(m, original)
        if not bytes then return nil, m.wdt .. ": " .. why end
        if bytes ~= original then done[#done + 1] = { path = path, bytes = bytes, file = m.wdt } end
    end
    if m.wdl and (#far > 0 or #off > 0) then
        local wdl = require("editor.wowwdl")
        local path = m.folder .. "/" .. m.wdl
        local original = read(path)
        if not original then return nil, "can't read " .. path end
        local bytes, why = wdl.patch(original, far)
        if bytes and #off > 0 then bytes, why = wdl.remove(bytes, off) end
        if not bytes then return nil, m.wdl .. ": " .. why end
        if bytes ~= original then done[#done + 1] = { path = path, bytes = bytes, file = m.wdl } end
    end
    local written = {}
    for _, d in ipairs(done) do
        local tmp = d.path .. ".new"
        local f = io.open(tmp, "wb")
        if not f then return nil, "can't write " .. tmp end
        f:write(d.bytes)
        f:close()
        local ok, err = os.rename(tmp, d.path)
        if not ok then return nil, err end
        written[#written + 1] = d.file
    end
    -- the files of the tiles taken off (unless a new tile took the name)
    for _, g in ipairs(off) do
        local path = m.folder .. "/" .. g.file
        local taken = false
        for _, e in ipairs(m.tiles) do if e.file:lower() == g.file:lower() then taken = true end end
        if not taken and read(path) then
            local ok, err = os.remove(path)
            if not ok then return nil, err end
            written[#written + 1] = g.file .. " (deleted)"
        end
    end
    for _, d in ipairs(done) do if d.t then clean(d.t) end end
    tl.saved(m)
    return written
end
-- }}}

-- {{{ undo: a chunk as it is now, and back
-- A snapshot holds the chunk's ground, its layers, which of them are
-- still to be written, and its tile's texture names. Put back after its
-- tile was saved, the chunk is written whole again (heights, holes,
-- layers) and its normals worked out again, since the file no longer
-- holds what the snapshot does.
function wt.snapshot(c)
    local h, layers, normals = {}, {}, nil
    for i = 1, 145 do h[i] = c.heights[i] end
    for l, L in ipairs(c.layers) do layers[l] = { texture = L.texture, texture_index = L.texture_index, alpha = L.alpha } end
    if c.normals then
        normals = {}
        for i, n in pairs(c.normals) do normals[i] = n end
    end
    local dirty
    if c.dirty then
        dirty = {}
        for k, v in pairs(c.dirty) do
            if type(v) == "table" then
                local cp = {}
                for i, x in pairs(v) do cp[i] = x end
                v = cp
            end
            dirty[k] = v
        end
    end
    local textures = {}
    for i, p in ipairs(c.tile.textures) do textures[i] = p end
    return { heights = h, holes = c.holes, layers = layers, normals = normals, dirty = dirty,
             textures = textures, saves = c.tile.saves or 0,
             water = require("editor.wowwater").copy(c.tile, c.iy * 16 + c.ix + 1) }
end

-- the chunk as the snapshot has it; m: its map
function wt.restore(m, c, s)
    for i = 1, 145 do c.heights[i] = s.heights[i] end
    c.holes = s.holes
    c.layers = {}
    for l, L in ipairs(s.layers) do c.layers[l] = { texture = L.texture, texture_index = L.texture_index, alpha = L.alpha } end
    local t = c.tile
    t.textures = {}
    for i, p in ipairs(s.textures) do t.textures[i] = p end
    require("editor.wowwater").put(t, c.iy * 16 + c.ix + 1, s.water or {})
    if (t.saves or 0) == s.saves then
        c.normals = s.normals
        c.dirty = nil
        if s.dirty then
            c.dirty = {}
            for k, v in pairs(s.dirty) do
                if type(v) == "table" then
                    local cp = {}
                    for i, x in pairs(v) do cp[i] = x end
                    v = cp
                end
                c.dirty[k] = v
            end
        end
    else
        c.dirty = { heights = true, holes = true, layers = #c.layers > 1 or nil, water = true }
        c.normals = nil
        local R, C = chunk_origin(t, c)
        local keys = {}
        for i = 1, 145 do if PR[i] % 2 == 0 then keys[(R + PR[i]) * KEY + C + PC[i]] = true end end
        renormal(m, keys)
    end
    t.dirty = t.places_dirty or nil                 -- (its placements, W10e, are their own undo's)
    for _, o in ipairs(t.chunks) do
        if o.dirty or o.normals then t.dirty = true break end
    end
end

-- the chunks a box of world yards falls on (read tiles only)
local function chunks_near(m, x, y, r)
    local out = {}
    local tiles = load_area(m, x, y, r) or {}
    for _, t in ipairs(tiles) do
        for _, c in ipairs(t.chunks) do
            local R, C = chunk_origin(t, c)
            local cx, cy = ORIGIN - R * CELL / 2, ORIGIN - C * CELL / 2
            if cx - CHUNK <= x + r and cx >= x - r and cy - CHUNK <= y + r and cy >= y - r then out[#out + 1] = c end
        end
    end
    return out
end
wt.chunks_near = chunks_near
-- }}}

-- {{{ wt.attach: the editor's strokes on a WoW map
-- E:wow_edit(dir) points the terrain tools at a WoW map of the project
-- (E:wow_edit(nil) back at the WC3 map); a stroke then works on that
-- map's tiles at world yards. The brush: brush.size in WC3 tile points
-- (one is a WoW cell, 4.17 yards) unless brush.wow_radius (yards);
-- brush.strength in WC3 units (W02's 1/30.72 yard each) unless
-- brush.wow_amount (yards); brush.wow_texture, the texture painted (a
-- path), else the tile's own texture number brush.texture + 1; paint
-- covers brush.wow_paint (0-1, else 0.5) a touch. water and dry (W10c,
-- editor/wowwater.lua): brush.wow_level, the surface (else 2 yards over
-- the ground where the stroke began), brush.wow_liquid, its kind (else 1,
-- water).
local TOOLS = { raise = true, lower = true, smooth = true, flatten = true, paint = true, hole = true, unhole = true,
                water = true, dry = true }
wt.TOOLS = TOOLS

function wt.attach(E)
    function E:wow_edit(dir)
        if not dir then self.wow_editing = nil return true end
        local m, why = self:wow_map(dir)
        if not m then return nil, why end
        local lib, lwhy = m:reader()
        if not lib then return nil, lwhy end
        self.wow_editing = m
        return m
    end

    function E:wow_stroke_begin(tool, x, y)
        tool = tool or self.tool
        local m = self.wow_editing
        if not m then return false end
        if not TOOLS[tool] then
            self:say("Not on a WoW map: " .. tostring(tool))
            return false
        end
        self.wow_stroke_now = { tool = tool, before = {}, list = {}, m = m }
        if x and tool == "flatten" then self.wow_stroke_now.flat = wt.ground(m, x, y) end
        if x and tool == "water" then
            local g = wt.ground(m, x, y)
            self.wow_stroke_now.level = self.brush.wow_level or (g and g + require("editor.wowwater").LEVEL_ABOVE)
        end
        return true
    end

    function E:wow_stroke(x, y)
        local s = self.wow_stroke_now
        if not s then return false end
        local m, b = s.m, self.brush
        local r = b.wow_radius or (b.size * CELL)
        -- every chunk the touch can change, as it was, the first time
        for _, c in ipairs(chunks_near(m, x, y, r + 2 * CELL)) do
            if not s.before[c] then
                s.before[c] = wt.snapshot(c)
                s.list[#s.list + 1] = c
            end
        end
        local amount = b.wow_amount or (b.strength * coords.YARDS_PER_UNIT)
        local got, why
        if s.tool == "raise" or s.tool == "lower" then
            got, why = wt[s.tool](m, x, y, { radius = r, amount = amount })
        elseif s.tool == "smooth" then
            got, why = wt.smooth(m, x, y, { radius = r })
        elseif s.tool == "flatten" then
            if not s.flat then s.flat = wt.ground(m, x, y) end
            got, why = wt.flatten(m, x, y, { radius = r, height = s.flat })
        elseif s.tool == "paint" then
            local tex = b.wow_texture
            if not tex then
                local c = chunks_near(m, x, y, 0)[1]
                tex = c and c.tile.textures[(b.texture or 0) + 1]
            end
            got, why = wt.paint(m, x, y, { radius = r, texture = tex, strength = b.wow_paint or 0.5 })
        elseif s.tool == "water" or s.tool == "dry" then
            local ww = require("editor.wowwater")
            if s.tool == "water" and not s.level then s.level = b.wow_level or ((wt.ground(m, x, y) or 0) + ww.LEVEL_ABOVE) end
            got, why = ww[s.tool](m, x, y, { radius = r, level = s.level, kind = b.wow_liquid })
        else
            got, why = wt.holes(m, x, y, { radius = r, on = s.tool == "hole" })
        end
        if not got then self:say(why) return false end
        if got.full and #got.full > 0 then
            self:say(string.format("%d chunks already have four textures", #got.full))
        end
        self.dirty.wow = true
        return true, got
    end

    function E:wow_stroke_end()
        local s = self.wow_stroke_now
        self.wow_stroke_now = nil
        if not s or #s.list == 0 then return nil end
        local after = {}
        for _, c in ipairs(s.list) do after[c] = wt.snapshot(c) end
        local me = self
        local function put_back(which)
            for _, c in ipairs(s.list) do wt.restore(s.m, c, which[c]) end
            me.dirty.wow = true
        end
        local names = { raise = "Raise", lower = "Lower", smooth = "Smooth", flatten = "Flatten", paint = "Paint",
                        hole = "Cut holes", unhole = "Fill holes", water = "Water", dry = "Dry" }
        local cmd = { name = names[s.tool] .. " (WoW map " .. s.m.directory .. ")",
                      redo = function() put_back(after) end, undo = function() put_back(s.before) end }
        self.history:record(cmd)
        return cmd.name
    end

    -- a tile added to the WoW map being edited, or taken off (W10d,
    -- editor/wowtiles.lua), as one step of the history: undo takes it off
    -- (puts it back) and its neighbours' edges as they were
    local function tile_step(me, m, tx, ty, name, act, unact)
        local tl = require("editor.wowtiles")
        -- the neighbours read first, so their edges are in the snapshot
        for dy = -1, 1 do
            for dx = -1, 1 do
                if (dx ~= 0 or dy ~= 0) and m.by_key[(tx + dx) .. "_" .. (ty + dy)] then
                    local got, why = m:tile(tx + dx, ty + dy)
                    if not got then return nil, why end
                    index_tile(m, got)
                end
            end
        end
        local list = tl.border_chunks(m, tx, ty)
        local before = {}
        for _, c in ipairs(list) do before[c] = wt.snapshot(c) end
        local state = {}
        local got, why = act(state)
        if not got then me:say(why) return nil, why end
        local after = {}
        for _, c in ipairs(list) do after[c] = wt.snapshot(c) end
        local function edges(which) for _, c in ipairs(list) do wt.restore(m, c, which[c]) end end
        me.history:record({ name = name .. " (WoW map " .. m.directory .. ")",
                            undo = function() unact(state) edges(before) me.dirty.wow = true end,
                            redo = function() act(state) edges(after) me.dirty.wow = true end })
        me.dirty.wow = true
        return got
    end

    -- state.gone: what taking it off kept (undo of the add), put back on redo
    function E:wow_add_tile(tx, ty, opts)
        local m = self.wow_editing
        if not m then return nil, "no WoW map is being edited (E:wow_edit)" end
        local tl = require("editor.wowtiles")
        return tile_step(self, m, tx, ty, string.format("Add tile %d, %d", tx, ty),
            function(state)
                if state.gone then return tl.put_back(m, state.gone) end
                return tl.add(m, tx, ty, opts)
            end,
            function(state) state.gone = tl.remove(m, tx, ty) end)
    end

    function E:wow_remove_tile(tx, ty)
        local m = self.wow_editing
        if not m then return nil, "no WoW map is being edited (E:wow_edit)" end
        local tl = require("editor.wowtiles")
        return tile_step(self, m, tx, ty, string.format("Take off tile %d, %d", tx, ty),
            function(state)
                local gone, why = tl.remove(m, tx, ty)
                state.gone = gone
                return gone, why
            end,
            function(state) tl.put_back(m, state.gone) end)
    end

    -- every opened WoW map's edited tiles, written over their files
    function E:wow_save()
        local all = {}
        for _, m in pairs(self.wow_opened or {}) do
            local written, why = wt.save(m)
            if not written then return nil, why end
            for _, f in ipairs(written) do all[#all + 1] = m.directory .. "/" .. f end
        end
        table.sort(all)
        if self.dirty then self.dirty.wow = false end
        return all
    end
end
-- }}}

-- {{{ for editor/wowwater.lua and editor/wowwdl.lua
wt.internal = { load_area = load_area, mark = mark, chunk_origin = chunk_origin, weight = weight,
                u32 = u32, u16 = u16, tag_at = tag_at, put = put, le32 = le32,
                index_tile = index_tile, renormal = renormal, read = read, KEY = KEY }
-- }}}

return wt

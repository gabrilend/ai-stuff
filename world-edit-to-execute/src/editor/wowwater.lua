--[[
Water on a WoW Map's Tiles (Issue W10c)

W10's "place liquids", without its window: water put on and taken off
a WoW map's tiles (editor/wowmap.lua reads them) as plain Lua, and the
tile's water block (MH2O) written again with the edits in it.

    ww.water(m, x, y, { radius, level, kind })   cells under the brush wet, their corners at level
    ww.dry(m, x, y, { radius, kind })            cells under the brush dry (of one kind, or all)

x, y and radius are world yards (as editor/wowterrain.lua's tools); a
radius of 0 is the one cell at the point. level is the surface's height
(else the ground at the point and 2 yards); kind is LiquidType.dbc's row
(1 water, the default; 2 ocean, 3 magma, 4 slime ...). Each returns {
cells, chunks, tiles = { "tx_ty" } }.

The water is wowmap's: a tile's liquids, each one layer of one chunk {
chunk, kind, col, row, w, h (the rectangle of cells it covers), wet (64
bytes, 1 a wet cell, row by row), height (81 corner heights, 9 x 9),
depth (81 bytes: yards x 9, as the W client measures it) }.

MH2O (as the W client's reader takes it, 020-adt.c, and W02a writes it):
256 heads of 12 bytes (where the chunk's layers are, how many, where its
attributes are; offsets from MH2O's data), each layer 24 bytes (kind u16,
vertex format u16, lowest and highest height, first column, first row,
width, height (u8 each), where its mask of wet cells is (0: all of the
rectangle), where its points are), the attributes 16 bytes (fishable
cells u64, deep cells u64), the mask (a bit a cell of the rectangle,
lowest first), the points ((w+1)(h+1) of them: format 0 a height (float)
each then a depth byte each; 1 a height and a picture position (4 bytes)
each; 2 a depth byte each; 3 a height, a picture position and a depth).

Written the way editor/wowterrain.lua writes ground: what an edit didn't
touch keeps its bytes.
  - A tile with no water edit: its MH2O as it was.
  - The ground moved under water: the depth bytes of the points whose
    ground moved, in place (formats 0, 2 and 3 hold depths; 1 none).
  - A chunk whose water was edited: its parts (layers, attributes, masks,
    points) replaced by the new water in W02a's form (format 0); a layer
    whose file layer of its kind was format 1 or 3 keeps that format
    (W10d), with its points' picture positions (see "picture positions"
    below); every other chunk's parts kept byte for byte, their offsets
    moved along.
    A chunk with water for the first time gets its parts at MH2O's end.
  - A tile with no MH2O and new water: one made (wowterrain puts it
    before the first MCNK and MHDR's field says where).
  An offset or a layer the writer can't account for refuses the write,
  saying which, rather than guessing.
]]

local ffi = require("ffi")
local bit = require("bit")
local coords = require("wowbuild.coords")
local adt = require("wowbuild.adt")
local bw = require("parsers.binwrite")
local wt = require("editor.wowterrain")

local ww = {}

local CHUNK, CELL, ORIGIN = coords.CHUNK, coords.CELL, coords.ORIGIN
ww.DEPTH_PER_YARD = 9          -- W02a's (wowbuild.terrain), from the W client's measurement
ww.WATER = 1                   -- LiquidType.dbc's "Water" in 3.3.5a
ww.LEVEL_ABOVE = 2             -- yards over the ground, when no level is given
local HEADS = 256 * 12
-- bytes a point, by vertex format; where its depth byte starts (points' bytes before it)
local POINT_BYTES = { [0] = 5, [1] = 8, [2] = 1, [3] = 9 }
local DEPTH_AFTER = { [0] = 4, [2] = 0, [3] = 8 }

local I = wt.internal
local u32, u16, put, le32 = I.u32, I.u16, I.put, I.le32
local cell = ffi.new("union { uint32_t u; float f; }")
local function f32(s, at) cell.u = u32(s, at) return cell.f end

-- {{{ the data: a tile's water by chunk
local function entries(t, k)                 -- k: 1-256
    local out = {}
    for _, q in ipairs(t.liquids) do if q.chunk == k then out[#out + 1] = q end end
    return out
end

local function copy(q)
    local h = {}
    for i = 1, 81 do h[i] = q.height[i] end
    return { chunk = q.chunk, kind = q.kind, col = q.col, row = q.row, w = q.w, h = q.h, wet = q.wet,
             height = h, depth = q.depth }
end

-- the water of chunk k, copied (for undo)
function ww.copy(t, k)
    local out = {}
    for _, q in ipairs(entries(t, k)) do out[#out + 1] = copy(q) end
    return out
end

-- chunk k's water made what list holds (copies), in the tile's order
function ww.put(t, k, list)
    local keep = {}
    for _, q in ipairs(t.liquids) do if q.chunk ~= k then keep[#keep + 1] = q end end
    for _, q in ipairs(list) do keep[#keep + 1] = copy(q) end
    -- by chunk, a chunk's layers in their order
    for i, q in ipairs(keep) do q.order_ = i end
    table.sort(keep, function(a, b) if a.chunk ~= b.chunk then return a.chunk < b.chunk end return a.order_ < b.order_ end)
    for _, q in ipairs(keep) do q.order_ = nil end
    t.liquids = keep
end

local function depth_of(surface, ground)
    local d = math.floor((surface - ground) * ww.DEPTH_PER_YARD + 0.5)
    return d < 0 and 0 or (d > 255 and 255 or d)
end

-- the rectangle of a layer's wet cells (nil when none)
local function rectangle(wet)
    local r0, r1, c0, c1 = 8, -1, 8, -1
    for r = 0, 7 do
        for c = 0, 7 do
            if wet[r * 8 + c + 1] == 1 then
                if r < r0 then r0 = r end
                if r > r1 then r1 = r end
                if c < c0 then c0 = c end
                if c > c1 then c1 = c end
            end
        end
    end
    if r1 < 0 then return nil end
    return c0, r0, c1 - c0 + 1, r1 - r0 + 1
end
-- }}}

-- {{{ the tools
-- the cells under the brush, by chunk: { { t, c, k, cells = { r * 8 + c } } }
local function cells_under(m, x, y, r)
    local tiles, why = I.load_area(m, x, y, r + CELL)
    if not tiles then return nil, why end
    local out = {}
    for _, t in ipairs(tiles) do
        for k, c in ipairs(t.chunks) do
            local R, C = I.chunk_origin(t, c)
            local cx, cy = ORIGIN - R * CELL / 2, ORIGIN - C * CELL / 2
            if cx - CHUNK <= x + r and cx >= x - r and cy - CHUNK <= y + r and cy >= y - r then
                local hits = {}
                for cr = 0, 7 do
                    for cc = 0, 7 do
                        local px, py = cx - (cr + 0.5) * CELL, cy - (cc + 0.5) * CELL
                        local inside
                        if r <= 0 then
                            inside = x <= cx - cr * CELL and x > cx - (cr + 1) * CELL and y <= cy - cc * CELL and y > cy - (cc + 1) * CELL
                        else
                            inside = (px - x) ^ 2 + (py - y) ^ 2 <= r * r
                        end
                        if inside then hits[#hits + 1] = cr * 8 + cc end
                    end
                end
                if #hits > 0 then out[#out + 1] = { t = t, c = c, k = k, cells = hits } end
            end
        end
    end
    return out
end

local function bytes_of(s)
    local t = {}
    for i = 1, #s do t[i] = s:byte(i) end
    return t
end
local function string_of(t)
    local parts = {}
    for i = 1, #t do parts[i] = string.char(t[i]) end
    return table.concat(parts)
end

local function summary(list)
    local tiles, seen, chunks, cells = {}, {}, 0, 0
    for _, e in ipairs(list) do
        chunks = chunks + 1
        cells = cells + e.n
        local key = e.t.tx .. "_" .. e.t.ty
        if not seen[key] then seen[key] = true tiles[#tiles + 1] = key end
    end
    table.sort(tiles)
    return { cells = cells, chunks = chunks, tiles = tiles }
end

function ww.water(m, x, y, o)
    o = o or {}
    local kind = o.kind or ww.WATER
    local level = o.level
    if not level then
        local g, why = wt.ground(m, x, y)
        if not g then return nil, why end
        level = g + ww.LEVEL_ABOVE
    end
    local under, why = cells_under(m, x, y, o.radius or 0)
    if not under then return nil, why end
    local done = {}
    for _, u in ipairs(under) do
        local t, c, k = u.t, u.c, u.k
        local q
        for _, e in ipairs(entries(t, k)) do if e.kind == kind then q = e break end end
        local fresh = q == nil
        if fresh then
            local h = {}
            for i = 1, 81 do h[i] = level end
            q = { chunk = k, kind = kind, col = 0, row = 0, w = 0, h = 0, wet = string.rep("\0", 64), height = h,
                  depth = string.rep("\255", 81) }
        end
        local wet, depth = bytes_of(q.wet), bytes_of(q.depth)
        local was_c, was_r, was_w, was_h = q.col, q.row, q.w, q.h
        local n = 0
        for _, cl in ipairs(u.cells) do
            local cr, cc = math.floor(cl / 8), cl % 8
            local changed = wet[cl + 1] ~= 1
            wet[cl + 1] = 1
            for dr = 0, 1 do
                for dc = 0, 1 do
                    local p = (cr + dr) * 9 + cc + dc + 1
                    if q.height[p] ~= level then changed = true end
                    q.height[p] = level
                    depth[p] = depth_of(level, c.z + c.heights[(cr + dr) * 17 + cc + dc + 1])
                end
            end
            if changed then n = n + 1 end
        end
        if n > 0 then
            local col, row, w, h = rectangle(wet)
            q.col, q.row, q.w, q.h = col, row, w, h
            -- corners new to the rectangle: their depth from their height
            for r = row, row + h do
                for cc = col, col + w do
                    local inside_was = not fresh and r >= was_r and r <= was_r + was_h and cc >= was_c and cc <= was_c + was_w
                    if not inside_was and depth[r * 9 + cc + 1] == 255 then
                        depth[r * 9 + cc + 1] = depth_of(q.height[r * 9 + cc + 1], c.z + c.heights[r * 17 + cc + 1])
                    end
                end
            end
            q.wet, q.depth = string_of(wet), string_of(depth)
            if fresh then
                local list = entries(t, k)
                list[#list + 1] = q
                ww.put(t, k, list)
            end
            I.mark(c, "water")
            done[#done + 1] = { t = t, n = n }
        end
    end
    return summary(done)
end

function ww.dry(m, x, y, o)
    o = o or {}
    local under, why = cells_under(m, x, y, o.radius or 0)
    if not under then return nil, why end
    local done = {}
    for _, u in ipairs(under) do
        local t, c, k = u.t, u.c, u.k
        local list, n = entries(t, k), 0
        local keep = {}
        for _, q in ipairs(list) do
            if not o.kind or q.kind == o.kind then
                local wet = bytes_of(q.wet)
                for _, cl in ipairs(u.cells) do
                    if wet[cl + 1] == 1 then wet[cl + 1] = 0 n = n + 1 end
                end
                q.wet = string_of(wet)
                local col, row, w, h = rectangle(wet)
                if col then
                    q.col, q.row, q.w, q.h = col, row, w, h
                    keep[#keep + 1] = q
                end
            else
                keep[#keep + 1] = q
            end
        end
        if n > 0 then
            ww.put(t, k, keep)
            I.mark(c, "water")
            done[#done + 1] = { t = t, n = n }
        end
    end
    return summary(done)
end
-- }}}

-- {{{ MH2O's layout: each chunk's layers and the parts they point at
-- D: MH2O's data. { [1..256] = { info, count, attr, layers = { { e, kind,
-- fmt, lo, hi, col, row, w, h, ob, ov, depth_at } }, parts = { { start, stop } } } }
function ww.layout(D)
    if #D < HEADS then return nil, string.format("MH2O is %d bytes, shorter than its 256 heads", #D) end
    local L = {}
    for k = 0, 255 do
        local info, count, attr = u32(D, k * 12), u32(D, k * 12 + 4), u32(D, k * 12 + 8)
        local ch = { info = info, count = count, attr = attr, layers = {}, parts = {} }
        local function part(a, b, what)
            if a < HEADS or b > #D then
                error(string.format("chunk %d's water %s (bytes %d-%d) is outside MH2O's data", k, what, a, b), 0)
            end
            ch.parts[#ch.parts + 1] = { start = a, stop = b }
        end
        local ok, err = pcall(function()
            if count > 0 then
                part(info, info + 24 * count, "layers")
                for l = 0, count - 1 do
                    local e = info + l * 24
                    local q = { e = e, kind = u16(D, e), fmt = u16(D, e + 2), lo = f32(D, e + 4), hi = f32(D, e + 8),
                                col = D:byte(e + 13), row = D:byte(e + 14), w = D:byte(e + 15), h = D:byte(e + 16),
                                ob = u32(D, e + 16), ov = u32(D, e + 20) }
                    local np = (q.w + 1) * (q.h + 1)
                    if q.ob ~= 0 then part(q.ob, q.ob + math.ceil(q.w * q.h / 8), "mask") end
                    if q.ov ~= 0 then
                        if POINT_BYTES[q.fmt] then
                            part(q.ov, q.ov + np * POINT_BYTES[q.fmt], "points")
                            if DEPTH_AFTER[q.fmt] then q.depth_at = q.ov + np * DEPTH_AFTER[q.fmt] end
                        else
                            q.unknown = true
                        end
                    end
                    ch.layers[#ch.layers + 1] = q
                end
            end
            if attr ~= 0 then part(attr, attr + 16, "attributes") end
        end)
        if not ok then return nil, err end
        L[k + 1] = ch
    end
    return L
end
-- }}}

-- {{{ a chunk's water in W02a's form, its parts from P (offsets from MH2O's data)
local function pad4(s) return s .. string.rep("\0", (4 - #s % 4) % 4) end

-- carry: per layer of list, nil (W02a's format 0) or { fmt = 1 or 3, uv = {
-- [r * 9 + c + 1] = { u, v } }, fit = function(r, c) -> u, v } (W10d: the
-- format the file's layer had, its picture positions kept)
local function chunk_bytes(list, P, deep_lo, deep_hi, carry)
    local n = #list
    if n == 0 then return "", 0, 0, 0 end
    local info_at, attr_at = P, P + 24 * n
    local at = attr_at + 16
    local infos, bodies = {}, {}
    local fish = {}
    for li, q in ipairs(list) do
        local wet = bytes_of(q.wet)
        local all, bits = true, {}
        for r = 0, q.h - 1 do
            for c = 0, q.w - 1 do
                local w = wet[(q.row + r) * 8 + q.col + c + 1] == 1 and 1 or 0
                bits[#bits + 1] = w
                if w == 0 then all = false else fish[(q.row + r) * 8 + q.col + c] = true end
            end
        end
        local mask = ""
        if not all then
            local bytes = {}
            for b = 0, #bits - 1, 8 do
                local v = 0
                for k = 0, 7 do v = v + (bits[b + k + 1] or 0) * 2 ^ k end
                bytes[#bytes + 1] = string.char(v)
            end
            mask = pad4(table.concat(bytes))
        end
        local mask_at = all and 0 or at
        local vert_at = at + #mask
        local cf = carry and carry[li]
        local fmt = cf and cf.fmt or 0
        local V, UV, D = bw.new(), bw.new(), {}
        local lo, hi = math.huge, -math.huge
        for r = q.row, q.row + q.h do
            for c = q.col, q.col + q.w do
                local h = q.height[r * 9 + c + 1]
                V:f32(h)
                D[#D + 1] = string.char(q.depth:byte(r * 9 + c + 1))
                if cf then
                    local kept = cf.uv[r * 9 + c + 1]
                    local u, v
                    if kept then u, v = kept[1], kept[2] else u, v = cf.fit(r, c) end
                    UV:u16(u):u16(v)
                end
                if h < lo then lo = h end
                if h > hi then hi = h end
            end
        end
        local verts
        if fmt == 1 then verts = pad4(V:done() .. UV:done())
        elseif fmt == 3 then verts = pad4(V:done() .. UV:done() .. table.concat(D))
        else verts = pad4(V:done() .. table.concat(D)) end
        infos[#infos + 1] = bw.new():u16(q.kind):u16(fmt):f32(lo):f32(hi)
            :u8(q.col):u8(q.row):u8(q.w):u8(q.h):u32(mask_at):u32(vert_at):done()
        bodies[#bodies + 1] = mask .. verts
        at = vert_at + #verts
    end
    local fl, fh = 0, 0
    for b in pairs(fish) do
        if b < 32 then fl = fl + 2 ^ b else fh = fh + 2 ^ (b - 32) end
    end
    local attr = bw.new():u32(fl):u32(fh):u32(bit.band(deep_lo or 0, fl) % 4294967296)
        :u32(bit.band(deep_hi or 0, fh) % 4294967296):done()
    return table.concat(infos) .. attr .. table.concat(bodies), info_at, n, attr_at
end
-- }}}

-- {{{ a layer's picture positions kept (W10d)
-- Formats 1 and 3 give each point a picture position (two u16: where on
-- the liquid's texture the point is, which the client moves to make
-- magma and slime flow). An edited layer that had one keeps its format:
-- a point the file has keeps its position; a point new to the layer gets
-- the position the layer's own points lie on (a plane fitted to them, by
-- least squares over the chunk's 9 x 9 corners), else UV_STEP a cell.
ww.UV_STEP = 2                 -- unchecked: a guess, used only for a layer with no positions at all

local function plane(uv)
    local n, sc, sr, scc, srr, scr, su, sv, suc, sur, svc, svr = 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    for p, e in pairs(uv) do
        local r, c = math.floor((p - 1) / 9), (p - 1) % 9
        n = n + 1
        sc, sr, scc, srr, scr = sc + c, sr + r, scc + c * c, srr + r * r, scr + c * r
        su, sv, suc, sur, svc, svr = su + e[1], sv + e[2], suc + e[1] * c, sur + e[1] * r, svc + e[2] * c, svr + e[2] * r
    end
    local function clamp(x)
        x = math.floor(x + 0.5)
        return x < 0 and 0 or (x > 65535 and 65535 or x)
    end
    if n == 0 then
        return function(r, c) return clamp(c * ww.UV_STEP), clamp(r * ww.UV_STEP) end
    end
    -- solve [n sc sr; sc scc scr; sr scr srr] [a b d] = [s sc' sr'] for each of u, v
    local A = { { n, sc, sr }, { sc, scc, scr }, { sr, scr, srr } }
    local function det3(m)
        return m[1][1] * (m[2][2] * m[3][3] - m[2][3] * m[3][2]) - m[1][2] * (m[2][1] * m[3][3] - m[2][3] * m[3][1])
            + m[1][3] * (m[2][1] * m[3][2] - m[2][2] * m[3][1])
    end
    local D = det3(A)
    local function solve(b)
        if math.abs(D) < 1e-9 then return { b[1] / n, 0, 0 } end      -- the points on one line: their mean
        local out = {}
        for k = 1, 3 do
            local M = { { A[1][1], A[1][2], A[1][3] }, { A[2][1], A[2][2], A[2][3] }, { A[3][1], A[3][2], A[3][3] } }
            for i = 1, 3 do M[i][k] = b[i] end
            out[k] = det3(M) / D
        end
        return out
    end
    local U, V = solve({ su, suc, sur }), solve({ sv, svc, svr })
    return function(r, c) return clamp(U[1] + U[2] * c + U[3] * r), clamp(V[1] + V[2] * c + V[3] * r) end
end

-- for each layer of list, the file's layer of its kind (the first of that
-- kind for the first, ...): its format and picture positions when it had them
local function carried(D, ch, list)
    local used, out = {}, {}
    for n, q in ipairs(list) do
        local f
        for _, g in ipairs(ch.layers) do
            if g.kind == q.kind and not used[g] then f = g used[g] = true break end
        end
        if f and (f.fmt == 1 or f.fmt == 3) then
            local uv = {}
            if f.ov ~= 0 then
                local base, i = f.ov + (f.w + 1) * (f.h + 1) * 4, 0
                for r = 0, f.h do
                    for c = 0, f.w do
                        uv[(f.row + r) * 9 + f.col + c + 1] = { u16(D, base + i * 4), u16(D, base + i * 4 + 2) }
                        i = i + 1
                    end
                end
            end
            out[n] = { fmt = f.fmt, uv = uv, fit = plane(uv) }
        end
    end
    return out
end
ww.plane = plane
-- }}}

-- {{{ ww.mh2o_bytes: the tile's MH2O block again (block nil: one made)
-- whether the tile needs an MH2O it hasn't got
function ww.needs_block(tile)
    for _, c in ipairs(tile.chunks) do
        if c.dirty and c.dirty.water and #entries(tile, c.iy * 16 + c.ix + 1) > 0 then return true end
    end
    return false
end

function ww.mh2o_bytes(block, tile)
    local D = block and block:sub(9) or string.rep("\0", HEADS)
    local edited, refresh = {}, {}
    for k, c in ipairs(tile.chunks) do
        if c.dirty and c.dirty.water then edited[k] = true
        elseif c.dirty and c.dirty.points and #entries(tile, k) > 0 then refresh[k] = true end
    end
    if not next(edited) and not next(refresh) then return block end
    local L, why = ww.layout(D)
    if not L then return nil, why end

    -- the ground moved under water: those points' depths (the data's, and
    -- the file's in place where its format holds them)
    for k, c in ipairs(tile.chunks) do
        local pts = c.dirty and c.dirty.points
        local list = pts and entries(tile, k) or {}
        for l, q in ipairs(list) do
            local depth, any = bytes_of(q.depth), false
            for r = q.row, q.row + q.h do
                for cc = q.col, q.col + q.w do
                    if pts[r * 17 + cc + 1] then
                        depth[r * 9 + cc + 1] = depth_of(q.height[r * 9 + cc + 1], c.z + c.heights[r * 17 + cc + 1])
                        any = true
                    end
                end
            end
            if any then q.depth = string_of(depth) end
            if refresh[k] then
                local f = L[k].layers[l]
                if not f or #L[k].layers ~= #list then
                    return nil, string.format("chunk %d: %d water layers in the file, %d read", k - 1, #L[k].layers, #list)
                end
                if any and f.depth_at then
                    local np = 0
                    for r = 0, f.h do
                        for cc = 0, f.w do
                            local i = (f.row + r) * 17 + f.col + cc + 1
                            if pts[i] then D = put(D, f.depth_at + np, string.char(depth[(f.row + r) * 9 + f.col + cc + 1])) end
                            np = np + 1
                        end
                    end
                end
            end
        end
    end
    if not next(edited) then return adt.block("MH2O", D) end

    -- every part, by owner, to see that an edited chunk's own no one else's
    local owner = {}
    for k = 1, 256 do for _, p in ipairs(L[k].parts) do owner[#owner + 1] = { k = k, p = p } end end
    local regions = {}
    for k in pairs(edited) do
        local ch = L[k]
        for _, q in ipairs(ch.layers) do
            if q.unknown then
                return nil, string.format("chunk %d's water has a vertex format %d this writer doesn't know; "
                    .. "its parts can't be replaced", k - 1, q.fmt)
            end
        end
        -- its parts, sorted, with zero padding (under 4 bytes) between them taken in
        local parts = {}
        for _, p in ipairs(ch.parts) do parts[#parts + 1] = { start = p.start, stop = p.stop } end
        table.sort(parts, function(a, b) return a.start < b.start end)
        local merged = {}
        for _, p in ipairs(parts) do
            local last = merged[#merged]
            if last and p.start <= last.stop then
                if p.stop > last.stop then last.stop = p.stop end
            elseif last and p.start - last.stop < 4 and D:sub(last.stop + 1, p.start) == string.rep("\0", p.start - last.stop) then
                last.stop = p.stop
            else
                merged[#merged + 1] = p
            end
        end
        -- a trailing pad of W02a's form, taken in too
        local last = merged[#merged]
        if last then
            local pad = (4 - last.stop % 4) % 4
            if pad > 0 and last.stop + pad <= #D and D:sub(last.stop + 1, last.stop + pad) == string.rep("\0", pad) then
                local free = true
                for _, o in ipairs(owner) do
                    if o.k ~= k and o.p.start < last.stop + pad and o.p.stop > last.stop then free = false end
                end
                if free then last.stop = last.stop + pad end
            end
        end
        for _, g in ipairs(merged) do
            for _, o in ipairs(owner) do
                if o.k ~= k and o.p.start < g.stop and o.p.stop > g.start then
                    return nil, string.format("chunk %d's water shares bytes %d-%d with chunk %d's; its parts can't be replaced",
                        k - 1, g.start, g.stop, o.k - 1)
                end
            end
        end
        local deep_lo, deep_hi = 0, 0
        if ch.attr ~= 0 then deep_lo, deep_hi = u32(D, ch.attr + 8), u32(D, ch.attr + 12) end
        local list = entries(tile, k)
        local carry = carried(D, ch, list)
        local len = #(chunk_bytes(list, 0, deep_lo, deep_hi, carry))
        local first = merged[1] or { start = #D, stop = #D }
        local function made(at)
            local bytes, info_at, n, attr_at = chunk_bytes(list, at, deep_lo, deep_hi, carry)
            edited[k] = { info = info_at, count = n, attr = attr_at }
            return bytes
        end
        regions[#regions + 1] = { start = first.start, stop = first.stop, data = made, len = len, seq = k }
        for i = 2, #merged do regions[#regions + 1] = { start = merged[i].start, stop = merged[i].stop, data = "", seq = k } end
    end
    local out, moved = wt.splice(D, regions)
    if not out then return nil, "MH2O: " .. moved end
    -- the heads, and the unedited layers' offsets, where their parts are now
    local function at(p, what, k)
        local q = moved(p)
        if not q then error(string.format("chunk %d's water %s (byte %d) is inside a replaced part", k - 1, what, p), 0) end
        return q
    end
    local ok, err = pcall(function()
        for k = 1, 256 do
            local h = (k - 1) * 12
            local e = edited[k]
            if e then
                if e == true then e = { info = 0, count = 0, attr = 0 } end      -- edited to no water, nowhere to put it
                if e.count == 0 then e.info, e.attr = 0, 0 end
                out = put(out, h, le32(e.info) .. le32(e.count) .. le32(e.attr))
            else
                local ch = L[k]
                if ch.count > 0 then out = put(out, h, le32(at(ch.info, "layers", k))) end
                if ch.attr ~= 0 then out = put(out, h + 8, le32(at(ch.attr, "attributes", k))) end
                for _, q in ipairs(ch.layers) do
                    local e2 = at(q.e, "layer", k)
                    if q.ob ~= 0 then out = put(out, e2 + 16, le32(at(q.ob, "mask", k))) end
                    if q.ov ~= 0 then out = put(out, e2 + 20, le32(at(q.ov, "points", k))) end
                end
            end
        end
    end)
    if not ok then return nil, err end
    return adt.block("MH2O", out)
end
-- }}}

return ww

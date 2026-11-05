--[[
Tiles Added to and Taken Off a WoW Map (Issue W10d)

Which tiles a WoW map has is its WDT's to say (MAIN: a flag a tile, 64 x
64; editor/wowmap.lua reads the list through the W client's wdt_read).
This module adds a tile next to the map's others and takes one off, as
plain Lua on the map wowmap.open gives, and editor/wowterrain.lua's save
writes the change: the tile's file, its MAIN flag in the WDT (patched in
place: the one bit, nothing else), its far view in the WDL.

    local tiles = require("editor.wowtiles")
    local t, why = tiles.add(m, tx, ty, { height = 12 })     -- flat, 12 yards
    local t, why = tiles.add(m, tx, ty, { texture = path })  -- its neighbours' edges, carried across
    local gone, why = tiles.remove(m, tx, ty)                -- off the map (the file goes at the save)
    tiles.put_back(m, gone)                                   -- undo of remove (and redo of add)

A new tile:
  - its ground: flat at opts.height, or (no height) made to meet its
    neighbours: each side a neighbour shares is that neighbour's edge,
    point for point; a side with none runs straight between its corners
    (a corner no tile shares takes the corners beside it); inside, a
    Coons patch of the four sides (each point the blend of the sides
    across from it, less the blend of the corners), so the ground runs
    smoothly from each edge to the one across. Middles are their four
    corners' mean (W02a's rule), each chunk's base its lowest point.
  - Points it shares with a tile already there keep that tile's height
    in both modes, so the ground stays joined (a flat tile next to higher
    ground rises to it within its first cell).
  - Normals by W02a's rule (editor/wowterrain.lua), its neighbours'
    edge points' again (they had none beyond their edge before).
  - One texture: opts.texture, else the first texture of a neighbour
    (one at its sides first); no holes, no shadow, no tints, no water,
    nothing placed.
  - Written at the save by W02a's tile writer (wowbuild/adt.lua), then
    patched with whatever was painted, cut or watered on it before then,
    as an edited tile is.

A tile taken off: its points leave the map's shared grid, its
neighbours' edge normals are worked out again (one-sided now, as at the
map's edge). At the save its file is deleted, its MAIN flag cleared and
its far view (MARE, MAHO) taken out of the WDL, MAOF's later offsets
moved along. Its data and its file's bytes are kept in what remove
returns, so put_back gives it back whole, before or after a save.

A tile can't be added where the map has one, outside 0-63, or where a
file of that name is that the WDT doesn't list (it would be written over).
]]

local ffi = require("ffi")
local bit = require("bit")
local coords = require("wowbuild.coords")
local adt = require("wowbuild.adt")
local wt = require("editor.wowterrain")

local tiles = {}

local TILE, CHUNK, CELL, ORIGIN = coords.TILE, coords.CHUNK, coords.CELL, coords.ORIGIN
local I = wt.internal
local KEY = I.KEY
local PR, PC = wt.POINT_ROW, wt.POINT_COLUMN
local ZEROS = string.rep("\0", 4096)

local function name_of(m, tx, ty) return string.format("%s_%d_%d.adt", m.directory, tx, ty) end
local function exists(path)
    local f = io.open(path, "rb")
    if f then f:close() return true end
    return false
end

-- {{{ the map's list
local function register(m, t, entry)
    local key = t.tx .. "_" .. t.ty
    entry = entry or { tx = t.tx, ty = t.ty, file = t.file }
    entry.missing = nil
    m.tiles[#m.tiles + 1] = entry
    table.sort(m.tiles, function(a, b) if a.ty ~= b.ty then return a.ty < b.ty end return a.tx < b.tx end)
    m.by_key[key] = entry
    m.read_tiles[key] = t
    m.tiles_changed = m.tiles_changed or {}
    m.tiles_changed[key] = true
    return entry
end

local function unregister(m, tx, ty)
    local key = tx .. "_" .. ty
    local entry = m.by_key[key]
    for i, e in ipairs(m.tiles) do if e == entry then table.remove(m.tiles, i) break end end
    m.by_key[key] = nil
    m.read_tiles[key] = nil
    for i, e in ipairs(m.missing or {}) do if e == entry then table.remove(m.missing, i) break end end
    m.tiles_changed = m.tiles_changed or {}
    m.tiles_changed[key] = true
    return entry
end

-- the 8 tiles round (tx, ty) the map has, read and on the shared grid
local function neighbours(m, tx, ty)
    local out = {}
    for dy = -1, 1 do
        for dx = -1, 1 do
            local x, y = tx + dx, ty + dy
            if (dx ~= 0 or dy ~= 0) and m.by_key[x .. "_" .. y] then
                local t, why = m:tile(x, y)
                if not t then return nil, why end
                I.index_tile(m, t)
                out[#out + 1] = { t = t, dx = dx, dy = dy }
            end
        end
    end
    return out
end

-- the corner keys round a tile's edge (on the map's half-cell grid: a tile
-- is 128 cells, 256 half cells, a side)
local SIDE = 128                       -- cells a tile side; its corners 0-128
local function edge_keys(tx, ty)
    local R0, C0 = ty * 2 * SIDE, tx * 2 * SIDE
    local out = {}
    for n = 0, SIDE do
        out[R0 * KEY + C0 + 2 * n] = true
        out[(R0 + 2 * SIDE) * KEY + C0 + 2 * n] = true
        out[(R0 + 2 * n) * KEY + C0] = true
        out[(R0 + 2 * n) * KEY + C0 + 2 * SIDE] = true
    end
    return out
end
-- }}}

-- {{{ tiles.add
-- the 129 x 129 corner heights of a new tile at (tx, ty): H[r * 129 + c]
local W1 = SIDE + 1
local function ground(m, tx, ty, o, near)
    local R0, C0 = ty * 2 * SIDE, tx * 2 * SIDE
    local function known(r, c)
        local e = m.points and m.points[(R0 + 2 * r) * KEY + C0 + 2 * c]
        return e and (e[1].z + e[1].heights[e[2]]) or nil
    end
    -- the points it shares with a tile already there
    local H, shared = {}, {}
    for r = 0, SIDE do
        for c = 0, SIDE do
            local h = (r == 0 or r == SIDE or c == 0 or c == SIDE) and known(r, c) or nil
            if h then shared[r * W1 + c] = h end
        end
    end
    if o.height then
        for i = 0, W1 * W1 - 1 do H[i] = shared[i] or o.height end
        return H
    end
    -- the sides: a neighbour's edge where there is one
    local side = {}
    for _, n in ipairs(near) do
        if n.dx == 0 and n.dy == -1 then side.N = true end
        if n.dx == 0 and n.dy == 1 then side.S = true end
        if n.dx == -1 and n.dy == 0 then side.W = true end
        if n.dx == 1 and n.dy == 0 then side.E = true end
    end
    -- the corners: shared, else the shared corners beside it, else all shared ones'
    local K = { NW = shared[0], NE = shared[SIDE], SW = shared[SIDE * W1], SE = shared[SIDE * W1 + SIDE] }
    local beside = { NW = { "NE", "SW" }, NE = { "NW", "SE" }, SW = { "NW", "SE" }, SE = { "NE", "SW" } }
    local fill = {}
    for name, b in pairs(beside) do
        if not K[name] then
            local sum, n = 0, 0
            for _, other in ipairs(b) do if K[other] then sum, n = sum + K[other], n + 1 end end
            if n > 0 then fill[name] = sum / n end
        end
    end
    for name, v in pairs(fill) do K[name] = v end
    local sum, n = 0, 0
    for _, name in ipairs({ "NW", "NE", "SW", "SE" }) do if K[name] then sum, n = sum + K[name], n + 1 end end
    if n == 0 then return nil, "no neighbour to match" end
    for _, name in ipairs({ "NW", "NE", "SW", "SE" }) do K[name] = K[name] or sum / n end
    local function edge(sd, a, b, at)
        if side[sd] then
            local r, c
            if sd == "N" then r, c = 0, at elseif sd == "S" then r, c = SIDE, at
            elseif sd == "W" then r, c = at, 0 else r, c = at, SIDE end
            local h = shared[r * W1 + c]
            if h then return h end
        end
        return a + (b - a) * at / SIDE
    end
    local N, S, W, E = {}, {}, {}, {}
    for i = 0, SIDE do
        N[i] = edge("N", K.NW, K.NE, i)
        S[i] = edge("S", K.SW, K.SE, i)
        W[i] = edge("W", K.NW, K.SW, i)
        E[i] = edge("E", K.NE, K.SE, i)
    end
    -- a Coons patch: each side blended toward the one across, less the corners' blend
    for r = 0, SIDE do
        local v = r / SIDE
        for c = 0, SIDE do
            local u = c / SIDE
            local h = (1 - v) * N[c] + v * S[c] + (1 - u) * W[r] + u * E[r]
                - ((1 - u) * (1 - v) * K.NW + u * (1 - v) * K.NE + (1 - u) * v * K.SW + u * v * K.SE)
            H[r * W1 + c] = shared[r * W1 + c] or h
        end
    end
    return H
end

function tiles.add(m, tx, ty, o)
    o = o or {}
    if type(tx) ~= "number" or type(ty) ~= "number" or tx ~= math.floor(tx) or ty ~= math.floor(ty)
        or tx < 0 or tx > 63 or ty < 0 or ty > 63 then
        return nil, string.format("tile %s, %s: tiles are numbered 0 to 63", tostring(tx), tostring(ty))
    end
    local key = tx .. "_" .. ty
    if m.by_key[key] then return nil, string.format("%s already has tile %d, %d", m.directory, tx, ty) end
    local file = name_of(m, tx, ty)
    for _, u in ipairs(m.unlisted or {}) do
        if u.tx == tx and u.ty == ty then file = u.file end
    end
    local gone = tiles.off_at(m, key)
    if exists(m.folder .. "/" .. file) and not (gone and not gone.saved) then
        return nil, string.format("%s is there already, though the WDT doesn't list it; "
            .. "take it away (or out of the folder) first", file)
    end
    local lib, lwhy = m:reader()
    if not lib then return nil, lwhy end
    local near, why = neighbours(m, tx, ty)
    if not near then return nil, why end
    if not o.height and #near == 0 then
        return nil, string.format("tile %d, %d has no neighbour to match; give it a height", tx, ty)
    end
    local texture = o.texture
    if not texture then
        table.sort(near, function(a, b) return (a.dx == 0 or a.dy == 0) and not (b.dx == 0 or b.dy == 0) end)
        for _, n in ipairs(near) do
            local c = n.t.chunks[1]
            texture = c and c.layers[1] and c.layers[1].texture
            if texture then break end
        end
    end
    if type(texture) ~= "string" or texture == "" then
        return nil, "which texture should the new tile have (opts.texture, a path)?"
    end
    local H, gwhy = ground(m, tx, ty, o, near)
    if not H then return nil, gwhy end

    local t = { tx = tx, ty = ty, file = file, textures = { texture }, chunks = {}, doodads = {}, buildings = {},
                liquids = {}, models = {}, building_models = {}, made = true, dirty = true }
    local function corner(r, c) return H[r * W1 + c] end
    for iy = 0, 15 do
        for ix = 0, 15 do
            local abs, base = {}, math.huge
            for i = 1, 145 do
                local pr, pc = iy * 16 + PR[i], ix * 16 + PC[i]        -- half cells from the tile's corner
                local h
                if pr % 2 == 0 then
                    h = corner(pr / 2, pc / 2)
                else
                    local r, c = (pr - 1) / 2, (pc - 1) / 2
                    h = (corner(r, c) + corner(r, c + 1) + corner(r + 1, c) + corner(r + 1, c + 1)) / 4
                end
                abs[i] = h
                if h < base then base = h end
            end
            local heights = {}
            for i = 1, 145 do heights[i] = abs[i] - base end
            local tint = {}
            for i = 1, 145 do tint[i] = { 127, 127, 127 } end
            t.chunks[iy * 16 + ix + 1] = {
                ix = ix, iy = iy, x = ORIGIN - (ty * 16 + iy) * CHUNK, y = ORIGIN - (tx * 16 + ix) * CHUNK, z = base,
                heights = heights, holes = 0, layers = { { texture = texture, texture_index = 1 } },
                shadow = ZEROS, tint = tint, dirty = { heights = true, holes = true },
            }
        end
    end
    register(m, t)
    I.index_tile(m, t)
    -- every corner's normal (and with them the middles'), its neighbours' edges too
    local keys = {}
    for r = 0, SIDE do for c = 0, SIDE do keys[(ty * 2 * SIDE + 2 * r) * KEY + tx * 2 * SIDE + 2 * c] = true end end
    I.renormal(m, keys)
    return t
end
-- }}}

-- {{{ tiles.remove, tiles.put_back
-- the latest tile taken off at key whose file the last save didn't delete,
-- else any taken off there
function tiles.off_at(m, key)
    local best
    for g in pairs(m.off or {}) do
        if g.key == key and (not best or (best.saved and not g.saved)) then best = g end
    end
    return best
end

local function unindex(m, t)
    if not t.indexed then return end
    for _, c in ipairs(t.chunks) do
        local R, C = I.chunk_origin(t, c)
        for i = 1, 145 do
            local key = (R + PR[i]) * KEY + C + PC[i]
            local e = m.points[key]
            if e then
                local keep = {}
                for n = 1, #e, 2 do
                    if e[n] ~= c then keep[#keep + 1] = e[n] keep[#keep + 1] = e[n + 1] end
                end
                m.points[key] = #keep > 0 and keep or nil
            end
        end
    end
    t.indexed = nil
end

-- what is left of the shared grid on the tile's edge: its normals again
local function rejoin(m, tx, ty)
    local keys = {}
    for key in pairs(edge_keys(tx, ty)) do if m.points[key] then keys[key] = true end end
    I.renormal(m, keys)
end

function tiles.remove(m, tx, ty)
    local key = tx .. "_" .. ty
    local entry = m.by_key[key]
    if not entry then return nil, string.format("%s has no tile %d, %d", m.directory, tx, ty) end
    local t
    if not entry.missing then
        local lib, lwhy = m:reader()
        if not lib then return nil, lwhy end
        local near, why = neighbours(m, tx, ty)
        if not near then return nil, why end
        t, why = m:tile(tx, ty)
        if not t then return nil, why end
        I.index_tile(m, t)
    end
    local path = m.folder .. "/" .. entry.file
    local f = io.open(path, "rb")
    local bytes = f and f:read("*a")
    if f then f:close() end
    unregister(m, tx, ty)
    if t then
        unindex(m, t)
        rejoin(m, tx, ty)
    end
    local gone = { tx = tx, ty = ty, key = key, t = t, entry = entry, bytes = bytes, saved = false }
    m.off = m.off or {}
    m.off[gone] = true
    return gone
end

-- a removed tile back as it was (gone: what remove returned)
function tiles.put_back(m, gone)
    local key = gone.tx .. "_" .. gone.ty
    if m.by_key[key] then return nil, string.format("%s has a tile %d, %d again", m.directory, gone.tx, gone.ty) end
    local t = gone.t
    if gone.saved then
        -- its file was deleted at a save: written again from the bytes it had
        if t then
            t.kept = gone.bytes
            t.dirty = true
        end
    end
    if t then
        register(m, t, gone.entry)
        I.index_tile(m, t)
        rejoin(m, gone.tx, gone.ty)
    else
        -- a tile the WDT listed with no file: listed again
        local entry = gone.entry
        register(m, { tx = gone.tx, ty = gone.ty, file = entry.file }, entry)
        m.read_tiles[key] = nil
        entry.missing = true
        m.missing = m.missing or {}
        m.missing[#m.missing + 1] = entry
    end
    if m.off then m.off[gone] = nil end
    return t or gone.entry
end
-- }}}

-- {{{ for the save (editor/wowterrain.lua's wt.save)
-- the bytes a tile with no file is patched from: its file as it was when
-- it was taken off, else (a new tile) W02a's tile from its data: ground,
-- normals, its first texture (the rest, holes and water are the patch's)
function tiles.base_bytes(m, t)
    if t.kept then return t.kept end
    if not t.made then return nil, "can't read " .. m.folder .. "/" .. t.file end
    local conv = { textures = t.textures, chunks = {} }
    for k, c in ipairs(t.chunks) do
        local nb = {}
        local R, C = I.chunk_origin(t, c)
        for i = 1, 145 do
            local n = c.normals and c.normals[i] or wt.normal(m, (R + PR[i]) * KEY + C + PC[i]) or { 0, 0, 127 }
            for a = 1, 3 do nb[(i - 1) * 3 + a] = string.char(n[a] % 256) end
        end
        conv.chunks[k - 1] = { ix = c.ix, iy = c.iy, x = c.x, y = c.y, z = c.z, heights = c.heights,
                               normals = table.concat(nb), layers = { { tex = c.layers[1].texture_index - 1 } },
                               lowres = string.rep("\0", 16) }
        -- what the patch puts on W02a's bare chunk
        c.dirty = c.dirty or {}
        c.dirty.heights, c.dirty.holes = true, true
        if #c.layers > 1 then c.dirty.layers = true end
        local k1 = c.iy * 16 + c.ix + 1
        for _, q in ipairs(t.liquids) do if q.chunk == k1 then c.dirty.water = true end end
    end
    return adt.tile_bytes(conv)
end

-- the WDT with MAIN's flag 1 set where the map has a tile and cleared where
-- it hasn't, for the tiles added or taken off (each entry's other bits and
-- its second word as they were); nil and why
function tiles.wdt_bytes(m, original)
    local blocks, tail = wt.walk(original)
    if not blocks then return nil, tail end
    local main
    for _, b in ipairs(blocks) do if b.tag == "MAIN" then main = b break end end
    if not main or main.len < 8 + 4096 * 8 then return nil, "no tile list (MAIN) of 64 x 64 entries" end
    local s = original
    for key in pairs(m.tiles_changed or {}) do
        local tx, ty = key:match("^(%d+)_(%d+)$")
        tx, ty = tonumber(tx), tonumber(ty)
        local at = main.at + 8 + (ty * 64 + tx) * 8
        local flags = I.u32(s, at)
        local want = m.by_key[key] and bit.bor(flags, 1) or bit.band(flags, bit.bnot(1))
        want = want % 4294967296
        if want ~= flags then s = I.put(s, at, I.le32(want)) end
    end
    return s
end

-- the tiles taken off since the last save: { { tx, ty, file } }
function tiles.taken_off(m)
    local out = {}
    for key in pairs(m.tiles_changed or {}) do
        if not m.by_key[key] then
            local g = tiles.off_at(m, key)
            local tx, ty = key:match("^(%d+)_(%d+)$")
            out[#out + 1] = { tx = tonumber(tx), ty = tonumber(ty), file = g and g.entry.file or name_of(m, tonumber(tx), tonumber(ty)) }
        end
    end
    table.sort(out, function(a, b) if a.ty ~= b.ty then return a.ty < b.ty end return a.tx < b.tx end)
    return out
end

-- after a save that wrote it all
-- (every tile off the map then: its file is gone or another tile's now)
function tiles.saved(m)
    for g in pairs(m.off or {}) do g.saved = true end
    for key in pairs(m.tiles_changed or {}) do
        local t = m.read_tiles[key]
        if t then t.made, t.kept = nil, nil end
    end
    m.tiles_changed = nil
end
-- }}}

-- {{{ the chunks round a tile (its neighbours' within a chunk of its edge),
-- for the editor's undo of an add or a remove
function tiles.border_chunks(m, tx, ty)
    local out = {}
    for dy = -1, 1 do
        for dx = -1, 1 do
            local t = (dx ~= 0 or dy ~= 0) and m.read_tiles[(tx + dx) .. "_" .. (ty + dy)]
            if t then
                for _, c in ipairs(t.chunks) do
                    local gr, gc = (t.ty * 16 + c.iy) - ty * 16, (t.tx * 16 + c.ix) - tx * 16
                    if gr >= -1 and gr <= 16 and gc >= -1 and gc <= 16 then out[#out + 1] = c end
                end
            end
        end
    end
    return out
end
-- }}}

return tiles

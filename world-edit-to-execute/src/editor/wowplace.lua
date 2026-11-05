--[[
Objects Placed on a WoW Map's Tiles (Issue W10e)

W10's step 3 without its window: models (M2 doodads: MMDX, MMID, MDDF)
and buildings (WMO: MWMO, MWID, MODF) placed, moved, turned, sized and
taken away on the tiles of a WoW map (editor/wowmap.lua reads them), as
plain Lua, and each edited tile's placement blocks written again by
editor/wowterrain.lua's tile writer.

    local pl = require("editor.wowplace")
    pl.load(m)                                         -- every tile read; ids counted
    local o, why = pl.place(m, { model = "World\\X\\Tree.m2", x = x, y = y })
    pl.place(m, { model = "World\\X\\Hut.wmo", x = x, y = y, size = { 20, 10 }, yaw = 90 })
    pl.move(m, o, x2, y2)                              -- its height over the ground kept
    pl.rotate(m, o, { yaw = 45 })                      -- or { rot = { a, b, c } } (the file's degrees)
    pl.scale(m, o, 1.5)                                -- models only
    pl.delete(m, o)
    pl.doodad_set(m, o, 2)                             -- a building's set of inside models (W10f)
    pl.near(m, x, y, r)                                -- the objects standing within r yards

o is { kind = "m2" or "wmo", uid }: an object is every entry of the map's
tiles with that kind and unique id (a building is listed by each tile its
box touches, with one id; the W client places it once, its 042-doodads.c).
Positions are world yards as the reader gives them (x north, y west, z up);
rotations the file's own three angles in degrees (the second turns it
about the vertical: W02b's facing, ry = WC3 angle + 90); a model's size
1.0 = as made (MDDF keeps 1024ths). A building's box (lo, hi: world axes)
is what decides its tiles and chunks; its model's own size isn't read
here (no game files), so a new building's box is opts.size { across
(west-east), up, deep (north-south; else across) } yards (else 10 x 10,
W02b's).

What is written (editor/wowterrain.lua's tile_bytes asks plan for it):
  - a tile no placement edit touched: its bytes as they were;
  - an edited tile: MMDX and MMID with a new model's name added at the
    end (names no longer used stay, so no number changes); MDDF and MODF
    with each entry as it was, byte for byte, but for the fields an edit
    changed, entries taken away left out and new ones at the end; each
    chunk's MCRF with its references renumbered, those of the moved and
    new objects worked out again by W02b's rule (a model by the chunk it
    stands in, a building by every chunk its box touches), the rest as
    they were; the blocks after them moved along.
]]

local bit = require("bit")
local coords = require("wowbuild.coords")
local adt = require("wowbuild.adt")
local bw = require("parsers.binwrite")
local wt = require("editor.wowterrain")

local pl = {}

local I = wt.internal
local u32, u16, put, le32, tag_at = I.u32, I.u16, I.put, I.le32, I.tag_at
local TILE, CHUNK, CELL, ORIGIN = coords.TILE, coords.CHUNK, coords.CELL, coords.ORIGIN
-- the W client's reader turns placement space into world with the float
-- 17066.666f (020-adt.c adt_place_read); the way back uses the same
-- number, so a position read and written again is the same float
pl.C = 17066.666015625
local C = pl.C
pl.SCALE_ONE = 1024
pl.BOX = { 10, 10 }                     -- W02b's building box, when none is given
local MDDF_BYTES, MODF_BYTES = 36, 64
local OFFSET_FIELDS = { 20, 24, 28, 32, 36, 44, 88, 96, 116, 120 }

local f32cell = require("ffi").new("union { uint32_t u; float f; }")
local function f32(s, at) f32cell.u = u32(s, at) return f32cell.f end
local function f32bytes(v) return bw.new():f32(v):done() end

-- {{{ the grid: which tile and chunk a world point is in
-- half a millimetre off a line counts as on it (W02b places on tile points,
-- some on chunk lines; a float read back may sit a hair either side); a
-- point on a line is in the chunk south (east) of it
local function grid(v)
    local g = (ORIGIN - v) / CELL
    local r = math.floor(g + 0.5)
    if math.abs(g - r) < 1e-4 then g = r end
    return g
end
-- (global chunk row, column) of a world point
local function chunk_at(x, y) return math.floor(grid(x) / 8), math.floor(grid(y) / 8) end
pl.chunk_at = chunk_at

-- { [tile key] = { [k 1-256] = true } }: where an object is listed and referenced
local function places_of(m, e)
    local out = {}
    local function add(gr, gc)
        local tx, ty = math.floor(gc / 16), math.floor(gr / 16)
        local key = tx .. "_" .. ty
        if not m.by_key[key] then return end
        out[key] = out[key] or {}
        out[key][(gr % 16) * 16 + gc % 16 + 1] = true
    end
    if e.kind == "m2" then
        add(chunk_at(e.x, e.y))
    else
        local r0, c0 = chunk_at(e.hi[1], e.hi[2])        -- north-west: the larger x and y
        local r1, c1 = chunk_at(e.lo[1], e.lo[2])
        -- a box ending on a line doesn't reach past it
        if grid(e.lo[1]) % 8 == 0 and r1 > r0 then r1 = r1 - 1 end
        if grid(e.lo[2]) % 8 == 0 and c1 > c0 then c1 = c1 - 1 end
        for gr = r0, r1 do for gc = c0, c1 do add(gr, gc) end end
    end
    return out
end
pl.places_of = places_of
-- }}}

-- {{{ pl.load: every tile read, each entry with its file record
local function read(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local d = f:read("*a")
    f:close()
    return d
end

local function blocks_by_tag(s)
    local blocks, why = wt.walk(s)
    if not blocks then return nil, why end
    local by = {}
    for _, b in ipairs(blocks) do if not by[b.tag] then by[b.tag] = b end end
    return by, blocks
end

local function entry_list(t, kind) return kind == "m2" and t.doodads or t.buildings end

-- the tile's entries tied to its file's records (raw: the record's bytes; slot: its number)
local function attach_records(m, t)
    if t.placed_loaded then return true end
    local s = t.kept or read(m.folder .. "/" .. t.file)
    if s then
        local by, why = blocks_by_tag(s)
        if not by then return nil, t.file .. ": " .. why end
        for _, kind in ipairs({ "m2", "wmo" }) do
            local b = by[kind == "m2" and "MDDF" or "MODF"]
            local each = kind == "m2" and MDDF_BYTES or MODF_BYTES
            local list = entry_list(t, kind)
            local ib = by[kind == "m2" and "MMID" or "MWID"]
            t.loaded_names = t.loaded_names or {}
            t.loaded_names[kind] = ib and math.floor((ib.len - 8) / 4) or 0
            local n = b and math.floor((b.len - 8) / each) or 0
            if n ~= #list then
                return nil, string.format("%s: %d %s records in the file, %d read", t.file, n, kind == "m2" and "MDDF" or "MODF", #list)
            end
            for i, e in ipairs(list) do
                e.kind = kind
                e.slot = i - 1
                e.raw = s:sub(b.at + 8 + (i - 1) * each + 1, b.at + 8 + i * each)
                if kind == "m2" then e.scale = u16(e.raw, 32) / pl.SCALE_ONE end
            end
        end
    else
        for _, kind in ipairs({ "m2", "wmo" }) do
            for _, e in ipairs(entry_list(t, kind)) do e.kind = kind end
        end
    end
    t.placed_loaded = true
    return true
end

function pl.load(m)
    local lib, why = m:reader()
    if not lib then return nil, why end
    local ok, bad = m:read_all()
    if not ok then return nil, table.concat(bad, "; ") end
    local top = m.next_uid or 0
    for _, e in ipairs(m.tiles) do
        local t = m.read_tiles[e.tx .. "_" .. e.ty]
        local done, awhy = attach_records(m, t)
        if not done then return nil, awhy end
        for _, kind in ipairs({ "m2", "wmo" }) do
            for _, p in ipairs(entry_list(t, kind)) do
                if p.uid + 1 > top then top = p.uid + 1 end
            end
        end
    end
    m.next_uid = math.max(top, 1)
    return true
end
-- }}}

-- {{{ finding objects
local function entries_of(m, o)
    local out = {}
    for _, e in ipairs(m.tiles) do
        local t = m.read_tiles[e.tx .. "_" .. e.ty]
        if t then
            for i, p in ipairs(entry_list(t, o.kind)) do
                if p.uid == o.uid then out[#out + 1] = { t = t, i = i, e = p } end
            end
        end
    end
    return out
end
pl.entries_of = entries_of

-- the objects standing within r yards of (x, y): { { kind, uid, x, y, d } }, nearest first
function pl.near(m, x, y, r)
    local seen, out = {}, {}
    for _, e in ipairs(m.tiles) do
        local t = m.read_tiles[e.tx .. "_" .. e.ty]
        for _, kind in ipairs({ "m2", "wmo" }) do
            for _, p in ipairs(t and entry_list(t, kind) or {}) do
                local id = kind .. p.uid
                local d = math.sqrt((p.x - x) ^ 2 + (p.y - y) ^ 2)
                if not seen[id] and d <= r then
                    seen[id] = true
                    out[#out + 1] = { kind = kind, uid = p.uid, x = p.x, y = p.y, d = d, model = p.model }
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.d < b.d end)
    return out
end
-- }}}

-- {{{ the edits
local function mark(t)
    t.places_dirty = true
    t.dirty = true
end

local function copy3(v) return v and { v[1], v[2], v[3] } or nil end
local function copy_entry(p)
    local c = {}
    for k, v in pairs(p) do c[k] = v end
    c.rot, c.lo, c.hi = copy3(p.rot), copy3(p.lo), copy3(p.hi)
    if p.edited then
        c.edited = {}
        for k, v in pairs(p.edited) do c.edited[k] = v end
    end
    return c
end
pl.copy_entry = copy_entry

-- the object as it stands now (one of its entries, copied)
local function current(m, o)
    local list = entries_of(m, o)
    if #list == 0 then return nil, string.format("no %s with unique id %s on %s", o.kind == "m2" and "model" or "building",
        tostring(o.uid), m.directory) end
    return copy_entry(list[1].e), list
end

-- the object made to stand as `want` says: every entry of it updated, taken
-- out of the tiles it leaves, added to those it reaches; fields: which
-- fields changed (pos, rot, scale, name, box, set). Returns the tiles touched.
local function settle(m, o, want, fields, list)
    local where = places_of(m, want)
    if not next(where) then
        return nil, string.format("%.1f, %.1f is on no tile of %s", want.x, want.y, m.directory)
    end
    local touched, had = {}, {}
    for _, h in ipairs(list or {}) do
        local key = h.t.tx .. "_" .. h.t.ty
        had[key] = h
        touched[key] = h.t
        if not where[key] then
            table.remove(entry_list(h.t, o.kind), h.i)
            mark(h.t)
            -- (later entries of the same list move up one; settle runs on a fresh list each time)
            for _, other in ipairs(list) do
                if other.t == h.t and other.i > h.i then other.i = other.i - 1 end
            end
        end
    end
    for key in pairs(where) do
        local t = m.read_tiles[key]
        touched[key] = t
        local h = had[key]
        if h then
            local p = h.e
            for _, f in ipairs({ "x", "y", "z", "model", "scale", "doodad_set" }) do p[f] = want[f] end
            p.rot, p.lo, p.hi = copy3(want.rot), copy3(want.lo), copy3(want.hi)
            p.reach = want.reach
            p.edited = p.edited or {}
            for f in pairs(fields) do p.edited[f] = true end
        else
            local p = copy_entry(want)
            p.slot, p.raw, p.edited = nil, want.raw, { pos = true, rot = true, scale = true, name = true, box = true, set = true }
            local l = entry_list(t, o.kind)
            l[#l + 1] = p
        end
        mark(t)
    end
    local out = {}
    for key in pairs(touched) do out[#out + 1] = key end
    table.sort(out)
    return { kind = o.kind, uid = o.uid, tiles = out }
end

function pl.place(m, o)
    o = o or {}
    if type(o.model) ~= "string" or o.model == "" then return nil, "place: which model (its path)?" end
    if not m.next_uid then
        local ok, why = pl.load(m)
        if not ok then return nil, why end
    end
    local lower = o.model:lower()
    local kind = lower:match("%.wmo$") and "wmo" or (lower:match("%.m2$") or lower:match("%.mdx$")) and "m2"
    if not kind then return nil, "place: " .. o.model .. " is neither a model (.m2) nor a building (.wmo)" end
    local z = o.z
    if not z then
        local g, why = wt.ground(m, o.x, o.y)
        if not g then return nil, why end
        z = g
    end
    local yaw = o.yaw or 0
    local want = { kind = kind, uid = m.next_uid, model = o.model, x = o.x, y = o.y, z = z,
                   rot = o.rot and copy3(o.rot) or { 0, yaw % 360, 0 }, scale = kind == "m2" and (o.scale or 1) or 1,
                   doodad_set = kind == "wmo" and (o.doodad_set or 0) or 0 }
    if kind == "wmo" then
        local across, up = (o.size and o.size[1]) or pl.BOX[1], (o.size and o.size[2]) or pl.BOX[2]
        local deep = (o.size and o.size[3]) or across
        want.lo = { o.x - deep / 2, o.y - across / 2, z }
        want.hi = { o.x + deep / 2, o.y + across / 2, z + up }
    end
    local got, why = settle(m, want, want, { pos = true, rot = true, scale = true, name = true, box = true, set = true }, {})
    if not got then return nil, why end
    m.next_uid = m.next_uid + 1
    return got
end

-- moved to (x, y), its height over the ground kept (or to z)
function pl.move(m, o, x, y, z)
    local want, list = current(m, o)
    if not want then return nil, list end
    if not z then
        local g0 = wt.ground(m, want.x, want.y)
        local g1, why = wt.ground(m, x, y)
        if not g1 then return nil, why end
        z = g1 + (g0 and (want.z - g0) or 0)
    end
    local dx, dy, dz = x - want.x, y - want.y, z - want.z
    want.x, want.y, want.z = x, y, z
    if want.kind == "wmo" then
        want.lo = { want.lo[1] + dx, want.lo[2] + dy, want.lo[3] + dz }
        want.hi = { want.hi[1] + dx, want.hi[2] + dy, want.hi[3] + dz }
    end
    return settle(m, o, want, { pos = true, box = want.kind == "wmo" or nil }, list)
end

-- turned: { yaw = degrees } (the second angle) or { rot = { a, b, c } }
function pl.rotate(m, o, r)
    local want, list = current(m, o)
    if not want then return nil, list end
    r = r or {}
    if r.rot then want.rot = copy3(r.rot) else want.rot = { want.rot[1], (r.yaw or 0) % 360, want.rot[3] } end
    local fields = { rot = true }
    if want.kind == "wmo" then
        -- its box: the square that holds its footprint at every turn (half
        -- side: its farthest corner from where it stands; a box already such
        -- a square keeps its size)
        local hx, hy = math.max(want.hi[1] - want.x, want.x - want.lo[1]), math.max(want.hi[2] - want.y, want.y - want.lo[2])
        local square = math.abs((want.hi[1] - want.x) - (want.x - want.lo[1])) < 1e-3
            and math.abs((want.hi[2] - want.y) - (want.y - want.lo[2])) < 1e-3 and math.abs(hx - hy) < 1e-3
        local reach = want.reach or (square and hx) or math.sqrt(hx * hx + hy * hy)
        want.reach = reach
        want.lo = { want.x - reach, want.y - reach, want.lo[3] }
        want.hi = { want.x + reach, want.y + reach, want.hi[3] }
        fields.box = true
    end
    return settle(m, o, want, fields, list)
end

function pl.scale(m, o, s)
    if o.kind ~= "m2" then return nil, "a building is drawn at its own size (MODF keeps no scale)" end
    if type(s) ~= "number" or s <= 0 then return nil, "scale: a number over 0" end
    local want, list = current(m, o)
    if not want then return nil, list end
    want.scale = s
    return settle(m, o, want, { scale = true }, list)
end

function pl.delete(m, o)
    local _, list = current(m, o)
    if not _ then return nil, list end
    local tiles = {}
    -- from the last entry back, so the numbers stay right
    table.sort(list, function(a, b) if a.t ~= b.t then return tostring(a.t) < tostring(b.t) end return a.i > b.i end)
    for _, h in ipairs(list) do
        table.remove(entry_list(h.t, o.kind), h.i)
        mark(h.t)
        tiles[#tiles + 1] = h.t.tx .. "_" .. h.t.ty
    end
    table.sort(tiles)
    return { kind = o.kind, uid = o.uid, tiles = tiles }
end

-- a building's doodad set (W10f): which of its WMO's sets of furniture
-- and small models the client draws inside it (MODF byte 58). Every
-- entry of the building takes it; nothing else of the record changes.
-- How many sets the WMO has is in the WMO (MODS), which isn't read here
-- (no game files), so any 16-bit number is taken.
function pl.doodad_set(m, o, n)
    if o.kind ~= "wmo" then return nil, "a model has no doodad sets; a building (WMO) has" end
    if type(n) ~= "number" or n ~= math.floor(n) or n < 0 or n > 65535 then
        return nil, "doodad set: a whole number from 0 to 65535"
    end
    local want, list = current(m, o)
    if not want then return nil, list end
    want.doodad_set = n
    return settle(m, o, want, { set = true }, list)
end

-- every entry of a tile counted as edited in every field (written again
-- from the data: what W02's placements written again must match)
function pl.touch(t)
    for _, kind in ipairs({ "m2", "wmo" }) do
        for _, p in ipairs(entry_list(t, kind)) do
            p.edited = { pos = true, rot = true, scale = true, name = true, box = true, set = true }
        end
    end
    mark(t)
end
-- }}}

-- {{{ undo: a tile's placements as they are, and back
function pl.snapshot(t)
    local s = { saves = t.saves or 0, dirty = t.places_dirty, m2 = {}, wmo = {} }
    for _, kind in ipairs({ "m2", "wmo" }) do
        for i, p in ipairs(entry_list(t, kind)) do s[kind][i] = copy_entry(p) end
    end
    return s
end

local SAME = { "x", "y", "z", "model", "scale", "doodad_set" }
local function same(a, b)
    for _, f in ipairs(SAME) do if a[f] ~= b[f] then return false end end
    for _, f in ipairs({ "rot", "lo", "hi" }) do
        local u, v = a[f], b[f]
        if (u == nil) ~= (v == nil) then return false end
        if u then for i = 1, 3 do if u[i] ~= v[i] then return false end end end
    end
    return true
end

-- the tile's placements as the snapshot has them. After a save in between,
-- the file numbers its records afresh: an entry the same as the one there
-- now is that one; any other is written again whole (its record from the
-- data, its references worked out again).
function pl.restore(t, s)
    local live = {}
    for _, kind in ipairs({ "m2", "wmo" }) do
        live[kind] = {}
        for _, p in ipairs(entry_list(t, kind)) do live[kind][p.uid] = p end
    end
    for _, kind in ipairs({ "m2", "wmo" }) do
        local list = {}
        for i, p in ipairs(s[kind]) do
            local c = copy_entry(p)
            if (t.saves or 0) ~= s.saves then
                local now = live[kind][c.uid]
                if now and not now.edited and same(now, c) then
                    c = copy_entry(now)
                else
                    c.slot = now and not now.edited and now.slot or nil
                    c.raw = (now and now.raw) or c.raw
                    c.edited = { pos = true, rot = true, scale = true, name = true, box = true, set = true }
                end
            end
            list[i] = c
        end
        if kind == "m2" then t.doodads = list else t.buildings = list end
    end
    if (t.saves or 0) == s.saves then t.places_dirty = s.dirty else t.places_dirty = true end
    t.dirty = t.places_dirty or nil
    for _, c in ipairs(t.chunks) do if c.dirty or c.normals then t.dirty = true end end
    if t.made or t.kept then t.dirty = true end
end
-- }}}

-- {{{ pl.plan: an edited tile's placement blocks and chunk references
-- the names of an MMDX/MWMO block and the offsets of its MMID/MWID
local function names_of(text, ids)
    local list = {}
    for i = 0, math.floor(#ids / 4) - 1 do
        local o = u32(ids, i * 4)
        local z = text:find("\0", o + 1, true)
        list[i + 1] = text:sub(o + 1, (z or (#text + 1)) - 1)
    end
    return list
end

-- the record for entry p (its own record with the edited fields written over)
local function encode(p, name)
    local each = p.kind == "m2" and MDDF_BYTES or MODF_BYTES
    local r = p.raw or string.rep("\0", each)
    local e = p.edited or {}
    if not p.raw or e.name then r = put(r, 0, le32(name)) end
    if not p.raw then r = put(r, 4, le32(p.uid)) end
    if not p.raw or e.pos then
        r = put(r, 8, f32bytes(C - p.y) .. f32bytes(p.z) .. f32bytes(C - p.x))
    end
    if not p.raw or e.rot then r = put(r, 20, f32bytes(p.rot[1]) .. f32bytes(p.rot[2]) .. f32bytes(p.rot[3])) end
    if p.kind == "m2" then
        if not p.raw or e.scale then
            local s = math.floor(p.scale * pl.SCALE_ONE + 0.5)
            if s < 1 then s = 1 elseif s > 65535 then s = 65535 end
            r = put(r, 32, string.char(s % 256, math.floor(s / 256)))
        end
    else
        if not p.raw or e.box then
            -- world box to placement space: the corners swap as the axes flip
            r = put(r, 32, f32bytes(C - p.hi[2]) .. f32bytes(p.lo[3]) .. f32bytes(C - p.hi[1])
                        .. f32bytes(C - p.lo[2]) .. f32bytes(p.hi[3]) .. f32bytes(C - p.lo[1]))
        end
        if not p.raw or e.set then r = put(r, 58, string.char(p.doodad_set % 256, math.floor(p.doodad_set / 256) % 256)) end
    end
    return r
end
pl.encode = encode

-- the old references of each chunk: { [k] = { d = { slots }, w = { slots }, at, ok } }
local function old_refs(original, blocks)
    local out = {}
    for _, b in ipairs(blocks) do
        if b.tag == "MCNK" and b.len >= 8 + 128 then
            local h = b.at + 8
            local ix, iy = u32(original, h + 4), u32(original, h + 8)
            local nd, nw = u32(original, h + 16), u32(original, h + 56)
            local at = u32(original, h + 32)
            local r = { d = {}, w = {} }
            if at ~= 0 and b.at + at + 8 <= b.at + b.len and tag_at(original, b.at + at) == "MCRF" then
                local size = u32(original, b.at + at + 4)
                if (nd + nw) * 4 > size then
                    return nil, string.format("chunk (%d, %d): its header counts %d references, its MCRF holds %d",
                        ix, iy, nd + nw, math.floor(size / 4))
                end
                for i = 0, nd - 1 do r.d[#r.d + 1] = u32(original, b.at + at + 8 + i * 4) end
                for i = 0, nw - 1 do r.w[#r.w + 1] = u32(original, b.at + at + 8 + (nd + i) * 4) end
                r.has = true
            elseif nd + nw > 0 then
                return nil, string.format("chunk (%d, %d): its header counts references but has no MCRF", ix, iy)
            end
            if ix < 16 and iy < 16 then out[iy * 16 + ix + 1] = r end
        end
    end
    return out
end

-- returns { blocks = { [tag] = bytes }, refs = { [k] = { d, w } }, pending = { [entry] = { slot, raw, index } } }
function pl.plan(m, original, t)
    local by, blocks = blocks_by_tag(original)
    if not by then return nil, blocks end
    for _, tag in ipairs({ "MMDX", "MMID", "MDDF", "MWMO", "MWID", "MODF" }) do
        if not by[tag] then return nil, "the tile has no " .. tag .. " block; its placements can't be written" end
    end
    local function data(tag) return original:sub(by[tag].at + 9, by[tag].at + by[tag].len) end
    local out = { blocks = {}, refs = {}, pending = {} }
    local new_index = { m2 = {}, wmo = {} }     -- old slot -> new number (entries not moved)
    local fresh = { m2 = {}, wmo = {} }         -- new numbers whose references are worked out again
    for _, kind in ipairs({ "m2", "wmo" }) do
        local TT, IT, PT = kind == "m2" and "MMDX" or "MWMO", kind == "m2" and "MMID" or "MWID", kind == "m2" and "MDDF" or "MODF"
        local text, ids = data(TT), data(IT)
        local names = names_of(text, ids)
        local added = {}
        local function number(p)
            if p.model_index and names[p.model_index] and names[p.model_index] == p.model then return p.model_index - 1 end
            for i, n in ipairs(names) do if n:lower() == p.model:lower() then return i - 1 end end
            if #text > 0 and text:sub(-1) ~= "\0" then error(TT .. "'s last name has no ending zero byte; a name can't be added after it", 0) end
            local at = #text
            text = text .. p.model .. "\0"
            ids = ids .. le32(at)
            names[#names + 1] = p.model
            added[#added + 1] = p.model
            return #names - 1
        end
        local recs, used = {}, {}
        local ok, err = pcall(function()
            for i, p in ipairs(entry_list(t, kind)) do
                local name = number(p)
                used[name] = true
                local rec = encode(p, name)
                recs[i] = rec
                out.pending[p] = { slot = i - 1, raw = rec, index = name + 1 }
                local e = p.edited or {}
                if p.slot and not e.pos and not e.box then new_index[kind][p.slot] = i - 1
                else fresh[kind][#fresh[kind] + 1] = { n = i - 1, p = p } end
            end
        end)
        if not ok then return nil, err end
        -- names this session added that nothing uses now, from the end (no
        -- number changes): an undone placement leaves its name list as it was
        local keep = (t.loaded_names and t.loaded_names[kind]) or #names
        local n = #names
        while n > keep and not used[n - 1] do n = n - 1 end
        if n < #names then
            local cut = u32(ids, n * 4)
            text, ids = text:sub(1, cut), ids:sub(1, n * 4)
            added[#added + 1] = "(trimmed)"
        end
        if #added > 0 then
            out.blocks[TT] = adt.block(TT, text)
            out.blocks[IT] = adt.block(IT, ids)
        end
        local body = table.concat(recs)
        if body ~= data(PT) then out.blocks[PT] = adt.block(PT, body) end
    end
    -- the chunks' references
    local old, why = old_refs(original, blocks)
    if not old then return nil, why end
    local key = t.tx .. "_" .. t.ty
    local add = { d = {}, w = {} }              -- [k] = { numbers }
    for _, kind in ipairs({ "m2", "wmo" }) do
        local w = kind == "m2" and "d" or "w"
        for _, f in ipairs(fresh[kind]) do
            local here = places_of(m, f.p)[key] or {}
            for k in pairs(here) do
                add[w][k] = add[w][k] or {}
                table.insert(add[w][k], f.n)
            end
        end
    end
    for k = 1, 256 do
        local o = old[k] or { d = {}, w = {} }
        local new = { d = {}, w = {} }
        for _, w in ipairs({ "d", "w" }) do
            local map = new_index[w == "d" and "m2" or "wmo"]
            for _, s in ipairs(o[w]) do
                if map[s] then new[w][#new[w] + 1] = map[s] end
            end
            local more = add[w][k] or {}
            table.sort(more)
            for _, n in ipairs(more) do new[w][#new[w] + 1] = n end
        end
        local same_refs = #new.d == #o.d and #new.w == #o.w
        if same_refs then
            for i = 1, #o.d do if new.d[i] ~= o.d[i] then same_refs = false end end
            for i = 1, #o.w do if new.w[i] ~= o.w[i] then same_refs = false end end
        end
        if not same_refs then
            if not o.has then return nil, string.format("chunk %d has no MCRF to hold its references", k - 1) end
            out.refs[k] = new
        end
    end
    return out
end

-- a chunk's MCRF made what refs says ({ d, w }: numbers into MDDF and MODF),
-- its header's counts with it, the blocks after it moved along
function pl.patch_refs(B, refs)
    local at = u32(B, 8 + 32)
    if at == 0 or at + 8 > #B or tag_at(B, at) ~= "MCRF" then return nil, "no MCRF where its header says" end
    local stop = math.min(#B, at + 8 + u32(B, at + 4))
    local R = bw.new()
    for _, n in ipairs(refs.d) do R:u32(n) end
    for _, n in ipairs(refs.w) do R:u32(n) end
    local out, moved = wt.splice(B, { { start = at, stop = stop, data = adt.block("MCRF", R:done()) } })
    if not out then return nil, moved end
    for _, f in ipairs(OFFSET_FIELDS) do
        local v = u32(B, 8 + f)
        if v ~= 0 and v > at then
            local q = moved(v)
            if not q then return nil, string.format("header byte %d points inside MCRF", f) end
            out = put(out, 8 + f, le32(q))
        end
    end
    out = put(out, 4, le32(#out - 8))
    out = put(out, 8 + 16, le32(#refs.d))
    out = put(out, 8 + 56, le32(#refs.w))
    return out
end

-- after the tile was written: each entry's record and number as written now
function pl.saved(t, pending)
    for _, kind in ipairs({ "m2", "wmo" }) do
        for _, p in ipairs(entry_list(t, kind)) do
            local q = pending and pending[p]
            if q then p.slot, p.raw, p.model_index = q.slot, q.raw, q.index end
            p.edited = nil
        end
    end
    t.places_dirty = nil
end
-- }}}

-- {{{ pl.attach: the editor's object tools on a WoW map (with undo)
-- E:wow_place(opts), E:wow_move_object(o, x, y, z), E:wow_rotate_object(o, r),
-- E:wow_scale_object(o, s), E:wow_delete_object(o), E:wow_doodad_set(o, n)
-- (W10f): on the map E:wow_edit
-- picked, each one step of the history (undo and redo, before and after a save)
function pl.attach(E)
    local function step(me, name, act)
        local m = me.wow_editing
        if not m then return nil, "no WoW map is being edited (E:wow_edit)" end
        if not m.next_uid then
            local ok, why = pl.load(m)
            if not ok then me:say(why) return nil, why end
        end
        -- every tile's placements as they were (an object can reach any of them)
        local before = {}
        for _, e in ipairs(m.tiles) do
            local t = m.read_tiles[e.tx .. "_" .. e.ty]
            if t then before[t] = pl.snapshot(t) end
        end
        local got, why = act(m)
        if not got then me:say(why) return nil, why end
        local after, list = {}, {}
        for _, key in ipairs(got.tiles) do
            local t = m.read_tiles[key]
            after[t] = pl.snapshot(t)
            list[#list + 1] = t
        end
        local function put_back(which) for _, t in ipairs(list) do pl.restore(t, which[t]) end me.dirty.wow = true end
        me.history:record({ name = name .. " (WoW map " .. m.directory .. ")",
                            undo = function() put_back(before) end, redo = function() put_back(after) end })
        me.dirty.wow = true
        return got
    end
    function E:wow_place(o) return step(self, "Place " .. tostring(o and o.model), function(m) return pl.place(m, o) end) end
    function E:wow_move_object(o, x, y, z) return step(self, "Move", function(m) return pl.move(m, o, x, y, z) end) end
    function E:wow_rotate_object(o, r) return step(self, "Turn", function(m) return pl.rotate(m, o, r) end) end
    function E:wow_scale_object(o, s) return step(self, "Size", function(m) return pl.scale(m, o, s) end) end
    function E:wow_delete_object(o) return step(self, "Delete", function(m) return pl.delete(m, o) end) end
    function E:wow_doodad_set(o, n) return step(self, "Doodad set", function(m) return pl.doodad_set(m, o, n) end) end
end
-- }}}

return pl

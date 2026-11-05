--[[
placements.lua - a WC3 map's doodads as WoW placement records (issue W02b)

Reads the map's doodads (parsers/doo.lua: war3map.doo, trees and rocks and
destructibles alike) and decides, for each, which model stands in for it
(the table in wowbuild/models.lua, or the map's own imported model), where
it stands in WoW's world, how it is turned and sized, and which ADT tile and
chunk list it. wowbuild/adt.lua writes the result: MMDX + MMID + MDDF for
models (M2), MWMO + MWID + MODF for buildings (WMO), and each chunk's MCRF
references.

Placement rules (decided 2026-11-04, W02b; the owner's to overturn):
  position   through wowbuild.coords (the scale rule), so a doodad stands on
             the ground W02a writes: the WC3 doodad's own height, which the
             World Editor keeps on the ground (or where the author raised it)
  facing     WC3's angle counts from east, anticlockwise; a WoW placement's
             front faces world angle ry + 180 degrees, counted from north
             towards west (the W client's 020-adt.h, checked there through
             its adt_place_matrix): ry = degrees(angle) + 90
  size       the mean of WC3's three scales times the row's own scale,
             1024 = 1.0 (MDDF keeps one number); a non-uniform WC3 scale is
             counted. WMOs are always drawn at their own size
  hidden     a doodad flagged invisible (flags 0) is left out, counted
  outside    one standing beyond the written ADT tiles is left out, counted
  unmapped   a type with no row is left out of the ADT and counted; the
             placement list (wowbuild.convert's placements.lua) still names
             it, so the W client can draw the WC3 model or a wire-frame there
  unique id  1, 2, 3 ... in the map's doodad order; a building crossing tile
             edges is listed in each tile it touches with the same id
  MCRF       a model is referenced by the chunk it stands in; a building by
             every chunk its box touches (020-adt doesn't read MCRF; the
             tests walk it)

    local placements = require("wowbuild.placements")
    local P = placements.prepare(map, layout, models, opts)
    -- map: { doodads = parsers.doo's, objects = { doodads = w3d, destructibles = w3b },
    --        has_file = fn(path) -> name or nil (a file inside the map archive) }
    P.tiles[ty * 64 + tx]   -- { models, doodads, buildings, places, refs[chunk] = { d = {...}, w = {...} } }
    P.list                  -- every doodad: what became of it
    P.imports               -- the map's own model files the placements use
    P:counts()              -- for the conversion report
]]

local coords = require("wowbuild.coords")

local placements = {}

placements.FLAG_INVISIBLE = 0
placements.SCALE_ONE = 1024

-- {{{ placements.load_models
-- The model table (wowbuild/models.lua or another file of that shape), read
-- as data in an empty environment
function placements.load_models(path)
    if not path then
        local here = debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$") or "."
        path = here .. "/models.lua"
    end
    local chunk, err = loadfile(path, "t", {})
    if not chunk then error("model table " .. path .. ": " .. tostring(err), 0) end
    if setfenv then setfenv(chunk, {}) end
    local ok, t = pcall(chunk)
    if not ok or type(t) ~= "table" then error("model table " .. path .. ": " .. tostring(t), 0) end
    return t, path
end
-- }}}

-- {{{ placements.wc3_key
-- A WC3 model path as by_model keys it: lower case, backslashes, ".mdx"
function placements.wc3_key(path)
    local p = tostring(path):gsub("/", "\\"):lower()
    if p:match("%.mdl$") then p = p:gsub("%.mdl$", ".mdx")
    elseif not p:match("%.mdx$") then p = p .. ".mdx" end
    return p
end
-- }}}

-- {{{ placements.own_file
-- The map archive's own file for a model field's value (WC3 names models
-- ".mdl" in object data and stores them as ".mdx"; some name none), or nil
function placements.own_file(has_file, value)
    if not has_file or type(value) ~= "string" or value == "" then return nil end
    local base = value:gsub("/", "\\")
    local tries = { base, (base:gsub("%.[mM][dD][lL]$", ".mdx")) }
    if not base:lower():match("%.md[xl]$") then tries[#tries + 1] = base .. ".mdx" end
    for _, p in ipairs(tries) do
        local name = has_file(p)
        if name then return name end
    end
    return nil
end
-- }}}

-- {{{ placements.find_row
-- The row for a type: returns row, source ("map", "model", "type", "class"),
-- and the WC3 model path the map named, if any. table: models.doodads or
-- models.units; objects: the object table holding the type's changes;
-- field: its model field code (dfil, bfil, umdl)
function placements.find_row(id, mtable, objects, field, has_file)
    local base = id
    local model
    if objects then
        if objects.custom and objects.custom[id] and objects.custom[id].parent_id then base = objects.custom[id].parent_id end
        if field and objects.get_modification then model = objects:get_modification(id, field) end
    end
    if model then
        local own = placements.own_file(has_file, model)
        if own then return { name = "the map's own model", wow = own, own = true, checked = true }, "map", model end
        local row = mtable.by_model and mtable.by_model[placements.wc3_key(model)]
        if row then return row, "model", model end
    end
    local row = mtable.types and (mtable.types[id] or mtable.types[base])
    if row then return row, "type", model end
    local classes = mtable.classes
    if classes and #base == 4 then
        local c = classes[base:sub(2, 2)]
        if c then
            row = c[base:sub(1, 1)] or c.any
            if row then return row, "class", model end
        end
    end
    return nil, nil, model
end
-- }}}

-- {{{ placements.facing
-- WC3 angle (radians, from east, anticlockwise) -> MDDF/MODF rotation y in
-- degrees (0-360), and the WoW orientation (radians from north towards
-- west, what creature spawns use)
function placements.rotation_y(angle)
    local d = math.deg(angle or 0) + 90
    d = d % 360
    return d
end

function placements.orientation(angle)
    local o = ((angle or 0) - math.pi / 2) % (2 * math.pi)
    return o
end
-- }}}

local function is_wmo(path) return tostring(path):lower():match("%.wmo$") ~= nil end

-- {{{ placements.prepare
-- map, layout (wowbuild.coords), models (the table), opts: none yet
function placements.prepare(map, layout, models, opts)
    opts = opts or {}
    local L = layout
    local P = { tiles = {}, list = {}, imports = {}, layout = L,
                n = { doodads = 0, placed_m2 = 0, placed_wmo = 0, hidden = 0, outside = 0, unmapped = 0,
                      nonuniform = 0, by_source = { map = 0, model = 0, type = 0, class = 0 }, no_baseline = 0 },
                unmapped = {}, used = {} }
    local doodads = map.doodads and map.doodads.doodads or {}
    local mtable = models.doodads or {}
    local obj = map.objects or {}

    local function tile_of(tx, ty)
        local key = ty * 64 + tx
        local t = P.tiles[key]
        if not t then
            t = { tx = tx, ty = ty, models = {}, model_index = {}, doodads = {}, buildings = {}, building_index = {},
                  places = {}, refs = {} }
            P.tiles[key] = t
        end
        return t
    end
    local function name_index(t, names, index, path)
        local k = index[path]
        if not k then
            names[#names + 1] = path
            k = #names - 1
            index[path] = k
        end
        return k
    end
    local function ref(t, chunk, kind, n)
        local r = t.refs[chunk]
        if not r then r = { d = {}, w = {} }; t.refs[chunk] = r end
        r[kind][#r[kind] + 1] = n
    end
    -- the written tile and chunk holding a global (row, col)
    local function where(row, col)
        if row < 0 or col < 0 or row >= L.nty * 128 or col >= L.ntx * 128 then return nil end
        local by, bx = math.floor(row / 128), math.floor(col / 128)
        local iy, ix = math.floor((row - by * 128) / 8), math.floor((col - bx * 128) / 8)
        return L.tx0 + bx, L.ty0 + by, iy * 16 + ix
    end

    for k, d in ipairs(doodads) do
        P.n.doodads = P.n.doodads + 1
        local is_destructible = obj.destructibles and obj.destructibles.has and obj.destructibles:has(d.id)
        local objects = is_destructible and obj.destructibles or obj.doodads
        if not (objects and objects.has and objects:has(d.id)) then objects = obj.doodads or obj.destructibles end
        local field = (objects == obj.destructibles) and "bfil" or "dfil"
        local row, source, wc3_model = placements.find_row(d.id, mtable, objects, field, map.has_file)
        local entry = { uid = k, id = d.id, variation = d.variation, creation_number = d.creation_number,
                        wc3 = { d.position.x, d.position.y, d.position.z }, angle = d.angle, wc3_model = wc3_model }
        P.list[k] = entry
        if d.flags == placements.FLAG_INVISIBLE then
            entry.left_out = "hidden"
            P.n.hidden = P.n.hidden + 1
        elseif not row then
            entry.left_out = "unmapped"
            P.n.unmapped = P.n.unmapped + 1
            P.unmapped[d.id] = (P.unmapped[d.id] or 0) + 1
        else
            local X, Y, Z = L:to_wow(d.position.x, d.position.y, d.position.z)
            local col = (d.position.x - L.offset_x) / coords.WC3_TILE
            local rowg = (L.H - 1) - (d.position.y - L.offset_y) / coords.WC3_TILE
            local tx, ty, chunk = where(rowg, col)
            if not tx then
                entry.left_out = "outside"
                P.n.outside = P.n.outside + 1
            else
                local s = d.scale or { x = 1, y = 1, z = 1 }
                if math.abs(s.x - s.y) > 1e-4 or math.abs(s.x - s.z) > 1e-4 then P.n.nonuniform = P.n.nonuniform + 1 end
                local scale = (s.x + s.y + s.z) / 3 * (row.scale or 1)
                local s16 = math.floor(scale * placements.SCALE_ONE + 0.5)
                if s16 < 1 then s16 = 1 elseif s16 > 65535 then s16 = 65535 end
                local ry = placements.rotation_y(d.angle)
                -- placement space: (ORIGIN - world y, world z, ORIGIN - world x)
                local p = { coords.ORIGIN - Y, Z, coords.ORIGIN - X }
                entry.wow = row.wow
                entry.source = source
                entry.world = { X, Y, Z }
                P.n.by_source[source] = P.n.by_source[source] + 1
                if not row.baseline and not row.own then P.n.no_baseline = P.n.no_baseline + 1 end
                P.used[row.wow] = row
                if row.own then P.imports[row.wow] = true end
                if is_wmo(row.wow) then
                    P.n.placed_wmo = P.n.placed_wmo + 1
                    entry.kind = "wmo"
                    local w, h = (row.size and row.size[1]) or 10, (row.size and row.size[2]) or 10
                    local lo = { p[1] - w / 2, p[2], p[3] - w / 2 }
                    local hi = { p[1] + w / 2, p[2] + h, p[3] + w / 2 }
                    -- every tile and chunk the box touches (rows from x, cols from y)
                    local function grid(xw, yw)
                        return (coords.ORIGIN - xw) / coords.CELL - L.ty0 * 128, (coords.ORIGIN - yw) / coords.CELL - L.tx0 * 128
                    end
                    local ra, ca = grid(X + w / 2, Y + w / 2)
                    local rb, cb = grid(X - w / 2, Y - w / 2)
                    local seen_tiles = {}
                    for rr = math.max(0, math.floor(ra / 8)), math.min(L.nty * 16 - 1, math.floor(rb / 8)) do
                        for cc = math.max(0, math.floor(ca / 8)), math.min(L.ntx * 16 - 1, math.floor(cb / 8)) do
                            local ttx, tty, ch = where(rr * 8, cc * 8)
                            if ttx then
                                local t = tile_of(ttx, tty)
                                local n = seen_tiles[t]
                                if not n then
                                    t.places[#t.places + 1] = { name = name_index(t, t.buildings, t.building_index, row.wow),
                                        uid = k, pos = p, rot = { 0, ry, 0 }, lo = lo, hi = hi }
                                    n = #t.places - 1
                                    seen_tiles[t] = n
                                end
                                ref(t, ch, "w", n)
                            end
                        end
                    end
                else
                    P.n.placed_m2 = P.n.placed_m2 + 1
                    entry.kind = "m2"
                    local t = tile_of(tx, ty)
                    t.doodads[#t.doodads + 1] = { name = name_index(t, t.models, t.model_index, row.wow),
                        uid = k, pos = p, rot = { 0, ry, 0 }, scale = s16 }
                    ref(t, chunk, "d", #t.doodads - 1)
                end
            end
        end
    end
    return setmetatable(P, { __index = placements.P })
end
-- }}}

placements.P = {}

-- {{{ P:counts
function placements.P:counts()
    local unchecked, used = 0, 0
    for _, row in pairs(self.used) do
        used = used + 1
        if not row.checked then unchecked = unchecked + 1 end
    end
    local ids = 0
    for _ in pairs(self.unmapped) do ids = ids + 1 end
    local imports = {}
    for path in pairs(self.imports) do imports[#imports + 1] = path end
    table.sort(imports)
    local n = self.n
    return {
        doodads = n.doodads, placed_m2 = n.placed_m2, placed_wmo = n.placed_wmo,
        hidden = n.hidden, outside = n.outside, unmapped = n.unmapped, unmapped_ids = ids,
        unmapped_by_id = self.unmapped, nonuniform_scales = n.nonuniform, by_source = n.by_source,
        models_used = used, models_unchecked = unchecked, waiting_for_baseline = n.no_baseline,
        own_models = imports,
    }
end
-- }}}

return placements

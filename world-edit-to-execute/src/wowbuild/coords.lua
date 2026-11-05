--[[
coords.lua - where a WC3 map lands in a WoW map (issue W02a)

The scale rule (docs/wow-client-bridge.md, "Scale"): one WC3 tile, 128 game
units, is one WoW terrain cell, 4.1667 yards. So WC3's tile points are the
ADT files' outer vertices one-to-one, and one yard is 30.72 WC3 units, up as
well as across.

A WoW map is 64 x 64 ADT tiles of 533.33 yards, each 16 x 16 chunks of 8 x 8
cells. ADT file <map>_<tx>_<ty>.adt: tx counts west to east, ty north to
south. WoW's world axes: x points north, y west, z up; the map's north-west
corner is at (17066.67, 17066.67). WC3's: x east, y north, z up; tile point
(i, j) is at (offset_x + 128 i, offset_y + 128 j), with j = 0 the southern
row.

Placement (decided 2026-11-04, W02a): the WC3 map's north-west tile point is
the north-west corner of ADT tile (tx0, ty0), where the map's ADT block is
centred on the middle of the 64 x 64 grid (tx0 = 32 - floor(ntx / 2)), so a
one-tile map starts at world (0, 0) and runs south and east from it. Cells
of the written ADTs beyond the WC3 grid take the nearest edge tile point
(clamped), so the ground there is a flat skirt, not a hole.

    local coords = require("wowbuild.coords")
    local L = coords.layout(terrain)          -- terrain: parsers.w3e's
    L.ntx, L.nty, L.tx0, L.ty0                -- ADT tiles written and the first's number
    local x, y, z = L:to_wow(wx, wy, wz)      -- a WC3 world point in WoW yards
    local i, j = L:tilepoint(row, col)        -- the WC3 tile point at a global vertex
    local X, Y = L:vertex_world(row, col)     -- that vertex's WoW world x, y
    local P = L:client_placement()            -- the same placement as plain data
    local cx, cy = coords.wc3_to_client(P, wx, wy)   -- a WC3 point as the W client's --camera

WoW's world coordinates here are the W client's own (custom-client's
src/018-maps.h: x north, y west, tile = floor(32 - x / 533.33) and
floor(32 - y / 533.33); src/033-ground-prep.c opens <map>_<y tile>_<x
tile>.adt, the west-east number first), so they are also what its
--camera takes (its issue 1109: "world x and y in yards"). Test Map
(issue 913) reads the placement from conversion-report.lua, where
wowbuild.convert writes client_placement(), and turns the editor's view
into the W client's --camera with wc3_to_client.

W02b places doodads and units through to_wow, so they stand on the ground
this writes.
]]

local coords = {}

coords.TILE = 1600 / 3                    -- yards an ADT tile side (533.33)
coords.CHUNK = coords.TILE / 16           -- 33.33
coords.CELL = coords.CHUNK / 8            -- 4.1667: one WC3 tile
coords.ORIGIN = 32 * coords.TILE          -- 17066.67: world x and y of the map's north-west corner
coords.WC3_TILE = 128                     -- WC3 units a tile side
coords.YARDS_PER_UNIT = coords.CELL / coords.WC3_TILE   -- 0.03255: 1 / 30.72

local Layout = {}
Layout.__index = Layout

-- {{{ coords.layout
-- terrain: width and height in tile points (parsers.w3e's), offset_x/y
function coords.layout(terrain)
    local W, H = terrain.width, terrain.height
    assert(W >= 2 and H >= 2, "a WC3 terrain needs at least 2 x 2 tile points")
    local cw, ch = W - 1, H - 1
    local ntx, nty = math.ceil(cw / 128), math.ceil(ch / 128)
    assert(ntx <= 64 and nty <= 64, "the map is wider than a WoW map (64 ADT tiles)")
    local self = setmetatable({
        W = W, H = H, cells_w = cw, cells_h = ch,
        ntx = ntx, nty = nty,
        tx0 = 32 - math.floor(ntx / 2), ty0 = 32 - math.floor(nty / 2),
        offset_x = terrain.offset_x or 0, offset_y = terrain.offset_y or 0,
    }, Layout)
    return self
end
-- }}}

-- {{{ Layout:tilepoint
-- The WC3 tile point (i east, j north) at global outer vertex (row from the
-- block's north edge, col from its west edge), clamped onto the grid
function Layout:tilepoint(row, col)
    local i = col
    local j = (self.H - 1) - row
    if i < 0 then i = 0 elseif i > self.W - 1 then i = self.W - 1 end
    if j < 0 then j = 0 elseif j > self.H - 1 then j = self.H - 1 end
    return i, j
end
-- }}}

-- {{{ Layout:vertex_world
-- WoW world x (north) and y (west) of a global vertex; row and col may be
-- fractional (a cell centre is row + 0.5, col + 0.5)
function Layout:vertex_world(row, col)
    return coords.ORIGIN - (self.ty0 * 128 + row) * coords.CELL,
           coords.ORIGIN - (self.tx0 * 128 + col) * coords.CELL
end
-- }}}

-- {{{ Layout:to_wow
-- A WC3 world point (x east, y north, z up; WC3 units) as WoW world yards
function Layout:to_wow(wx, wy, wz)
    local col = (wx - self.offset_x) / coords.WC3_TILE
    local row = (self.H - 1) - (wy - self.offset_y) / coords.WC3_TILE
    local x, y = self:vertex_world(row, col)
    return x, y, (wz or 0) * coords.YARDS_PER_UNIT
end
-- }}}

-- {{{ Layout:to_wc3
-- The other way: WoW world x, y (yards) to WC3 world x, y (units)
function Layout:to_wc3(x, y)
    local row = (coords.ORIGIN - x) / coords.CELL - self.ty0 * 128
    local col = (coords.ORIGIN - y) / coords.CELL - self.tx0 * 128
    return self.offset_x + col * coords.WC3_TILE, self.offset_y + ((self.H - 1) - row) * coords.WC3_TILE
end
-- }}}

-- {{{ Layout:client_placement
-- The placement as plain numbers, for conversion-report.lua: enough to turn
-- a WC3 point into the W client's world without the terrain. The mapping
-- is a scale and a shift with WC3's axes turned a quarter (WC3 x east is
-- WoW -y, WC3 y north is WoW x):
--     client x = x0 + scale * wc3 y        client y = y0 - scale * wc3 x
-- wc3_min and wc3_max bound the WC3 map's tile points (its ground).
function Layout:client_placement()
    local x0, y0 = self:to_wow(0, 0)
    return {
        scale = coords.YARDS_PER_UNIT,
        x0 = x0, y0 = y0,
        wc3_min = { self.offset_x, self.offset_y },
        wc3_max = { self.offset_x + (self.W - 1) * coords.WC3_TILE, self.offset_y + (self.H - 1) * coords.WC3_TILE },
    }
end
-- }}}

-- {{{ coords.check_placement
-- A placement read back from a report: nil and why when it isn't one
local function finite(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
function coords.check_placement(p)
    if type(p) ~= "table" then return nil, "no placement" end
    if not finite(p.scale) or p.scale <= 0 then return nil, "the placement's scale isn't a number above 0" end
    if not finite(p.x0) or not finite(p.y0) then return nil, "the placement's x0 or y0 isn't a number" end
    for _, k in ipairs({ "wc3_min", "wc3_max" }) do
        local b = p[k]
        if type(b) ~= "table" or not finite(b[1]) or not finite(b[2]) then
            return nil, "the placement's " .. k .. " isn't two numbers"
        end
    end
    if p.wc3_min[1] > p.wc3_max[1] or p.wc3_min[2] > p.wc3_max[2] then
        return nil, "the placement's wc3_min is beyond its wc3_max"
    end
    return p
end
-- }}}

-- {{{ coords.wc3_to_client
-- A WC3 world point (x east, y north; WC3 units) as the W client's world
-- x (north) and y (west) in yards, by a placement (client_placement's, or
-- read back from conversion-report.lua). A point off the WC3 map, or
-- within EDGE_INSET of its edge, is first moved inside that margin, so it
-- lands on ground the converter wrote (the W client refuses a start with
-- no ground under it). The margin is there because a point exactly on an
-- edge that is also an ADT tile's edge belongs, by the client's
-- maps_tile_of (018-maps.c: floor, in 32-bit floats), to the tile beyond
-- it, which isn't written: a 129 x 129 map's south and east edges are,
-- checked against that function. The third result is true when the point
-- was moved.
-- nil and why for a bad placement.
coords.EDGE_INSET = coords.WC3_TILE / 4      -- 32 WC3 units, about a yard
function coords.wc3_to_client(p, wx, wy)
    local ok, why = coords.check_placement(p)
    if not ok then return nil, why end
    if type(wx) ~= "number" or type(wy) ~= "number" or wx ~= wx or wy ~= wy then
        return nil, "the point isn't two numbers"
    end
    local lo, hi = p.wc3_min, p.wc3_max
    local function inside(v, a, b)
        local m = math.min(coords.EDGE_INSET, (b - a) / 2)
        return math.min(math.max(v, a + m), b - m)
    end
    local cx, cy = inside(wx, lo[1], hi[1]), inside(wy, lo[2], hi[2])
    return p.x0 + p.scale * cy, p.y0 - p.scale * cx, (cx ~= wx or cy ~= wy)
end
-- }}}

-- {{{ coords.client_adt
-- The ADT the W client opens for its world point (x, y): the numbers in
-- <map>_<tx>_<ty>.adt, tx west to east, ty north to south. Its own rule,
-- in its own 32-bit floats: custom-client src/018-maps.c maps_tile_of
-- (tile x = floor(32 - x / 533.33333f), tile y likewise from y) and
-- src/033-ground-prep.c, which names the file with tile y first
local ok_ffi, ffi = pcall(require, "ffi")
local function f32(v) return ok_ffi and tonumber(ffi.new("float", v)) or v end
function coords.client_adt(x, y)
    local G = f32(533.33333)
    local north_south = math.floor(f32(32 - f32(f32(x) / G)))
    local west_east = math.floor(f32(32 - f32(f32(y) / G)))
    return west_east, north_south
end
-- }}}

-- {{{ Layout:tiles
-- The ADT tiles written: { tx, ty, bx, by } each, bx/by its place in the block
function Layout:tiles()
    local list = {}
    for by = 0, self.nty - 1 do
        for bx = 0, self.ntx - 1 do
            list[#list + 1] = { tx = self.tx0 + bx, ty = self.ty0 + by, bx = bx, by = by }
        end
    end
    return list
end
-- }}}

return coords

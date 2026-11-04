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

--[[
WC3 minimap: the map in the console's corner (Issues 507a, 507d)

In plain terms: where a point of the map falls on the minimap and back,
with the map fitted into the minimap's square as WC3 fits a map that is
not square: the whole map shown, at one scale across and down, centred,
the rest of the square left dark. And the camera's view, four ground
points, cut to the picture, as the box the minimap draws.

  local minimap = require("ui.wc3.minimap")
  local mm = minimap.new({ x0 =, y0 =, x1 =, y1 = }, { x =, y =, w =, h = })
  mm.picture                       -- { x, y, w, h }: where the map's picture goes
  local px, py = mm:to_minimap(x, y)    -- north up
  local x, y = mm:to_world(px, py)      -- held to the map
  mm:inside(px, py)                     -- on the minimap at all
  local box = mm:view_box(quad)         -- quad: { x1, y1, ... x4, y4 } on the ground;
                                        -- box: { {px, py}, ... }, cut to the picture

The extent is the map's ground in WC3 units (x east, y north); the rect
is the minimap's square on the screen (y down).
]]

local minimap = {}
local Minimap = {}
Minimap.__index = Minimap

-- {{{ minimap.fit
-- The picture's rectangle: the extent at one scale, as large as fits the
-- rect, centred in it.
function minimap.fit(extent, rect)
    local ew, eh = extent.x1 - extent.x0, extent.y1 - extent.y0
    if ew <= 0 or eh <= 0 then return { x = rect.x, y = rect.y, w = rect.w, h = rect.h } end
    local scale = math.min(rect.w / ew, rect.h / eh)
    local w, h = ew * scale, eh * scale
    return { x = rect.x + (rect.w - w) / 2, y = rect.y + (rect.h - h) / 2, w = w, h = h }
end
-- }}}

-- {{{ minimap.new
function minimap.new(extent, rect)
    return setmetatable({ extent = extent, rect = rect, picture = minimap.fit(extent, rect) }, Minimap)
end
-- }}}

-- {{{ Minimap:to_minimap / to_world
function Minimap:to_minimap(x, y)
    local e, p = self.extent, self.picture
    return p.x + (x - e.x0) / (e.x1 - e.x0) * p.w, p.y + (e.y1 - y) / (e.y1 - e.y0) * p.h
end

-- A point of the minimap's square to the map; a point off the picture (in
-- the dark margin, or past it) is the nearest point of the map.
function Minimap:to_world(px, py)
    local e, p = self.extent, self.picture
    local fx = math.max(0, math.min(1, (px - p.x) / p.w))
    local fy = math.max(0, math.min(1, (py - p.y) / p.h))
    return e.x0 + fx * (e.x1 - e.x0), e.y1 - fy * (e.y1 - e.y0)
end
-- }}}

-- {{{ Minimap:inside
function Minimap:inside(px, py)
    local r = self.rect
    return px >= r.x and px < r.x + r.w and py >= r.y and py < r.y + r.h
end
-- }}}

-- {{{ Minimap:view_box
-- The ground quad on the minimap, cut to the picture (each edge of the
-- picture in turn): a box that runs off the map shows the part on it.
-- Empty when none of it is on the map.
local function cut(points, inside, cross)
    local out = {}
    for i = 1, #points do
        local a, b = points[i], points[i % #points + 1]
        local ia, ib = inside(a), inside(b)
        if ia then out[#out + 1] = a end
        if ia ~= ib then out[#out + 1] = cross(a, b) end
    end
    return out
end

function Minimap:view_box(quad)
    local pts = {}
    for i = 1, 7, 2 do
        local px, py = self:to_minimap(quad[i], quad[i + 1])
        pts[#pts + 1] = { px, py }
    end
    local p = self.picture
    local function at_x(x) return function(a, b) local t = (x - a[1]) / (b[1] - a[1]) return { x, a[2] + (b[2] - a[2]) * t } end end
    local function at_y(y) return function(a, b) local t = (y - a[2]) / (b[2] - a[2]) return { a[1] + (b[1] - a[1]) * t, y } end end
    local x0, y0, x1, y1 = p.x, p.y, p.x + p.w, p.y + p.h
    pts = cut(pts, function(q) return q[1] >= x0 end, at_x(x0))
    pts = cut(pts, function(q) return q[1] <= x1 end, at_x(x1))
    pts = cut(pts, function(q) return q[2] >= y0 end, at_y(y0))
    pts = cut(pts, function(q) return q[2] <= y1 end, at_y(y1))
    return pts
end
-- }}}

return minimap

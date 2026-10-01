--[[
Geometry Kit (Issue 516b)

Builds structures out of flat-shaded boxes, wedges and quads, in WC3 world
units: x east, y north, z up, 128 units to a terrain tile. A structure is
data (a list of primitives) plus the surfaces a unit can stand on, so the
same fort can be drawn, walked on and tested without a window.

    local kit = require("geometry.kit")
    local world = kit.new()
    world:slab(0, 0, 2048, 2048, 32, 0)                -- a raised square
    world:rampart(-768, -768, 768, -768, { z = 32 })   -- wall with merlons
    world:ramp(544, -352, 32, 544, 416, 320, 128)      -- low end -> high end
    world:emit(render)                                 -- paint (static layer)
    local z = world:height_at(x, y, z_now)             -- where a unit stands

Primitives (WC3 space):
    { kind = "box" | "wedge", x, y, z, len, wid, hgt, yaw, color }
        (x, y, z) is the centre of the base; len runs along yaw, wid across,
        hgt up. A wedge is 0 high at its -len end and hgt at its +len end.
    { kind = "quad", pts = { {x, y, z} x4 }, color }

Surfaces: { x, y, len, wid, yaw, z0, z1 }, a rectangle whose height runs
from z0 at its -len end to z1 at its +len end (flat when equal).
]]

local kit = {}

-- {{{ Constants
-- Render space is 1 unit per tile (as src/demo/map_renderer.lua draws terrain)
kit.RENDER_SCALE = 1 / 128

-- The most a walking unit rises in one step. Surfaces higher than this
-- above its feet are walls or bridges it passes beside or under.
kit.MAX_STEP = 48

kit.COLORS = {
    stone      = { 96, 112, 168 },   -- slate blue walls
    stone_dark = { 70, 82, 132 },
    stone_top  = { 128, 146, 200 },
    plinth     = { 58, 86, 170 },    -- the blue square
    wood       = { 140, 92, 50 },
    wood_dark  = { 96, 62, 34 },
    iron       = { 60, 60, 66 },
    roof       = { 176, 58, 44 },
    bell       = { 214, 176, 60 },
}
-- }}}

-- {{{ kit.new
local World = {}
World.__index = World

function kit.new()
    return setmetatable({ prims = {}, surfaces = {} }, World)
end
-- }}}

-- {{{ Primitive constructors

-- {{{ World:box
function World:box(x, y, z, len, wid, hgt, yaw, color)
    local p = { kind = "box", x = x, y = y, z = z, len = len, wid = wid,
                hgt = hgt, yaw = yaw or 0, color = color or kit.COLORS.stone }
    self.prims[#self.prims + 1] = p
    return p
end
-- }}}

-- {{{ World:wedge
function World:wedge(x, y, z, len, wid, hgt, yaw, color)
    local p = { kind = "wedge", x = x, y = y, z = z, len = len, wid = wid,
                hgt = hgt, yaw = yaw or 0, color = color or kit.COLORS.stone }
    self.prims[#self.prims + 1] = p
    return p
end
-- }}}

-- {{{ World:quad
-- pts: four {x, y, z} corners in order around the edge
function World:quad(pts, color)
    local p = { kind = "quad", pts = pts, color = color or kit.COLORS.stone }
    self.prims[#self.prims + 1] = p
    return p
end
-- }}}

-- {{{ World:surface
function World:surface(x, y, len, wid, yaw, z0, z1)
    local s = { x = x, y = y, len = len, wid = wid, yaw = yaw or 0,
                z0 = z0, z1 = z1 or z0 }
    self.surfaces[#self.surfaces + 1] = s
    return s
end
-- }}}
-- }}}

-- {{{ Geometry helpers

-- {{{ segment
-- Centre, length and angle of the segment (x1, y1) -> (x2, y2)
local function segment(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return (x1 + x2) / 2, (y1 + y2) / 2, math.sqrt(dx * dx + dy * dy), math.atan2(dy, dx)
end
-- }}}

-- {{{ kit.local_point
-- Offset (along, across) from (x, y) in the frame turned by yaw
function kit.local_point(x, y, yaw, along, across)
    local c, s = math.cos(yaw), math.sin(yaw)
    return x + along * c - across * s, y + along * s + across * c
end
-- }}}
-- }}}

-- {{{ Composite structures

-- {{{ World:slab
-- A solid block you can stand on top of
function World:slab(x, y, len, wid, hgt, z, yaw, color)
    z, yaw = z or 0, yaw or 0
    self:box(x, y, z, len, wid, hgt, yaw, color or kit.COLORS.plinth)
    self:surface(x, y, len, wid, yaw, z + hgt)
end
-- }}}

-- {{{ merlon_row
-- Merlons (the raised teeth of a battlement) along one edge of a walkway.
-- (x1, y1) -> (x2, y2) is the edge; they sit on top at height z.
local function merlon_row(world, x1, y1, x2, y2, z, opts)
    local size = opts.merlon or 40
    local gap = opts.merlon_gap or 48
    local cx, cy, len, yaw = segment(x1, y1, x2, y2)
    local count = math.max(1, math.floor((len + gap) / (size + gap)))
    local span = count * size + (count - 1) * gap
    for i = 0, count - 1 do
        local along = -span / 2 + size / 2 + i * (size + gap)
        local mx, my = kit.local_point(cx, cy, yaw, along, 0)
        world:box(mx, my, z, size, size * 0.8, size * 1.2, yaw, opts.top_color or kit.COLORS.stone_top)
    end
end
-- }}}

-- {{{ World:rampart
-- A wall from (x1, y1) to (x2, y2) with a walkway on top and merlons on its
-- outer edge. opts: thickness (160), height (288), z (0), outward (+1: the
-- merlons go on the left of the direction of travel; -1: right), color.
-- Returns the walkway's centre line as two points at walkway height.
function World:rampart(x1, y1, x2, y2, opts)
    opts = opts or {}
    local thick = opts.thickness or 160
    local height = opts.height or 288
    local z = opts.z or 0
    local outward = opts.outward or 1
    local cx, cy, len, yaw = segment(x1, y1, x2, y2)

    self:box(cx, cy, z, len, thick, height, yaw, opts.color or kit.COLORS.stone)
    self:surface(cx, cy, len, thick, yaw, z + height)

    -- merlons along the outer edge, set in a little from the face
    local edge = outward * (thick / 2 - 16)
    local ax, ay = kit.local_point(x1, y1, yaw, 0, edge)
    local bx, by = kit.local_point(x2, y2, yaw, 0, edge)
    merlon_row(self, ax, ay, bx, by, z + height, opts)

    return { x1 = x1, y1 = y1, x2 = x2, y2 = y2, z = z + height }
end
-- }}}

-- {{{ World:tower
-- A square tower with battlements on every edge and a flat top.
-- Returns the top's height.
function World:tower(x, y, size, height, z, opts)
    opts = opts or {}
    z = z or 0
    self:box(x, y, z, size, size, height, opts.yaw or 0, opts.color or kit.COLORS.stone)
    self:surface(x, y, size, size, opts.yaw or 0, z + height)
    if opts.battlements ~= false then
        local h = size / 2 - 16
        local top = z + height
        merlon_row(self, x - h, y - h, x + h, y - h, top, opts)
        merlon_row(self, x + h, y - h, x + h, y + h, top, opts)
        merlon_row(self, x + h, y + h, x - h, y + h, top, opts)
        merlon_row(self, x - h, y + h, x - h, y - h, top, opts)
    end
    return z + height
end
-- }}}

-- {{{ World:belltower
-- A tall tower with an open belfry on top: a post at each corner, a
-- pyramid roof and a bell hanging in the middle. Units stand on the belfry
-- floor. Returns the floor height.
function World:belltower(x, y, size, height, z, opts)
    opts = opts or {}
    local floor = self:tower(x, y, size, height, z, { battlements = false })
    local post, post_h = 28, 176
    local h = size / 2 - post / 2
    for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
        self:box(x + c[1] * h, y + c[2] * h, floor, post, post, post_h, 0, kit.COLORS.wood)
    end
    -- low rail between the posts, leaving each side open to shoot from
    local eave = floor + post_h
    self:box(x, y, eave, size + 24, size + 24, 20, 0, kit.COLORS.wood_dark)
    -- pyramid roof: four sloped quads meeting at the apex
    local apex = { x, y, eave + 20 + size * 0.55 }
    local r = size / 2 + 20
    local corners = { { x - r, y - r }, { x + r, y - r }, { x + r, y + r }, { x - r, y + r } }
    for i = 1, 4 do
        local a, b = corners[i], corners[i % 4 + 1]
        -- a quad whose last two corners meet at the apex draws as a triangle
        self:quad({ { a[1], a[2], eave + 20 }, { b[1], b[2], eave + 20 }, apex, apex },
                  kit.COLORS.roof)
    end
    -- the bell, hung from the eave
    self:box(x, y, eave - 70, 40, 40, 56, 0, kit.COLORS.bell)
    self:box(x, y, eave - 14, 8, 8, 14, 0, kit.COLORS.iron)
    return floor
end
-- }}}

-- {{{ World:gatehouse
-- A fortified entrance in a wall that runs along x at y = wall_y, its outer
-- face toward -y. Two towers stand out from the wall on either side of the
-- opening; a bridge spans the opening at walkway height (a unit walking the
-- wall crosses over the gate, a unit entering walks under it); a portcullis
-- hangs half raised in the opening.
-- opts: opening (256), tower (224), depth of the towers beyond the wall
-- face (96), height (288, the walkway), z (0), thickness (160).
-- Returns the gate's inner and outer ground points.
function World:gatehouse(x, wall_y, opts)
    opts = opts or {}
    local opening = opts.opening or 256
    local tsize = opts.tower or 224
    local depth = opts.depth or 96
    local height = opts.height or 288
    local z = opts.z or 0
    local thick = opts.thickness or 160

    -- flanking towers: flush with the wall's inner face, standing out past
    -- its outer face by depth, their tops level with the walkway
    local ty = wall_y - depth / 2
    local tdepth = thick + depth
    for _, side in ipairs({ -1, 1 }) do
        local tx = x + side * (opening / 2 + tsize / 2)
        self:box(tx, ty, z, tsize, tdepth, height, 0, kit.COLORS.stone_dark)
        self:surface(tx, ty, tsize, tdepth, 0, z + height)
        local h = tsize / 2 - 16
        local oy = ty - tdepth / 2 + 16
        merlon_row(self, tx - h, oy, tx + h, oy, z + height, opts)
    end

    -- the bridge over the opening, with a parapet on its outer edge
    local bridge_h = 64
    self:box(x, wall_y, z + height - bridge_h, opening, thick, bridge_h, 0, kit.COLORS.stone_dark)
    self:surface(x, wall_y, opening, thick, 0, z + height)
    merlon_row(self, x - opening / 2, wall_y - thick / 2 + 16,
               x + opening / 2, wall_y - thick / 2 + 16, z + height, opts)

    -- portcullis: iron bars across the opening, lifted to leave a way in
    local lift = height - bridge_h - 110
    local bars = 7
    for i = 0, bars - 1 do
        local bx = x - opening / 2 + (i + 0.5) * opening / bars
        self:box(bx, wall_y - thick / 2 + 12, z + lift, 10, 10, height - bridge_h - lift, 0, kit.COLORS.iron)
    end
    self:box(x, wall_y - thick / 2 + 12, z + lift, opening, 10, 10, 0, kit.COLORS.iron)

    return {
        outside = { x = x, y = wall_y - thick / 2 - depth - 64, z = z },
        inside = { x = x, y = wall_y + thick / 2 + 64, z = z },
    }
end
-- }}}

-- {{{ World:ramp
-- A solid ramp from (x1, y1) at height z1 up to (x2, y2) at z2, width wide.
function World:ramp(x1, y1, z1, x2, y2, z2, width, color)
    local cx, cy, len, yaw = segment(x1, y1, x2, y2)
    self:wedge(cx, cy, z1, len, width, z2 - z1, yaw, color or kit.COLORS.stone_dark)
    self:surface(cx, cy, len, width, yaw, z1, z2)
end
-- }}}

-- {{{ World:stairs
-- Steps from (x1, y1) at z1 up to (x2, y2) at z2. Walked as a slope; drawn
-- as a stack of blocks, each reaching down to z1.
function World:stairs(x1, y1, z1, x2, y2, z2, width, steps, color)
    local cx, cy, len, yaw = segment(x1, y1, x2, y2)
    steps = steps or math.max(2, math.floor((z2 - z1) / 32 + 0.5))
    local tread = len / steps
    local rise = (z2 - z1) / steps
    for i = 0, steps - 1 do
        local sx, sy = kit.local_point(x1, y1, yaw, (i + 0.5) * tread, 0)
        self:box(sx, sy, z1, tread, width, rise * (i + 1), yaw, color or kit.COLORS.stone_top)
    end
    self:surface(cx, cy, len, width, yaw, z1, z2)
end
-- }}}
-- }}}

-- {{{ Standing on the world

-- {{{ surface_height
-- Height of surface s at (x, y), or nil when (x, y) is off it
local function surface_height(s, x, y)
    local c, sn = math.cos(s.yaw), math.sin(s.yaw)
    local dx, dy = x - s.x, y - s.y
    local along = dx * c + dy * sn
    local across = -dx * sn + dy * c
    local hl, hw = s.len / 2, s.wid / 2
    if along < -hl or along > hl or across < -hw or across > hw then
        return nil
    end
    if s.z0 == s.z1 then return s.z0 end
    return s.z0 + (s.z1 - s.z0) * (along + hl) / s.len
end
-- }}}

-- {{{ World:height_at
-- Where a unit at (x, y), feet at z_now, stands: the highest surface under
-- it that it can step up to (at most MAX_STEP above its feet), else the
-- ground (0). Without z_now, the highest surface there.
function World:height_at(x, y, z_now)
    local limit = z_now and (z_now + kit.MAX_STEP) or math.huge
    local best = 0
    for _, s in ipairs(self.surfaces) do
        local h = surface_height(s, x, y)
        if h and h <= limit and h > best then best = h end
    end
    return best
end
-- }}}
-- }}}

-- {{{ Painting

-- {{{ kit.to_render
-- WC3 (x, y, z) to render space (x, up, z): x -> x, z -> up, y -> -z, all
-- scaled by RENDER_SCALE, and lifted by ground (render units). North is -z
-- so that the view is not a mirror image: swapping y and z alone would
-- reflect the world, as src/demo/map_renderer.lua's terrain is by default.
function kit.to_render(x, y, z, ground)
    local k = kit.RENDER_SCALE
    return x * k, z * k + (ground or 0), -y * k
end
-- }}}

-- {{{ kit.emit_prims
-- Paint primitives through the render module (render.geo_*), placed by
-- kit.to_render. A facing turns the other way in render space (y is
-- negated), so yaw is negated. dynamic: the per-frame layer. Returns how
-- many were painted.
function kit.emit_prims(prims, render, dynamic, ground)
    local k = kit.RENDER_SCALE
    ground = ground or 0
    local painted = 0
    for _, p in ipairs(prims) do
        local c = p.color
        local index
        if p.kind == "quad" then
            local a, b, cc, d = p.pts[1], p.pts[2], p.pts[3], p.pts[4]
            index = render.geo_quad(
                a[1] * k, a[3] * k + ground, -a[2] * k,
                b[1] * k, b[3] * k + ground, -b[2] * k,
                cc[1] * k, cc[3] * k + ground, -cc[2] * k,
                d[1] * k, d[3] * k + ground, -d[2] * k,
                c[1], c[2], c[3], dynamic)
        else
            local fn = p.kind == "box" and render.geo_box or render.geo_wedge
            index = fn(p.x * k, p.z * k + ground, -p.y * k,
                       p.len * k, p.hgt * k, p.wid * k, -p.yaw,
                       c[1], c[2], c[3], dynamic)
        end
        if index and index >= 0 then painted = painted + 1 end
    end
    return painted
end
-- }}}

-- {{{ World:emit
function World:emit(render, ground)
    return kit.emit_prims(self.prims, render, false, ground)
end
-- }}}
-- }}}

return kit

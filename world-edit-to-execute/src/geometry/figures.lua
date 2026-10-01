--[[
Figures (Issue 516b)

Little people and props made of boxes, posed each frame: a bowman, a straw
training dummy, an arrow, and a ring on the ground (for showing ranges).
Each returns a list of primitives in WC3 units (see geometry/kit.lua), to
paint on the dynamic layer with kit.emit_prims(prims, render, true).

    local figures = require("geometry.figures")
    local prims = figures.bowman(x, y, z, facing, { stride = s, draw = d })
]]

local kit = require("geometry.kit")
local local_point = kit.local_point

local figures = {}

figures.COLORS = {
    bowman      = { 240, 128, 36 },    -- orange
    bowman_dark = { 190, 92, 24 },
    hood        = { 250, 168, 70 },
    bow         = { 120, 72, 32 },
    string      = { 235, 225, 200 },
    straw       = { 206, 180, 96 },
    straw_dark  = { 160, 132, 64 },
    target      = { 200, 60, 50 },
    flash       = { 255, 255, 255 },
    arrow       = { 250, 240, 210 },
}

-- {{{ part
-- A box placed relative to a figure standing at (x, y, z) facing yaw:
-- along (forward), across (to its left), up (from its feet)
local function part(list, x, y, z, yaw, along, across, up, len, wid, hgt, color)
    local px, py = local_point(x, y, yaw, along, across)
    list[#list + 1] = { kind = "box", x = px, y = py, z = z + up, len = len,
                        wid = wid, hgt = hgt, yaw = yaw, color = color }
end
-- }}}

-- {{{ figures.bowman
-- A bowman about 90 units tall. opts:
--   stride: distance walked so far (swings the legs; nil stands still)
--   draw:   0..1, how far the bowstring is drawn back
--   color:  body colour (orange)
function figures.bowman(x, y, z, facing, opts)
    opts = opts or {}
    local C = figures.COLORS
    local body = opts.color or C.bowman
    local list = {}

    -- legs: swing opposite ways, one full step every 64 units walked
    local swing = 0
    if opts.stride then
        swing = math.sin(opts.stride * 2 * math.pi / 64) * 9
    end
    part(list, x, y, z, facing, swing, 7, 0, 12, 10, 38, C.bowman_dark)
    part(list, x, y, z, facing, -swing, -7, 0, 12, 10, 38, C.bowman_dark)

    -- torso, quiver on the back, hooded head
    part(list, x, y, z, facing, 0, 0, 38, 18, 26, 30, body)
    part(list, x, y, z, facing, -12, -6, 44, 8, 8, 30, C.bow)
    part(list, x, y, z, facing, 0, 0, 68, 18, 18, 18, C.hood)

    -- bow held out in front, left hand: a tall thin stave with bent tips
    local draw = opts.draw or 0
    part(list, x, y, z, facing, 22, 10, 36, 5, 5, 50, C.bow)
    part(list, x, y, z, facing, 18, 10, 84, 5, 5, 10, C.bow)
    part(list, x, y, z, facing, 18, 10, 28, 5, 5, 10, C.bow)
    -- the string, pulled back toward the chest as the bow is drawn
    part(list, x, y, z, facing, 17 - draw * 12, 10, 38, 2, 2, 46, C.string)
    -- drawing arm
    part(list, x, y, z, facing, 12 - draw * 6, 12, 58, 20 - draw * 6, 6, 6, body)

    return list
end
-- }}}

-- {{{ figures.dummy
-- A straw training dummy on a post, with a red target on its chest.
-- opts.stride sways it as it trundles along; opts.flash > 0 lights it white.
function figures.dummy(x, y, z, facing, opts)
    opts = opts or {}
    local C = figures.COLORS
    local lit = opts.flash and opts.flash > 0
    local straw = lit and C.flash or C.straw
    local list = {}
    local lean = opts.stride and math.sin(opts.stride * 2 * math.pi / 96) * 4 or 0
    part(list, x, y, z, facing, 0, 0, 0, 10, 10, 44, C.straw_dark)                -- post
    part(list, x, y, z, facing, lean, 0, 44, 22, 34, 40, straw)                   -- body
    part(list, x, y, z, facing, lean, 0, 58, 12, 60, 10, C.straw_dark)            -- arms
    part(list, x, y, z, facing, lean + 12, 0, 54, 2, 18, 18, lit and C.flash or C.target)
    part(list, x, y, z, facing, lean, 0, 84, 20, 20, 20, straw)                   -- head
    return list
end
-- }}}

-- {{{ figures.arrow
-- An arrow at (x, y, z) pointing along (dx, dy, dz)
function figures.arrow(x, y, z, dx, dy, dz)
    local flat = math.sqrt(dx * dx + dy * dy)
    local yaw = math.atan2(dy, dx)
    local list = {}
    -- the shaft, laid along yaw; pitch shows as a short rise over its length
    local len = 36
    local rise = flat > 0 and dz / flat * len or 0
    local tx, ty = local_point(x, y, yaw, -len / 2, 0)
    local hx, hy = local_point(x, y, yaw, len / 2, 0)
    local w = 1.5
    local sx, sy = local_point(0, 0, yaw, 0, w)
    list[1] = { kind = "quad", color = figures.COLORS.arrow, pts = {
        { tx - sx, ty - sy, z - rise / 2 }, { hx - sx, hy - sy, z + rise / 2 },
        { hx + sx, hy + sy, z + rise / 2 }, { tx + sx, ty + sy, z - rise / 2 },
    } }
    list[2] = { kind = "quad", color = figures.COLORS.arrow, pts = {
        { tx, ty, z - rise / 2 - w }, { hx, hy, z + rise / 2 - w },
        { hx, hy, z + rise / 2 + w }, { tx, ty, z - rise / 2 + w },
    } }
    return list
end
-- }}}

-- {{{ figures.ring
-- A thin ring of radius r around (x, y) at height z, made of quads: shows
-- what "r units from here" covers.
function figures.ring(x, y, z, r, color, segments, width)
    segments = segments or 48
    width = width or 6
    local list = {}
    for i = 0, segments - 1 do
        local a0 = i / segments * 2 * math.pi
        local a1 = (i + 1) / segments * 2 * math.pi
        local c0, s0, c1, s1 = math.cos(a0), math.sin(a0), math.cos(a1), math.sin(a1)
        list[#list + 1] = { kind = "quad", color = color, pts = {
            { x + c0 * (r - width), y + s0 * (r - width), z },
            { x + c1 * (r - width), y + s1 * (r - width), z },
            { x + c1 * (r + width), y + s1 * (r + width), z },
            { x + c0 * (r + width), y + s0 * (r + width), z },
        } }
    end
    return list
end
-- }}}

return figures

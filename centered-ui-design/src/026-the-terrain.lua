-- 026-the-terrain.lua - the land's shape, as a grid of lit points.
--
-- In plain terms: the ground is not painted. Instead the land is a grid of
-- points, like the corners of a terrain mesh without its triangles, and
-- each point knows three things: how high the land is there, which way its
-- slope faces, and what colour it is. The renderer (013) draws each point
-- as a small round sprite facing the camera, lit on the side toward the sun
-- — so a cliff facing east is bright in the morning and in shadow at
-- evening, like the cliffs of the Barrens (issue 214, the owner's picture).
--
-- This file only makes the data; drawing it is the renderer's business.
--
-- Data flow:  seed ─▶ mesas (flat-topped hills with steep sides)
--                  ─▶ for each ring of points (evenly spaced along it):
--                     height ─▶ facing (from the height's steepness)
--                            ─▶ colour (by height and steepness)
--
-- Points are spaced evenly along every ring and between rings, so a longer
-- ring far out holds more points than a short one near the hub ("At
-- distant distances, we'll have more of them, and closer we'll have
-- fewer").

local sphere_fold = require("004-the-sphere-fold")
local seeding = require("007-seeding-the-units")

local M = {}

-- How far apart points stand (ground units), along a ring and between
-- rings; how many mesas rise from the land; the gentle roll of the lowland.
-- Tuning knobs: record changes in docs/balance-updates.md.
M.POINT_SPACING = 3.0
M.MESA_COUNT = 9
M.ROLL_HEIGHT = 0.6

-- The land's paints, by where a point is: low ground, mesa tops, cliffs.
M.PAINTS = {
    meadow = { 0.42, 0.50, 0.26 },
    sand   = { 0.68, 0.60, 0.42 },
    top    = { 0.74, 0.62, 0.38 },
    cliff  = { 0.62, 0.38, 0.24 },
}

-- {{{ local function smooth()
local function smooth(edge0, edge1, x)
    local t = math.min(math.max((x - edge0) / (edge1 - edge0), 0), 1)
    return t * t * (3 - 2 * t)
end
-- }}}

-- {{{ function M.mesas()
-- The flat-topped hills, the same for the same seed: a list of
-- { x, z, radius, height, edge } (ground units; `edge` is how wide the cliff
-- is). They stand away from the hub, in the outer two thirds of the map.
function M.mesas(seed, fold)
    local stream = seeding.new_stream(seed + 4242)
    local hills = {}
    for index = 1, M.MESA_COUNT do
        local reach = fold.hub_radius + (fold.edge_radius - fold.hub_radius)
            * (0.35 + 0.6 * seeding.next_fraction(stream))
        local angle = 2 * math.pi * seeding.next_fraction(stream)
        hills[index] = {
            x = reach * math.sin(angle),
            z = -reach * math.cos(angle),
            radius = 7 + 10 * seeding.next_fraction(stream),
            height = 4 + 5 * seeding.next_fraction(stream),
            edge = 1.5 + 1.5 * seeding.next_fraction(stream),
        }
    end
    return hills
end
-- }}}

-- {{{ function M.height_at()
-- How high the land is at ground x, z: the highest mesa there (its top
-- flat, falling steeply across its edge), over a gentle roll.
function M.height_at(hills, x, z)
    local height = M.ROLL_HEIGHT * math.sin(x * 0.13) * math.sin(z * 0.11)
    for _, hill in ipairs(hills) do
        local distance = math.sqrt((x - hill.x) ^ 2 + (z - hill.z) ^ 2)
        local top = hill.height * smooth(hill.radius + hill.edge, hill.radius - hill.edge, distance)
        height = math.max(height, top)
    end
    return height
end
-- }}}

-- {{{ function M.facing_at()
-- Which way the land faces at x, z: a unit vector (nx, ny, nz), straight up
-- on flat ground, tipped toward the downhill side on a slope. From the
-- height's steepness, measured a small step either way.
function M.facing_at(hills, x, z)
    local step = 0.25
    local dx = (M.height_at(hills, x + step, z) - M.height_at(hills, x - step, z)) / (2 * step)
    local dz = (M.height_at(hills, x, z + step) - M.height_at(hills, x, z - step)) / (2 * step)
    local length = math.sqrt(dx * dx + 1 + dz * dz)
    return -dx / length, 1 / length, -dz / length
end
-- }}}

-- {{{ function M.sun_direction()
-- Where the sun is, as a unit vector from the ground toward it, at an hour
-- (the light dials' hour angle: 0 noon, -pi/2 morning, pi/2 evening, pi
-- midnight). It rises in the east (+x), stands high at noon, sets in the
-- west, and at night sits below the land. The Lua twin of sun_direction()
-- in the renderer's terrain shader (013).
function M.sun_direction(hour_angle)
    local x = -math.sin(hour_angle)
    local y = math.cos(hour_angle) * 0.9 + 0.1
    local z = -0.35
    local length = math.sqrt(x * x + y * y + z * z)
    return x / length, y / length, z / length
end
-- }}}

-- {{{ function M.build()
-- The terrain's points, the same for the same seed: a list of
-- { r (tier distance), angle, height, facing = { x, y, z },
--   color = { r, g, b } }, ring by ring from the hub outward.
function M.build(seed, fold)
    local hills = M.mesas(seed, fold)
    local stream = seeding.new_stream(seed + 1717)
    local points = {}
    local reach = fold.hub_radius + M.POINT_SPACING / 2
    while reach < fold.edge_radius do
        -- as many points on this ring as its length holds at the spacing
        local count = math.floor(2 * math.pi * reach / M.POINT_SPACING)
        local r = sphere_fold.tier_distance(fold, reach)
        for index = 0, count - 1 do
            -- a little jitter, so the grid does not show as stripes
            local angle = 2 * math.pi * (index + 0.35 * (seeding.next_fraction(stream) - 0.5)) / count
            local x, z = reach * math.sin(angle), -reach * math.cos(angle)
            local height = M.height_at(hills, x, z)
            local fx, fy, fz = M.facing_at(hills, x, z)
            -- the paint: cliffs where steep, tops where high, else lowland
            local paint
            if fy < 0.8 then
                paint = M.PAINTS.cliff
            elseif height > 2.5 then
                paint = M.PAINTS.top
            elseif seeding.next_fraction(stream) < 0.55 then
                paint = M.PAINTS.meadow
            else
                paint = M.PAINTS.sand
            end
            local shade = 0.9 + 0.2 * seeding.next_fraction(stream)
            points[#points + 1] = {
                r = r, angle = angle, height = height,
                facing = { fx, fy, fz },
                color = { paint[1] * shade, paint[2] * shade, paint[3] * shade },
            }
        end
        reach = reach + M.POINT_SPACING
    end
    return points
end
-- }}}

return M

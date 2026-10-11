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
M.POINT_SPACING = 3.0 / math.sqrt(2)   -- twice the points of a spacing of 3
M.MESA_COUNT = 9
M.ROLL_HEIGHT = 0.6

-- The lake: how far out its middle lies (a share of the way from the hub to
-- the edge), and its radius (ground units).
M.LAKE_REACH_SHARE = 0.22
M.LAKE_RADIUS = 11

-- Water's two colours: the sun side bright blue, the shade side deep blue;
-- near the shore the shade side muddier ("If it's dark, or if the water is
-- muddy, then darker blue, with particulates adding their own color").
M.WATER_SUN = { 0.55, 0.78, 0.92 }
M.WATER_SHADE = { 0.04, 0.10, 0.26 }
M.WATER_MUD = { 0.22, 0.18, 0.10 }

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

-- {{{ function M.shade_turn()
-- How far a point's circle is turned (radians, from bright-pole-up,
-- positive toward the screen's right), for a slope facing (fx, fy, fz)
-- under a sun (sx, sy, sz) whose side on screen is `sun_side` (positive:
-- right). The more squarely the slope faces the sun, the nearer to 0
-- (bright pole up: the land there reads lit); facing away, the nearer to
-- pi (dark pole up: in shadow). Nothing else lights the circle — "the
-- spinning of the sprite axies is what will display their lighting". The
-- Lua twin of the dot shader's turn.
function M.shade_turn(fx, fy, fz, sx, sy, sz, sun_side)
    local facing_sun = math.max(-1, math.min(1, fx * sx + fy * sy + fz * sz))
    local lean = math.acos(facing_sun)
    -- the bright pole leans toward the sun's side of the screen
    if sun_side < 0 then
        return -lean
    end
    return lean
end
-- }}}

-- {{{ function M.lake()
-- Where the lake is, the same for the same seed: { x, z, radius }.
function M.lake(seed, fold)
    local stream = seeding.new_stream(seed + 9090)
    local reach = fold.hub_radius + (fold.edge_radius - fold.hub_radius) * M.LAKE_REACH_SHARE
    local angle = 2 * math.pi * seeding.next_fraction(stream)
    return { x = reach * math.sin(angle), z = -reach * math.cos(angle), radius = M.LAKE_RADIUS }
end
-- }}}

-- {{{ function M.water_lean()
-- How far a water point is turned from sun-side-up (radians, 0..pi), and
-- its facing, at ground x, z and time t (seconds) with its wave phase,
-- under a sun (sx, sy, sz): three passing waves tip its surface. The Lua
-- twin of ceramics_water_lean in 020 (which the engine runs each step).
local WAVE_K = { { 0.35, 0.10 }, { -0.20, 0.50 }, { 0.55, -0.55 } }
local WAVE_SPEED = { 1.2, 1.7, 2.3 }
local WAVE_TIP = { 0.50, 0.38, 0.26 }
function M.water_lean(x, z, t, phase, sx, sy, sz)
    local slope_x, slope_z = 0, 0
    for w = 1, 3 do
        local kx, kz = WAVE_K[w][1], WAVE_K[w][2]
        local crest = math.cos(kx * x + kz * z - WAVE_SPEED[w] * t + phase * w)
        local k = math.sqrt(kx * kx + kz * kz)
        slope_x = slope_x + WAVE_TIP[w] * crest * kx / k
        slope_z = slope_z + WAVE_TIP[w] * crest * kz / k
    end
    local length = math.sqrt(slope_x * slope_x + 1 + slope_z * slope_z)
    local fx, fy, fz = -slope_x / length, 1 / length, -slope_z / length
    local facing_sun = math.max(-1, math.min(1, fx * sx + fy * sy + fz * sz))
    return math.acos(facing_sun), fx, fy, fz
end
-- }}}

-- {{{ function M.build()
-- The terrain's sheen-points, the same for the same seed: two lists, the
-- still land and the moving water, each point
-- { r (tier distance), angle, height, facing = { x, y, z },
--   sun_color = { r, g, b }, shade_color = { r, g, b }, wave_phase },
-- ring by ring from the hub outward. Every point records its own two
-- colours (the owner: "One side of the circle can be one color, and one
-- side another color, it's arbitrary, but should be recorded per circle").
function M.build(seed, fold)
    local hills = M.mesas(seed, fold)
    local lake = M.lake(seed, fold)
    local water = {}
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
            local from_lake = math.sqrt((x - lake.x) ^ 2 + (z - lake.z) ^ 2)
            -- in the lake: a water point, turned by the engine's waves
            if from_lake < lake.radius then
                local shore = math.max(0, math.min(1, (from_lake / lake.radius - 0.6) / 0.4))
                local shade = {}
                for channel = 1, 3 do
                    shade[channel] = M.WATER_SHADE[channel] + (M.WATER_MUD[channel] - M.WATER_SHADE[channel]) * shore
                end
                water[#water + 1] = {
                    r = sphere_fold.tier_distance(fold, reach), angle = angle, height = 0,
                    facing = { 0, 1, 0 },
                    sun_color = { M.WATER_SUN[1], M.WATER_SUN[2], M.WATER_SUN[3] },
                    shade_color = shade,
                    wave_phase = 2 * math.pi * seeding.next_fraction(stream),
                }
                goto next_point
            end
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
            local tone = 0.9 + 0.2 * seeding.next_fraction(stream)
            points[#points + 1] = {
                r = r, angle = angle, height = height,
                facing = { fx, fy, fz },
                -- the land's two colours: its paint lit, and its paint in
                -- shadow (a little cooler)
                sun_color = { paint[1] * tone * 1.25, paint[2] * tone * 1.25, paint[3] * tone * 1.2 },
                shade_color = { paint[1] * tone * 0.18, paint[2] * tone * 0.2, paint[3] * tone * 0.26 },
                wave_phase = 0,
            }
            ::next_point::
        end
        reach = reach + M.POINT_SPACING
    end
    return points, water
end
-- }}}

return M

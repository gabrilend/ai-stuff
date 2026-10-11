-- 018-the-light-pipe-model.lua - the inside of the light pipe, as a room.
--
-- In plain terms: the light pipe is the passage the laser light travels
-- down, curving around the head inside the crown. Seen from inside, it is a
-- long curved hall (the owner: "like a large atrium"): mirrored walls with
-- ridges that send light back, a mirror closing the back end with the red
-- and green emitters coming in from the side just in front of it, the beams
-- running down the middle, slotted tabs swung in from floor, ceiling and
-- sides, small paired levers that stir the liquid, a faint spiral of light
-- near the wall, and at the front the mirrored drum of the store with its
-- slit of an aperture. The liquid filling it all is shown as a haze.
--
-- Everything is made by formula (issue 105). Sizes are placeholders in
-- millimetres until phases 1 and 2 give real ones; they are chosen to show
-- the parts, not to be built.
--
-- Where things are: the pipe's middle line is an arc of a circle of radius
-- CURVE_RADIUS around the head's vertical axis, in the horizontal plane,
-- from the temple at the back (BACK_ANGLE) to the brow at the front
-- (FRONT_ANGLE). +x points forward out of the face, z to the wearer's left,
-- y up, as in the crown sketch (002). A place in the pipe is given by s,
-- 0 at the back mirror to 1 at the store, and an offset across the pipe:
-- `up` (toward the ceiling) and `out` (toward the outer wall), each a share
-- of the pipe's radius.

local record = require("001-the-shape-record")
local kit = require("002-the-test-shapes").kit

local M = {}

local CURVE_RADIUS = 90          -- mm, head centre to the pipe's middle line
local BACK_ANGLE = 2.4           -- radians around the head: by the temple
local FRONT_ANGLE = 0.15         -- radians: at the brow
local PIPE_RADIUS = 7            -- mm, the hall's half-height
local AROUND = 40                -- steps around a cross-section
local ALONG = 160                -- steps along the curve

-- {{{ small vector arithmetic
local function add(a, b) return { a[1] + b[1], a[2] + b[2], a[3] + b[3] } end
local function scale(a, k) return { a[1] * k, a[2] * k, a[3] * k } end
local function cross(a, b) return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] } end
local function unit(a)
    local length = math.sqrt(a[1] * a[1] + a[2] * a[2] + a[3] * a[3])
    return { a[1] / length, a[2] / length, a[3] / length }
end
-- }}}

-- {{{ the curve and its frame
local UP = { 0, 1, 0 }
local function angle_at(s) return BACK_ANGLE + (FRONT_ANGLE - BACK_ANGLE) * s end
-- the middle line at s
local function middle(s)
    local a = angle_at(s)
    return { CURVE_RADIUS * math.cos(a), 0, CURVE_RADIUS * math.sin(a) }
end
-- outward from the head, at s
local function outward(s)
    local a = angle_at(s)
    return { math.cos(a), 0, math.sin(a) }
end
-- the way light travels (back to front), at s
local function forward(s)
    local a = angle_at(s)
    return { math.sin(a), 0, -math.cos(a) }
end
-- a point in the pipe: s along, `up` and `out` as shares of the radius
local function at(s, up, out)
    return add(middle(s), add(scale(UP, (up or 0) * PIPE_RADIUS), scale(outward(s), (out or 0) * PIPE_RADIUS)))
end
-- the wall's direction at angle phi around the cross-section (0 = outer
-- wall, pi/2 = ceiling)
local function across(s, phi)
    return add(scale(outward(s), math.cos(phi)), scale(UP, math.sin(phi)))
end
M.at, M.forward = at, forward
-- }}}

-- {{{ shapes made from the pieces above
-- {{{ local function oriented_box()
-- A box around `centre` with half-sizes h1, h2, h3 along the unit
-- directions a1, a2, a3.
local function oriented_box(part, centre, a1, h1, a2, h2, a3, h3)
    local function corner(i, j, k)
        return add(centre, add(scale(a1, i * h1), add(scale(a2, j * h2), scale(a3, k * h3))))
    end
    local faces = {
        { corner(-1, -1, -1), corner(1, -1, -1), corner(1, 1, -1), corner(-1, 1, -1) },
        { corner(-1, -1, 1), corner(1, -1, 1), corner(1, 1, 1), corner(-1, 1, 1) },
        { corner(-1, -1, -1), corner(1, -1, -1), corner(1, -1, 1), corner(-1, -1, 1) },
        { corner(-1, 1, -1), corner(1, 1, -1), corner(1, 1, 1), corner(-1, 1, 1) },
        { corner(-1, -1, -1), corner(-1, 1, -1), corner(-1, 1, 1), corner(-1, -1, 1) },
        { corner(1, -1, -1), corner(1, 1, -1), corner(1, 1, 1), corner(1, -1, 1) },
    }
    for _, f in ipairs(faces) do kit.quad(part, f[1], f[2], f[3], f[4], centre) end
end
-- }}}

-- {{{ local function tube()
-- A thin tube following `path(t)` for t from 0 to 1, of radius r, closed at
-- both ends. Its cross-section is turned to stay square to the path.
local function tube(part, path, r, steps, sides)
    local rings = {}
    for i = 0, steps do
        local t = i / steps
        local p = path(t)
        local q = path(math.min(1, t + 1e-3))
        local o = path(math.max(0, t - 1e-3))
        local d = unit({ q[1] - o[1], q[2] - o[2], q[3] - o[3] })
        -- a direction across the path: up unless the path runs up
        local side = math.abs(d[2]) > 0.9 and { 1, 0, 0 } or UP
        local e1 = unit(cross(d, side))
        local e2 = cross(d, e1)
        local ring = {}
        for k = 0, sides - 1 do
            local a = 2 * math.pi * k / sides
            ring[k + 1] = add(p, add(scale(e1, r * math.cos(a)), scale(e2, r * math.sin(a))))
        end
        rings[i + 1] = { centre = p, points = ring }
    end
    for i = 1, steps do
        local inside = scale(add(rings[i].centre, rings[i + 1].centre), 0.5)
        for k = 1, sides do
            local k2 = k % sides + 1
            kit.quad(part, rings[i].points[k], rings[i].points[k2], rings[i + 1].points[k2], rings[i + 1].points[k], inside)
        end
    end
    for _, i in ipairs({ 1, steps + 1 }) do
        local other = (i == 1) and rings[2].centre or rings[steps].centre
        local inside = scale(add(rings[i].centre, other), 0.5)
        for k = 1, sides do
            kit.outward_triangle(part, rings[i].centre, rings[i].points[k], rings[i].points[k % sides + 1], inside)
        end
    end
end
-- }}}

-- {{{ local function disc()
-- A flat round sheet at `centre`, facing `normal`, of radius r (both faces
-- are lit the same, so one face is enough).
local function disc(part, centre, normal, r, sides)
    local side = math.abs(normal[2]) > 0.9 and { 1, 0, 0 } or UP
    local e1 = unit(cross(normal, side))
    local e2 = cross(normal, e1)
    for k = 0, sides - 1 do
        local a0, a1 = 2 * math.pi * k / sides, 2 * math.pi * (k + 1) / sides
        local p0 = add(centre, add(scale(e1, r * math.cos(a0)), scale(e2, r * math.sin(a0))))
        local p1 = add(centre, add(scale(e1, r * math.cos(a1)), scale(e2, r * math.sin(a1))))
        record.add_triangle(part, centre[1], centre[2], centre[3], p0[1], p0[2], p0[3], p1[1], p1[2], p1[3])
    end
end
-- }}}
-- }}}

-- {{{ the parts
-- {{{ local function add_wall()
-- The mirrored wall: the inside of a tube along the curve, open at both
-- ends (the back mirror and the store close them).
local function add_wall(part)
    for i = 0, ALONG - 1 do
        local s0, s1 = i / ALONG, (i + 1) / ALONG
        for k = 0, AROUND - 1 do
            local f0, f1 = 2 * math.pi * k / AROUND, 2 * math.pi * (k + 1) / AROUND
            local a = add(middle(s0), scale(across(s0, f0), PIPE_RADIUS))
            local b = add(middle(s0), scale(across(s0, f1), PIPE_RADIUS))
            local c = add(middle(s1), scale(across(s1, f1), PIPE_RADIUS))
            local d = add(middle(s1), scale(across(s1, f0), PIPE_RADIUS))
            -- facing inward (toward the middle line), the side seen from
            -- inside the hall
            kit.quad(part, a, b, c, d, add(middle(s0), scale(across(s0, f0), 2 * PIPE_RADIUS)))
        end
    end
end
-- }}}

-- {{{ local function add_ridges()
-- Rings carved into the wall, each a sawtooth: a steep face toward the
-- front and a long slope back, so light meeting one is sent backward.
local function add_ridges(part)
    local depth, slope = 0.12 * PIPE_RADIUS, 0.012
    for s = 0.08, 0.96, 0.055 do
        for k = 0, AROUND - 1 do
            local f0, f1 = 2 * math.pi * k / AROUND, 2 * math.pi * (k + 1) / AROUND
            -- front foot, crest (same s), back foot (a little toward the back)
            local function foot(phi) return add(middle(s), scale(across(s, phi), PIPE_RADIUS)) end
            local function crest(phi) return add(middle(s), scale(across(s, phi), PIPE_RADIUS - depth)) end
            local function back(phi) return add(middle(s - slope), scale(across(s - slope, phi), PIPE_RADIUS)) end
            local inside = add(middle(s), scale(across(s, (f0 + f1) / 2), 2 * PIPE_RADIUS))
            kit.quad(part, foot(f0), foot(f1), crest(f1), crest(f0), inside)
            kit.quad(part, crest(f0), crest(f1), back(f1), back(f0), inside)
        end
    end
end
-- }}}

-- {{{ local function add_tab()
-- One tab: hinged on the wall at s, on the side `side_phi` (0 outer wall,
-- pi/2 ceiling, pi inner wall, 3pi/2 floor), swung `swing` radians toward
-- the front from standing straight across the pipe. A strip of `slots`
-- windows; `open[i]` true where light passes. Built from two side rails,
-- a bar between each pair of windows, and a plate in every closed window.
local function add_tab(tab_part, hinge_part, s, side_phi, swing, open)
    local wall_dir = across(s, side_phi)
    local inward = scale(wall_dir, -1)
    local length_dir = unit(add(scale(inward, math.cos(swing)), scale(forward(s), math.sin(swing))))
    local width_dir = unit(cross(length_dir, forward(s)))
    -- the plate's own face, square to its length and width
    local face_dir = cross(length_dir, width_dir)
    local hinge = add(middle(s), scale(wall_dir, 0.86 * PIPE_RADIUS))
    local length, width, thick = 1.5 * PIPE_RADIUS, 0.7 * PIPE_RADIUS, 0.05 * PIPE_RADIUS
    local rail = 0.1 * width
    local cell = length / #open
    for _, edge in ipairs({ -1, 1 }) do
        local centre = add(hinge, add(scale(length_dir, length / 2), scale(width_dir, edge * (width / 2 - rail / 2))))
        oriented_box(tab_part, centre, length_dir, length / 2, width_dir, rail / 2, face_dir, thick / 2)
    end
    for i = 0, #open do
        local centre = add(hinge, scale(length_dir, i * cell))
        oriented_box(tab_part, centre, length_dir, 0.04 * cell, width_dir, width / 2, face_dir, thick / 2)
    end
    for i, is_open in ipairs(open) do
        if not is_open then
            local centre = add(hinge, scale(length_dir, (i - 0.5) * cell))
            oriented_box(tab_part, centre, length_dir, cell / 2, width_dir, width / 2 - rail, face_dir, thick / 4)
        end
    end
    -- the hinge pin, across the tab's foot
    tube(hinge_part, function(t) return add(hinge, scale(width_dir, (t - 0.5) * width * 1.1)) end, 0.06 * PIPE_RADIUS, 1, 12)
end
-- }}}

-- {{{ local function add_lever_pair()
-- Two small levers side by side on the lower wall, each a motor (a short
-- drum on the wall) and an arm reaching in toward the front: duplicated,
-- so they share the load and, drawing different currents, report a fault.
local function add_lever_pair(motor_part, arm_part, s, phi)
    for _, offset in ipairs({ -0.012, 0.012 }) do
        local here = s + offset
        local wall_dir = across(here, phi)
        local base = add(middle(here), scale(wall_dir, 0.9 * PIPE_RADIUS))
        tube(motor_part, function(t) return add(base, scale(wall_dir, (t - 0.5) * 0.2 * PIPE_RADIUS)) end, 0.14 * PIPE_RADIUS, 1, 16)
        local arm_dir = unit(add(scale(wall_dir, -1), scale(forward(here), 0.8)))
        local arm_centre = add(base, scale(arm_dir, 0.22 * PIPE_RADIUS))
        local side = unit(cross(arm_dir, forward(here)))
        oriented_box(arm_part, arm_centre, arm_dir, 0.22 * PIPE_RADIUS, side, 0.03 * PIPE_RADIUS, cross(arm_dir, side), 0.02 * PIPE_RADIUS)
    end
end
-- }}}

-- {{{ local function add_store()
-- The store: a mirrored drum standing upright just past the pipe's front
-- end, its wall open where the pipe comes in and slit opposite (the
-- aperture), with a gold frame around the slit.
local function add_store(drum_part, aperture_part)
    local radius, half_height = 1.25 * PIPE_RADIUS, 1.2 * PIPE_RADIUS
    local f = forward(1)
    local centre = add(middle(1), scale(f, radius * 0.9))
    -- angles around the drum, measured from the forward direction
    local side = unit(cross(UP, f))
    local function rim(a, y) return add(centre, add(add(scale(f, radius * math.cos(a)), scale(side, radius * math.sin(a))), scale(UP, y))) end
    local entrance = math.asin(math.min(1, PIPE_RADIUS * 1.05 / radius))
    local slit = 0.07
    local steps = 72
    for k = 0, steps - 1 do
        local a0, a1 = 2 * math.pi * k / steps, 2 * math.pi * (k + 1) / steps
        local middle_angle = (a0 + a1) / 2
        local from_back = math.abs(((middle_angle - math.pi + math.pi) % (2 * math.pi)) - math.pi)
        local from_front = math.abs(((middle_angle + math.pi) % (2 * math.pi)) - math.pi)
        -- no wall where the pipe enters (the back) or across the slit (the front)
        if from_back > entrance and from_front > slit then
            kit.quad(drum_part, rim(a0, -half_height), rim(a1, -half_height), rim(a1, half_height), rim(a0, half_height), add(centre, scale(f, 0)))
        end
    end
    disc(drum_part, add(centre, scale(UP, half_height)), UP, radius, 48)
    disc(drum_part, add(centre, scale(UP, -half_height)), UP, radius, 48)
    -- the slit's frame: two posts and a sill and lintel
    for _, a in ipairs({ -slit, slit }) do
        local p = rim(a, 0)
        oriented_box(aperture_part, p, UP, half_height, side, 0.05 * PIPE_RADIUS, f, 0.08 * PIPE_RADIUS)
    end
    for _, y in ipairs({ -half_height, half_height }) do
        oriented_box(aperture_part, add(rim(0, y), scale(f, 0)), side, radius * math.sin(slit) + 0.05 * PIPE_RADIUS, UP, 0.05 * PIPE_RADIUS, f, 0.08 * PIPE_RADIUS)
    end
    return centre, radius
end
-- }}}
-- }}}

-- {{{ function M.build()
-- The whole model: a finished shape record with its stations and filling.
function M.build()
    local shape = record.new("light-pipe", "made", "y")
    shape.units = "millimetres"
    local function part(name, colour) return record.add_part(shape, name, colour) end

    local wall = part("light pipe wall", { 0.62, 0.66, 0.72 })
    local ridges = part("wall ridges", { 0.80, 0.83, 0.88 })
    local back_mirror = part("back mirror", { 0.92, 0.94, 0.97 })
    local red_emitter = part("red emitter", { 0.85, 0.15, 0.12 })
    local green_emitter = part("green emitter", { 0.15, 0.80, 0.25 })
    local red_beam = part("red beam", { 1.0, 0.35, 0.30 })
    local green_beam = part("green beam", { 0.45, 1.0, 0.45 })
    local tabs = part("tabs", { 0.16, 0.17, 0.20 })
    local hinges = part("tab hinges", { 0.78, 0.62, 0.30 })
    local motors = part("lever motors", { 0.45, 0.38, 0.30 })
    local levers = part("levers", { 0.70, 0.55, 0.35 })
    local vortex = part("light vortex", { 0.40, 0.95, 0.90 })
    local store = part("store", { 0.55, 0.62, 0.78 })
    local aperture = part("aperture", { 0.95, 0.80, 0.30 })

    add_wall(wall)
    add_ridges(ridges)
    disc(back_mirror, middle(0), forward(0), PIPE_RADIUS, AROUND)

    -- {{{ emitters and beams
    -- the emitters come in through the upper wall just in front of the
    -- back mirror; each beam runs from its emitter's tip to the middle, then
    -- along the curve to the store
    local beams = { { emitter = red_emitter, beam = red_beam, phi = 0.62 * math.pi, up = 0.08 },
                    { emitter = green_emitter, beam = green_beam, phi = 0.38 * math.pi, up = -0.08 } }
    for _, b in ipairs(beams) do
        local s = 0.05
        local dir = across(s, b.phi)
        local outside = add(middle(s), scale(dir, 1.5 * PIPE_RADIUS))
        local tip = add(middle(s), scale(dir, 0.8 * PIPE_RADIUS))
        tube(b.emitter, function(t) return add(outside, scale(add(tip, scale(outside, -1)), t)) end, 0.16 * PIPE_RADIUS, 1, 20)
        local start = at(0.08, b.up, 0)
        tube(b.beam, function(t) return add(tip, scale(add(start, scale(tip, -1)), t)) end, 0.025 * PIPE_RADIUS, 1, 10)
        tube(b.beam, function(t) return at(0.08 + 0.95 * t * (1 - 0.08), b.up, 0) end, 0.025 * PIPE_RADIUS, 120, 10)
    end
    -- }}}

    -- {{{ tabs: positions, sides, swings and slot patterns
    local o, x = true, false
    local tab_plan = {
        { s = 0.22, side = 1.5 * math.pi, swing = 0.0,  open = { o, x, o, o, x, o, x, o } },
        { s = 0.32, side = 0.5 * math.pi, swing = 0.45, open = { x, o, o, x, o, o, o, x } },
        { s = 0.43, side = 0.0,           swing = 0.8,  open = { o, o, x, o, x, x, o, o } },
        { s = 0.53, side = math.pi,       swing = -0.35, open = { x, x, o, o, o, x, o, o } },
        { s = 0.66, side = 1.5 * math.pi, swing = 1.0,  open = { o, x, x, o, o, o, x, o } },
        { s = 0.78, side = 0.5 * math.pi, swing = 0.2,  open = { o, o, o, x, o, x, o, x } },
    }
    for _, t in ipairs(tab_plan) do add_tab(tabs, hinges, t.s, t.side, t.swing, t.open) end
    -- }}}

    for _, s in ipairs({ 0.27, 0.49, 0.61, 0.86 }) do add_lever_pair(motors, levers, s, 1.25 * math.pi) end
    tube(vortex, function(t)
        local phi = 0.3 + 7 * 2 * math.pi * t
        return add(middle(0.04 + 0.92 * t), scale(across(0.04 + 0.92 * t, phi), 0.8 * PIPE_RADIUS))
    end, 0.018 * PIPE_RADIUS, 900, 8)
    local store_centre, store_radius = add_store(store, aperture)

    -- {{{ stations: where to stand, and what to look at
    local f1 = forward(1)
    -- stations stand off the middle line: the beams run down it, and a
    -- camera standing in a beam sees nothing but the beam (the first set of
    -- pictures, 055-066 in development-history, did exactly that)
    local function station(name, eye, look) return { name = name, eye = eye, look = look } end
    shape.stations = {
        station("back-mirror", at(0.14, -0.3, -0.3), at(0.0, 0, 0)),
        station("emitters-from-above", at(0.16, 0.6, 0), at(0.05, 0.55, 0)),
        station("first-tabs-low", at(0.10, -0.55, 0), at(0.30, 0, 0)),
        station("along-the-middle", at(0.28, 0.3, -0.35), at(0.45, 0, 0)),
        station("ceiling-looking-back", at(0.44, 0.6, 0), at(0.26, -0.2, 0)),
        station("outer-wall-across", at(0.50, 0, 0.6), at(0.56, 0, -0.6)),
        station("levers-low", at(0.56, -0.5, -0.3), at(0.64, -0.65, -0.4)),
        station("along-the-middle-2", at(0.62, -0.3, 0.35), at(0.80, 0, 0)),
        station("high-looking-back", at(0.80, 0.55, 0), at(0.60, -0.3, 0)),
        station("toward-the-store", at(0.88, 0.3, 0.3), add(store_centre, scale(f1, store_radius))),
        station("aperture-from-low", at(0.97, -0.5, 0), add(store_centre, add(scale(f1, store_radius), scale(UP, 0.3 * PIPE_RADIUS)))),
        station("inside-the-store", add(store_centre, scale(UP, 0.4 * PIPE_RADIUS)), at(0.86, 0, 0)),
    }
    -- }}}

    -- the index-matched liquid, as a pale haze thickening with distance
    shape.filling = { colour = { 0.52, 0.74, 0.82 }, density = 0.03 }
    return record.finish(shape)
end
-- }}}

return M

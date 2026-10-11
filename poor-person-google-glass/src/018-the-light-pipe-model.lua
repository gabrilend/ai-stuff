-- 018-the-light-pipe-model.lua - the inside of the light pipe, as a room.
--
-- In plain terms: the light pipe is the passage the laser light travels
-- down, curving around the head inside the crown. Seen from inside, it is a
-- long curved hall (the owner: "like a large atrium", "sized like a room,
-- picture an interior design magazine image"). Its wall is the boundary
-- where the glass core meets a lower-index cladding, so light striking it at
-- a glancing angle is turned back in (total internal reflection), and that
-- boundary is made of facets:
--   contributing facets lie flat and pass light on toward the output;
--   recycling facets are tilted a few degrees to face backward, each a
--   slightly different amount along a spiral, so the light they turn back
--   feeds a different part of the coruscating vortex.
-- At the back, a mirror closes the hall, the red and green emitters coming
-- in through the upper wall just in front of it. The beams run down the
-- middle; slotted tabs swing in from floor, ceiling and sides; paired
-- levers stir the liquid; three glowing strands of light spiral near the
-- wall. The last stretch narrows into a concentrator funnel ending at the
-- output aperture, beyond which stands the store's mirrored drum with its
-- slit. The index-matched liquid fills it all, shown as a haze.
--
-- Everything is made by formula (issue 105). Sizes are placeholders in
-- millimetres until phases 1 and 2 give real ones; they are chosen to show
-- the parts, not to be built.
--
-- Where things are: the pipe's middle line is an arc of a circle of radius
-- CURVE_RADIUS around the head's vertical axis, in the horizontal plane,
-- from the temple at the back (BACK_ANGLE) to the brow at the front
-- (FRONT_ANGLE). +x points forward out of the face, z to the wearer's left,
-- y up. A place in the pipe is given by s, 0 at the back mirror to 1 at the
-- output aperture, and an offset across the pipe: `up` (toward the ceiling)
-- and `out` (toward the outer wall), each a share of the pipe's radius at s
-- (which shrinks through the concentrator).

local record = require("001-the-shape-record")
local kit = require("002-the-test-shapes").kit

local M = {}

local CURVE_RADIUS = 90          -- mm, head centre to the pipe's middle line
local BACK_ANGLE = 2.4           -- radians around the head: by the temple
local FRONT_ANGLE = 0.15         -- radians: at the brow
local PIPE_RADIUS = 7            -- mm, the hall's half-height
local CONCENTRATOR_STARTS = 0.80 -- s where the funnel begins
local APERTURE_SHARE = 0.32      -- the output aperture's radius, share of PIPE_RADIUS
local FACETS_ALONG = 96          -- facets from back mirror to output
local FACETS_AROUND = 24         -- facets around the wall

-- {{{ small vector arithmetic
local function add(a, b) return { a[1] + b[1], a[2] + b[2], a[3] + b[3] } end
local function scale(a, k) return { a[1] * k, a[2] * k, a[3] * k } end
local function cross(a, b) return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] } end
local function unit(a)
    local length = math.sqrt(a[1] * a[1] + a[2] * a[2] + a[3] * a[3])
    return { a[1] / length, a[2] / length, a[3] / length }
end
local function distance(a, b) return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2) end
-- }}}

-- {{{ the curve, its radius, and its frame
local UP = { 0, 1, 0 }
local function angle_at(s) return BACK_ANGLE + (FRONT_ANGLE - BACK_ANGLE) * s end
-- the pipe's radius at s: constant, then narrowing smoothly (a half cosine)
-- through the concentrator to the output aperture
local function radius_at(s)
    if s <= CONCENTRATOR_STARTS then return PIPE_RADIUS end
    local t = math.min(1, (s - CONCENTRATOR_STARTS) / (1 - CONCENTRATOR_STARTS))
    return PIPE_RADIUS * (APERTURE_SHARE + (1 - APERTURE_SHARE) * (0.5 + 0.5 * math.cos(math.pi * t)))
end
local function middle(s)
    local a = angle_at(s)
    return { CURVE_RADIUS * math.cos(a), 0, CURVE_RADIUS * math.sin(a) }
end
local function outward(s)
    local a = angle_at(s)
    return { math.cos(a), 0, math.sin(a) }
end
-- the way light travels (back to front), at s
local function forward(s)
    local a = angle_at(s)
    return { math.sin(a), 0, -math.cos(a) }
end
-- a point in the pipe: s along, `up` and `out` as shares of the radius at s
local function at(s, up, out)
    local r = radius_at(math.min(1, math.max(0, s)))
    return add(middle(s), add(scale(UP, (up or 0) * r), scale(outward(s), (out or 0) * r)))
end
-- the wall's direction at angle phi around the cross-section (0 = outer
-- wall, pi/2 = ceiling)
local function across(s, phi)
    return add(scale(outward(s), math.cos(phi)), scale(UP, math.sin(phi)))
end
local function on_wall(s, phi, inset) return add(middle(s), scale(across(s, phi), radius_at(s) - (inset or 0))) end
M.at, M.forward, M.radius_at = at, forward, radius_at
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
-- {{{ local function recycling_tilt()
-- How many degrees a recycling facet faces backward: 2 to 6, rising and
-- falling along a spiral (the angle around the wall and the distance along
-- it, together), so neighbouring facets return light to slightly different
-- parts of the vortex.
local function recycling_tilt(s, phi)
    return 2 + 4 * (0.5 + 0.5 * math.sin(3 * phi + 25 * s))
end
M.recycling_tilt = recycling_tilt
-- }}}

-- {{{ local function add_facets()
-- The wall, as facets. A contributing facet lies on the wall. A recycling
-- facet is tilted to face backward: its back edge on the wall, its front
-- edge stood in from the wall by the facet's length x tan(tilt), so its
-- surface faces partly back down the hall; a small step at its front edge
-- returns to the wall. Facets in the concentrator, and just before it,
-- contribute; the rest recycle.
local function add_facets(contributing, recycling, steps)
    for i = 0, FACETS_ALONG - 1 do
        local s0, s1 = i / FACETS_ALONG, (i + 1) / FACETS_ALONG
        local length = distance(middle(s0), middle(s1))
        for k = 0, FACETS_AROUND - 1 do
            local f0, f1 = 2 * math.pi * k / FACETS_AROUND, 2 * math.pi * (k + 1) / FACETS_AROUND
            -- seen from inside: each facet faces away from a point beyond the wall
            local beyond = on_wall((s0 + s1) / 2, (f0 + f1) / 2, -radius_at((s0 + s1) / 2))
            if s0 >= CONCENTRATOR_STARTS - 0.04 then
                kit.quad(contributing, on_wall(s0, f0), on_wall(s0, f1), on_wall(s1, f1), on_wall(s1, f0), beyond)
            else
                local inset = length * math.tan(math.rad(recycling_tilt((s0 + s1) / 2, (f0 + f1) / 2)))
                kit.quad(recycling, on_wall(s0, f0), on_wall(s0, f1), on_wall(s1, f1, inset), on_wall(s1, f0, inset), beyond)
                -- the step back to the wall, facing forward (away from the
                -- facet's own body, just behind it)
                local body = on_wall(s1 - 0.25 / FACETS_ALONG, (f0 + f1) / 2, inset / 2)
                kit.quad(steps, on_wall(s1, f0, inset), on_wall(s1, f1, inset), on_wall(s1, f1), on_wall(s1, f0), body)
            end
        end
    end
end
-- }}}

-- {{{ local function add_cladding()
-- The lower-index cladding around the core: a shell just outside the
-- facets, seen through the seams between them.
local function add_cladding(part)
    local steps, around = 120, 32
    for i = 0, steps - 1 do
        local s0, s1 = i / steps, (i + 1) / steps
        for k = 0, around - 1 do
            local f0, f1 = 2 * math.pi * k / around, 2 * math.pi * (k + 1) / around
            local out = -0.06 * PIPE_RADIUS
            local beyond = on_wall((s0 + s1) / 2, (f0 + f1) / 2, -2 * radius_at((s0 + s1) / 2))
            kit.quad(part, on_wall(s0, f0, out), on_wall(s0, f1, out), on_wall(s1, f1, out), on_wall(s1, f0, out), beyond)
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
-- The store: a mirrored drum standing upright just past the output
-- aperture, its wall open where the light comes in and slit opposite, with
-- a gold frame around the slit.
local function add_store(drum_part, slit_part)
    local radius, half_height = 1.25 * PIPE_RADIUS, 1.2 * PIPE_RADIUS
    local f = forward(1)
    local centre = add(middle(1), scale(f, radius * 0.97))
    local side = unit(cross(UP, f))
    local function rim(a, y) return add(centre, add(add(scale(f, radius * math.cos(a)), scale(side, radius * math.sin(a))), scale(UP, y))) end
    local entrance = math.asin(math.min(1, radius_at(1) * 1.3 / radius))
    local slit = 0.07
    local steps = 72
    for k = 0, steps - 1 do
        local a0, a1 = 2 * math.pi * k / steps, 2 * math.pi * (k + 1) / steps
        local middle_angle = (a0 + a1) / 2
        local from_back = math.abs(((middle_angle - math.pi + math.pi) % (2 * math.pi)) - math.pi)
        local from_front = math.abs(((middle_angle + math.pi) % (2 * math.pi)) - math.pi)
        -- no wall where the light enters (the back) or across the slit (the front)
        if from_back > entrance and from_front > slit then
            kit.quad(drum_part, rim(a0, -half_height), rim(a1, -half_height), rim(a1, half_height), rim(a0, half_height), centre)
        end
    end
    disc(drum_part, add(centre, scale(UP, half_height)), UP, radius, 48)
    disc(drum_part, add(centre, scale(UP, -half_height)), UP, radius, 48)
    for _, a in ipairs({ -slit, slit }) do
        oriented_box(slit_part, rim(a, 0), UP, half_height, side, 0.05 * PIPE_RADIUS, f, 0.08 * PIPE_RADIUS)
    end
    for _, y in ipairs({ -half_height, half_height }) do
        oriented_box(slit_part, rim(0, y), side, radius * math.sin(slit) + 0.05 * PIPE_RADIUS, UP, 0.05 * PIPE_RADIUS, f, 0.08 * PIPE_RADIUS)
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
    local function part(name, colour, glow)
        local p = record.add_part(shape, name, colour)
        if glow then p.glow = true end
        return p
    end

    local contributing = part("contributing facets", { 0.86, 0.89, 0.93 })
    local recycling = part("recycling facets", { 0.60, 0.68, 0.80 })
    local facet_steps = part("facet steps", { 0.38, 0.44, 0.55 })
    local cladding = part("cladding", { 0.10, 0.16, 0.32 })
    local back_mirror = part("back mirror", { 0.95, 0.96, 0.98 })
    local red_emitter = part("red emitter", { 0.85, 0.15, 0.12 })
    local green_emitter = part("green emitter", { 0.15, 0.80, 0.25 })
    local red_beam = part("red beam", { 1.0, 0.30, 0.25 }, true)
    local green_beam = part("green beam", { 0.40, 1.0, 0.45 }, true)
    local tabs = part("tabs", { 0.16, 0.17, 0.20 })
    local hinges = part("tab hinges", { 0.78, 0.62, 0.30 })
    local motors = part("lever motors", { 0.45, 0.38, 0.30 })
    local levers = part("levers", { 0.70, 0.55, 0.35 })
    local strands = {
        part("vortex strand, red", { 1.0, 0.45, 0.40 }, true),
        part("vortex strand, green", { 0.50, 1.0, 0.60 }, true),
        part("vortex strand, gold", { 1.0, 0.85, 0.40 }, true),
    }
    local aperture = part("output aperture", { 0.95, 0.78, 0.32 })
    local store = part("store", { 0.55, 0.62, 0.78 })
    local slit = part("store slit", { 0.85, 0.70, 0.30 })

    add_facets(contributing, recycling, facet_steps)
    add_cladding(cladding)
    disc(back_mirror, middle(0), forward(0), PIPE_RADIUS, 48)

    -- {{{ emitters and beams
    -- the emitters come in through the upper wall just in front of the back
    -- mirror; each beam runs from its emitter's tip to the middle, then
    -- along the curve, drawn together by the concentrator into the aperture
    local beams = { { emitter = red_emitter, beam = red_beam, phi = 0.62 * math.pi, up = 0.08 },
                    { emitter = green_emitter, beam = green_beam, phi = 0.38 * math.pi, up = -0.08 } }
    for _, b in ipairs(beams) do
        local s = 0.05
        local dir = across(s, b.phi)
        local outside = add(middle(s), scale(dir, 1.5 * PIPE_RADIUS))
        local tip = add(middle(s), scale(dir, 0.8 * PIPE_RADIUS))
        tube(b.emitter, function(t) return add(outside, scale(add(tip, scale(outside, -1)), t)) end, 0.16 * PIPE_RADIUS, 1, 20)
        local start = at(0.08, b.up, 0)
        tube(b.beam, function(t) return add(tip, scale(add(start, scale(tip, -1)), t)) end, 0.012 * PIPE_RADIUS, 1, 10)
        tube(b.beam, function(t) return at(0.08 + 0.92 * t, b.up, 0) end, 0.012 * PIPE_RADIUS, 140, 10)
    end
    -- }}}

    -- {{{ tabs: positions, sides, swings and slot patterns
    local o, x = true, false
    local tab_plan = {
        { s = 0.20, side = 1.5 * math.pi, swing = 0.0,  open = { o, x, o, o, x, o, x, o } },
        { s = 0.30, side = 0.5 * math.pi, swing = 0.45, open = { x, o, o, x, o, o, o, x } },
        { s = 0.40, side = 0.0,           swing = 0.8,  open = { o, o, x, o, x, x, o, o } },
        { s = 0.50, side = math.pi,       swing = -0.35, open = { x, x, o, o, o, x, o, o } },
        { s = 0.61, side = 1.5 * math.pi, swing = 1.0,  open = { o, x, x, o, o, o, x, o } },
        { s = 0.71, side = 0.5 * math.pi, swing = 0.2,  open = { o, o, o, x, o, x, o, x } },
    }
    for _, t in ipairs(tab_plan) do add_tab(tabs, hinges, t.s, t.side, t.swing, t.open) end
    -- }}}

    for _, s in ipairs({ 0.26, 0.45, 0.56, 0.68 }) do add_lever_pair(motors, levers, s, 1.25 * math.pi) end

    -- {{{ the coruscating vortex: three strands at different radii and pace
    local strand_plan = { { radius = 0.80, phase = 0.0, turns = 7 }, { radius = 0.64, phase = 2.1, turns = 9 },
                          { radius = 0.50, phase = 4.2, turns = 11 } }
    for index, plan in ipairs(strand_plan) do
        tube(strands[index], function(t)
            local s = 0.04 + 0.95 * t
            local phi = plan.phase + plan.turns * 2 * math.pi * t
            return add(middle(s), scale(across(s, phi), plan.radius * radius_at(s)))
        end, 0.011 * PIPE_RADIUS, 1000, 8)
    end
    -- }}}

    -- the output aperture: a gold ring where the concentrator ends
    tube(aperture, function(t)
        return add(middle(1), scale(across(1, 2 * math.pi * t), radius_at(1) * 1.05))
    end, 0.07 * PIPE_RADIUS, 64, 12)
    local store_centre, store_radius = add_store(store, slit)

    -- {{{ stations: composed like interior photographs
    -- a wide lens, the eye a little below the middle of the hall, and the
    -- look point at the same height when looking along it, so verticals
    -- stand straight; a few look up, across or back, to show every part.
    -- Every eye stands well off the middle line: the beams glow there, and a
    -- camera beside a beam sees a wedge of colour, not a hall (the first
    -- magazine set, pictures 112-125, did that)
    local WIDE = 75
    local function station(name, eye, look, fov) return { name = name, eye = eye, look = look, fov = fov or WIDE } end
    local f1 = forward(1)
    shape.stations = {
        station("the-hall-from-the-back", at(0.10, -0.3, -0.45), at(0.24, -0.3, -0.45)),
        station("back-mirror-and-emitters", at(0.17, -0.35, -0.5), at(0.0, 0.15, 0.1)),
        station("emitters-close", at(0.10, 0.3, -0.45), at(0.05, 0.6, 0.0), 65),
        station("first-tab", at(0.13, -0.35, 0.5), at(0.21, -0.35, 0)),
        station("ceiling-facets", at(0.33, -0.5, -0.3), at(0.355, 0.9, 0), 80),
        station("recycling-wall", at(0.37, -0.35, -0.6), at(0.40, -0.1, 0.9), 70),
        station("tab-gallery", at(0.42, -0.3, -0.45), at(0.58, -0.3, -0.2)),
        station("levers", at(0.47, -0.45, -0.25), at(0.505, -0.8, -0.45), 70),
        station("vortex-strands", at(0.53, 0.45, 0.4), at(0.60, 0.45, -0.35)),
        station("looking-back-to-the-mirror", at(0.64, -0.3, 0.45), at(0.44, -0.3, 0.45)),
        station("last-tab", at(0.66, -0.3, 0.5), at(0.76, -0.3, 0)),
        station("into-the-concentrator", at(0.79, -0.35, -0.45), at(1.0, 0, 0)),
        station("the-output-aperture", at(0.93, -0.5, 0.35), add(store_centre, scale(f1, store_radius)), 60),
        station("from-the-store", add(store_centre, scale(UP, 0.35 * PIPE_RADIUS)), at(0.86, 0, 0)),
        -- inside the drum, by the entrance, facing the slit the light leaves by
        station("the-store-slit", add(store_centre, add(scale(f1, -0.45 * store_radius), scale(UP, -0.25 * PIPE_RADIUS))),
            add(store_centre, scale(f1, store_radius)), 70),
    }
    -- }}}

    -- the index-matched liquid, as a pale haze thickening with distance
    shape.filling = { colour = { 0.52, 0.74, 0.82 }, density = 0.03 }
    return record.finish(shape)
end
-- }}}

return M

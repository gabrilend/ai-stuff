-- 002-the-test-shapes.lua - shapes made by formula, never drawn by hand.
--
-- In plain terms: tests and demos need models to read and look at, and a
-- model made by a few lines of arithmetic can be remade, resized and checked
-- exactly, where a file someone drew cannot. Two shapes live here: a unit
-- cube (the smallest thing with an inside and an outside), and a rough
-- sketch of the crown from docs/core-terms.md.
--
-- The crown's sizes are PLACEHOLDERS for phase 5 (the band), not design: a
-- head about 200 mm front to back and 160 mm side to side, the band 12 mm
-- tall, the panel about 50 mm in front of the brow. Units are millimetres.
-- Axes: y is up, +x points forward out of the wearer's face, +z to their
-- left. The band sits at y = 0; the eyes are about 60 mm below it.
--
-- Every face is wound so its normal points outward. Rather than get each
-- corner order right by hand, every quad is given a point known to be
-- inside the solid and turns itself to face away from it.

local record = require("001-the-shape-record")

local M = {}

-- {{{ local function add_outward_triangle()
-- Adds triangle a, b, c (each {x,y,z}), swapped if needed so its normal
-- points away from `inside` ({x,y,z}).
local function add_outward_triangle(part, a, b, c, inside)
    local ux, uy, uz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
    local vx, vy, vz = c[1] - a[1], c[2] - a[2], c[3] - a[3]
    local nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
    local cx = (a[1] + b[1] + c[1]) / 3 - inside[1]
    local cy = (a[2] + b[2] + c[2]) / 3 - inside[2]
    local cz = (a[3] + b[3] + c[3]) / 3 - inside[3]
    -- facing inward: swap two corners, which reverses the facing
    if nx * cx + ny * cy + nz * cz < 0 then b, c = c, b end
    record.add_triangle(part, a[1], a[2], a[3], b[1], b[2], b[3], c[1], c[2], c[3])
end
-- }}}

-- {{{ local function add_quad()
-- Four corners in order around the edge, as two triangles facing away from
-- `inside`.
local function add_quad(part, a, b, c, d, inside)
    add_outward_triangle(part, a, b, c, inside)
    add_outward_triangle(part, a, c, d, inside)
end
-- }}}

-- {{{ local function add_box()
-- An axis-aligned box between two opposite corners.
local function add_box(part, x0, y0, z0, x1, y1, z1)
    local inside = { (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2 }
    local function corner(i, j, k)
        return { i == 0 and x0 or x1, j == 0 and y0 or y1, k == 0 and z0 or z1 }
    end
    -- one face per axis and side: the axis is held at 0 or 1 while the other
    -- two walk around a square
    local square = { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 0, 1 } }
    for axis = 1, 3 do
        for side = 0, 1 do
            local face = {}
            for index, step in ipairs(square) do
                local ijk = { 0, 0, 0 }
                ijk[axis] = side
                ijk[axis % 3 + 1] = step[1]
                ijk[(axis + 1) % 3 + 1] = step[2]
                face[index] = corner(ijk[1], ijk[2], ijk[3])
            end
            add_quad(part, face[1], face[2], face[3], face[4], inside)
        end
    end
end
-- }}}

-- {{{ local function add_band_arc()
-- A stretch of the band: a hollow oval ring section running from angle a0 to
-- a1 (radians, 0 = straight forward, counting toward the wearer's left),
-- between `inner` and `outer` offsets from the head's oval (radii rx front-
-- to-back, rz side-to-side), from height y0 to y1. Closed at both ends.
local function add_band_arc(part, rx, rz, inner, outer, y0, y1, a0, a1, segments)
    local function at(angle, offset, y)
        return { (rx + offset) * math.cos(angle), y, (rz + offset) * math.sin(angle) }
    end
    local middle_offset, middle_y = (inner + outer) / 2, (y0 + y1) / 2
    for step = 0, segments - 1 do
        local s0 = a0 + (a1 - a0) * step / segments
        local s1 = a0 + (a1 - a0) * (step + 1) / segments
        local inside = at((s0 + s1) / 2, middle_offset, middle_y)
        add_quad(part, at(s0, outer, y0), at(s1, outer, y0), at(s1, outer, y1), at(s0, outer, y1), inside)
        add_quad(part, at(s0, inner, y0), at(s1, inner, y0), at(s1, inner, y1), at(s0, inner, y1), inside)
        add_quad(part, at(s0, inner, y1), at(s1, inner, y1), at(s1, outer, y1), at(s0, outer, y1), inside)
        add_quad(part, at(s0, inner, y0), at(s1, inner, y0), at(s1, outer, y0), at(s0, outer, y0), inside)
    end
    -- the two ends: a full ring has none, an arc must be closed to be solid
    if math.abs(a1 - a0) < 2 * math.pi - 1e-9 then
        for _, angle in ipairs({ a0, a1 }) do
            local step_inward = (angle == a0) and 1e-3 or -1e-3
            local inside = at(angle + step_inward * (a1 > a0 and 1 or -1), middle_offset, middle_y)
            add_quad(part, at(angle, inner, y0), at(angle, outer, y0), at(angle, outer, y1), at(angle, inner, y1), inside)
        end
    end
end
-- }}}

-- {{{ local function add_disc()
-- A short cylinder (a dial) whose axis points along `direction` ({x,y,z},
-- unit length, horizontal), centred at `centre`.
local function add_disc(part, centre, direction, radius, thickness, segments)
    -- two directions across the axis: straight up, and up × axis
    local up = { 0, 1, 0 }
    local across = { up[2] * direction[3] - up[3] * direction[2],
                     up[3] * direction[1] - up[1] * direction[3],
                     up[1] * direction[2] - up[2] * direction[1] }
    local function rim(angle, side)
        local c, s, h = math.cos(angle) * radius, math.sin(angle) * radius, side * thickness / 2
        return { centre[1] + up[1] * c + across[1] * s + direction[1] * h,
                 centre[2] + up[2] * c + across[2] * s + direction[2] * h,
                 centre[3] + up[3] * c + across[3] * s + direction[3] * h }
    end
    for step = 0, segments - 1 do
        local s0, s1 = 2 * math.pi * step / segments, 2 * math.pi * (step + 1) / segments
        add_quad(part, rim(s0, -1), rim(s1, -1), rim(s1, 1), rim(s0, 1), centre)
        for _, side in ipairs({ -1, 1 }) do
            local cap = { centre[1] + direction[1] * side * thickness / 2,
                          centre[2] + direction[2] * side * thickness / 2,
                          centre[3] + direction[3] * side * thickness / 2 }
            add_outward_triangle(part, cap, rim(s0, side), rim(s1, side), centre)
        end
    end
end
-- }}}

-- {{{ local function add_curved_panel()
-- The panel: a thin slice of a cylinder standing upright, curving around a
-- vertical line at `axis_x` (behind it, near the eyes), `radius` away,
-- spanning `half_angle` radians either side of straight ahead. Given a
-- thickness so it is a solid like everything else.
local function add_curved_panel(part, axis_x, radius, half_angle, y0, y1, thickness, segments)
    local first = #part.positions + 1
    -- a band arc with no head inside it (both radii zero) is a plain
    -- circular arc of the given radius around the origin
    add_band_arc(part, 0, 0, radius, radius + thickness, y0, y1, -half_angle, half_angle, segments)
    -- move only the corners just added forward to the panel's own axis
    local p = part.positions
    for index = first, #p, 3 do p[index] = p[index] + axis_x end
end
-- }}}

-- {{{ function M.cube()
-- The unit cube, corners 0..1 on every axis: 12 triangles.
function M.cube()
    local shape = record.new("cube", "made", "y")
    add_box(record.add_part(shape, "cube", { 0.85, 0.55, 0.25 }), 0, 0, 0, 1, 1, 1)
    return record.finish(shape)
end
-- }}}

-- {{{ function M.crown()
-- A rough crown: the band, two emitters at the back by the temples, a light
-- pipe running forward along each side, three dials per side, the panel arm
-- at the front reaching down and out, and the curved panel at its end.
function M.crown()
    local shape = record.new("crown-sketch", "made", "y")
    local rx, rz = 100, 80
    local band = record.add_part(shape, "band", { 0.30, 0.20, 0.13 })
    add_band_arc(band, rx, rz, 0, 4, 0, 12, 0, 2 * math.pi, 96)

    -- emitters: blocks on the outside of the band, behind each temple
    local emitters = record.add_part(shape, "emitters", { 0.80, 0.18, 0.15 })
    for _, side in ipairs({ 1, -1 }) do
        add_band_arc(emitters, rx, rz, 4, 12, 1, 11, side * 2.3, side * 2.7, 6)
    end

    -- light pipes: from each emitter forward along the band to the brow
    local pipes = record.add_part(shape, "light pipes", { 0.45, 0.85, 0.80 })
    for _, side in ipairs({ 1, -1 }) do
        add_band_arc(pipes, rx, rz, 4, 8, 3, 9, side * 2.3, side * 0.12, 40)
    end

    -- dials: forward, back, and by the ear, on each side
    local dials = record.add_part(shape, "dials", { 0.12, 0.12, 0.14 })
    for _, side in ipairs({ 1, -1 }) do
        for _, angle in ipairs({ 1.1, 1.9, 1.5 }) do
            local a = side * angle
            local x, z = (rx + 4) * math.cos(a), (rz + 4) * math.sin(a)
            local length = math.sqrt(x * x + z * z)
            local y = (angle == 1.5) and -10 or 6
            add_disc(dials, { x, y, z }, { x / length, 0, z / length }, 6, 4, 20)
        end
    end

    -- the panel arm: a stalk down from the brow, then a reach forward
    local arm = record.add_part(shape, "panel arm", { 0.62, 0.64, 0.68 })
    add_box(arm, rx + 4, -64, -3, rx + 10, 0, 3)
    add_box(arm, rx + 4, -64, -3, rx + 52, -58, 3)

    -- the panel: curved around a line near the eyes, facing the wearer
    local panel = record.add_part(shape, "panel", { 0.92, 0.93, 0.88 })
    add_curved_panel(panel, 60, 92, 0.32, -78, -44, 1.5, 24)

    return record.finish(shape)
end
-- }}}

-- Each test shape by name, so a script can ask for one by a word.
M.BY_NAME = { cube = M.cube, crown = M.crown }

return M

-- 015-building-the-solids.lua - solved parts into triangles.
--
-- In plain terms: each part the solver (014) measured and placed becomes a
-- solid of its kind -- a box, a cylinder, a cone, a sphere or a ring --
-- made of triangles in a shape record (001), which the viewer and every
-- file writer already understand.
--
-- Each solid is first made standing upright around the origin, in its own
-- frame: across on x, along on y (its axis), deep on z. Then it is turned
-- so its axis runs where the solver said, and moved to its middle. The
-- turns are true rotations (never mirrors), so faces made facing outward
-- stay facing outward:
--   axis y:  as made
--   axis x:  (x, y, z) -> (y, -x, z)     a quarter turn about z
--   axis z:  (x, y, z) -> (x, -z, y)     a quarter turn about x
-- Every face is made facing away from a point known to be inside the solid
-- (the helpers lent by 002), so no corner order is worked out by hand.

local record = require("001-the-shape-record")
local kit = require("002-the-test-shapes").kit
local words = require("012-the-shape-words")

local M = {}

local SEGMENTS = 48       -- around a round solid
local SPHERE_BANDS = 16   -- from pole to pole
local RING_TUBE = 16      -- around a ring's tube

-- {{{ TURNS
-- A point in the solid's own frame to the world's directions, by axis.
local TURNS = {
    y = function(x, y, z) return x, y, z end,
    x = function(x, y, z) return y, -x, z end,
    z = function(x, y, z) return x, -z, y end,
}
-- }}}

-- {{{ SOLIDS
-- Each solid kind to a function adding its triangles to `part`, in its own
-- frame, for extents a (across), h (along), d (deep). All are centred on
-- the origin, which lies inside every one but the ring.
local SOLIDS = {
    box = function(part, a, h, d)
        kit.box(part, -a / 2, -h / 2, -d / 2, a / 2, h / 2, d / 2)
    end,
    cylinder = function(part, a, h, d)
        local inside = { 0, 0, 0 }
        local function rim(t, y) return { a / 2 * math.cos(t), y, d / 2 * math.sin(t) } end
        for k = 0, SEGMENTS - 1 do
            local t0, t1 = 2 * math.pi * k / SEGMENTS, 2 * math.pi * (k + 1) / SEGMENTS
            kit.quad(part, rim(t0, -h / 2), rim(t1, -h / 2), rim(t1, h / 2), rim(t0, h / 2), inside)
            kit.outward_triangle(part, { 0, h / 2, 0 }, rim(t0, h / 2), rim(t1, h / 2), inside)
            kit.outward_triangle(part, { 0, -h / 2, 0 }, rim(t0, -h / 2), rim(t1, -h / 2), inside)
        end
    end,
    cone = function(part, a, h, d)
        -- the point at the far end of the axis; the middle of the axis is
        -- inside (the cone is a quarter of its width across there)
        local inside, apex = { 0, 0, 0 }, { 0, h / 2, 0 }
        local function rim(t) return { a / 2 * math.cos(t), -h / 2, d / 2 * math.sin(t) } end
        for k = 0, SEGMENTS - 1 do
            local t0, t1 = 2 * math.pi * k / SEGMENTS, 2 * math.pi * (k + 1) / SEGMENTS
            kit.outward_triangle(part, apex, rim(t0), rim(t1), inside)
            kit.outward_triangle(part, { 0, -h / 2, 0 }, rim(t0), rim(t1), inside)
        end
    end,
    sphere = function(part, a, h, d)
        local inside = { 0, 0, 0 }
        local function at(band, k)
            local lat = -math.pi / 2 + math.pi * band / SPHERE_BANDS
            local lon = 2 * math.pi * k / SEGMENTS
            return { a / 2 * math.cos(lat) * math.cos(lon), h / 2 * math.sin(lat), d / 2 * math.cos(lat) * math.sin(lon) }
        end
        for band = 0, SPHERE_BANDS - 1 do
            for k = 0, SEGMENTS - 1 do
                local p00, p01, p11, p10 = at(band, k), at(band, k + 1), at(band + 1, k + 1), at(band + 1, k)
                -- the bands touching a pole are triangles: their pole edge
                -- has no length, and a square there would be a sliver
                if band == 0 then
                    kit.outward_triangle(part, p00, p11, p10, inside)
                elseif band == SPHERE_BANDS - 1 then
                    kit.outward_triangle(part, p00, p01, p10, inside)
                else
                    kit.quad(part, p00, p01, p11, p10, inside)
                end
            end
        end
    end,
    ring = function(part, a, h, d)
        -- a tube of diameter h bent round a circle, outside width a: the
        -- tube's middle runs at (a - h) / 2 from the axis
        local rx, rz, r = (a - h) / 2, (d - h) / 2, h / 2
        local function at(k, j)
            local u, v = 2 * math.pi * k / SEGMENTS, 2 * math.pi * j / RING_TUBE
            return { (rx + r * math.cos(v)) * math.cos(u), r * math.sin(v), (rz + r * math.cos(v)) * math.sin(u) }
        end
        for k = 0, SEGMENTS - 1 do
            -- inside the tube: its middle line, at this slice's angle
            local u = 2 * math.pi * (k + 0.5) / SEGMENTS
            local inside = { rx * math.cos(u), 0, rz * math.sin(u) }
            for j = 0, RING_TUBE - 1 do
                kit.quad(part, at(k, j), at(k + 1, j), at(k + 1, j + 1), at(k, j + 1), inside)
            end
        end
    end,
}
-- }}}

-- {{{ function M.build()
-- solved: the solver's result. name: the model's name. Returns a finished
-- shape record (y up), units recorded as words.
function M.build(solved, name)
    local shape = record.new(name, "words", "y")
    shape.units = "units (1 = a default part's width)"
    for _, solved_part in ipairs(solved.parts) do
        local part = record.add_part(shape, solved_part.name, solved_part.colour)
        local e = solved_part.extents
        SOLIDS[words.KINDS[solved_part.kind].solid](part, e.across, e.along, e.deep)
        -- turn to the part's axis, then move to its middle
        local turn, c, p = TURNS[solved_part.axis], solved_part.centre, part.positions
        for k = 1, #p, 3 do
            local x, y, z = turn(p[k], p[k + 1], p[k + 2])
            p[k], p[k + 1], p[k + 2] = x + c[1], y + c[2], z + c[3]
        end
    end
    return record.finish(shape)
end
-- }}}

return M

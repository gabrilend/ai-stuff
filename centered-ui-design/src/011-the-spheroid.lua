-- 011-the-spheroid.lua - the one shape every unit is made of.
--
-- In plain terms: a unit is an oblong spheroid — a ball stretched longer
-- along the way it faces. Only one ball is ever built: a sphere of radius 1
-- made of rings of latitude and longitude. Each unit draws that same ball,
-- stretched by its own sizes and turned to its own heading, on the graphics
-- card. Because a stretched sphere is described by one formula, its shading
-- (which way each bit of surface faces) comes from the same formula: no
-- model files, nothing hand-placed.
--
-- Vertex: x, y, z (a point on the unit sphere: x = sideways, y = up,
-- z = forward), u, v (texture coordinates: u around the long axis, v from
-- the back tip to the front tip). The long axis is z, so the texture's
-- bands wrap around the unit's body like hoops.

local M = {}

-- {{{ function M.build()
-- Returns `vertices` (list of {x, y, z, u, v}) and `triangles` (list of
-- 1-based vertex indices, three per triangle) for a sphere with `rings`
-- steps from tip to tip and `segments` steps around.
function M.build(rings, segments)
    local vertices = {}
    local triangles = {}
    for ring = 0, rings do
        local v = ring / rings
        -- from the back tip (z = -1) to the front tip (z = 1)
        local polar = math.pi * (1 - v)
        local z = math.cos(polar)
        local around_radius = math.sin(polar)
        for segment = 0, segments do
            local u = segment / segments
            local turn = u * math.pi * 2
            vertices[#vertices + 1] = {
                around_radius * math.cos(turn),
                around_radius * math.sin(turn),
                z,
                u, v,
            }
        end
    end
    -- two triangles per quad of the grid; the seam column is duplicated so
    -- the texture's u can run 0..1 without wrapping back mid-triangle
    local row = segments + 1
    for ring = 0, rings - 1 do
        for segment = 0, segments - 1 do
            local a = ring * row + segment + 1
            local b = a + 1
            local c = a + row
            local d = c + 1
            triangles[#triangles + 1] = a
            triangles[#triangles + 1] = c
            triangles[#triangles + 1] = b
            triangles[#triangles + 1] = b
            triangles[#triangles + 1] = c
            triangles[#triangles + 1] = d
        end
    end
    return vertices, triangles
end
-- }}}

return M

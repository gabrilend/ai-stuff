-- meshes.lua - the shapes the gallery can place in a scene.
--
-- What this is, generally: a cabinet of solid shapes, each built from
-- triangles, each triangle facing outward. A scene names a shape by word
-- ("cube", "torus", "star_prism") and this file builds it once; the
-- choreographer moves copies of it around, and the rasteriser draws them.
--
-- Data format, worth knowing whenever a new shape is added:
--   mesh = {
--     verts = { {x, y, z}, ... }      -- numbers, around the origin, size ~1
--     faces = { {a, b, c}, ... }      -- 1-based vertex indices, integers;
--                                        counter-clockwise seen from outside,
--                                        so cross(b-a, c-a) points outward
--     superball = true | nil          -- a sphere whose vertices may be
--                                        re-pushed at render time toward a
--                                        cube or octahedron (see reshape())
--   }
-- Winding is repaired at build time against a "which way is out" rule each
-- generator supplies, then checked; a shape that still faces inward anywhere
-- is an error, because the rasteriser's lighting trusts the normals.

local meshes = {}

-- {{{ local function sub()
local function sub(a, b) return { a[1] - b[1], a[2] - b[2], a[3] - b[3] } end
-- }}}

-- {{{ local function cross()
local function cross(a, b)
    return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end
-- }}}

-- {{{ local function dot()
local function dot(a, b) return a[1] * b[1] + a[2] * b[2] + a[3] * b[3] end
-- }}}

-- {{{ local function face_centre()
local function face_centre(mesh, face)
    local a, b, c = mesh.verts[face[1]], mesh.verts[face[2]], mesh.verts[face[3]]
    return { (a[1] + b[1] + c[1]) / 3, (a[2] + b[2] + c[2]) / 3, (a[3] + b[3] + c[3]) / 3 }
end
-- }}}

-- {{{ local function orient_faces()
-- Makes every face's normal agree with `outward(centre)`, a function giving
-- a direction that points out of the solid at a face's centre. For a convex
-- shape that is simply the centre itself (the origin is inside); a torus
-- supplies "away from the tube's core". Flips any face that disagrees, then
-- refuses a face that is degenerate (no area, so no direction at all).
local function orient_faces(mesh, outward, name)
    for index, face in ipairs(mesh.faces) do
        local a, b, c = mesh.verts[face[1]], mesh.verts[face[2]], mesh.verts[face[3]]
        local normal = cross(sub(b, a), sub(c, a))
        local out = outward(face_centre(mesh, face))
        local agreement = dot(normal, out)
        if agreement == 0 then
            error("meshes: " .. name .. " face " .. index .. " has no outward direction")
        end
        -- Two paths: already outward -> leave it; inward -> swap two corners.
        if agreement < 0 then face[2], face[3] = face[3], face[2] end
    end
    return mesh
end
-- }}}

-- {{{ local function convex()
-- The outward rule for any shape built around the origin with no dents.
local function convex(centre) return centre end
-- }}}

-- The cabinet. Each entry builds one shape from its (optional) parameters.
local generators = {
    -- {{{ cube
    cube = function()
        local s = 0.8
        local verts = {}
        for x = -1, 1, 2 do for y = -1, 1, 2 do for z = -1, 1, 2 do
            verts[#verts + 1] = { x * s, y * s, z * s }
        end end end
        -- vertex index = 1 + 4*(x>0) + 2*(y>0) + (z>0)
        local quads = { { 1, 2, 4, 3 }, { 5, 7, 8, 6 }, { 1, 5, 6, 2 },
                        { 3, 4, 8, 7 }, { 1, 3, 7, 5 }, { 2, 6, 8, 4 } }
        local faces = {}
        for _, q in ipairs(quads) do
            faces[#faces + 1] = { q[1], q[2], q[3] }
            faces[#faces + 1] = { q[1], q[3], q[4] }
        end
        return orient_faces({ verts = verts, faces = faces }, convex, "cube")
    end,
    -- }}}
    -- {{{ tetrahedron
    tetrahedron = function()
        local s = 0.75
        local verts = { { s, s, s }, { s, -s, -s }, { -s, s, -s }, { -s, -s, s } }
        local faces = { { 1, 2, 3 }, { 1, 3, 4 }, { 1, 4, 2 }, { 2, 4, 3 } }
        return orient_faces({ verts = verts, faces = faces }, convex, "tetrahedron")
    end,
    -- }}}
    -- {{{ octahedron
    octahedron = function()
        local verts = { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } }
        local faces = {}
        for _, x in ipairs({ 1, 2 }) do for _, y in ipairs({ 3, 4 }) do for _, z in ipairs({ 5, 6 }) do
            faces[#faces + 1] = { x, y, z }
        end end end
        return orient_faces({ verts = verts, faces = faces }, convex, "octahedron")
    end,
    -- }}}
    -- {{{ icosahedron
    icosahedron = function()
        local t = (1 + math.sqrt(5)) / 2
        local k = 1 / math.sqrt(1 + t * t)
        local verts = {
            { -1, t, 0 }, { 1, t, 0 }, { -1, -t, 0 }, { 1, -t, 0 },
            { 0, -1, t }, { 0, 1, t }, { 0, -1, -t }, { 0, 1, -t },
            { t, 0, -1 }, { t, 0, 1 }, { -t, 0, -1 }, { -t, 0, 1 },
        }
        for _, v in ipairs(verts) do v[1], v[2], v[3] = v[1] * k, v[2] * k, v[3] * k end
        local faces = {
            { 1, 12, 6 }, { 1, 6, 2 }, { 1, 2, 8 }, { 1, 8, 11 }, { 1, 11, 12 },
            { 2, 6, 10 }, { 6, 12, 5 }, { 12, 11, 3 }, { 11, 8, 7 }, { 8, 2, 9 },
            { 4, 10, 5 }, { 4, 5, 3 }, { 4, 3, 7 }, { 4, 7, 9 }, { 4, 9, 10 },
            { 5, 10, 6 }, { 3, 5, 12 }, { 7, 3, 11 }, { 9, 7, 8 }, { 10, 9, 2 },
        }
        return orient_faces({ verts = verts, faces = faces }, convex, "icosahedron")
    end,
    -- }}}
    -- {{{ torus
    -- A ring: `major` is the ring's radius, `minor` the tube's. The outward
    -- rule is "away from the nearest point on the ring's centre line".
    torus = function(params)
        local major, minor = params.major or 0.75, params.minor or 0.28
        local rings, sides = params.rings or 24, params.sides or 12
        local verts, faces = {}, {}
        for i = 0, rings - 1 do
            local u = 2 * math.pi * i / rings
            for j = 0, sides - 1 do
                local v = 2 * math.pi * j / sides
                local r = major + minor * math.cos(v)
                verts[#verts + 1] = { r * math.cos(u), minor * math.sin(v), r * math.sin(u) }
            end
        end
        -- {{{ local function at()
        local function at(i, j) return 1 + (i % rings) * sides + (j % sides) end
        -- }}}
        for i = 0, rings - 1 do for j = 0, sides - 1 do
            faces[#faces + 1] = { at(i, j), at(i + 1, j), at(i + 1, j + 1) }
            faces[#faces + 1] = { at(i, j), at(i + 1, j + 1), at(i, j + 1) }
        end end
        -- {{{ local function away_from_core()
        local function away_from_core(p)
            local len = math.sqrt(p[1] * p[1] + p[3] * p[3])
            return { p[1] - p[1] / len * major, p[2], p[3] - p[3] / len * major }
        end
        -- }}}
        return orient_faces({ verts = verts, faces = faces }, away_from_core, "torus")
    end,
    -- }}}
    -- {{{ star_prism
    -- A flat five-pointed (or `points`-pointed) star with thickness: the
    -- yellow star of the house look, made solid. Outward is "away from the
    -- prism's middle plane" for the caps and "away from the axis" for sides.
    star_prism = function(params)
        local points = params.points or 5
        local outer, inner, depth = params.outer or 1.0, params.inner or 0.45, params.depth or 0.3
        local verts, faces = { { 0, 0, depth / 2 }, { 0, 0, -depth / 2 } }, {}
        local rim = points * 2
        for i = 0, rim - 1 do
            local angle = math.pi / 2 + math.pi * i / points
            local r = (i % 2 == 0) and outer or inner
            verts[#verts + 1] = { r * math.cos(angle), r * math.sin(angle), depth / 2 }
            verts[#verts + 1] = { r * math.cos(angle), r * math.sin(angle), -depth / 2 }
        end
        -- {{{ local function front()
        local function front(i) return 3 + 2 * (i % rim) end
        -- }}}
        -- {{{ local function back()
        local function back(i) return 4 + 2 * (i % rim) end
        -- }}}
        local side_of = {}
        for i = 0, rim - 1 do
            faces[#faces + 1] = { 1, front(i), front(i + 1) }
            faces[#faces + 1] = { 2, back(i + 1), back(i) }
            faces[#faces + 1] = { front(i), back(i), back(i + 1) }
            side_of[#faces] = true
            faces[#faces + 1] = { front(i), back(i + 1), front(i + 1) }
            side_of[#faces] = true
        end
        local mesh = { verts = verts, faces = faces }
        -- The star is not convex, so each face gets the rule for its kind:
        -- caps point along the axis; sides point along the rim edge's own
        -- outward normal in the plane (perpendicular to the edge, away from
        -- the axis side of it).
        for index, face in ipairs(faces) do
            local a, b, c = verts[face[1]], verts[face[2]], verts[face[3]]
            local normal = cross(sub(b, a), sub(c, a))
            local out
            if side_of[index] then
                -- rim edge in the plane: the two distinct xy points of the quad
                local p, q = verts[face[1]], nil
                for k = 2, 3 do
                    local v = verts[face[k]]
                    if math.abs(v[1] - p[1]) + math.abs(v[2] - p[2]) > 1e-9 then q = v end
                end
                local ex, ey = q[1] - p[1], q[2] - p[2]
                local nx, ny = ey, -ex
                -- choose the perpendicular that points away from the axis
                if nx * (p[1] + q[1]) + ny * (p[2] + q[2]) < 0 then nx, ny = -nx, -ny end
                out = { nx, ny, 0 }
            else
                out = { 0, 0, face_centre(mesh, face)[3] }
            end
            if dot(normal, out) < 0 then face[2], face[3] = face[3], face[2] end
        end
        return mesh
    end,
    -- }}}
    -- {{{ cone
    -- Point up (+y), round base down, closed underneath: a skirt, a hat's
    -- crown, a party hat, a seashell's whorl. Convex, so "out" is simply
    -- away from the middle.
    cone = function(params)
        local segments = params.segments or 24
        local radius, height = params.radius or 1, params.height or 1.6
        local verts = { { 0, height / 2, 0 }, { 0, -height / 2, 0 } }
        for i = 0, segments - 1 do
            local a = 2 * math.pi * i / segments
            verts[#verts + 1] = { radius * math.cos(a), -height / 2, radius * math.sin(a) }
        end
        local faces = {}
        for i = 0, segments - 1 do
            local here, next_one = 3 + i, 3 + (i + 1) % segments
            faces[#faces + 1] = { 1, here, next_one }
            faces[#faces + 1] = { 2, next_one, here }
        end
        return orient_faces({ verts = verts, faces = faces }, convex, "cone")
    end,
    -- }}}
    -- {{{ horn
    -- A unicorn's horn: a long taper along +x (so face_motion points it
    -- forward), its cross-section a rounded star of `ridges` lobes that turns
    -- `twist` times from base to tip, which is what draws the spiral grooves.
    -- Out is "away from the long axis" on the sides and "backward" on the
    -- base cap.
    horn = function(params)
        local ridges, twist = params.ridges or 3, params.twist or 2
        local length, radius = params.length or 2.2, params.radius or 0.32
        local rings, around = params.rings or 28, (params.ridges or 3) * 6
        local verts = { { -length / 2, 0, 0 }, { length / 2, 0, 0 } } -- base centre, tip
        for i = 0, rings - 1 do
            local s = i / rings
            local taper = radius * (1 - s)
            for j = 0, around - 1 do
                local theta = 2 * math.pi * j / around + twist * 2 * math.pi * s
                local r = taper * (1 + 0.22 * math.cos(ridges * (2 * math.pi * j / around)))
                verts[#verts + 1] = { -length / 2 + length * s, r * math.cos(theta), r * math.sin(theta) }
            end
        end
        -- {{{ local function at()
        local function at(i, j) return 3 + i * around + (j % around) end
        -- }}}
        local faces, is_base = {}, {}
        for j = 0, around - 1 do
            faces[#faces + 1] = { 1, at(0, j + 1), at(0, j) }
            is_base[#faces] = true
            faces[#faces + 1] = { 2, at(rings - 1, j), at(rings - 1, j + 1) }
        end
        for i = 0, rings - 2 do for j = 0, around - 1 do
            faces[#faces + 1] = { at(i, j), at(i + 1, j), at(i + 1, j + 1) }
            faces[#faces + 1] = { at(i, j), at(i + 1, j + 1), at(i, j + 1) }
        end end
        local mesh = { verts = verts, faces = faces }
        for index, face in ipairs(faces) do
            local a, b, c = verts[face[1]], verts[face[2]], verts[face[3]]
            local normal = cross(sub(b, a), sub(c, a))
            local centre = face_centre(mesh, face)
            local out = is_base[index] and { -1, 0, 0 } or { 0, centre[2], centre[3] }
            -- the tip's last ring is so thin that its faces point mostly
            -- forward; "forward" is the honest outward there
            if face[1] == 2 then out = { 1, centre[2], centre[3] } end
            if dot(normal, out) < 0 then face[2], face[3] = face[3], face[2] end
        end
        return mesh
    end,
    -- }}}
    -- {{{ terrain
    -- A square of ground `size` wide, cut into a `grid` of squares, each
    -- corner lifted to meshes.terrain_height. An open sheet rather than a
    -- solid, so "out" is simply up: it is meant to be seen from above.
    -- Built in world units; place it at the origin with scale 1.
    terrain = function(params)
        local size, grid = params.size or 8, params.grid or 24
        local verts, faces = {}, {}
        for i = 0, grid do
            for j = 0, grid do
                local x, z = -size / 2 + size * i / grid, -size / 2 + size * j / grid
                verts[#verts + 1] = { x, meshes.terrain_height(params, x, z), z }
            end
        end
        -- {{{ local function at()
        local function at(i, j) return 1 + i * (grid + 1) + j end
        -- }}}
        for i = 0, grid - 1 do for j = 0, grid - 1 do
            faces[#faces + 1] = { at(i, j), at(i + 1, j), at(i + 1, j + 1) }
            faces[#faces + 1] = { at(i, j), at(i + 1, j + 1), at(i, j + 1) }
        end end
        -- {{{ local function up()
        local function up() return { 0, 1, 0 } end
        -- }}}
        local sheet = orient_faces({ verts = verts, faces = faces }, up, "terrain")
        -- open: the painter cuts it face by face at the lens rather than
        -- dropping it whole, because the ground always runs under the camera
        sheet.open_sheet = true
        return sheet
    end,
    -- }}}
    -- {{{ superball
    -- A sphere fine enough to be pushed into a cube or an octahedron at
    -- render time; see meshes.reshape(). Built as a cube whose six faces are
    -- each an n-by-n grid, then pushed out onto the sphere -- not as a
    -- latitude/longitude sphere, whose crowded poles made the cube end of
    -- the morph lumpy. This way the cube end is a true cube: each face's
    -- grid lies flat again, and its edges stop glowing.
    superball = function(params)
        local n = params.grid or 8
        local verts, faces, index_of = {}, {}, {}
        -- {{{ local function vertex()
        local function vertex(x, y, z)
            local key = string.format("%.6f,%.6f,%.6f", x, y, z)
            if not index_of[key] then
                local len = math.sqrt(x * x + y * y + z * z)
                verts[#verts + 1] = { x / len, y / len, z / len }
                index_of[key] = #verts
            end
            return index_of[key]
        end
        -- }}}
        -- each cube face: which axis it sits on, which side, and the two
        -- axes its grid runs along
        local sides = { { 1, 2, 3 }, { 2, 3, 1 }, { 3, 1, 2 } }
        for _, axes in ipairs(sides) do
            for _, sign in ipairs({ -1, 1 }) do
                for i = 0, n - 1 do for j = 0, n - 1 do
                    local corner = {}
                    for k, d in ipairs({ { 0, 0 }, { 1, 0 }, { 1, 1 }, { 0, 1 } }) do
                        local p = {}
                        p[axes[1]] = sign
                        p[axes[2]] = -1 + 2 * (i + d[1]) / n
                        p[axes[3]] = -1 + 2 * (j + d[2]) / n
                        corner[k] = vertex(p[1], p[2], p[3])
                    end
                    faces[#faces + 1] = { corner[1], corner[2], corner[3] }
                    faces[#faces + 1] = { corner[1], corner[3], corner[4] }
                end end
            end
        end
        local mesh = { verts = verts, faces = faces, superball = true }
        return orient_faces(mesh, convex, "superball")
    end,
    -- }}}
}

-- {{{ function meshes.radius_toward()
-- How far out from the middle a solid with no dents reaches in direction v
-- (a unit vector), scaled so its farthest corner is at 1 -- so every solid
-- is measured at the same size. For each face, the distance along v to that
-- face's plane is (face distance) / (face normal . v); the surface is the
-- nearest such plane. Face planes are worked out once and kept on the mesh.
-- Morphing between two solids is then just blending the two reaches.
function meshes.radius_toward(mesh, v)
    if not mesh.planes then
        local planes, far = {}, 0
        for _, face in ipairs(mesh.faces) do
            local a, b, c = mesh.verts[face[1]], mesh.verts[face[2]], mesh.verts[face[3]]
            local n = cross(sub(b, a), sub(c, a))
            local len = math.sqrt(dot(n, n))
            n = { n[1] / len, n[2] / len, n[3] / len }
            planes[#planes + 1] = { n, dot(n, a) }
        end
        for _, p in ipairs(mesh.verts) do far = math.max(far, math.sqrt(dot(p, p))) end
        mesh.planes, mesh.circumradius = planes, far
    end
    local nearest = math.huge
    for _, plane in ipairs(mesh.planes) do
        local facing = dot(plane[1], v)
        if facing > 1e-9 then nearest = math.min(nearest, plane[2] / facing) end
    end
    return nearest / mesh.circumradius
end
-- }}}

-- {{{ function meshes.terrain_height()
-- The height of the ground at (x, z), from the same numbers the terrain mesh
-- is built from -- so a ball told to roll on the ground rests exactly on the
-- surface that is drawn. `params`:
--   hills = { { x, z, height, radius }, ... }  -- smooth bell-shaped mounds
--   waves = { { amp, fx, fz, phase }, ... }    -- gentle rolling ripples
--   base  = number                            -- the ground's resting level
function meshes.terrain_height(params, x, z)
    local h = params.base or 0
    for _, hill in ipairs(params.hills or {}) do
        local dx, dz = x - hill[1], z - hill[2]
        h = h + hill[3] * math.exp(-(dx * dx + dz * dz) / (hill[4] * hill[4]))
    end
    for _, w in ipairs(params.waves or {}) do
        h = h + w[1] * math.sin(w[2] * x + w[3] * z + (w[4] or 0))
    end
    return h
end
-- }}}

-- {{{ function meshes.names()
function meshes.names()
    local list = {}
    for name in pairs(generators) do list[#list + 1] = name end
    table.sort(list)
    return list
end
-- }}}

-- {{{ function meshes.build()
-- Builds the named shape. An unknown word is refused with the legal list.
function meshes.build(name, params)
    local generate = generators[name]
    if not generate then
        error("meshes: no shape named '" .. tostring(name) .. "' - legal shapes: "
              .. table.concat(meshes.names(), ", "), 0)
    end
    return generate(params or {})
end
-- }}}

-- {{{ function meshes.reshape()
-- Pushes a unit-sphere vertex onto the surface of a "p-ball": the set of
-- points whose p-norm is 1. p = 2 is the sphere itself; p near 1 is the
-- octahedron; large p is the cube. Animating p morphs one into the other
-- through the sphere, with every vertex keeping its identity -- which is why
-- the morph needs no correspondence table between the two solids.
-- The cube end is scaled by 0.8 so the three read as the same size.
function meshes.reshape(v, p)
    local norm = (math.abs(v[1]) ^ p + math.abs(v[2]) ^ p + math.abs(v[3]) ^ p) ^ (1 / p)
    local size = p > 2 and (1 - 0.2 * math.min(1, (p - 2) / 6)) or 1
    return v[1] / norm * size, v[2] / norm * size, v[3] / norm * size
end
-- }}}

return meshes

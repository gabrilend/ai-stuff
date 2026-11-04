-- 001-the-shape-record.lua - the one shape every CAD reader makes and every
-- viewer draws.
--
-- In plain terms: a 3D model, whatever file it came from, becomes a list of
-- named parts, each a pile of triangles with a colour. Readers fill it in;
-- the viewer only ever sees this. Keeping that seam here means a new file
-- format never touches drawing code, and a new way of drawing never touches
-- file formats.
--
-- Data layout (all numbers are plain Lua numbers):
--   shape = { name = string, source_format = "stl"|"obj"|"gltf"|"made",
--             up_axis = "y"|"z", parts = { part, ... },
--             bounds = { min = {x,y,z}, max = {x,y,z} },   -- set by finish()
--             triangle_count = whole, degenerate_count = whole }
--   part  = { name = string, colour = {r,g,b} (0..1),
--             positions = {x1,y1,z1, x2,y2,z2, x3,y3,z3, ...},
--             normals   = same length as positions, or empty until finish() }
-- Positions are flat (not a list of corner tables) because a model can hold
-- millions of corners, and one flat list is one allocation, read in order.
-- Three corners make a triangle; there are no shared corners or index lists
-- in this record, because the viewer hands the corners straight to the
-- graphics card in exactly this order.

local M = {}

local DEFAULT_COLOUR = { 0.72, 0.74, 0.78 }

-- {{{ function M.new()
-- A new empty shape. up_axis records the file's own convention so the viewer
-- can stand the model upright; nothing is rotated here.
function M.new(name, source_format, up_axis)
    return {
        name = name,
        source_format = source_format,
        up_axis = up_axis,
        parts = {},
        triangle_count = 0,
        degenerate_count = 0,
    }
end
-- }}}

-- {{{ function M.add_part()
-- Adds an empty part and returns it. colour may be nil when a format carries
-- none (STL); the part is then the plain light grey CAD programs use, and
-- that choice is visible to the reader of this line, not hidden in a viewer.
function M.add_part(shape, name, colour)
    local part = {
        name = name,
        colour = colour or { DEFAULT_COLOUR[1], DEFAULT_COLOUR[2], DEFAULT_COLOUR[3] },
        positions = {},
        normals = {},
    }
    shape.parts[#shape.parts + 1] = part
    return part
end
-- }}}

-- {{{ function M.add_triangle()
-- Appends one triangle's three corners. Normals are optional: given, they
-- are kept (smooth shading from glTF); absent, finish() computes flat ones.
function M.add_triangle(part, ax, ay, az, bx, by, bz, cx, cy, cz, normals)
    local p = part.positions
    local n = #p
    p[n + 1], p[n + 2], p[n + 3] = ax, ay, az
    p[n + 4], p[n + 5], p[n + 6] = bx, by, bz
    p[n + 7], p[n + 8], p[n + 9] = cx, cy, cz
    if normals ~= nil then
        local q = part.normals
        for index = 1, 9 do q[n + index] = normals[index] end
    end
end
-- }}}

-- {{{ local function flat_normals()
-- Computes one direction per triangle (the cross product of two edges) and
-- gives it to all three corners: flat facets, the way CAD models look.
-- Returns how many triangles had no direction (corners on one line).
local function flat_normals(part)
    local p, q = part.positions, {}
    local degenerate = 0
    for base = 0, #p - 9, 9 do
        local ux, uy, uz = p[base + 4] - p[base + 1], p[base + 5] - p[base + 2], p[base + 6] - p[base + 3]
        local vx, vy, vz = p[base + 7] - p[base + 1], p[base + 8] - p[base + 2], p[base + 9] - p[base + 3]
        local nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
        local length = math.sqrt(nx * nx + ny * ny + nz * nz)
        -- a sliver with no area: counted and given a zero direction, so it
        -- draws unlit rather than vanishing; the count goes on the viewer's
        -- panel, where a model full of slivers is noticed
        if length == 0 then
            degenerate = degenerate + 1
        else
            nx, ny, nz = nx / length, ny / length, nz / length
        end
        for corner = 0, 6, 3 do
            q[base + corner + 1], q[base + corner + 2], q[base + corner + 3] = nx, ny, nz
        end
    end
    part.normals = q
    return degenerate
end
-- }}}

-- {{{ function M.finish()
-- Computes missing normals, the bounds and the counts, then checks the whole
-- record. Every reader calls this last; after it the shape is ready to draw.
function M.finish(shape)
    local min = { math.huge, math.huge, math.huge }
    local max = { -math.huge, -math.huge, -math.huge }
    shape.triangle_count = 0
    shape.degenerate_count = 0
    for _, part in ipairs(shape.parts) do
        local p = part.positions
        -- normals: a reader supplied all of them, or none (then flat ones)
        if #part.normals == 0 then
            shape.degenerate_count = shape.degenerate_count + flat_normals(part)
        end
        for index = 1, #p, 3 do
            for axis = 1, 3 do
                local value = p[index + axis - 1]
                if value < min[axis] then min[axis] = value end
                if value > max[axis] then max[axis] = value end
            end
        end
        shape.triangle_count = shape.triangle_count + #p / 9
    end
    shape.bounds = { min = min, max = max }
    M.check(shape)
    return shape
end
-- }}}

-- {{{ function M.check()
-- Raises an error naming the first thing wrong. A shape with no triangles at
-- all is wrong: an empty file is reported, never drawn as an empty window.
function M.check(shape)
    local function fail(message) error("shape '" .. tostring(shape.name) .. "': " .. message, 0) end
    if type(shape.name) ~= "string" then fail("has no name") end
    if shape.up_axis ~= "y" and shape.up_axis ~= "z" then fail("up axis must be y or z") end
    if #shape.parts == 0 then fail("has no parts") end
    if shape.triangle_count == 0 then fail("has no triangles") end
    for _, part in ipairs(shape.parts) do
        if #part.positions % 9 ~= 0 then fail("part '" .. part.name .. "' has a triangle missing corners") end
        if #part.normals ~= #part.positions then
            fail("part '" .. part.name .. "' has " .. #part.normals .. " normal numbers for " .. #part.positions .. " position numbers")
        end
        for index = 1, #part.positions do
            local value = part.positions[index]
            -- a NaN is the only number not equal to itself
            if value ~= value or value == math.huge or value == -math.huge then
                fail("part '" .. part.name .. "' has a corner that is not a finite number")
            end
        end
    end
end
-- }}}

-- {{{ function M.size()
-- The extent along each axis, { x, y, z } numbers.
function M.size(shape)
    local b = shape.bounds
    return { b.max[1] - b.min[1], b.max[2] - b.min[2], b.max[3] - b.min[3] }
end
-- }}}

return M

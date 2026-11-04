-- 026-finding-joints.lua - which parts of a model touch or nearly touch.
--
-- In plain terms: for every pair of parts, find how close their surfaces
-- come. Each corner of one part is measured to the nearest triangle of the
-- other (and the other way round), so a corner resting on the middle of a
-- big flat face is found touching, not merely as close as the face's own
-- corners. Pairs closer than a contact distance are joints, and for each the
-- measures a calculation can use are taken from the geometry: the gap, where
-- the parts come closest, the direction across the contact, how far each
-- part reaches along that direction, and how large the touching zone is.
--
-- Speed: a part's triangles are put into a grid of cubes once, each
-- triangle into every cube it comes within the contact distance of, so a
-- corner is only measured against the few triangles in its own cube.
-- Edge-to-edge contacts with no corner near the other part are missed;
-- every pair of solids that rest on each other has corners near the other.
--
-- A found joint: { a = part name, b = part name, gap = number (units),
--   contact_point = {x,y,z}, normal = {x,y,z} (unit, from a toward b),
--   reach_a, reach_b (each part's extent along the normal),
--   contact_size (largest extent of the zone within the contact distance) }

local M = {}

-- {{{ local function closest_on_triangle()
-- The point of triangle a,b,c nearest p (all {x,y,z}): the standard
-- method of testing which region of the triangle p's foot lies in
-- (Ericson, Real-Time Collision Detection, 5.1.5).
local function sub(u, v) return { u[1] - v[1], u[2] - v[2], u[3] - v[3] } end
local function dot(u, v) return u[1] * v[1] + u[2] * v[2] + u[3] * v[3] end
local function along(o, d, t) return { o[1] + d[1] * t, o[2] + d[2] * t, o[3] + d[3] * t } end
local function closest_on_triangle(p, a, b, c)
    local ab, ac, ap = sub(b, a), sub(c, a), sub(p, a)
    local d1, d2 = dot(ab, ap), dot(ac, ap)
    if d1 <= 0 and d2 <= 0 then return a end
    local bp = sub(p, b)
    local d3, d4 = dot(ab, bp), dot(ac, bp)
    if d3 >= 0 and d4 <= d3 then return b end
    local vc = d1 * d4 - d3 * d2
    if vc <= 0 and d1 >= 0 and d3 <= 0 then return along(a, ab, d1 / (d1 - d3)) end
    local cp = sub(p, c)
    local d5, d6 = dot(ab, cp), dot(ac, cp)
    if d6 >= 0 and d5 <= d6 then return c end
    local vb = d5 * d2 - d1 * d6
    if vb <= 0 and d2 >= 0 and d6 <= 0 then return along(a, ac, d2 / (d2 - d6)) end
    local va = d3 * d6 - d5 * d4
    if va <= 0 and (d4 - d3) >= 0 and (d5 - d6) >= 0 then
        return along(b, sub(c, b), (d4 - d3) / ((d4 - d3) + (d5 - d6)))
    end
    local denominator = 1 / (va + vb + vc)
    local v, w = vb * denominator, vc * denominator
    return { a[1] + ab[1] * v + ac[1] * w, a[2] + ab[2] * v + ac[2] * w, a[3] + ab[3] * v + ac[3] * w }
end
M.closest_on_triangle = closest_on_triangle
-- }}}

-- {{{ local function bounds_of()
local function bounds_of(part)
    local p = part.positions
    local lo, hi = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
    for k = 1, #p, 3 do
        for axis = 1, 3 do
            local v = p[k + axis - 1]
            if v < lo[axis] then lo[axis] = v end
            if v > hi[axis] then hi[axis] = v end
        end
    end
    return { lo = lo, hi = hi }
end
-- }}}

-- {{{ local function grid_of()
-- A part's triangles by grid cube: cube key -> list of triangle numbers.
-- Each triangle goes into every cube its bounds (grown by `reach`) touch.
local OFFSET, SPAN = 100000, 200000
local function cube_key(ix, iy, iz) return (ix + OFFSET) + (iy + OFFSET) * SPAN + (iz + OFFSET) * SPAN * SPAN end
local function grid_of(part, cube, reach)
    local p, cells = part.positions, {}
    for t = 0, #p / 9 - 1 do
        local base = t * 9
        local lo, hi = {}, {}
        for axis = 1, 3 do
            local a, b, c = p[base + axis], p[base + 3 + axis], p[base + 6 + axis]
            lo[axis] = math.floor((math.min(a, b, c) - reach) / cube)
            hi[axis] = math.floor((math.max(a, b, c) + reach) / cube)
        end
        for ix = lo[1], hi[1] do for iy = lo[2], hi[2] do for iz = lo[3], hi[3] do
            local key = cube_key(ix, iy, iz)
            local list = cells[key]
            if list == nil then list = {}; cells[key] = list end
            list[#list + 1] = t
        end end end
    end
    return cells
end
-- }}}

-- {{{ local function measure()
-- Every corner of `from` measured to the nearest triangle of `to` (through
-- to's grid). Returns the closest distance, the two closest points, the
-- triangle it was on, and the corners within `reach` (the touching zone).
local function measure(from, to, to_cells, cube, reach, to_bounds)
    local best, best_from, best_to, best_triangle = math.huge, nil, nil, nil
    local zone = {}
    local p, q = from.positions, to.positions
    for k = 1, #p, 3 do
        local x, y, z = p[k], p[k + 1], p[k + 2]
        -- far outside the other part's bounds: no triangle can be near
        if x >= to_bounds.lo[1] - reach and x <= to_bounds.hi[1] + reach and y >= to_bounds.lo[2] - reach
            and y <= to_bounds.hi[2] + reach and z >= to_bounds.lo[3] - reach and z <= to_bounds.hi[3] + reach then
            local list = to_cells[cube_key(math.floor(x / cube), math.floor(y / cube), math.floor(z / cube))]
            if list then
                local point = { x, y, z }
                local nearest = math.huge
                for _, t in ipairs(list) do
                    local base = t * 9
                    local c = closest_on_triangle(point, { q[base + 1], q[base + 2], q[base + 3] },
                        { q[base + 4], q[base + 5], q[base + 6] }, { q[base + 7], q[base + 8], q[base + 9] })
                    local dx, dy, dz = c[1] - x, c[2] - y, c[3] - z
                    local d = math.sqrt(dx * dx + dy * dy + dz * dz)
                    if d < nearest then nearest = d end
                    if d < best then best, best_from, best_to, best_triangle = d, point, c, t end
                end
                if nearest <= reach then zone[#zone + 1] = point end
            end
        end
    end
    return best, best_from, best_to, best_triangle, zone
end
-- }}}

-- {{{ local function extent_along()
-- How far a part reaches along a direction (largest minus smallest
-- projection of its corners).
local function extent_along(part, n)
    local p, lo, hi = part.positions, math.huge, -math.huge
    for k = 1, #p, 3 do
        local d = p[k] * n[1] + p[k + 1] * n[2] + p[k + 2] * n[3]
        if d < lo then lo = d end
        if d > hi then hi = d end
    end
    return hi - lo
end
-- }}}

-- {{{ function M.find()
-- shape (a finished shape record), contact_distance (model units) -> list
-- of found joints (above), in part order.
function M.find(shape, contact_distance)
    local reach = contact_distance
    local size = 0
    for axis = 1, 3 do size = math.max(size, shape.bounds.max[axis] - shape.bounds.min[axis]) end
    -- cubes of about a hundredth of the model, never smaller than the reach
    local cube = math.max(reach, size / 100)
    local bounds, grids = {}, {}
    for i, part in ipairs(shape.parts) do bounds[i] = bounds_of(part) end
    local function grid(i)
        grids[i] = grids[i] or grid_of(shape.parts[i], cube, reach)
        return grids[i]
    end
    local joints = {}
    for i = 1, #shape.parts do
        for j = i + 1, #shape.parts do
            local A, B = bounds[i], bounds[j]
            local apart = false
            for axis = 1, 3 do
                if A.lo[axis] > B.hi[axis] + reach or B.lo[axis] > A.hi[axis] + reach then apart = true end
            end
            if not apart then
                local a, b = shape.parts[i], shape.parts[j]
                local d1, from1, to1, tri1, zone1 = measure(a, b, grid(j), cube, reach, B)
                local d2, from2, to2, tri2, zone2 = measure(b, a, grid(i), cube, reach, A)
                local gap = math.min(d1, d2)
                if gap <= reach then
                    -- the closest pair, as points on a and on b
                    local on_a, on_b = from1, to1
                    if d2 < d1 then on_a, on_b = to2, from2 end
                    local normal
                    if gap > 1e-9 * math.max(1, size) then
                        local v = sub(on_b, on_a)
                        normal = { v[1] / gap, v[2] / gap, v[3] / gap }
                    else
                        -- touching: the face touched, turned to point from a to b
                        local part, t = b, tri1
                        if d2 < d1 then part, t = a, tri2 end
                        local q, base = part.normals, t * 9
                        normal = { q[base + 1], q[base + 2], q[base + 3] }
                        local ca = { (A.lo[1] + A.hi[1]) / 2, (A.lo[2] + A.hi[2]) / 2, (A.lo[3] + A.hi[3]) / 2 }
                        local cb = { (B.lo[1] + B.hi[1]) / 2, (B.lo[2] + B.hi[2]) / 2, (B.lo[3] + B.hi[3]) / 2 }
                        if dot(normal, sub(cb, ca)) < 0 then normal = { -normal[1], -normal[2], -normal[3] } end
                    end
                    -- the touching zone: every corner of either part within reach
                    local lo, hi = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
                    for _, zone in ipairs({ zone1, zone2 }) do
                        for _, point in ipairs(zone) do
                            for axis = 1, 3 do
                                if point[axis] < lo[axis] then lo[axis] = point[axis] end
                                if point[axis] > hi[axis] then hi[axis] = point[axis] end
                            end
                        end
                    end
                    local contact_size = 0
                    if lo[1] <= hi[1] then
                        for axis = 1, 3 do contact_size = math.max(contact_size, hi[axis] - lo[axis]) end
                    end
                    joints[#joints + 1] = {
                        a = a.name, b = b.name, gap = gap,
                        contact_point = { (on_a[1] + on_b[1]) / 2, (on_a[2] + on_b[2]) / 2, (on_a[3] + on_b[3]) / 2 },
                        normal = normal, reach_a = extent_along(a, normal), reach_b = extent_along(b, normal),
                        contact_size = contact_size,
                    }
                end
            end
        end
    end
    return joints
end
-- }}}

return M

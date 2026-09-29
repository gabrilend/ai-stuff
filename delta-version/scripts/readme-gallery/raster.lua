-- raster.lua - turns placed shapes into a frame of palette colours.
--
-- What this is, generally: the painter. It takes the stage manager's list of
-- placed shapes and draws them the way a camera would see them: nearer
-- things hide farther ones, faces turned toward the light are brighter, the
-- edges of the house style glow. It knows nothing of scenes, reactions or
-- loops -- only shapes, a camera, and a canvas.
--
-- How, in a few lines: every shape's corners are moved into place, then
-- projected through a pinhole onto a canvas twice the final width and height.
-- Each triangle is filled pixel by pixel, keeping a pixel only if it is nearer
-- than what is already there (the depth buffer). The big canvas is then
-- averaged down by 2x2, which smooths every edge, and each final pixel is
-- given its palette index by the gif generator's own indexer.
--
-- Data formats worth knowing more than once:
--   canvas.rgb    float[W*W*3]  linear light, 0..1, row-major, y downward
--   canvas.depth  float[W*W]    1/distance (0 = nothing drawn = infinitely far);
--                               larger is nearer. 1/distance rather than
--                               distance because it interpolates straight
--                               across a projected triangle.
--   canvas.out    uint8[S*S]    final palette indices, 0-based, what the
--                               gif encoder compresses
--   W = S * SUPERSAMPLE

local ffi = require("ffi")

local raster = {}

local SUPERSAMPLE = 2

-- Nearest a shape's corner may come to the lens, in world units, before the
-- whole shape is left out of the frame (or, for an open sheet like the
-- ground, before that one face is).
local NEAR = 0.3

-- Lighting knobs, in camera space. The key light sits just above and to the
-- left of the lens, so whatever faces the viewer is lit; a light placed high
-- in the world went dark whenever the camera looked down on the scene. The
-- rim term brightens faces seen edge-on, which is what makes solids read as
-- glowing on black rather than as grey plastic. The palette's ramps are gamma-spaced and lean dark, so a face at half
-- brightness already reads muddy (gold turns olive); the floor is set high
-- enough that every lit face stays in the vivid upper half of its ramp.
local AMBIENT, DIFFUSE, RIM = 0.42, 0.62, 0.35
local LIGHT = { -0.35, 0.30, 0.89 }
do
    local len = math.sqrt(LIGHT[1] ^ 2 + LIGHT[2] ^ 2 + LIGHT[3] ^ 2)
    for i = 1, 3 do LIGHT[i] = LIGHT[i] / len end
end

-- {{{ function raster.new()
-- camera = { distance, fov (degrees), tilt (radians, looking down) }
function raster.new(size, camera, meshes)
    local W = size * SUPERSAMPLE
    local canvas = {
        size = size, W = W,
        rgb = ffi.new("float[?]", W * W * 3),
        depth = ffi.new("float[?]", W * W),
        out = ffi.new("uint8_t[?]", size * size),
        distance = camera.distance or 7,
        focal = (W / 2) / math.tan(math.rad(camera.fov or 45) / 2),
        cos_tilt = math.cos(camera.tilt or 0), sin_tilt = math.sin(camera.tilt or 0),
        meshes = meshes,
    }
    return canvas
end
-- }}}

-- {{{ function raster.set_view()
-- Points the lens for this frame. `view` is { eye, target, roll } from the
-- stage manager, or nil for the still camera. From eye and target it builds
-- the three directions the camera measures along -- forward (toward the
-- target), right, and up -- keeping "up" near the world's up, then turns
-- right and up about forward by the roll.
function raster.set_view(canvas, view)
    if not view then canvas.basis = nil; return end
    local e, g = view.eye, view.target
    local fx, fy, fz = g[1] - e[1], g[2] - e[2], g[3] - e[3]
    local len = math.sqrt(fx * fx + fy * fy + fz * fz)
    fx, fy, fz = fx / len, fy / len, fz / len
    -- right = forward x world-up; if looking straight up or down, any
    -- horizontal right will do
    local rx, ry, rz = -fz, 0, fx
    local rl = math.sqrt(rx * rx + rz * rz)
    if rl < 1e-6 then rx, ry, rz, rl = 1, 0, 0, 1 end
    rx, ry, rz = rx / rl, ry / rl, rz / rl
    local ux, uy, uz = ry * fz - rz * fy, rz * fx - rx * fz, rx * fy - ry * fx
    local c, s = math.cos(view.roll or 0), math.sin(view.roll or 0)
    canvas.basis = {
        eye = e,
        right = { rx * c + ux * s, ry * c + uy * s, rz * c + uz * s },
        up = { ux * c - rx * s, uy * c - ry * s, uz * c - rz * s },
        forward = { fx, fy, fz },
    }
end
-- }}}

-- {{{ function raster.clear()
function raster.clear(canvas)
    ffi.fill(canvas.rgb, canvas.W * canvas.W * 3 * 4)
    ffi.fill(canvas.depth, canvas.W * canvas.W * 4)
end
-- }}}

-- {{{ local function to_camera()
-- World point to camera space: the world is tipped by the camera's tilt,
-- then the camera sits `distance` back along +z looking toward -z.
-- Returns x, y, and depth (distance in front of the lens).
local function to_camera(canvas, x, y, z)
    -- Two paths: a moving camera's view (set by raster.set_view) measures
    -- the point against the eye's own right, up and forward directions; the
    -- still camera keeps its original arithmetic below, untouched, because
    -- the approved films are reproduced from it byte for byte.
    local basis = canvas.basis
    if basis then
        local px, py, pz = x - basis.eye[1], y - basis.eye[2], z - basis.eye[3]
        local r, u, f = basis.right, basis.up, basis.forward
        return px * r[1] + py * r[2] + pz * r[3],
               px * u[1] + py * u[2] + pz * u[3],
               px * f[1] + py * f[2] + pz * f[3]
    end
    local c, s = canvas.cos_tilt, canvas.sin_tilt
    local yc = y * c - z * s
    local zc = y * s + z * c
    return x, yc, canvas.distance - zc
end
-- }}}

-- {{{ local function project()
local function project(canvas, x, y, depth)
    local half = canvas.W / 2
    return half + canvas.focal * x / depth, half - canvas.focal * y / depth
end
-- }}}

-- {{{ local function fill_triangle()
-- Screen-space triangle with per-corner 1/depth; one flat colour.
local function fill_triangle(canvas, ax, ay, az, bx, by, bz, cx, cy, cz, r, g, b)
    local W = canvas.W
    local area = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
    if area == 0 then return end
    local minx = math.max(0, math.floor(math.min(ax, bx, cx)))
    local maxx = math.min(W - 1, math.ceil(math.max(ax, bx, cx)))
    local miny = math.max(0, math.floor(math.min(ay, by, cy)))
    local maxy = math.min(W - 1, math.ceil(math.max(ay, by, cy)))
    local rgb, depth = canvas.rgb, canvas.depth
    local inv_area = 1 / area
    for py = miny, maxy do
        local sy = py + 0.5
        for px = minx, maxx do
            local sx = px + 0.5
            local w0 = ((bx - sx) * (cy - sy) - (by - sy) * (cx - sx)) * inv_area
            local w1 = ((cx - sx) * (ay - sy) - (cy - sy) * (ax - sx)) * inv_area
            local w2 = 1 - w0 - w1
            -- Inside when all three weights share the triangle's sign; the
            -- division by area already made them positive inside either way.
            if w0 >= 0 and w1 >= 0 and w2 >= 0 then
                local inv = w0 * az + w1 * bz + w2 * cz
                local i = py * W + px
                if inv > depth[i] then
                    depth[i] = inv
                    rgb[i * 3], rgb[i * 3 + 1], rgb[i * 3 + 2] = r, g, b
                end
            end
        end
    end
end
-- }}}

-- {{{ local function draw_line()
-- A glowing edge: two pixels thick on the big canvas (one after the 2x2
-- average), kept only where it is not well behind what is drawn there.
local function draw_line(canvas, ax, ay, az, bx, by, bz, r, g, b)
    local W = canvas.W
    local steps = math.max(1, math.ceil(math.max(math.abs(bx - ax), math.abs(by - ay))))
    local rgb, depth = canvas.rgb, canvas.depth
    for k = 0, steps do
        local f = k / steps
        local x = math.floor(ax + (bx - ax) * f)
        local y = math.floor(ay + (by - ay) * f)
        local inv = az + (bz - az) * f
        for dy = 0, 1 do for dx = 0, 1 do
            local px, py = x + dx, y + dy
            if px >= 0 and px < W and py >= 0 and py < W then
                local i = py * W + px
                -- the small allowance lets an edge win against the very
                -- face it borders, which sits at nearly the same depth
                if inv >= depth[i] * 0.985 then
                    if inv > depth[i] then depth[i] = inv end
                    rgb[i * 3], rgb[i * 3 + 1], rgb[i * 3 + 2] = r, g, b
                end
            end
        end end
    end
end
-- }}}

-- {{{ local function edges_of()
-- Every edge of a shape with the one or two faces that share it, worked out
-- once and kept on the shape. Which of them glow is decided each frame (see
-- is_feature), because a morphing shape's creases come and go.
local function edges_of(mesh)
    if mesh.edges then return mesh.edges end
    local seen, edges = {}, {}
    for f, face in ipairs(mesh.faces) do
        for k = 1, 3 do
            local i, j = face[k], face[k % 3 + 1]
            local key = math.min(i, j) * 65536 + math.max(i, j)
            if seen[key] then
                seen[key].f2 = f
            else
                seen[key] = { i = i, j = j, f1 = f }
                edges[#edges + 1] = seen[key]
            end
        end
    end
    mesh.edges = edges
    return edges
end
-- }}}

-- {{{ local function is_feature()
-- An edge worth glowing: two faces meeting at a visible angle, or a face
-- with no neighbour. The diagonal splitting a cube's square face is not one,
-- nor is the grid on a flat face of the superball when it stands as a cube.
local CREASE = 0.985
local function is_feature(edge, normals)
    local n1, n2 = normals[edge.f1], edge.f2 and normals[edge.f2]
    if not n2 then return true end
    return (n1[1] * n2[1] + n1[2] * n2[2] + n1[3] * n2[3]) < CREASE
end
-- }}}

-- {{{ local function shade()
-- Brightness of a face from its camera-space unit normal. Two paths: a solid
-- face (only ever seen from the front) and a shard (thin, seen from either
-- side, so the light is judged against whichever side faces the camera).
local function shade(nx, ny, nz, two_sided, glow)
    if two_sided and nz < 0 then nx, ny, nz = -nx, -ny, -nz end
    local lambert = math.max(0, nx * LIGHT[1] + ny * LIGHT[2] + nz * LIGHT[3])
    local rim = (1 - math.max(0, nz)) ^ 3
    return math.min(1, AMBIENT + DIFFUSE * lambert + RIM * rim + 0.45 * glow)
end
-- }}}

-- {{{ function raster.draw_item()
-- One placed shape (see choreography.lua for the fields).
function raster.draw_item(canvas, item)
    local mesh = item.mesh
    local rot, pos, st, sc = item.rotation, item.position, item.stretch, item.scale
    local shattered = item.shatter > 0.01

    -- corners to camera space and to the screen, once each
    local cam, scr = {}, {}
    for v, p in ipairs(mesh.verts) do
        local x, y, z = p[1], p[2], p[3]
        if item.morph_p then x, y, z = canvas.meshes.reshape(p, item.morph_p) end
        -- morphing through solids: each sphere corner is pushed out to the
        -- blend of how far the two solids reach in its direction
        if item.through then
            local th = item.through
            local ra = canvas.meshes.radius_toward(th.a, p)
            local rb = canvas.meshes.radius_toward(th.b, p)
            local r = ra + (rb - ra) * th.f
            x, y, z = p[1] * r, p[2] * r, p[3] * r
        end
        -- stretched, then shifted by the pivot (so a petal hinges at its
        -- base rather than its middle), then sized, then turned and placed
        local pv = item.pivot
        if pv then
            x, y, z = (x * st[1] + pv[1]) * sc, (y * st[2] + pv[2]) * sc, (z * st[3] + pv[3]) * sc
        else
            x, y, z = x * st[1] * sc, y * st[2] * sc, z * st[3] * sc
        end
        local wx = rot[1][1] * x + rot[1][2] * y + rot[1][3] * z + pos[1]
        local wy = rot[2][1] * x + rot[2][2] * y + rot[2][3] * z + pos[2]
        local wz = rot[3][1] * x + rot[3][2] * y + rot[3][3] * z + pos[3]
        local cx, cy, depth = to_camera(canvas, wx, wy, wz)
        -- Two paths near the lens. A solid touching or behind it is skipped
        -- whole: a flying camera passes right by things, and half a shape
        -- drawn through the lens is a smear across the frame. An open sheet
        -- (the ground) always reaches under the camera, so it loses only the
        -- faces that do. (A still camera never comes this close, so the
        -- approved films are unaffected.)
        if depth < NEAR and not mesh.open_sheet then return end
        cam[v] = { cx, cy, depth }
    end

    local front, normals = {}, {}
    for f, face in ipairs(mesh.faces) do
        local a, b, c = cam[face[1]], cam[face[2]], cam[face[3]]
        if mesh.open_sheet and (a[3] < NEAR or b[3] < NEAR or c[3] < NEAR) then goto next_face end
        -- camera space here has +z toward the viewer = -(depth); rebuild it
        local ax, ay, az = a[1], a[2], -a[3]
        local bx, by, bz = b[1], b[2], -b[3]
        local cx, cy, cz = c[1], c[2], -c[3]
        local ux, uy, uz = bx - ax, by - ay, bz - az
        local vx, vy, vz = cx - ax, cy - ay, cz - az
        local nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
        local len = math.sqrt(nx * nx + ny * ny + nz * nz)
        if len > 0 then
            nx, ny, nz = nx / len, ny / len, nz / len
            normals[f] = { nx, ny, nz }
            -- facing the lens: the normal points back toward the camera,
            -- which sits at (0, 0, 0) looking down -z in these coordinates
            local mx, my, mz = (ax + bx + cx) / 3, (ay + by + cy) / 3, (az + bz + cz) / 3
            local toward = -(nx * mx + ny * my + nz * mz)
            front[f] = toward > 0

            local r, g, bl = item.rgb[1], item.rgb[2], item.rgb[3]
            local corners = { { ax, ay, az }, { bx, by, bz }, { cx, cy, cz } }
            if shattered then
                -- the face flies out along its own normal and shrinks toward
                -- its middle; its colour turns toward its rainbow seat
                local s = item.shatter
                local push = s * item.shard_distance * sc
                local shrink = 1 - 0.45 * s
                for _, k in ipairs(corners) do
                    k[1] = mx + (k[1] - mx) * shrink + nx * push
                    k[2] = my + (k[2] - my) * shrink + ny * push
                    k[3] = mz + (k[3] - mz) * shrink + nz * push
                end
                local seat = item.shard_rgbs[(f - 1) % #item.shard_rgbs + 1]
                r, g, bl = r + (seat[1] - r) * s, g + (seat[2] - g) * s, bl + (seat[3] - bl) * s
            end
            -- Paint paths: a wire shape draws no faces; a whole solid draws
            -- only faces turned toward the lens; shards draw both sides.
            if item.style ~= "wire" and (front[f] or shattered) then
                local light = shade(nx, ny, nz, shattered, item.glow)
                local p = {}
                for i, k in ipairs(corners) do
                    local depth = -k[3]
                    if depth <= 0.05 then return end -- behind the lens: skip shape
                    local sx, sy = project(canvas, k[1], k[2], depth)
                    p[i] = { sx, sy, 1 / depth }
                end
                fill_triangle(canvas, p[1][1], p[1][2], p[1][3], p[2][1], p[2][2], p[2][3],
                              p[3][1], p[3][2], p[3][3], r * light, g * light, bl * light)
            end
        end
        ::next_face::
    end

    -- Edge paths: glow edges only on a whole shape (shards carry their own
    -- colour); wire draws every feature edge at full colour, front or back.
    if shattered or item.style == "solid" then return end
    local er, eg, eb, all_sides
    if item.style == "wire" then
        er, eg, eb, all_sides = item.rgb[1], item.rgb[2], item.rgb[3], true
    else
        local k = 0.45
        er = item.rgb[1] + (1 - item.rgb[1]) * k
        eg = item.rgb[2] + (1 - item.rgb[2]) * k
        eb = item.rgb[3] + (1 - item.rgb[3]) * k
        all_sides = false
    end
    for _, e in ipairs(edges_of(mesh)) do
        local faces_known = normals[e.f1] and (not e.f2 or normals[e.f2])
        if faces_known and is_feature(e, normals)
           and (all_sides or front[e.f1] or (e.f2 and front[e.f2])) then
            local a, b = cam[e.i], cam[e.j]
            if a[3] > 0.05 and b[3] > 0.05 then
                local ax, ay = project(canvas, a[1], a[2], a[3])
                local bx, by = project(canvas, b[1], b[2], b[3])
                draw_line(canvas, ax, ay, 1 / a[3], bx, by, 1 / b[3], er, eg, eb)
            end
        end
    end
end
-- }}}

-- {{{ function raster.project_point()
-- Where a world point lands in the frame: x and y as fractions across it
-- (0 to 1, y downward) and its depth in front of the lens. Used by the
-- framing check to ask whether a shape is in view.
function raster.project_point(canvas, x, y, z)
    local cx, cy, depth = to_camera(canvas, x, y, z)
    if depth <= 0 then return -1, -1, depth end
    local sx, sy = project(canvas, cx, cy, depth)
    return sx / canvas.W, sy / canvas.W, depth
end
-- }}}

-- {{{ function raster.draw_stroke()
-- A thin line of light through world points (a gust of wind): each segment
-- drawn like a glowing edge, hidden where a nearer shape stands in front.
-- Segments touching or behind the lens are left out.
function raster.draw_stroke(canvas, stroke)
    local previous = nil
    local limit = canvas.W * 4
    for k, p in ipairs(stroke.points) do
        local cx, cy, depth = to_camera(canvas, p[1], p[2], p[3])
        local here = nil
        if depth > NEAR then
            local sx, sy = project(canvas, cx, cy, depth)
            here = { sx, sy, 1 / depth }
        end
        -- a segment flung far past the frame (one end just in front of the
        -- lens) would cost thousands of steps to draw nothing; skip it
        if previous and here and math.abs(here[1] - previous[1]) + math.abs(here[2] - previous[2]) < limit then
            local rgb = stroke.rgbs and stroke.rgbs[k - 1] or stroke.rgb
            draw_line(canvas, previous[1], previous[2], previous[3], here[1], here[2], here[3],
                      rgb[1], rgb[2], rgb[3])
        end
        previous = here
    end
end
-- }}}

-- {{{ local function view_basis()
-- The lens as an eye and three directions (right, up, forward), for either
-- camera: a moving one's view as set, or the still camera's tilt and
-- distance rewritten in the same terms -- the same arithmetic to_camera does.
local function view_basis(canvas)
    if canvas.basis then return canvas.basis end
    local c, s, d = canvas.cos_tilt, canvas.sin_tilt, canvas.distance
    return { eye = { 0, d * s, d * c }, right = { 1, 0, 0 }, up = { 0, c, -s }, forward = { 0, -s, -c } }
end
-- }}}

-- Blob drawing knobs. AMBIENT_BLOB lights the side facing away from every
-- light (the darkest band); MARCH_STEPS and HIT bound the ray march.
local AMBIENT_BLOB, MARCH_STEPS, HIT = 0.3, 64, 0.002

-- {{{ local function band_level()
-- The band a light's slant on a surface falls in: the slant (0 = edge-on,
-- 1 = facing the light) is cut into `bands` equal steps, and the step is
-- given as a level from 0 (dark) to 1 (full). This cutting is what turns
-- smooth shading into stacked levels of brightness.
local function band_level(slant, bands)
    if slant <= 0 then return 0 end
    return math.min(bands - 1, math.floor(slant * bands)) / (bands - 1)
end
raster.band_level = band_level
-- }}}

-- {{{ function raster.draw_blobs()
-- Soft round bodies that melt together, lit in bands by point lights.
--
-- How, in a few lines: each group of blobs is one surface -- the "smooth
-- union" of spheres, where two spheres closer than their softness bulge
-- into each other instead of meeting at a crease. For every pixel the blobs
-- might cover, a ray is sent from the eye; only blobs whose (softened) ball
-- the ray actually passes through are considered, and the ray creeps
-- forward by the distance to the nearest surface until it lands on it
-- ("ray marching"). There the surface's direction (normal) is measured, and
-- for each light the light's slant on it is cut into `bands` whole steps --
-- so each blob reads as stacked levels of brightness that sweep round as
-- the light moves. No outlines, no wireframe. The colour is a blend of the
-- nearby blobs' colours; nearer pixels win against everything already drawn
-- (the same depth buffer the solids use).
--
-- items: placed shapes with a `blob` table; lights: { { position, rgb } }.
function raster.draw_blobs(canvas, items, lights)
    if #items == 0 then return end
    local W, rgb, depth = canvas.W, canvas.rgb, canvas.depth
    local b = view_basis(canvas)
    local ex, ey, ez = b.eye[1], b.eye[2], b.eye[3]
    local R, U, F = b.right, b.up, b.forward
    local half, focal = W / 2, canvas.focal

    -- group the blobs; each group melts only into itself
    local groups, order = {}, {}
    for _, item in ipairs(items) do
        local g = item.blob.group
        if not groups[g] then groups[g] = {}; order[#order + 1] = g end
        local list = groups[g]
        list[#list + 1] = { x = item.position[1], y = item.position[2], z = item.position[3],
                            r = item.scale, soft = item.blob.soft, bands = item.blob.bands,
                            cr = item.rgb[1], cg = item.rgb[2], cb = item.rgb[3] }
    end

    for _, g in ipairs(order) do
        local blobs = groups[g]
        local n = #blobs
        local k = blobs[1].soft
        -- where on the screen this group can land: each blob's softened ball
        -- projected; a ball near or behind the lens widens it to everything
        local minx, miny, maxx, maxy = W, W, -1, -1
        for i = 1, n do
            local o = blobs[i]
            local px, py, pz = o.x - ex, o.y - ey, o.z - ez
            local cx = px * R[1] + py * R[2] + pz * R[3]
            local cy = px * U[1] + py * U[2] + pz * U[3]
            local cz = px * F[1] + py * F[2] + pz * F[3]
            local reach = o.r + k
            if cz - reach <= NEAR then
                minx, miny, maxx, maxy = 0, 0, W - 1, W - 1
            else
                local sx, sy = half + focal * cx / cz, half - focal * cy / cz
                local sr = focal * reach / (cz - reach) + 2
                minx, maxx = math.min(minx, sx - sr), math.max(maxx, sx + sr)
                miny, maxy = math.min(miny, sy - sr), math.max(maxy, sy + sr)
            end
        end
        minx, miny = math.max(0, math.floor(minx)), math.max(0, math.floor(miny))
        maxx, maxy = math.min(W - 1, math.ceil(maxx)), math.min(W - 1, math.ceil(maxy))

        local cand = {}
        for py = miny, maxy do
            local vy = (half - (py + 0.5)) / focal
            for px = minx, maxx do
                local vx = (px + 0.5 - half) / focal
                -- the ray: eye + t * dir, where t is exactly the depth
                local dx = F[1] + R[1] * vx + U[1] * vy
                local dy = F[2] + R[2] * vx + U[2] * vy
                local dz = F[3] + R[3] * vx + U[3] * vy
                local dlen = math.sqrt(dx * dx + dy * dy + dz * dz)
                -- the blobs this ray passes near, and the stretch of ray to search
                local m, t0, t1 = 0, math.huge, -math.huge
                for i = 1, n do
                    local o = blobs[i]
                    local ox, oy, oz = ex - o.x, ey - o.y, ez - o.z
                    local reach = o.r + k
                    local a = dx * dx + dy * dy + dz * dz
                    local bb = 2 * (ox * dx + oy * dy + oz * dz)
                    local c = ox * ox + oy * oy + oz * oz - reach * reach
                    local disc = bb * bb - 4 * a * c
                    if disc > 0 then
                        local sq = math.sqrt(disc)
                        local ta, tb = (-bb - sq) / (2 * a), (-bb + sq) / (2 * a)
                        if tb > NEAR then
                            m = m + 1
                            cand[m] = o
                            if ta < t0 then t0 = ta end
                            if tb > t1 then t1 = tb end
                        end
                    end
                end
                if m > 0 then
                    if t0 < NEAR then t0 = NEAR end
                    -- {{{ local function field()
                    -- distance from a point to the melted surface of the
                    -- candidate blobs (negative inside)
                    local function field(x, y, z)
                        local d = math.huge
                        for i = 1, m do
                            local o = cand[i]
                            local di = math.sqrt((x - o.x) ^ 2 + (y - o.y) ^ 2 + (z - o.z) ^ 2) - o.r
                            if d == math.huge then
                                d = di
                            elseif k > 0 then
                                local h = math.max(k - math.abs(d - di), 0) / k
                                d = math.min(d, di) - h * h * k * 0.25
                            else
                                d = math.min(d, di)
                            end
                        end
                        return d
                    end
                    -- }}}
                    local t, hit = t0, false
                    for _ = 1, MARCH_STEPS do
                        local d = field(ex + dx * t, ey + dy * t, ez + dz * t)
                        if d < HIT then hit = true; break end
                        t = t + d / dlen
                        if t > t1 then break end
                    end
                    local inv = 1 / t
                    local idx = py * W + px
                    if hit and inv > depth[idx] then
                        local hx, hy, hz = ex + dx * t, ey + dy * t, ez + dz * t
                        -- the surface's direction, from how the distance
                        -- changes a hair's breadth either way
                        local e = 0.002
                        local nx = field(hx + e, hy, hz) - field(hx - e, hy, hz)
                        local ny = field(hx, hy + e, hz) - field(hx, hy - e, hz)
                        local nz = field(hx, hy, hz + e) - field(hx, hy, hz - e)
                        local nl = math.sqrt(nx * nx + ny * ny + nz * nz)
                        if nl > 0 then nx, ny, nz = nx / nl, ny / nl, nz / nl end
                        -- colour and banding from the nearby blobs, nearer weighing more
                        local wsum, cr, cg, cb, bands = 0, 0, 0, 0, 0
                        for i = 1, m do
                            local o = cand[i]
                            local di = math.sqrt((hx - o.x) ^ 2 + (hy - o.y) ^ 2 + (hz - o.z) ^ 2) - o.r
                            local w = math.exp(-math.max(di, 0) / (k * 0.35 + 1e-3)) + 1e-9
                            wsum = wsum + w
                            cr, cg, cb = cr + o.cr * w, cg + o.cg * w, cb + o.cb * w
                            bands = bands + o.bands * w
                        end
                        cr, cg, cb = cr / wsum, cg / wsum, cb / wsum
                        bands = math.floor(bands / wsum + 0.5)
                        -- each light's slant, cut into whole bands
                        local lr, lg, lb = AMBIENT_BLOB, AMBIENT_BLOB, AMBIENT_BLOB
                        for _, light in ipairs(lights) do
                            local lx, ly, lz = light.position[1] - hx, light.position[2] - hy, light.position[3] - hz
                            local ll = math.sqrt(lx * lx + ly * ly + lz * lz)
                            local slant = (nx * lx + ny * ly + nz * lz) / ll
                            local level = band_level(slant, bands)
                            lr = lr + light.rgb[1] * level * (1 - AMBIENT_BLOB)
                            lg = lg + light.rgb[2] * level * (1 - AMBIENT_BLOB)
                            lb = lb + light.rgb[3] * level * (1 - AMBIENT_BLOB)
                        end
                        depth[idx] = inv
                        rgb[idx * 3] = math.min(1, cr * lr)
                        rgb[idx * 3 + 1] = math.min(1, cg * lg)
                        rgb[idx * 3 + 2] = math.min(1, cb * lb)
                    end
                end
            end
        end
    end
end
-- }}}

-- {{{ function raster.draw_stars()
-- Background points, drawn first so every shape covers them. Each star is
-- { x, y (0..1 across the frame), rgb, brightness } at this moment; bright
-- ones get a small cross so they sparkle instead of sitting as dots.
function raster.draw_stars(canvas, stars)
    local W = canvas.W
    local rgb = canvas.rgb
    for _, star in ipairs(stars) do
        local cx = math.floor(star.x * (canvas.size - 1)) * SUPERSAMPLE
        local cy = math.floor(star.y * (canvas.size - 1)) * SUPERSAMPLE
        -- {{{ local function dab()
        local function dab(px, py, amount)
            for dy = 0, SUPERSAMPLE - 1 do for dx = 0, SUPERSAMPLE - 1 do
                local x, y = px + dx, py + dy
                if x >= 0 and x < W and y >= 0 and y < W then
                    local i = (y * W + x) * 3
                    rgb[i] = math.min(1, rgb[i] + star.rgb[1] * amount)
                    rgb[i + 1] = math.min(1, rgb[i + 1] + star.rgb[2] * amount)
                    rgb[i + 2] = math.min(1, rgb[i + 2] + star.rgb[3] * amount)
                end
            end end
        end
        -- }}}
        dab(cx, cy, star.brightness)
        if star.brightness > 0.6 then
            local arm = (star.brightness - 0.6) * 1.2
            dab(cx - SUPERSAMPLE, cy, arm)
            dab(cx + SUPERSAMPLE, cy, arm)
            dab(cx, cy - SUPERSAMPLE, arm)
            dab(cx, cy + SUPERSAMPLE, arm)
        end
    end
end
-- }}}

-- {{{ function raster.finish()
-- Averages the big canvas down 2x2 and asks the palette for each pixel's
-- index. `index_of(r, g, b)` is handed in (the gif generator's indexer bound
-- to this scene's palette), so this file never learns how the palette works.
function raster.finish(canvas, index_of)
    local S, W, rgb, out = canvas.size, canvas.W, canvas.rgb, canvas.out
    local quarter = 1 / (SUPERSAMPLE * SUPERSAMPLE)
    for y = 0, S - 1 do
        for x = 0, S - 1 do
            local r, g, b = 0, 0, 0
            for dy = 0, SUPERSAMPLE - 1 do for dx = 0, SUPERSAMPLE - 1 do
                local i = ((y * SUPERSAMPLE + dy) * W + (x * SUPERSAMPLE + dx)) * 3
                r, g, b = r + rgb[i], g + rgb[i + 1], b + rgb[i + 2]
            end end
            out[y * S + x] = index_of(r * quarter, g * quarter, b * quarter)
        end
    end
    return out
end
-- }}}

return raster

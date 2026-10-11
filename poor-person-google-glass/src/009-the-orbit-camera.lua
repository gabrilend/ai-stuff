-- 009-the-orbit-camera.lua - a camera on an invisible ball around the shape.
--
-- In plain terms: the camera always looks at one point (the target) from a
-- distance, and the mouse moves it around the surface of a ball centred on
-- that point: left and right is yaw (turning about the vertical), up and down
-- is pitch (tilting over the top). Zooming shrinks or grows the ball;
-- panning slides the target sideways. This file is only arithmetic, with no
-- LÖVE in it, so the tests can run it directly.
--
-- Matrices here are 4x4, written as four rows of four numbers
-- ({ {..}, {..}, {..}, {..} }), and multiply column vectors: a point p goes
-- to M·p. The projection is OpenGL's: after dividing by w, everything on
-- screen has x, y and z between -1 and 1.
--
-- World space is y up. A shape whose file says z is up is stood upright by
-- the "upright" matrix, which the viewer applies before the camera sees it.

local M = {}

local PITCH_LIMIT = math.rad(89)

-- {{{ local function multiply()
local function multiply(a, b)
    local out = {}
    for row = 1, 4 do
        out[row] = {}
        for column = 1, 4 do
            local sum = 0
            for k = 1, 4 do sum = sum + a[row][k] * b[k][column] end
            out[row][column] = sum
        end
    end
    return out
end
M.multiply = multiply
-- }}}

-- {{{ function M.upright()
-- The model matrix that stands a shape upright: none for y up; for z up, a
-- quarter turn about x, taking the file's z to the world's y and the file's
-- y to the world's -z (so a model's front, toward -y in CAD, faces the
-- default camera).
function M.upright(up_axis)
    if up_axis == "z" then
        return { { 1, 0, 0, 0 }, { 0, 0, 1, 0 }, { 0, -1, 0, 0 }, { 0, 0, 0, 1 } }
    end
    return { { 1, 0, 0, 0 }, { 0, 1, 0, 0 }, { 0, 0, 1, 0 }, { 0, 0, 0, 1 } }
end
-- }}}

-- {{{ function M.transform()
-- A point {x,y,z} through a matrix; returns x, y, z, w.
function M.transform(m, p)
    local x, y, z = p[1], p[2], p[3]
    return m[1][1] * x + m[1][2] * y + m[1][3] * z + m[1][4],
           m[2][1] * x + m[2][2] * y + m[2][3] * z + m[2][4],
           m[3][1] * x + m[3][2] * y + m[3][3] * z + m[3][4],
           m[4][1] * x + m[4][2] * y + m[4][3] * z + m[4][4]
end
-- }}}

-- {{{ function M.new()
-- camera = { target = {x,y,z}, yaw = radians, pitch = radians,
--            distance = number, radius = number (the shape's size, for the
--            near and far planes), fov = radians (top to bottom) }
function M.new(fov_degrees)
    return { target = { 0, 0, 0 }, yaw = math.rad(35), pitch = math.rad(25),
             distance = 10, radius = 1, fov = math.rad(fov_degrees) }
end
-- }}}

-- {{{ function M.fit()
-- Aims at `centre` and backs off until a ball of `radius` around it fits the
-- narrower of the two screen directions, with a tenth to spare.
function M.fit(camera, centre, radius, aspect)
    camera.target = { centre[1], centre[2], centre[3] }
    camera.radius = math.max(radius, 1e-9)
    local half = camera.fov / 2
    -- a window taller than wide sees less side to side than top to bottom
    if aspect < 1 then half = math.atan(math.tan(half) * aspect) end
    camera.distance = camera.radius / math.sin(half) * 1.1
end
-- }}}

-- {{{ function M.stand_at()
-- Stands at `eye` looking at `look` (each {x,y,z}): the same camera, its
-- target the look point and its yaw, pitch and distance worked back from
-- the eye, so turning and zooming carry on from a station as from anywhere.
-- Pitch is held short of straight up or down, like any other pitch.
function M.stand_at(camera, eye, look)
    local dx, dy, dz = eye[1] - look[1], eye[2] - look[2], eye[3] - look[3]
    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
    if distance == 0 then error("a station's eye and look point are the same point", 0) end
    camera.target = { look[1], look[2], look[3] }
    camera.distance = distance
    camera.yaw = math.atan2(dx, dz)
    camera.pitch = math.max(-PITCH_LIMIT, math.min(PITCH_LIMIT, math.asin(dy / distance)))
end
-- }}}

-- {{{ function M.eye()
-- Where the camera stands: on the ball, at its yaw and pitch.
function M.eye(camera)
    local c = math.cos(camera.pitch)
    return { camera.target[1] + camera.distance * c * math.sin(camera.yaw),
             camera.target[2] + camera.distance * math.sin(camera.pitch),
             camera.target[3] + camera.distance * c * math.cos(camera.yaw) }
end
-- }}}

-- {{{ local function axes()
-- The camera's own right, up and backward directions (unit length).
local function axes(camera)
    local eye = M.eye(camera)
    local bx, by, bz = eye[1] - camera.target[1], eye[2] - camera.target[2], eye[3] - camera.target[3]
    local length = math.sqrt(bx * bx + by * by + bz * bz)
    bx, by, bz = bx / length, by / length, bz / length
    -- right = world up × backward; never zero, because pitch stops short of
    -- straight up or down
    local rx, ry, rz = bz, 0, -bx
    length = math.sqrt(rx * rx + rz * rz)
    rx, rz = rx / length, rz / length
    local ux, uy, uz = by * rz - bz * ry, bz * rx - bx * rz, bx * ry - by * rx
    return { rx, ry, rz }, { ux, uy, uz }, { bx, by, bz }, eye
end
-- }}}

-- {{{ function M.view()
-- World to camera: the camera at the origin looking down its own -z.
function M.view(camera)
    local r, u, b, e = axes(camera)
    local function dot(v) return v[1] * e[1] + v[2] * e[2] + v[3] * e[3] end
    return { { r[1], r[2], r[3], -dot(r) },
             { u[1], u[2], u[3], -dot(u) },
             { b[1], b[2], b[3], -dot(b) },
             { 0, 0, 0, 1 } }
end
-- }}}

-- {{{ function M.projection()
-- Perspective. Near and far hug the shape's ball, so depth precision is
-- spent on the shape, not on empty space in front of and behind it.
function M.projection(camera, aspect)
    local near = math.max(camera.distance - camera.radius * 1.5, camera.distance * 0.01)
    local far = camera.distance + camera.radius * 1.5
    local f = 1 / math.tan(camera.fov / 2)
    return { { f / aspect, 0, 0, 0 },
             { 0, f, 0, 0 },
             { 0, 0, (far + near) / (near - far), 2 * far * near / (near - far) },
             { 0, 0, -1, 0 } }
end
-- }}}

-- {{{ function M.to_screen()
-- Where a world point lands on a picture `width` × `height` pixels, with
-- (0, 0) at the top left as LÖVE draws. Returns x, y, and whether the point
-- is in front of the camera (a point behind it has no honest place).
function M.to_screen(camera, point, width, height)
    local m = multiply(M.projection(camera, width / height), M.view(camera))
    local x, y, _, w = M.transform(m, point)
    if w <= 0 then return 0, 0, false end
    return (x / w + 1) / 2 * width, (1 - y / w) / 2 * height, true
end
-- }}}

-- {{{ function M.orbit()
-- Moves around the ball; pitch stops just short of the poles.
function M.orbit(camera, yaw_radians, pitch_radians)
    camera.yaw = camera.yaw + yaw_radians
    camera.pitch = math.max(-PITCH_LIMIT, math.min(PITCH_LIMIT, camera.pitch + pitch_radians))
end
-- }}}

-- {{{ function M.pan()
-- Slides the target across the screen by a number of pixels, scaled so a
-- point at the target's depth follows the mouse exactly.
function M.pan(camera, dx_pixels, dy_pixels, screen_height)
    local r, u = axes(camera)
    local per_pixel = 2 * camera.distance * math.tan(camera.fov / 2) / screen_height
    for axis = 1, 3 do
        camera.target[axis] = camera.target[axis] - r[axis] * dx_pixels * per_pixel + u[axis] * dy_pixels * per_pixel
    end
end
-- }}}

-- {{{ function M.zoom()
-- Each wheel notch moves a tenth closer (positive) or farther (negative).
function M.zoom(camera, notches)
    camera.distance = camera.distance * 0.9 ^ notches
end
-- }}}

return M

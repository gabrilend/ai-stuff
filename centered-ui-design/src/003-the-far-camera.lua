-- 003-the-far-camera.lua - the camera that sits impossibly far away.
--
-- In plain terms: the world is filmed from a camera millions of units away
-- through a very long lens, so it looks almost flat and evenly scaled, like a
-- map, while still being true 3D. Filming from that far normally ruins the
-- accuracy of a graphics card's numbers; this file avoids that by never
-- multiplying by the large distance. Everything is measured from the map's
-- center (the camera's target), and the distance only appears once, divided,
-- where it can do no harm.
--
-- The same arithmetic exists twice: here in Lua (for clicking on the map and
-- for tests) and as a shader snippet (for drawing). They must stay identical;
-- the tests compare them on the CPU side.
--
-- Data flow:  world point (x, y, z), target-relative
--          -> eye amounts: across (ex), up (ey), toward camera (ez)
--          -> clip: x = ex / (half_height * aspect)
--                   y = ey / half_height
--                   w = 1 - ez / camera_distance   (the only use of distance)
--                   z = (-ez / depth_half_range) * w   (depth: linear across
--                                                       the scene's band)
--
-- Why w is "1 - ez / distance": a true perspective divides by the distance
-- from the camera, (distance - ez). Dividing that by the distance itself
-- changes nothing on screen (clip coordinates are homogeneous) but keeps
-- every number near 1. At ten million units away, ez/distance is about one
-- part in a hundred thousand: the perspective is real but faint, exactly as
-- an impossibly far camera would see it.

local M = {}

-- {{{ function M.new()
-- Builds a camera from the checked settings and the window's aspect ratio.
-- Fields (all numbers): right_x/y/z, up_x/y/z, back_x/y/z (unit vectors: the
-- screen's rightward, upward, and toward-the-camera directions in the world),
-- half_height (zoom: world units from the target to the screen's top edge),
-- aspect (width / height), distance (camera to target), depth_half_range.
function M.new(settings, aspect)
    local elevation = math.rad(settings.camera_elevation_degrees)
    -- The camera sits above and to the south of the target (south = +z,
    -- toward the bottom of the screen), looking down at `elevation`.
    local camera = {
        right_x = 1, right_y = 0, right_z = 0,
        up_x = 0, up_y = math.cos(elevation), up_z = -math.sin(elevation),
        back_x = 0, back_y = math.sin(elevation), back_z = math.cos(elevation),
        half_height = settings.view_half_height,
        aspect = aspect,
        distance = settings.camera_distance,
        depth_half_range = settings.depth_half_range,
        -- the chair's turn about the hub (radians); the game sets it
        turn = 0,
    }
    return camera
end
-- }}}

-- {{{ function M.project()
-- Projects a world point to normalized screen coordinates (ndc x and y from
-- -1 to 1, up is +y) and depth (-1 near .. 1 far), after turning it by the
-- chair (camera.turn: a point at angle a appears at angle a - turn).
-- The CPU twin of the shader's project_world().
function M.project(camera, x, y, z)
    local c, s = math.cos(camera.turn), math.sin(camera.turn)
    return M.project_fixed(camera, x * c + z * s, y, z * c - x * s)
end
-- }}}

-- {{{ function M.project_fixed()
-- The same, without the turn: for things hung on the camera itself.
-- The CPU twin of the shader's project_fixed().
function M.project_fixed(camera, x, y, z)
    local ex = x * camera.right_x + y * camera.right_y + z * camera.right_z
    local ey = x * camera.up_x + y * camera.up_y + z * camera.up_z
    local ez = x * camera.back_x + y * camera.back_y + z * camera.back_z
    local w = 1 - ez / camera.distance
    local clip_x = ex / (camera.half_height * camera.aspect)
    local clip_y = ey / camera.half_height
    local clip_z = (-ez / camera.depth_half_range) * w
    return clip_x / w, clip_y / w, clip_z / w
end
-- }}}

-- {{{ function M.ndc_to_pixels()
-- Normalized screen coordinates to window pixels (origin top-left, y down).
function M.ndc_to_pixels(ndc_x, ndc_y, width, height)
    return (ndc_x * 0.5 + 0.5) * width, (0.5 - ndc_y * 0.5) * height
end
-- }}}

-- {{{ function M.view_plane_corners()
-- The four corners of a flat plane hanging `plane_distance` world units in
-- front of the target (toward the camera), sized so that it exactly fills the
-- camera's view at that distance and zoom: a texture drawn on it lands on the
-- screen pixel for pixel.
--
-- Why the size is half_height * (1 - plane_distance / distance): the plane is
-- that much closer to the camera than the target is, so the view there is
-- that much narrower. With a camera this far away the factor is a hair under
-- one — but it is computed, not assumed.
--
-- Returns a list of four corners, each {x, y, z, u, v} (texture u, v with
-- 0,0 at the top-left), in the order top-left, top-right, bottom-right,
-- bottom-left.
function M.view_plane_corners(camera, plane_distance)
    local shrink = 1 - plane_distance / camera.distance
    local half_h = camera.half_height * shrink
    local half_w = half_h * camera.aspect
    local corners = {}
    local layout = {
        { -1,  1, 0, 0 },  -- top-left
        {  1,  1, 1, 0 },  -- top-right
        {  1, -1, 1, 1 },  -- bottom-right
        { -1, -1, 0, 1 },  -- bottom-left
    }
    for index, spot in ipairs(layout) do
        local ex = spot[1] * half_w
        local ey = spot[2] * half_h
        local ez = plane_distance
        corners[index] = {
            ex * camera.right_x + ey * camera.up_x + ez * camera.back_x,
            ex * camera.right_y + ey * camera.up_y + ez * camera.back_y,
            ex * camera.right_z + ey * camera.up_z + ez * camera.back_z,
            spot[3], spot[4],
        }
    end
    return corners
end
-- }}}
-- {{{ function M.ground_point_under_pixel()
-- Where on the ground (y = 0) a window pixel looks, in world terms (the
-- chair's turn undone). Used to name a stand by clicking it. Returns x, z.
--
-- Because the camera is so far away its rays are parallel to within float
-- accuracy, so the ray through a pixel is "the pixel's eye position, moved
-- along the view direction until it meets the ground".
function M.ground_point_under_pixel(camera, pixel_x, pixel_y, width, height)
    local ndc_x = (pixel_x / width) * 2 - 1
    local ndc_y = 1 - (pixel_y / height) * 2
    local ex = ndc_x * camera.half_height * camera.aspect
    local ey = ndc_y * camera.half_height
    -- the point (ex, ey, 0) in eye terms, as a (turned) world point
    local px = ex * camera.right_x + ey * camera.up_x
    local py = ex * camera.right_y + ey * camera.up_y
    local pz = ex * camera.right_z + ey * camera.up_z
    -- slide along the view direction (back) to the ground: py + t * back_y = 0
    local t = -py / camera.back_y
    local turned_x, turned_z = px + t * camera.back_x, pz + t * camera.back_z
    -- undo the chair's turn
    local c, s = math.cos(camera.turn), math.sin(camera.turn)
    return turned_x * c - turned_z * s, turned_z * c + turned_x * s
end
-- }}}

-- The shader twin of M.project_fixed: for things hung on the camera (the
-- console's sheet), which do not turn with the chair.
M.GLSL_FIXED = [[
uniform vec3 cam_right;
uniform vec3 cam_up;
uniform vec3 cam_back;
uniform float view_half_height;
uniform float view_aspect;
uniform float camera_distance;
uniform float depth_half_range;
uniform float flip_y;

// The far camera's projection. See 003-the-far-camera.lua for why the
// distance only ever appears divided.
vec4 project_fixed(vec3 p) {
    float ex = dot(p, cam_right);
    float ey = dot(p, cam_up);
    float ez = dot(p, cam_back);
    float w = 1.0 - ez / camera_distance;
    return vec4(ex / (view_half_height * view_aspect),
                flip_y * ey / view_half_height,
                (-ez / depth_half_range) * w,
                w);
}
]]

-- The shader twin of M.project: the world, turned by the chair first.
M.GLSL = M.GLSL_FIXED .. [[
uniform float view_turn;

// Turns the world about the hub so the chair's direction faces up the
// screen: a point at angle a appears at angle a - view_turn.
vec4 project_world(vec3 p) {
    float c = cos(view_turn);
    float s = sin(view_turn);
    return project_fixed(vec3(p.x * c + p.z * s, p.y, p.z * c - p.x * s));
}
]]

-- {{{ function M.send()
-- Hands the camera's numbers to a shader that includes M.GLSL (or
-- M.GLSL_FIXED, with `fixed` true: no turn is sent). `flip_y` is 1 or -1:
-- whether the target being drawn into stores rows top-down or bottom-up
-- (decided by the renderer, which knows).
function M.send(camera, shader, flip_y, fixed)
    shader:send("cam_right", { camera.right_x, camera.right_y, camera.right_z })
    shader:send("cam_up", { camera.up_x, camera.up_y, camera.up_z })
    shader:send("cam_back", { camera.back_x, camera.back_y, camera.back_z })
    shader:send("view_half_height", camera.half_height)
    shader:send("view_aspect", camera.aspect)
    shader:send("camera_distance", camera.distance)
    shader:send("depth_half_range", camera.depth_half_range)
    shader:send("flip_y", flip_y)
    -- the world turns with the chair; the sheet on the camera does not
    if not fixed then
        shader:send("view_turn", camera.turn)
    end
end
-- }}}

return M

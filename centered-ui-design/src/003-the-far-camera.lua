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
--
-- A second view stands beside it, for comparison (issue 214): the hub
-- camera, an ordinary perspective camera just above the hub, aimed out and
-- down across one quadrant at a time — the valley of the owner's reference
-- pictures, the near ground large and the far tiers shrinking toward a
-- horizon. It is close, so it needs no special care with numbers. The
-- console's sheet always hangs on the far camera (project_fixed), whichever
-- view films the world.

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
        -- Which view films the world: "flat" (this far camera) or "hub" (a
        -- true perspective camera standing just above the hub, looking out
        -- and down across one quadrant — the valley of the owner's reference
        -- pictures). The game can switch it while running.
        view = settings.view_depth,
        hub_eye_height = settings.hub_eye_height,
        hub_look_down = math.rad(settings.hub_look_down_degrees),
        hub_focal = 1 / math.tan(math.rad(settings.hub_field_of_view_degrees) / 2),
        hub_near = 0.5,
        hub_far = settings.edge_radius * 1.6,
    }
    return camera
end
-- }}}

-- {{{ function M.hub_basis()
-- The hub camera's directions in the world, from where the chair faces:
-- forward (out and down across the quadrant), right, and up (the screen's).
-- Each a list of three numbers.
function M.hub_basis(camera)
    local a, d = camera.turn, camera.hub_look_down
    local forward = { math.sin(a) * math.cos(d), -math.sin(d), -math.cos(a) * math.cos(d) }
    local right = { math.cos(a), 0, math.sin(a) }
    local up = { math.sin(a) * math.sin(d), math.cos(d), -math.cos(a) * math.sin(d) }
    return forward, right, up
end
-- }}}

-- {{{ local function project_hub()
-- The hub camera: an ordinary perspective from the eye just above the hub.
-- Depth runs from -1 at the near plane to 1 at the far plane.
local function project_hub(camera, x, y, z)
    local forward, right, up = M.hub_basis(camera)
    local rx, ry, rz = x, y - camera.hub_eye_height, z
    local xe = rx * right[1] + ry * right[2] + rz * right[3]
    local ye = rx * up[1] + ry * up[2] + rz * up[3]
    local ze = rx * forward[1] + ry * forward[2] + rz * forward[3]
    local near, far = camera.hub_near, camera.hub_far
    local depth = ((far + near) * ze - 2 * far * near) / ((far - near) * ze)
    return camera.hub_focal * xe / (camera.aspect * ze), camera.hub_focal * ye / ze, depth
end
-- }}}

-- {{{ function M.project()
-- Projects a world point to normalized screen coordinates (ndc x and y from
-- -1 to 1, up is +y) and depth (-1 near .. 1 far), through whichever view
-- films the world. The far view first turns the world by the chair
-- (camera.turn: a point at angle a appears at angle a - turn); the hub view
-- aims along the chair instead. The CPU twin of the shader's project_world().
function M.project(camera, x, y, z)
    -- the hub camera
    if camera.view == "hub" then
        return project_hub(camera, x, y, z)
    end
    -- the far camera
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
    -- the hub camera: follow the ray from the eye through the pixel to the ground
    if camera.view == "hub" then
        local forward, right, up = M.hub_basis(camera)
        local sx = ndc_x * camera.aspect / camera.hub_focal
        local sy = ndc_y / camera.hub_focal
        local dx = forward[1] + right[1] * sx + up[1] * sy
        local dy = forward[2] + right[2] * sx + up[2] * sy
        local dz = forward[3] + right[3] * sx + up[3] * sy
        -- looking at or above the horizon: the ray never meets the ground
        if dy >= -1e-6 then
            return math.huge, math.huge
        end
        local t = camera.hub_eye_height / -dy
        return dx * t, dz * t
    end
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

-- The shader twin of M.project: the world through whichever view films it.
M.GLSL = M.GLSL_FIXED .. [[
uniform float view_turn;
uniform float hub_view;      // 1: the hub camera; 0: the far camera
uniform float hub_eye_height;
uniform vec3 hub_forward;
uniform vec3 hub_right;
uniform vec3 hub_up;
uniform float hub_focal;
uniform float hub_near;
uniform float hub_far;

// How far a world point is from the hub camera's eye, along its view
// (for haze and focus). 0 under the far camera.
float hub_distance(vec3 p) {
    return hub_view * dot(p - vec3(0.0, hub_eye_height, 0.0), hub_forward);
}

// Which way a world-space surface faces, in the viewer's terms: x toward the
// screen's right, y toward its top. (For looking up the light dials, 213.)
vec2 view_facing(vec3 n) {
    if (hub_view > 0.5) {
        // the hub camera's own right and up
        return vec2(dot(n, hub_right), dot(n, hub_up));
    }
    // the far camera sees the world turned by the chair
    float c = cos(view_turn);
    float s = sin(view_turn);
    vec3 turned = vec3(n.x * c + n.z * s, n.y, n.z * c - n.x * s);
    return vec2(dot(turned, cam_right), dot(turned, cam_up));
}

vec4 project_world(vec3 p) {
    if (hub_view > 0.5) {
        // the hub camera: an ordinary perspective from just above the hub
        vec3 r = p - vec3(0.0, hub_eye_height, 0.0);
        float xe = dot(r, hub_right);
        float ye = dot(r, hub_up);
        float ze = dot(r, hub_forward);
        return vec4(hub_focal * xe / view_aspect,
                    flip_y * hub_focal * ye,
                    ((hub_far + hub_near) * ze - 2.0 * hub_far * hub_near) / (hub_far - hub_near),
                    ze);
    }
    // the far camera: turn the world about the hub so the chair's direction
    // faces up the screen (a point at angle a appears at angle a - view_turn)
    float c = cos(view_turn);
    float s = sin(view_turn);
    return project_fixed(vec3(p.x * c + p.z * s, p.y, p.z * c - p.x * s));
}
]]
-- {{{ function M.send_used()
-- Sends a value to a shader only if the shader uses it. A shader that needs
-- only part of the camera's arithmetic (the focus ring reads the eye and
-- rays, not the depth band) has the unused uniforms removed when compiled,
-- and sending to a removed uniform is an error — so absence here means "not
-- needed by this shader", never "missing".
function M.send_used(shader, name, value)
    if shader:hasUniform(name) then
        shader:send(name, value)
    end
end
-- }}}

-- {{{ function M.send()
-- Hands the camera's numbers to a shader that includes M.GLSL (or
-- M.GLSL_FIXED, with `fixed` true: no turn is sent). `flip_y` is 1 or -1:
-- whether the target being drawn into stores rows top-down or bottom-up
-- (decided by the renderer, which knows).
function M.send(camera, shader, flip_y, fixed)
    M.send_used(shader, "cam_right", { camera.right_x, camera.right_y, camera.right_z })
    M.send_used(shader, "cam_up", { camera.up_x, camera.up_y, camera.up_z })
    M.send_used(shader, "cam_back", { camera.back_x, camera.back_y, camera.back_z })
    M.send_used(shader, "view_half_height", camera.half_height)
    M.send_used(shader, "view_aspect", camera.aspect)
    M.send_used(shader, "camera_distance", camera.distance)
    M.send_used(shader, "depth_half_range", camera.depth_half_range)
    M.send_used(shader, "flip_y", flip_y)
    -- the world turns with the chair (or the hub camera aims along it); the
    -- sheet on the camera does neither
    if not fixed then
        local forward, right, up = M.hub_basis(camera)
        M.send_used(shader, "view_turn", camera.turn)
        M.send_used(shader, "hub_view", camera.view == "hub" and 1 or 0)
        M.send_used(shader, "hub_eye_height", camera.hub_eye_height)
        M.send_used(shader, "hub_forward", forward)
        M.send_used(shader, "hub_right", right)
        M.send_used(shader, "hub_up", up)
        M.send_used(shader, "hub_focal", camera.hub_focal)
        M.send_used(shader, "hub_near", camera.hub_near)
        M.send_used(shader, "hub_far", camera.hub_far)
    end
end
-- }}}

return M

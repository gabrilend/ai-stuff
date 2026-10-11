-- 025-the-focus-ring.lua - the tilt-shift blur, sharp in a ring of distance.
--
-- In plain terms: a tilt-shift photograph looks like a model because only a
-- band of it is sharp. Here the sharp band is a ring of distance around the
-- hub: ground that far out is crisp, and everything nearer or farther blurs
-- the more the further it is from that ring. Seen from the hub camera, a ring
-- of ground at one distance is an arc across the screen, so the sharp zone
-- is a semicircle — the owner: "be sure if you apply blurring to apply it in
-- a semicircle around a radius zone."
--
-- How a pixel's distance is known: the finished world picture holds only
-- colours, so each pixel's distance is worked out from the camera instead —
-- the ray from the eye through that pixel, met with the ground. (A figure
-- standing on the ground gets the distance of the ground just behind it,
-- close enough for a blur.)
--
-- The owner also noted the effect can be had without blurring, "if you have
-- lots of visible spaces" — the blur can be switched off in the settings
-- menu to compare.
--
-- Data flow:  finished world picture + camera ─▶ per pixel: ground distance
--             ─▶ blur radius ─▶ a disc of samples averaged ─▶ screen

local far_camera = require("003-the-far-camera")

local M = {}

-- Where the sharp ring is and how wide (shares of the map's edge radius), and
-- the widest blur (pixels). Tuning knobs: record changes in
-- docs/balance-updates.md.
M.FOCUS_SHARE = 0.42
M.SHARP_HALF_WIDTH_SHARE = 0.10
M.BLUR_RAMP_SHARE = 0.35
M.MOST_BLUR_PIXELS = 7

local PIXEL = far_camera.GLSL .. [[
uniform vec2 picture_size;
uniform float focus_distance;
uniform float sharp_half_width;
uniform float blur_ramp;
uniform float most_blur;

// How far from the hub the ground under this pixel is.
float ground_distance(vec2 uv) {
    vec2 ndc = vec2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);
    if (hub_view > 0.5) {
        // the hub camera: the ray from the eye through the pixel
        vec3 ray = hub_forward + hub_right * (ndc.x * view_aspect / hub_focal)
                 + hub_up * (ndc.y / hub_focal);
        if (ray.y > -1e-4) {
            // at or above the horizon: as far as can be
            return 1e6;
        }
        float t = hub_eye_height / -ray.y;
        return length(ray.xz * t);
    }
    // the far camera: rays are parallel; slide this pixel's eye point to the ground
    vec3 p = cam_right * (ndc.x * view_half_height * view_aspect) + cam_up * (ndc.y * view_half_height);
    float t = -p.y / cam_back.y;
    vec3 ground = p + cam_back * t;
    return length(ground.xz);
}

vec4 effect(vec4 color, Image world, vec2 uv, vec2 screen) {
    float d = ground_distance(uv);
    float off_focus = max(abs(d - focus_distance) - sharp_half_width, 0.0);
    float radius = most_blur * smoothstep(0.0, blur_ramp, off_focus);
    if (radius < 0.5) {
        // inside the sharp ring
        return Texel(world, uv);
    }
    // a disc of 16 samples on a golden-angle spiral
    vec4 sum = vec4(0.0);
    for (int i = 0; i < 16; i++) {
        float f = (float(i) + 0.5) / 16.0;
        float a = float(i) * 2.39996323;
        vec2 offset = vec2(cos(a), sin(a)) * sqrt(f) * radius / picture_size;
        sum += Texel(world, uv + offset);
    }
    return sum / 16.0;
}
]]

-- {{{ function M.new()
function M.new()
    return { shader = love.graphics.newShader(PIXEL) }
end
-- }}}

-- {{{ function M.draw()
-- Draws the finished world picture onto the current target through the
-- focus ring. `edge_radius` is the map's edge (world units).
function M.draw(ring, world_canvas, camera, edge_radius, flip_y)
    local shader = ring.shader
    love.graphics.setShader(shader)
    far_camera.send(camera, shader, flip_y)
    shader:send("picture_size", { world_canvas:getWidth(), world_canvas:getHeight() })
    shader:send("focus_distance", edge_radius * M.FOCUS_SHARE)
    shader:send("sharp_half_width", edge_radius * M.SHARP_HALF_WIDTH_SHARE)
    shader:send("blur_ramp", edge_radius * M.BLUR_RAMP_SHARE)
    shader:send("most_blur", M.MOST_BLUR_PIXELS)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(world_canvas)
    love.graphics.setShader()
end
-- }}}

return M

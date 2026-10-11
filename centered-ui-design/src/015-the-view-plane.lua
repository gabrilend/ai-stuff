-- 015-the-view-plane.lua - hanging the dashboard in the world, in front of the camera.
--
-- In plain terms: the dashboard's three layers (face, dials, glass) are not
-- pasted onto the screen. They are laid on a flat sheet placed in the 3D
-- scene itself, a set distance in front of the map, between the camera and
-- the world — and the sheet is sized so that, at that distance and at the
-- camera's current zoom, it exactly fills the view. Every pixel of the
-- dashboard pictures lands on one screen pixel.
--
-- The sheet's shader puts the layers together: where the face has metal, the
-- metal shows; where a window is cut, the glass bends the paper dial beneath
-- it a little outward toward the window's rim, tints it, and adds a curved
-- highlight; outside the dashboard the sheet is clear and the world shows.
--
-- Data flow:  camera settings + plane distance --> four corners in the world
--             (003, view_plane_corners) --> a four-cornered mesh --> projected
--             by the same far-camera arithmetic as the world --> screen

local far_camera = require("003-the-far-camera")

local M = {}

-- How far the glass bends what is beneath it, at a window's rim, as a share
-- of the picture's height.
M.REFRACTION = 0.004

-- How many times more strongly the arch's band bends the world than a
-- window bends its dial: the band is a lens over the map.
M.BAND_BEND = 3.0

local PLANE_VERTEX = far_camera.GLSL .. [[
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    return project_world(vertex_position.xyz);
}
]]

local PLANE_PIXEL = [[
uniform Image dials;
uniform Image glass;
uniform Image world;
uniform float band_bend;
uniform float refraction;
uniform float aspect_of_picture;

vec4 effect(vec4 color, Image face, vec2 uv, vec2 screen) {
    vec4 metal = Texel(face, uv);
    vec4 bend = Texel(glass, uv);
    // the glass's lean: green/blue around 0.5 mean none; red says glass is here
    vec2 lean = (bend.gb - vec2(0.5)) * 2.0 * bend.r;
    vec2 offset = lean * refraction * vec2(1.0 / aspect_of_picture, 1.0);
    // look a little inward from here, so the dial seems bent outward
    vec4 dial = Texel(dials, uv - offset);
    // glass: a faint cool tint, darker toward the rim, and a curved highlight
    // on the upper-left side of each window
    float rim = length(lean);
    vec3 under_glass = dial.rgb * (0.9 - 0.18 * rim) * vec3(0.95, 0.98, 1.0);
    float highlight = pow(max(dot(normalize(lean + vec2(1e-4)), vec2(-0.7071, -0.7071)), 0.0), 6.0)
                    * smoothstep(0.55, 0.95, rim) * 0.45;
    under_glass += vec3(highlight);
    float glass_here = step(0.5, bend.r);

    // The arch's band (glass alpha 0.5): the map display. The world itself
    // lies beneath it, seen through a stronger lens that bends it outward,
    // brightened a touch and warmed toward the gold edges.
    float band_here = glass_here * (1.0 - step(0.75, bend.a));
    vec4 world_seen = Texel(world, uv - offset * band_bend);
    vec3 through_band = world_seen.rgb * 1.15 * mix(vec3(1.0), vec3(1.0, 0.9, 0.7), rim * 0.6)
                      + vec3(highlight * 0.6);
    under_glass = mix(under_glass, through_band, band_here);
    float beneath_alpha = mix(dial.a, 1.0, band_here);

    // metal over glass over what is beneath; nothing at all outside the console
    vec3 rgb = mix(under_glass, metal.rgb, metal.a);
    float alpha = max(metal.a, glass_here * beneath_alpha);
    return vec4(rgb, alpha);
}
]]

-- {{{ function M.new()
function M.new(camera, plane_distance, dashboard)
    local plane = {
        camera = camera,
        plane_distance = plane_distance,
        dashboard = dashboard,
        shader = love.graphics.newShader(PLANE_PIXEL, PLANE_VERTEX),
    }
    local corners = far_camera.view_plane_corners(camera, plane_distance)
    plane.mesh = love.graphics.newMesh({
        { "VertexPosition", "float", 3 },
        { "VertexTexCoord", "float", 2 },
    }, corners, "fan", "static")
    plane.mesh:setTexture(dashboard.face)
    return plane
end
-- }}}

-- {{{ function M.draw()
-- Draws the sheet over the world. It is drawn after the world picture is
-- finished (not into it), because the arch's band looks through the sheet
-- at that picture: `world_canvas` is the finished world. The sheet still
-- goes through the far camera's projection, at its own distance.
function M.draw(plane, flip_y, world_canvas)
    love.graphics.setDepthMode("always", false)
    love.graphics.setShader(plane.shader)
    far_camera.send(plane.camera, plane.shader, flip_y)
    plane.shader:send("dials", plane.dashboard.dials)
    plane.shader:send("glass", plane.dashboard.glass)
    plane.shader:send("world", world_canvas)
    plane.shader:send("band_bend", M.BAND_BEND)
    plane.shader:send("refraction", M.REFRACTION)
    plane.shader:send("aspect_of_picture", plane.camera.aspect)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(plane.mesh)
    love.graphics.setShader()
end
-- }}}

return M

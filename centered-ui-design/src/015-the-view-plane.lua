-- 015-the-view-plane.lua - hanging the console in the world, in front of the camera.
--
-- In plain terms: the console's layers (face, dials, glass, band) are not
-- pasted onto the screen. They are laid on a flat sheet placed in the 3D
-- scene itself, a set distance in front of the map, between the camera and
-- the world — and the sheet is sized so that, at that distance and at the
-- camera's current zoom, it exactly fills the view. Every pixel of the
-- console's pictures lands on one screen pixel. The sheet hangs on the
-- camera: it does not turn with the chair.
--
-- The sheet's shader puts the layers together: where the face has metal, the
-- metal shows; where a window is cut, the glass bends the paper dial beneath
-- it a little outward toward the window's rim, tints it, and adds a curved
-- highlight; where the arch's band is, the map is painted on, as seen from
-- far beyond (024): each band pixel looks up its ally's quadrant at its own
-- place along the band (the angle) and across it (hub to farthest tier).
-- Outside the console the sheet is clear and the world shows.
--
-- Data flow:  camera settings + plane distance --> four corners in the world
--             (003, view_plane_corners) --> a four-cornered mesh --> projected
--             by the same far-camera arithmetic as the world (without the
--             chair's turn) --> screen

local far_camera = require("003-the-far-camera")

local M = {}

-- How far the glass bends what is beneath it, at a window's rim, as a share
-- of the picture's height.
M.REFRACTION = 0.004

local PLANE_VERTEX = far_camera.GLSL_FIXED .. [[
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    return project_fixed(vertex_position.xyz);
}
]]

local PLANE_PIXEL = [[
uniform Image dials;
uniform Image glass;
uniform Image band;
uniform Image beyond;
uniform float team_size;
uniform float refraction;
uniform float aspect_of_picture;
uniform vec2 picture_size;     // the console's pictures, pixels
uniform vec4 arch_shape;       // the arch: center x, base y, height, half width (pixels)
uniform float spin;            // how far the console is spun from the seat in front (-0.5..0.5 seats)

// Spinning along the curve (issue 302): the console is drawn once at home;
// each screen pixel finds its arch-shaped ring and its angle along it, the
// angle moved by the spin — half a turn of the curve per seat, so a seat
// slides down past one foot as the next rises over the other, the way the
// world's rings carry the land — and reads the console there. Returns the
// home uv and (z) which seat it falls in, counted from the seat in front.
// The Lua twin is unwarp in 014.
vec3 along_the_curve(vec2 uv) {
    vec2 p = uv * picture_size;
    float dx = p.x - arch_shape.x;
    float up = arch_shape.y - p.y;
    // below the base: no warp
    if (up <= 0.0) {
        return vec3(uv, 0.0);
    }
    float H = arch_shape.z;
    float half_width = arch_shape.w;
    float f = (up + sqrt(up * up + 4.0 * H * H * dx * dx / (half_width * half_width))) / (2.0 * H);
    float s = clamp(dx / (f * half_width), -1.0, 1.0);
    float turned = asin(s) + spin * 3.14159265;
    float seat = floor((turned + 1.57079633) / 3.14159265);
    float back = sin(turned - seat * 3.14159265);
    vec2 home = vec2(arch_shape.x + back * f * half_width, arch_shape.y - f * H * (1.0 - back * back));
    return vec3(home / picture_size, seat);
}

vec4 effect(vec4 color, Image face, vec2 screen_uv, vec2 screen) {
    vec3 carried = along_the_curve(screen_uv);
    vec2 uv = carried.xy;
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

    // The arch's band (glass alpha 0.5): the map, painted on from far beyond.
    // Along the band runs the ally's quadrant (left foot to right foot);
    // across it the distance from the hub (inner edge) to the farthest tier
    // (outer edge). Warmed toward the gold edges.
    float band_here = glass_here * (1.0 - step(0.75, bend.a));
    vec4 where = Texel(band, uv);
    // each seat's band shows its own quadrant: a neighbour come round the
    // curve shows the next quadrant along
    float angle = 6.2831853 * (where.b + (where.r + carried.z) / team_size);
    vec2 map_uv = vec2(0.5) + 0.5 * where.g * vec2(sin(angle), -cos(angle));
    vec3 painted = (Texel(beyond, map_uv).rgb * 1.9 + vec3(0.03, 0.035, 0.05))
                 * mix(vec3(1.0), vec3(1.0, 0.88, 0.62), rim * 0.5)
                 + vec3(highlight * 0.6);
    under_glass = mix(under_glass, painted, band_here);
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
-- Draws the sheet over the finished world. `beyond` is the map from beyond
-- (024's canvas), painted onto the arches' bands.
function M.draw(plane, flip_y, beyond)
    love.graphics.setDepthMode("always", false)
    love.graphics.setShader(plane.shader)
    far_camera.send(plane.camera, plane.shader, flip_y, true)
    plane.shader:send("dials", plane.dashboard.dials)
    plane.shader:send("glass", plane.dashboard.glass)
    plane.shader:send("band", plane.dashboard.band)
    plane.shader:send("beyond", beyond)
    plane.shader:send("team_size", plane.dashboard.team_size)
    plane.shader:send("refraction", M.REFRACTION)
    plane.shader:send("aspect_of_picture", plane.camera.aspect)
    local dashboard = plane.dashboard
    local section = dashboard.section
    plane.shader:send("picture_size", { dashboard.face:getWidth(), dashboard.face:getHeight() })
    plane.shader:send("arch_shape", { section.center_x, section.base_y, section.height, section.width / 2 })
    plane.shader:send("spin", dashboard.chair_offset - math.floor(dashboard.chair_offset + 0.5))
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(plane.mesh)
    love.graphics.setShader()
end
-- }}}

return M

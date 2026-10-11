-- 013-the-world-renderer.lua - the ground, the units and the cuboids, in 3D.
--
-- In plain terms: three things are drawn into the world picture. The ground
-- is the flat map (drawn by formula) laid on a disc whose rings follow the
-- sphere fold. The units are one figure mesh drawn once per unit, bent,
-- turned and placed by each unit's record read straight from shared memory.
-- The cuboids are one sphere pushed toward a cube, drawn once per cuboid.
--
-- Light (issue 213): nothing here has a light direction. Every surface looks
-- its light up on its material's light dial (metal, glaze or earth, painted by
-- 012) through a window, by which way it faces the viewer; the dials turn
-- with the time of day, so noon, dusk, night and dawn pass over everything.
-- Colours of one material are tints of its dial.
--
-- Depth (issue 214): under the hub camera, far things fade into a haze; and
-- figures may stand upright (the owner's choice) or, to compare, lean away
-- from the hub.
--
-- Data flow:  unit and cuboid blocks (shared memory) --(whole blocks, as
--             per-instance vertex data)--> instance meshes --> shaders: fold
--             the place onto the ground, bend and turn the figure, project
--             through the camera, look up the light --> world canvas (depth)
--
-- This is viewing code: it reads records and never writes them.

local far_camera = require("003-the-far-camera")
local sphere_fold = require("004-the-sphere-fold")
local terrain = require("026-the-terrain")
local records = require("005-unit-records")
local body_plan = require("018-the-body-plan")
local made_by_formula = require("012-made-by-formula")
local spheroid = require("011-the-spheroid")

local M = {}

-- The seats' paint colors (bright, saturated) and the foe's (dark,
-- desaturated), indexed by owner 0..4. Shared with the dashboard.
M.OWNER_COLORS = {
    { 1.00, 0.62, 0.12 },  -- seat 1, amber
    { 0.15, 0.78, 1.00 },  -- seat 2, cyan
    { 0.96, 0.26, 0.60 },  -- seat 3, magenta
    { 0.55, 0.95, 0.22 },  -- seat 4, lime
    { 0.42, 0.17, 0.15 },  -- foe, dark rust
}

-- How tall a unit is drawn, in world units, per unit of its record's size
-- (at tier 1; the fold shrinks it further out).
M.UNIT_WORLD_SCALE = 5.0

-- The ground speed (world units per second) at which a unit counts as walking
-- at full stride; slower, its limbs bend less.
M.FULL_PACE = 1.5

-- The light dials' window: how far its center sits from the dial's center,
-- and its radius (shares of the dial's radius), like a watch's date window.
M.WINDOW_CENTER = 0.52
M.WINDOW_RADIUS = 0.44

-- The haze far things fade into under the hub camera (also the sky's colour
-- there), and how far the outward lean tips a figure (radians).
M.HAZE_COLOR = { 0.40, 0.44, 0.50 }
M.OUTWARD_LEAN = 0.45

-- Shared by every world shader: the light dial lookup, the haze, the lean.
local LIGHT_GLSL = [[
uniform float hour_angle;      // the dials' turn: 0 noon, pi midnight
uniform float window_center;
uniform float window_radius;

// The light a surface receives: its material's dial, seen through the
// window at the spot its facing points to. Facing up looks toward the dial's
// bright rim; facing sideways looks at earlier or later hours.
vec3 dial_light(Image dial, vec2 facing) {
    vec2 p = vec2(0.0, window_center) + facing * window_radius;
    float c = cos(hour_angle);
    float s = sin(hour_angle);
    vec2 d = vec2(p.x * c + p.y * s, p.y * c - p.x * s);
    return Texel(dial, vec2(0.5 + 0.5 * d.x, 0.5 - 0.5 * d.y)).rgb;
}
]]

local HAZE_GLSL = [[
uniform vec3 haze_color;
// far things fade into the haze (only the hub camera has any distance)
vec3 hazed(vec3 lit, float haze) {
    return mix(lit, haze_color, smoothstep(0.30, 1.0, haze) * 0.9);
}
]]

local LEAN_GLSL = [[
uniform float lean_out;   // 0: upright; more: tipped away from the hub
// Tips a direction away from the hub, turning it about the ground's sideways
// line at `angle` (a rotation, so lengths and right angles are kept).
vec3 lean(vec3 v, float angle) {
    vec3 t = vec3(cos(angle), 0.0, sin(angle));
    float a = -lean_out;
    return v * cos(a) + cross(t, v) * sin(a) + t * dot(t, v) * (1.0 - cos(a));
}
]]

local GROUND_VERTEX = far_camera.GLSL .. sphere_fold.GLSL .. [[
varying vec2 v_facing;
varying float v_haze;

// The ground mesh, by its own unbroken angle (0 .. 2 pi round the mesh,
// never wrapped), so no ground piece can straddle a wrap and stretch across
// the screen; under the arch view in the copy `arch_winding`.
vec4 project_ground(float r, float mesh_angle) {
    vec3 ground = fold_ground_position(r, mesh_angle);
    if (arch_view < 0.5) {
        return project_unwarped(ground);
    }
    float from_chair = mesh_angle - mod(view_turn, 6.28318531) + 6.28318531 * arch_winding;
    float radius = length(ground.xz);
    vec4 spot = arch_spot(radius, from_chair);
    return arch_clip(spot.xy, (radius - arch_reach * 0.5) * cam_up.y / depth_half_range);
}

// The ground mesh stores each vertex as (tier distance, angle); the fold
// places it on the ground.
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    vec3 ground = fold_ground_position(vertex_position.x, vertex_position.y);
    v_facing = view_facing(vec3(0.0, 1.0, 0.0));
    v_haze = clamp(hub_distance(ground) / hub_far, 0.0, 1.0);
    return project_ground(vertex_position.x, vertex_position.y);
}
]]

local GROUND_PIXEL = LIGHT_GLSL .. HAZE_GLSL .. [[
uniform Image earth_dial;
varying vec2 v_facing;
varying float v_haze;
vec4 effect(vec4 color, Image map, vec2 uv, vec2 screen) {
    vec4 flat_map = Texel(map, uv);
    // a soft darkening toward the map's rim
    float from_center = length(uv - vec2(0.5)) * 2.0;
    float rim_shade = 1.0 - 0.35 * smoothstep(0.75, 1.0, from_center);
    // the ground is earth, the map's rings and tints drawn on it
    vec3 earth = vec3(0.26, 0.25, 0.18) + flat_map.rgb * 1.3;
    vec3 lit = earth * rim_shade * dial_light(earth_dial, v_facing) * 1.35;
    return vec4(hazed(lit, v_haze), 1.0);
}
]]

-- The terrain (issue 214): each of the land's points (026) drawn as one flat
-- circle facing the camera, shaded from a dark pole to a bright pole (012's
-- round shade), and only turned: about the line to the camera, by how
-- squarely the point's slope faces the sun (bright pole up: lit; down: in
-- shadow). No light is worked out on the circle's pixels. So many overlap
-- that each shows only its upper edge, and together they paint the land.
-- A circle's whole face takes its point's depth; drawn nearest first with a
-- strict depth test, a circle wholly covered is never painted.
M.DOT_SIZE = 5.2      -- ground units across

local DOT_VERTEX = far_camera.GLSL .. sphere_fold.GLSL .. [[
attribute vec4 SheenA;      // r, angle, height, lean (set by the engine when driven)
attribute vec4 SheenB;      // facing x, y, z; driven (1: the engine turns it)
attribute vec4 SheenC;      // sun-side colour r, g, b; wave phase
attribute vec4 SheenD;      // shade-side colour r, g, b; unused
uniform float dot_size;
uniform vec3 sun;           // toward the sun (026's sun_direction)
varying vec3 v_sun_color;
varying vec3 v_shade_color;
varying vec2 v_local;
varying vec2 v_turn;        // cos, sin of the circle's turn
varying float v_sun_side;   // 1: the sun on the screen's right; -1: left
varying float v_haze;
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    float r = SheenA.x;
    float angle = SheenA.y;
    float height = SheenA.z;
    vec2 local = vertex_position.xy;            // the circle's square, -1..1
    vec3 sideways = vec3(cos(angle), 0.0, sin(angle));
    float cos_e = cam_up.y;
    float half_size = 0.5 * dot_size;
    // facing the camera: across along the ring, up the screen
    vec3 spot = fold_ground_position(r, angle);
    vec3 offset = sideways * local.x * half_size + vec3(0.0, height + local.y * half_size / cos_e, 0.0);
    vec4 corner = project_anchored(spot, offset);
    vec4 middle = project_anchored(spot, vec3(0.0));
    // the whole circle at one depth: its point's distance from the centre
    // alone (measured on the ground, not counting its height), so a raised
    // circle never covers a nearer one in front of it
    corner.z = middle.z / middle.w * corner.w;
    // the turn: from sun-side-up by how far the surface faces away from the
    // sun — the engine's lean for a driven point (water, each step), else
    // worked out here from its facing (026's shade_turn) — leaning to the
    // sun's side of the screen
    float lean = SheenB.w > 0.5 ? SheenA.w : acos(clamp(dot(SheenB.xyz, sun), -1.0, 1.0));
    v_sun_side = view_facing(sun).x < 0.0 ? -1.0 : 1.0;
    float turn = v_sun_side * lean;
    v_turn = vec2(cos(turn), sin(turn));
    v_local = local;
    v_sun_color = SheenC.rgb;
    v_shade_color = SheenD.rgb;
    v_haze = clamp(hub_distance(spot + offset) / hub_far, 0.0, 1.0);
    return corner;
}
]]

local DOT_PIXEL = HAZE_GLSL .. [[
uniform Image round_shade;  // the circle (012)
uniform float circle_bars;  // 1: the bar-chart circle (to check the turn); 0: the shade
uniform float circle_open;  // 1: the bar chart's background clear; 0: opaque
varying vec3 v_sun_color;
varying vec3 v_shade_color;
varying vec2 v_local;
varying vec2 v_turn;
varying float v_sun_side;
varying float v_haze;
vec4 effect(vec4 color, Image t, vec2 uv, vec2 screen) {
    // look the circle up turned: its sun side leans by the turn
    vec2 p = vec2(v_local.x * v_turn.x - v_local.y * v_turn.y,
                  v_local.x * v_turn.y + v_local.y * v_turn.x);
    // outside the circle (cut exactly here, not from the picture's rim):
    // nothing
    if (dot(v_local, v_local) > 1.0) {
        discard;
    }
    vec3 lit;
    if (circle_bars > 0.5) {
        // the bar-chart circle: 24 bars round the centre, each reaching a
        // little farther than the last — none at the start, the rim at the
        // end (the sun side's place, up before the turn); winding clockwise
        // with the sun on the screen's right, counter-clockwise on its left
        float around = atan(p.x, p.y) / 6.28318531;      // 0 up, growing clockwise
        float share = fract(around * v_sun_side + 1.0);   // 0 .. 1 round the circle
        float bar = floor(share * 24.0);
        float reach = (bar + 1.0) / 24.0;
        bool on_bar = fract(share * 24.0) < 0.7 && length(p) <= reach;
        // between bars: the shade colour, or (open) nothing, showing behind
        if (!on_bar && circle_open > 0.5) {
            discard;
        }
        lit = on_bar ? v_sun_color : v_shade_color;
    } else {
        // the shade: from the shade-side colour to the sun-side colour round
        // the centre
        vec4 shade = Texel(round_shade, vec2(0.5 + 0.5 * p.x, 0.5 - 0.5 * p.y));
        lit = mix(v_shade_color, v_sun_color, shade.r);
    }
    return vec4(hazed(lit, v_haze), 1.0);
}
]]

local UNIT_VERTEX = far_camera.GLSL .. sphere_fold.GLSL .. body_plan.GLSL .. LEAN_GLSL .. [[
attribute vec4 UnitA;   // r, angle, heading, size
attribute vec4 UnitB;   // width (girth), owner, level, walking phase
attribute vec4 UnitC;   // speed_r, speed_angle, order_kind, named
attribute vec4 UnitD;   // job, target, wants, carrying (color + 1, or 0)
attribute float PartIndex;  // which part of the body plan this vertex belongs to

uniform vec3 owner_colors[5];
uniform float unit_world_scale;
uniform float full_pace;    // ground speed (world units / s) that counts as walking fully

varying vec2 v_facing;
varying vec3 v_color;
varying float v_named;
varying float v_haze;
varying float v_rim;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
    float r = UnitA.x;
    float angle = UnitA.y;
    // turned to its path on screen under the arch view (003)
    float heading = apparent_heading(fold_ground_position(UnitA.x, UnitA.y), UnitA.z);
    float height = UnitA.w * unit_world_scale * fold_size_scale(r);
    float girth = UnitB.x / UnitA.w / 0.53;
    float walk = UnitB.w;

    // how much the unit is walking: its ground speed, from the same
    // arithmetic the move box uses to face it, against a full pace
    float outward = fold_slope(r) * UnitC.x;
    float sideways = fold_radius(r) * UnitC.y;
    float moving = clamp(length(vec2(outward, sideways)) / full_pace, 0.0, 1.0);

    // bend this vertex's part by the body plan (018): limbs deform, not rotate
    vec3 local_normal;
    float carrying = step(0.5, UnitD.w);
    vec3 local_point = bend_part(int(PartIndex + 0.5), vertex_position.xyz, walk, moving, girth, carrying, local_normal);

    // the unit's own axes on the ground: forward along its heading; tipped
    // away from the hub when the outward lean is chosen (0 by default)
    vec3 forward = lean(vec3(sin(heading), 0.0, -cos(heading)), angle);
    vec3 right = lean(vec3(cos(heading), 0.0, sin(heading)), angle);
    vec3 up = lean(vec3(0.0, 1.0, 0.0), angle);

    // the figure's feet are at height 0 in the body plan: it stands on the ground
    vec3 world = fold_ground_position(r, angle)
               + (right * local_point.x + up * local_point.y + forward * local_point.z) * height;

    vec3 n = normalize(right * local_normal.x + up * local_normal.y + forward * local_normal.z);
    v_facing = view_facing(n);
    v_rim = 1.0 - length(v_facing);
    v_color = owner_colors[int(UnitB.y + 0.5)];
    v_named = UnitC.w;
    v_haze = clamp(hub_distance(world) / hub_far, 0.0, 1.0);
    // anchored at its feet: under the arch view the feet are placed on their
    // ring and the figure drawn upright there at one size
    vec3 feet = fold_ground_position(r, angle);
    return project_upright(feet, world - feet);
}
]]

local UNIT_PIXEL = LIGHT_GLSL .. HAZE_GLSL .. [[
uniform Image metal_dial;
uniform Image glaze_dial;
varying vec2 v_facing;
varying vec3 v_color;
varying float v_named;
varying float v_haze;
varying float v_rim;

vec4 effect(vec4 color, Image skin, vec2 uv, vec2 screen) {
    // the skin stores brightness (red) and where owner colour shows (green):
    // metal panels look up the metal dial; the band, the glaze dial, tinted
    vec4 texel = Texel(skin, uv);
    vec2 facing = clamp(v_facing, vec2(-1.0), vec2(1.0));
    vec3 metal = vec3(0.78, 0.80, 0.85) * texel.r * dial_light(metal_dial, facing) * 1.9;
    vec3 band = v_color * (0.6 + 0.5 * texel.r) * dial_light(glaze_dial, facing) * 1.6;
    vec3 lit = mix(metal, band, texel.g);
    // the named unit glows at its edges
    float edge = pow(max(1.0 - length(facing), 0.0), 0.5);
    lit += v_named * (vec3(1.0, 1.0, 0.8) * edge * 1.4 + vec3(0.22, 0.22, 0.18));
    return vec4(hazed(lit, v_haze), 1.0);
}
]]

-- How square the cuboids are: each coordinate of the unit sphere is raised to
-- this power (a superellipsoid). 1 is the sphere itself; toward 0, a cube.
-- 0.3 keeps the edges rounded — "cubes made of rounded spheres".
M.CUBOID_ROUNDNESS = 0.3

local CUBOID_VERTEX = far_camera.GLSL .. sphere_fold.GLSL .. LEAN_GLSL .. [[
attribute vec4 CubeA;   // r, angle, height, size
attribute vec4 CubeB;   // color, state, claimant, carrier
attribute vec4 CubeC;   // timer, slot, appearances, turn

uniform vec3 cuboid_colors[4];
uniform float roundness;

varying vec2 v_facing;
varying vec3 v_color;
varying float v_haze;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
    // the unit sphere pushed toward a cube: each coordinate raised to a small
    // power, keeping its sign (a superellipsoid)
    vec3 v = vertex_position.xyz;
    vec3 a = abs(v);
    vec3 shape = sign(v) * pow(a, vec3(roundness));
    // the surface |x|^(2/e) + |y|^(2/e) + |z|^(2/e) = 1 faces along
    // sign * |shape|^(2/e - 1), which is sign * a^(2 - e) at these points
    vec3 n = sign(v) * pow(a, vec3(2.0 - roundness));

    float size = CubeA.w * fold_size_scale(CubeA.x);
    float turn = apparent_heading(fold_ground_position(CubeA.x, CubeA.y), CubeC.w);
    vec3 forward = lean(vec3(sin(turn), 0.0, -cos(turn)), CubeA.y);
    vec3 right = lean(vec3(cos(turn), 0.0, sin(turn)), CubeA.y);
    vec3 up = lean(vec3(0.0, 1.0, 0.0), CubeA.y);
    vec3 half_edge = shape * size * 0.5;
    vec3 world = fold_ground_position(CubeA.x, CubeA.y)
               + up * (CubeA.z + size * 0.5)
               + right * half_edge.x + up * half_edge.y + forward * half_edge.z;
    v_facing = view_facing(normalize(right * n.x + up * n.y + forward * n.z));
    v_color = cuboid_colors[int(CubeB.x + 0.5)];
    v_haze = clamp(hub_distance(world) / hub_far, 0.0, 1.0);
    // anchored where it lies (see the unit shader)
    vec3 spot = fold_ground_position(CubeA.x, CubeA.y);
    return project_upright(spot, world - spot);
}
]]

local CUBOID_PIXEL = LIGHT_GLSL .. HAZE_GLSL .. [[
uniform Image glaze_dial;
varying vec2 v_facing;
varying vec3 v_color;
varying float v_haze;

// Glazed ceramic: its colour, tinting the glaze dial's light.
vec4 effect(vec4 color, Image t, vec2 uv, vec2 screen) {
    vec2 facing = clamp(v_facing, vec2(-1.0), vec2(1.0));
    vec3 lit = v_color * dial_light(glaze_dial, facing) * 1.6;
    return vec4(hazed(lit, v_haze), 1.0);
}
]]
-- {{{ local function build_ground_mesh()
-- A disc of `rings` x `segments`, each vertex holding (tier distance, angle)
-- as its position and its spot on the flat map as its texture coordinate.
local function build_ground_mesh(tiers_shown, rings, segments)
    local vertices = {}
    for ring = 0, rings do
        local r = tiers_shown * ring / rings
        for segment = 0, segments do
            local angle = 2 * math.pi * segment / segments
            local reach = r / tiers_shown
            vertices[#vertices + 1] = {
                r, angle,
                0.5 + 0.5 * reach * math.sin(angle),
                0.5 - 0.5 * reach * math.cos(angle),
            }
        end
    end
    local triangles = {}
    local row = segments + 1
    for ring = 0, rings - 1 do
        for segment = 0, segments - 1 do
            local a = ring * row + segment + 1
            local b = a + 1
            local c = a + row
            local d = c + 1
            triangles[#triangles + 1] = a
            triangles[#triangles + 1] = b
            triangles[#triangles + 1] = c
            triangles[#triangles + 1] = b
            triangles[#triangles + 1] = d
            triangles[#triangles + 1] = c
        end
    end
    local mesh = love.graphics.newMesh({
        { "VertexPosition", "float", 2 },
        { "VertexTexCoord", "float", 2 },
    }, vertices, "triangles", "static")
    mesh:setVertexMap(triangles)
    return mesh
end
-- }}}
-- {{{ function M.new()
-- Builds everything the world picture needs. `unit_count` and
-- `cuboid_count` size the per-unit and per-cuboid data meshes; `sections`
-- (from 007) are painted into the flat map.
function M.new(settings, camera, fold, unit_count, cuboid_count, sections)
    local renderer = {
        camera = camera,
        fold = fold,
        unit_count = unit_count,
        cuboid_count = cuboid_count,
    }

    renderer.ground_shader = love.graphics.newShader(GROUND_PIXEL, GROUND_VERTEX)
    renderer.dot_shader = love.graphics.newShader(DOT_PIXEL, DOT_VERTEX)
    -- the sprite: a square, the round relief cut from it in the shader
    renderer.dot_mesh = love.graphics.newMesh({ { "VertexPosition", "float", 2 } },
        { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }, "fan", "static")
    local shade = love.graphics.newImage(made_by_formula.round_shade(128))
    shade:setFilter("linear", "linear")
    renderer.dot_count = 0
    renderer.water_count = 0
    renderer.dot_shader:send("round_shade", shade)
    renderer.dot_shader:send("dot_size", M.DOT_SIZE)
    renderer.unit_shader = love.graphics.newShader(UNIT_PIXEL, UNIT_VERTEX)
    renderer.cuboid_shader = love.graphics.newShader(CUBOID_PIXEL, CUBOID_VERTEX)

    renderer.ground_mesh = build_ground_mesh(settings.tiers_shown, 96, 192)
    renderer.flat_map = made_by_formula.flat_map(2048, settings.tiers_shown, M.OWNER_COLORS, sections)
    renderer.flat_map:setFilter("linear", "linear", 8)
    renderer.ground_mesh:setTexture(renderer.flat_map)

    -- the figure: six unit spheres tagged by part, built once and never again
    local figure_vertices, figure_triangles = body_plan.figure_vertices(12, 16)
    renderer.unit_mesh = love.graphics.newMesh({
        { "VertexPosition", "float", 3 },
        { "VertexTexCoord", "float", 2 },
        { "PartIndex", "float", 1 },
    }, figure_vertices, "triangles", "static")
    renderer.unit_mesh:setVertexMap(figure_triangles)
    local skin = love.graphics.newImage(made_by_formula.unit_skin(512, 256), { mipmaps = true })
    skin:setFilter("linear", "linear", 8)
    skin:setMipmapFilter("linear")
    skin:setWrap("repeat", "clamp")
    renderer.unit_mesh:setTexture(skin)

    -- the per-unit data: one "vertex" per unit, in the record's own layout
    renderer.instance_mesh = love.graphics.newMesh(records.VERTEX_FORMAT, unit_count, "points", "stream")
    for _, group in ipairs({ "UnitA", "UnitB", "UnitC", "UnitD" }) do
        renderer.unit_mesh:attachAttribute(group, renderer.instance_mesh, "perinstance")
    end

    -- the cuboid: one unit sphere, pushed toward a cube in the shader
    local cube_vertices, cube_triangles = spheroid.build(14, 20)
    renderer.cuboid_mesh = love.graphics.newMesh({
        { "VertexPosition", "float", 3 },
        { "VertexTexCoord", "float", 2 },
    }, cube_vertices, "triangles", "static")
    renderer.cuboid_mesh:setVertexMap(cube_triangles)
    renderer.cuboid_instances = love.graphics.newMesh(records.CUBOID_VERTEX_FORMAT, cuboid_count, "points", "stream")
    for _, group in ipairs({ "CubeA", "CubeB", "CubeC" }) do
        renderer.cuboid_mesh:attachAttribute(group, renderer.cuboid_instances, "perinstance")
    end
    renderer.unit_shader:send("owner_colors", unpack(M.OWNER_COLORS))
    renderer.unit_shader:send("unit_world_scale", M.UNIT_WORLD_SCALE)
    renderer.unit_shader:send("full_pace", M.FULL_PACE)
    body_plan.send(renderer.unit_shader)
    renderer.cuboid_shader:send("cuboid_colors", M.OWNER_COLORS[1], M.OWNER_COLORS[2],
        M.OWNER_COLORS[3], M.OWNER_COLORS[4])
    renderer.cuboid_shader:send("roundness", M.CUBOID_ROUNDNESS)

    -- the light dials, painted once (013's lighting; issue 213)
    renderer.dials = {}
    for _, material in ipairs({ "metal", "glaze", "earth" }) do
        local dial = love.graphics.newImage(made_by_formula.light_dial(512, material))
        dial:setFilter("linear", "linear")
        dial:setWrap("clamp", "clamp")
        renderer.dials[material] = dial
    end
    renderer.ground_shader:send("earth_dial", renderer.dials.earth)
    renderer.unit_shader:send("metal_dial", renderer.dials.metal)
    renderer.unit_shader:send("glaze_dial", renderer.dials.glaze)
    renderer.cuboid_shader:send("glaze_dial", renderer.dials.glaze)
    for _, shader in ipairs({ renderer.ground_shader, renderer.dot_shader, renderer.unit_shader,
            renderer.cuboid_shader }) do
        -- the terrain's circles use no light dial (only haze): each value
        -- goes only to the shaders that use it
        far_camera.send_used(shader, "window_center", M.WINDOW_CENTER)
        far_camera.send_used(shader, "window_radius", M.WINDOW_RADIUS)
        far_camera.send_used(shader, "haze_color", M.HAZE_COLOR)
    end
    return renderer
end
-- }}}

-- {{{ function M.set_terrain()
-- Hands the renderer the still land's sheen-points (the first list from
-- 026's build) and how many moving ones there are (their records stream
-- from the engine's blocks each frame). The land is put in order from near
-- to far once: drawn so with a strict depth test, a circle wholly covered
-- by nearer ones is rejected without being painted (and where two at one
-- depth overlap, the one drawn first — the nearer — stays). Turning the
-- chair keeps every point's distance from the hub, so the order holds.
function M.set_terrain(renderer, points, moving_count)
    renderer.dot_count = #points
    renderer.water_count = moving_count
    -- moving sheen-points: a stream the engine's front block is copied into
    if moving_count > 0 then
        renderer.water_instances = love.graphics.newMesh(records.SHEEN_VERTEX_FORMAT, moving_count, "points", "stream")
        renderer.water_mesh = love.graphics.newMesh({ { "VertexPosition", "float", 2 } },
            { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }, "fan", "static")
        for _, group in ipairs({ "SheenA", "SheenB", "SheenC", "SheenD" }) do
            renderer.water_mesh:attachAttribute(group, renderer.water_instances, "perinstance")
        end
    end
    -- no land: nothing more
    if #points == 0 then
        return
    end
    local ordered = {}
    for index, point in ipairs(points) do
        ordered[index] = point
    end
    table.sort(ordered, function(a, b) return a.r < b.r end)
    local vertices = {}
    for index, point in ipairs(ordered) do
        vertices[index] = { point.r, point.angle, point.height, 0,
            point.facing[1], point.facing[2], point.facing[3], 0,
            point.sun_color[1], point.sun_color[2], point.sun_color[3], point.wave_phase,
            point.shade_color[1], point.shade_color[2], point.shade_color[3], 0 }
    end
    renderer.dot_instances = love.graphics.newMesh(records.SHEEN_VERTEX_FORMAT, vertices, "points", "static")
    for _, group in ipairs({ "SheenA", "SheenB", "SheenC", "SheenD" }) do
        renderer.dot_mesh:attachAttribute(group, renderer.dot_instances, "perinstance")
    end
end
-- }}}

-- {{{ local function send_frame()
-- What changes frame to frame: the camera, the fold, the hour, the lean.
local function send_frame(renderer, shader, flip_y, look)
    far_camera.send(renderer.camera, shader, flip_y)
    sphere_fold.send(renderer.fold, shader)
    far_camera.send_used(shader, "hour_angle", look.hour_angle)
    far_camera.send_used(shader, "lean_out", look.standing == "outward" and M.OUTWARD_LEAN or 0)
end
-- }}}

-- {{{ function M.draw()
-- Draws the ground, the units and the cuboids into whatever canvas is set
-- (it must have a depth buffer). The two front blocks (byte data) are handed
-- to the graphics card whole. `look` carries hour_angle (radians, the light
-- dials' turn: 0 noon) and standing ("upright" or "outward").
function M.draw(renderer, front_units, front_cuboids, flip_y, look, front_sheens)
    renderer.instance_mesh:setVertices(front_units)
    renderer.cuboid_instances:setVertices(front_cuboids)
    -- the moving sheen-points, as the engine left them
    if renderer.water_count > 0 then
        renderer.water_instances:setVertices(front_sheens)
    end

    love.graphics.setDepthMode("lequal", true)
    love.graphics.setMeshCullMode("none")

    -- the arch view draws the world once per winding, so a span past a
    -- full turn shows the same ground at both ends (a magic circle); every
    -- other view draws it once
    local windings = { 0 }
    if renderer.camera.view == "arch" then
        windings = far_camera.arch_windings(renderer.camera)
    end
    -- first the land, every winding: the painted map, or the land's lit
    -- points on an empty canvas (the owner: "we don't draw a texture onto
    -- the ground. It's just a completely empty canvas with invisible
    -- points. Then, we add our stuff.")
    local sun_x, sun_y, sun_z = terrain.sun_direction(look.hour_angle)
    for _, winding in ipairs(windings) do
        renderer.camera.arch_winding = winding
        -- the painted map
        if look.ground == "map" then
            love.graphics.setShader(renderer.ground_shader)
            send_frame(renderer, renderer.ground_shader, flip_y, look)
            love.graphics.draw(renderer.ground_mesh)
        -- the land's points, if there are any
        elseif renderer.dot_count > 0 then
            love.graphics.setDepthMode("less", true)
            love.graphics.setShader(renderer.dot_shader)
            send_frame(renderer, renderer.dot_shader, flip_y, look)
            renderer.dot_shader:send("sun", { sun_x, sun_y, sun_z })
            renderer.dot_shader:send("circle_bars", look.circle ~= "shade" and 1 or 0)
            renderer.dot_shader:send("circle_open", look.circle == "bars-open" and 1 or 0)
            love.graphics.drawInstanced(renderer.dot_mesh, renderer.dot_count)
            -- the moving surfaces, turned by the engine
            if renderer.water_count > 0 then
                love.graphics.drawInstanced(renderer.water_mesh, renderer.water_count)
            end
            love.graphics.setDepthMode("lequal", true)
        end
    end
    -- then everything standing on it
    for _, winding in ipairs(windings) do
        renderer.camera.arch_winding = winding

        love.graphics.setShader(renderer.unit_shader)
        send_frame(renderer, renderer.unit_shader, flip_y, look)
        love.graphics.drawInstanced(renderer.unit_mesh, renderer.unit_count)

        love.graphics.setShader(renderer.cuboid_shader)
        send_frame(renderer, renderer.cuboid_shader, flip_y, look)
        love.graphics.drawInstanced(renderer.cuboid_mesh, renderer.cuboid_count)
    end
    renderer.camera.arch_winding = 0

    love.graphics.setShader()
end
-- }}}

return M

-- 013-the-world-renderer.lua - the ground and the units, in 3D.
--
-- In plain terms: two things are drawn into the world picture. The ground is
-- the flat map (drawn by formula) laid on a disc whose rings follow the
-- sphere fold, so the evenly spaced tier rings come out folded toward the
-- edge. The units are one spheroid drawn once per unit, each stretched, turned
-- and placed by its own record read straight from shared memory, and lit with
-- a polished-metal highlight.
--
-- Data flow:  unit block (shared memory) --(whole block, as per-unit vertex
--             data)--> instance mesh --> unit shader: fold the place onto the
--             ground, stretch and turn the spheroid, project through the far
--             camera --> world canvas (with depth)
--
-- This is viewing code: it reads records and never writes them.

local far_camera = require("003-the-far-camera")
local sphere_fold = require("004-the-sphere-fold")
local records = require("005-unit-records")
local body_plan = require("018-the-body-plan")
local made_by_formula = require("012-made-by-formula")

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

local GROUND_VERTEX = far_camera.GLSL .. sphere_fold.GLSL .. [[
// The ground mesh stores each vertex as (tier distance, angle); the fold
// places it on the ground.
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    vec3 ground = fold_ground_position(vertex_position.x, vertex_position.y);
    return project_world(ground);
}
]]

local GROUND_PIXEL = [[
vec4 effect(vec4 color, Image map, vec2 uv, vec2 screen) {
    vec4 flat_map = Texel(map, uv);
    // a soft darkening toward the map's rim
    float from_center = length(uv - vec2(0.5)) * 2.0;
    float rim_shade = 1.0 - 0.35 * smoothstep(0.75, 1.0, from_center);
    return vec4(flat_map.rgb * rim_shade, 1.0);
}
]]

local UNIT_VERTEX = far_camera.GLSL .. sphere_fold.GLSL .. body_plan.GLSL .. [[
attribute vec4 UnitA;   // r, angle, heading, size
attribute vec4 UnitB;   // width (girth), owner, level, walking phase
attribute vec4 UnitC;   // speed_r, speed_angle, order_kind, named
attribute float PartIndex;  // which part of the body plan this vertex belongs to

uniform vec3 owner_colors[5];
uniform float unit_world_scale;
uniform float full_pace;    // ground speed (world units / s) that counts as walking fully

varying vec3 v_normal;
varying vec3 v_color;
varying float v_named;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
    float r = UnitA.x;
    float angle = UnitA.y;
    float heading = UnitA.z;
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
    vec3 local_point = bend_part(int(PartIndex + 0.5), vertex_position.xyz, walk, moving, girth, local_normal);

    // the unit's own axes on the ground: forward along its heading
    vec3 forward = vec3(sin(heading), 0.0, -cos(heading));
    vec3 right = vec3(cos(heading), 0.0, sin(heading));
    vec3 up = vec3(0.0, 1.0, 0.0);

    // the figure's feet are at height 0 in the body plan: it stands on the ground
    vec3 world = fold_ground_position(r, angle)
               + (right * local_point.x + up * local_point.y + forward * local_point.z) * height;

    v_normal = right * local_normal.x + up * local_normal.y + forward * local_normal.z;
    v_color = owner_colors[int(UnitB.y + 0.5)];
    v_named = UnitC.w;
    return project_world(world);
}
]]

local UNIT_PIXEL = [[
uniform vec3 cam_back;
varying vec3 v_normal;
varying vec3 v_color;
varying float v_named;

vec4 effect(vec4 color, Image skin, vec2 uv, vec2 screen) {
    // the skin stores brightness (red) and how much owner color shows (green)
    vec4 texel = Texel(skin, uv);
    vec3 n = normalize(v_normal);
    vec3 to_light = normalize(vec3(-0.45, 0.8, 0.4));
    vec3 to_eye = normalize(cam_back);
    vec3 halfway = normalize(to_light + to_eye);

    float diffuse = max(dot(n, to_light), 0.0);
    // Blinn-Phong: a tight highlight where the surface faces halfway between
    // the light and the eye — the polished-metal glint
    float specular = pow(max(dot(n, halfway), 0.0), 48.0);

    vec3 metal = vec3(0.62, 0.66, 0.72) * texel.r;
    vec3 body = mix(metal, v_color * (0.55 + 0.6 * texel.r), texel.g);
    vec3 lit = body * (0.28 + 0.85 * diffuse)
             + specular * vec3(1.0, 0.97, 0.92) * (0.55 + 0.45 * texel.r);

    // a cool rim of light on every unit; a bright one on the named unit
    float rim = pow(1.0 - max(dot(n, to_eye), 0.0), 2.5);
    lit += rim * (0.12 * vec3(0.6, 0.75, 0.9) + v_named * vec3(1.0, 1.0, 0.8) * 2.2)
         + v_named * vec3(0.25, 0.25, 0.2);
    return vec4(lit, 1.0);
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
-- Builds everything the world picture needs. `unit_count` sizes the
-- per-unit data mesh.
function M.new(settings, camera, fold, unit_count)
    local renderer = {
        camera = camera,
        fold = fold,
        unit_count = unit_count,
    }

    renderer.ground_shader = love.graphics.newShader(GROUND_PIXEL, GROUND_VERTEX)
    renderer.unit_shader = love.graphics.newShader(UNIT_PIXEL, UNIT_VERTEX)

    renderer.ground_mesh = build_ground_mesh(settings.tiers_shown, 96, 192)
    renderer.flat_map = made_by_formula.flat_map(2048, settings.tiers_shown, M.OWNER_COLORS)
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
    renderer.unit_mesh:attachAttribute("UnitA", renderer.instance_mesh, "perinstance")
    renderer.unit_mesh:attachAttribute("UnitB", renderer.instance_mesh, "perinstance")
    renderer.unit_mesh:attachAttribute("UnitC", renderer.instance_mesh, "perinstance")

    renderer.unit_shader:send("owner_colors", unpack(M.OWNER_COLORS))
    renderer.unit_shader:send("unit_world_scale", M.UNIT_WORLD_SCALE)
    renderer.unit_shader:send("full_pace", M.FULL_PACE)
    body_plan.send(renderer.unit_shader)
    return renderer
end
-- }}}

-- {{{ function M.draw()
-- Draws the ground and the units into whatever canvas is set (it must have
-- a depth buffer). `front_block` is the byte data of the current front unit
-- block; it is handed to the graphics card whole.
function M.draw(renderer, front_block, flip_y)
    renderer.instance_mesh:setVertices(front_block)

    love.graphics.setDepthMode("lequal", true)
    love.graphics.setMeshCullMode("none")

    love.graphics.setShader(renderer.ground_shader)
    far_camera.send(renderer.camera, renderer.ground_shader, flip_y)
    sphere_fold.send(renderer.fold, renderer.ground_shader)
    love.graphics.draw(renderer.ground_mesh)

    love.graphics.setShader(renderer.unit_shader)
    far_camera.send(renderer.camera, renderer.unit_shader, flip_y)
    sphere_fold.send(renderer.fold, renderer.unit_shader)
    love.graphics.drawInstanced(renderer.unit_mesh, renderer.unit_count)

    love.graphics.setShader()
end
-- }}}

return M

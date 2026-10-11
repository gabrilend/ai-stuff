-- 018-the-body-plan.lua - what a unit's body is made of, and how its limbs bend.
--
-- In plain terms: a unit is a small figure of six spheroids — a body, a head,
-- two arms, two legs. One mesh holds all six, built once at start, each part
-- tagged with its number. This file's table (the body plan) says where each
-- part sits and how big it is, in multiples of the figure's height, and how
-- it moves.
--
-- Limbs do not swing as rigid pieces around a joint. A limb is BENT: every
-- point on it is pushed forward (or back) and lifted by an amount that grows
-- with the square of its distance from where the limb attaches. The shoulder
-- or hip stays where it is; the hand or foot travels furthest, along a curve.
--
--   s       = how far along the limb a point is: 0 at the attachment, 1 at the tip
--   swing   = sin(walking phase + the part's offset)
--   forward = stride * swing * s^2 * limb length
--   up      = lift * max(swing, 0) * s^2 * limb length
--
-- The mesh never changes. Each unit's walking phase lives in its record and is
-- advanced by the move box (006) from how fast it is going; the shader reads
-- the phase and bends the limbs. Updating the formula's input, not rebuilding
-- the shape, is what makes them walk.
--
-- The surface's facing follows the bend: pushing points forward by f(y) is a
-- shear, and a shear turns a surface's facing by its slope, f'(y) — the shader
-- corrects each normal by exactly that (see M.bend_normal).
--
-- The numbers below are tuning knobs: record changes in docs/balance-updates.md.

local spheroid = require("011-the-spheroid")

local M = {}

-- x = to the figure's right, y = up, z = forward; height of the figure = 1.
-- stride: forward bend at the tip, in limb lengths, at full walking pace
-- lift:   upward bend at the tip during the forward half of the swing
-- offset: where in the walking cycle the part swings (radians)
-- idle:   how much of the swing remains when standing still (a sway)
-- bob:    how much the part rises and falls with each step
-- holds:  1 if the part takes the holding pose when the unit carries a cuboid
M.PARTS = {
    { name = "body",      center = { 0, 0.56, 0 },     radii = { 0.16, 0.20, 0.11 },
      stride = 0,    lift = 0,    offset = 0,       idle = 0,    bob = 1, holds = 0 },
    { name = "head",      center = { 0, 0.86, 0.01 },  radii = { 0.085, 0.095, 0.085 },
      stride = 0,    lift = 0,    offset = 0,       idle = 0,    bob = 1, holds = 0 },
    { name = "left arm",  center = { -0.21, 0.53, 0 }, radii = { 0.045, 0.17, 0.045 },
      stride = 0.55, lift = 0.12, offset = 0,       idle = 0.08, bob = 1, holds = 1 },
    { name = "right arm", center = { 0.21, 0.53, 0 },  radii = { 0.045, 0.17, 0.045 },
      stride = 0.55, lift = 0.12, offset = math.pi, idle = 0.08, bob = 1, holds = 1 },
    { name = "left leg",  center = { -0.08, 0.19, 0 }, radii = { 0.06, 0.19, 0.06 },
      stride = 0.60, lift = 0.35, offset = math.pi, idle = 0,    bob = 0, holds = 0 },
    { name = "right leg", center = { 0.08, 0.19, 0 },  radii = { 0.06, 0.19, 0.06 },
      stride = 0.60, lift = 0.35, offset = 0,       idle = 0,    bob = 0, holds = 0 },
}
-- Each arm swings opposite the leg on its own side (left arm offset 0, left
-- leg offset pi), the way people walk.

-- How high a step's bob lifts the upper body, in figure heights.
M.BOB_HEIGHT = 0.025

-- The holding pose: when a unit carries a cuboid, each part marked `holds`
-- (the arms) bends forward and up by these amounts instead of swinging,
-- bringing the hands out in front of the chest. The lift stays under 0.5 so
-- the bend never folds the limb back over itself (see the shear note above:
-- 1 + g' must stay positive, and g' reaches -2 x lift at the hand).
M.HOLD_FORWARD = 0.95
M.HOLD_LIFT = 0.45

-- {{{ function M.figure_vertices()
-- The figure mesh: six unit spheres, each vertex {x, y, z, u, v, part}.
-- spheroid.build makes its long axis z; here each sphere is turned so its
-- poles are up and down (y), so a limb's texture runs from shoulder to hand.
function M.figure_vertices(rings, segments)
    local sphere_vertices, sphere_triangles = spheroid.build(rings, segments)
    local vertices, triangles = {}, {}
    for part_index = 1, #M.PARTS do
        local first = #vertices
        for _, vertex in ipairs(sphere_vertices) do
            -- (x, y, z) of the sphere becomes (x, z, y): poles up and down
            vertices[#vertices + 1] = { vertex[1], vertex[3], vertex[2], vertex[4], vertex[5], part_index - 1 }
        end
        for _, index in ipairs(sphere_triangles) do
            triangles[#triangles + 1] = first + index
        end
    end
    return vertices, triangles
end
-- }}}

-- {{{ function M.bend()
-- The Lua twin of the shader's bend, for tests. Takes a part (from M.PARTS),
-- a point on the unit sphere (x, y, z with y the pole), the walking phase
-- how much the unit is moving (0..1), and whether it carries (0 or 1).
-- Returns the bent point in figure
-- heights.
function M.bend(part, x, y, z, walking_phase, moving, carrying)
    local amount = part.idle + (1 - part.idle) * moving
    local swing = math.sin(walking_phase + part.offset)
    local s = (1 - y) * 0.5
    local length = 2 * part.radii[2]
    local holding = (carrying or 0) * part.holds
    local forward = part.stride * swing * amount
    forward = forward + (M.HOLD_FORWARD - forward) * holding
    local up = part.lift * math.max(swing, 0) * amount
    up = up + (M.HOLD_LIFT - up) * holding
    local px = part.center[1] + x * part.radii[1]
    local py = part.center[2] + y * part.radii[2] + up * s * s * length
    local pz = part.center[3] + z * part.radii[3] + forward * s * s * length
    return px, py, pz
end
-- }}}

-- {{{ function M.send()
-- Hands the body plan to a shader as four small arrays indexed by part.
function M.send(shader)
    local centers, radii, motions, bobs, holds = {}, {}, {}, {}, {}
    for index, part in ipairs(M.PARTS) do
        centers[index] = part.center
        radii[index] = part.radii
        motions[index] = { part.stride, part.lift, part.offset, part.idle }
        bobs[index] = part.bob
        holds[index] = part.holds
    end
    shader:send("part_center", unpack(centers))
    shader:send("part_radii", unpack(radii))
    shader:send("part_motion", unpack(motions))
    shader:send("part_bob", unpack(bobs))
    shader:send("part_holds", unpack(holds))
    shader:send("hold_forward", M.HOLD_FORWARD)
    shader:send("hold_lift", M.HOLD_LIFT)
    shader:send("bob_height", M.BOB_HEIGHT)
end
-- }}}

-- The shader twin of M.bend, plus the normal correction. `v` is the unit
-- sphere point, `walk` the phase, `moving` 0..1, `girth` widens x and z.
M.GLSL = [[
uniform vec3 part_center[6];
uniform vec3 part_radii[6];
uniform vec4 part_motion[6];   // stride, lift, offset, idle
uniform float part_bob[6];
uniform float part_holds[6];
uniform float hold_forward;
uniform float hold_lift;
uniform float bob_height;

// Bends one part of the figure. Returns the point (figure heights) and,
// through `normal`, its surface facing after the bend.
vec3 bend_part(int p, vec3 v, float walk, float moving, float girth, float carrying, out vec3 normal) {
    vec3 radii = part_radii[p] * vec3(girth, 1.0, girth);
    vec4 motion = part_motion[p];
    float amount = mix(motion.w, 1.0, moving);
    float swing = sin(walk + motion.z);
    float s = (1.0 - v.y) * 0.5;
    float len = 2.0 * radii.y;
    float holding = carrying * part_holds[p];
    float forward = mix(motion.x * swing * amount, hold_forward, holding);
    float up = mix(motion.y * max(swing, 0.0) * amount, hold_lift, holding);

    vec3 point = part_center[p] + v * radii;
    point.z += forward * s * s * len;
    point.y += up * s * s * len;
    point.y += part_bob[p] * bob_height * abs(sin(walk)) * moving;

    // The bend is a shear: z moves by f(y), y by g(y). Its slopes, per unit
    // of height: f' = -2 * forward * s, g' = -2 * up * s. A surface's facing
    // under that shear is (nx, (ny - f' nz) / (1 + g'), nz).
    vec3 n = v / radii;
    float f_slope = -2.0 * forward * s;
    float g_slope = -2.0 * up * s;
    normal = vec3(n.x, (n.y - f_slope * n.z) / (1.0 + g_slope), n.z);
    return point;
}
]]

return M

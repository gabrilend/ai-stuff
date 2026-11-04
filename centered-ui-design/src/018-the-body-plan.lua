-- 018-the-body-plan.lua - what a unit's body is made of, and how its limbs bend.
--
-- In plain terms: a unit is a small figure of six spheroids — a body, a head,
-- two arms, two legs. One mesh holds all six, built once at start, each part
-- tagged with its number. This file's table (the body plan) says where each
-- part sits and how big it is, in multiples of the figure's height, and how
-- it moves.
--
-- Limbs bend at a joint halfway down (issue 210: "bend at the elbow
-- instead of curving ... the knee should only go forward"). Each limb is
-- still one spheroid; its upper half turns rigidly about the shoulder or hip
-- by the swing angle, and its lower half turns about the elbow or knee —
-- carried along by the upper half — by the swing angle plus the joint's
-- bend. Points exactly at the joint move the same either way, so the limb
-- never tears.
--
--   swing  = sin(walking phase + the part's offset)
--   upper  = swing angle x swing                (forward positive)
--   joint  = elbow: rest + bend x max(swing, 0), forward (+)
--            knee:  bend x max(cos(phase + offset), 0), back (-): the
--                   knee points forward and the shin folds back, most
--                   while the leg swings forward (cos > 0), straight as
--                   the foot plants
--
-- (They once curved: every point pushed forward by the square of its
-- distance along the limb.) The mesh never changes; the walking phase in
-- each unit's record drives the bend (006 advances it). Facings turn with
-- each half — a rotation, so no correction is needed.
--
-- The numbers below are tuning knobs: record changes in docs/balance-updates.md.

local spheroid = require("011-the-spheroid")

local M = {}

-- x = to the figure's right, y = up, z = forward; height of the figure = 1.
-- swing:  how far the limb swings from its shoulder or hip, radians, at
--         full walking pace
-- bend:   how far its elbow or knee bends at most, radians
-- rest:   the elbow's or knee's bend when still, radians
-- joint:  +1 the lower half folds forward (an elbow), -1 back (a knee, its
--         point forward), 0 no joint
-- offset: where in the walking cycle the part swings (radians)
-- idle:   how much of the swing remains when standing still (a sway)
-- bob:    how much the part rises and falls with each step
-- holds:  1 if the part takes the holding pose when the unit carries a cuboid
M.PARTS = {
    { name = "body",      center = { 0, 0.56, 0 },     radii = { 0.16, 0.20, 0.11 },
      swing = 0,    bend = 0,    rest = 0,    joint = 0,  offset = 0,       idle = 0,    bob = 1, holds = 0 },
    { name = "head",      center = { 0, 0.86, 0.01 },  radii = { 0.085, 0.095, 0.085 },
      swing = 0,    bend = 0,    rest = 0,    joint = 0,  offset = 0,       idle = 0,    bob = 1, holds = 0 },
    { name = "left arm",  center = { -0.21, 0.53, 0 }, radii = { 0.045, 0.17, 0.045 },
      swing = 0.50, bend = 0.55, rest = 0.30, joint = 1,  offset = 0,       idle = 0.08, bob = 1, holds = 1 },
    { name = "right arm", center = { 0.21, 0.53, 0 },  radii = { 0.045, 0.17, 0.045 },
      swing = 0.50, bend = 0.55, rest = 0.30, joint = 1,  offset = math.pi, idle = 0.08, bob = 1, holds = 1 },
    { name = "left leg",  center = { -0.08, 0.19, 0 }, radii = { 0.06, 0.19, 0.06 },
      swing = 0.45, bend = 0.95, rest = 0.05, joint = -1, offset = math.pi, idle = 0,    bob = 0, holds = 0 },
    { name = "right leg", center = { 0.08, 0.19, 0 },  radii = { 0.06, 0.19, 0.06 },
      swing = 0.45, bend = 0.95, rest = 0.05, joint = -1, offset = 0,       idle = 0,    bob = 0, holds = 0 },
}
-- Each arm swings opposite the leg on its own side (left arm offset 0, left
-- leg offset pi), the way people walk.

-- How high a step's bob lifts the upper body, in figure heights.
M.BOB_HEIGHT = 0.025

-- The holding pose: when a unit carries a cuboid, each part marked `holds`
-- (the arms) takes these angles instead of swinging — upper arms a little
-- forward, forearms bent up in front of the chest (radians).
M.HOLD_FORWARD = 0.45
M.HOLD_LIFT = 1.25

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

-- {{{ local function turned()
-- Turns (y, z) by an angle about the figure's sideways line: positive
-- swings a downward limb forward.
local function turned(y, z, angle)
    local c, s = math.cos(angle), math.sin(angle)
    return y * c + z * s, -y * s + z * c
end
-- }}}

-- {{{ function M.joint_angles()
-- A limb's two angles at a walking phase: the upper half's swing from the
-- shoulder or hip, and the lower half's total angle (upper plus the joint's
-- bend), radians, forward positive. The Lua twin of the shader's.
function M.joint_angles(part, walking_phase, moving, carrying)
    local amount = part.idle + (1 - part.idle) * moving
    local swing = math.sin(walking_phase + part.offset)
    local upper = part.swing * swing * amount
    local joint
    -- an elbow folds forward, more as the arm swings forward
    if part.joint > 0 then
        joint = part.rest + part.bend * math.max(swing, 0) * amount
    -- a knee folds back (its point forward), most while the leg swings
    -- forward, straight as the foot plants
    elseif part.joint < 0 then
        joint = -(part.rest + part.bend * math.max(math.cos(walking_phase + part.offset), 0) * amount)
    -- no joint: one rigid piece
    else
        joint = 0
    end
    local holding = (carrying or 0) * part.holds
    upper = upper + (M.HOLD_FORWARD - upper) * holding
    joint = joint + (M.HOLD_LIFT - joint) * holding
    return upper, upper + joint
end
-- }}}

-- {{{ function M.bend()
-- The Lua twin of the shader's bend, for tests. Takes a part (from M.PARTS),
-- a point on the unit sphere (x, y, z with y the pole), the walking phase,
-- how much the unit is moving (0..1), and whether it carries (0 or 1).
-- Returns the bent point in figure heights (bob left out).
function M.bend(part, x, y, z, walking_phase, moving, carrying)
    local upper, lower = M.joint_angles(part, walking_phase, moving, carrying)
    local length = 2 * part.radii[2]
    -- relative to the limb's top (shoulder or hip)
    local py, pz = y * part.radii[2] - part.radii[2], z * part.radii[3]
    local s = (1 - y) * 0.5
    local ry, rz
    -- the upper half turns about the top
    if s < 0.5 then
        ry, rz = turned(py, pz, upper)
    -- the lower half turns about the joint, which the upper half carries
    else
        local jy, jz = turned(-length / 2, 0, upper)
        local qy, qz = turned(py + length / 2, pz, lower)
        ry, rz = jy + qy, jz + qz
    end
    return part.center[1] + x * part.radii[1], part.center[2] + part.radii[2] + ry, part.center[3] + rz
end
-- }}}

-- {{{ function M.send()
-- Hands the body plan to a shader as four small arrays indexed by part.
function M.send(shader)
    local centers, radii, motions, bobs, holds, joints = {}, {}, {}, {}, {}, {}
    for index, part in ipairs(M.PARTS) do
        centers[index] = part.center
        radii[index] = part.radii
        motions[index] = { part.swing, part.bend, part.offset, part.idle }
        joints[index] = { part.rest, part.joint }
        bobs[index] = part.bob
        holds[index] = part.holds
    end
    shader:send("part_center", unpack(centers))
    shader:send("part_radii", unpack(radii))
    shader:send("part_motion", unpack(motions))
    shader:send("part_bob", unpack(bobs))
    shader:send("part_holds", unpack(holds))
    shader:send("part_joint", unpack(joints))
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
uniform vec2 part_joint[6];    // rest bend, +1 elbow / -1 knee / 0 none
uniform float hold_forward;
uniform float hold_lift;
uniform float bob_height;

// Turns (y, z) by an angle about the figure's sideways line: positive swings
// a downward limb forward.
vec2 turned(vec2 yz, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return vec2(yz.x * c + yz.y * s, -yz.x * s + yz.y * c);
}

// Bends one part of the figure at its joint (twin of M.bend and
// M.joint_angles). Returns the point (figure heights) and, through
// `normal`, its surface facing — turned with its half, exactly.
vec3 bend_part(int p, vec3 v, float walk, float moving, float girth, float carrying, out vec3 normal) {
    vec3 radii = part_radii[p] * vec3(girth, 1.0, girth);
    vec4 motion = part_motion[p];       // swing, bend, offset, idle
    vec2 joint_kind = part_joint[p];    // rest, +1 elbow / -1 knee / 0 none
    float amount = mix(motion.w, 1.0, moving);
    float swing = sin(walk + motion.z);
    float upper = motion.x * swing * amount;
    float joint = 0.0;
    if (joint_kind.y > 0.5) {
        // an elbow folds forward, more as the arm swings forward
        joint = joint_kind.x + motion.y * max(swing, 0.0) * amount;
    } else if (joint_kind.y < -0.5) {
        // a knee folds back, its point forward, most while the leg swings
        // forward, straight as the foot plants
        joint = -(joint_kind.x + motion.y * max(cos(walk + motion.z), 0.0) * amount);
    }
    float holding = carrying * part_holds[p];
    upper = mix(upper, hold_forward, holding);
    joint = mix(joint, hold_lift, holding);
    float lower = upper + joint;

    float len = 2.0 * radii.y;
    float s = (1.0 - v.y) * 0.5;
    vec2 rel = vec2(v.y * radii.y - radii.y, v.z * radii.z);   // from the top
    vec3 n = v / radii;
    vec2 placed;
    float angle;
    if (s < 0.5) {
        // the upper half turns about the shoulder or hip
        placed = turned(rel, upper);
        angle = upper;
    } else {
        // the lower half turns about the elbow or knee, carried by the upper
        placed = turned(vec2(-len * 0.5, 0.0), upper) + turned(rel + vec2(len * 0.5, 0.0), lower);
        angle = lower;
    }
    vec2 ny = turned(n.yz, angle);
    normal = vec3(n.x, ny.x, ny.y);
    vec3 point = vec3(part_center[p].x + v.x * radii.x,
                      part_center[p].y + radii.y + placed.x,
                      part_center[p].z + placed.y);
    point.y += part_bob[p] * bob_height * abs(sin(walk)) * moving;
    return point;
}
]]

return M

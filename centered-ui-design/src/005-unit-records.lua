-- 005-unit-records.lua - how units and cuboids are laid out in shared memory.
--
-- In plain terms: every unit's state is sixteen numbers in a row, and every
-- cuboid's twelve, in blocks of memory the ceramic engine's workers and the
-- graphics card both read directly. There are two blocks of each, front and
-- back: during a step everything is read from the front and written to the
-- back, then the two swap.
--
-- Why 32-bit floats only: the graphics card reads the very same bytes as
-- per-unit and per-cuboid drawing data (groups of four floats), so the
-- layouts here, the vertex formats below, and the structs in
-- src/020-ceramic-boxes.c must all match exactly — that is what lets the
-- world go from the engine to the screen with no copying field by field.
--
-- Unit record (64 bytes, four groups of four floats):
--   group A  r            tier distance from the hub (0 = hub)
--            angle        radians, 0 = north, clockwise
--            heading      radians, the direction the unit faces on the ground
--            length       the figure's size (its height, in units of the body
--                         plan, before the world scale and the fold)
--   group B  width        girth: width / length sets how stocky the figure is
--            owner        seat index 0..3, or 4 for a foe (stored as float)
--            level        the unit's level (float)
--            phase        walking phase, radians 0..2pi (advanced by the move
--                         box from ground speed; bends the limbs, see 018)
--   group C  speed_r      tiers per second, outward positive
--            speed_angle  radians per second, clockwise positive
--            order_kind   the last order received (index into the verb list;
--                         0 = none given, so the unit hauls cuboids)
--            named        1 if this unit is the one named by the last map click
--   group D  job          0 idle, 1 fetching a cuboid, 2 carrying one
--            target       the cuboid it fetches or carries, or -1
--            wants        what it asks of that cuboid this step: 0 nothing,
--                         1 pick it up, 2 set it down
--            carrying     0, or the carried cuboid's color + 1 (the shader
--                         bends the arms into a holding pose)
--
-- Cuboid record (48 bytes, three groups of four floats):
--   group A  r, angle     where it is (tier distance, radians)
--            height       how far above the ground (world units)
--            size         its edge, world units at tier 1
--   group B  color        0..3: which section it belongs in
--            state        0 lying, 1 carried, 2 delivered (resting in its section)
--            claimant     the lowest-numbered unit fetching it, or -1
--            carrier      the unit carrying it, or -1
--   group C  timer        seconds it has rested in its section
--            slot         its place in its section's stack
--            appearances  how many times it has appeared (seeds where next)
--            turn         radians: which way it faces
--
-- Sheen record (64 bytes, four groups of four floats): one sheen-point of a
-- surface (issue 214), drawn as a flat circle shaded from its shade-side
-- colour to its sun-side colour round its centre, only turned:
--   group A  r, angle     where it is (tier distance, radians)
--            height       how high (world units)
--            lean         radians from sun-side-up, set by the engine for
--                         driven points (0: its sun side up; pi: shade side)
--   group B  facing x, y, z   which way its surface faces (unit vector)
--            driven       1: the engine turns it each step (water); 0: still
--                         (the land: its lean is worked out when drawn)
--   group C  sun-side colour r, g, b
--            wave phase   radians: where this point is in the waves
--   group D  shade-side colour r, g, b
--            (unused)

local ffi = require("ffi")

local M = {}

ffi.cdef([[
typedef struct {
    float r, angle, heading, length;
    float width, owner, level, phase;
    float speed_r, speed_angle, order_kind, named;
    float job, target, wants, carrying;
} unit_record;

typedef struct {
    float r, angle, height, size;
    float color, state, claimant, carrier;
    float timer, slot, appearances, turn;
} cuboid_record;

typedef struct {
    float r, angle, height, lean;
    float facing_x, facing_y, facing_z, driven;
    float sun_r, sun_g, sun_b, wave_phase;
    float shade_r, shade_g, shade_b, unused;
} sheen_record;
]])

M.RECORD_BYTES = ffi.sizeof("unit_record")
M.CUBOID_BYTES = ffi.sizeof("cuboid_record")
M.SHEEN_BYTES = ffi.sizeof("sheen_record")

-- What the job, wants and state numbers mean (see the C boxes).
M.JOB_IDLE, M.JOB_FETCHING, M.JOB_CARRYING = 0, 1, 2
M.CUBE_LYING, M.CUBE_CARRIED, M.CUBE_DELIVERED = 0, 1, 2

-- The per-unit and per-cuboid vertex formats the graphics card reads the
-- records as: one shader attribute per group of four floats, in order.
M.VERTEX_FORMAT = {
    { "UnitA", "float", 4 },
    { "UnitB", "float", 4 },
    { "UnitC", "float", 4 },
    { "UnitD", "float", 4 },
}
M.SHEEN_VERTEX_FORMAT = {
    { "SheenA", "float", 4 },
    { "SheenB", "float", 4 },
    { "SheenC", "float", 4 },
    { "SheenD", "float", 4 },
}
M.CUBOID_VERTEX_FORMAT = {
    { "CubeA", "float", 4 },
    { "CubeB", "float", 4 },
    { "CubeC", "float", 4 },
}

-- {{{ function M.records_at()
-- Views raw memory (a pointer from LÖVE byte data, or an ffi array) as an
-- array of unit records, indexed from 0.
function M.records_at(pointer)
    return ffi.cast("unit_record *", pointer)
end
-- }}}

-- {{{ function M.sheens_at()
function M.sheens_at(pointer)
    return ffi.cast("sheen_record *", pointer)
end
-- }}}

-- {{{ function M.cuboids_at()
function M.cuboids_at(pointer)
    return ffi.cast("cuboid_record *", pointer)
end
-- }}}

-- {{{ function M.copy_record()
-- Copies one unit record (a plain struct copy).
function M.copy_record(destination, source)
    ffi.copy(destination, source, M.RECORD_BYTES)
end
-- }}}

return M

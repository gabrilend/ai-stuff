-- 005-unit-records.lua - how one unit is laid out in shared memory.
--
-- In plain terms: every unit's state is twelve numbers in a row, in a block
-- of memory every worker thread and the graphics card can read directly.
-- There are two such blocks, front and back: during a step each unit is read
-- from the front and written to the back, then the two swap. A small header
-- block says which is the front and how much time the step covers.
--
-- Why 32-bit floats only: the graphics card reads the very same bytes as
-- per-unit drawing data (three groups of four floats), so the layout here and
-- the vertex format below must match exactly — that is what lets the unit
-- positions go from shared memory to the screen with no copying field by
-- field.
--
-- Record (48 bytes, three groups of four floats):
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
--            order_kind   the last order received (index into the verb list)
--            named        1 if this unit is the one named by the last map click
--
-- Header (16 bytes): front (0 or 1), step_seconds, step_number, unit_count.

local ffi = require("ffi")

local M = {}

ffi.cdef([[
typedef struct {
    float r, angle, heading, length;
    float width, owner, level, phase;
    float speed_r, speed_angle, order_kind, named;
} unit_record;

typedef struct {
    float front, step_seconds, step_number, unit_count;
} step_header;
]])

M.RECORD_BYTES = ffi.sizeof("unit_record")
M.HEADER_BYTES = ffi.sizeof("step_header")

-- The per-unit vertex format the graphics card reads the records as. Each
-- entry is one shader attribute of four floats; the order is the record's.
M.VERTEX_FORMAT = {
    { "UnitA", "float", 4 },
    { "UnitB", "float", 4 },
    { "UnitC", "float", 4 },
}

-- {{{ function M.records_at()
-- Views raw memory (a pointer from LÖVE byte data, or an ffi array) as an
-- array of unit records, indexed from 0.
function M.records_at(pointer)
    return ffi.cast("unit_record *", pointer)
end
-- }}}

-- {{{ function M.header_at()
function M.header_at(pointer)
    return ffi.cast("step_header *", pointer)
end
-- }}}

-- {{{ function M.copy_record()
-- Copies one record field for field (a plain struct copy).
function M.copy_record(destination, source)
    destination.r = source.r
    destination.angle = source.angle
    destination.heading = source.heading
    destination.length = source.length
    destination.width = source.width
    destination.owner = source.owner
    destination.level = source.level
    destination.phase = source.phase
    destination.speed_r = source.speed_r
    destination.speed_angle = source.speed_angle
    destination.order_kind = source.order_kind
    destination.named = source.named
end
-- }}}

return M

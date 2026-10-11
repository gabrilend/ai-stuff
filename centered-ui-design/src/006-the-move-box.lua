-- 006-the-move-box.lua - what happens to one unit in one step.
--
-- In plain terms: a unit is read from the front block, moved by its speeds
-- for exactly as long as the step lasted, turned to face where it is going,
-- and written to the back block. It touches no other unit, so any worker can
-- do any unit at any moment, in any order, and the result is the same.
--
-- This is a soramech box: a function of its inputs that remembers nothing.
-- Its inputs are the unit's index, the step's length in seconds, the two
-- blocks, and the fold (for facing). It is pure Lua over ffi records, so it
-- runs the same in a worker thread and in a plain LuaJIT test.

local records = require("005-unit-records")
local sphere_fold = require("004-the-sphere-fold")

local M = {}

local TWO_PI = math.pi * 2

-- How close to the hub and to the outer edge units may walk before turning
-- back (tier distances).
M.INNER_LIMIT = 0.75

-- {{{ local function bounce_inside()
-- Keeps r inside [low, high] by reflecting off the walls, turning the radial
-- speed around when it reflects. Returns new r and speed.
local function bounce_inside(r, speed_r, low, high)
    -- walked in past the inner wall: reflect outward
    if r < low then
        return low + (low - r), -speed_r
    end
    -- walked out past the outer wall: reflect inward
    if r > high then
        return high - (r - high), -speed_r
    end
    -- inside: unchanged
    return r, speed_r
end
-- }}}

-- {{{ function M.move_unit()
-- The box. Reads unit `index` from `front`, writes it to `back`.
-- `step_seconds` is the time this step covers: every motion is scaled by it.
function M.move_unit(front, back, index, step_seconds, fold)
    local source = front[index]
    local unit = back[index]
    records.copy_record(unit, source)

    local outer_limit = fold.tiers_shown - 0.3
    local r = source.r + source.speed_r * step_seconds
    local speed_r
    r, speed_r = bounce_inside(r, source.speed_r, M.INNER_LIMIT, outer_limit)
    unit.r = r
    unit.speed_r = speed_r

    -- angle wraps around the full turn
    local angle = (source.angle + source.speed_angle * step_seconds) % TWO_PI
    unit.angle = angle

    unit.phase = (source.phase + step_seconds) % 1000

    -- Facing: the motion through (tier, angle), turned into a direction on the
    -- folded ground: outward speed stretched by the fold's slope, sideways
    -- speed by the radius it is travelling around at.
    local slope = sphere_fold.slope(fold, r)
    local radius = sphere_fold.radius(fold, r)
    local outward = slope * speed_r
    local sideways = radius * source.speed_angle
    -- standing still: keep facing the way it was facing
    if math.abs(outward) + math.abs(sideways) < 1e-6 then
        unit.heading = source.heading
    else
        -- moving: ground direction = outward * (radial unit) + sideways * (tangent unit)
        local dx = outward * math.sin(angle) + sideways * math.cos(angle)
        local dz = -outward * math.cos(angle) + sideways * math.sin(angle)
        unit.heading = math.atan2(dx, -dz)
    end
end
-- }}}

return M

-- 007-seeding-the-units.lua - where the first units come from.
--
-- In plain terms: from the game's seed, scatter units across the map — each
-- seat's units in its own quarter of the circle, foes further out — give each
-- a size, a level, and a gentle wandering motion, and write them into the
-- front block of shared memory. Then scatter the cuboids, and name the four
-- color-coded sections they are carried to. The same seed always scatters
-- them the same way.
--
-- Randomness comes from a small generator written with LuaJIT's bit library
-- (xorshift, 32-bit), not math.random, because math.random's sequence is not
-- promised to be the same between builds — and the same seed must give the
-- same world everywhere (later: on every machine in a networked game).

local bit = require("bit")
local sphere_fold = require("004-the-sphere-fold")

local M = {}

local TWO_PI = math.pi * 2

-- {{{ function M.new_stream()
-- A random stream: a table holding one 32-bit state (as a Lua number).
-- Zero would make xorshift stuck at zero forever, so it is moved off zero.
function M.new_stream(seed)
    local state = bit.tobit(seed)
    -- a zero seed would never change: use a fixed odd constant instead
    if state == 0 then
        state = 0x2545F491
    end
    return { state = state }
end
-- }}}

-- {{{ function M.next_fraction()
-- Advances the stream and returns a number in [0, 1).
function M.next_fraction(stream)
    local x = stream.state
    x = bit.bxor(x, bit.lshift(x, 13))
    x = bit.bxor(x, bit.rshift(x, 17))
    x = bit.bxor(x, bit.lshift(x, 5))
    stream.state = x
    -- bit operations give signed 32-bit results; shift into 0 .. 2^32
    local unsigned = x % 4294967296
    return unsigned / 4294967296
end
-- }}}

-- {{{ local function between()
local function between(stream, low, high)
    return low + (high - low) * M.next_fraction(stream)
end
-- }}}

-- {{{ function M.seed_units()
-- Fills `front` (an array of unit records, indexed from 0) with `count`
-- units. One unit in five is a foe out past tier 3; the rest belong to the
-- seat whose quarter of the circle they start in.
function M.seed_units(front, count, seed, fold)
    local stream = M.new_stream(seed)
    local outer_limit = fold.tiers_shown - 0.3
    for index = 0, count - 1 do
        local unit = front[index]
        local is_foe = M.next_fraction(stream) < 0.2
        -- foes start far out; seats' units anywhere from near the hub outward
        if is_foe then
            unit.r = between(stream, 3.2, outer_limit)
        else
            unit.r = between(stream, 0.9, 3.6)
        end
        unit.angle = between(stream, 0, TWO_PI)
        unit.heading = between(stream, 0, TWO_PI)
        unit.length = between(stream, 1.3, 2.2)
        unit.width = unit.length * between(stream, 0.45, 0.62)
        -- owner: a foe is 4; otherwise the seat whose quarter it stands in
        if is_foe then
            unit.owner = 4
        else
            unit.owner = math.floor(unit.angle / (TWO_PI / 4)) % 4
        end
        unit.level = math.floor(between(stream, 1, 9))
        unit.phase = between(stream, 0, TWO_PI)
        unit.speed_r = between(stream, -0.12, 0.12)
        unit.speed_angle = between(stream, -0.05, 0.05)
        unit.order_kind = 0
        unit.named = 0
        unit.job = 0
        unit.target = -1
        unit.wants = 0
        unit.carrying = 0
    end
end
-- }}}

-- The color-coded sections: where cuboids of each color are taken. One in
-- the middle of each quadrant, a little out from the hub; colors 0..3 match
-- seats 1..4. r and radius in tier distances, angle in radians.
M.SECTIONS = {
    { r = 1.7, angle = math.pi * 0.25, radius = 0.42 },
    { r = 1.7, angle = math.pi * 0.75, radius = 0.42 },
    { r = 1.7, angle = math.pi * 1.25, radius = 0.42 },
    { r = 1.7, angle = math.pi * 1.75, radius = 0.42 },
}

-- A cuboid's edge, in world units at tier 1.
M.CUBOID_SIZE = 2.4

-- {{{ function M.seed_cuboids()
-- Scatters `count` cuboids lying about, colors taken in turn, from the seed
-- (a stream of its own, so adding cuboids never moves the units).
function M.seed_cuboids(front, count, seed, fold)
    local stream = M.new_stream(seed + 7919)
    for index = 0, count - 1 do
        local cuboid = front[index]
        cuboid.r = between(stream, 0.9, fold.tiers_shown - 0.5)
        cuboid.angle = between(stream, 0, TWO_PI)
        cuboid.height = 0
        cuboid.size = M.CUBOID_SIZE
        cuboid.color = index % #M.SECTIONS
        cuboid.state = 0
        cuboid.claimant = -1
        cuboid.carrier = -1
        cuboid.timer = 0
        cuboid.slot = 0
        cuboid.appearances = 0
        cuboid.turn = cuboid.angle
    end
end
-- }}}

return M

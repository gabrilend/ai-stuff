--[[
Frame-Based Direction Encoding for Pathfinding

Frames encode direction as quadrant votes, not array indices. Each frame byte
describes the SHAPE of movement - which way the path curves, where momentum
points. The bit pattern IS the direction, visually.

Quadrant layout:
       (-1,+1)         (+1,+1)
          ╲    FAR    ╱
           ╲   │    ╱
    Q1      ╲ │ ╱      Q2
  (top-left) ╲│╱  (top-right)
  ────────────(0,0)────────────  ← NEAR (11) = toward here
              ╱│╲
    Q3      ╱ │ ╲      Q4
 (btm-left) ╱   ╲ (btm-right)
          ╱   FAR  ╲
       (-1,-1)         (+1,-1)

Bit values: 00=Far, 01=Right, 10=Left, 11=Near

A frame is a sentence: "Q1 votes far, Q2 votes near, Q3 votes left, Q4 votes right"
The combination describes a direction through space.
]]

-- {{{ Compatibility layer for bitwise operations
-- Works with both LuaJIT (bit library) and Lua 5.3+ (native operators)
local compat = require("compat")
local band = compat.band
local bor = compat.bor
local bxor = compat.bxor
local lshift = compat.lshift
local rshift = compat.rshift
-- }}}

local frames = {}

-- {{{ Cardinal directions
-- Pure axis-aligned movement. Opposing sides vote together.
frames.NORTH = 0x0F  -- 00 00 11 11 : top far, bottom near → up
frames.SOUTH = 0xF0  -- 11 11 00 00 : top near, bottom far → down
frames.EAST  = 0xCC  -- 11 00 11 00 : left near, right far → right
frames.WEST  = 0x33  -- 00 11 00 11 : left far, right near → left
-- }}}

-- {{{ Ordinal directions
-- Diagonal movement. One quadrant dominates (far), adjacent support.
frames.NORTHEAST = 0x4C  -- 01 00 11 00 : Q2 far, Q1 right-ish, Q3 near
frames.NORTHWEST = 0x1C  -- 00 01 11 00 : Q1 far, Q2 right-ish, Q4 near
frames.SOUTHEAST = 0xC4  -- 11 00 01 00 : Q4 far, Q3 near, Q1 supports
frames.SOUTHWEST = 0xC1  -- 11 00 00 01 : Q3 far, Q4 right-ish, others near
-- }}}

-- {{{ Special frames
frames.ORIGIN   = 0xFF  -- 11 11 11 11 : all near → at target, arrived
frames.OVERSHOOT = 0x00 -- 00 00 00 00 : all far → passed target, reverse
frames.STATIONARY = 0xFF -- same as origin, no movement
-- }}}

-- {{{ Direction vectors (dx, dy) for each cardinal/ordinal
local DIR_VECTORS = {
    [frames.NORTH]     = {  0,  1 },
    [frames.SOUTH]     = {  0, -1 },
    [frames.EAST]      = {  1,  0 },
    [frames.WEST]      = { -1,  0 },
    [frames.NORTHEAST] = {  1,  1 },
    [frames.NORTHWEST] = { -1,  1 },
    [frames.SOUTHEAST] = {  1, -1 },
    [frames.SOUTHWEST] = { -1, -1 },
    [frames.ORIGIN]    = {  0,  0 },
}
-- }}}

-- {{{ frame_to_vector
-- Convert frame to dx, dy movement vector
-- @param frame Direction frame byte
-- @return dx, dy (each -1, 0, or 1)
function frames.frame_to_vector(frame)
    local vec = DIR_VECTORS[frame]
    if vec then
        return vec[1], vec[2]
    end

    -- For non-cardinal frames, decode from quadrant votes
    -- Extract each quadrant (2 bits each)
    local q1 = band(rshift(frame, 6), 0x03)  -- bits 7-6
    local q2 = band(rshift(frame, 4), 0x03)  -- bits 5-4
    local q3 = band(rshift(frame, 2), 0x03)  -- bits 3-2
    local q4 = band(frame, 0x03)              -- bits 1-0

    -- Quadrant contributions (Far=0 means pointing to corner)
    -- Q1 corner: (-1, +1), Q2: (+1, +1), Q3: (-1, -1), Q4: (+1, -1)
    local dx, dy = 0, 0

    -- Far (00) = contributes corner direction, Near (11) = contributes nothing
    -- Intermediate values = partial contribution
    local weight = { [0] = 1.0, [1] = 0.33, [2] = 0.33, [3] = 0.0 }

    dx = dx + (-1) * weight[q1]  -- Q1 contributes -X
    dx = dx + ( 1) * weight[q2]  -- Q2 contributes +X
    dx = dx + (-1) * weight[q3]  -- Q3 contributes -X
    dx = dx + ( 1) * weight[q4]  -- Q4 contributes +X

    dy = dy + ( 1) * weight[q1]  -- Q1 contributes +Y
    dy = dy + ( 1) * weight[q2]  -- Q2 contributes +Y
    dy = dy + (-1) * weight[q3]  -- Q3 contributes -Y
    dy = dy + (-1) * weight[q4]  -- Q4 contributes -Y

    -- Normalize to -1, 0, 1
    if dx > 0.3 then dx = 1 elseif dx < -0.3 then dx = -1 else dx = 0 end
    if dy > 0.3 then dy = 1 elseif dy < -0.3 then dy = -1 else dy = 0 end

    return dx, dy
end
-- }}}

-- {{{ vector_to_frame
-- Convert dx, dy movement to frame byte
-- @param dx X direction (-1, 0, 1)
-- @param dy Y direction (-1, 0, 1)
-- @return frame byte
function frames.vector_to_frame(dx, dy)
    -- Normalize
    if dx > 0 then dx = 1 elseif dx < 0 then dx = -1 end
    if dy > 0 then dy = 1 elseif dy < 0 then dy = -1 end

    -- Map to frame
    if dx == 0 and dy == 1 then return frames.NORTH end
    if dx == 0 and dy == -1 then return frames.SOUTH end
    if dx == 1 and dy == 0 then return frames.EAST end
    if dx == -1 and dy == 0 then return frames.WEST end
    if dx == 1 and dy == 1 then return frames.NORTHEAST end
    if dx == -1 and dy == 1 then return frames.NORTHWEST end
    if dx == 1 and dy == -1 then return frames.SOUTHEAST end
    if dx == -1 and dy == -1 then return frames.SOUTHWEST end

    return frames.ORIGIN  -- dx == 0 and dy == 0
end
-- }}}

-- {{{ points_to_frame
-- Convert two points to direction frame
-- @param x1, y1 Starting point
-- @param x2, y2 Ending point
-- @return frame byte
function frames.points_to_frame(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return frames.vector_to_frame(dx, dy)
end
-- }}}

-- {{{ path_to_frames
-- Convert coordinate path to frame sequence (choreography)
-- @param path Array of {x, y} waypoints
-- @return frame_path { start = {x, y}, frames = {...} }
function frames.path_to_frames(path)
    if not path or #path < 1 then
        return { start = { x = 0, y = 0 }, frames = {} }
    end

    local result = {
        start = { x = path[1].x, y = path[1].y },
        frames = {},
    }

    for i = 2, #path do
        local frame = frames.points_to_frame(
            path[i-1].x, path[i-1].y,
            path[i].x, path[i].y
        )
        result.frames[#result.frames + 1] = frame
    end

    return result
end
-- }}}

-- {{{ frames_to_path
-- Convert frame sequence back to coordinate path
-- @param frame_path { start = {x, y}, frames = {...} }
-- @return path Array of {x, y} waypoints
function frames.frames_to_path(frame_path)
    local path = {
        { x = frame_path.start.x, y = frame_path.start.y }
    }

    local x, y = frame_path.start.x, frame_path.start.y

    for _, frame in ipairs(frame_path.frames) do
        local dx, dy = frames.frame_to_vector(frame)
        x = x + dx
        y = y + dy
        path[#path + 1] = { x = x, y = y }
    end

    return path
end
-- }}}

-- {{{ apply_frame
-- Apply a single frame to a position
-- @param x, y Current position
-- @param frame Direction frame
-- @param magnitude How many steps (default 1)
-- @return new_x, new_y
function frames.apply_frame(x, y, frame, magnitude)
    magnitude = magnitude or 1
    local dx, dy = frames.frame_to_vector(frame)
    return x + dx * magnitude, y + dy * magnitude
end
-- }}}

-- {{{ combine_frames
-- Combine two direction frames (vector addition in frame space)
-- Uses LUT concept: result trends toward combined direction
-- @param frame_a First direction
-- @param frame_b Second direction
-- @return combined frame
function frames.combine_frames(frame_a, frame_b)
    -- Extract quadrants from both frames
    local function get_quadrants(f)
        return {
            band(rshift(f, 6), 0x03),
            band(rshift(f, 4), 0x03),
            band(rshift(f, 2), 0x03),
            band(f, 0x03),
        }
    end

    local qa = get_quadrants(frame_a)
    local qb = get_quadrants(frame_b)

    -- Combine each quadrant (mod 4 arithmetic)
    local result = 0
    for i = 1, 4 do
        local combined = (qa[i] + qb[i]) % 4
        result = bor(result, lshift(combined, (4 - i) * 2))
    end

    return result
end
-- }}}

-- {{{ frame_difference
-- How different are two frames? (0 = same, 255 = opposite)
-- @param frame_a First direction
-- @param frame_b Second direction
-- @return difference score 0-255
function frames.frame_difference(frame_a, frame_b)
    if frame_a == frame_b then return 0 end

    -- XOR gives bits that differ
    local diff = bxor(frame_a, frame_b)

    -- Count differing bits, weight by position
    local score = 0
    for i = 0, 7 do
        if band(rshift(diff, i), 1) == 1 then
            score = score + 32  -- each bit contributes ~32 to max 256
        end
    end

    return math.min(255, score)
end
-- }}}

-- {{{ ASCII visualization
-- Visual representation of frame as ASCII art
frames.GLYPHS = {
    [frames.NORTH]     = "↑",
    [frames.SOUTH]     = "↓",
    [frames.EAST]      = "→",
    [frames.WEST]      = "←",
    [frames.NORTHEAST] = "↗",
    [frames.NORTHWEST] = "↖",
    [frames.SOUTHEAST] = "↘",
    [frames.SOUTHWEST] = "↙",
    [frames.ORIGIN]    = "○",
    [frames.OVERSHOOT] = "×",
}

-- {{{ frame_to_glyph
function frames.frame_to_glyph(frame)
    return frames.GLYPHS[frame] or string.format("%02X", frame)
end
-- }}}

-- {{{ path_to_ascii
-- Convert frame path to ASCII art string
-- @param frame_path { start = {x, y}, frames = {...} }
-- @return string like "→→↗↗↑↑←"
function frames.path_to_ascii(frame_path)
    local parts = {}
    for _, frame in ipairs(frame_path.frames) do
        parts[#parts + 1] = frames.frame_to_glyph(frame)
    end
    return table.concat(parts)
end
-- }}}
-- }}}

-- {{{ Momentum structure
-- Direction + magnitude, for physics calculations
frames.Momentum = {}
frames.Momentum.__index = frames.Momentum

function frames.Momentum.new(direction, count)
    return setmetatable({
        direction = direction or frames.ORIGIN,
        count = count or 0,
    }, frames.Momentum)
end

function frames.Momentum:apply_force(force_direction)
    self.direction = frames.combine_frames(self.direction, force_direction)
    self.count = self.count + 1
end

function frames.Momentum:decay(amount)
    amount = amount or 1
    self.count = math.max(0, self.count - amount)
end

function frames.Momentum:is_stationary()
    return self.count == 0 or self.direction == frames.ORIGIN
end

function frames.Momentum:get_vector()
    if self:is_stationary() then
        return 0, 0
    end
    local dx, dy = frames.frame_to_vector(self.direction)
    return dx * self.count, dy * self.count
end
-- }}}

return frames

--[[
Frame-Based Direction Encoding for Pathfinding

Frames encode direction as quadrant votes, not array indices. Each frame byte
describes the SHAPE of movement - which way the path curves, where momentum
points. The bit pattern IS the direction, visually.

Quadrant layout (Cartesian plane):
       Q1 (top-left)     Q2 (top-right)
       corner: NW        corner: NE
       (-1,+1)           (+1,+1)
              \   +Y    /
               \   |   /
                \  |  /
       -X ───────(0,0)─────── +X  ← NEAR (00) = toward origin
                /  |  \
               /   |   \
              /   -Y    \
       Q4 (bottom-left)  Q3 (bottom-right)
       corner: SW        corner: SE
       (-1,-1)           (+1,-1)

Bit values per quadrant (2 bits each):
  00 = Near  : toward origin (no directional contribution)
  01 = Right : 45° clockwise from Far (axis-aligned)
  10 = Left  : 45° counter-clockwise from Far (axis-aligned)
  11 = Far   : toward corner (diagonal)

Byte layout: [Q1:2bits][Q2:2bits][Q3:2bits][Q4:2bits]
             bits 7-6   bits 5-4   bits 3-2   bits 1-0

Per-quadrant angle mapping:
  Q2: Right=0°(+X), Far=45°(NE), Left=90°(+Y)
  Q1: Right=90°(+Y), Far=135°(NW), Left=180°(-X)
  Q4: Right=180°(-X), Far=225°(SW), Left=270°(-Y)
  Q3: Right=270°(-Y), Far=315°(SE), Left=0°(+X)

Adjacent quadrants share axis boundaries continuously (no gaps).

See docs/binary-vector-frames.md for full specification.
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
-- Pure axis-aligned movement using Left/Right pairs from adjacent quadrants.
-- Cardinals use axis-projections (Left/Right), not corner-projections (Far).
frames.NORTH = 0x60  -- 01 10 00 00 : Q1 Right (+Y), Q2 Left (+Y)
frames.SOUTH = 0x06  -- 00 00 01 10 : Q3 Right (-Y), Q4 Left (-Y)
frames.EAST  = 0x18  -- 00 01 10 00 : Q2 Right (+X), Q3 Left (+X)
frames.WEST  = 0x81  -- 10 00 00 01 : Q1 Left (-X), Q4 Right (-X)
-- }}}

-- {{{ Ordinal directions
-- Diagonal movement. One quadrant votes Far toward its corner.
frames.NORTHEAST = 0x30  -- 00 11 00 00 : Q2 Far (NE corner)
frames.NORTHWEST = 0xC0  -- 11 00 00 00 : Q1 Far (NW corner)
frames.SOUTHEAST = 0x0C  -- 00 00 11 00 : Q3 Far (SE corner)
frames.SOUTHWEST = 0x03  -- 00 00 00 11 : Q4 Far (SW corner)
-- }}}

-- {{{ Special frames
-- Boundary signals for curve convergence
frames.ORIGIN    = 0x00  -- 00 00 00 00 : all Near → at target, arrived
frames.OVERSHOOT = 0xFF  -- 11 11 11 11 : all Far → passed target, reverse & halve momentum
frames.STATIONARY = 0x00 -- same as origin, no movement
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

    -- Quadrant corner contributions:
    -- Q1: (-1, +1) = NW, Q2: (+1, +1) = NE, Q3: (+1, -1) = SE, Q4: (-1, -1) = SW
    local dx, dy = 0, 0

    -- Bit value weights:
    -- Near (00) = no contribution (toward origin)
    -- Right (01) = partial contribution (axis-aligned, clockwise from Far)
    -- Left (10) = partial contribution (axis-aligned, counter-clockwise from Far)
    -- Far (11) = full corner contribution
    local weight = { [0] = 0.0, [1] = 0.5, [2] = 0.5, [3] = 1.0 }

    -- Q1 at (-1, +1) = NW corner
    dx = dx + (-1) * weight[q1]
    dy = dy + ( 1) * weight[q1]

    -- Q2 at (+1, +1) = NE corner
    dx = dx + ( 1) * weight[q2]
    dy = dy + ( 1) * weight[q2]

    -- Q3 at (+1, -1) = SE corner
    dx = dx + ( 1) * weight[q3]
    dy = dy + (-1) * weight[q3]

    -- Q4 at (-1, -1) = SW corner
    dx = dx + (-1) * weight[q4]
    dy = dy + (-1) * weight[q4]

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

-- {{{ Convergence detection
-- Detect when figure-eight convergence has found the target

-- {{{ frame_complement
-- Get the complement of a frame (swap Far<->Near, Left<->Right)
-- @param frame Input frame
-- @return complemented frame
function frames.frame_complement(frame)
    -- For each quadrant: 00<->11, 01<->10
    -- This is equivalent to XOR with 0xFF for Far<->Near swap
    -- But we need Left<->Right swap too (01<->10)
    local q1 = band(rshift(frame, 6), 0x03)
    local q2 = band(rshift(frame, 4), 0x03)
    local q3 = band(rshift(frame, 2), 0x03)
    local q4 = band(frame, 0x03)

    -- Complement table: 00->11, 01->10, 10->01, 11->00
    local comp = { [0] = 3, [1] = 2, [2] = 1, [3] = 0 }

    return bor(
        lshift(comp[q1], 6),
        lshift(comp[q2], 4),
        lshift(comp[q3], 2),
        comp[q4]
    )
end
-- }}}

-- {{{ is_complement_pair
-- Check if two frames are complements (oscillation detection)
-- @param frame_a First frame
-- @param frame_b Second frame
-- @return true if frames are complements
function frames.is_complement_pair(frame_a, frame_b)
    return frames.frame_complement(frame_a) == frame_b
end
-- }}}

-- {{{ detect_convergence
-- Detect convergence from a sequence of recent frames
-- Convergence = repeated complement oscillation (e.g., FF 00 FF 00)
-- @param frame_history Array of recent frames (newest first)
-- @param min_oscillations Minimum oscillation count to trigger (default 2)
-- @return true if converged, false otherwise
function frames.detect_convergence(frame_history, min_oscillations)
    min_oscillations = min_oscillations or 2

    if #frame_history < min_oscillations * 2 then
        return false
    end

    -- Check for alternating complement pairs
    local oscillations = 0
    for i = 1, #frame_history - 1 do
        if frames.is_complement_pair(frame_history[i], frame_history[i + 1]) then
            oscillations = oscillations + 1
        else
            break  -- Pattern broken
        end
    end

    return oscillations >= min_oscillations
end
-- }}}
-- }}}

return frames

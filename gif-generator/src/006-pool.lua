-- 006-pool.lua — the particle pool: every particle that will ever be
-- alive at once, allocated before the first one is born.
--
-- What this is, generally: one block of memory laid out as parallel
-- flat arrays — all the x positions together, all the y positions
-- together, and so on. One particle is one index across all arrays.
-- Memory first, then work: the pool never grows, and asking for more
-- than it holds is a loud error naming who asked, because silently
-- dropping particles would silently change the picture.
--
-- Data-format notes worth knowing more than once:
--   * live particles always form a solid prefix: indices 0..live-1.
--     Death is swap-with-last — the last live particle moves into
--     the dead one's slot and the count drops. No liveness flags,
--     no fragmentation, and iteration never checks a hole.
--   * the swap means indices are NOT stable across a reap; nothing
--     downstream may remember a particle by index across ticks.
--     (The renderer reads whole snapshots; nothing needs stability.)
--   * hue is a small integer naming a seat in the score's declared
--     hue list, not a color — colors live with the palette.
--   * drag and jitter ride per particle (set at spawn from the
--     recipe) so strokes of different characters can share one pool.

local ffi = require("ffi")

local pool = {}

-- Sizing headroom: the estimate below is honest but an estimate;
-- the margin covers spawn-accumulator ripple and easing bunching.
-- If the margin is ever actually consumed, the overflow error tells
-- us the estimate lied — which we want to hear, not absorb.
local HEADROOM = 1.25
local FLOOR = 64

-- {{{ function pool.new()
-- All arrays born at once. Capacity comes from pool.size_for or an
-- explicit number (tests use small explicit pools to hit the walls).
function pool.new(capacity)
    if capacity < 1 then
        error("pool: capacity must be at least 1, got "
              .. tostring(capacity))
    end
    return {
        capacity = capacity,
        live = 0,
        x      = ffi.new("float[?]", capacity),
        y      = ffi.new("float[?]", capacity),
        vx     = ffi.new("float[?]", capacity),
        vy     = ffi.new("float[?]", capacity),
        age    = ffi.new("float[?]", capacity),
        life   = ffi.new("float[?]", capacity),
        drag   = ffi.new("float[?]", capacity),
        jitter = ffi.new("float[?]", capacity),
        seed   = ffi.new("float[?]", capacity),
        hue    = ffi.new("uint8_t[?]", capacity),
    }
end
-- }}}

-- {{{ function pool.spawn()
-- Hands out the next slot past the live prefix. The caller (the emit
-- step) fills the fields; the asker's name makes the overflow error
-- point at the stroke that outgrew the estimate.
function pool.spawn(p, asker)
    if p.live >= p.capacity then
        error("pool: overflow — '" .. tostring(asker) .. "' asked for "
              .. "particle " .. (p.live + 1) .. " of " .. p.capacity
              .. "; the sizing estimate lied and we want to know")
    end
    local i = p.live
    p.live = p.live + 1
    return i
end
-- }}}

-- {{{ function pool.kill()
-- Swap-with-last: the prefix stays solid. Killing the last live
-- particle is just the count dropping — the copy is harmless then.
function pool.kill(p, i)
    if i >= p.live then
        error("pool: killing index " .. i .. " beyond the live prefix ("
              .. p.live .. ") — a caller is confused about liveness")
    end
    local last = p.live - 1
    p.x[i], p.y[i]   = p.x[last], p.y[last]
    p.vx[i], p.vy[i] = p.vx[last], p.vy[last]
    p.age[i]         = p.age[last]
    p.life[i]        = p.life[last]
    p.drag[i]        = p.drag[last]
    p.jitter[i]      = p.jitter[last]
    p.seed[i]        = p.seed[last]
    p.hue[i]         = p.hue[last]
    p.live = last
end
-- }}}

-- {{{ function pool.size_for()
-- The sizing arithmetic: given each stroke's demand as
-- { rate, life, from, upto } (emission window [from, upto]), find
-- the peak count of particles alive at any instant, numerically.
-- A particle alive at time t was born inside [t - life, t] AND
-- inside the emission window; the overlap length times the rate is
-- that stroke's standing population at t. Sampling every 0.05s is
-- plenty against tenth-quantized windows, and honesty comes from
-- the headroom plus the overflow wall — not from pretending this
-- integral is exact.
function pool.size_for(demands)
    local horizon = 0
    for _, d in ipairs(demands) do
        local tail = d.upto + d.life
        if tail > horizon then horizon = tail end
    end
    local peak = 0
    local t = 0
    while t <= horizon do
        local alive = 0
        for _, d in ipairs(demands) do
            local born_from = math.max(d.from, t - d.life)
            local born_upto = math.min(d.upto, t)
            if born_upto > born_from then
                alive = alive + d.rate * (born_upto - born_from)
            end
        end
        if alive > peak then peak = alive end
        t = t + 0.05
    end
    return math.ceil(peak * HEADROOM) + FLOOR
end
-- }}}

return pool

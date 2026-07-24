-- 000-canvas.lua — the light buffer and the tone-mapper.
--
-- What this is, generally: the canvas every particle glows onto. It
-- accumulates light energy as floating-point numbers (so a thousand
-- faint glows can pile into one brilliant core without clipping along
-- the way), and at the end of each frame it compresses that energy
-- into displayable color exactly once.
--
-- THE INDEX RITUAL (this being the first indexed file): source files
-- carry a three-digit reading-order index. To create one: read the
-- hidden .file-index-counter at the project root (it holds the next
-- unused index), name your file with it, increment the counter by the
-- number of indices you took. The numbers flow through all
-- directories and tell the story of the build in order.
--
-- Data-format notes worth knowing more than once:
--   * energy is laid out flat: three floats (r,g,b) per pixel, row by
--     row — index of pixel (x,y) is (y*width + x) * 3. Every consumer
--     of a canvas assumes this layout; change it nowhere or everywhere.
--   * coordinates are 0-based and y grows DOWNWARD (screen space, as
--     pinned down in docs/datapath-scene-script.md).
--   * zero energy IS the background. Nothing ever paints black.

local ffi = require("ffi")

local canvas = {}

-- Aesthetic knobs. Tuning these changes the *feel* of every gif, so
-- changes belong in docs/balance-updates.md with a reason attached.
-- WHITE_KNEE: how much accumulated light it takes before a hue starts
--   bleaching toward white-hot. Lower = eager to bleach.
-- GAMMA: perceptual spacing; applied last so dark glow tails get
--   tonal room on their way into the palette's dark ramp entries.
local WHITE_KNEE = 3.0
local GAMMA = 2.2

-- {{{ function canvas.new()
-- One allocation, up front, memory-first: the energy plane and the
-- mapped plane are both born here and reused for every frame after.
function canvas.new(width, height)
    -- refuse nonsense sizes loudly; a zero-area canvas is a scene bug,
    -- and discovering it here beats discovering it as a corrupt gif.
    if width < 1 or height < 1 then
        error("canvas: width and height must be at least 1, got "
              .. tostring(width) .. "x" .. tostring(height))
    end
    local cv = {
        width  = width,
        height = height,
        -- the accumulation plane: raw light energy, unbounded above
        energy = ffi.new("float[?]", width * height * 3),
        -- the mapped plane: tone-mapped [0,1] color, written by tonemap
        mapped = ffi.new("float[?]", width * height * 3),
    }
    return cv
end
-- }}}

-- {{{ function canvas.clear()
-- Zero is the black background; clearing is the only moment the
-- canvas touches every pixel without light being involved.
function canvas.clear(cv)
    ffi.fill(cv.energy, ffi.sizeof("float") * cv.width * cv.height * 3)
end
-- }}}

-- {{{ function canvas.add()
-- The single write operation: deposit energy at a pixel. Addition
-- commutes, so particle order never matters — the property the
-- threaded pipeline will later lean its whole weight on.
function canvas.add(cv, x, y, er, eg, eb)
    -- out-of-bounds is a caller bug (the splatter clips before
    -- calling); erroring here keeps such bugs young and easy to catch.
    if x < 0 or x >= cv.width or y < 0 or y >= cv.height then
        error("canvas: deposit outside the canvas at ("
              .. x .. "," .. y .. ")")
    end
    local i = (y * cv.width + x) * 3
    cv.energy[i]     = cv.energy[i]     + er
    cv.energy[i + 1] = cv.energy[i + 1] + eg
    cv.energy[i + 2] = cv.energy[i + 2] + eb
end
-- }}}

-- {{{ function canvas.tonemap()
-- Energy to displayable color, in three moves per pixel:
--   1. white-shift: as total light climbs, blend each channel toward
--      the pixel's mean energy — dense cores of any hue read white-hot
--      while their dimmer halos keep the hue.
--   2. soft knee (Reinhard): e/(1+e) — linear when dim, gentle
--      shoulder into saturation, never quite 1, never clips.
--   3. gamma: perceptual spacing, applied last.
-- The mapped plane is the return value's home; it is reused, not
-- reallocated (memory first, then work).
function canvas.tonemap(cv)
    local e, m = cv.energy, cv.mapped
    local n = cv.width * cv.height
    local inv_gamma = 1.0 / GAMMA
    for p = 0, n - 1 do
        local i = p * 3
        local r, g, b = e[i], e[i + 1], e[i + 2]
        local mean = (r + g + b) / 3.0
        -- the white-shift blend weight: 0 when dim (hue kept),
        -- toward 1 when blazing (hue surrendered to white)
        local s = mean / (mean + WHITE_KNEE)
        r = r + s * (mean * 3.0 - r)
        g = g + s * (mean * 3.0 - g)
        b = b + s * (mean * 3.0 - b)
        -- soft knee, then gamma; each channel rides alone from here
        r = r / (1.0 + r)
        g = g / (1.0 + g)
        b = b / (1.0 + b)
        m[i]     = r ^ inv_gamma
        m[i + 1] = g ^ inv_gamma
        m[i + 2] = b ^ inv_gamma
    end
    return m
end
-- }}}

-- {{{ function canvas.mapped_byte()
-- A viewing convenience (tests, debug dumps): one mapped channel as a
-- 0..255 byte. The pipeline itself never uses bytes-per-channel — it
-- goes straight from mapped floats to palette indices.
function canvas.mapped_byte(cv, x, y, channel)
    local i = (y * cv.width + x) * 3 + channel
    local v = cv.mapped[i] * 255.0 + 0.5
    if v > 255.0 then v = 255.0 end
    return math.floor(v)
end
-- }}}

return canvas

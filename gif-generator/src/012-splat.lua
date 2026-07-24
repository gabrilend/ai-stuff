-- 012-splat.lua — the frame snapshot and the glow splatter: where a
-- particle population becomes light on the canvas.
--
-- What this is, generally: after each simulation tick, the live
-- prefix of the pool is copied into a compact snapshot (positions,
-- fades, hues, bright-seeds — numbers only, tens of kilobytes). The
-- splatter stamps each entry as a small radial glow, additively, at
-- its true fractional position. The copy is the design, not waste:
-- it draws a clean testable border between simulating and drawing,
-- and it is the border worker threads will later stand on (see
-- strategems/pipeline-of-snapshots).
--
-- Data-format notes worth knowing more than once:
--   * a snapshot's arrays are sized to the pool's capacity once and
--     reused every frame; only the first n entries are meaningful.
--   * fade is computed AT SNAPSHOT TIME (it derives from age, and
--     age keeps moving) — a snapshot is a moment, frozen honestly.
--   * hue colors arrive as a flat float array, three per declared
--     hue, built once per render from the palette's vocabulary.

local ffi = require("ffi")
local physics = require("010-physics")
local palette = require("002-palette")
local canvas = require("000-canvas")

local splat = {}

-- Aesthetic knobs (tuning belongs in docs/balance-updates.md):
-- RADIUS: the glow stamp's reach in pixels. INTENSITY: energy at a
-- stamp's heart before fade and seed have their say.
local RADIUS = 2.6
local INTENSITY = 0.55

-- {{{ function splat.colors_for()
-- The declared hue names, resolved once into a flat float array the
-- hot loop can index without a table in sight.
function splat.colors_for(declared)
    local colors = ffi.new("float[?]", #declared * 3)
    for n, name in ipairs(declared) do
        local r, g, b = palette.hue_color(name)
        colors[(n - 1) * 3]     = r
        colors[(n - 1) * 3 + 1] = g
        colors[(n - 1) * 3 + 2] = b
    end
    return colors
end
-- }}}

-- {{{ function splat.snapshot()
-- A reusable snapshot sized to the pool it will mirror.
function splat.snapshot(capacity)
    return {
        n = 0,
        capacity = capacity,
        x    = ffi.new("float[?]", capacity),
        y    = ffi.new("float[?]", capacity),
        -- fade is the one value BORN at this border (derived from
        -- age, which keeps moving), so the border keeps its full
        -- precision — a float here made snapshot renders differ
        -- from pool renders in the last bits, and the identity test
        -- caught it. Positions copy float-to-float, lossless.
        fade = ffi.new("double[?]", capacity),
        seed = ffi.new("float[?]", capacity),
        hue  = ffi.new("uint8_t[?]", capacity),
    }
end
-- }}}

-- {{{ function splat.take()
-- Freeze the moment: copy the live prefix, fades included.
function splat.take(p, snap)
    if p.live > snap.capacity then
        error("splat: snapshot too small for the pool ("
              .. p.live .. " live, " .. snap.capacity .. " seats) — "
              .. "snapshots are sized from the pool; someone resized one")
    end
    for i = 0, p.live - 1 do
        snap.x[i] = p.x[i]
        snap.y[i] = p.y[i]
        snap.fade[i] = physics.fade_of(p, i)
        snap.seed[i] = p.seed[i]
        snap.hue[i] = p.hue[i]
    end
    snap.n = p.live
    return snap
end
-- }}}

-- {{{ local function stamp()
-- One radial glow at a fractional position. The bell is a squared
-- falloff — cheap, and indistinguishable from a Gaussian at this
-- size. Edges clip by loop bounds; the canvas never sees an
-- out-of-range deposit.
local function stamp(cv, cx, cy, er, eg, eb)
    local x0 = math.floor(cx - RADIUS)
    local x1 = math.ceil(cx + RADIUS)
    local y0 = math.floor(cy - RADIUS)
    local y1 = math.ceil(cy + RADIUS)
    if x0 < 0 then x0 = 0 end
    if y0 < 0 then y0 = 0 end
    if x1 > cv.width - 1 then x1 = cv.width - 1 end
    if y1 > cv.height - 1 then y1 = cv.height - 1 end
    local r2 = RADIUS * RADIUS
    for y = y0, y1 do
        for x = x0, x1 do
            -- distance from the pixel to the TRUE center — this is
            -- where sub-pixel motion stays silky instead of snapping
            local dx, dy = x - cx, y - cy
            local d2 = dx * dx + dy * dy
            if d2 < r2 then
                local w = 1 - d2 / r2
                w = w * w
                canvas.add(cv, x, y, er * w, eg * w, eb * w)
            end
        end
    end
end
-- }}}

-- {{{ function splat.render_snapshot()
-- The pipeline's true path: a frozen moment onto the canvas.
function splat.render_snapshot(cv, snap, colors)
    for i = 0, snap.n - 1 do
        local e = INTENSITY * snap.fade[i] * snap.seed[i]
        local c = snap.hue[i] * 3
        stamp(cv, snap.x[i], snap.y[i],
              colors[c] * e, colors[c + 1] * e, colors[c + 2] * e)
    end
end
-- }}}

-- {{{ function splat.render_pool()
-- The same light, straight from the pool — exists so the tests can
-- prove the snapshot copy loses nothing. The pipeline never calls
-- this; if the two paths ever disagree, the snapshot lied.
function splat.render_pool(cv, p, colors)
    for i = 0, p.live - 1 do
        local e = INTENSITY * physics.fade_of(p, i) * p.seed[i]
        local c = p.hue[i] * 3
        stamp(cv, p.x[i], p.y[i],
              colors[c] * e, colors[c + 1] * e, colors[c + 2] * e)
    end
end
-- }}}

return splat

-- two-clocks.lua — the phase-3 demo: the vision, staged.
--
-- What this is, generally: the founding gesture from notes/vision,
-- choreographed directly against the track machinery (the score
-- language of phase 4 will compile to exactly this). Every track
-- below carries the sentence of vision prose it translates — this
-- file is the dress rehearsal for the vocabulary, and anything that
-- translated awkwardly here is a language bug to fix before the
-- format freezes.
--
-- Geometry decided here (a choice, not a fact — the vision names no
-- third vertex): the "triangle" is the two resting tips plus a low
-- center point between the clocks.

local DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"
if arg and arg[1] then DIR = arg[1] end
package.path = DIR .. "/src/?.lua;" .. package.path

local ffi = require("ffi")
local canvas = require("000-canvas")
local palette = require("002-palette")
local gif = require("004-gif")
local pool = require("006-pool")
local emit = require("008-emit")
local paths = require("014-paths")
local easing = require("016-easing")
local tracks = require("018-tracks")
local fills = require("020-fills")
local splat = require("012-splat")

local SIZE = 256
local FPS = 25
local DT = 1 / FPS
local SECONDS = 4.6
local SEED = 77

-- the two clock faces, side by side, and where their hands rest
local LEFT  = { center = { 76, 108}, radius = 52 }
local RIGHT = { center = {180, 108}, radius = 52 }
-- {{{ local function tip_of()
-- where a hand's sweep ends: on the circle at the resting hour
local function tip_of(clock, hour)
    local a = paths.clock_angle(hour)
    return { clock.center[1] + math.cos(a) * clock.radius,
             clock.center[2] + math.sin(a) * clock.radius }
end
-- }}}
local LEFT_TIP  = tip_of(LEFT, 7)
local RIGHT_TIP = tip_of(RIGHT, 5)
local LOW_POINT = { 128, 208 }

local HUES = { "ember", "violet" }
local EMBER, VIOLET = 0, 1

-- the hands share a character: drawn at the tip, oriented inward
-- (aim rides the sweep's tangent), trailing embers as they go
local hand_recipe = { rate = 700, spread = 2.2, speed = 26, aim = 0.7,
                      drag = 3.0, jitter = 18, life = 0.65,
                      life_jitter = 0.35 }

local timeline = tracks.timeline({

    -- "Two circles, both starting at 12 o'clock... the one on the
    --  left starts at 12 and goes to 7" — "slow at first but then
    --  fast like a stroke"
    tracks.track{
        name = "left-hand", from = 0.0, lasts = 2.0,
        ease = easing.motion("stroke"),
        envelope = easing.envelope("hold"),
        path = paths.arc{ center = LEFT.center, radius = LEFT.radius,
                          from = 12, to = 7, turn = "clockwise" },
        recipe = emit.recipe(hand_recipe, EMBER),
    },

    -- "the one on the right is reversed such that it starts at 12
    --  and sweeps around to about 5, counterclockwise"
    tracks.track{
        name = "right-hand", from = 0.0, lasts = 2.0,
        ease = easing.motion("stroke"),
        envelope = easing.envelope("hold"),
        path = paths.arc{ center = RIGHT.center, radius = RIGHT.radius,
                          from = 12, to = 5, turn = "counterclockwise" },
        recipe = emit.recipe(hand_recipe, EMBER),
    },

    -- the resting tips keep a quiet ember while the seal is drawn —
    -- the vision keeps them as the triangle's upper corners, so the
    -- eye should too
    tracks.track{
        name = "left-rest", from = 2.0, lasts = 2.2,
        ease = easing.motion("linear"),
        envelope = easing.envelope("hold"),
        path = paths.point{ at = LEFT_TIP },
        recipe = emit.recipe({ rate = 90, spread = 1.5, speed = 6,
                               aim = 0, drag = 2, jitter = 10,
                               life = 0.5 }, EMBER),
    },
    tracks.track{
        name = "right-rest", from = 2.0, lasts = 2.2,
        ease = easing.motion("linear"),
        envelope = easing.envelope("hold"),
        path = paths.point{ at = RIGHT_TIP },
        recipe = emit.recipe({ rate = 90, spread = 1.5, speed = 6,
                               aim = 0, drag = 2, jitter = 10,
                               life = 0.5 }, EMBER),
    },

    -- "After 5 for the left hand and 7 for the right hand, fade in
    --  a line between 7 on the left clock and 5 on the right clock."
    --  — the line arrives whole and breathes in: an at-once field
    fills.track{
        name = "seal-line", from = 2.2, lasts = 0.9,
        ease = easing.motion("linear"),
        envelope = easing.envelope("in"),
        region = fills.region{ vertices = { LEFT_TIP, RIGHT_TIP },
                               sweep = "at-once" },
        recipe = emit.recipe({ rate = 800, spread = 1.2, speed = 5,
                               aim = 0, drag = 2.5, jitter = 8,
                               life = 0.7 }, VIOLET),
    },

    -- "Fill the 'triangle' between 7 on the left clock, 5 on the
    --  right clock, slowly." — a downward frontier descends from
    --  the seal-line toward the low point
    fills.track{
        name = "seal-fill", from = 3.0, lasts = 1.2,
        ease = easing.motion("linear"),
        envelope = easing.envelope("in"),
        region = fills.region{ vertices = { LEFT_TIP, RIGHT_TIP,
                                            LOW_POINT },
                               sweep = "downward" },
        recipe = emit.recipe({ rate = 1400, spread = 1.4, speed = 4,
                               aim = 0, drag = 2.5, jitter = 8,
                               life = 0.9, life_jitter = 0.3 }, VIOLET),
    },

}, 0, 0)

-- pool sizing from every track's demand, the honest way
local demands = {}
for _, tr in ipairs(timeline.tracks) do
    demands[#demands + 1] = {
        rate = tr.recipe.rate, life = tr.recipe.life,
        from = tr.from, upto = tr.from + tr.lasts,
    }
end
local p = pool.new(pool.size_for(demands))
local rng = emit.rng(SEED)
local pal = palette.build(HUES)
local colors = splat.colors_for(HUES)
local cv = canvas.new(SIZE, SIZE)
local snap = splat.snapshot(p.capacity)

local FRAMES = math.floor(SECONDS * FPS)
local frames = {}
local peak = 0
for f = 0, FRAMES - 1 do
    tracks.step(timeline, p, rng, f * DT, DT)
    if p.live > peak then peak = p.live end
    splat.take(p, snap)
    canvas.clear(cv)
    splat.render_snapshot(cv, snap, colors)
    local mapped = canvas.tonemap(cv)
    local frame = ffi.new("uint8_t[?]", SIZE * SIZE)
    for px = 0, SIZE * SIZE - 1 do
        local i = px * 3
        frame[px] = palette.index_of(pal, mapped[i], mapped[i + 1],
                                     mapped[i + 2])
    end
    frames[#frames + 1] = frame
end

local spec = { width = SIZE, height = SIZE, palette_bytes = pal.bytes,
               frames = frames, delay_cs = math.floor(100 / FPS) }
local here = DIR .. "/issues/completed/demos/phase-3/two-clocks.gif"
local bytes = gif.write(here, spec)
gif.write(DIR .. "/output/two-clocks.gif", spec)

print("two clocks (the vision, staged):")
print("  tracks:          " .. #timeline.tracks)
print("  frames:          " .. FRAMES)
print("  bytes:           " .. bytes)
print("  peak particles:  " .. peak)
print("  pool estimate:   " .. p.capacity
      .. string.format("  (peak used %.0f%%)", 100 * peak / p.capacity))
print("  written to:      " .. here)

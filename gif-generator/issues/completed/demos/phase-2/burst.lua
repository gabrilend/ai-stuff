-- burst.lua — the phase-2 demo: a bloom and a fountain, the first
-- gifs drawn by a living particle population.
--
-- What this is, generally: two short pieces rendered by the full
-- particle machinery — pool, emitters, physics, snapshot, splatter —
-- through the phase-1 substrate untouched. The bloom is a single
-- breath of gold fired outward and dragging to embers; the fountain
-- is a teal-and-rose jet that rises, falls, and never stops. The
-- demo prints measured numbers: peak population, how much of the
-- pool's estimate was actually used, frames, bytes.

local DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"
if arg and arg[1] then DIR = arg[1] end
package.path = DIR .. "/src/?.lua;" .. package.path

local ffi = require("ffi")
local canvas = require("000-canvas")
local palette = require("002-palette")
local gif = require("004-gif")
local pool = require("006-pool")
local emit = require("008-emit")
local physics = require("010-physics")
local splat = require("012-splat")

local SIZE = 256
local FPS = 25
local DT = 1 / FPS

-- {{{ local function render_piece()
-- One piece: a list of strokes-by-hand (emitter, position, heading,
-- window), a gravity, a length, a palette. Returns measured facts.
-- This shape is a hand-made preview of what compiled scores will
-- hand the runner in phase 4.
local function render_piece(name, hues, strokes, gravity_y, seconds, seed)
    local frames_wanted = math.floor(seconds * FPS)
    local demands = {}
    for _, s in ipairs(strokes) do
        demands[#demands + 1] = {
            rate = s.recipe.rate, life = s.recipe.life,
            from = s.from, upto = s.upto,
        }
    end
    local p = pool.new(pool.size_for(demands))
    local rng = emit.rng(seed)
    local pal = palette.build(hues)
    local colors = splat.colors_for(hues)
    local cv = canvas.new(SIZE, SIZE)
    local snap = splat.snapshot(p.capacity)

    local frames = {}
    local peak = 0
    for f = 0, frames_wanted - 1 do
        local t = f * DT
        for _, s in ipairs(strokes) do
            -- window gating: outside its time a stroke is silent
            if t >= s.from and t < s.upto then
                s.carry = emit.step(p, rng, s.recipe, name, s.x, s.y,
                                    s.hx, s.hy, 1.0, DT, s.carry)
            end
        end
        physics.tick(p, rng, DT, 0, gravity_y)
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
    local here = DIR .. "/issues/completed/demos/phase-2/" .. name .. ".gif"
    local bytes = gif.write(here, spec)
    gif.write(DIR .. "/output/" .. name .. ".gif", spec)

    print(name .. ":")
    print("  frames:          " .. #frames)
    print("  bytes:           " .. bytes)
    print("  peak particles:  " .. peak)
    print("  pool estimate:   " .. p.capacity
          .. string.format("  (peak used %.0f%%)", 100 * peak / p.capacity))
    print("  written to:      " .. here)
    return peak
end
-- }}}

-- the bloom: one breath of gold, fired every way at once, dragging
-- to a halt and embering out — the aesthetic checkpoint
render_piece("bloom", { "gold" }, {
    {
        x = SIZE / 2, y = SIZE / 2, hx = 0, hy = 0,
        from = 0.0, upto = 0.15, carry = 0,
        recipe = emit.recipe({
            rate = 2600, speed = 95, aim = 0.0, spread = 2,
            drag = 1.7, jitter = 12, life = 1.5, life_jitter = 0.45,
        }, 0),
    },
}, 14, 2.6, 71)

-- the fountain: teal jet with a rose heart, rising against gravity,
-- falling as sparks — runs the whole loop so it seams cleanly
render_piece("fountain", { "teal", "rose" }, {
    {
        x = SIZE / 2, y = 236, hx = 0, hy = -1,
        from = 0.0, upto = 4.0, carry = 0,
        recipe = emit.recipe({
            rate = 900, speed = 150, aim = 0.9, spread = 3,
            drag = 0.35, jitter = 26, life = 1.7, life_jitter = 0.3,
        }, 0),
    },
    {
        x = SIZE / 2, y = 236, hx = 0, hy = -1,
        from = 0.0, upto = 4.0, carry = 0,
        recipe = emit.recipe({
            rate = 260, speed = 120, aim = 0.95, spread = 1.5,
            drag = 0.35, jitter = 14, life = 1.2, life_jitter = 0.3,
        }, 1),
    },
}, 105, 4.0, 72)

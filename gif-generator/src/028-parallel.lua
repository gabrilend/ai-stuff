-- 028-parallel.lua — the pipeline of snapshots made real: the sim
-- keeps ticking while worker threads rasterize and compress frames.
--
-- What this is, generally: the strategem performed. The simulator
-- must run in order (time depends on time), but a finished frame's
-- snapshot doesn't care who draws it or when — so each frame is
-- packed into one flat string, pushed through a channel, and any
-- worker splats, tone-maps, indexes, and LZW-compresses it. Results
-- reassemble by sequence number. Byte-identity is the honesty test:
-- the same scene and seed yield the same gif with one worker, three
-- workers, or none (the sequential runner), because workers consume
-- no randomness and addition commutes.
--
-- Vehicle choice, recorded as the blueprint demands: effil threads
-- (each its own LuaJIT state running these same modules), loaded
-- from the shared shelf. The house C threadpool was structurally
-- disqualified before any stopwatch: it dispatches C functions, and
-- the stages being parallelized are Lua — driving them from C
-- threads would mean one embedded Lua state per thread plus glue,
-- which is this same design wearing a heavier coat.
--
-- Snapshot wire format (all offsets from 0, n = particle count):
--   [x f32*n][y f32*n][fade f64*n][seed f32*n][hue u8*n]
-- x at 0, y at 4n, fade at 8n (8-aligned since 8|8n), seed at 16n,
-- hue at 20n; 21n bytes total. Fade rides at full width for the
-- same reason the snapshot module keeps it in doubles: identity.

local EFFIL_CPATH = "/home/ritz/programming/ai-stuff/libs/lua/"
                    .. "effil-jit/build/?.so;"

local ffi = require("ffi")
local pool = require("006-pool")
local emit = require("008-emit")
local splat = require("012-splat")
local tracks = require("018-tracks")
local gif = require("004-gif")

local parallel = {}

-- {{{ local function load_effil()
local function load_effil()
    package.cpath = EFFIL_CPATH .. package.cpath
    local ok, effil = pcall(require, "effil")
    if not ok then
        error("parallel: effil is missing from the shared shelf ("
              .. EFFIL_CPATH .. ") — the many-hands pipeline needs "
              .. "it; the sequential runner still works without")
    end
    return effil
end
-- }}}

-- {{{ function parallel.pack_snapshot()
-- One frame's moment as one flat string, per the wire format above.
function parallel.pack_snapshot(snap)
    local n = snap.n
    local bytes = ffi.new("uint8_t[?]", 21 * n)
    ffi.copy(bytes, snap.x, 4 * n)
    ffi.copy(bytes + 4 * n, snap.y, 4 * n)
    ffi.copy(bytes + 8 * n, snap.fade, 8 * n)
    ffi.copy(bytes + 16 * n, snap.seed, 4 * n)
    ffi.copy(bytes + 20 * n, snap.hue, n)
    return ffi.string(bytes, 21 * n), n
end
-- }}}

-- {{{ local function worker_main()
-- The whole worker, self-contained (effil ships it to a fresh Lua
-- state, so everything arrives as arguments and requires happen
-- inside). Pops jobs until the well says done; pushes back
-- (sequence, compressed frame data).
local function worker_main(dir, size, ramps, white, colors_str,
                           jobs, results)
    package.path = dir .. "/src/?.lua;" .. package.path
    local ffi_w = require("ffi")
    local canvas_w = require("000-canvas")
    local palette_w = require("002-palette")
    local splat_w = require("012-splat")
    local gif_w = require("004-gif")

    local colors = ffi_w.cast("const float*", colors_str)
    -- the indexer reads only the seating chart, never the bytes —
    -- ramps and white crossed the thread border as plain tables
    local pal_view = { ramps = ramps, white = white }
    local cv = canvas_w.new(size, size)
    local frame = ffi_w.new("uint8_t[?]", size * size)

    while true do
        local seq, packed, n = jobs:pop()
        if seq == "done" then break end
        local base = ffi_w.cast("const uint8_t*", packed)
        local snap_view = {
            n = n,
            x = ffi_w.cast("const float*", base),
            y = ffi_w.cast("const float*", base + 4 * n),
            fade = ffi_w.cast("const double*", base + 8 * n),
            seed = ffi_w.cast("const float*", base + 16 * n),
            hue = ffi_w.cast("const uint8_t*", base + 20 * n),
        }
        canvas_w.clear(cv)
        splat_w.render_snapshot(cv, snap_view, colors)
        local mapped = canvas_w.tonemap(cv)
        for px = 0, size * size - 1 do
            local i = px * 3
            frame[px] = palette_w.index_of(pal_view, mapped[i],
                                           mapped[i + 1], mapped[i + 2])
        end
        results:push(seq, gif_w.compress_frame(frame, size * size))
    end
    return true
end
-- }}}

-- {{{ function parallel.render_to_gif()
-- The many-hands render: compiled score in, gif bytes and facts
-- out, with the worker count chosen by the caller. One worker is a
-- first-class road, not a fossil — the identity test drives it.
function parallel.render_to_gif(compiled, dir, workers)
    local effil = load_effil()
    if workers < 1 then
        error("parallel: " .. workers .. " workers cannot draw — "
              .. "one is the floor")
    end

    local size = compiled.canvas.size
    local fps = compiled.canvas.fps
    local dt = 1 / fps
    local total = math.floor(compiled.canvas.length * fps + 0.5)

    -- colors ship to workers as raw float bytes
    local colors = splat.colors_for(compiled.hues)
    local colors_str = ffi.string(colors, #compiled.hues * 3 * 4)

    local jobs = effil.channel()
    local results = effil.channel()
    local crew = {}
    for w = 1, workers do
        crew[w] = effil.thread(worker_main)(
            dir, size, compiled.pal.ramps, compiled.pal.white,
            colors_str, jobs, results)
    end

    -- the sequential heart: tick, freeze, pack, hand off, move on
    local p = pool.new(compiled.capacity)
    local rng = emit.rng(compiled.canvas.seed)
    local snap = splat.snapshot(p.capacity)
    local peak = 0
    for f = 0, total - 1 do
        tracks.step(compiled.timeline, p, rng, f * dt, dt)
        if p.live > peak then peak = p.live end
        splat.take(p, snap)
        local packed, n = parallel.pack_snapshot(snap)
        jobs:push(f + 1, packed, n)
    end
    for _ = 1, workers do
        jobs:push("done")
    end

    -- reassembly by sequence number — the only ordering point
    local compressed = {}
    for _ = 1, total do
        local seq, data = results:pop()
        compressed[seq] = data
    end
    for w = 1, workers do
        local ok, err = crew[w]:wait(), nil
        if ok ~= "completed" then
            _, err = crew[w]:get()
            error("parallel: worker " .. w .. " died: "
                  .. tostring(err))
        end
    end

    local bytes = gif.assemble{
        width = size, height = size,
        palette_bytes = compiled.pal.bytes,
        compressed = compressed,
        delay_cs = math.floor(100 / fps),
    }
    return bytes, { frames = total, peak = peak, workers = workers,
                    bytes = #bytes }
end
-- }}}

return parallel

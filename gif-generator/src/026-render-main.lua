-- 026-render-main.lua — the runner: the program the vision
-- describes, end to end.
--
-- What this is, generally: reads score files from input/, walks each
-- through the whole pipeline — read, wall, sim, snapshot, splat,
-- tone-map, index, encode — and lands finished gifs in output/ with
-- an honest report beside each. The last thing it does is write
-- goodbye. Also usable as a module: the render function is the one
-- true pipeline spine, shared by demos, tests, and the porch's
-- thumbnails.
--
-- Decisions worth knowing more than once:
--   * finished files arrive by rename from a dot-partial in the SAME
--     directory — output/ may live on a different filesystem than
--     the RAM scratch (rename across filesystems fails with EXDEV),
--     and a half-written gif must never be visible under its final
--     name. Failure removes the partial; success renames it in.
--   * stage timers use CPU clock and feed REPORTS ONLY — nothing
--     rendered ever depends on a clock, or determinism would be a
--     lie with good manners.
--   * a scene that fails does not stop its siblings; the exit code
--     remembers everyone's truth (nonzero if anything failed).

local DEFAULT_DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"

-- invoked directly, this file must teach Lua where its siblings
-- live BEFORE asking for any of them; required as a module, the
-- asker has already done so
if arg and arg[0] and arg[0]:find("026%-render%-main") then
    package.path = (arg[1] or DEFAULT_DIR) .. "/src/?.lua;"
                   .. package.path
end

local ffi = require("ffi")
local canvas = require("000-canvas")
local palette = require("002-palette")
local gif = require("004-gif")
local pool = require("006-pool")
local emit = require("008-emit")
local splat = require("012-splat")
local tracks = require("018-tracks")
local score = require("022-score")
local compile = require("024-compile")

local main = {}

-- {{{ function main.render()
-- The pipeline spine: a compiled score in, frames and measured
-- facts out. Everything downstream of the wall lives here, once.
function main.render(compiled)
    local size = compiled.canvas.size
    local fps = compiled.canvas.fps
    local dt = 1 / fps
    local total = math.floor(compiled.canvas.length * fps + 0.5)

    local p = pool.new(compiled.capacity)
    local rng = emit.rng(compiled.canvas.seed)
    local colors = splat.colors_for(compiled.hues)
    local cv = canvas.new(size, size)
    local snap = splat.snapshot(p.capacity)

    local frames = {}
    local peak = 0
    local seats = {}
    local sim_s, draw_s = 0, 0
    for f = 0, total - 1 do
        local t0 = os.clock()
        tracks.step(compiled.timeline, p, rng, f * dt, dt)
        sim_s = sim_s + (os.clock() - t0)
        if p.live > peak then peak = p.live end

        local t1 = os.clock()
        splat.take(p, snap)
        canvas.clear(cv)
        splat.render_snapshot(cv, snap, colors)
        local mapped = canvas.tonemap(cv)
        local frame = ffi.new("uint8_t[?]", size * size)
        for px = 0, size * size - 1 do
            local i = px * 3
            local idx = palette.index_of(compiled.pal, mapped[i],
                                         mapped[i + 1], mapped[i + 2])
            frame[px] = idx
            seats[idx] = true
        end
        frames[#frames + 1] = frame
        draw_s = draw_s + (os.clock() - t1)
    end

    local lit = 0
    for _ in pairs(seats) do lit = lit + 1 end
    return frames, {
        frames = total, peak = peak, capacity = compiled.capacity,
        seats_lit = lit, sim_seconds = sim_s, draw_seconds = draw_s,
    }
end
-- }}}

-- {{{ function main.render_to_gif()
-- Spine plus encoder: compiled score in, gif bytes and facts out.
function main.render_to_gif(compiled)
    local frames, facts = main.render(compiled)
    local t0 = os.clock()
    local bytes = gif.encode{
        width = compiled.canvas.size, height = compiled.canvas.size,
        palette_bytes = compiled.pal.bytes, frames = frames,
        delay_cs = math.floor(100 / compiled.canvas.fps),
    }
    facts.encode_seconds = os.clock() - t0
    facts.bytes = #bytes
    return bytes, facts
end
-- }}}

-- {{{ local function land()
-- The atomic finish: dot-partial in output/, rename on success.
local function land(dir, name, bytes)
    local final = dir .. "/output/" .. name .. ".gif"
    local partial = dir .. "/output/." .. name .. ".partial"
    local f, err = io.open(partial, "wb")
    if not f then
        error("runner: cannot open '" .. partial .. "': "
              .. tostring(err) .. " — does output/ exist?")
    end
    f:write(bytes)
    f:close()
    local ok, ren_err = os.rename(partial, final)
    if not ok then
        os.remove(partial)
        error("runner: could not land '" .. final .. "': "
              .. tostring(ren_err))
    end
    return final
end
-- }}}

-- {{{ local function report()
-- The measured facts beside the gif, as plain readable data lines —
-- the gallery reads these for captions; the statistics utility
-- summarizes them. Nothing here is ever an estimate.
local function report(dir, name, facts)
    local path = dir .. "/output/" .. name .. ".report"
    local f = assert(io.open(path, "w"))
    f:write("scene: ", name, "\n")
    f:write("frames: ", facts.frames, "\n")
    f:write("bytes: ", facts.bytes, "\n")
    f:write("peak_particles: ", facts.peak, "\n")
    f:write("pool_capacity: ", facts.capacity, "\n")
    f:write("palette_seats_lit: ", facts.seats_lit, "\n")
    f:write(string.format("sim_seconds: %.3f\n", facts.sim_seconds))
    f:write(string.format("draw_seconds: %.3f\n", facts.draw_seconds))
    f:write(string.format("encode_seconds: %.3f\n",
                          facts.encode_seconds))
    f:close()
end
-- }}}

-- {{{ local function log_line()
-- Render history streams to the RAM log tier. A missing tier means
-- bootstrap has not run on this machine since boot — say so, stop.
local function log_line(dir, text)
    local f = io.open(dir .. "/tmp/shared-memory/render.log", "a")
    if not f then
        error("runner: cannot write the render log — the RAM tiers "
              .. "are missing; run ./bootstrap first")
    end
    f:write(text, "\n")
    f:close()
end
-- }}}

-- {{{ local function discover()
-- Every score in input/ (read-only listing). Names come back bare,
-- without directory or extension.
local function discover(dir)
    local names = {}
    local ls = io.popen("ls -1 '" .. dir .. "/input/'")
    for entry in ls:lines() do
        local name = entry:match("^(.+)%.lua$")
        if name then names[#names + 1] = name end
    end
    ls:close()
    return names
end
-- }}}

-- {{{ function main.run()
-- The front door: render one named scene, or everything in input/.
function main.run(dir, wanted)
    local names
    if wanted then
        names = { (wanted:gsub("%.lua$", "")) }
    else
        names = discover(dir)
        if #names == 0 then
            error("runner: input/ holds no scores — write one, or "
                  .. "start from input/orbit.lua in the repository")
        end
    end

    local failures = 0
    local landed = {}
    for _, name in ipairs(names) do
        local ok, err = pcall(function()
            local raw = score.read(dir .. "/input/" .. name .. ".lua")
            local compiled = compile.score(raw)
            local bytes, facts = main.render_to_gif(compiled)
            local final = land(dir, name, bytes)
            report(dir, name, facts)
            log_line(dir, name .. ": " .. facts.bytes .. " bytes, "
                     .. facts.frames .. " frames, peak "
                     .. facts.peak .. " particles")
            print(name .. ": " .. final)
            print(string.format(
                "  %d frames, %d bytes, peak %d of %d particles, "
                .. "%d palette seats", facts.frames, facts.bytes,
                facts.peak, facts.capacity, facts.seats_lit))
            landed[#landed + 1] = name
        end)
        if not ok then
            failures = failures + 1
            print(err)
        end
    end

    -- the last act: goodbye — what was made, and what was not
    local bye = io.open(dir .. "/output/goodbye", "w")
    if bye then
        bye:write("goodbye — rendered ", #landed, " of ", #names,
                  " score(s)")
        if #landed > 0 then
            bye:write(": ", table.concat(landed, ", "))
        end
        bye:write("\n")
        bye:close()
    end

    if failures > 0 then os.exit(1) end
end
-- }}}

-- Run as a program when invoked directly; stay quiet as a module.
-- (arg[0] is the invoked script's own path only in that case.)
if arg and arg[0] and arg[0]:find("026%-render%-main") then
    local dir = arg[1] or DEFAULT_DIR
    main.run(dir, arg[2])
end

return main

-- 053-two-spaces.lua - renders a two-space score: shapes in a world, and
-- strokes of light painted onto panes of glass, in one frame.
--
-- What this is, generally: the runner's spine (026-render-main.lua) hands
-- a compiled score here when it has a second space (issue 701d) -- shapes,
-- panes besides the front one, or a background. Each frame:
--   1. the world is drawn at this moment of its loop (052-frame.lua), and
--      every shape a stroke follows is found on the picture;
--   2. each pane's strokes paint their light onto the pane, exactly as a
--      stroke-only score paints onto its canvas;
--   3. the world panes are laid into the world's depth, and the frame is
--      composed: all light summed, tone-mapped once, added to the shapes'
--      colour, indexed once through the house palette.
-- The runner then encodes the frames once, as it does every score.
--
-- Decisions worth knowing more than once:
--   * the world's loop is the score's length: frame f of F is the world at
--     f/F, the same moment the shape films draw, so a score that only has
--     shapes films the very bytes of the scene it came from.
--   * the strokes' clock is the stroke-only scores' clock (frame f is
--     f/fps seconds); each pane has its own random stream, and the front
--     pane keeps the canvas's seed.

local ffi = require("ffi")
local canvas = require("000-canvas")
local palette = require("002-palette")
local pool = require("006-pool")
local emit = require("008-emit")
local splat = require("012-splat")
local tracks = require("018-tracks")
local frame = require("052-frame")

local two_spaces = {}

-- {{{ local function fill_constant()
-- Every pixel of a light plane set to one colour of light.
local function fill_constant(plane, n, light)
    for p = 0, n - 1 do
        plane[p * 3], plane[p * 3 + 1], plane[p * 3 + 2] = light[1], light[2], light[3]
    end
end
-- }}}

-- {{{ local function add_plane()
-- One light plane added into another of the same size.
local function add_plane(into, from, n)
    for i = 0, n * 3 - 1 do into[i] = into[i] + from[i] end
end
-- }}}

-- {{{ function two_spaces.render()
-- A compiled two-space score in; frames and measured facts out, as
-- main.render gives them.
function two_spaces.render(compiled)
    local studio = compiled.studio
    local size = compiled.canvas.size
    local fps = compiled.canvas.fps
    local dt = 1 / fps
    local total = studio.frames
    local pixels = size * size
    local pal = compiled.pal
    local function index_of(r, g, b) return palette.index_of(pal, r, g, b) end

    -- the world's painter, when there is a world
    local three = studio.three
    local raster = three and three.raster
    local rc = studio.world and raster.new(size, studio.world.camera or {}, three.meshes)

    -- each pane with strokes: its own pool, stream, snapshot and light
    local painted = {}
    for _, pane in ipairs(studio.panes) do
        if pane.strokes > 0 then
            pane.pool = pool.new(pane.capacity)
            pane.rng = emit.rng(pane.seed)
            pane.colors = splat.colors_for(pane.hues)
            pane.cv = canvas.new(pane.width, pane.height)
            pane.snap = splat.snapshot(pane.capacity)
            painted[#painted + 1] = pane
        end
    end

    local tm = canvas.new(size, size)
    local front = ffi.new("float[?]", pixels * 3)
    local back = ffi.new("float[?]", pixels * 3)
    local gathered = rc and ffi.new("float[?]", rc.W * rc.W * 3)
    local has_back, has_world_panes = studio.background ~= nil, false
    for _, pane in ipairs(painted) do
        if pane.place == "back" then has_back = true end
        if pane.place == "world" then has_world_panes = true end
    end

    local frames = {}
    local peak = 0
    local seats = {}
    local sim_s, draw_s = 0, 0
    for f = 0, total - 1 do
        local t1 = os.clock()
        -- the world at this moment, and where its followed shapes appear
        if rc then
            local placed = frame.draw_world(rc, raster, three.choreography, studio.world, f / total)
            for tag, cell in pairs(studio.landmarks) do
                cell[1], cell[2] = frame.landmark(rc, raster, placed, tag, size)
            end
        end
        draw_s = draw_s + (os.clock() - t1)

        -- every pane's strokes, on its own clock-step
        local t0 = os.clock()
        for _, pane in ipairs(painted) do
            tracks.step(pane.timeline, pane.pool, pane.rng, f * dt, dt)
        end
        sim_s = sim_s + (os.clock() - t0)

        local t2 = os.clock()
        local live = 0
        if studio.background then fill_constant(back, pixels, studio.background)
        elseif has_back then ffi.fill(back, pixels * 3 * 4) end
        ffi.fill(front, pixels * 3 * 4)
        if gathered then ffi.fill(gathered, rc.W * rc.W * 3 * 4) end
        for _, pane in ipairs(painted) do
            live = live + pane.pool.live
            splat.take(pane.pool, pane.snap)
            canvas.clear(pane.cv)
            splat.render_snapshot(pane.cv, pane.snap, pane.colors)
            if pane.place == "front" then
                add_plane(front, pane.cv.energy, pixels)
            elseif pane.place == "back" then
                add_plane(back, pane.cv.energy, pixels)
            else
                frame.gather_pane(rc, raster, gathered, pane)
            end
        end
        if live > peak then peak = live end

        local out = ffi.new("uint8_t[?]", pixels)
        frame.compose{
            rc = rc, gathered = has_world_panes and gathered or nil,
            back = has_back and back or nil, front = front,
            tm = tm, tonemap = canvas.tonemap, out = out, index_of = index_of,
        }
        for px = 0, pixels - 1 do seats[out[px]] = true end
        frames[#frames + 1] = out
        draw_s = draw_s + (os.clock() - t2)
    end

    local capacity = 0
    for _, pane in ipairs(painted) do capacity = capacity + pane.capacity end
    local lit = 0
    for _ in pairs(seats) do lit = lit + 1 end
    return frames, {
        frames = total, peak = peak, capacity = capacity,
        seats_lit = lit, sim_seconds = sim_s, draw_seconds = draw_s,
    }
end
-- }}}

return two_spaces

#!/usr/bin/env luajit
-- 039-shape-films.lua - renders the shape films: animations of solid shapes.
--
-- What this is, generally: the 3D half of this studio, first made for the
-- repository's front page. Each animation is a short scene written as plain data -- which
-- shapes, how they move, what they do when they meet -- and this program
-- films it as a looping GIF in the house look: black ground, bright colour.
-- The finished films are candidates; a person approves each one before it is
-- used anywhere.
--
-- How, generally: three separate workers pass the film along. The stage
-- manager (035-choreography.lua) says where every shape is at each moment.
-- The painter (036-raster.lua) draws that moment, in the order the frame
-- (052-frame.lua) keeps for every film and two-space score alike. This project's own encoder
-- and palette (004-gif.lua, 002-palette.lua) pack the drawings into a GIF.
--
-- Usage:
--   039-shape-films.lua [DIR] [scene ...] [--out=DIR] [--still] [--stills=DIR] [--frames=N]
--     DIR        the gif-generator project (default below); scenes live in
--                its input/shapes/
--     scene      a scene name from input/shapes/, or a path to a .lua scene
--                file; none means every scene in input/shapes/
--     --out=     where the GIFs go (default: RAM, the candidates folder)
--     --still    also save the first frame of each as a PNG (beside the GIF)
--     (every film gets a card beside it, NAME.gif.card: what made it and its
--     ratings; see 055-cards.lua and docs/card-format.md)
--     --stills=  save those PNGs in this folder instead (implies --still)
--     --frames=  override the frame count (tests use it to render quickly)
--     --jobs=N   split each film's frames across N worker processes, at most 4 (a
--                scene may ask for this itself with `jobs = N`); the frames
--                are reassembled in order, byte-identical to one process
--     --shard=k/N, --shard-dir=  (used by those workers: draw every Nth frame
--                starting at k, and leave each compressed frame in the folder)

-- {{{ DIR Configuration
-- Hard-coded so the tool runs from any directory; a first argument that is
-- a directory replaces it. Everything else is found relative to DIR.
local DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"
local arguments = {}
for _, a in ipairs(arg) do arguments[#arguments + 1] = a end
do
    local first = arguments[1]
    if first and not first:match("^%-%-") and not first:match("%.lua$") then
        local probe = io.open(first .. "/input/shapes", "r")
        if probe then
            probe:close()
            DIR = first
            table.remove(arguments, 1)
        end
    end
end
local SRC = DIR .. "/src"
local OUT_DEFAULT = "/dev/shm/gif-generator/shape-film-candidates"
-- The most worker processes one film may use at once.
local MAX_WORKERS = 4
-- }}}

local meshes = dofile(SRC .. "/034-meshes.lua")
local choreography = dofile(SRC .. "/035-choreography.lua")
local raster = dofile(SRC .. "/036-raster.lua")
local png = dofile(SRC .. "/038-png.lua")
local fluid = dofile(SRC .. "/037-fluid.lua")
local scene_file = dofile(SRC .. "/045-scene-file.lua")
local frame_parts = dofile(SRC .. "/052-frame.lua")
local cards = dofile(SRC .. "/055-cards.lua")
local gif = dofile(SRC .. "/004-gif.lua")
local palette = dofile(SRC .. "/002-palette.lua")
local ffi = require("ffi")

-- Every film declares the whole hue vocabulary, in one fixed order, so the
-- palette's seats are the same in every GIF of the gallery and shards can
-- take any rainbow colour.
local ALL_HUES = { "rose", "ember", "gold", "jade", "teal", "ice", "violet" }

-- {{{ local function parse_options()
local function parse_options(list)
    local options = { scenes = {}, out = OUT_DEFAULT, still = false }
    local handlers = {
        -- {{{ --out=
        out = function(value) options.out = value end,
        -- }}}
        -- {{{ --frames=
        frames = function(value)
            options.frames = tonumber(value)
            if not options.frames then error("--frames= needs a number", 0) end
        end,
        -- }}}
        -- {{{ --still
        still = function() options.still = true end,
        -- }}}
        -- {{{ --jobs=
        jobs = function(value)
            options.jobs = tonumber(value)
            if not options.jobs or options.jobs < 1 or options.jobs % 1 ~= 0 then
                error("--jobs= needs a whole number of workers, at least 1", 0)
            end
        end,
        -- }}}
        -- {{{ --shard=
        shard = function(value)
            local k, n = value:match("^(%d+)/(%d+)$")
            if not k then error("--shard= needs k/N", 0) end
            options.shard_k, options.shard_n = tonumber(k), tonumber(n)
        end,
        -- }}}
        -- {{{ --shard-dir=
        ["shard-dir"] = function(value) options.shard_dir = value end,
        -- }}}
        -- {{{ --stills=
        stills = function(value)
            if value == "" then error("--stills= needs a folder", 0) end
            options.still, options.stills = true, value
        end,
        -- }}}
    }
    for _, a in ipairs(list) do
        local key, value = a:match("^%-%-([%w%-]+)=?(.*)$")
        if key then
            if not handlers[key] then error("unknown option --" .. key, 0) end
            handlers[key](value)
        else
            options.scenes[#options.scenes + 1] = a
        end
    end
    return options
end
-- }}}

-- {{{ local function scene_path()
-- A bare name means input/shapes/<name>.lua; anything ending in .lua is a path.
local function scene_path(name)
    if name:match("%.lua$") then return name end
    return DIR .. "/input/shapes/" .. name .. ".lua"
end
-- }}}

-- {{{ local function all_scene_names()
local function all_scene_names()
    local names = {}
    local pipe = io.popen(string.format("ls %q", DIR .. "/input/shapes"))
    for line in pipe:lines() do
        local name = line:match("^(.+)%.lua$")
        if name then names[#names + 1] = name end
    end
    pipe:close()
    table.sort(names)
    return names
end
-- }}}

-- {{{ local function palette_rgb_string()
-- The palette-indexed frame as plain RGB bytes, for the PNG still.
local function palette_rgb_string(pal, indices, count)
    local bytes = ffi.new("uint8_t[?]", count * 3)
    for i = 0, count - 1 do
        local seat = indices[i] * 3
        bytes[i * 3], bytes[i * 3 + 1], bytes[i * 3 + 2] =
            pal.bytes[seat], pal.bytes[seat + 1], pal.bytes[seat + 2]
    end
    return ffi.string(bytes, count * 3)
end
-- }}}

-- {{{ local function film()
-- One scene, start to finish. Returns the byte count written.
local function film(name, options)
    local path = scene_path(name)
    local scene = scene_file.read(path)
    if options.frames then scene.frames = options.frames end

    local hue_table = {}
    for _, hue in ipairs(ALL_HUES) do hue_table[hue] = { palette.hue_color(hue) } end
    -- "cloud" is white light. It needs no ramp of its own: the palette's
    -- indexer sends anything this unsaturated to its shared white ramp, the
    -- one kept for white-hot cores.
    hue_table.cloud = { 1, 1, 1 }
    choreography.load(scene, hue_table, meshes, fluid)

    local pal = palette.build(ALL_HUES)
    -- {{{ local function index_of()
    local function index_of(r, g, b) return palette.index_of(pal, r, g, b) end
    -- }}}
    local canvas = raster.new(scene.size, scene.camera or {}, meshes)
    local pixel_count = scene.size * scene.size

    -- {{{ local function draw_frame()
    -- One frame, drawn and compressed; frame 1 also leaves the still.
    local function draw_frame(frame)
        local t = (frame - 1) / scene.frames
        frame_parts.draw_world(canvas, raster, choreography, scene, t)
        local indices = raster.finish(canvas, index_of)
        if frame == 1 and options.still then
            local still = png.encode(scene.size, scene.size, palette_rgb_string(pal, indices, pixel_count))
            local handle = assert(io.open((options.stills or options.out) .. "/" .. scene.name .. ".png", "wb"))
            handle:write(still)
            handle:close()
        end
        return gif.compress_frame(indices, pixel_count)
    end
    -- }}}

    -- Three ways to film. As a worker: draw only this worker's share of the
    -- frames (every Nth, from k), leave each in the shard folder, and stop.
    -- As the head of a team: start the workers side by side, wait, then
    -- gather their frames in order -- frames do not depend on each other,
    -- so the film is byte-identical to one drawn alone. Alone: every frame.
    -- never more than MAX_WORKERS at once, whatever is asked (the owner's
    -- limit, 2026-09-26: "use up to 4 threads")
    local jobs = math.min(options.jobs or scene.jobs or 1, MAX_WORKERS)
    local compressed = {}
    if options.shard_n then
        for frame = 1 + options.shard_k, scene.frames, options.shard_n do
            local handle = assert(io.open(string.format("%s/frame-%05d.bin", options.shard_dir, frame), "wb"))
            handle:write(draw_frame(frame))
            handle:close()
        end
        return 0
    elseif jobs > 1 then
        local shard_dir = string.format("/dev/shm/gif-generator/shape-film-shards/%s-%d-%d", scene.name, os.time(), math.random(1e6))
        os.execute(string.format("mkdir -p %q", shard_dir))
        local commands = {}
        for k = 0, jobs - 1 do
            local parts = { "luajit", string.format("%q", SRC .. "/039-shape-films.lua"), string.format("%q", DIR),
                            string.format("%q", path), "--shard=" .. k .. "/" .. jobs,
                            string.format("--shard-dir=%q", shard_dir), string.format("--out=%q", options.out) }
            if options.frames then parts[#parts + 1] = "--frames=" .. options.frames end
            if options.still then parts[#parts + 1] = "--still" end
            if options.stills then parts[#parts + 1] = string.format("--stills=%q", options.stills) end
            commands[#commands + 1] = table.concat(parts, " ") .. " &"
        end
        os.execute(table.concat(commands, " ") .. " wait")
        for frame = 1, scene.frames do
            local handle = io.open(string.format("%s/frame-%05d.bin", shard_dir, frame), "rb")
            if not handle then error("a worker left no frame " .. frame .. " in " .. shard_dir, 0) end
            compressed[frame] = handle:read("*a")
            handle:close()
        end
        os.execute(string.format("rm -r %q", shard_dir))
    else
        for frame = 1, scene.frames do compressed[frame] = draw_frame(frame) end
    end

    local bytes = gif.assemble{
        width = scene.size, height = scene.size, palette_bytes = pal.bytes,
        compressed = compressed, delay_cs = scene.delay_cs or 4,
    }
    local target = options.out .. "/" .. scene.name .. ".gif"
    local handle = assert(io.open(target, "wb"))
    handle:write(bytes)
    handle:close()
    -- every film keeps a card beside it (issue 701e): what made it, and
    -- its ratings; a film made again with new bytes is told so on its card
    local card
    if path == scene_path(scene.name) then
        card = cards.what_made(DIR, scene.name .. ".gif")
    else
        card = { category = "shapes", score = path, seed = "none", about = cards.about(path) }
    end
    card.size, card.frames = scene.size, scene.frames
    cards.film_made(target, card, options.approved)
    print(string.format("%-22s %4d frames  %4dx%-4d  %8d bytes  %s",
        scene.name, scene.frames, scene.size, scene.size, #bytes, target))
    return #bytes
end
-- }}}

-- {{{ local function main()
local function main()
    local options = parse_options(arguments)
    options.approved = cards.approved(DIR)
    os.execute(string.format("mkdir -p %q", options.out))
    if options.stills then os.execute(string.format("mkdir -p %q", options.stills)) end
    local names = #options.scenes > 0 and options.scenes or all_scene_names()
    for _, name in ipairs(names) do film(name, options) end
end
-- }}}

-- A refusal (unknown shape, fractional cycle, missing option value) prints
-- as one plain line; anything else keeps its traceback.
local ok, failure = xpcall(main, function(message)
    if type(message) == "string" and not message:match("^[^\n]*:%d+:") then return message end
    return debug.traceback(message, 2)
end)
if not ok then
    io.stderr:write("shape-films: " .. tostring(failure) .. "\n")
    os.exit(1)
end

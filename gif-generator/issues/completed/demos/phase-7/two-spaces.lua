-- two-spaces.lua — the phase-7 demo: one canvas, two spaces, shown
-- rather than told.
--
-- What this is, generally: takes one score that speaks both vocabularies
-- (meeting.lua: two shapes in a world, strokes of light painted on panes
-- of glass, two strokes following the shapes across the picture), proves
-- it passes the wall, and films it three ways: the shapes alone, the light
-- alone, and both. The three are also laid side by side in one film, so
-- the composition can be watched frame by frame. Every number printed is
-- measured this run. Each film keeps a card, and the pool is counted from
-- the cards.
--
-- Usage: luajit two-spaces.lua [DIR]   (DIR = the gif-generator project)
-- The films land beside this file.

local DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"
if arg and arg[1] then DIR = arg[1] end
package.path = DIR .. "/src/?.lua;" .. package.path

local ffi = require("ffi")
local gif = require("004-gif")
local palette = require("002-palette")
local score = require("022-score")
local compile = require("024-compile")
local two_spaces = require("053-two-spaces")
local stats = require("030-stats")
local cards = dofile(DIR .. "/src/055-cards.lua")

local HERE = DIR .. "/issues/completed/demos/phase-7"
local SCORE = HERE .. "/meeting.lua"
local LIBRARY = "/home/ritz/pictures/shape-gifs"
local GAP = 4 -- black pixels between the three halves

-- {{{ local function land()
-- Bytes to a film beside this file, with its card.
local function land(name, bytes, card)
    local path = HERE .. "/" .. name .. ".gif"
    local handle = assert(io.open(path, "wb"))
    handle:write(bytes)
    handle:close()
    card.about = card.about or cards.about(SCORE)
    cards.film_made(path, card)
    return path
end
-- }}}

-- {{{ local function film()
-- One way of filming the score: its frames, its bytes, and what it took.
local function film(compiled, show)
    local t0 = stats.wall()
    local frames, facts = two_spaces.render(compiled, show)
    local t1 = os.clock()
    local bytes = gif.encode{
        width = compiled.canvas.size, height = compiled.canvas.size,
        palette_bytes = compiled.pal.bytes, frames = frames,
        delay_cs = math.floor(100 / compiled.canvas.fps),
    }
    facts.encode_seconds = os.clock() - t1
    facts.wall_seconds = stats.wall() - t0
    facts.bytes = #bytes
    return frames, bytes, facts
end
-- }}}

-- {{{ local function say()
local function say(label, facts)
    print(string.format("  %-11s %d frames, %d bytes, %d palette seats lit, peak %d particles",
        label, facts.frames, facts.bytes, facts.seats_lit, facts.peak))
    print(string.format("  %-11s sim %.2f s, draw %.2f s, encode %.2f s (%.2f s wall)",
        "", facts.sim_seconds, facts.draw_seconds, facts.encode_seconds, facts.wall_seconds))
end
-- }}}

-- {{{ local function side_by_side()
-- The three halves' frames laid left to right in one wider frame.
local function side_by_side(size, black, ...)
    local sets = { ... }
    local width = size * #sets + GAP * (#sets - 1)
    local frames = {}
    for f = 1, #sets[1] do
        local wide = ffi.new("uint8_t[?]", width * size)
        ffi.fill(wide, width * size, black)
        for k, set in ipairs(sets) do
            local left = (k - 1) * (size + GAP)
            for y = 0, size - 1 do
                ffi.copy(wide + y * width + left, set[f] + y * size, size)
            end
        end
        frames[f] = wide
    end
    return frames, width
end
-- }}}

print("— the score, at the wall —")
local raw = score.read(SCORE)
local compiled = compile.score(raw)
local studio = compiled.studio
local followed = {}
for tag in pairs(studio.landmarks) do followed[#followed + 1] = tag end
table.sort(followed)
print(string.format("  meeting.lua passes: %d shapes, %d strokes on %d panes, %d shapes followed (%s)",
    #raw.shapes, #raw.strokes, #studio.panes, #followed, table.concat(followed, ", ")))

print("— three ways of filming it —")
local world_frames, world_bytes, world_facts = film(compile.score(score.read(SCORE)), "world")
say("the shapes", world_facts)
local light_frames, light_bytes, light_facts = film(compile.score(score.read(SCORE)), "light")
say("the light", light_facts)
local both_frames, both_bytes, both_facts = film(compiled, nil)
say("both", both_facts)

local size = compiled.canvas.size
local black = palette.index_of(compiled.pal, 0, 0, 0)
local wide, width = side_by_side(size, black, world_frames, light_frames, both_frames)
local halves = gif.encode{
    width = width, height = size, palette_bytes = compiled.pal.bytes,
    frames = wide, delay_cs = math.floor(100 / compiled.canvas.fps),
}
print(string.format("  side by side: %d by %d, %d bytes", width, size, #halves))

print("— landed, each with its card —")
local made = { category = "two spaces", score = "issues/completed/demos/phase-7/meeting.lua",
               seed = compiled.canvas.seed, frames = both_facts.frames }
local function card(extra)
    local c = {}
    for k, v in pairs(made) do c[k] = v end
    for k, v in pairs(extra) do c[k] = v end
    return c
end
for _, path in ipairs({
    land("meeting", both_bytes, card{ size = size }),
    land("meeting-shapes", world_bytes, card{ size = size,
        about = "the shapes of meeting.lua alone: no pane's light, no background glow" }),
    land("meeting-light", light_bytes, card{ size = size,
        about = "the light of meeting.lua alone: the shapes hide and show it, but are not drawn" }),
    land("meeting-side-by-side", halves, card{ size = width .. "x" .. size,
        about = "meeting.lua three ways, left to right: the shapes, the light, both" }),
}) do
    print("  " .. path)
end

print("— the pool, counted from the cards —")
for _, folder in ipairs({ LIBRARY, HERE }) do
    local probe = io.open(folder, "r")
    if probe then
        probe:close()
        print(cards.describe(cards.counts(folder), folder))
    else
        print("  (" .. folder .. " isn't on this machine)")
    end
end

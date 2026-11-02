-- 156-checking-frames-and-moves.lua
--
-- Checks issue 806, step 1: frame N of a move is where the arithmetic
-- says — from + (N - start) / (stop - start) of the way to `to`, held
-- before and after — worked out from the frame number alone, the same in
-- any order; moves are checked through the wall; the .mp4 paintbrush's
-- document matches its table.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local motion = require("155-the-motion")
local wall = require("151-the-wall")

local canvas = table.concat({
    'canvas{ category = "clip", width = 200, height = 100 }',
    'frames{ count = 11 }',
    'rate{ per_second = 10 }',
    'surface{ name = "dot", points = { {0, 0}, {10, 0}, {10, 10}, {0, 10} }, colour = {0, 0, 0} }',
    'surface{ name = "home", points = { {100, 50}, {110, 50}, {110, 60} } }',
    'arrow{ from = "dot", to = "home" }',
    'move{ word = "dot", field = "offset", from = {0, 0}, to = {100, 40} }',
    'move{ word = "dot", field = "colour", from = {0, 0, 0}, to = {255, 100, 10}, start = 2, stop = 6 }',
}, "\n")
local clip, findings = motion.read(canvas)
kit.check(clip ~= nil, "a clip canvas reads: " .. tostring(findings and wall.text(findings[1])))
kit.equal(clip.count, 11, "its frame count")
kit.equal(clip.rate, 10, "its rate")
kit.equal(#clip.moves, 2, "both moves")
kit.equal(clip.moves[1].stop, 10, "a move with no stop runs to the last frame")

for n = 0, 10 do
    local f = motion.frame(clip, n)
    local t = n / 10
    kit.equal(f.xs[1], 100 * t, "frame " .. n .. ": the dot's corner is " .. n .. "/10 of the way across")
    kit.equal(f.ys[3], 10 + 40 * t, "frame " .. n .. ": and down")
end

local function colour_at(n)
    return table.concat(motion.frame(clip, n).surfaces.colour[1], ",")
end
kit.equal(colour_at(0), "0,0,0", "before its start, a colour move holds its from")
kit.equal(colour_at(2), "0,0,0", "on its start frame, its from")
kit.equal(colour_at(4), "128,50,5", "halfway (frame 4 of 2 to 6): half of each channel, rounded")
kit.equal(colour_at(6), "255,100,10", "on its stop frame, its to")
kit.equal(colour_at(9), "255,100,10", "after its stop, its to")

local f5 = motion.frame(clip, 5)
kit.equal(f5.arrows.x1[1], 5 + 50, "an arrow from a moving surface follows it")
kit.equal(f5.arrows.x2[1], clip.still.arrows.x2[1], "its other end stays")
kit.equal(clip.still.xs[1], 0, "working out a frame never changes the still")
kit.equal(clip.still.arrows.x1[1], 5, "nor its arrows")

local forward, backward = {}, {}
for n = 0, 10 do forward[n] = motion.frame(clip, n).xs[2] .. "/" .. colour_at(n) end
for n = 10, 0, -1 do backward[n] = motion.frame(clip, n).xs[2] .. "/" .. colour_at(n) end
local same = true
for n = 0, 10 do same = same and forward[n] == backward[n] end
kit.check(same, "frames worked out in any order are the same: each depends on its number alone")

kit.equal(motion.fraction({ start = 3, stop = 3 }, 3), 1, "a move whose start is its stop jumps")
kit.raises(function() motion.frame(clip, 11) end, "outside 0 to 10", "a frame past the last is refused")

local function first(text)
    local _, f = motion.read(text)
    return f and wall.text(f[1]) or "(none)"
end
local head = 'canvas{ category = "clip" }\nframes{ count = 5 }\nsurface{ name = "dot", points = { {0, 0}, {1, 0}, {1, 1} } }\n'
kit.check(first(head .. 'move{ word = "dto", field = "offset", from = {0, 0}, to = {1, 1} }'):find("no surface has that name; did you mean 'dot'", 1, true) ~= nil,
    "a move naming no surface is a finding with the nearest")
kit.check(first(head .. 'move{ word = "dot", field = "colur", from = {0, 0}, to = {1, 1} }'):find("did you mean 'colour'", 1, true) ~= nil,
    "an unknown field is a finding with the nearest")
kit.check(first(head .. 'move{ word = "dot", field = "colour", from = {0, 0}, to = {1, 1} }'):find("'from' wants {r, g, b}", 1, true) ~= nil,
    "a colour move given points is a finding")
kit.check(first(head .. 'move{ word = "dot", field = "offset", from = {0, 0}, to = {1, 1}, stop = 9 }'):find("frames run 0 to 4", 1, true) ~= nil,
    "a move past the last frame is a finding")
kit.check(first(head .. 'move{ word = "dot", field = "offset", from = {0, 0}, to = {1, 1}, start = 4, stop = 2 }'):find("after it stops", 1, true) ~= nil,
    "a move that starts after it stops is a finding")
kit.check(first('canvas{ category = "clip" }\n'):find("needs one frames", 1, true) ~= nil, "a clip with no frames{} is refused")
kit.check(first('canvas{ category = "clip" }\nframes{ count = 2 }\nmove{ word = "x", field = "offset", from = {0, 0}, to = {1, 1} }\nmvoe{}'):find(":3:", 1, true) ~= nil,
    "findings come in line order")

kit.equal(kit.fs.read(kit.DIR .. "/docs/paintbrush-mp4.md"), wall.document(motion.MP4),
    "the committed docs/paintbrush-mp4.md is exactly what the table generates")
for name in pairs(wall.PNG.words) do
    kit.check(motion.MP4.words[name] ~= nil, "the .mp4 paintbrush has the .png word " .. name)
end

kit.finish()

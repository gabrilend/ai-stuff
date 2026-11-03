-- 155-the-motion.lua
--
-- The .mp4 end's motion (docs/067, issue 806, step 1): the `.png` words
-- plus `frames`, `rate` and `move{ word = …, field = …, from = …, to = … }`.
-- Every moment is worked out from the frame number, never the clock: frame
-- n of a move is its `from` plus (n - start) / (stop - start) of the way to
-- its `to`, held at `from` before `start` and at `to` after `stop`. So the
-- same canvas gives the same frames whoever paints them, in any order, on
-- one worker or many (806's step 2). Painting each frame is the .png
-- painter's (803); encoding is ffmpeg's and the house GIF encoder's (step 3).

local wall = require("151-the-wall")

local motion = {}

-- What a move may change on a named surface: its colour, or an offset
-- added to every one of its points.
motion.FIELDS = { "colour", "offset" }

-- {{{ local function copy_words
local function copy_words(words)
    local out = {}
    for k, v in pairs(words) do
        out[k] = v
    end
    return out
end
-- }}}

-- The `.mp4` paintbrush: the `.png` paintbrush's words, plus three.
motion.MP4 = {
    name = "mp4",
    source = "src/155-the-motion.lua",
    words = copy_words(wall.PNG.words),
}
motion.MP4.words.frames = {
    doc = "how many frames the clip has", once = true, required = true,
    order = { "count" },
    fields = { count = { type = "positive", required = true, doc = "frames, numbered from 0" } },
}
motion.MP4.words.rate = {
    doc = "how many frames make a second", once = true,
    order = { "per_second" },
    fields = { per_second = { type = "positive", default = 30, doc = "frames a second" } },
}
motion.MP4.words.move = {
    doc = "a named surface's colour or offset, moving from one value to another over frames",
    order = { "word", "field", "from", "to", "start", "stop" },
    fields = {
        word = { type = "name", required = true, doc = "the name of the surface that moves" },
        field = { type = { doc = "one of " .. table.concat(motion.FIELDS, ", "), check = function(v)
            for _, f in ipairs(motion.FIELDS) do
                if v == f then return nil end
            end
            return "wants one of " .. table.concat(motion.FIELDS, ", ") .. ", got '" .. tostring(v) .. "'", wall.nearest(v, motion.FIELDS)
        end }, required = true, doc = "what moves: `colour` (from and to are colours) or `offset` (points)" },
        from = { type = { doc = "a colour or a point, as `field` says", check = function(v)
            if type(v) ~= "table" then return "wants a colour or a point" end
        end }, required = true, doc = "the value at `start` and before" },
        to = { type = { doc = "a colour or a point, as `field` says", check = function(v)
            if type(v) ~= "table" then return "wants a colour or a point" end
        end }, required = true, doc = "the value at `stop` and after" },
        start = { type = "whole", default = 0, doc = "the frame the move begins on" },
        stop = { type = "whole", default = "last", doc = "the frame the move ends on; the last frame when absent" },
    },
}

-- {{{ function motion.read
-- A `.mp4` canvas's text through the wall: { still = the compiled canvas
-- (151's compile, its .png words), count, rate, moves }, or nil and every
-- finding — the wall's, and a move naming no surface, a value that does
-- not fit its field, or frames out of range.
function motion.read(text, where)
    local words, findings = wall.load(text, motion.MP4, where)
    local still, more = wall.compile(words)
    for _, f in ipairs(more) do
        findings[#findings + 1] = f
    end
    local count, rate = 1, 30
    for _, w in ipairs(words) do
        if w.word == "frames" and w.fields.count then count = w.fields.count end
        if w.word == "rate" then rate = w.fields.per_second end
    end
    local surface_names = {}
    for name in pairs(still.names) do
        surface_names[#surface_names + 1] = name
    end
    table.sort(surface_names)
    local moves = {}
    for _, w in ipairs(words) do
        local f = w.fields
        if w.word == "move" and f.word and f.field and f.from and f.to then
            local ok = true
            local function bad(message, suggestion)
                findings[#findings + 1] = { line = w.line, word = "move", message = message, suggestion = suggestion }
                ok = false
            end
            local index = still.names[f.word]
            if not index or index < 1 then
                bad("'word' names '" .. f.word .. "', and no surface has that name", wall.nearest(f.word, surface_names))
            end
            local kind = f.field == "colour" and "colour" or "point"
            for _, which in ipairs({ "from", "to" }) do
                local wrong = wall.TYPES[kind].check(f[which])
                if wrong then
                    bad("'" .. which .. "' " .. wrong .. " (field '" .. f.field .. "')")
                end
            end
            if kind == "colour" and f.from and f.to and #f.from ~= #f.to then
                bad("'from' and 'to' must both be {r, g, b} or both {r, g, b, a}")
            end
            local stop = f.stop == "last" and (count - 1) or f.stop
            if f.start > stop then
                bad("starts on frame " .. f.start .. ", after it stops on frame " .. stop)
            end
            if stop > count - 1 then
                bad("stops on frame " .. stop .. ", but the frames run 0 to " .. (count - 1))
            end
            if ok then
                moves[#moves + 1] = { surface = index, field = f.field, from = f.from, to = f.to, start = f.start, stop = stop }
            end
        end
    end
    if #findings > 0 then
        for i, x in ipairs(findings) do x.order = i end
        table.sort(findings, function(a, b)
            if (a.line or 0) ~= (b.line or 0) then return (a.line or 0) < (b.line or 0) end
            return a.order < b.order
        end)
        return nil, findings
    end
    return { still = still, count = count, rate = rate, moves = moves }
end
-- }}}

-- {{{ function motion.fraction
-- How far through a move frame n is: 0 at and before `start`, 1 at and
-- after `stop`, linear between. A move whose start is its stop jumps.
function motion.fraction(move, n)
    if n <= move.start then
        return move.start == move.stop and 1 or 0
    end
    if n >= move.stop then
        return 1
    end
    return (n - move.start) / (move.stop - move.start)
end
-- }}}

-- {{{ local function between
local function between(from, to, t, round)
    local out = {}
    for i = 1, #from do
        local v = from[i] + (to[i] - from[i]) * t
        out[i] = round and math.floor(v + 0.5) or v
    end
    return out
end
-- }}}

-- {{{ function motion.frame
-- The compiled canvas of frame n (0 .. count-1): the still with every move
-- applied at its fraction. A new table each time; the still is never
-- changed, so frames may be worked out in any order. Colours round to
-- whole channels; offsets stay exact. An arrow whose end is a moving
-- surface moves its end with it.
function motion.frame(clip, n)
    if type(n) ~= "number" or n % 1 ~= 0 or n < 0 or n >= clip.count then
        error("motion.frame: frame " .. tostring(n) .. " is outside 0 to " .. (clip.count - 1))
    end
    local s = clip.still
    local frame = {}
    for k, v in pairs(s) do
        frame[k] = v
    end
    frame.xs, frame.ys = { unpack(s.xs) }, { unpack(s.ys) }
    local colours = {}
    for i = 1, s.surfaces.n do
        colours[i] = s.surfaces.colour[i]
    end
    local surfaces = {}
    for k, v in pairs(s.surfaces) do
        surfaces[k] = v
    end
    surfaces.colour = colours
    frame.surfaces = surfaces
    -- Arrows pointing at a surface follow it when it moves.
    local arrows = {}
    for k, v in pairs(s.arrows) do
        arrows[k] = type(v) == "table" and { unpack(v, 1, s.arrows.n) } or v
    end
    frame.arrows = arrows
    for _, m in ipairs(clip.moves) do
        local t = motion.fraction(m, n)
        if m.field == "colour" then
            colours[m.surface] = between(m.from, m.to, t, true)
        else
            local d = between(m.from, m.to, t, false)
            local first, count = s.surfaces.first[m.surface], s.surfaces.count[m.surface]
            for i = first, first + count - 1 do
                frame.xs[i] = frame.xs[i] + d[1]
                frame.ys[i] = frame.ys[i] + d[2]
            end
            for i = 1, arrows.n do
                if arrows.from[i] == m.surface then
                    arrows.x1[i], arrows.y1[i] = arrows.x1[i] + d[1], arrows.y1[i] + d[2]
                end
                if arrows.to[i] == m.surface then
                    arrows.x2[i], arrows.y2[i] = arrows.x2[i] + d[1], arrows.y2[i] + d[2]
                end
            end
        end
    end
    frame.number = n
    return frame
end
-- }}}

return motion

-- 059-say-back.lua — reads a raw score back as plain lines, one per
-- thing in it, so a person can check what the porch heard without
-- reading Lua (issue 704).
--
-- What this is, generally: the porch (032-porch.lua) turns speech into a
-- score. Before anyone films it, each call in that score is said back in
-- pseudo-code English: "wanderer: a violet icosahedron, glowing, circles
-- at radius 2.4, once a loop". The lines are written here, from the calls
-- themselves, never by the model, so they say what the score will do and
-- not what the model hoped it would. A line that reads wrong is the
-- person's cue to say so in their own words.
--
-- The lines come in a fixed order: the canvas, the camera, the world,
-- the shapes, the panes, then the strokes in playing order. A word the
-- sayings below don't know is still said, by name, so nothing in a score
-- goes unmentioned.

local sayback = {}

-- {{{ local function num()
-- A number as a person would say it: whole numbers bare, others to two
-- places with trailing zeros dropped.
local function num(n)
    if type(n) ~= "number" then return tostring(n) end
    if n == math.floor(n) then return string.format("%d", n) end
    return (string.format("%.2f", n):gsub("0+$", ""))
end
-- }}}

-- {{{ local function where()
-- A position: {x,y,z} or {x,y} as "(x, y, z)"; a tip, or a tag, as the
-- name of what it follows.
local function where(p)
    if type(p) == "string" then return p end
    if type(p) ~= "table" then return tostring(p) end
    if p.ref == "tip" then return p.of end
    local parts = {}
    for i, v in ipairs(p) do parts[i] = num(v) end
    return "(" .. table.concat(parts, ", ") .. ")"
end
-- }}}

-- {{{ local function times()
-- A whole count per loop: "once a loop", "twice a loop", "3 times a
-- loop". Negative counts go the other way.
local function times(n, noun)
    noun = noun or "loop"
    if n == nil then n = 1 end
    local back = ""
    if type(n) == "number" and n < 0 then n, back = -n, ", the other way" end
    local said
    if n == 1 then said = "once"
    elseif n == 2 then said = "twice"
    else said = num(n) .. " times" end
    return said .. " a " .. noun .. back
end
-- }}}

-- {{{ local function list()
local function list(items)
    if #items <= 1 then return items[1] or "" end
    return table.concat(items, ", ", 1, #items - 1) .. " and " .. items[#items]
end
-- }}}

-- {{{ local function a()
-- "a" or "an", by the word that follows.
local function a(word)
    word = tostring(word)
    return (word:match("^[aeiouAEIOU]") and "an " or "a ") .. word
end
-- }}}

-- {{{ local function rest()
-- The words of a table that a saying didn't use, named, so nothing
-- passes unmentioned: " (also: bob, lag)". Where a loop starts, and the
-- seeds, change no reading, so they stay quiet.
local QUIET = { phase = true, seed = true, turn_phase = true, wave_phase = true }
local function rest(t, used)
    local left = {}
    for k in pairs(t) do
        if not used[k] and not QUIET[k] then left[#left + 1] = tostring(k) end
    end
    if #left == 0 then return "" end
    table.sort(left)
    return " (also: " .. table.concat(left, ", ") .. ")"
end
-- }}}

-- {{{ local function used()
local function used(...)
    local set = {}
    for _, k in ipairs({ ... }) do set[k] = true end
    return set
end
-- }}}

-- {{{ local MOTION_SAYS
-- How each kind of shape motion is said. Each returns the words and the
-- set of keys it spoke of.
local MOTION_SAYS = {
    fixed = function(m)
        if m.at then return "stands at " .. where(m.at), used("kind", "at") end
        return "stands still", used("kind")
    end,
    orbit = function(m)
        local s = "circles at radius " .. num(m.radius)
        if m.center then s = s .. " round " .. where(m.center) end
        return s .. ", " .. times(m.cycles), used("kind", "radius", "center", "cycles")
    end,
    swing = function(m)
        return "swings between " .. where(m.from) .. " and " .. where(m.to)
            .. ", " .. times(m.cycles), used("kind", "from", "to", "cycles")
    end,
    lissajous = function(m)
        return "weaves a knot " .. where(m.size) .. " wide, " .. where(m.freq)
            .. " waves a loop", used("kind", "size", "freq")
    end,
    arc = function(m)
        local s = "arches over at radius " .. num(m.radius)
        if m.center then s = s .. " round " .. where(m.center) end
        return s .. ", " .. times(m.cycles), used("kind", "radius", "center", "cycles")
    end,
    conveyor = function(m)
        return "grows at " .. where(m.from) .. ", travels to " .. where(m.to)
            .. " and shrinks away, " .. times(m.cycles), used("kind", "from", "to", "cycles")
    end,
    keyframes = function(m)
        return "follows a route of " .. #(m.points or {}) .. " points, "
            .. times(m.cycles), used("kind", "points", "cycles")
    end,
    wave = function(m)
        return "ripples from " .. where(m.from) .. " to " .. where(m.to)
            .. ", " .. times(m.cycles), used("kind", "from", "to", "cycles")
    end,
    bezier = function(m)
        local p = m.points or {}
        return "flies a curve from " .. where(p[1]) .. " to " .. where(p[#p])
            .. ", " .. times(m.cycles), used("kind", "points", "cycles")
    end,
    spline = function(m)
        return "rounds a closed curve through " .. #(m.points or {}) .. " points, "
            .. times(m.cycles), used("kind", "points", "cycles")
    end,
}
-- }}}

-- {{{ local CAMERA_SAYS
local CAMERA_SAYS = {
    orbit = function(m)
        return "circles at radius " .. num(m.radius) .. ", " .. times(m.cycles),
            used("kind", "radius", "cycles")
    end,
    dolly = function(m)
        return "slides between " .. where(m.from) .. " and " .. where(m.to)
            .. ", " .. times(m.cycles), used("kind", "from", "to", "cycles")
    end,
    crane = function(m)
        return "rises from " .. num(m.low) .. " to " .. num(m.high) .. " and sinks, "
            .. times(m.cycles), used("kind", "low", "high", "cycles")
    end,
    spiral = function(m)
        return "spirals in to " .. num(m.near) .. " and out to " .. num(m.far)
            .. ", " .. times(m.cycles), used("kind", "near", "far", "cycles")
    end,
    lobed = function(m)
        return "loops round in " .. num(m.lobes) .. " lobes, " .. times(m.cycles),
            used("kind", "lobes", "cycles")
    end,
    ride = function(m)
        return "rides the track, " .. times(m.cycles), used("kind", "cycles")
    end,
    fly = function(m)
        return "flies a knot " .. where(m.size) .. " wide", used("kind", "size")
    end,
}
-- }}}

-- {{{ local function motion()
local function motion(m, says)
    if type(m) ~= "table" then return "stands still" end
    local say = says[m.kind]
    if not say then return "moves by " .. tostring(m.kind) end
    local words, spoke = say(m)
    return words .. rest(m, spoke)
end
-- }}}

-- {{{ local function canvas()
local function canvas(c)
    local s = "the canvas: " .. num(c.size) .. " pixels square"
    if c.frames then
        s = s .. ", " .. num(c.frames) .. " frames"
    else
        s = s .. ", " .. num(c.length) .. " s"
    end
    s = s .. " at " .. num(c.fps) .. " frames a second"
    local bg = c.background
    if bg == nil or bg == "black" then s = s .. ", on black"
    elseif bg == "sky" then s = s .. ", under the stars"
    else s = s .. ", on a dark " .. bg .. " glow" end
    return s .. rest(c, used("size", "frames", "length", "fps", "background", "seed"))
end
-- }}}

-- {{{ local function camera()
local function camera(c)
    local s
    if c.motion then
        s = "the eye " .. motion(c.motion, CAMERA_SAYS)
    else
        s = "the eye stands " .. num(c.distance or 0) .. " back"
        if c.tilt then s = s .. ", tipped down " .. num(c.tilt) end
    end
    if c.fov then s = s .. ", seeing " .. num(c.fov) .. " degrees" end
    if c.roll then s = s .. ", the horizon rolling" end
    return s .. rest(c, used("motion", "distance", "tilt", "fov", "roll"))
end
-- }}}

-- {{{ local function world()
local function world(w)
    local s = "the world:"
    local spoke = used("stars")
    if w.stars then
        s = s .. " " .. num(w.stars.count or 0) .. " stars"
        if w.stars.hues then s = s .. " in " .. list(w.stars.hues) end
    else
        s = s .. " no stars"
    end
    return s .. rest(w, spoke)
end
-- }}}

-- {{{ local function shape()
local function shape(sh, n)
    local name = sh.tag or ("shape #" .. n)
    local s = name .. ": " .. a(sh.hue or "white") .. " " .. tostring(sh.mesh or "blob")
    if sh.style and sh.style ~= "solid" then s = s .. ", " .. sh.style .. "ing" end
    s = s .. ", " .. motion(sh.motion, MOTION_SAYS)
    if sh.spin then s = s .. ", spinning " .. times(sh.spin.turns) end
    if sh.pulse then s = s .. ", breathing " .. times(sh.pulse.cycles) end
    for _, r in ipairs(sh.reacts or {}) do
        s = s .. ", " .. tostring(r.effect) .. "s when " .. tostring(r.to)
            .. " comes within " .. num(r.within)
    end
    return s .. rest(sh, used("tag", "hue", "mesh", "style", "motion", "spin",
                             "pulse", "reacts", "scale"))
end
-- }}}

-- {{{ local function pane()
local function pane(p, n)
    local name = "pane " .. (p.name or ("#" .. n))
    local place = p.place or "world"
    if place == "front" then return name .. ": glass over the whole picture" end
    if place == "back" then return name .. ": glass behind every shape" end
    local size = p.size or { 1, 1 }
    local s = name .. ": glass " .. num(size[1]) .. " by " .. num(size[2])
        .. " standing at " .. where(p.at or { 0, 0, 0 })
    if p.facing then s = s .. ", facing " .. where(p.facing) end
    return s .. rest(p, used("name", "place", "size", "at", "facing", "pixels"))
end
-- }}}

-- {{{ local SHAPE_SAYS
-- How each stroke shape is said.
local SHAPE_SAYS = {
    arc = function(a)
        local function hour(h)
            if type(h) == "number" then return num(h) .. " o'clock" end
            return tostring(h)
        end
        return "arc of radius " .. num(a.radius) .. " round " .. where(a.center)
            .. ", " .. tostring(a.turn or "?") .. " from " .. hour(a.from)
            .. " to " .. hour(a.to)
    end,
    line = function(l) return "line from " .. where(l.from) .. " to " .. where(l.to) end,
    point = function(p)
        if type(p.at) == "table" and p.at.ref == "tip" then
            return "point following " .. p.at.of
        end
        return "point at " .. where(p.at)
    end,
    fill = function(f) return "fill of " .. #(f.vertices or {}) .. " corners" end,
}
-- }}}

-- {{{ local function stroke()
local function stroke(st)
    local at, lasts = st.at or 0, st.lasts or 0
    local sh = st.shape or {}
    local say = SHAPE_SAYS[sh.kind]
    local s = num(at) .. " to " .. num(at + lasts) .. " s: " .. a(st.color)
        .. " " .. (say and say(sh) or tostring(sh.kind))
    if st.pane then s = s .. ", on pane " .. st.pane end
    if st.name then s = st.name .. ", " .. s end
    return s
end
-- }}}

-- {{{ function sayback.lines()
-- Every thing in a raw score (as score.read or porch.collect leave it),
-- said back as one plain line each, in a fixed order.
function sayback.lines(raw)
    local lines = {}
    if raw.canvas then lines[#lines + 1] = canvas(raw.canvas) end
    if raw.camera then lines[#lines + 1] = camera(raw.camera) end
    if raw.world then lines[#lines + 1] = world(raw.world) end
    for n, sh in ipairs(raw.shapes or {}) do lines[#lines + 1] = shape(sh, n) end
    for n, p in ipairs(raw.panes or {}) do lines[#lines + 1] = pane(p, n) end
    for _, st in ipairs(raw.strokes or {}) do lines[#lines + 1] = stroke(st) end
    return lines
end
-- }}}

-- {{{ function sayback.header()
-- The same lines as Lua comments, to head a written score.
function sayback.header(raw)
    local out = { "-- what the porch heard:" }
    for _, line in ipairs(sayback.lines(raw)) do out[#out + 1] = "--   " .. line end
    return table.concat(out, "\n") .. "\n\n"
end
-- }}}

return sayback

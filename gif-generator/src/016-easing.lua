-- 016-easing.lua — the easing curves and the fade envelopes: how
-- progress and brightness ride time.
--
-- What this is, generally: two small dispatch tables of pure
-- functions. EASINGS shape *motion* — raw time-fraction in, shaped
-- progress out ("stroke" is the vision's brush gesture: slow at
-- first but then fast). ENVELOPES shape *brightness* — raw
-- time-fraction in, emission strength out (the score's fade words:
-- in, out, in-out, hold, flash). Both tables are the single truth
-- their names are checked against: the validator derives its legal
-- lists from here, so a curve added is a word learned everywhere,
-- and nothing can drift.
--
-- The contract every easing must keep: 0 maps to 0, 1 maps to 1,
-- and the curve stays inside [0, 1]. Envelopes keep only the bounds
-- (an envelope may start and end anywhere inside them — "hold" is
-- flat 1). A property test walks both whole tables so a new entry
-- cannot forget its promise.

local easing = {}

-- How hard the stroke gesture leans: higher = a longer slow start
-- and a harder snap at the end. An aesthetic knob — tuning belongs
-- in docs/balance-updates.md.
local STROKE_POWER = 2.6

-- Motion: raw time-fraction u in [0,1] → shaped progress in [0,1].
easing.EASINGS = {
    -- {{{ linear
    linear = function(u)
        return u
    end,
    -- }}}
    -- {{{ stroke
    -- the vision's gesture: slow at first, then fast like a stroke
    stroke = function(u)
        return u ^ STROKE_POWER
    end,
    -- }}}
    -- {{{ ease-out
    -- the stroke's mirror: fast departure, gentle arrival
    ["ease-out"] = function(u)
        return 1 - (1 - u) ^ STROKE_POWER
    end,
    -- }}}
    -- {{{ smoothstep
    -- gentle both ways; the classic 3u² - 2u³
    smoothstep = function(u)
        return u * u * (3 - 2 * u)
    end,
    -- }}}
}

-- Brightness: raw time-fraction u in [0,1] → emission strength.
-- The ramps use smoothstep shoulders so light breathes rather than
-- snapping; RAMP is the fraction of the window a shoulder takes.
local RAMP = 0.25

-- {{{ local function shoulder()
-- a smoothstep from 0 to 1 across [a, b], flat outside
local function shoulder(u, a, b)
    if u <= a then return 0 end
    if u >= b then return 1 end
    local t = (u - a) / (b - a)
    return t * t * (3 - 2 * t)
end
-- }}}

easing.ENVELOPES = {
    -- {{{ hold
    hold = function()
        return 1
    end,
    -- }}}
    -- {{{ in
    ["in"] = function(u)
        return shoulder(u, 0, RAMP)
    end,
    -- }}}
    -- {{{ out
    ["out"] = function(u)
        return 1 - shoulder(u, 1 - RAMP, 1)
    end,
    -- }}}
    -- {{{ in-out
    ["in-out"] = function(u)
        return shoulder(u, 0, RAMP) * (1 - shoulder(u, 1 - RAMP, 1))
    end,
    -- }}}
    -- {{{ flash
    -- everything at once, then a long decay — a spark, not a breath
    flash = function(u)
        return (1 - u) ^ 3
    end,
    -- }}}
}

-- {{{ function easing.motion()
-- Look up an easing by name; refusal carries the legal list, so a
-- misspelling teaches instead of stranding.
function easing.motion(name)
    local fn = easing.EASINGS[name]
    if not fn then
        error("easing: no motion curve named '" .. tostring(name)
              .. "' — legal: " .. easing.names(easing.EASINGS))
    end
    return fn
end
-- }}}

-- {{{ function easing.envelope()
function easing.envelope(name)
    local fn = easing.ENVELOPES[name]
    if not fn then
        error("easing: no fade envelope named '" .. tostring(name)
              .. "' — legal: " .. easing.names(easing.ENVELOPES))
    end
    return fn
end
-- }}}

-- {{{ function easing.names()
-- The legal words of a table, sorted, comma-joined — used by error
-- messages here and by the validator and the porch grammar, so the
-- vocabulary has one voice everywhere.
function easing.names(tbl)
    local list = {}
    for name in pairs(tbl) do list[#list + 1] = name end
    table.sort(list)
    return table.concat(list, ", ")
end
-- }}}

return easing

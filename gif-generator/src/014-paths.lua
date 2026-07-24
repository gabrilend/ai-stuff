-- 014-paths.lua — parametric paths: progress in, position and
-- heading out, spoken in the vision's own clock-face words.
--
-- What this is, generally: a path is a function from progress (0 to
-- 1) to a place on the canvas, plus the direction of travel there —
-- the tangent, which lets emitters bias velocity along or against
-- the motion ("oriented inward"). Three shapes: arcs, lines, points.
-- Fill regions live in their own module; they answer a different
-- question (a region, not a spot).
--
-- THE CLOCK-FACE CONVENTION, implemented exactly once, here (the
-- datapath document pins it down in prose):
--   * screen coordinates: x grows rightward, y grows DOWNWARD —
--     which flips the usual math convention, so "clockwise" on
--     screen is the direction of INCREASING angle.
--   * 12 o'clock is straight up from center. Each hour is 30
--     degrees. Fractional hours are legal ("about 7" may be 7.2).
--   * hour h → angle (h / 12) * 2π - π/2, in screen space.

local paths = {}

-- {{{ function paths.clock_angle()
-- The one home of hour-to-angle. Accepts numbers (7, 7.2) or the
-- score's spoken form ("7 o'clock", "12 o'clock").
function paths.clock_angle(hour)
    if type(hour) == "string" then
        local h = hour:match("^([%d%.]+)%s*o'clock$")
        if not h then
            error("paths: cannot read the clock position '" .. hour
                  .. "' — say a number or \"7 o'clock\"")
        end
        hour = tonumber(h)
    end
    if type(hour) ~= "number" then
        error("paths: a clock position must be a number or a spoken "
              .. "hour, got " .. type(hour))
    end
    return (hour / 12) * 2 * math.pi - math.pi / 2
end
-- }}}

-- {{{ function paths.arc()
-- An arc: center, radius, from and to clock positions, and an
-- EXPLICIT direction of turn. "From 12 to 7" is ambiguous without
-- it — the vision's two hands prove both directions matter — so an
-- arc without a stated turn is refused, never guessed.
function paths.arc(spec)
    if spec.turn ~= "clockwise" and spec.turn ~= "counterclockwise" then
        error("paths: an arc needs turn = \"clockwise\" or "
              .. "\"counterclockwise\" — from " .. tostring(spec.from)
              .. " to " .. tostring(spec.to)
              .. " could sweep either way, and guessing would draw "
              .. "the wrong picture silently")
    end
    local a0 = paths.clock_angle(spec.from)
    local a1 = paths.clock_angle(spec.to)
    -- normalize the sweep to the stated turn: clockwise means the
    -- angle increases (y grows downward — see the file head), so
    -- wind the destination past the start in the right direction
    local sweep
    if spec.turn == "clockwise" then
        sweep = (a1 - a0) % (2 * math.pi)
    else
        sweep = -((a0 - a1) % (2 * math.pi))
    end
    local cx, cy, r = spec.center[1], spec.center[2], spec.radius
    return {
        kind = "arc",
        -- {{{ at()
        at = function(t)
            local a = a0 + sweep * t
            return cx + math.cos(a) * r, cy + math.sin(a) * r
        end,
        -- }}}
        -- {{{ heading()
        -- the tangent: perpendicular to the radius, signed by the
        -- turn, unit length by construction
        heading = function(t)
            local a = a0 + sweep * t
            local s = sweep >= 0 and 1 or -1
            return -math.sin(a) * s, math.cos(a) * s
        end,
        -- }}}
    }
end
-- }}}

-- {{{ function paths.line()
-- A straight interpolation between two points. The heading is
-- constant; a zero-length line has no direction to speak of and
-- says so rather than dividing by zero.
function paths.line(spec)
    local x0, y0 = spec.from[1], spec.from[2]
    local x1, y1 = spec.to[1], spec.to[2]
    local dx, dy = x1 - x0, y1 - y0
    local len = math.sqrt(dx * dx + dy * dy)
    if len == 0 then
        error("paths: a line from a point to itself has no direction"
              .. " — use a point if standing still is the intent")
    end
    local hx, hy = dx / len, dy / len
    return {
        kind = "line",
        -- {{{ at()
        at = function(t)
            return x0 + dx * t, y0 + dy * t
        end,
        -- }}}
        -- {{{ heading()
        heading = function()
            return hx, hy
        end,
        -- }}}
    }
end
-- }}}

-- {{{ function paths.point()
-- A position that ignores progress. Its heading is zero — a still
-- emitter scatters by its recipe's aim blend, and zero heading
-- makes "aim" mean nothing extra, which is the honest reading.
function paths.point(spec)
    local x, y = spec.at[1], spec.at[2]
    return {
        kind = "point",
        -- {{{ at()
        at = function()
            return x, y
        end,
        -- }}}
        -- {{{ heading()
        heading = function()
            return 0, 0
        end,
        -- }}}
    }
end
-- }}}

return paths

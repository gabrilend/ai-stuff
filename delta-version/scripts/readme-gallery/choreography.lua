-- choreography.lua - where every shape is, and what it is doing, at a moment.
--
-- What this is, generally: the stage manager. A scene file lists the shapes,
-- how each one travels, spins, breathes, and how it reacts when another shape
-- comes close. Given a moment in the loop (a number from 0 up to 1), this
-- file answers with a list of placed shapes -- position, turn, size, colour,
-- how shattered, how morphed. It never touches a pixel; the rasteriser does.
--
-- Why every motion counts whole cycles: the animation is a loop, and the
-- last frame must lead into the first with no seam. A spin of 1.5 turns
-- would jump half a turn at the join, so fractional cycle counts are refused
-- when the scene is loaded, not discovered by eye after rendering.
--
-- Data formats worth knowing more than once:
--   scene.instances[i] = {
--     tag     = string            -- what reactions look for; several may share it
--     mesh    = string            -- a word from meshes.lua; mesh_params = table
--     hue     = string            -- a word from the palette's hue vocabulary
--     scale   = number            -- overall size, default 1
--     stretch = {x, y, z}         -- per-axis size, default {1,1,1}
--     style   = "solid"|"glow"|"wire"
--     motion  = { kind = ..., ... }   -- see MOTIONS below
--     spin    = { axis = {x,y,z}, turns = integer, phase = 0..1 }
--     pulse   = { amount = number, cycles = integer, phase = 0..1 }
--     morph   = { cycles = integer, phase = 0..1, cube = p, octa = p } (superball only)
--     face_motion = true          -- point the shape's +x along its travel
--     orient  = { axis = {x,y,z}, angle = radians }        -- standing turn
--     rock    = { axis = {x,y,z}, center = radians, amount = radians, cycles = integer, phase }
--                                    swings amount either side of center
--     pivot   = {x,y,z}           -- move the shape off its centre before
--                                    turning, so it swings about one end
--     burst   = { amount, cycles = integer, phase, power } -- timed shatter
--     shards  = "rainbow"|"own"   -- shard colours (default rainbow)
--     reacts  = { { to = tag, within = distance, effect = word, amount = number }, ... }
--   }
--   motion modifiers, on any kind: lag = fraction of a loop,
--     offset = {x,y,z}, sway = { { vector = {x,y,z}, cycles, phase }, ... }
--   placed item (the output) = {
--     mesh, position {x,y,z}, rotation (3x3 rows), scale, stretch {x,y,z}, pivot,
--     rgb {r,g,b} (0..1 linear light), style, shatter (0..1), morph_p (number|nil),
--     shard_rgbs (list of {r,g,b}), glow (0..1)
--   }

local choreography = {}

local TAU = 2 * math.pi

-- The shard rainbow, in wheel order. Shattered faces take these colours by
-- face number, so a burst always reads as a rainbow whatever the shape's hue.
local RAINBOW = { "rose", "ember", "gold", "jade", "teal", "ice", "violet" }

-- {{{ local function is_whole()
local function is_whole(n) return type(n) == "number" and n == math.floor(n) end
-- }}}

-- {{{ local function smooth()
-- 0 at the edge of a reaction's reach, 1 at touching, eased so reactions
-- swell in and out instead of snapping.
local function smooth(x)
    if x <= 0 then return 0 end
    if x >= 1 then return 1 end
    return x * x * (3 - 2 * x)
end
-- }}}

-- {{{ local function rotation_about()
-- Rotation matrix (rows) for `angle` radians about unit-ised `axis`.
local function rotation_about(axis, angle)
    local len = math.sqrt(axis[1] ^ 2 + axis[2] ^ 2 + axis[3] ^ 2)
    local x, y, z = axis[1] / len, axis[2] / len, axis[3] / len
    local c, s = math.cos(angle), math.sin(angle)
    local k = 1 - c
    return {
        { c + x * x * k,     x * y * k - z * s, x * z * k + y * s },
        { y * x * k + z * s, c + y * y * k,     y * z * k - x * s },
        { z * x * k - y * s, z * y * k + x * s, c + z * z * k },
    }
end
-- }}}

-- {{{ local function multiply()
local function multiply(a, b)
    local out = {}
    for r = 1, 3 do
        out[r] = {}
        for c = 1, 3 do
            out[r][c] = a[r][1] * b[1][c] + a[r][2] * b[2][c] + a[r][3] * b[3][c]
        end
    end
    return out
end
-- }}}

-- {{{ local function facing()
-- A rotation whose +x column points along `dir`, keeping "up" roughly up:
-- used by face_motion so a fish swims nose-first.
local function facing(dir)
    local len = math.sqrt(dir[1] ^ 2 + dir[2] ^ 2 + dir[3] ^ 2)
    if len < 1e-9 then return { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } } end
    local fx, fy, fz = dir[1] / len, dir[2] / len, dir[3] / len
    -- side = forward x up(0,1,0), then true up = side x forward
    local sx, sy, sz = -fz, 0, fx
    local sl = math.sqrt(sx * sx + sz * sz)
    if sl < 1e-6 then sx, sy, sz, sl = 0, 0, 1, 1 end
    sx, sy, sz = sx / sl, sy / sl, sz / sl
    local ux, uy, uz = sy * fz - sz * fy, sz * fx - sx * fz, sx * fy - sy * fx
    -- columns: forward, up, side
    return { { fx, ux, sx }, { fy, uy, sy }, { fz, uz, sz } }
end
-- }}}

-- How a shape travels. Each takes the motion table and the moment t in [0,1)
-- and returns a position. All of them return to their start at t = 1.
local MOTIONS = {
    -- {{{ fixed
    fixed = function(m) local a = m.at or { 0, 0, 0 }; return { a[1], a[2], a[3] } end,
    -- }}}
    -- {{{ orbit
    -- A circle of `radius` around `center`, `cycles` times per loop, tipped
    -- by `tilt` (about x) then turned by `yaw` (about y); `bob` adds an
    -- up-and-down wave with its own whole number of cycles.
    orbit = function(m, t)
        local angle = TAU * (m.cycles * t + (m.phase or 0))
        local x, y, z = m.radius * math.cos(angle), 0, m.radius * math.sin(angle)
        local tilt, yaw = m.tilt or 0, m.yaw or 0
        y, z = y * math.cos(tilt) - z * math.sin(tilt), y * math.sin(tilt) + z * math.cos(tilt)
        x, z = x * math.cos(yaw) + z * math.sin(yaw), -x * math.sin(yaw) + z * math.cos(yaw)
        if m.bob then
            y = y + m.bob.amount * math.sin(TAU * (m.bob.cycles * t + (m.bob.phase or 0)))
        end
        local c = m.center or { 0, 0, 0 }
        return { c[1] + x, c[2] + y, c[3] + z }
    end,
    -- }}}
    -- {{{ swing
    -- Back and forth between `from` and `to`, easing at each end like a
    -- pendulum: at t = phase it is at `from`.
    swing = function(m, t)
        local s = 0.5 - 0.5 * math.cos(TAU * (m.cycles * t + (m.phase or 0)))
        return { m.from[1] + (m.to[1] - m.from[1]) * s,
                 m.from[2] + (m.to[2] - m.from[2]) * s,
                 m.from[3] + (m.to[3] - m.from[3]) * s }
    end,
    -- }}}
    -- {{{ lissajous
    -- Each axis its own sine wave with a whole-number frequency: a knotted
    -- closed path, the route a school of fish can circle forever.
    lissajous = function(m, t)
        local p = m.phase or 0
        local c = m.center or { 0, 0, 0 }
        local out = {}
        for axis = 1, 3 do
            local shift = (m.shift and m.shift[axis]) or 0
            out[axis] = c[axis] + m.size[axis] * math.sin(TAU * (m.freq[axis] * (t + p) + shift))
        end
        return out
    end,
    -- }}}
    -- {{{ arc
    -- One way along an arch -- a part of a circle standing upright in the
    -- picture, from `from_angle` to `to_angle` (radians; pi is the left foot,
    -- 0 the right) -- then back to the start unseen. The second value it
    -- returns is a size envelope: zero at both feet, full at the crown, so
    -- a shape shrinks to nothing as it lands and grows from nothing as it
    -- sets off again, and the jump back to the start is never visible.
    arc = function(m, t)
        local u = (m.cycles * t + (m.phase or 0)) % 1
        local a0, a1 = m.from_angle or math.pi, m.to_angle or 0
        local angle = a0 + (a1 - a0) * u
        local c = m.center or { 0, 0, 0 }
        return { c[1] + m.radius * math.cos(angle), c[2] + m.radius * math.sin(angle), c[3] + (m.depth or 0) },
               math.sin(math.pi * u) ^ 0.6, u
    end,
    -- }}}
    -- {{{ conveyor
    -- Straight from `from` to `to`, then back to `from` unseen, `cycles`
    -- times a loop: rings streaming down a tunnel toward the lens. Like the
    -- arc, it returns a size envelope -- growing out of nothing over the
    -- first sixth of the trip and shrinking away over the last tenth -- so
    -- the return jump is never seen.
    conveyor = function(m, t)
        local u = (m.cycles * t + (m.phase or 0)) % 1
        local envelope = math.min(1, u / 0.16) * math.min(1, (1 - u) / 0.1)
        return { m.from[1] + (m.to[1] - m.from[1]) * u,
                 m.from[2] + (m.to[2] - m.from[2]) * u,
                 m.from[3] + (m.to[3] - m.from[3]) * u }, envelope, u
    end,
    -- }}}
}

-- {{{ local function ease()
local function ease(x) return x * x * (3 - 2 * x) end
-- }}}

-- {{{ local function keyed()
-- Finds where `u` falls among keys sorted by their first field (each a
-- moment in [0,1)), wrapping from the last key round to the first, and
-- returns the two keys and the eased fraction between them.
local function keyed(keys, u)
    local n = #keys
    for i = 1, n do
        local a, b = keys[i], keys[i % n + 1]
        local ua, ub = a[1], b[1]
        if i == n then ub = ub + 1 end
        local uu = u
        if i == n and uu < ua then uu = uu + 1 end
        if uu >= ua and uu < ub then return a, b, ease((uu - ua) / (ub - ua)) end
    end
    -- before the first key: the wrap segment from the last key
    local a, b = keys[n], keys[1]
    return a, b, ease((u + 1 - a[1]) / (b[1] + 1 - a[1]))
end
-- }}}

MOTIONS.keyframes = function(m, t)
    -- {{{ keyframes
    -- A route through named moments: `points = { {u, x, z}, {u, x, z, y}, ... }`
    -- (u from 0 up to 1, in order). A point without a y rests on the scene's
    -- ground (plus `lift`, e.g. a ball's radius); a point with one hangs at
    -- that height. Between two ground points the shape follows the ground's
    -- rise and fall; otherwise it glides between the heights. `sizes =
    -- { {u, s}, ... }` sets its size along the way (0 hides it, which is how a
    -- route jumps back to its start unseen). Easing at every key makes each
    -- leg start and stop gently. Returns position, size, and u.
    local u = (m.cycles * t + (m.phase or 0)) % 1
    local a, b, f = keyed(m.points, u)
    local x = a[2] + (b[2] - a[2]) * f
    local z = a[3] + (b[3] - a[3]) * f
    local y
    if a[4] == nil and b[4] == nil then
        y = m._ground(x, z)
    else
        local ya = a[4] or m._ground(a[2], a[3])
        local yb = b[4] or m._ground(b[2], b[3])
        y = ya + (yb - ya) * f
    end
    local size = 1
    if m.sizes then
        local sa, sb, g = keyed(m.sizes, u)
        size = sa[2] + (sb[2] - sa[2]) * g
    end
    return { x, y, z }, size, u
    -- }}}
end

MOTIONS.wave = function(m, t)
    -- {{{ wave
    -- Along a straight line from `from` to `to`, `cycles` times a loop,
    -- rippling to either side (along `up`, default upward) in a sine wave
    -- of `waves` crests over the line's length and `amplitude` high -- a star
    -- riding a gust of wind. Grows and shrinks at the ends like the conveyor.
    local u = (m.cycles * t + (m.phase or 0)) % 1
    local up = m.up or { 0, 1, 0 }
    local s = m.amplitude * math.sin(TAU * (m.waves * u + (m.wave_phase or 0)))
    local envelope = math.min(1, u / 0.12) * math.min(1, (1 - u) / 0.12)
    return { m.from[1] + (m.to[1] - m.from[1]) * u + up[1] * s,
             m.from[2] + (m.to[2] - m.from[2]) * u + up[2] * s,
             m.from[3] + (m.to[3] - m.from[3]) * u + up[3] * s }, envelope, u
    -- }}}
end

MOTIONS.bezier = function(m, t)
    -- {{{ bezier
    -- A curved flight worked out in advance: a cubic curve through four
    -- points `points = { start, pull1, pull2, end }`, `cycles` times a loop.
    -- The two middle points bend the path -- a dart swinging wide before it
    -- homes in. It grows from nothing at the start and vanishes at the end,
    -- so each flight respawns at its start unseen. Why worked out in advance
    -- rather than steered each frame: a steered dart's path depends on every
    -- frame before it, so the last frame never leads back to the first; a
    -- curve fixed ahead of time is the same at t = 0 and t = 1 by
    -- construction.
    local u = (m.cycles * t + (m.phase or 0)) % 1
    local p0, p1, p2, p3 = m.points[1], m.points[2], m.points[3], m.points[4]
    local v = 1 - u
    local out = {}
    for axis = 1, 3 do
        out[axis] = v * v * v * p0[axis] + 3 * v * v * u * p1[axis] + 3 * v * u * u * p2[axis] + u * u * u * p3[axis]
    end
    return out, math.min(1, u / 0.08) * math.min(1, (1 - u) / 0.05), u
    -- }}}
end

-- {{{ local function closed_spline()
-- A smooth closed curve through `points` (a Catmull-Rom spline: it passes
-- through every point, and each point's neighbours set how it bends there).
-- `s` from 0 up to 1 goes once round, each stretch between points taking an
-- equal share; s = 1 is s = 0 again, which is what makes a route or a track
-- built on it loop without a seam.
local function closed_spline(points, s)
    local n = #points
    local x = (s % 1) * n
    local i = math.floor(x)
    local f = x - i
    local p0, p1 = points[(i - 1) % n + 1], points[i % n + 1]
    local p2, p3 = points[(i + 1) % n + 1], points[(i + 2) % n + 1]
    local f2, f3 = f * f, f * f * f
    local out = {}
    for axis = 1, 3 do
        out[axis] = 0.5 * (2 * p1[axis] + (-p0[axis] + p2[axis]) * f
            + (2 * p0[axis] - 5 * p1[axis] + 4 * p2[axis] - p3[axis]) * f2
            + (-p0[axis] + 3 * p1[axis] - 3 * p2[axis] + p3[axis]) * f3)
    end
    return out
end
-- }}}
choreography.closed_spline = closed_spline

MOTIONS.spline = function(m, t)
    -- {{{ spline
    -- Round a smooth closed curve through `points` ({x,y,z} each), `cycles`
    -- times a loop -- a flight that swoops and loops without stopping at its
    -- points (keyframes ease to a halt at each). `sizes = {{u,s}...}` sets its
    -- size along the way, as with keyframes. Returns position, size, and u.
    local u = (m.cycles * t + (m.phase or 0)) % 1
    local size = 1
    if m.sizes then
        local sa, sb, g = keyed(m.sizes, u)
        size = sa[2] + (sb[2] - sa[2]) * g
    end
    return closed_spline(m.points, u), size, u
    -- }}}
end

-- {{{ function choreography.track_frame()
-- Where the track is at s (0 up to 1, once round), and which way its rails
-- lie: returns the centre point, the direction along the track, the
-- sideways direction (from one rail toward the other), the track's own up,
-- and how far it has twisted. The twist is a corkscrew: over the stretch
-- from `twist.from` to `twist.to` the rails turn `twist.turns` whole times
-- round the direction of travel, easing in and out, and are level again
-- after -- so the track, and anyone riding it, comes back to itself.
--
-- With `twist.radius`, the corkscrew is a real one: the track does not just
-- turn about its own centre line but swings out round an axis `radius` to
-- one side of it -- over the top and back -- so the rider travels a wide
-- helix. The swing is radius * (sideways * sin(turn) + up * (1 - cos(turn))),
-- zero at both ends of the corkscrew, so the track rejoins itself. (The owner
-- found the first corkscrew, which only turned the rails in place, "much too
-- tight".)
-- {{{ local function base_frame()
-- The unturned track at s: centre, along, sideways, up, and its turn there.
local function base_frame(track, s)
    local c = closed_spline(track.points, s)
    local ahead = closed_spline(track.points, s + 1e-4)
    local tx, ty, tz = ahead[1] - c[1], ahead[2] - c[2], ahead[3] - c[3]
    local tl = math.sqrt(tx * tx + ty * ty + tz * tz)
    tx, ty, tz = tx / tl, ty / tl, tz / tl
    -- sideways = along x up (0,1,0), then the track's up = sideways x along
    local sx, sy, sz = -tz, 0, tx
    local sl = math.sqrt(sx * sx + sz * sz)
    if sl < 1e-6 then sx, sy, sz, sl = 1, 0, 0, 1 end
    sx, sy, sz = sx / sl, sy / sl, sz / sl
    local ux, uy, uz = sy * tz - sz * ty, sz * tx - sx * tz, sx * ty - sy * tx
    local twist = 0
    local tw = track.twist
    if tw then
        local u = s % 1
        local f = (u - tw.from) / (tw.to - tw.from)
        if f > 0 and f < 1 then twist = TAU * tw.turns * smooth(f) end
    end
    return c, { tx, ty, tz }, { sx, sy, sz }, { ux, uy, uz }, twist
end
-- }}}

-- {{{ local function swung_centre()
-- The centre line after the corkscrew's swing (unchanged without a radius).
local function swung_centre(track, s)
    local c, _, side, up, twist = base_frame(track, s)
    local r = track.twist and track.twist.radius
    if not r or twist == 0 then return c, side, up, twist end
    local out, lift = r * math.sin(twist), r * (1 - math.cos(twist))
    return { c[1] + side[1] * out + up[1] * lift, c[2] + side[2] * out + up[2] * lift,
             c[3] + side[3] * out + up[3] * lift }, side, up, twist
end
-- }}}

function choreography.track_frame(track, s)
    local c, base_side, base_up, twist = swung_centre(track, s)
    local ahead = swung_centre(track, s + 1e-4)
    local tx, ty, tz = ahead[1] - c[1], ahead[2] - c[2], ahead[3] - c[3]
    local tl = math.sqrt(tx * tx + ty * ty + tz * tz)
    tx, ty, tz = tx / tl, ty / tl, tz / tl
    local sx, sy, sz = base_side[1], base_side[2], base_side[3]
    local ux, uy, uz = base_up[1], base_up[2], base_up[3]
    local co, si = math.cos(twist), math.sin(twist)
    local side = { sx * co + ux * si, sy * co + uy * si, sz * co + uz * si }
    local up = { ux * co - sx * si, uy * co - sy * si, uz * co - sz * si }
    return c, { tx, ty, tz }, side, up, twist
end
-- }}}

-- Integer-cycle fields each motion kind must carry, checked on load.
local MOTION_CYCLES = { fixed = {}, orbit = { "cycles" }, swing = { "cycles" }, lissajous = {},
                        arc = { "cycles" }, conveyor = { "cycles" }, keyframes = { "cycles" },
                        wave = { "cycles" }, bezier = { "cycles" }, spline = { "cycles" } }

-- How the camera travels, when a scene gives it a motion. Each returns the
-- eye's position and the point it looks at, at moment t. Every one of them
-- is back where it started at t = 1, by the same whole-cycle rule as the
-- shapes, so a moving camera loops without a seam too.
--   target -- the point looked at (default the origin); "ahead" is legal
--             only for fly, and means "along the path"
local CAMERA_MOTIONS = {
    -- {{{ orbit
    -- Circle the target at `radius`, `height` above it, `cycles` times a
    -- loop (negative for the other way); `bob` lifts and lowers the eye.
    orbit = function(c, t)
        local angle = TAU * (c.cycles * t + (c.phase or 0))
        local target = c.target or { 0, 0, 0 }
        local lift = c.bob and c.bob.amount * math.sin(TAU * (c.bob.cycles * t + (c.bob.phase or 0))) or 0
        return { target[1] + c.radius * math.cos(angle), target[2] + (c.height or 0) + lift,
                 target[3] + c.radius * math.sin(angle) }, target
    end,
    -- }}}
    -- {{{ dolly
    -- Glide toward and away from the target along a straight track, easing
    -- at each end: at t = phase the eye is at `from`, halfway at `to`.
    dolly = function(c, t)
        local s = 0.5 - 0.5 * math.cos(TAU * (c.cycles * t + (c.phase or 0)))
        return { c.from[1] + (c.to[1] - c.from[1]) * s, c.from[2] + (c.to[2] - c.from[2]) * s,
                 c.from[3] + (c.to[3] - c.from[3]) * s }, c.target or { 0, 0, 0 }
    end,
    -- }}}
    -- {{{ crane
    -- Rise from `low` to `high` and sink again `cycles` times a loop, while
    -- circling the target `turns` times (0 for a straight lift) at `radius`.
    -- The target rises with the eye by `follow` (0 to 1), so the lens can
    -- ride up a tower looking at it rather than tipping over it.
    crane = function(c, t)
        local s = 0.5 - 0.5 * math.cos(TAU * (c.cycles * t + (c.phase or 0)))
        local height = c.low + (c.high - c.low) * s
        local angle = TAU * ((c.turns or 0) * t + (c.turn_phase or 0))
        local base = c.target or { 0, 0, 0 }
        local target = { base[1], base[2] + (height - c.low) * (c.follow or 0), base[3] }
        return { base[1] + c.radius * math.cos(angle), height, base[3] + c.radius * math.sin(angle) }, target
    end,
    -- }}}
    -- {{{ spiral
    -- Circle the target `turns` times while the radius breathes between
    -- `near` and `far` and the height between `low` and `high`, each
    -- `cycles` times a loop: sweeping in close, then pulling up and away.
    spiral = function(c, t)
        local s = 0.5 - 0.5 * math.cos(TAU * (c.cycles * t + (c.phase or 0)))
        local radius = c.far + (c.near - c.far) * s
        local height = c.high + (c.low - c.high) * s
        local angle = TAU * (c.turns * t + (c.turn_phase or 0))
        local target = c.target or { 0, 0, 0 }
        return { target[1] + radius * math.cos(angle), target[2] + height,
                 target[3] + radius * math.sin(angle) }, target
    end,
    -- }}}
    -- {{{ fly
    -- Follow a knotted closed path (the lissajous of the shapes' vocabulary:
    -- `size`, `freq`, `shift`, `center`), looking either at a fixed target
    -- or `target = "ahead"`, a little way along the path -- a fly-through.
    fly = function(c, t)
        local eye = MOTIONS.lissajous(c, t)
        -- Two ways of looking ahead: straight along the path's direction
        -- (the default), or, with `lead`, at the point the camera will reach
        -- that fraction of a loop later -- which turns the lens into a bend
        -- rather than off it, keeping what lines the path in the picture.
        if c.target == "ahead" and c.lead then
            return eye, MOTIONS.lissajous(c, t + c.lead)
        end
        if c.target == "ahead" then
            local next_eye = MOTIONS.lissajous(c, t + 0.02)
            local dx, dy, dz = next_eye[1] - eye[1], next_eye[2] - eye[2], next_eye[3] - eye[3]
            return eye, { eye[1] + dx * 10, eye[2] + dy * 10, eye[3] + dz * 10 }
        end
        return eye, c.target or { 0, 0, 0 }
    end,
    -- }}}
}

-- {{{ lobed
-- Round a loop that pinches in toward the middle `lobes` times and swells
-- out between -- with two lobes, a figure-of-eight that never crosses
-- itself: bend in, bend out, curve round, bend in, bend out, curve round.
-- The distance from `center` is radius * (1 - pinch * cos(lobes * angle)).
-- Looks at `target`, or `"ahead"` at where it will be `lead` of a loop later.
CAMERA_MOTIONS.lobed = function(c, t)
    -- {{{ local function at()
    local function at(time)
        local angle = TAU * (c.cycles * time + (c.phase or 0))
        local r = c.radius * (1 - c.pinch * math.cos(c.lobes * angle))
        local center = c.center or { 0, 0, 0 }
        local lift = c.bob and c.bob.amount * math.sin(TAU * (c.bob.cycles * time + (c.bob.phase or 0))) or 0
        return { center[1] + r * math.cos(angle), center[2] + (c.height or 0) + lift, center[3] + r * math.sin(angle) }
    end
    -- }}}
    local eye = at(t)
    if c.target == "ahead" then return eye, at(t + (c.lead or 0.03)) end
    return eye, c.target or { 0, 0, 0 }
end
-- }}}

-- {{{ ride
-- Ride the scene's `track`, `cycles` times round a loop, `height` above the
-- rails, looking at the track `lead` of a loop ahead. The third value is
-- the track's twist at the rider, so the view corkscrews with the rails.
CAMERA_MOTIONS.ride = function(c, t)
    local s = (c.cycles * t + (c.phase or 0)) % 1
    local here, _, _, up, twist = choreography.track_frame(c._track, s)
    local there, _, _, up_there = choreography.track_frame(c._track, s + (c.lead or 0.02))
    local h = c.height or 0.4
    return { here[1] + up[1] * h, here[2] + up[2] * h, here[3] + up[3] * h },
           { there[1] + up_there[1] * h, there[2] + up_there[2] * h, there[3] + up_there[3] * h },
           twist
end
-- }}}

-- Whole-number fields each camera motion must carry, checked on load.
local CAMERA_CYCLES = { orbit = { "cycles" }, dolly = { "cycles" }, crane = { "cycles" },
                        lobed = { "cycles", "lobes" }, ride = { "cycles" },
                        spiral = { "cycles", "turns" }, fly = {} }

-- Where a carried part is at moment t -- filled in further down, once the
-- posing functions exist; declared here so a route can start at a wand.
local find_part_position

-- {{{ local function anchored()
-- A route whose points are written `{ part = tag, plus = {x,y,z} }` starts
-- (or ends) wherever that carried part is at the moment the shape sets off
-- on this trip round its cycle -- a spell leaving the wand's tip as the wand
-- is at that instant, not a fixed spot. The launch moment is found from the
-- route's own cycle: lt - u / cycles, where u is how far round it is now.
-- Each trip therefore has fixed points once launched; the loop stays
-- seamless because the moment one loop later launches from the same place.
local function anchored(m, t)
    local lt = t - (m.lag or 0)
    local u = (m.cycles * lt + (m.phase or 0)) % 1
    local launch = lt - u / m.cycles
    local copy = {}
    for k, v in pairs(m) do copy[k] = v end
    -- {{{ local function resolve()
    local function resolve(point)
        if type(point) == "table" and point.part then
            local at = find_part_position(m._scene, point.part, launch)
            local plus = point.plus or { 0, 0, 0 }
            return { at[1] + plus[1], at[2] + plus[2], at[3] + plus[3] }
        end
        return point
    end
    -- }}}
    copy.from, copy.to = resolve(m.from), resolve(m.to)
    if m.points then
        copy.points = {}
        for i, p in ipairs(m.points) do copy.points[i] = resolve(p) end
    end
    copy._anchored = nil
    return copy
end
-- }}}

-- {{{ local function travel()
-- Where a motion puts a shape at t, with the three modifiers any motion may
-- carry:
--   lag    -- follow the same path this fraction of a loop behind (a tail,
--             a tentacle, a school); shifting time keeps the loop seamless
--   offset -- {x,y,z} added after, so several shapes share one path apart
--   sway   -- a list of { vector = {x,y,z}, cycles, phase }: each a wave
--             added on top (a tentacle's ripple, a petal's flutter)
-- Returns the position, the size envelope (1 unless the motion has one),
-- and -- for motions that run a route once per cycle -- how far round that
-- cycle the shape is (u, 0 up to 1), which is what "becomes" is timed by.
local function travel(m, t)
    if m._anchored then m = anchored(m, t) end
    local position, envelope, u = MOTIONS[m.kind](m, t - (m.lag or 0))
    -- `on_ground`: the height the motion gives is measured up from the
    -- scene's ground at that spot, so a windmill or a wizard stands on the
    -- surface wherever it is placed. (Keyframes rest on the ground their
    -- own way, point by point, and do not use this.)
    if m.on_ground then position[2] = position[2] + m._ground(position[1], position[3]) end
    if m.offset then
        for axis = 1, 3 do position[axis] = position[axis] + m.offset[axis] end
    end
    for _, wave in ipairs(m.sway or {}) do
        local s = math.sin(TAU * (wave.cycles * t + (wave.phase or 0)))
        for axis = 1, 3 do position[axis] = position[axis] + wave.vector[axis] * s end
    end
    return position, envelope or 1, u
end
-- }}}

-- What a reaction does to a shape, at `strength` between 0 and 1. Effects
-- write only into the shape's own record; the neighbour is read from the
-- un-reacted copy, so the order reactions are listed in never matters.
local EFFECTS = {
    -- {{{ swell
    swell = function(item, strength, amount) item.scale = item.scale * (1 + amount * strength) end,
    -- }}}
    -- {{{ bleed_hue
    -- Borrow the neighbour's colour, up to half-and-half at touching.
    bleed_hue = function(item, strength, amount, other)
        local k = 0.5 * strength * amount
        for c = 1, 3 do item.rgb[c] = item.rgb[c] * (1 - k) + other.rgb[c] * k end
    end,
    -- }}}
    -- {{{ shatter
    shatter = function(item, strength, amount)
        item.shatter = math.min(1, item.shatter + strength * amount)
    end,
    -- }}}
    -- {{{ glow
    glow = function(item, strength, amount) item.glow = math.min(1, item.glow + strength * amount) end,
    -- }}}
}

-- {{{ local function refuse()
local function refuse(scene_name, message)
    error("scene " .. scene_name .. ": " .. message, 0)
end
-- }}}

-- {{{ local function legal_words()
local function legal_words(tbl)
    local list = {}
    for k in pairs(tbl) do list[#list + 1] = k end
    table.sort(list)
    return table.concat(list, ", ")
end
-- }}}

-- The motions that run a route once per cycle and report how far along it
-- they are -- the only ones a rolling or becoming shape can use.
local ROUTES = { keyframes = true, wave = true, bezier = true, arc = true, conveyor = true, spline = true }

-- The solids a shape can morph through: those with no dents, whose surface
-- can be reached by one straight line out from the middle in every
-- direction (see meshes.radius_toward).
local CONVEX = { cube = true, tetrahedron = true, octahedron = true, icosahedron = true }

-- {{{ local function has_tag()
-- Whether any shape, or any part carried at any depth, carries the tag.
local function has_tag(list, tag)
    for _, item in ipairs(list) do
        if item.tag == tag then return true end
        if item.parts and has_tag(item.parts, tag) then return true end
    end
    return false
end
-- }}}

-- {{{ local function shallow_copy()
local function shallow_copy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end
-- }}}

-- {{{ local function trail_of()
-- The copies that follow a shape: each one the same route a little later in
-- time, smaller, tagged "trail" so nothing reacts to it, carrying none of
-- the leader's reactions, parts or own trail.
local function trail_of(leader, trail)
    local copies = {}
    for k = 1, trail.count do
        local copy = shallow_copy(leader)
        copy.motion = shallow_copy(leader.motion)
        copy.motion.lag = (leader.motion.lag or 0) + k * (trail.spacing or 0.012)
        copy.scale = (leader.scale or 1) * (trail.shrink or 0.8) ^ k
        copy.tag, copy.reacts, copy.parts, copy.trail = "trail", nil, nil, nil
        -- a trail in a shape of its own takes that shape's plain proportions
        copy.mesh = trail.mesh or leader.mesh
        if trail.mesh then copy.mesh_params = nil end
        if trail.hues then copy.hue = trail.hues[1 + (k - 1) % #trail.hues] end
        if trail.dim then copy.dim = trail.dim end
        -- a trail shows motion: resting, its sparks would pile up into a
        -- column under the leader, so each copy fades out as it slows below
        -- `full_speed` (world units per loop)
        copy._speed_fade = trail.full_speed or 6
        copies[#copies + 1] = copy
    end
    return copies
end
-- }}}

-- {{{ local function expand_shorthand()
-- Unfolds `becomes` and `trail` into plain shapes, in place of the one that
-- carried them: the shape, then what it becomes, then each one's trail.
local function expand_shorthand(instances, scene_name)
    local out = {}
    for written, inst in ipairs(instances) do
        local family = { inst }
        if inst.becomes then
            local b = inst.becomes
            if type(b.at) ~= "number" or b.at <= 0 or b.at >= 1 then
                refuse(scene_name, "becomes needs an `at` between 0 and 1 (a point in the route's cycle)")
            end
            local before = shallow_copy(inst)
            before.becomes = nil
            before._fade = { kind = "out", at = b.at, over = b.over or 0.05 }
            local after = shallow_copy(inst)
            after.becomes, after.trail, after.reacts = nil, b.trail, b.reacts
            for _, field in ipairs({ "mesh", "mesh_params", "hue", "scale", "stretch", "style", "spin",
                                      "orient", "rock", "pulse", "face_motion", "roll", "tag", "dim" }) do
                if b[field] ~= nil then after[field] = b[field] end
            end
            if b.roll == false then after.roll = nil end
            -- a new shape takes its own proportions, not the old shape's
            if b.mesh and b.mesh_params == nil then after.mesh_params = nil end
            after._fade = { kind = "in", at = b.at, over = b.over or 0.05 }
            family = { before, after }
        end
        for _, member in ipairs(family) do
            -- every shape unfolded from one written shape shares a family
            -- number, so checks can tell a ball turning into its own star
            -- from two balls crowding each other
            member._family = written
            out[#out + 1] = member
            if member.trail then
                if not is_whole(member.trail.count) or member.trail.count < 1 then
                    refuse(scene_name, "a trail needs a whole count of at least one")
                end
                for _, copy in ipairs(trail_of(member, member.trail)) do out[#out + 1] = copy end
            end
        end
    end
    return out
end
-- }}}

-- {{{ local function check_blob()
-- A blob: `blob = { group, bands, soft }` on a shape with a hue and no mesh.
-- Blobs of one group melt into each other where they come within `soft` of
-- touching; `bands` is how many brightness levels its lighting is cut into
-- (at least 2, a whole number).
local function check_blob(scene_name, label, inst, hues)
    if not hues[inst.hue] then
        refuse(scene_name, label .. " has hue '" .. tostring(inst.hue) .. "'; legal hues: " .. legal_words(hues))
    end
    if inst.mesh or inst.parts then
        refuse(scene_name, label .. " is a blob, which is a soft round body with no mesh and no parts")
    end
    local b = inst.blob
    if b.bands ~= nil and not (is_whole(b.bands) and b.bands >= 2) then
        refuse(scene_name, label .. "'s blob bands must be a whole number, at least 2")
    end
    if b.soft ~= nil and not (type(b.soft) == "number" and b.soft >= 0) then
        refuse(scene_name, label .. "'s blob softness must be a number, zero or more")
    end
end
-- }}}

-- {{{ local function check_turns()
-- The whole-number rules for the ways a shape turns and breathes in place.
local function check_turns(scene_name, label, p)
    if p.spin and not is_whole(p.spin.turns) then refuse(scene_name, label .. "'s spin turns must be whole") end
    if p.pulse and not is_whole(p.pulse.cycles) then refuse(scene_name, label .. "'s pulse cycles must be whole") end
    if p.rock and not is_whole(p.rock.cycles) then refuse(scene_name, label .. "'s rock cycles must be whole") end
end
-- }}}

-- {{{ local function check_keyframes()
-- A keyframed route: at least two points, their moments in order within
-- [0,1), each a table {u, x, z [, y]}; sizes likewise. Points without a
-- height rest on the scene's ground, so a route using them needs a ground.
local function check_keyframes(scene_name, label, m, scene, meshes)
    if type(m.points) ~= "table" or #m.points < 2 then
        refuse(scene_name, label .. "'s keyframes need at least two points")
    end
    local needs_ground = false
    for k, p in ipairs(m.points) do
        if type(p[1]) ~= "number" or p[1] < 0 or p[1] >= 1 or (k > 1 and p[1] <= m.points[k - 1][1]) then
            refuse(scene_name, label .. "'s keyframe moments must rise from 0 up to (not reaching) 1")
        end
        if p[4] == nil then needs_ground = true end
    end
    for k, s in ipairs(m.sizes or {}) do
        if type(s[1]) ~= "number" or s[1] < 0 or s[1] >= 1 or (k > 1 and s[1] <= m.sizes[k - 1][1]) then
            refuse(scene_name, label .. "'s size moments must rise from 0 up to (not reaching) 1")
        end
    end
    if needs_ground and not scene.ground then
        refuse(scene_name, label .. " rests on the ground, but the scene has no `ground`")
    end
    local lift = m.lift or 0
    -- {{{ function m._ground()
    function m._ground(x, z) return meshes.terrain_height(scene.ground, x, z) + lift end
    -- }}}
end
-- }}}

-- {{{ local function check_parts()
-- A carried part is checked like a shape (mesh, hue, turning rules) and its
-- mesh is built; parts may carry parts. Parts do not travel or react: they
-- ride their parent.
local function check_parts(scene_name, label, parts, hues, meshes, scene)
    for k, part in ipairs(parts) do
        local part_label = label .. " part " .. k .. (part.tag and (" (" .. part.tag .. ")") or "")
        if not hues[part.hue] then
            refuse(scene_name, part_label .. " has hue '" .. tostring(part.hue) .. "'; legal hues: " .. legal_words(hues))
        end
        if part.motion or part.reacts then
            refuse(scene_name, part_label .. " travels or reacts, but parts only ride their parent")
        end
        part.built_mesh = meshes.build(part.mesh, part.mesh_params)
        check_turns(scene_name, part_label, part)
        if part.parts then check_parts(scene_name, part_label, part.parts, hues, meshes, scene) end
    end
end
-- }}}

-- {{{ function choreography.load()
-- Checks a scene table and returns it ready to pose. `hues` is the colour
-- vocabulary (name -> {r,g,b}) and `meshes` the shape cabinet; both are
-- handed in so this file depends on neither the palette nor the renderer.
-- `fluid` (the liquid simulator, fluid.lua) is handed in the same way, and
-- is needed only by a scene with a `fluid`.
function choreography.load(scene, hues, meshes, fluid)
    local name = scene.name or "(unnamed)"
    if not is_whole(scene.frames) or scene.frames < 1 then refuse(name, "frames must be a whole number above 0") end
    if not is_whole(scene.size) or scene.size < 8 then refuse(name, "size must be a whole number of pixels, at least 8") end
    -- a scene needs something to film: shapes of its own, or a track whose
    -- ties and trackside shapes are laid out below
    if type(scene.instances) ~= "table" or (#scene.instances == 0 and not scene.track) then
        refuse(name, "no instances")
    end

    -- Words that are shorthand for several shapes are unfolded first, so
    -- everything after sees only plain shapes:
    --   becomes -- the shape shrinks away at a point in its route and a new
    --              one (its `becomes` table: mesh, hue, scale, ...) grows in
    --              its place, riding the same route from then on
    --   trail   -- `count` smaller copies following the same route a little
    --              behind in time (`spacing` of a cycle apart), each `shrink`
    --              times the size of the one before, optionally in other
    --              shapes and colours (`mesh`, `hues`)
    scene.instances = expand_shorthand(scene.instances, name)

    -- A track (scene.track) is a smooth closed curve with a corkscrew; its
    -- rails are drawn as strokes, a camera may ride it, and here its ties
    -- -- small bars across the rails, `track.ties = { count, hues, dim }` --
    -- become plain shapes laid along it, each turned to the track there.
    local track = scene.track
    if track then
        if type(track.points) ~= "table" or #track.points < 4 then
            refuse(name, "a track needs at least four points to bend through")
        end
        if track.twist and not is_whole(track.twist.turns) then
            refuse(name, "a track's corkscrew must turn a whole number of times, or the rails do not meet")
        end
        if track.rails then
            for _, hue in ipairs(track.rails.hues or {}) do
                if not hues[hue] then refuse(name, "the track's rails have hue '" .. tostring(hue) .. "'") end
            end
        end
        local ties = track.ties
        for k = 0, ties and ties.count - 1 or -1 do
            local c, along, side, up = choreography.track_frame(track, k / ties.count)
            scene.instances[#scene.instances + 1] = {
                tag = "tie", mesh = "cube", hue = ties.hues[k % #ties.hues + 1], dim = ties.dim,
                scale = 1, stretch = { ties.width or 0.05, ties.thickness or 0.03, (track.gauge or 0.8) * 0.72 },
                style = "solid",
                motion = { kind = "fixed", at = { c[1] - up[1] * 0.04, c[2] - up[2] * 0.04, c[3] - up[3] * 0.04 } },
                -- columns: along the track, the track's up, across the rails
                _frame = { { along[1], up[1], side[1] }, { along[2], up[2], side[2] }, { along[3], up[3], side[3] } },
            }
        end
        -- Shapes set beside the track: `track.along = { { count, mesh, hues,
        -- scale, side, up, spin, style }, ... }` places `count` of them evenly
        -- round it, alternately left and right of the rails by about `side`
        -- and above by about `up` (each varied a little by its number, so they
        -- do not stand in rows) -- stars the rider rushes past.
        for _, row in ipairs(track.along or {}) do
            for k = 0, row.count - 1 do
                local c, _, side, up = choreography.track_frame(track, (k + 0.5) / row.count)
                local lr = (k % 2 == 0) and 1 or -1
                local out = row.side * lr * (1 + 0.35 * ((k * 7) % 3))
                local high = row.up * (0.4 + 0.3 * ((k * 5) % 4))
                scene.instances[#scene.instances + 1] = {
                    tag = row.tag or "trackside", mesh = row.mesh, hue = row.hues[k % #row.hues + 1],
                    scale = row.scale, style = row.style or "glow",
                    motion = { kind = "fixed", at = { c[1] + side[1] * out + up[1] * high,
                                                      c[2] + side[2] * out + up[2] * high,
                                                      c[3] + side[3] * out + up[3] * high } },
                    spin = row.spin,
                }
            end
        end
    end

    scene.built = {}
    for index, inst in ipairs(scene.instances) do
        local label = (inst.tag or "instance") .. " #" .. index
        -- Three paths: a blob (a soft round body with no mesh -- see below)
        -- is checked for its own words; a shape with a mesh is checked and
        -- built; a shape with only parts is a spine -- posed so its parts can
        -- hang from it, but never drawn itself.
        if inst.blob then
            check_blob(name, label, inst, hues)
        elseif inst.mesh or not inst.parts then
            if not hues[inst.hue] then
                refuse(name, label .. " has hue '" .. tostring(inst.hue) .. "'; legal hues: " .. legal_words(hues))
            end
            -- Shapes with default proportions are built once and shared; a
            -- shape given its own parameters gets its own copy, keyed by its
            -- position.
            local key = inst.mesh_params and (inst.mesh .. "#" .. index) or inst.mesh
            scene.built[key] = scene.built[key] or meshes.build(inst.mesh, inst.mesh_params)
            inst.built_mesh = scene.built[key]
        end

        local motion = inst.motion or { kind = "fixed" }
        inst.motion = motion
        if not MOTIONS[motion.kind] then
            refuse(name, label .. " moves by '" .. tostring(motion.kind) .. "'; legal motions: " .. legal_words(MOTIONS))
        end
        for _, field in ipairs(MOTION_CYCLES[motion.kind]) do
            if not is_whole(motion[field]) then
                refuse(name, label .. "'s " .. motion.kind .. " " .. field .. " must be a whole number, or the loop has a seam")
            end
        end
        if motion.kind == "lissajous" then
            for axis = 1, 3 do
                if not is_whole(motion.freq[axis]) then
                    refuse(name, label .. "'s lissajous frequencies must be whole numbers, or the loop has a seam")
                end
            end
        end
        if motion.kind == "keyframes" then
            check_keyframes(name, label, motion, scene, meshes)
        elseif motion.on_ground then
            if not scene.ground then refuse(name, label .. " stands on the ground, but the scene has no `ground`") end
            -- {{{ function motion._ground()
            function motion._ground(x, z) return meshes.terrain_height(scene.ground, x, z) end
            -- }}}
        end
        if motion.kind == "bezier" and (type(motion.points) ~= "table" or #motion.points ~= 4) then
            refuse(name, label .. "'s bezier needs exactly four points: start, two pulls, end")
        end
        if motion.bob and not is_whole(motion.bob.cycles) then refuse(name, label .. "'s bob cycles must be whole") end
        for _, wave in ipairs(motion.sway or {}) do
            if not is_whole(wave.cycles) then refuse(name, label .. "'s sway cycles must be whole") end
        end
        -- a route starting or ending at a carried part: remember the scene so
        -- the part can be found, and check such a part exists
        local anchors = {}
        for _, p in ipairs({ motion.from or false, motion.to or false, unpack(motion.points or {}) }) do
            if type(p) == "table" and p.part then anchors[#anchors + 1] = p.part end
        end
        if #anchors > 0 then
            if not ROUTES[motion.kind] then
                refuse(name, label .. " starts from a part, which needs a route motion (" .. legal_words(ROUTES) .. ")")
            end
            for _, tag in ipairs(anchors) do
                if not has_tag(scene.instances, tag) then
                    refuse(name, label .. " starts from a part tagged '" .. tag .. "', but nothing carries one")
                end
            end
            motion._anchored, motion._scene = true, scene
        end
        if inst.shatter_keys then
            if not ROUTES[motion.kind] then refuse(name, label .. "'s shatter_keys need a route motion") end
            for k, key in ipairs(inst.shatter_keys) do
                if type(key[1]) ~= "number" or key[1] < 0 or key[1] >= 1
                   or (k > 1 and key[1] <= inst.shatter_keys[k - 1][1]) then
                    refuse(name, label .. "'s shatter moments must rise from 0 up to (not reaching) 1")
                end
            end
        end
        if inst.morph_through then
            local mt = inst.morph_through
            if not (inst.built_mesh and inst.built_mesh.superball) then
                refuse(name, label .. " morphs through solids, but only a superball can")
            end
            if not is_whole(mt.cycles) then refuse(name, label .. "'s morph_through cycles must be whole") end
            if type(mt.shapes) ~= "table" or #mt.shapes < 2 then
                refuse(name, label .. " morphs through solids, so it needs at least two shapes")
            end
            mt._meshes = {}
            for k, shape in ipairs(mt.shapes) do
                if not CONVEX[shape] then
                    refuse(name, label .. " cannot morph through '" .. tostring(shape) .. "'; it can through "
                           .. legal_words(CONVEX) .. " (solids with no dents)")
                end
                mt._meshes[k] = meshes.build(shape)
            end
            for _, hue in ipairs(mt.hues or {}) do
                if not hues[hue] then refuse(name, label .. "'s morph_through hue '" .. tostring(hue) .. "' is not known") end
            end
        end
        check_turns(name, label, inst)
        if inst.burst and not is_whole(inst.burst.cycles) then refuse(name, label .. "'s burst cycles must be whole") end
        if inst.shards and inst.shards ~= "rainbow" and inst.shards ~= "own" then
            refuse(name, label .. "'s shards must be \"rainbow\" or \"own\", not '" .. tostring(inst.shards) .. "'")
        end
        if inst.morph then
            if not inst.built_mesh.superball then refuse(name, label .. " morphs, but only a superball can") end
            if not is_whole(inst.morph.cycles) then refuse(name, label .. "'s morph cycles must be whole") end
        end
        -- rolling and becoming are timed by the route's own cycle, which only
        -- the route motions report
        if (inst.roll or inst._fade) and not ROUTES[motion.kind] then
            refuse(name, label .. (inst.roll and " rolls" or " becomes something") .. ", which needs a route motion ("
                   .. legal_words(ROUTES) .. "), not " .. motion.kind)
        end
        if inst.roll and not (type(inst.roll.radius) == "number" and inst.roll.radius > 0) then
            refuse(name, label .. " rolls, so it needs a radius above zero")
        end
        if inst.dim and not (type(inst.dim) == "number" and inst.dim >= 0 and inst.dim <= 1) then
            refuse(name, label .. "'s dim must be a number from 0 to 1")
        end
        if inst.parts then check_parts(name, label, inst.parts, hues, meshes, scene) end
        for _, reaction in ipairs(inst.reacts or {}) do
            if not EFFECTS[reaction.effect] then
                refuse(name, label .. " reacts with '" .. tostring(reaction.effect) .. "'; legal effects: " .. legal_words(EFFECTS))
            end
        end
    end

    for index, beam in ipairs(scene.beams or {}) do
        if not is_whole(beam.writhe or 0) then
            refuse(name, "beam #" .. index .. "'s writhe must be a whole number, or the loop has a seam")
        end
        for _, end_tag in ipairs({ beam.from, beam.to }) do
            if not has_tag(scene.instances, end_tag) then
                refuse(name, "beam #" .. index .. " joins '" .. tostring(end_tag) .. "', but nothing is tagged so")
            end
        end
    end
    for index, light in ipairs(scene.lights or {}) do
        if not light.tag and not light.at then
            refuse(name, "light #" .. index .. " needs a tag to ride or a fixed `at`")
        end
        if light.tag and not has_tag(scene.instances, light.tag) then
            refuse(name, "light #" .. index .. " rides '" .. light.tag .. "', but nothing is tagged so")
        end
        if light.hue and not hues[light.hue] then
            refuse(name, "light #" .. index .. " has hue '" .. tostring(light.hue) .. "'")
        end
    end
    -- A liquid in an invisible tilting box (see fluid.lua): worked out once
    -- here, then its drops are posed as blobs each frame.
    if scene.fluid then
        local spec = scene.fluid
        if not fluid then refuse(name, "this scene has a liquid, but no liquid simulator was handed in") end
        if not (is_whole(spec.count) and spec.count >= 1) then refuse(name, "the liquid needs a whole count of drops") end
        if not (spec.tilt and is_whole(spec.tilt.cycles)) then
            refuse(name, "the liquid's box must tilt a whole number of times a loop, or the loop has a seam")
        end
        if type(spec.box) ~= "table" or #spec.box ~= 3 then refuse(name, "the liquid needs a box of three half-widths") end
        for _, hue in ipairs(spec.hues or { "teal" }) do
            if not hues[hue] then refuse(name, "the liquid has hue '" .. tostring(hue) .. "'") end
        end
        scene._fluid = fluid.simulate(spec, scene.frames)
        scene._fluid_module = fluid
    end
    if scene.streaks and not is_whole(scene.streaks.cycles) then
        refuse(name, "the streaks' cycles must be whole, or the loop has a seam")
    end
    if scene.streaks and not (scene.camera and scene.camera.motion) then
        refuse(name, "streaks rush past a moving camera, but this scene's camera stands still")
    end
    for index, stroke in ipairs(scene.strokes or {}) do
        if not is_whole(stroke.drift or 0) then
            refuse(name, "wind stroke #" .. index .. "'s drift must be a whole number, or the loop has a seam")
        end
        if stroke.hue and not hues[stroke.hue] then
            refuse(name, "wind stroke #" .. index .. " has hue '" .. tostring(stroke.hue) .. "'")
        end
    end
    if scene.framing and not (type(scene.framing.tag) == "string" and is_whole(scene.framing.at_least)) then
        refuse(name, "framing needs a tag and a whole at_least")
    end

    -- The camera. Two paths: no `motion` -> the original still camera,
    -- set back `distance` and tipped by `tilt`, drawn by the rasteriser's
    -- original arithmetic (the approved films depend on it byte for byte);
    -- a `motion` -> a moving eye, checked here by the same loop rules.
    local camera = scene.camera or {}
    if camera.motion then
        local cm = camera.motion
        if not CAMERA_MOTIONS[cm.kind] then
            refuse(name, "the camera moves by '" .. tostring(cm.kind) .. "'; legal camera motions: "
                   .. legal_words(CAMERA_MOTIONS))
        end
        for _, field in ipairs(CAMERA_CYCLES[cm.kind]) do
            if not is_whole(cm[field]) then
                refuse(name, "the camera's " .. cm.kind .. " " .. field .. " must be a whole number, or the loop has a seam")
            end
        end
        if cm.turns ~= nil and not is_whole(cm.turns) then refuse(name, "the camera's turns must be whole") end
        if cm.kind == "fly" then
            for axis = 1, 3 do
                if not is_whole(cm.freq[axis]) then refuse(name, "the camera's fly frequencies must be whole") end
            end
        elseif cm.target == "ahead" and cm.kind ~= "lobed" then
            refuse(name, "only a flying or lobed camera can look \"ahead\"")
        end
        if cm.kind == "ride" then
            if not scene.track then refuse(name, "the camera rides a track, but the scene has no `track`") end
            cm._track = scene.track
        end
        if cm.bob and not is_whole(cm.bob.cycles) then refuse(name, "the camera's bob cycles must be whole") end
        local roll = camera.roll
        if roll and not is_whole(roll.cycles or roll.turns) then
            refuse(name, "the camera's roll must count whole cycles or whole turns")
        end
    end

    scene.rainbow = {}
    for i, hue in ipairs(RAINBOW) do scene.rainbow[i] = hues[hue] end
    scene.hues = hues
    return scene
end
-- }}}

-- {{{ local function turn_in_place()
-- The standing orient, then the continuous spin, then the back-and-forth
-- rock, each in the frame of the one before, applied onto `rotation`.
-- Shared by whole shapes and by the parts a shape carries.
local function turn_in_place(p, t, rotation)
    if p.orient then
        rotation = multiply(rotation, rotation_about(p.orient.axis, p.orient.angle))
    end
    if p.spin then
        local angle = TAU * (p.spin.turns * t + (p.spin.phase or 0))
        rotation = multiply(rotation, rotation_about(p.spin.axis or { 0, 1, 0 }, angle))
    end
    if p.rock then
        local angle = (p.rock.center or 0)
            + p.rock.amount * math.sin(TAU * (p.rock.cycles * t + (p.rock.phase or 0)))
        rotation = multiply(rotation, rotation_about(p.rock.axis, angle))
    end
    return rotation
end
-- }}}

-- {{{ local function breathe()
-- Size and per-axis stretch after a pulse. Two pulse paths: with `axes` the
-- breath stretches only those axes (a jellyfish bell squeezing sideways, a
-- skirt flaring); without, the whole shape grows and shrinks evenly.
local function breathe(p, t, scale)
    local stretch = { 1, 1, 1 }
    if p.stretch then stretch = { p.stretch[1], p.stretch[2], p.stretch[3] } end
    if p.pulse then
        local s = p.pulse.amount * math.sin(TAU * (p.pulse.cycles * t + (p.pulse.phase or 0)))
        if p.pulse.axes then
            for axis = 1, 3 do stretch[axis] = stretch[axis] * (1 + s * p.pulse.axes[axis]) end
        else
            scale = scale * (1 + s)
        end
    end
    return scale, stretch
end
-- }}}

-- {{{ local function rolling()
-- A ball rolling without slipping: turned about the level line across its
-- path by the distance it has come this cycle, divided by its radius. The
-- distance is measured by walking the route from the cycle's start in small
-- steps. Resting still, it keeps whatever turn it had; it cannot know which
-- way "forward" is, so it leaves the turn about a fixed line.
local ROLL_STEPS = 48
local function rolling(inst, t, u)
    local m = inst.motion
    local start = t - u / m.cycles
    local distance = 0
    local previous = travel(m, start)
    for k = 1, ROLL_STEPS do
        local here = travel(m, start + (t - start) * k / ROLL_STEPS)
        distance = distance + math.sqrt((here[1] - previous[1]) ^ 2 + (here[2] - previous[2]) ^ 2
                                        + (here[3] - previous[3]) ^ 2)
        previous = here
    end
    local now, ahead = travel(m, t), travel(m, t + 1e-3)
    local vx, vz = ahead[1] - now[1], ahead[3] - now[3]
    local len = math.sqrt(vx * vx + vz * vz)
    local axis = len > 1e-9 and { vz / len, 0, -vx / len } or (inst._last_roll_axis or { 0, 0, -1 })
    inst._last_roll_axis = axis
    return rotation_about(axis, distance / inst.roll.radius)
end
-- }}}

-- {{{ local function fade_of()
-- How much of a shape that is becoming another (or being become) shows at
-- cycle position u: the old shape shrinks away over `over` before `at`, the
-- new one grows over `over` after it. Anything else shows fully.
local function fade_of(inst, u)
    local f = inst._fade
    if not f then return 1 end
    if f.kind == "out" then
        return 1 - smooth((u - (f.at - f.over)) / f.over)
    end
    return smooth((u - f.at) / f.over)
end
-- }}}

-- {{{ local function base_pose()
-- One shape at moment t, before anyone reacts to anyone.
-- Turning is composed in a fixed order, each step in the frame of the one
-- before: rolling contact (roll), then nose along the path (face_motion),
-- then the standing orientation (orient), the continuous spin, and the
-- back-and-forth rock. So a petal is first turned to its place around the
-- flower (by its standing orient or its spin) and then rocks open about its
-- own hinge, not the flower's.
local function base_pose(scene, inst, t)
    local position, envelope, u = travel(inst.motion, t)
    local rotation = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }
    -- a shape laid along a track (a tie across the rails) starts from the
    -- track's own directions there rather than the world's
    if inst._frame then rotation = inst._frame end
    if inst.roll then rotation = rolling(inst, t, u) end
    if inst.face_motion then
        local ahead = travel(inst.motion, t + 1e-3)
        rotation = facing({ ahead[1] - position[1], ahead[2] - position[2], ahead[3] - position[3] })
    end
    rotation = turn_in_place(inst, t, rotation)
    local scale = (inst.scale or 1) * envelope
    if inst._fade then scale = scale * fade_of(inst, u) end
    if inst._speed_fade then
        local ahead = travel(inst.motion, t + 1e-3)
        local speed = math.sqrt((ahead[1] - position[1]) ^ 2 + (ahead[2] - position[2]) ^ 2
                                + (ahead[3] - position[3]) ^ 2) / 1e-3
        scale = scale * smooth(speed / inst._speed_fade)
    end
    local stretch
    scale, stretch = breathe(inst, t, scale)
    -- A burst is a shatter on a timer rather than a reaction: the shape
    -- splits on the crest of its own wave and is whole in the trough.
    local shatter = 0
    if inst.burst then
        local s = math.sin(TAU * (inst.burst.cycles * t + (inst.burst.phase or 0)))
        shatter = inst.burst.amount * math.max(0, s) ^ (inst.burst.power or 2)
    end
    -- A shatter timed by the route instead: `shatter_keys = {{u, amount}...}`
    -- opens and closes the shape at chosen points of its trip -- a fish that
    -- bursts where two shoals meet and reforms as it swims away.
    if inst.shatter_keys then
        local a, b, g = keyed(inst.shatter_keys, u)
        shatter = math.max(shatter, a[2] + (b[2] - a[2]) * g)
    end
    local morph_p = nil
    if inst.morph then
        -- Above zero the shape leans toward the cube, below toward the
        -- octahedron; the log scale makes both ends take equal time.
        local s = math.sin(TAU * (inst.morph.cycles * t + (inst.morph.phase or 0)))
        local cube, octa = inst.morph.cube or 8, inst.morph.octa or 1.05
        local log2 = s >= 0 and (1 + s * (math.log(cube) / math.log(2) - 1))
                             or (1 + s * (1 - math.log(octa) / math.log(2)))
        morph_p = 2 ^ log2
    end
    -- A shape that only carries parts (a character's invisible spine) has
    -- no hue and no mesh of its own; it is posed for its parts and hidden.
    local hue = scene.hues[inst.hue or "cloud"]
    -- Morphing through a list of solids: the loop is shared equally among
    -- them; each is held whole for `hold` of its share, then the shape
    -- flows into the next, its colour following if `hues` are given.
    local through = nil
    if inst.morph_through then
        local mt = inst.morph_through
        local n = #mt._meshes
        local x = ((mt.cycles * t + (mt.phase or 0)) % 1) * n
        local i = math.floor(x)
        local g = smooth(((x - i) - (mt.hold or 0.5)) / (1 - (mt.hold or 0.5)))
        local here, next_one = i % n + 1, (i + 1) % n + 1
        through = { a = mt._meshes[here], b = mt._meshes[next_one], f = g }
        if mt.hues then
            local ha, hb = scene.hues[mt.hues[here]], scene.hues[mt.hues[next_one]]
            hue = { ha[1] + (hb[1] - ha[1]) * g, ha[2] + (hb[2] - ha[2]) * g, ha[3] + (hb[3] - ha[3]) * g }
        end
    end
    local dim = inst.dim or 1
    -- Two shard paths: a rainbow burst (the default), or shards that keep
    -- the shape's own colour -- a fruit falling into segments of itself.
    local shard_rgbs = scene.rainbow
    if inst.shards == "own" then shard_rgbs = { hue } end
    return {
        tag = inst.tag, mesh = inst.built_mesh, hidden = inst.built_mesh == nil and not inst.blob,
        family = inst._family,
        -- a blob's size is its radius; its group decides what it melts into
        blob = inst.blob and { group = inst.blob.group or "blobs", bands = inst.blob.bands or 4,
                               soft = inst.blob.soft or 0.3 } or nil,
        position = position, rotation = rotation,
        scale = scale, stretch = stretch, pivot = inst.pivot,
        rgb = { hue[1] * dim, hue[2] * dim, hue[3] * dim },
        style = inst.style or "glow", shatter = shatter, glow = 0, morph_p = morph_p,
        shard_rgbs = shard_rgbs, shard_distance = inst.shard_distance or 1.2,
        through = through,
    }
end
-- }}}

-- {{{ local function place_parts()
-- The parts a shape carries, placed in its frame: each part's `offset` is
-- turned and sized with its parent, then the part turns in place on top of
-- its parent's turn (orient, spin, rock) and may carry parts of its own --
-- an arm carries a wand, the wand carries a star. Parts are drawn, and
-- counted for framing, but do not react; reactions belong to whole shapes.
local function place_parts(scene, parent, parts, t, out)
    local R, P, S = parent.rotation, parent.position, parent.scale
    for _, part in ipairs(parts) do
        local o = part.offset or { 0, 0, 0 }
        local ox, oy, oz = o[1] * S, o[2] * S, o[3] * S
        local position = {
            P[1] + R[1][1] * ox + R[1][2] * oy + R[1][3] * oz,
            P[2] + R[2][1] * ox + R[2][2] * oy + R[2][3] * oz,
            P[3] + R[3][1] * ox + R[3][2] * oy + R[3][3] * oz,
        }
        local rotation = turn_in_place(part, t, R)
        local scale, stretch = breathe(part, t, S * (part.scale or 1))
        local hue = scene.hues[part.hue]
        local dim = part.dim or 1
        local item = {
            tag = part.tag or parent.tag, mesh = part.built_mesh, hidden = false,
            position = position, rotation = rotation, scale = scale, stretch = stretch, pivot = part.pivot,
            rgb = { hue[1] * dim, hue[2] * dim, hue[3] * dim }, style = part.style or "glow",
            shatter = 0, glow = 0, morph_p = nil, shard_rgbs = scene.rainbow, shard_distance = 1.2,
        }
        out[#out + 1] = item
        if part.parts then place_parts(scene, item, part.parts, t, out) end
    end
end
-- }}}

-- {{{ function choreography.pose()
-- Every shape at moment t, after reactions. Two passes: place everyone,
-- then let each react to the nearest un-reacted neighbour carrying the tag
-- it listens for (a shape never reacts to itself). Parts are placed last,
-- in their reacted parent's frame, and follow the whole shapes in the list.
function choreography.pose(scene, t)
    local placed, untouched = {}, {}
    for index, inst in ipairs(scene.instances) do
        placed[index] = base_pose(scene, inst, t)
        untouched[index] = base_pose(scene, inst, t)
    end
    for index, inst in ipairs(scene.instances) do
        for _, reaction in ipairs(inst.reacts or {}) do
            local nearest, best = nil, math.huge
            for other_index, other in ipairs(untouched) do
                if other_index ~= index and other.tag == reaction.to then
                    local a, b = placed[index].position, other.position
                    local d = math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2)
                    if d < best then nearest, best = other, d end
                end
            end
            -- Two paths: nobody with that tag exists -> no reaction at all;
            -- someone does -> react at the strength their distance gives.
            if nearest then
                local strength = smooth(1 - best / reaction.within)
                EFFECTS[reaction.effect](placed[index], strength, reaction.amount or 1, nearest)
            end
        end
    end
    local whole = #placed
    for index = 1, whole do
        local parts = scene.instances[index].parts
        if parts then place_parts(scene, placed[index], parts, t, placed) end
    end
    -- the liquid's drops, taken from the worked-out film for this frame and
    -- carried out of the box's own frame by the box's tilt at this moment
    -- (its tilt runs `start` frames ahead of the loop, where the film began)
    local liquid = scene._fluid
    if liquid then
        local spec = scene.fluid
        local frame = math.floor(t * scene.frames + 0.5) % scene.frames
        local m = scene._fluid_module.tilt_matrix(spec.tilt, t + liquid.start / scene.frames)
        local c = spec.center or { 0, 0, 0 }
        local drop_hues = spec.hues or { "teal" }
        for i, p in ipairs(liquid.frames[frame]) do
            local h = scene.hues[drop_hues[(i - 1) % #drop_hues + 1]]
            placed[#placed + 1] = {
                tag = "drop", hidden = false, blob = { group = "liquid", bands = spec.bands or 4, soft = spec.soft or 0.25 },
                position = { c[1] + m[1][1] * p[1] + m[1][2] * p[2] + m[1][3] * p[3],
                             c[2] + m[2][1] * p[1] + m[2][2] * p[2] + m[2][3] * p[3],
                             c[3] + m[3][1] * p[1] + m[3][2] * p[2] + m[3][3] * p[3] },
                rotation = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }, scale = spec.radius * (spec.blob_size or 1.3),
                stretch = { 1, 1, 1 }, rgb = { h[1], h[2], h[3] }, shatter = 0, glow = 0,
            }
        end
    end
    return placed
end
-- }}}

-- {{{ function choreography.strokes()
-- Wind drawn as light: each stroke in `scene.strokes` is a thin line from
-- `from` to `to`, bent into a sine wave of `waves` crests and `amplitude`
-- high (along `up`), tapering flat at both ends, the wave travelling along
-- it `drift` whole times a loop. Returned as polylines for the painter:
-- { { points = { {x,y,z}, ... }, rgb = {r,g,b} }, ... }.
function choreography.strokes(scene, t)
    local out = {}
    for _, s in ipairs(scene.strokes or {}) do
        local hue = scene.hues[s.hue or "cloud"]
        local dim = s.dim or 0.6
        local up = s.up or { 0, 1, 0 }
        local points = {}
        local segments = s.segments or 40
        for k = 0, segments do
            local f = k / segments
            local lift = s.amplitude * math.sin(TAU * (s.waves * f - (s.drift or 0) * t + (s.phase or 0)))
                         * math.sin(math.pi * f)
            points[#points + 1] = {
                s.from[1] + (s.to[1] - s.from[1]) * f + up[1] * lift,
                s.from[2] + (s.to[2] - s.from[2]) * f + up[2] * lift,
                s.from[3] + (s.to[3] - s.from[3]) * f + up[3] * lift,
            }
        end
        out[#out + 1] = { points = points, rgb = { hue[1] * dim, hue[2] * dim, hue[3] * dim } }
    end
    -- The track's rails: two lines of light either side of the centre line,
    -- following its corkscrew, striped in turn with the `rails.hues`
    -- (candy stripes) -- each rail drawn as three close lines, `thickness`
    -- apart, so it reads thicker than a wind stroke. The rails do not move;
    -- the rider does.
    local track = scene.track
    if track and track.rails then
        local samples = track.rails.samples or 240
        local stripes = track.rails.stripes or 48
        local gauge = (track.gauge or 0.8) / 2
        local rdim = track.rails.dim or 1
        local thick = track.rails.thickness or 0.035
        for _, side_sign in ipairs({ 1, -1 }) do
            for _, lift in ipairs({ 0, thick, thick * 2 }) do
                local points, rgbs = {}, {}
                for k = 0, samples do
                    local c, _, side, up = choreography.track_frame(track, k / samples)
                    points[#points + 1] = {
                        c[1] + side[1] * gauge * side_sign + up[1] * lift,
                        c[2] + side[2] * gauge * side_sign + up[2] * lift,
                        c[3] + side[3] * gauge * side_sign + up[3] * lift,
                    }
                    if k < samples then
                        local stripe = math.floor(k / samples * stripes) % #track.rails.hues + 1
                        local h = scene.hues[track.rails.hues[stripe]]
                        rgbs[#rgbs + 1] = { h[1] * rdim, h[2] * rdim, h[3] * rdim }
                    end
                end
                out[#out + 1] = { points = points, rgbs = rgbs, rgb = rgbs[1] }
            end
        end
    end
    return out
end
-- }}}

-- {{{ find_part_position = function()
-- Where the shape or carried part tagged `tag` is at moment t, posed without
-- reactions (anchors need only the wand's place, not what reacts to it).
-- Remembered per moment, since every spell in flight asks the same question.
find_part_position = function(scene, tag, t)
    scene._anchor_memory = scene._anchor_memory or {}
    local key = tag .. "@" .. string.format("%.12f", t)
    local known = scene._anchor_memory[key]
    if known then return known end
    for _, inst in ipairs(scene.instances) do
        local item = base_pose(scene, inst, t)
        if item.tag == tag and not inst.parts then
            scene._anchor_memory[key] = item.position
            return item.position
        end
        if inst.parts then
            local list = {}
            place_parts(scene, item, inst.parts, t, list)
            for _, part in ipairs(list) do
                if part.tag == tag then
                    scene._anchor_memory[key] = part.position
                    return part.position
                end
            end
        end
    end
    error("scene " .. tostring(scene.name) .. ": nothing tagged '" .. tag .. "' to start from", 0)
end
choreography.part_position = function(scene, tag, t) return find_part_position(scene, tag, t) end
-- }}}

-- {{{ function choreography.beams()
-- Lines of light that always join two moving things -- a spell streaming
-- from the wand's tip to its target, bending and writhing. Worked out afresh
-- every frame from where the two ends are in `placed` (the frame's posed
-- shapes), so however the wand moves the beam stays attached. Each beam in
-- `scene.beams` = { from = tag, to = tag, amplitude, waves, writhe (whole
-- travels of the wave per loop), strands, hues, dim, segments }: `strands`
-- lines twist round the straight path, each bulging most at the middle and
-- pinned exactly to both ends.
function choreography.beams(scene, t, placed)
    local out = {}
    for _, beam in ipairs(scene.beams or {}) do
        local a, b
        for _, item in ipairs(placed) do
            if not a and item.tag == beam.from then a = item.position end
            if not b and item.tag == beam.to then b = item.position end
        end
        if not (a and b) then
            error("scene " .. tostring(scene.name) .. ": a beam needs something tagged '" .. beam.from
                  .. "' and something tagged '" .. beam.to .. "'", 0)
        end
        local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
        local len = math.sqrt(dx * dx + dy * dy + dz * dz)
        local fx, fy, fz = dx / len, dy / len, dz / len
        -- two directions square to the beam, to writhe in
        local px, py, pz = -fz, 0, fx
        local pl = math.sqrt(px * px + pz * pz)
        if pl < 1e-6 then px, py, pz, pl = 1, 0, 0, 1 end
        px, py, pz = px / pl, py / pl, pz / pl
        local qx, qy, qz = py * fz - pz * fy, pz * fx - px * fz, px * fy - py * fx
        local segments = beam.segments or 48
        local hues = beam.hues or { "violet" }
        for strand = 1, beam.strands or 1 do
            local offset = (strand - 1) / (beam.strands or 1)
            local points = {}
            for k = 0, segments do
                local sfrac = k / segments
                local phase = TAU * (beam.waves * sfrac - beam.writhe * t + offset)
                local bulge = beam.amplitude * math.sin(math.pi * sfrac)
                local wp, wq = bulge * math.sin(phase), bulge * 0.7 * math.cos(phase * 0.5 + offset * TAU)
                points[#points + 1] = { a[1] + dx * sfrac + px * wp + qx * wq,
                                        a[2] + dy * sfrac + py * wp + qy * wq,
                                        a[3] + dz * sfrac + pz * wp + qz * wq }
            end
            -- pinned: the first and last points are the ends themselves
            points[1] = { a[1], a[2], a[3] }
            points[#points] = { b[1], b[2], b[3] }
            local h = scene.hues[hues[(strand - 1) % #hues + 1]]
            local dim = beam.dim or 1
            out[#out + 1] = { points = points, rgb = { h[1] * dim, h[2] * dim, h[3] * dim } }
        end
    end
    return out
end
-- }}}

-- {{{ function choreography.streaks()
-- The feeling of speed: short pale streaks rushing past from the point the
-- camera is heading toward -- the direction it is actually moving this
-- instant, not the way it happens to look. Each streak is a dash laid along
-- that heading, at a fixed angle and distance from the line through the
-- eye, sliding from `far` ahead to `near` `cycles` times a loop; as it nears
-- it spreads outward on the screen, so they all pour out of the heading's
-- vanishing point. They are laid out afresh every frame around the eye's
-- current position and heading, so when the ride swerves they swing round
-- at once. (The owner: "make the gray streaks come from the orientation of
-- motion? They can adjust instantly because we are constantly adjusting
-- momentum." The first cut streamed them from the middle of the view.)
-- `scene.streaks = { count, seed, cycles, far, near, length, inner, outer,
-- hue, dim }`. Returned as world polylines. A still camera has no heading;
-- then they stream from the way it looks.
function choreography.streaks(scene, t)
    local sp = scene.streaks
    if not sp then return {} end
    if not scene._streak_seeds then
        local state = sp.seed or 1
        -- {{{ local function next_random()
        local function next_random()
            state = (state * 16807) % 2147483647
            return state / 2147483647
        end
        -- }}}
        scene._streak_seeds = {}
        for i = 1, sp.count do
            scene._streak_seeds[i] = { angle = next_random() * TAU,
                                       radius = sp.inner + (sp.outer - sp.inner) * next_random(),
                                       phase = next_random() }
        end
    end
    local hue = scene.hues[sp.hue or "cloud"]
    local dim = sp.dim or 0.55
    -- the eye and its heading now: where it will be a moment later, less
    -- where it is (or, if it is not moving, the way it looks)
    local view = choreography.camera(scene, t)
    if not view then
        error("scene " .. tostring(scene.name) .. ": streaks need a moving camera to stream past", 0)
    end
    local eye = view.eye
    local soon = choreography.camera(scene, t + 1e-4).eye
    local hx, hy, hz = soon[1] - eye[1], soon[2] - eye[2], soon[3] - eye[3]
    local hl = math.sqrt(hx * hx + hy * hy + hz * hz)
    if hl < 1e-12 then
        hx, hy, hz = view.target[1] - eye[1], view.target[2] - eye[2], view.target[3] - eye[3]
        hl = math.sqrt(hx * hx + hy * hy + hz * hz)
    end
    hx, hy, hz = hx / hl, hy / hl, hz / hl
    -- two directions square to the heading, for placing each streak round it
    local px, py, pz = -hz, 0, hx
    local pl = math.sqrt(px * px + pz * pz)
    if pl < 1e-6 then px, py, pz, pl = 1, 0, 0, 1 end
    px, py, pz = px / pl, py / pl, pz / pl
    local qx, qy, qz = py * hz - pz * hy, pz * hx - px * hz, px * hy - py * hx
    local out = {}
    for _, seed in ipairs(scene._streak_seeds) do
        local u = (sp.cycles * t + seed.phase) % 1
        local z = sp.far + (sp.near - sp.far) * u
        local a, b = seed.radius * math.cos(seed.angle), seed.radius * math.sin(seed.angle)
        local ox, oy, oz = eye[1] + px * a + qx * b, eye[2] + py * a + qy * b, eye[3] + pz * a + qz * b
        -- fade in from the distance and out as it passes
        local fade = math.min(1, u / 0.2) * math.min(1, (1 - u) / 0.1)
        out[#out + 1] = { points = { { ox + hx * (z + sp.length), oy + hy * (z + sp.length), oz + hz * (z + sp.length) },
                                     { ox + hx * z, oy + hy * z, oz + hz * z } },
                          heading = { hx, hy, hz },
                          rgb = { hue[1] * dim * fade, hue[2] * dim * fade, hue[3] * dim * fade } }
    end
    return out
end
-- }}}

-- {{{ local function seeded()
-- A tiny deterministic generator (a linear congruential sequence): the same
-- seed gives the same sky on every machine, so renders stay byte-identical.
local function seeded(seed)
    local state = seed % 2147483647
    if state <= 0 then state = state + 2147483646 end
    return function()
        state = (state * 16807) % 2147483647
        return (state - 1) / 2147483646
    end
end
-- }}}

-- {{{ function choreography.lights()
-- The point lights at moment t, for lighting the blobs: each in
-- `scene.lights = { { tag = ..., hue, strength }, ... }` shines from wherever
-- the shape or carried part with that tag is in `placed` (a glowing orb on a
-- turning arm -- the light "machinery" -- so the light's own motion is just
-- that part's), or from a fixed `at`. Returns { { position, rgb }... }.
function choreography.lights(scene, t, placed)
    local out = {}
    for _, light in ipairs(scene.lights or {}) do
        local position = light.at
        if light.tag then
            for _, item in ipairs(placed) do
                if item.tag == light.tag then position = item.position; break end
            end
        end
        local h = scene.hues[light.hue or "cloud"]
        local k = light.strength or 1
        out[#out + 1] = { position = { position[1], position[2], position[3] },
                          rgb = { h[1] * k, h[2] * k, h[3] * k } }
    end
    return out
end
-- }}}

-- {{{ function choreography.camera()
-- The view at moment t: { eye = {x,y,z}, target = {x,y,z}, roll = radians },
-- or nil for a still camera (which the rasteriser handles its original way).
-- Roll has two forms: { amount, cycles, phase } rocks the horizon side to
-- side; { turns } turns it all the way round a whole number of times.
function choreography.camera(scene, t)
    local camera = scene.camera or {}
    if not camera.motion then return nil end
    local eye, target, twist = CAMERA_MOTIONS[camera.motion.kind](camera.motion, t)
    local roll = 0
    if camera.roll then
        if camera.roll.turns then
            roll = TAU * camera.roll.turns * t
        else
            roll = camera.roll.amount * math.sin(TAU * (camera.roll.cycles * t + (camera.roll.phase or 0)))
        end
    end
    -- a camera riding a twisting track turns with it, on top of any roll
    if twist then roll = roll + twist end
    return { eye = eye, target = target, roll = roll }
end
-- }}}

-- {{{ function choreography.stars()
-- The sky at moment t: `scene.stars = { count, seed, hues = {...} }`.
-- Positions are fixed; each star twinkles a whole number of times per loop.
-- Two paths: a scene without stars gets an empty sky.
function choreography.stars(scene, t)
    local spec = scene.stars
    if not spec then return {} end
    if not scene.sky then
        local random = seeded(spec.seed or 1)
        local palette_words = spec.hues or { "gold", "ice" }
        scene.sky = {}
        for i = 1, spec.count do
            scene.sky[i] = {
                x = random(), y = random(),
                rgb = scene.hues[palette_words[1 + math.floor(random() * #palette_words)]],
                base = 0.35 + 0.6 * random(),
                twinkles = 1 + math.floor(random() * 3),
                phase = random(),
            }
        end
    end
    -- Two sky paths: under a still camera the stars stay put; under a moving
    -- one the whole sky slides against the camera's heading and pitch, so an
    -- orbit shows the heavens wheeling past. A full turn of heading slides the
    -- sky exactly one width, so the loop stays seamless.
    local shift_x, shift_y = 0, 0
    local view = choreography.camera(scene, t)
    if view then
        local dx, dy, dz = view.target[1] - view.eye[1], view.target[2] - view.eye[2], view.target[3] - view.eye[3]
        local flat = math.sqrt(dx * dx + dz * dz)
        shift_x = math.atan2(dx, dz) / TAU
        shift_y = math.atan2(dy, flat) / math.pi
    end
    local now = {}
    for i, star in ipairs(scene.sky) do
        local wave = 0.5 + 0.5 * math.sin(TAU * (star.twinkles * t + star.phase))
        local x, y = star.x, star.y
        if view then x, y = (x + shift_x) % 1, (y + shift_y) % 1 end
        now[i] = { x = x, y = y, rgb = star.rgb,
                   brightness = star.base * (0.45 + 0.55 * wave) }
    end
    return now
end
-- }}}

return choreography

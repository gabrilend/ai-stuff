--[[
Locomotion (Issue 516c)

How a WC3 ground unit gets from here to there:

  - Constant speed. A unit is either walking at its full move speed or
    standing; there is no acceleration or braking.
  - Turning before walking. A unit turns toward where it is going at its turn
    rate, and walks only while that direction lies within its propulsion
    window of its facing. Outside the window it turns in place; inside, it
    walks along its facing while it keeps turning, so a sharp change of
    direction is a turn on the spot followed by a short arc.
  - Walking over things. Its feet follow the surfaces under it (ramps,
    stairs, walkways) through a ground function, and it can only step up a
    little at a time (see geometry/kit.lua height_at).

Numbers are WC3 units (128 to a terrain tile) and seconds.

    local loco = require("runtime.locomotion")
    local u = loco.new(loco.UNIT_TYPES.archer, x, y, z, facing)
    local done = loco.follow(u, route, dt, ground)   -- route: { {x=, y=}, ... }

STAND-IN VALUES. The move speed 270 is WC3's "average" speed. The rest
(TURN_SCALE, the propulsion window, the attack numbers in UNIT_TYPES) are
placeholders chosen to look right, not measured; issue 516d says how to
measure each on a real install. Change them in one place: here.
]]

local loco = {}

-- {{{ Constants

-- Radians per second of turning for each 1.0 of a unit's turn rate field
-- (umvr). STAND-IN: the field's true unit is unmeasured. At 10, a turn rate
-- of 0.6 turns a unit about in half a second.
loco.TURN_SCALE = 10.0

-- A route waypoint counts as reached within this distance, so units round
-- corners instead of stopping on every waypoint. The last one is exact.
loco.PASS_RADIUS = 24

-- {{{ Unit types
-- Stat blocks; object editor field codes in comments where the project's
-- w3u parser knows them.
-- STAND-INS except speed: see the header.
loco.UNIT_TYPES = {
    archer = {
        speed = 270,             -- umvs, movement speed
        turn_rate = 0.6,         -- umvr
        propwin = 60,            -- uprw, propulsion window, degrees
        collision = 16,          -- ucol
        acquire = 600,           -- uacq, acquisition range
        range = 500,             -- ua1r, attack range
        cooldown = 1.5,          -- ua1c, seconds between attacks
        attack_point = 0.4,      -- windup before the arrow leaves, seconds
        backswing = 0.3,         -- recovery after release, seconds
        face_tolerance = 20,     -- degrees off target allowed when releasing
        missile_speed = 900,     -- arrow speed, units per second
        missile_arc = 0.15,      -- how high the arrow arcs, as a fraction of its flight
    },
    dummy = {
        speed = 180,
        turn_rate = 0.3,
        propwin = 60,
        collision = 24,
    },
}
-- }}}
-- }}}

-- {{{ Angles

-- {{{ loco.angle_diff
-- Signed smallest turn from angle a to angle b, in (-pi, pi]
function loco.angle_diff(a, b)
    local d = (b - a) % (2 * math.pi)
    if d > math.pi then d = d - 2 * math.pi end
    return d
end
-- }}}

-- {{{ loco.turn_speed
-- Radians per second for a turn rate field value
function loco.turn_speed(turn_rate)
    return turn_rate * loco.TURN_SCALE
end
-- }}}
-- }}}

-- {{{ loco.new
-- A mover with the given stats, standing at (x, y, z) facing `facing`
-- (radians, 0 = east, counter-clockwise).
function loco.new(stats, x, y, z, facing)
    return {
        x = x, y = y, z = z or 0,
        facing = facing or 0,
        speed = stats.speed,
        turn = loco.turn_speed(stats.turn_rate),
        window = math.rad(stats.propwin or 60),
        stats = stats,
        route = nil,
        route_index = 1,
        walked = 0,          -- total distance walked (animation stride)
        walking = false,     -- walked this tick
    }
end
-- }}}

-- {{{ loco.turn_toward
-- Turn up to turn * dt toward angle. Returns how far off it still is.
function loco.turn_toward(u, angle, dt)
    local diff = loco.angle_diff(u.facing, angle)
    local step = u.turn * dt
    if math.abs(diff) <= step then
        u.facing = angle
        return 0
    end
    u.facing = (u.facing + (diff > 0 and step or -step)) % (2 * math.pi)
    return math.abs(diff) - step
end
-- }}}

-- {{{ loco.step
-- One tick toward (tx, ty). ground(x, y, z_now) -> z gives the height to
-- stand at (flat ground when nil). radius: how close counts as arrived.
-- Returns true once arrived.
function loco.step(u, tx, ty, dt, ground, radius)
    u.walking = false
    local dx, dy = tx - u.x, ty - u.y
    local dist = math.sqrt(dx * dx + dy * dy)
    radius = radius or 0
    if dist <= math.max(radius, 1e-6) then
        return true
    end

    local off = loco.turn_toward(u, math.atan2(dy, dx), dt)
    if off > u.window then
        return false  -- outside the propulsion window: turn in place
    end

    -- Walk along the facing. Close enough to reach this tick: land on it.
    local travel = u.speed * dt
    local nx, ny
    if travel >= dist then
        nx, ny = tx, ty
        travel = dist
    else
        nx = u.x + math.cos(u.facing) * travel
        ny = u.y + math.sin(u.facing) * travel
    end

    local nz = ground and ground(nx, ny, u.z) or 0
    u.x, u.y, u.z = nx, ny, nz
    u.walked = u.walked + travel
    u.walking = true

    local rx, ry = tx - nx, ty - ny
    return math.sqrt(rx * rx + ry * ry) <= math.max(radius, 1e-6)
end
-- }}}

-- {{{ loco.set_route
function loco.set_route(u, route)
    u.route = route
    u.route_index = 1
end
-- }}}

-- {{{ loco.follow
-- One tick along the unit's route (loco.set_route), or along `route` when
-- given (it is set first if it differs). Passes intermediate waypoints
-- within PASS_RADIUS; stops exactly on the last. Returns true when done.
function loco.follow(u, route, dt, ground)
    if route and route ~= u.route then loco.set_route(u, route) end
    local r = u.route
    if not r or u.route_index > #r then
        u.walking = false
        return true
    end
    local last = u.route_index == #r
    local wp = r[u.route_index]
    if loco.step(u, wp.x, wp.y, dt, ground, last and 0 or loco.PASS_RADIUS) then
        u.route_index = u.route_index + 1
    end
    return u.route_index > #r
end
-- }}}

-- {{{ loco.distance
-- Distance on the ground plane (WC3 ranges ignore height)
function loco.distance(a, b)
    local dx, dy = b.x - a.x, b.y - a.y
    return math.sqrt(dx * dx + dy * dy)
end
-- }}}

return loco

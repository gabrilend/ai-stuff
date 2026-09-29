--[[
Behaviours (Issue 516c)

Small state machines that drive movers from runtime/locomotion.lua:

  nav     - a walk graph of points joined by lanes, and shortest routes on it
  garrison - march to an assigned post by route, then hold it facing out;
            with a bow, acquire targets in range, turn to face them, draw,
            loose an arrow, recover, and wait out the cooldown
  patrol  - walk a closed loop for ever
  volley  - arrows in flight: they home on their target as WC3 missiles do,
            arcing up by the missile arc, and report a hit on arrival

    local behaviors = require("runtime.behaviors")
    local g = behaviors.nav()
    g:lane({ {0, 0}, {0, 400}, {300, 400} })
    local route = g:route_between(0, 0, 300, 400)

    local b = behaviors.garrison(unit, route, post)
    b:update(dt, world)   -- world: { ground = fn, targets = list, volley = v }
]]

local loco = require("runtime.locomotion")

local behaviors = {}

-- {{{ Walk graph

local Nav = {}
Nav.__index = Nav

-- {{{ behaviors.nav
function behaviors.nav()
    return setmetatable({ nodes = {}, edges = {}, by_key = {} }, Nav)
end
-- }}}

-- {{{ Nav:point
-- The node at (x, y), made if new. Lanes that pass through the same point
-- share its node, which is how lanes join.
function Nav:point(x, y)
    local key = string.format("%.1f,%.1f", x, y)
    local id = self.by_key[key]
    if not id then
        id = #self.nodes + 1
        self.nodes[id] = { x = x, y = y, id = id }
        self.edges[id] = {}
        self.by_key[key] = id
    end
    return id
end
-- }}}

-- {{{ Nav:link
function Nav:link(a, b)
    local na, nb = self.nodes[a], self.nodes[b]
    local d = loco.distance(na, nb)
    self.edges[a][b] = d
    self.edges[b][a] = d
end
-- }}}

-- {{{ Nav:lane
-- Join points { {x, y}, ... } in order. Returns their node ids.
function Nav:lane(points)
    local ids = {}
    for i, p in ipairs(points) do
        ids[i] = self:point(p[1], p[2])
        if i > 1 then self:link(ids[i - 1], ids[i]) end
    end
    return ids
end
-- }}}

-- {{{ Nav:nearest
function Nav:nearest(x, y)
    local best, best_d = nil, math.huge
    for id, n in ipairs(self.nodes) do
        local dx, dy = n.x - x, n.y - y
        local d = dx * dx + dy * dy
        if d < best_d then best, best_d = id, d end
    end
    return best
end
-- }}}

-- {{{ Nav:route
-- Shortest route between two nodes (Dijkstra), as { {x=, y=}, ... }
-- including both ends; nil when they are not connected.
function Nav:route(from, to)
    local dist, prev, done = { [from] = 0 }, {}, {}
    while true do
        local best, best_d = nil, math.huge
        for id, d in pairs(dist) do
            if not done[id] and d < best_d then best, best_d = id, d end
        end
        if not best then return nil end
        if best == to then break end
        done[best] = true
        for nb, w in pairs(self.edges[best]) do
            if not done[nb] and best_d + w < (dist[nb] or math.huge) then
                dist[nb] = best_d + w
                prev[nb] = best
            end
        end
    end
    local route, id = {}, to
    while id do
        table.insert(route, 1, { x = self.nodes[id].x, y = self.nodes[id].y })
        id = prev[id]
    end
    return route
end
-- }}}

-- {{{ Nav:route_between
-- Route between the nodes nearest two points
function Nav:route_between(x1, y1, x2, y2)
    return self:route(self:nearest(x1, y1), self:nearest(x2, y2))
end
-- }}}
-- }}}

-- {{{ Volley (arrows in flight)

local Volley = {}
Volley.__index = Volley

-- {{{ behaviors.volley
function behaviors.volley()
    return setmetatable({ arrows = {} }, Volley)
end
-- }}}

-- {{{ Volley:loose
-- An arrow from (x, y, z) homing on target (a table with x, y, z; aimed at
-- its middle, aim_height above its feet). speed in units per second; arc
-- lifts its path by arc * flight distance at mid-flight.
function Volley:loose(x, y, z, target, speed, arc, aim_height)
    local a = { x = x, y = y, z = z, sx = x, sy = y, sz = z,
                target = target, speed = speed, arc = arc or 0,
                aim = aim_height or 50, travelled = 0,
                dx = 1, dy = 0, dz = 0 }
    self.arrows[#self.arrows + 1] = a
    return a
end
-- }}}

-- {{{ Volley:update
-- Move every arrow. Returns the targets hit this tick, and the arrows
-- that hit them (with whatever the caller stored on them, e.g. damage).
function Volley:update(dt)
    local hits, arrived = {}, {}
    local keep = {}
    for _, a in ipairs(self.arrows) do
        local t = a.target
        -- straight-line position toward where the target is now
        local tx, ty, tz = t.x, t.y, (t.z or 0) + a.aim
        local dx, dy = tx - a.sx, ty - a.sy
        local flight = math.sqrt(dx * dx + dy * dy)   -- launch point to target now
        a.travelled = a.travelled + a.speed * dt
        local frac = flight > 0 and math.min(1, a.travelled / flight) or 1
        local px = a.sx + dx * frac
        local py = a.sy + dy * frac
        local pz = a.sz + (tz - a.sz) * frac
            + a.arc * flight * 4 * frac * (1 - frac)
        a.dx, a.dy, a.dz = px - a.x, py - a.y, pz - a.z
        a.x, a.y, a.z = px, py, pz
        if frac >= 1 then
            hits[#hits + 1] = t
            arrived[#arrived + 1] = a
        else
            keep[#keep + 1] = a
        end
    end
    self.arrows = keep
    return hits, arrived
end
-- }}}
-- }}}

-- {{{ Garrison

local Garrison = {}
Garrison.__index = Garrison

-- {{{ behaviors.garrison
-- unit: a mover (loco.new). route: the walk to its post. post: { x, y,
-- facing } where it stands and which way it looks out.
function behaviors.garrison(unit, route, post)
    local b = setmetatable({ unit = unit, post = post, state = "march",
                             timer = 0, cooldown = 0, target = nil,
                             draw = 0 }, Garrison)
    loco.set_route(unit, route)
    return b
end
-- }}}

-- {{{ Garrison:acquire
-- Nearest target within acquisition range (ground distance)
function Garrison:acquire(targets)
    local stats = self.unit.stats
    local best, best_d = nil, stats.acquire or 0
    for _, t in ipairs(targets or {}) do
        local d = loco.distance(self.unit, t)
        if d <= best_d then best, best_d = t, d end
    end
    return best
end
-- }}}

-- {{{ Garrison:update
-- world: { ground = fn(x, y, z_now) -> z, targets = { {x, y, z}, ... },
--          volley = behaviors.volley() }
function Garrison:update(dt, world)
    local u = self.unit
    local stats = u.stats
    self.cooldown = math.max(0, self.cooldown - dt)

    if self.state == "march" then
        if loco.follow(u, nil, dt, world.ground) then
            self.state = "hold"
        end
        return
    end

    u.walking = false

    if self.state == "hold" then
        self.draw = 0
        if stats.range then
            local t = self:acquire(world.targets)
            if t then
                self.target = t
                self.state = "aim"
                return
            end
        end
        loco.turn_toward(u, self.post.facing, dt)
        return
    end

    local t = self.target
    local in_range = t and loco.distance(u, t) <= stats.range + 0.001

    if self.state == "aim" then
        -- a target that walked out of range is let go (a garrisoned bowman
        -- holds its post rather than chasing)
        if not in_range then
            self.target, self.state = nil, "hold"
            return
        end
        local off = loco.turn_toward(u, math.atan2(t.y - u.y, t.x - u.x), dt)
        if off <= math.rad(stats.face_tolerance or 20) and self.cooldown <= 0 then
            -- the cooldown runs from the start of one attack to the start
            -- of the next, so the windup counts toward it
            self.cooldown = stats.cooldown
            self.state, self.timer = "draw", 0
        end
        return
    end

    if self.state == "draw" then
        -- keep turning with the target through the windup
        loco.turn_toward(u, math.atan2(t.y - u.y, t.x - u.x), dt)
        self.timer = self.timer + dt
        self.draw = math.min(1, self.timer / stats.attack_point)
        if self.timer >= stats.attack_point then
            local hx = u.x + math.cos(u.facing) * 22
            local hy = u.y + math.sin(u.facing) * 22
            if world.volley then
                world.volley:loose(hx, hy, u.z + 60, t, stats.missile_speed, stats.missile_arc)
            end
            self.state, self.timer, self.draw = "recover", 0, 0
            self.shots = (self.shots or 0) + 1
        end
        return
    end

    if self.state == "recover" then
        self.timer = self.timer + dt
        if self.timer >= stats.backswing then
            self.state = in_range and "aim" or "hold"
            if not in_range then self.target = nil end
        end
    end
end
-- }}}
-- }}}

-- {{{ Patrol

-- {{{ behaviors.patrol
-- Walk the closed loop of points { {x=, y=}, ... } for ever
function behaviors.patrol(unit, loop)
    local b = { unit = unit, loop = loop, index = 1 }
    function b:update(dt, world)
        local wp = self.loop[self.index]
        if loco.step(self.unit, wp.x, wp.y, dt, world and world.ground, loco.PASS_RADIUS) then
            self.index = self.index % #self.loop + 1
        end
    end
    return b
end
-- }}}
-- }}}

return behaviors

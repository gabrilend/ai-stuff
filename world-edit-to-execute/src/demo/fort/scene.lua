--[[
Fort Scene (Issue 516e)

A slate-blue fort on a blue plinth. Orange bowmen file in through the
gatehouse, climb the ramp inside the east wall, spread along the walkways
and up the belltower stairs, and man 25 posts. Straw dummies trundle round
outside; bowmen within range turn, draw, and loose arrows at them.

Headless: build(), update() and paint() only need a render module for
paint, so the whole scene runs in tests.

    local fort = require("demo.fort.scene")
    local s = fort.build()
    fort.update(s, 0.02)           -- one tick
    fort.paint(s, render)          -- this frame's units and arrows
]]

local kit = require("geometry.kit")
local figures = require("geometry.figures")
local loco = require("runtime.locomotion")
local behaviors = require("runtime.behaviors")

local fort = {}

-- {{{ Layout (WC3 units; the fort's centre is 0, 0)
fort.LAYOUT = {
    plinth = 2304,        -- side of the blue square
    plinth_height = 32,
    half = 768,           -- outer half-width of the walls
    thickness = 160,
    wall_height = 288,
    belfry_floor = 576,   -- above the ground
    spawn = { x = 0, y = -1600 },
    release_every = 0.5,  -- seconds between bowmen setting off
    dummies = 4,
    dummy_loop = 1040,    -- radius of the dummies' circuit
}
-- }}}

-- {{{ build_structures
-- The fort's stones. Returns the world and the gate's ground points.
local function build_structures(L)
    local w = kit.new()
    local z = L.plinth_height
    local top = z + L.wall_height
    local c = L.half - L.thickness / 2          -- wall centre lines at +/- c

    -- the blue square, and a ramp up onto it before the gate
    w:slab(0, 0, L.plinth, L.plinth, z, 0)
    w:ramp(0, -L.plinth / 2 - 128, 0, 0, -L.plinth / 2, z, 448, kit.COLORS.plinth)

    local wall = { thickness = L.thickness, height = L.wall_height, z = z, outward = -1 }
    -- south wall, either side of the gatehouse
    w:rampart(-L.half, -c, -352, -c, wall)
    w:rampart(352, -c, L.half, -c, wall)
    -- east, north (up to the belltower), west (up to the belltower)
    w:rampart(c, -L.half, c, L.half, wall)
    w:rampart(L.half, c, -512, c, wall)
    w:rampart(-c, 512, -c, -L.half, wall)

    local gate = w:gatehouse(0, -c, { z = z, height = L.wall_height, thickness = L.thickness })

    -- ramp up the inside of the east wall, and a landing at its top
    local rx = c - L.thickness / 2 - 64
    w:ramp(rx, -352, z, rx, 416, top, 128)
    w:slab(rx, 480, 128, 128, L.wall_height, z, 0, kit.COLORS.stone_dark)

    -- belltower in the north-west corner, stairs up from the north walkway
    local floor = w:belltower(-640, 640, 256, L.belfry_floor - z, z)
    w:stairs(-192, c, top, -512, c, floor, L.thickness, 8)

    return w, gate, { top = top, c = c, rx = rx, floor = floor }
end
-- }}}

-- {{{ build_nav
-- Lanes a bowman can walk, and the 25 posts along them.
-- Returns the graph and the posts (farthest first).
local function build_nav(L, gate, m)
    local g = behaviors.nav()
    local c, rx = m.c, m.rx
    local S, N, E, W = -math.pi / 2, math.pi / 2, 0, math.pi
    local posts = {}
    local function post(x, y, facing, where)
        posts[#posts + 1] = { x = x, y = y, facing = facing, where = where }
        return { x, y }
    end

    -- outside, through the gate, across the yard to the foot of the ramp
    g:lane({ { L.spawn.x, L.spawn.y }, { gate.outside.x, gate.outside.y },
             { gate.inside.x, gate.inside.y }, { rx, -440 } })
    -- up the ramp, over the landing, onto the east walkway
    g:lane({ { rx, -440 }, { rx, -352 }, { rx, 416 }, { rx, 480 }, { c, 480 } })

    -- east walkway south to the corner, posts looking east
    g:lane({ { c, 480 }, post(c, 300, E, "east wall"), post(c, 100, E, "east wall"),
             post(c, -100, E, "east wall"), post(c, -300, E, "east wall"),
             post(c, -500, E, "east wall"), { c, -c } })
    -- south walkway west, over the gate, posts looking south
    g:lane({ { c, -c }, post(560, -c, S, "south wall"), post(440, -c, S, "south wall"),
             post(240, -c, S, "gate tower"), post(0, -c, S, "over the gate"),
             post(-240, -c, S, "gate tower"), post(-440, -c, S, "south wall"),
             post(-560, -c, S, "south wall"), { -c, -c } })
    -- west walkway north, posts looking west
    g:lane({ { -c, -c }, post(-c, -500, W, "west wall"), post(-c, -300, W, "west wall"),
             post(-c, -100, W, "west wall"), post(-c, 100, W, "west wall"),
             post(-c, 300, W, "west wall"), { -c, 480 } })
    -- east walkway north to the corner, then the north walkway west
    g:lane({ { c, 480 }, { c, c }, post(560, c, N, "north wall"), post(360, c, N, "north wall"),
             post(160, c, N, "north wall"), post(-40, c, N, "north wall"), { -192, c } })
    -- up the stairs into the belfry, a bowman at each open side
    g:lane({ { -192, c }, { -512, c }, { -592, 640 }, { -640, 640 } })
    for _, b in ipairs({ { -712, 640, W }, { -640, 712, N }, { -568, 640, E }, { -640, 568, S } }) do
        g:lane({ { -640, 640 }, post(b[1], b[2], b[3], "belfry") })
    end

    -- farthest posts first, so the column doesn't stop to let others by
    for _, p in ipairs(posts) do
        p.route = g:route_between(L.spawn.x, L.spawn.y, p.x, p.y)
        local len = 0
        for i = 2, #p.route do len = len + loco.distance(p.route[i - 1], p.route[i]) end
        p.length = len
    end
    table.sort(posts, function(a, b) return a.length > b.length end)
    return g, posts
end
-- }}}

-- {{{ fort.build
function fort.build(layout)
    local L = layout or fort.LAYOUT
    local world, gate, m = build_structures(L)
    local nav, posts = build_nav(L, gate, m)
    local s = {
        layout = L, world = world, nav = nav, posts = posts, measures = m,
        bowmen = {}, dummies = {}, volley = behaviors.volley(),
        time = 0, released = 0, hits = 0, shots = 0, rings = 0,
    }
    s.ground = function(x, y, z_now) return world:height_at(x, y, z_now) end

    -- the dummies' circuit: a ring of waypoints outside the walls
    local loop = {}
    for i = 0, 23 do
        local a = i / 24 * 2 * math.pi
        loop[#loop + 1] = { x = math.cos(a) * L.dummy_loop, y = math.sin(a) * L.dummy_loop }
    end
    for i = 1, L.dummies do
        local start = math.floor((i - 1) * #loop / L.dummies) + 1
        local p = loop[start]
        local u = loco.new(loco.UNIT_TYPES.dummy, p.x, p.y, s.ground(p.x, p.y, 0),
                           math.atan2(p.y, p.x) + math.pi / 2)
        local b = behaviors.patrol(u, loop)
        b.index = start % #loop + 1
        u.flash = 0
        s.dummies[i] = b
    end
    return s
end
-- }}}

-- {{{ fort.update
-- One tick of dt seconds
function fort.update(s, dt)
    s.time = s.time + dt
    local L = s.layout

    -- release the next bowman from the spawn point
    while s.released < #s.posts and s.time >= s.released * L.release_every do
        s.released = s.released + 1
        local p = s.posts[s.released]
        local u = loco.new(loco.UNIT_TYPES.archer, L.spawn.x, L.spawn.y, 0, math.pi / 2)
        local b = behaviors.garrison(u, p.route, p)
        s.bowmen[#s.bowmen + 1] = b
    end

    local targets = {}
    for _, d in ipairs(s.dummies) do
        d:update(dt, s)
        d.unit.flash = math.max(0, d.unit.flash - dt)
        targets[#targets + 1] = d.unit
    end

    local world = { ground = s.ground, targets = targets, volley = s.volley }
    for _, b in ipairs(s.bowmen) do
        local before = b.shots or 0
        b:update(dt, world)
        s.shots = s.shots + (b.shots or 0) - before
    end

    for _, t in ipairs(s.volley:update(dt)) do
        t.flash = 0.15
        s.hits = s.hits + 1
    end
end
-- }}}

-- {{{ fort.manned
-- How many bowmen have reached their posts
function fort.manned(s)
    local n = 0
    for _, b in ipairs(s.bowmen) do
        if b.state ~= "march" then n = n + 1 end
    end
    return n
end
-- }}}

-- {{{ fort.cycle_rings
-- Range rings: off -> the belfry's first bowman -> every manned bowman
function fort.cycle_rings(s)
    s.rings = (s.rings + 1) % 3
end
-- }}}

-- {{{ fort.frame_prims
-- This frame's moving things, as primitives
function fort.frame_prims(s)
    local prims = {}
    local function add(list)
        for _, p in ipairs(list) do prims[#prims + 1] = p end
    end
    for _, b in ipairs(s.bowmen) do
        local u = b.unit
        add(figures.bowman(u.x, u.y, u.z, u.facing,
            { stride = u.walking and u.walked or nil, draw = b.draw }))
    end
    for _, d in ipairs(s.dummies) do
        local u = d.unit
        add(figures.dummy(u.x, u.y, u.z, u.facing, { stride = u.walked, flash = u.flash }))
    end
    for _, a in ipairs(s.volley.arrows) do
        add(figures.arrow(a.x, a.y, a.z, a.dx, a.dy, a.dz))
    end
    if s.rings > 0 then
        for i, b in ipairs(s.bowmen) do
            if b.state ~= "march" and (s.rings == 2 or i == 1) then
                local u, st = b.unit, b.unit.stats
                add(figures.ring(u.x, u.y, u.z + 4, st.range, { 255, 200, 80 }))
                if s.rings == 1 then
                    add(figures.ring(u.x, u.y, u.z + 4, st.acquire, { 120, 220, 255 }))
                end
            end
        end
    end
    return prims
end
-- }}}

-- {{{ fort.paint
function fort.paint(s, render, ground)
    return kit.emit_prims(fort.frame_prims(s), render, true, ground)
end
-- }}}

-- {{{ fort.status
function fort.status(s)
    return string.format("%.1fs  bowmen %d/%d manned  arrows %d loosed, %d hit",
        s.time, fort.manned(s), #s.posts, s.shots, s.hits)
end
-- }}}

return fort

#!/usr/bin/env luajit
--[[
crowd-lua-run.lua - runs a crossing scene on the Lua crowd, the reference the C crowd is checked against (issue 515k)

What this is: reads a scene (crowd-scene.lua's format), puts its units into
the Lua crowd (src/runtime/crowd.lua), sends each army to the other's home
and, whenever nobody is moving any more, back again -- exactly what the C
runner (crowd-run.c) does -- and prints every unit's position at set
ticks, so the two can be compared line by line.

Output: for every EVERY-th tick, "tick T" and then "X Y" per unit (17
significant digits).

Usage: luajit crowd-lua-run.lua DIR SCENE TICKS EVERY
]]

local DIR, SCENE = arg[1], arg[2]
local TICKS, EVERY = tonumber(arg[3]), tonumber(arg[4])
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path
local crowd = require("runtime.crowd")

-- {{{ read the scene
local f = assert(io.open(SCENE))
local w, h, cell = f:read("*n", "*n", "*n")
f:read("*l")
local grid = {}
for y = 1, h do
    local row = f:read("*l")
    grid[y] = {}
    for x = 1, w do grid[y][x] = row:sub(x, x) ~= "#" end
end
local _, hx1, hy1, hx2, hy2 = f:read("*l"):match("(%S+) (%S+) (%S+) (%S+) (%S+)")
local homes = { { tonumber(hx1), tonumber(hy1) }, { tonumber(hx2), tonumber(hy2) } }
local n = tonumber(f:read("*l"):match("UNITS (%d+)"))
local c = crowd.new(grid, cell)
local armies = { {}, {} }
for id = 1, n do
    local x, y, r, speed, team = f:read("*n", "*n", "*n", "*n", "*n")
    c:add(id, x, y, r, speed, team)
    table.insert(armies[team], id)
end
f:close()
-- }}}

-- {{{ local function send(to_home)
-- Each army as a group: to the other's home, or back to its own.
local function send(to_home)
    for army = 1, 2 do
        local home = homes[to_home and army or (3 - army)]
        c:move_group(armies[army], home[1], home[2])
    end
end
-- }}}

send(false)
local across = true
local out = {}
for t = 1, TICKS do
    c:tick(1 / 62.5)
    local moving = false
    for id = 1, n do if c.units[id].moving then moving = true; break end end
    if not moving then
        across = not across
        send(not across)
    end
    if t % EVERY == 0 then
        out[#out + 1] = "tick " .. t
        for id = 1, n do out[#out + 1] = string.format("%.17g %.17g", c.units[id].x, c.units[id].y) end
    end
end
print(table.concat(out, "\n"))

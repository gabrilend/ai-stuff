#!/usr/bin/env luajit
--[[
crowd-scene.lua - writes a crossing scene for the C crowd, from the Lua one (issue 515k)

What this is: the benchmark's scene at a given army size, written as text
so the C crowd and the Lua crowd start from exactly the same ground and
the same units. The armies are placed by the Lua crossing game
(net/crossing_sim.lua, place()), so there is one source of truth.

Output, one item a line:
  W H CELL                     the ground's size in cells, and a cell's size
  ROW x H                      the ground, top row first: "#" wall, else ground
  HOMES X1 Y1 X2 Y2            each army's home point
  UNITS N
  X Y RADIUS SPEED TEAM x N    each unit, in id order (team 1 or 2)
Numbers are written with 17 significant digits, so they come back as the
same doubles.

Usage: luajit crowd-scene.lua DIR PER_ARMY > scene.txt
]]

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
local per_army = tonumber(arg[2]) or error("usage: crowd-scene.lua DIR PER_ARMY", 0)
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local crossing_sim = require("net.crossing_sim")
local map, c = crossing_sim.place({ per_army = per_army })
local out = {}
-- {{{ local function w(...)
local function w(...) out[#out + 1] = string.format(...) end
-- }}}
w("%d %d %.17g", #map.rows[1], #map.rows, map.cell)
for _, row in ipairs(map.rows) do w("%s", row) end
w("HOMES %.17g %.17g %.17g %.17g", map.homes[1][1], map.homes[1][2], map.homes[2][1], map.homes[2][2])
w("UNITS %d", #c.order)
for _, id in ipairs(c.order) do
    local u = c.units[id]
    w("%.17g %.17g %.17g %.17g %d", u.x, u.y, u.radius, u.speed, u.team)
end
print(table.concat(out, "\n"))

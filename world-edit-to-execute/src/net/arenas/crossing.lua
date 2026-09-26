--[[
crossing.lua - the crossing-armies demo's map: a field split by a wall with one gap (issue 804)

What this is: the map both the server and the renderer read, the way both
sides of a Warcraft III game read the same map file. The ground is built
from a few numbers rather than drawn by hand, so it can't come out
lopsided, and returned as text rows, top row first: "#" a wall, "." open
ground. The armies are listed by size: each is packed round its home
point, and sent to the other army's home point.

Sizes, as the owner asked (2026-09-25: "Can you make some units of larger
size?"): small, medium and large, the large ones slower.
]]

local W, H = 40, 22           -- cells
local WALL_X = 20             -- the dividing wall's column
local GAP = { 6, 17 }         -- its gap, rows (twelve)
-- 2x2 pillars, top-left cells; mirrored east. Four cells apart: at two
-- apart they made a narrow channel right on the armies' straight line,
-- and the two armies funnelled into it head-on
local PILLARS = { { 14, 7 }, { 14, 14 } }

-- {{{ local function build()
local function build()
    local cells = {}
    for y = 1, H do
        cells[y] = {}
        for x = 1, W do
            local edge = x == 1 or x == W or y == 1 or y == H
            local wall = x == WALL_X and (y < GAP[1] or y > GAP[2])
            cells[y][x] = (edge or wall) and "#" or "."
        end
    end
    for _, p in ipairs(PILLARS) do
        for dy = 0, 1 do
            for dx = 0, 1 do
                cells[p[2] + dy][p[1] + dx] = "#"
                cells[p[2] + dy][W + 1 - (p[1] + dx)] = "#"
            end
        end
    end
    local rows = {}
    for y = 1, H do rows[y] = table.concat(cells[y]) end
    return rows
end
-- }}}

-- Each army: how many of each size (radius, world units; speed, world
-- units a second). Both armies are the same; the east one is mirrored.
local ARMY = {
    { count = 4,  radius = 0.8,  speed = 2.2 },   -- large
    { count = 20, radius = 0.5,  speed = 3.0 },   -- medium
    { count = 16, radius = 0.35, speed = 3.6 },   -- small
}

return {
    cell = 1.0,          -- world units a cell
    rows = build(),
    army = ARMY,
    homes = { { 6.5, 11.5 }, { W - 6.5, 11.5 } },   -- west, east: world units
}

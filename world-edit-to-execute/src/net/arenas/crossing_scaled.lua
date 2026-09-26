--[[
crossing_scaled.lua - the crossing demo's map at any army size (issue 515k)

What this is: the crossing map (a field split by a wall with one gap, two
pillars each side, two armies of three sizes swapping sides) built for a
given number of units per army, for the benchmark that runs the crowd at
500 to 5,000 units. Everything grows with the square root of the army size
over 40, so the armies fill the field about as much at every size; at 40
units per army it is exactly the demo's map (net/arenas/crossing.lua is
this at 40).

Usage: local build = require("net.arenas.crossing_scaled")
       local map = build(250)   -- 250 units per army, 500 in all
Returns the same shape as crossing.lua: cell, rows, army, homes.
]]

-- {{{ local function round(x)
local function round(x) return math.floor(x + 0.5) end
-- }}}

-- {{{ local function build(per_army)
local function build(per_army)
    local s = math.sqrt(per_army / 40)
    local W, H = round(40 * s), round(22 * s)
    local WALL_X = round(20 * s)
    local gap_rows = round(12 * s)
    local gap_top = math.floor((H - gap_rows) / 2) + 1
    local GAP = { gap_top, gap_top + gap_rows - 1 }
    -- 2x2 pillars, their top-left cells; mirrored east
    local PILLARS = { { round(14 * s), round(7 * s) }, { round(14 * s), round(14 * s) } }
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
    -- the sizes in the demo's proportions: 1 large, 5 medium, 4 small in 10
    local large = round(per_army / 10)
    local small = round(per_army * 4 / 10)
    local medium = per_army - large - small
    return {
        cell = 1.0,
        rows = rows,
        army = {
            { count = large,  radius = 0.8,  speed = 2.2 },
            { count = medium, radius = 0.5,  speed = 3.0 },
            { count = small,  radius = 0.35, speed = 3.6 },
        },
        homes = { { 6.5 * s, H / 2 + 0.5 }, { W - 6.5 * s, H / 2 + 0.5 } },
    }
end
-- }}}

return build

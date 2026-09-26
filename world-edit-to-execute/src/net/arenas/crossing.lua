--[[
crossing.lua - the crossing-armies demo's map: a field split by a wall with one gap (issue 804)

What this is: the map both the server and the renderer read, the way both
sides of a Warcraft III game read the same map file. It is built from a
few numbers rather than drawn by hand, so it can't come out lopsided, and
returned as text rows, top row first: "#" a wall, "." open ground, "w" a
west-army unit's starting cell, "e" an east-army unit's. Each unit is sent
to the cell mirrored across the middle (the west army to where the east
army started, and back).

The gap is twelve cells for armies eight deep: an eight-cell gap jams for
good (runtime/crowd.lua's known limit). Two pillars on each side give the
paths something to go around besides each other.
]]

local W, H = 40, 22           -- cells
local WALL_X = 20             -- the dividing wall's column
local GAP = { 6, 17 }         -- its gap, rows (twelve)
local ARMY_ROWS = { 8, 15 }   -- eight deep
local WEST_COLS = { 4, 8 }    -- five wide; the east army mirrors it
local PILLARS = { { 14, 9 }, { 14, 13 } }   -- 2x2, top-left cells; mirrored east

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
    for y = ARMY_ROWS[1], ARMY_ROWS[2] do
        for x = WEST_COLS[1], WEST_COLS[2] do
            cells[y][x] = "w"
            cells[y][W + 1 - x] = "e"
        end
    end
    local rows = {}
    for y = 1, H do rows[y] = table.concat(cells[y]) end
    return rows
end
-- }}}

return {
    cell = 1.0,          -- world units a cell
    unit_radius = 0.4,
    unit_speed = 3.0,    -- world units a second
    rows = build(),
}

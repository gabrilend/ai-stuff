-- 024-the-map-from-beyond.lua - the map as seen from far beyond, for the arch's band.
--
-- In plain terms: the arch's band is the console's display of the map — "not
-- through its opening, but painted onto its surface from some distant
-- beyond". This file paints that picture each frame: the whole round map
-- seen from straight above, very far away (so the tiers are evenly spaced,
-- unfolded), with every unit a dot in its owner's color and every cuboid a
-- larger dot in its own. The band then shows its ally's quadrant of this
-- picture, unrolled along its length (see 015).
--
-- This is viewing code: it reads the front blocks and writes only its picture.

local M = {}

-- {{{ function M.new()
-- `flat_map` is the evenly spaced map canvas from 012.
function M.new(size, flat_map)
    local picture = {
        size = size,
        flat_map = flat_map,
        canvas = love.graphics.newCanvas(size, size),
        unit_points = {},
        cuboid_points = {},
    }
    picture.canvas:setFilter("linear", "linear")
    return picture
end
-- }}}

-- {{{ local function spot()
-- A place (tier distance, angle) on the flat picture.
local function spot(picture, tiers, r, angle)
    local half = picture.size / 2
    local reach = half * r / tiers
    return half + reach * math.sin(angle), half - reach * math.cos(angle)
end
-- }}}

-- {{{ function M.draw()
-- Repaints the picture from the front blocks (record arrays from 005).
function M.draw(picture, units, unit_count, cuboids, cuboid_count, tiers, colors)
    local unit_points, cuboid_points = picture.unit_points, picture.cuboid_points
    for index = 0, unit_count - 1 do
        local unit = units[index]
        local x, y = spot(picture, tiers, unit.r, unit.angle)
        local color = colors[unit.owner + 1]
        unit_points[index + 1] = { x, y, color[1], color[2], color[3], 1 }
    end
    for index = 0, cuboid_count - 1 do
        local cuboid = cuboids[index]
        local x, y = spot(picture, tiers, cuboid.r, cuboid.angle)
        local color = colors[cuboid.color + 1]
        cuboid_points[index + 1] = { x, y, color[1] * 1.2, color[2] * 1.2, color[3] * 1.2, 1 }
    end

    love.graphics.push("all")
    love.graphics.setCanvas(picture.canvas)
    love.graphics.setDepthMode("always", false)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setColor(1.25, 1.25, 1.25, 1)
    love.graphics.draw(picture.flat_map, 0, 0, 0, picture.size / picture.flat_map:getWidth())
    love.graphics.setPointSize(math.max(2, picture.size / 300))
    love.graphics.points(unit_points)
    love.graphics.setPointSize(math.max(3, picture.size / 180))
    love.graphics.points(cuboid_points)
    love.graphics.pop()
end
-- }}}

return M

-- 012-made-by-formula.lua - every picture the game uses, drawn by code.
--
-- In plain terms: nothing on screen is a picture someone generated with AI.
-- The units' skin (metal panels, seams, rivets, a band in the owner's color)
-- and the flat map (tier rings, quadrant lines, tier numbers) are drawn here,
-- pixel by pixel or line by line, from formulas, when the game starts.
--
-- The unit skin stores two things per pixel, not a color: red is how bright
-- the metal is there (seams dark, rivets dark, panels light), green is how
-- much of the owner's color shows there (the band). The unit shader turns
-- those into color, so one skin serves every owner.

local M = {}

-- {{{ function M.unit_skin()
-- Returns LÖVE image data, width x height, for the unit skin.
function M.unit_skin(width, height)
    local data = love.image.newImageData(width, height)
    data:mapPixel(function(x, y)
        local u = x / width
        local v = y / height
        local brightness = 0.78
        -- panel seams: eight hoops around the body
        local hoop = (u * 8) % 1
        if hoop < 0.035 then
            brightness = 0.42
        end
        -- panel seams: six lines from tip to tip
        local line = (v * 6) % 1
        if line < 0.03 then
            brightness = 0.46
        end
        -- rivets: small dark dots beside each hoop seam
        local rivet_u = ((u * 8) % 1) - 0.09
        local rivet_v = ((v * 24) % 1) - 0.5
        if rivet_u * rivet_u * 900 + rivet_v * rivet_v * 9 < 0.6 then
            brightness = 0.35
        end
        -- a fine brushed grain across the panels
        brightness = brightness + 0.05 * math.sin(v * 900 + math.sin(u * 40) * 3)
        -- the owner's band: a broad hoop around the middle of the body
        local band = 0
        if v > 0.44 and v < 0.6 then
            band = 1
        end
        return brightness, band, 0, 1
    end)
    return data
end
-- }}}

-- {{{ function M.flat_map()
-- Draws the flat map into a new square canvas `size` pixels across: tiers
-- equally spaced (the fold is applied later, when the map is laid on the
-- folded ground), quadrant lines, faint quadrant tints in the seats' colors.
-- `seat_colors` is a list of {r, g, b}; `tiers` a whole number; `sections` a
-- list of {r, angle, radius} (tier distances and radians; see 007).
function M.flat_map(size, tiers, seat_colors, sections)
    local canvas = love.graphics.newCanvas(size, size)
    local center = size / 2
    local radius = size / 2
    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0.06, 0.07, 0.08, 1)

    -- the four quadrants, each faintly tinted with its seat's color
    for seat = 1, 4 do
        local color = seat_colors[seat]
        love.graphics.setColor(color[1], color[2], color[3], 0.07)
        -- quadrant 1 spans north to east (clockwise from up); LÖVE's angles
        -- start at +x and turn clockwise on screen, so north is -pi/2
        local start_angle = -math.pi / 2 + (seat - 1) * math.pi / 2
        love.graphics.arc("fill", center, center, radius, start_angle, start_angle + math.pi / 2, 48)
    end

    -- a faint grid of angle slices, every 15 degrees
    love.graphics.setColor(0.6, 0.7, 0.75, 0.06)
    love.graphics.setLineWidth(1)
    for slice = 0, 23 do
        local angle = slice * math.pi / 12
        love.graphics.line(center, center,
            center + radius * math.sin(angle), center - radius * math.cos(angle))
    end

    -- the tier rings: thin glass lines, brighter every other tier
    for tier = 1, tiers do
        local ring_radius = radius * tier / tiers
        local strength = (tier % 2 == 0) and 0.35 or 0.22
        love.graphics.setColor(0.7, 0.85, 0.95, strength)
        love.graphics.setLineWidth(size / 512)
        love.graphics.circle("line", center, center, ring_radius, 192)
    end

    -- the quadrant boundaries: four radial lines
    love.graphics.setColor(0.8, 0.85, 0.9, 0.3)
    love.graphics.setLineWidth(size / 400)
    for quarter = 0, 3 do
        local angle = quarter * math.pi / 2
        love.graphics.line(center, center,
            center + radius * math.sin(angle), center - radius * math.cos(angle))
    end

    -- the color-coded sections: a tinted floor and a bright edge in the color
    -- of the cuboids that belong there (section k takes color k = seat k+1)
    for index, section in ipairs(sections) do
        local color = seat_colors[index]
        local reach = radius * section.r / tiers
        local x = center + reach * math.sin(section.angle)
        local y = center - reach * math.cos(section.angle)
        local section_radius = radius * section.radius / tiers
        love.graphics.setColor(color[1], color[2], color[3], 0.28)
        love.graphics.circle("fill", x, y, section_radius, 96)
        love.graphics.setColor(color[1], color[2], color[3], 0.9)
        love.graphics.setLineWidth(size / 300)
        love.graphics.circle("line", x, y, section_radius, 96)
        love.graphics.circle("line", x, y, section_radius * 0.82, 96)
    end

    love.graphics.pop()
    return canvas
end
-- }}}

return M

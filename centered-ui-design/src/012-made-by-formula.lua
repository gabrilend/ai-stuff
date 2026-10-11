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

-- {{{ local function smooth()
local function smooth(edge0, edge1, x)
    local t = math.min(math.max((x - edge0) / (edge1 - edge0), 0), 1)
    return t * t * (3 - 2 * t)
end
-- }}}

-- {{{ local function light_of_the_hour()
-- The light at one hour, from the dial's angle (0 = noon at the top, turning
-- clockwise; pi = midnight at the bottom): deep blue at night, orange at
-- dawn and dusk, warm white at noon. Returns r, g, b.
local function light_of_the_hour(hour_angle)
    local day = math.cos(hour_angle)  -- 1 at noon, -1 at midnight
    local night = { 0.10, 0.13, 0.26 }
    local dusk = { 0.95, 0.55, 0.30 }
    local noon = { 1.00, 0.96, 0.88 }
    local to_dusk = smooth(-0.45, 0.10, day)
    local to_noon = smooth(0.05, 0.75, day)
    local light = {}
    for channel = 1, 3 do
        local value = night[channel] + (dusk[channel] - night[channel]) * to_dusk
        light[channel] = value + (noon[channel] - value) * to_noon
    end
    return light[1], light[2], light[3]
end
-- }}}

-- How each material answers the light, by where on its dial a surface looks
-- (`reach`: 0 the dial's center .. 1 its rim, where surfaces facing up look;
-- `hour_angle` as above). A dispatch table from material to formula; each
-- returns a brightness multiplier and a shine (added light).
local MATERIALS = {
    -- brushed metal: fine circular streaks, a firm highlight ring
    metal = function(reach, hour_angle)
        local body = 0.30 + 0.70 * smooth(0.10, 0.95, reach)
        local streaks = 0.06 * math.sin(hour_angle * 220 + reach * 40)
        local shine = 1.0 * math.exp(-((reach - 0.86) / 0.04) ^ 2)
        return body + streaks, shine
    end,
    -- glaze: a smooth body, a sharp bright ring and a soft sheen (ceramic, paint)
    glaze = function(reach, hour_angle)
        local body = 0.28 + 0.72 * smooth(0.05, 0.92, reach)
        local shine = 1.3 * math.exp(-((reach - 0.90) / 0.025) ^ 2)
            + 0.18 * math.exp(-((reach - 0.68) / 0.14) ^ 2)
        return body, shine
    end,
    -- earth: broad and matte, no highlight
    earth = function(reach, hour_angle)
        return 0.45 + 0.55 * smooth(0.0, 1.0, reach), 0
    end,
}

-- {{{ function M.light_at()
-- The light dial's colour at one point (x, y from -1 to 1, y up) for a
-- material: the formula the painter below fills a picture with. Plain
-- numbers in and out, so it can be checked without a window.
function M.light_at(material, x, y)
    local answer = MATERIALS[material]
    -- an unknown material is a mistake in the caller
    if answer == nil then
        error("made_by_formula: no light dial for the material '" .. tostring(material) .. "'", 2)
    end
    -- outside the disc: the rim's colour carried on, so lookups at the very
    -- edge never meet black
    local reach = math.min(math.sqrt(x * x + y * y), 1)
    local hour_angle = math.atan2(x, y)
    local r, g, b = light_of_the_hour(hour_angle)
    local body, shine = answer(reach, hour_angle)
    local day = math.max(math.cos(hour_angle), 0.12)
    return r * body + shine * r * day, g * body + shine * g * day, b * body + shine * b * day
end
-- }}}

-- {{{ function M.dial_light()
-- The light a surface receives from a material's dial, without a picture:
-- the Lua twin of dial_light() in the world shaders (013). `facing_x`,
-- `facing_y` say which way the surface faces in the viewer's terms (x right,
-- y up the screen); the window onto the dial sits `window_center` up from
-- the dial's middle with radius `window_radius`, and the dial is turned by
-- `hour_angle`. Used for the console's metal, which is not a world surface
-- but should be lit like one. Returns r, g, b.
function M.dial_light(material, facing_x, facing_y, hour_angle, window_center, window_radius)
    local px = facing_x * window_radius
    local py = window_center + facing_y * window_radius
    local c, s = math.cos(hour_angle), math.sin(hour_angle)
    return M.light_at(material, px * c + py * s, py * c - px * s)
end
-- }}}

-- {{{ function M.light_dial()
-- Paints one material's light dial (issue 213): a round picture whose rim is
-- a clock of the day — noon at the top, dusk and dawn at the sides, night at
-- the bottom — brighter toward the rim (light from above), with the
-- material's own highlight. Surfaces look up their light through a window
-- onto this dial; the dial turns with the time of day. Returns image data.
function M.light_dial(size, material)
    local data = love.image.newImageData(size, size)
    data:mapPixel(function(px, py)
        local x = (px + 0.5) / size * 2 - 1
        local y = 1 - (py + 0.5) / size * 2
        local r, g, b = M.light_at(material, x, y)
        return r, g, b, 1
    end)
    return data
end
-- }}}

-- {{{ function M.round_relief()
-- The one round picture every terrain point is drawn with (issue 214):
-- a small dome seen from straight on, stored as which way each pixel of
-- it faces — red: across (0 the left edge's side .. 1 the right's), green:
-- up (0 bottom .. 1 top), blue: how squarely it faces out (1 at the
-- middle, 0 at the rim) — and alpha: inside the circle or not. Lit by a
-- sun, one side comes out bright and the other dark; the renderer turns
-- the dome with the point's slope, so which side is bright follows the
-- sun across the day. A circle-texture utility like the console's dials.
-- Returns image data, `size` pixels square.
function M.round_relief(size)
    local data = love.image.newImageData(size, size)
    data:mapPixel(function(px, py)
        local x = (px + 0.5) / size * 2 - 1
        local y = 1 - (py + 0.5) / size * 2
        local reach = math.sqrt(x * x + y * y)
        -- outside the circle: nothing
        if reach > 1 then
            return 0.5, 0.5, 0, 0
        end
        local out = math.sqrt(1 - reach * reach)
        return 0.5 + 0.5 * x, 0.5 + 0.5 * y, out, 1
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

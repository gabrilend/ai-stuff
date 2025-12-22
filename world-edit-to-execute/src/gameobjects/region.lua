-- Region Class
-- Represents trigger regions and waygate destinations from war3map.w3r.
-- Wraps parsed region data with methods for point containment, weather, etc.
--
-- Implementation: 206d-implement-region-class
--
-- Parser output fields (from src/parsers/w3r.lua):
--   name: region name string
--   creation_number: unique ID for waygate targeting
--   bounds: {left, bottom, right, top} world coordinates
--   weather_id: 4-char weather effect code (e.g., "RAhr")
--   weather: friendly name for weather effect
--   ambient_sound: sound name from w3s, or nil
--   color: {r, g, b, a} editor color (0-255)

-- {{{ Region class
local Region = {}
Region.__index = Region

-- {{{ new
-- Create a new Region from parsed region data.
-- @param data Table from w3r.parse() containing region fields
-- @return Region instance
function Region.new(data)
    local self = setmetatable({}, Region)

    -- Core identification
    self.name = data.name or ""
    self.creation_number = data.creation_number

    -- Bounds (defensive copy)
    -- left/right are X coordinates, bottom/top are Y coordinates
    if data.bounds then
        self.bounds = {
            left = data.bounds.left,
            bottom = data.bounds.bottom,
            right = data.bounds.right,
            top = data.bounds.top,
        }
    else
        self.bounds = { left = 0, bottom = 0, right = 0, top = 0 }
    end

    -- Weather effect
    -- weather_id is the 4-char code, weather is the friendly name
    self.weather_id = data.weather_id
    self.weather = data.weather

    -- Ambient sound reference (from w3s)
    self.ambient_sound = data.ambient_sound

    -- Editor color (defensive copy)
    if data.color then
        self.color = {
            r = data.color.r or 255,
            g = data.color.g or 255,
            b = data.color.b or 255,
            a = data.color.a or 255,
        }
    else
        self.color = { r = 255, g = 255, b = 255, a = 255 }
    end

    return self
end
-- }}}

-- {{{ get_center
-- Calculate the center point of the region.
-- @return Table with x, y coordinates
function Region:get_center()
    return {
        x = (self.bounds.left + self.bounds.right) / 2,
        y = (self.bounds.bottom + self.bounds.top) / 2,
    }
end
-- }}}

-- {{{ get_size
-- Calculate the width and height of the region.
-- @return Table with width, height values
function Region:get_size()
    return {
        width = self.bounds.right - self.bounds.left,
        height = self.bounds.top - self.bounds.bottom,
    }
end
-- }}}

-- {{{ get_area
-- Calculate the area of the region in square game units.
-- @return number
function Region:get_area()
    local size = self:get_size()
    return size.width * size.height
end
-- }}}

-- {{{ contains_point
-- Check if a point is within the region bounds.
-- Uses inclusive bounds (points on edges are inside).
-- @param x X coordinate
-- @param y Y coordinate
-- @return boolean
function Region:contains_point(x, y)
    return x >= self.bounds.left and x <= self.bounds.right
       and y >= self.bounds.bottom and y <= self.bounds.top
end
-- }}}

-- {{{ overlaps_region
-- Check if this region overlaps with another region.
-- @param other Region instance
-- @return boolean
function Region:overlaps_region(other)
    -- Check if either region is completely to the left/right/above/below the other
    if self.bounds.right < other.bounds.left then return false end
    if self.bounds.left > other.bounds.right then return false end
    if self.bounds.top < other.bounds.bottom then return false end
    if self.bounds.bottom > other.bounds.top then return false end
    return true
end
-- }}}

-- {{{ has_weather
-- Check if this region has a weather effect.
-- @return boolean
function Region:has_weather()
    return self.weather_id ~= nil and self.weather_id ~= ""
end
-- }}}

-- {{{ get_weather_id
-- Get the 4-char weather effect code.
-- @return string or nil
function Region:get_weather_id()
    return self.weather_id
end
-- }}}

-- {{{ get_weather_name
-- Get the friendly name for the weather effect.
-- @return string or nil
function Region:get_weather_name()
    return self.weather
end
-- }}}

-- {{{ has_ambient_sound
-- Check if this region has an ambient sound.
-- @return boolean
function Region:has_ambient_sound()
    return self.ambient_sound ~= nil and self.ambient_sound ~= ""
end
-- }}}

-- {{{ get_ambient_sound
-- Get the ambient sound reference name.
-- @return string or nil
function Region:get_ambient_sound()
    return self.ambient_sound
end
-- }}}

-- {{{ get_color
-- Get the editor color as RGB values.
-- @return Table with r, g, b values (0-255)
function Region:get_color()
    return {
        r = self.color.r,
        g = self.color.g,
        b = self.color.b,
    }
end
-- }}}

-- {{{ get_color_rgba
-- Get the editor color with alpha channel.
-- @return Table with r, g, b, a values (0-255)
function Region:get_color_rgba()
    return {
        r = self.color.r,
        g = self.color.g,
        b = self.color.b,
        a = self.color.a,
    }
end
-- }}}

-- {{{ __tostring
function Region:__tostring()
    local size = self:get_size()
    local extras = {}
    if self:has_weather() then
        extras[#extras + 1] = "weather"
    end
    if self:has_ambient_sound() then
        extras[#extras + 1] = "sound"
    end
    local extra_str = ""
    if #extras > 0 then
        extra_str = " [" .. table.concat(extras, "+") .. "]"
    end
    return string.format("Region<%s %.0fx%.0f%s>",
        self.name ~= "" and self.name or "unnamed",
        size.width,
        size.height,
        extra_str)
end
-- }}}
-- }}}

return Region

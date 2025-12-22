-- Region Class
-- Represents trigger regions and waygate destinations from war3map.w3r.
-- Wraps parsed region data with methods for point containment, weather, etc.
--
-- Implementation: 206d-implement-region-class

-- {{{ Region class
local Region = {}
Region.__index = Region

-- {{{ new
-- Create a new Region from parsed region data.
-- @param data Table from w3r.parse() containing region fields
-- @return Region instance
function Region.new(data)
    local self = setmetatable({}, Region)
    -- TODO: Copy fields from data in 206d
    self.name = data.name
    self.creation_number = data.creation_number
    self.bounds = data.bounds
    self.weather = data.weather_id
    self.ambient_sound = data.ambient_sound
    return self
end
-- }}}

-- {{{ Placeholder methods (implement in 206d)
function Region:get_center()
    -- TODO: Calculate center from bounds
    if self.bounds then
        return {
            x = (self.bounds.left + self.bounds.right) / 2,
            y = (self.bounds.bottom + self.bounds.top) / 2,
        }
    end
    return { x = 0, y = 0 }
end

function Region:get_size()
    -- TODO: Calculate size from bounds
    if self.bounds then
        return {
            width = self.bounds.right - self.bounds.left,
            height = self.bounds.top - self.bounds.bottom,
        }
    end
    return { width = 0, height = 0 }
end

function Region:contains_point(x, y)
    -- TODO: Check if point is within bounds
    if not self.bounds then return false end
    return x >= self.bounds.left and x <= self.bounds.right
       and y >= self.bounds.bottom and y <= self.bounds.top
end

function Region:has_weather()
    -- TODO: Check weather_id is set
    return self.weather ~= nil and self.weather ~= ""
end

function Region:has_ambient_sound()
    -- TODO: Check ambient_sound is set
    return self.ambient_sound ~= nil and self.ambient_sound ~= ""
end
-- }}}

-- {{{ __tostring
function Region:__tostring()
    local size = self:get_size()
    return string.format("Region<%s %.0fx%.0f>",
        self.name or "?",
        size.width,
        size.height)
end
-- }}}
-- }}}

return Region
